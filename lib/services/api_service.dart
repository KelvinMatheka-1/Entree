import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/event_model.dart';
import '../models/guest_model.dart';
import '../models/user_profile_model.dart';
import 'local_storage_service.dart';
import 'pass_token_service.dart';

export 'invite_crypto_service.dart'
    show VerificationResult, CheckInVerificationType, InvitePayloadResult, InviteCryptoService;

class ScanResult {
  final bool canCheckIn;
  final String status;
  final String message;
  final GuestModel? guest;
  final bool outsideJurisdiction;

  const ScanResult({
    required this.canCheckIn,
    required this.status,
    required this.message,
    this.guest,
    this.outsideJurisdiction = false,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      canCheckIn: json['canCheckIn'] == true,
      status: json['status']?.toString() ?? 'ready',
      message: json['message']?.toString() ?? '',
      guest: json['guest'] != null ? GuestModel.fromJson(json['guest']) : null,
      outsideJurisdiction: json['outsideJurisdiction'] == true,
    );
  }
}

class CheckInResult {
  final bool success;
  final String message;
  final GuestModel? guest;

  const CheckInResult({
    required this.success,
    required this.message,
    this.guest,
  });

  factory CheckInResult.fromJson(Map<String, dynamic> json) {
    return CheckInResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      guest: json['guest'] != null ? GuestModel.fromJson(json['guest']) : null,
    );
  }
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// Clean environment toggle for MachineNova live upstream integration
  /// Defaults to false so developers can work solo without active organization credentials.
  static bool useMachineNovaLive =
      const bool.fromEnvironment('USE_MACHINENOVA_LIVE', defaultValue: false);

  /// Dynamic preference checker combining environment default and SharedPreferences
  static bool get isMachineNovaLiveEnabled =>
      LocalStorageService.instance.getUseMachineNovaLive() || useMachineNovaLive;

  /// Set the environment toggle dynamically at runtime
  static Future<void> setUseMachineNovaLive(bool enabled) async {
    useMachineNovaLive = enabled;
    await LocalStorageService.instance.setUseMachineNovaLive(enabled);
  }

  // Base URL for production / local proxy
  static String baseUrl = 'http://localhost:4000/api/v1';

  bool _isBackendReachable = true;
  bool get isBackendReachable => _isBackendReachable;

  // --- CRYPTOGRAPHIC QR TOKEN UTILITIES ---

  /// Encodes a verifiable, cryptographically signed JWT pass token for an event attendee
  String generatePassToken(EventModel event, GuestModel guest) {
    return PassTokenService.generatePassToken(event: event, guest: guest);
  }

  /// Parses and verifies any raw barcode/JWT input
  PassTokenPayload decodePassToken(String rawCode, {String? defaultEventId}) {
    return PassTokenService.decodeToken(rawCode, defaultEventId: defaultEventId);
  }

  // --- EVENTS CRUD ---

  Future<List<EventModel>> getEvents({
    String? status,
    String? search,
    bool refresh = false,
  }) async {
    // When live MachineNova toggle is OFF, route directly through persistent local storage
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.getEvents(status: status, search: search);
    }

    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (refresh) queryParams['refresh'] = 'true';

      final uri = Uri.parse('$baseUrl/events').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['events'] as List<dynamic>)
            .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
            .toList();

        _isBackendReachable = true;
        // Mirror to local persistent cache
        for (final ev in list) {
          await LocalStorageService.instance.updateEvent(ev);
        }
        return list;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] 401/403 MachineNova Auth failed, falling back to persistent local storage engine.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] getEvents network error, falling back to persistent local storage: $e');
      _isBackendReachable = false;
    }

    return LocalStorageService.instance.getEvents(status: status, search: search);
  }

  Future<EventModel?> getEvent(String id) async {
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.getEvent(id);
    }

    try {
      final uri = Uri.parse('$baseUrl/events/$id');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isBackendReachable = true;
        final event = EventModel.fromJson(data['event']);
        await LocalStorageService.instance.updateEvent(event);
        return event;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] getEvent 401/403 auth error, falling back to local engine.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] getEvent network error, falling back to local engine: $e');
    }

    return LocalStorageService.instance.getEvent(id);
  }

  Future<EventModel> createEvent(EventModel event) async {
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.createEvent(event);
    }

    try {
      final uri = Uri.parse('$baseUrl/events');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(event.toJson()),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final created = EventModel.fromJson(data['event']);
        await LocalStorageService.instance.createEvent(created);
        return created;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] createEvent 401/403 auth error, saving to local engine.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] createEvent network error, saving to local engine: $e');
    }

    return LocalStorageService.instance.createEvent(event);
  }

  Future<EventModel> updateEvent(EventModel event) async {
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.updateEvent(event);
    }

    try {
      final uri = Uri.parse('$baseUrl/events/${event.id}');
      final response = await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(event.toJson()),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updated = EventModel.fromJson(data['event']);
        await LocalStorageService.instance.updateEvent(updated);
        return updated;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] updateEvent 401/403 auth error, updating local engine.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] updateEvent network error, updating local engine: $e');
    }

    return LocalStorageService.instance.updateEvent(event);
  }

  Future<bool> deleteEvent(String id) async {
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.deleteEvent(id);
    }

    try {
      final uri = Uri.parse('$baseUrl/events/$id');
      final response = await http.delete(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        await LocalStorageService.instance.deleteEvent(id);
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] deleteEvent 401/403 auth error, deleting locally.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] deleteEvent network error: $e');
    }

    return LocalStorageService.instance.deleteEvent(id);
  }

  // --- GUESTS CRUD & INVITES ---

  Future<List<GuestModel>> getGuests(
    String eventId, {
    String? status,
    String? search,
  }) async {
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.getGuests(eventId, status: status, search: search);
    }

    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/events/$eventId/guests').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['guests'] as List<dynamic>)
            .map((g) => GuestModel.fromJson(g as Map<String, dynamic>))
            .toList();

        for (final g in list) {
          await LocalStorageService.instance.addGuest(eventId, g);
        }
        return list;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] getGuests 401/403 auth error, falling back to local engine.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] getGuests network error, falling back to local engine: $e');
    }

    return LocalStorageService.instance.getGuests(eventId, status: status, search: search);
  }

  Future<GuestModel> addGuest(String eventId, GuestModel guest) async {
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.addGuest(eventId, guest);
    }

    try {
      final uri = Uri.parse('$baseUrl/events/$eventId/guests');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(guest.toJson()),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final created = GuestModel.fromJson(data['guest']);
        await LocalStorageService.instance.addGuest(eventId, created);
        return created;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] addGuest 401/403 auth error, saving to local engine.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] addGuest network error, saving to local engine: $e');
    }

    return LocalStorageService.instance.addGuest(eventId, guest);
  }

  /// Self-service attendee RSVP: registers a new attendee, creates a signed pass,
  /// updates event's passesIssued count, and saves to storage
  Future<GuestModel> rsvpGuest({
    required String eventId,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    return LocalStorageService.instance.rsvpGuest(
      eventId: eventId,
      fullName: fullName,
      email: email,
      phone: phone,
    );
  }

  // --- SCAN & CHECK-IN VALIDATION ---

  Future<ScanResult> verifyScan(String eventId, String passIdOrToken) async {
    final tokenPayload = PassTokenService.decodeToken(passIdOrToken, defaultEventId: eventId);
    final rawPassId = tokenPayload.passId;

    if (!isMachineNovaLiveEnabled) {
      final localRes = await LocalStorageService.instance.verifyScan(eventId, passIdOrToken);
      return ScanResult(
        canCheckIn: localRes.canCheckIn,
        status: localRes.status,
        message: localRes.message,
        guest: localRes.guest,
        outsideJurisdiction: localRes.outsideJurisdiction,
      );
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/events/$eventId/scan?passId=${Uri.encodeComponent(rawPassId)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScanResult.fromJson(data['verification']);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] verifyScan 401/403, validating via local persistent engine.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] verifyScan network error, validating via local persistent engine: $e');
    }

    final localRes = await LocalStorageService.instance.verifyScan(eventId, passIdOrToken);
    return ScanResult(
      canCheckIn: localRes.canCheckIn,
      status: localRes.status,
      message: localRes.message,
      guest: localRes.guest,
      outsideJurisdiction: localRes.outsideJurisdiction,
    );
  }

  Future<CheckInResult> checkInGuest(
    String eventId,
    String passIdOrToken, {
    String? operatorId,
    String? fullName,
  }) async {
    final tokenPayload = PassTokenService.decodeToken(passIdOrToken, defaultEventId: eventId);
    final targetPassId = tokenPayload.passId;
    final targetName = fullName ?? tokenPayload.fullName;

    if (!isMachineNovaLiveEnabled) {
      final localRes = await LocalStorageService.instance.checkInGuest(
        eventId,
        passIdOrToken,
        operatorId: operatorId,
        fullName: targetName,
      );
      return CheckInResult(
        success: localRes.success,
        message: localRes.message,
        guest: localRes.guest,
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/events/$eventId/checkin');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'passId': targetPassId,
              'operatorId': operatorId ?? 'mobile-app',
              'fullName': targetName,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = CheckInResult.fromJson(data);

        // Mirror check-in to local persistent storage
        await LocalStorageService.instance.checkInGuest(
          eventId,
          passIdOrToken,
          operatorId: operatorId,
          fullName: targetName,
        );
        return result;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] checkInGuest 401/403 auth error, committing locally.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] checkInGuest network error, committing locally: $e');
    }

    final localRes = await LocalStorageService.instance.checkInGuest(
      eventId,
      passIdOrToken,
      operatorId: operatorId,
      fullName: targetName,
    );
    return CheckInResult(
      success: localRes.success,
      message: localRes.message,
      guest: localRes.guest,
    );
  }

  /// Comprehensive QR Scan verification and check-in pipeline
  Future<VerificationResult> verifyAndCheckIn(
    String eventId,
    String passIdOrToken, {
    String? operatorId,
    String? fullName,
  }) async {
    // In local mode (default), execute directly against persistent storage engine
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.verifyAndCheckIn(eventId, passIdOrToken);
    }

    try {
      final scan = await verifyScan(eventId, passIdOrToken);
      if (!scan.canCheckIn) {
        if (scan.outsideJurisdiction || scan.status == 'wrong_event') {
          return VerificationResult(
            type: CheckInVerificationType.wrongEvent,
            message: scan.message,
            guest: scan.guest,
            isCryptographicallyVerified: true,
          );
        }
        if (scan.status == 'already_checked_in') {
          return VerificationResult(
            type: CheckInVerificationType.duplicate,
            message: scan.message,
            guest: scan.guest,
            previousCheckInTime: scan.guest?.checkInTime,
          );
        }
        return VerificationResult(
          type: CheckInVerificationType.invalidPayload,
          message: scan.message,
          guest: scan.guest,
        );
      }

      final checkIn = await checkInGuest(
        eventId,
        passIdOrToken,
        operatorId: operatorId,
        fullName: fullName,
      );

      if (checkIn.success) {
        return VerificationResult(
          type: CheckInVerificationType.valid,
          message: checkIn.message,
          guest: checkIn.guest,
          isCryptographicallyVerified: true,
        );
      } else {
        return VerificationResult(
          type: CheckInVerificationType.duplicate,
          message: checkIn.message,
          guest: checkIn.guest,
          previousCheckInTime: checkIn.guest?.checkInTime,
        );
      }
    } catch (e) {
      debugPrint('[API_SERVICE] verifyAndCheckIn live fallback to local engine: $e');
    }

    return LocalStorageService.instance.verifyAndCheckIn(eventId, passIdOrToken);
  }

  Future<bool> undoCheckIn(String eventId, String passIdOrToken) async {
    final tokenPayload = PassTokenService.decodeToken(passIdOrToken, defaultEventId: eventId);
    final targetPassId = tokenPayload.passId;

    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.undoCheckIn(eventId, targetPassId);
    }

    try {
      final uri = Uri.parse('$baseUrl/events/$eventId/undo-checkin');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'passId': targetPassId}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        await LocalStorageService.instance.undoCheckIn(eventId, targetPassId);
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] undoCheckIn 401/403 auth error, reverting locally.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] undoCheckIn network error: $e');
    }

    return LocalStorageService.instance.undoCheckIn(eventId, targetPassId);
  }

  Future<Map<String, dynamic>?> getEventStats(String eventId) async {
    try {
      final uri = Uri.parse('$baseUrl/events/$eventId/stats');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['stats'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] getEventStats fallback: $e');
    }

    final ev = await LocalStorageService.instance.getEvent(eventId);
    if (ev != null) {
      return {
        'totalCheckins': ev.checkedIn,
        'passesIssued': ev.passesIssued,
        'totalCapacity': ev.totalCapacity,
        'remaining': ev.expected,
      };
    }
    return null;
  }

  // --- USER PROFILE & SYSTEM DIAGNOSTICS ---

  Future<FullProfileData?> getProfile({bool forceRefresh = false}) async {
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.getProfile();
    }

    try {
      final uri = Uri.parse('$baseUrl/auth/profile');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isBackendReachable = true;
        return FullProfileData.fromJson(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] getProfile 401/403, loading local profile.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] getProfile error: $e');
    }

    return LocalStorageService.instance.getProfile();
  }

  Future<UserProfileModel?> updateProfile({
    String? fullName,
    String? email,
    String? role,
    String? organization,
    String? phone,
    String? avatarUrl,
    String? bio,
    String? scannerSpeed,
    bool? hapticFeedback,
  }) async {
    if (!isMachineNovaLiveEnabled) {
      return LocalStorageService.instance.updateProfile(
        fullName: fullName,
        email: email,
        role: role,
        organization: organization,
        phone: phone,
        avatarUrl: avatarUrl,
        bio: bio,
        scannerSpeed: scannerSpeed,
        hapticFeedback: hapticFeedback,
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/auth/profile');
      final payload = <String, dynamic>{};
      if (fullName != null) payload['fullName'] = fullName;
      if (email != null) payload['email'] = email;
      if (role != null) payload['role'] = role;
      if (organization != null) payload['organization'] = organization;
      if (phone != null) payload['phone'] = phone;
      if (avatarUrl != null) payload['avatarUrl'] = avatarUrl;
      if (bio != null) payload['bio'] = bio;
      if (scannerSpeed != null) payload['scannerSpeed'] = scannerSpeed;
      if (hapticFeedback != null) payload['hapticFeedback'] = hapticFeedback;

      final response = await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updated = UserProfileModel.fromJson(data['profile']);
        await LocalStorageService.instance.updateProfile(
          fullName: updated.fullName,
          email: updated.email,
          role: updated.role,
          organization: updated.organization,
          phone: updated.phone,
          avatarUrl: updated.avatarUrl,
          bio: updated.bio,
          scannerSpeed: updated.scannerSpeed,
          hapticFeedback: updated.hapticFeedback,
        );
        return updated;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[API_SERVICE] updateProfile 401/403, saving to local persistent engine.');
      }
    } catch (e) {
      debugPrint('[API_SERVICE] updateProfile error: $e');
    }

    return LocalStorageService.instance.updateProfile(
      fullName: fullName,
      email: email,
      role: role,
      organization: organization,
      phone: phone,
      avatarUrl: avatarUrl,
      bio: bio,
      scannerSpeed: scannerSpeed,
      hapticFeedback: hapticFeedback,
    );
  }

  Future<bool> flushSyncQueue() async {
    try {
      final uri = Uri.parse('$baseUrl/sync/flush');
      final response = await http.post(uri).timeout(const Duration(seconds: 6));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API_SERVICE] flushSyncQueue error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSystemDiagnostics() async {
    try {
      final uri = Uri.parse('$baseUrl/auth/status');
      final stopwatch = Stopwatch()..start();
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        data['latencyMs'] = stopwatch.elapsedMilliseconds;
        return data;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] getSystemDiagnostics error: $e');
    }

    return {
      'status': 'ok',
      'mode': isMachineNovaLiveEnabled ? 'machinenova_live' : 'local_storage',
      'useMachineNovaLive': isMachineNovaLiveEnabled,
      'latencyMs': 0,
      'storage': 'SharedPreferences Persistent Engine',
      'message': 'Local standalone engine active with zero external API dependencies.',
    };
  }
}
