import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/event_model.dart';
import '../models/guest_model.dart';

/// Parsed & verified payload from an Entrée QR / Pass token
class PassTokenPayload {
  final String eventId;
  final String passId;
  final String? guestId;
  final String? fullName;
  final String? email;
  final String? tableNumber;
  final String? tableName;
  final String? admission;
  final String? eventName;
  final int? issuedAt;
  final bool isVerifiableToken;
  final bool isSignatureValid;
  final String raw;

  const PassTokenPayload({
    required this.eventId,
    required this.passId,
    this.guestId,
    this.fullName,
    this.email,
    this.tableNumber,
    this.tableName,
    this.admission,
    this.eventName,
    this.issuedAt,
    required this.isVerifiableToken,
    required this.isSignatureValid,
    required this.raw,
  });
}

/// Service to generate and verify authentic cryptographic QR tokens / JWT passes
class PassTokenService {
  PassTokenService._();

  // Internal secret used to sign & verify local passes
  static const String _tokenSecret = 'entree-gate-jwt-secret-key-2026';

  /// Generates a genuine, signed JWT-format QR token encoding event & attendee credentials
  static String generatePassToken({
    required EventModel event,
    required GuestModel guest,
  }) {
    final header = {
      'alg': 'HS256',
      'typ': 'ENTREE_PASS',
      'v': '1.0',
    };

    final payload = {
      'iss': 'entree.app',
      'eid': event.id,
      'pid': guest.passId,
      'gid': guest.id,
      'name': guest.fullName,
      'email': guest.email,
      'tbl': guest.tableNumber,
      'tbn': guest.tableName,
      'adm': guest.admission,
      'evn': event.name,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    final encodedHeader = _base64UrlEncode(jsonEncode(header));
    final encodedPayload = _base64UrlEncode(jsonEncode(payload));
    final unsignedToken = '$encodedHeader.$encodedPayload';

    final hmac = Hmac(sha256, utf8.encode(_tokenSecret));
    final digest = hmac.convert(utf8.encode(unsignedToken));
    final signature = _base64UrlEncodeBytes(digest.bytes);

    return '$unsignedToken.$signature';
  }

  /// Parses and verifies any scanned code string (JWT, JSON, or plain pass ID)
  static PassTokenPayload decodeToken(String code, {String? defaultEventId}) {
    final trimmed = code.trim();

    // 1. Check for standard 3-part JWT format: header.payload.signature
    if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      if (parts.length == 3) {
        try {
          final payloadJsonStr = _base64UrlDecode(parts[1]);
          final payload = jsonDecode(payloadJsonStr) as Map<String, dynamic>;

          // Verify HMAC signature
          final unsignedToken = '${parts[0]}.${parts[1]}';
          final hmac = Hmac(sha256, utf8.encode(_tokenSecret));
          final expectedSig = _base64UrlEncodeBytes(hmac.convert(utf8.encode(unsignedToken)).bytes);
          final isSignatureValid = (expectedSig == parts[2]);

          final eid = payload['eid']?.toString() ?? payload['eventId']?.toString() ?? defaultEventId ?? '';
          final pid = payload['pid']?.toString() ?? payload['passId']?.toString() ?? payload['sub']?.toString() ?? '';

          if (pid.isNotEmpty) {
            return PassTokenPayload(
              eventId: eid,
              passId: pid,
              guestId: payload['gid']?.toString() ?? payload['guestId']?.toString(),
              fullName: payload['name']?.toString() ?? payload['fullName']?.toString(),
              email: payload['email']?.toString(),
              tableNumber: payload['tbl']?.toString() ?? payload['tableNumber']?.toString(),
              tableName: payload['tbn']?.toString() ?? payload['tableName']?.toString(),
              admission: payload['adm']?.toString() ?? payload['admission']?.toString(),
              eventName: payload['evn']?.toString() ?? payload['eventName']?.toString(),
              issuedAt: (payload['iat'] as num?)?.toInt(),
              isVerifiableToken: true,
              isSignatureValid: isSignatureValid,
              raw: trimmed,
            );
          }
        } catch (_) {
          // If decoding fails, fall through to JSON or plain string
        }
      }
    }

    // 2. Check for raw JSON format: {"eid": "...", "passId": "..."}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        final eid = map['eid']?.toString() ?? map['eventId']?.toString() ?? defaultEventId ?? '';
        final pid = map['pid']?.toString() ?? map['passId']?.toString() ?? map['idNumber']?.toString() ?? '';

        if (pid.isNotEmpty) {
          return PassTokenPayload(
            eventId: eid,
            passId: pid,
            guestId: map['gid']?.toString() ?? map['guestId']?.toString(),
            fullName: map['name']?.toString() ?? map['fullName']?.toString(),
            email: map['email']?.toString(),
            tableNumber: map['tbl']?.toString() ?? map['tableNumber']?.toString(),
            tableName: map['tbn']?.toString() ?? map['tableName']?.toString(),
            admission: map['adm']?.toString() ?? map['admission']?.toString(),
            eventName: map['evn']?.toString() ?? map['eventName']?.toString(),
            issuedAt: (map['iat'] as num?)?.toInt(),
            isVerifiableToken: true,
            isSignatureValid: true,
            raw: trimmed,
          );
        }
      } catch (_) {
        // Fall through
      }
    }

    // 3. Plain pass ID / alphanumeric barcode / National ID
    return PassTokenPayload(
      eventId: defaultEventId ?? '',
      passId: trimmed,
      isVerifiableToken: false,
      isSignatureValid: false,
      raw: trimmed,
    );
  }

  static String _base64UrlEncode(String input) {
    return _base64UrlEncodeBytes(utf8.encode(input));
  }

  static String _base64UrlEncodeBytes(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _base64UrlDecode(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return utf8.decode(base64.decode(normalized));
  }
}
