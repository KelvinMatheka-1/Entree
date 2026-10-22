import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/guest_model.dart';

/// Verification status for scanned check-in
enum CheckInVerificationType {
  valid,
  duplicate,
  wrongEvent,
  invalidPayload,
}

/// Comprehensive result for a scan verification and check-in attempt
class VerificationResult {
  final CheckInVerificationType type;
  final String message;
  final GuestModel? guest;
  final String? previousCheckInTime;
  final String? eventName;
  final bool isCryptographicallyVerified;

  const VerificationResult({
    required this.type,
    required this.message,
    this.guest,
    this.previousCheckInTime,
    this.eventName,
    this.isCryptographicallyVerified = false,
  });

  bool get isValid => type == CheckInVerificationType.valid;
  bool get isDuplicate => type == CheckInVerificationType.duplicate;
  bool get isWrongEvent => type == CheckInVerificationType.wrongEvent;
  bool get isInvalid => type == CheckInVerificationType.invalidPayload;
}

/// Parsed result from an invite payload or deep link
class InvitePayloadResult {
  final bool isValid;
  final String eventId;
  final String guestId;
  final String inviteCode;
  final String? fullName;
  final int? timestamp;
  final String? signature;
  final String? rawData;
  final String? errorMessage;

  const InvitePayloadResult({
    required this.isValid,
    required this.eventId,
    required this.guestId,
    required this.inviteCode,
    this.fullName,
    this.timestamp,
    this.signature,
    this.rawData,
    this.errorMessage,
  });

  factory InvitePayloadResult.invalid(String error, {String? rawData}) {
    return InvitePayloadResult(
      isValid: false,
      eventId: '',
      guestId: '',
      inviteCode: '',
      errorMessage: error,
      rawData: rawData,
    );
  }
}

/// Cryptographic QR & Deep Link Payload Engine
/// Generates and verifies HMAC-SHA256 signed invite payloads matching the exact specification:
/// {"v": 1, "event_id": "...", "guest_id": "...", "invite_code": "...", "sig": "..."}
class InviteCryptoService {
  InviteCryptoService._();

  static const String _secretKey = 'entree-machinenova-invite-hmac-secret-2026';
  static const int currentVersion = 1;

  /// Generate HMAC-SHA256 signature for payload fields
  static String _generateSignature({
    required int version,
    required String eventId,
    required String guestId,
    required String inviteCode,
  }) {
    final message = '$version.$eventId.$guestId.$inviteCode';
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmac.convert(utf8.encode(message));
    return digest.toString();
  }

  /// Create a signed payload map
  static Map<String, dynamic> createSignedPayload({
    required String eventId,
    required String guestId,
    required String inviteCode,
    String? fullName,
    int? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sig = _generateSignature(
      version: currentVersion,
      eventId: eventId,
      guestId: guestId,
      inviteCode: inviteCode,
    );

    return {
      'v': currentVersion,
      'event_id': eventId,
      'guest_id': guestId,
      'invite_code': inviteCode,
      if (fullName != null && fullName.isNotEmpty) 'name': fullName,
      'ts': ts,
      'sig': sig,
    };
  }

  /// Create compact JSON string payload
  static String createSignedPayloadJson({
    required String eventId,
    required String guestId,
    required String inviteCode,
    String? fullName,
    int? timestamp,
  }) {
    final map = createSignedPayload(
      eventId: eventId,
      guestId: guestId,
      inviteCode: inviteCode,
      fullName: fullName,
      timestamp: timestamp,
    );
    return jsonEncode(map);
  }

  /// Generate a clickable deep link URL
  /// Supports custom scheme: entree://invite?data=...
  /// and universal HTTPS link: https://machinenova.com/invite?data=...
  static String generateDeepLink({
    required String eventId,
    required String guestId,
    required String inviteCode,
    String? fullName,
    bool useUniversalLink = true,
  }) {
    final payloadJson = createSignedPayloadJson(
      eventId: eventId,
      guestId: guestId,
      inviteCode: inviteCode,
      fullName: fullName,
    );

    final encodedData = base64Url.encode(utf8.encode(payloadJson)).replaceAll('=', '');

    if (useUniversalLink) {
      return 'https://machinenova.com/invite?data=$encodedData';
    } else {
      return 'entree://invite?data=$encodedData';
    }
  }

  /// Generate a public shareable Event RSVP Link that organizers can distribute anywhere
  /// Anyone with this link can open the RSVP page, register, and get their cryptographic pass.
  static String generateEventRsvpLink(String eventId, {bool useUniversalLink = true}) {
    if (useUniversalLink) {
      return 'https://machinenova.com/event/$eventId/rsvp';
    } else {
      return 'entree://event/$eventId/rsvp';
    }
  }

  /// Verifies a payload map's HMAC-SHA256 signature
  static bool verifyPayload(Map<String, dynamic> payload) {
    try {
      final v = payload['v'] is int ? payload['v'] as int : int.tryParse(payload['v']?.toString() ?? '1') ?? 1;
      final eventId = payload['event_id']?.toString() ?? '';
      final guestId = payload['guest_id']?.toString() ?? '';
      final inviteCode = payload['invite_code']?.toString() ?? '';
      final sig = payload['sig']?.toString() ?? '';

      if (eventId.isEmpty || guestId.isEmpty || inviteCode.isEmpty || sig.isEmpty) {
        return false;
      }

      final expected = _generateSignature(
        version: v,
        eventId: eventId,
        guestId: guestId,
        inviteCode: inviteCode,
      );

      return expected == sig;
    } catch (_) {
      return false;
    }
  }

  /// Parse and verify any raw input (URL, Deep Link, JSON string, or Base64 data string)
  static InvitePayloadResult parseAndVerify(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty) {
      return InvitePayloadResult.invalid('Empty payload input', rawData: input);
    }

    try {
      Map<String, dynamic>? payloadMap;

      final isUrl = input.startsWith('entree://') || input.startsWith('http://') || input.startsWith('https://');

      // Case 1: Full URL with query parameter (e.g. entree://invite?data=... or https://machinenova.com/invite?data=...)
      if (isUrl) {
        final uri = Uri.tryParse(input);
        if (uri != null && uri.queryParameters.containsKey('data')) {
          final dataParam = uri.queryParameters['data']!;
          payloadMap = _decodeBase64Json(dataParam);
        } else {
          return InvitePayloadResult.invalid('Not a valid invite deep link', rawData: input);
        }
      }

      // Case 2: Raw JSON string starting with '{'
      if (payloadMap == null && !isUrl && input.startsWith('{') && input.endsWith('}')) {
        payloadMap = jsonDecode(input) as Map<String, dynamic>;
      }

      // Case 3: Raw base64 encoded string
      if (payloadMap == null && !isUrl && !input.contains(' ') && input.length > 10) {
        payloadMap = _decodeBase64Json(input);
      }

      if (payloadMap == null) {
        return InvitePayloadResult.invalid('Unrecognized payload format', rawData: input);
      }

      final isSigValid = verifyPayload(payloadMap);
      if (!isSigValid) {
        return InvitePayloadResult.invalid('Cryptographic signature verification failed (tampered or invalid payload)', rawData: input);
      }

      return InvitePayloadResult(
        isValid: true,
        eventId: payloadMap['event_id']?.toString() ?? '',
        guestId: payloadMap['guest_id']?.toString() ?? '',
        inviteCode: payloadMap['invite_code']?.toString() ?? '',
        fullName: payloadMap['name']?.toString(),
        timestamp: (payloadMap['ts'] as num?)?.toInt(),
        signature: payloadMap['sig']?.toString(),
        rawData: input,
      );
    } catch (e) {
      return InvitePayloadResult.invalid('Failed to parse payload: $e', rawData: input);
    }
  }

  static Map<String, dynamic>? _decodeBase64Json(String base64Str) {
    try {
      var normalized = base64Str.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final jsonStr = utf8.decode(base64.decode(normalized));
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
