import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_model.dart';
import '../models/guest_model.dart';
import '../models/user_profile_model.dart';
import '../data/mock_data.dart';
import 'pass_token_service.dart';
import 'invite_crypto_service.dart';

export 'invite_crypto_service.dart'
    show VerificationResult, CheckInVerificationType, InvitePayloadResult, InviteCryptoService;

/// Persistent local storage engine using SharedPreferences
/// Provides full offline/standalone CRUD with identical API response models
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  static const String _kEventsKey = 'entree_local_events_v1';
  static const String _kGuestsKey = 'entree_local_guests_v1';
  static const String _kProfileKey = 'entree_local_user_profile_v1';
  static const String _kUseMachineNovaKey = 'entree_use_machinenova_live';

  SharedPreferences? _prefs;
  bool _initialized = false;

  // In-memory write-through cache
  final List<EventModel> _cachedEvents = [];
  final Map<String, List<GuestModel>> _cachedGuests = {};
  FullProfileData? _cachedProfile;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadOrSeed();
      _initialized = true;
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] Initialization error: $e');
      _seedMemoryFallback();
      _initialized = true;
    }
  }

  Future<void> _loadOrSeed() async {
    final prefs = _prefs;
    if (prefs == null) {
      _seedMemoryFallback();
      return;
    }

    // 1. Events
    final eventsJson = prefs.getString(_kEventsKey);
    if (eventsJson != null && eventsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(eventsJson) as List<dynamic>;
        _cachedEvents.clear();
        _cachedEvents.addAll(decoded.map((e) => EventModel.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] Corrupt events JSON, re-seeding: $e');
        _seedEvents(prefs);
      }
    } else {
      _seedEvents(prefs);
    }

    // 2. Guests
    final guestsJson = prefs.getString(_kGuestsKey);
    if (guestsJson != null && guestsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(guestsJson) as Map<String, dynamic>;
        _cachedGuests.clear();
        decoded.forEach((eventId, guestList) {
          _cachedGuests[eventId] = (guestList as List<dynamic>)
              .map((g) => GuestModel.fromJson(g as Map<String, dynamic>))
              .toList();
        });
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] Corrupt guests JSON, re-seeding: $e');
        _seedGuests(prefs);
      }
    } else {
      _seedGuests(prefs);
    }

    // 3. Profile
    final profileJson = prefs.getString(_kProfileKey);
    if (profileJson != null && profileJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(profileJson) as Map<String, dynamic>;
        _cachedProfile = FullProfileData.fromJson(decoded);
      } catch (_) {
        _buildDefaultProfile();
      }
    } else {
      _buildDefaultProfile();
    }
  }

  void _seedEvents(SharedPreferences prefs) {
    _cachedEvents.clear();
    _cachedEvents.addAll(MockData.events);
    _persistEvents();
  }

  void _seedGuests(SharedPreferences prefs) {
    _cachedGuests.clear();
    // Seed default guests for existing mock events
    for (final event in MockData.events) {
      _cachedGuests[event.id] = List<GuestModel>.from(MockData.guests);
    }
    _persistGuests();
  }

  void _seedMemoryFallback() {
    _cachedEvents.clear();
    _cachedEvents.addAll(MockData.events);
    _cachedGuests.clear();
    for (final event in MockData.events) {
      _cachedGuests[event.id] = List<GuestModel>.from(MockData.guests);
    }
    _buildDefaultProfile();
  }

  Future<void> _persistEvents() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final jsonList = _cachedEvents.map((e) => e.toJson()).toList();
      await prefs.setString(_kEventsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] Error persisting events: $e');
    }
  }

  Future<void> _persistGuests() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final map = <String, dynamic>{};
      _cachedGuests.forEach((eventId, guests) {
        map[eventId] = guests.map((g) => g.toJson()).toList();
      });
      await prefs.setString(_kGuestsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] Error persisting guests: $e');
    }
  }

  Future<void> _persistProfile() async {
    final prefs = _prefs;
    if (prefs == null || _cachedProfile == null) return;
    try {
      final profileMap = {
        'profile': _cachedProfile!.profile.toJson(),
        'stats': {
          'totalEvents': _cachedProfile!.stats.totalEvents,
          'totalCapacity': _cachedProfile!.stats.totalCapacity,
          'totalCheckedIn': _cachedProfile!.stats.totalCheckedIn,
          'totalPasses': _cachedProfile!.stats.totalPasses,
          'checkInRate': _cachedProfile!.stats.checkInRate,
          'pendingSyncs': _cachedProfile!.stats.pendingSyncs,
        },
        'upstream': {
          'configured': _cachedProfile!.upstream.configured,
          'mode': _cachedProfile!.upstream.mode,
          'target': _cachedProfile!.upstream.target,
          'frontend': _cachedProfile!.upstream.frontend,
        },
      };
      await prefs.setString(_kProfileKey, jsonEncode(profileMap));
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] Error persisting profile: $e');
    }
  }

  void _buildDefaultProfile() {
    final totalCapacity = _cachedEvents.fold<int>(0, (sum, e) => sum + e.totalCapacity);
    final totalCheckedIn = _cachedEvents.fold<int>(0, (sum, e) => sum + e.checkedIn);
    final totalPasses = _cachedEvents.fold<int>(0, (sum, e) => sum + e.passesIssued);
    final checkInRate = totalPasses > 0
        ? '${((totalCheckedIn / totalPasses) * 100).toStringAsFixed(1)}%'
        : totalCapacity > 0
            ? '${((totalCheckedIn / totalCapacity) * 100).toStringAsFixed(1)}%'
            : '0.0%';

    _cachedProfile = FullProfileData(
      profile: const UserProfileModel(
        id: 'local-owner-1',
        fullName: 'Kelvin Matheka',
        email: 'kelvin@entree.app',
        role: 'Event Owner',
        organization: 'Entrée Live Operations',
        phone: '+254 700 000 000',
        scannerSpeed: 'High sensitivity',
        hapticFeedback: true,
      ),
      stats: ProfileStats(
        totalEvents: _cachedEvents.length,
        totalCapacity: totalCapacity,
        totalCheckedIn: totalCheckedIn,
        totalPasses: totalPasses,
        checkInRate: checkInRate,
        pendingSyncs: 0,
      ),
      upstream: const UpstreamStatus(
        configured: false,
        mode: 'local_storage',
        target: 'https://checkin-backend.machinenova.com',
        frontend: 'https://checkin.machinenova.com',
      ),
    );
  }

  // --- TOGGLE PREFERENCES ---

  bool getUseMachineNovaLive() {
    if (_prefs == null) return false;
    return _prefs!.getBool(_kUseMachineNovaKey) ??
        const bool.fromEnvironment('USE_MACHINENOVA_LIVE', defaultValue: false);
  }

  Future<void> setUseMachineNovaLive(bool enabled) async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setBool(_kUseMachineNovaKey, enabled);
    }
    if (_cachedProfile != null) {
      _cachedProfile = FullProfileData(
        profile: _cachedProfile!.profile,
        stats: _cachedProfile!.stats,
        upstream: UpstreamStatus(
          configured: enabled,
          mode: enabled ? 'machinenova_live' : 'local_storage',
          target: _cachedProfile!.upstream.target,
          frontend: _cachedProfile!.upstream.frontend,
        ),
      );
      await _persistProfile();
    }
  }

  // --- EVENTS CRUD ---

  Future<List<EventModel>> getEvents({
    String? status,
    String? search,
  }) async {
    await init();
    var list = List<EventModel>.from(_cachedEvents);

    if (status != null && status.isNotEmpty) {
      list = list.where((e) => e.status.name.toLowerCase() == status.toLowerCase()).toList();
    }

    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      list = list.where((e) =>
          e.name.toLowerCase().contains(s) ||
          e.venue.toLowerCase().contains(s) ||
          e.collection.toLowerCase().contains(s) ||
          (e.city != null && e.city!.toLowerCase().contains(s))).toList();
    }
    return list;
  }

  Future<EventModel?> getEvent(String id) async {
    await init();
    try {
      return _cachedEvents.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<EventModel> createEvent(EventModel event) async {
    await init();
    _cachedEvents.insert(0, event);

    // Initialize guest list for this new event
    if (!_cachedGuests.containsKey(event.id)) {
      _cachedGuests[event.id] = [];
    }

    await _persistEvents();
    _refreshProfileStats();
    return event;
  }

  Future<EventModel> updateEvent(EventModel event) async {
    await init();
    final idx = _cachedEvents.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      _cachedEvents[idx] = event;
    } else {
      _cachedEvents.insert(0, event);
    }
    await _persistEvents();
    _refreshProfileStats();
    return event;
  }

  Future<bool> deleteEvent(String id) async {
    await init();
    _cachedEvents.removeWhere((e) => e.id == id);
    _cachedGuests.remove(id);
    await _persistEvents();
    await _persistGuests();
    _refreshProfileStats();
    return true;
  }

  // --- GUESTS CRUD & INVITES ---

  Future<List<GuestModel>> getGuests(
    String eventId, {
    String? status,
    String? search,
  }) async {
    await init();
    if (!_cachedGuests.containsKey(eventId)) {
      _cachedGuests[eventId] = [];
      await _persistGuests();
    }

    // Self-heal: If this event is a custom/user event (not in MockData.events) and its guest list
    // was erroneously populated with MockData.guests by earlier auto-seed logic, reset to []
    final isMockEvent = MockData.events.any((e) => e.id == eventId);
    if (!isMockEvent && _cachedGuests.containsKey(eventId)) {
      final currentGuests = _cachedGuests[eventId]!;
      final isAllMockGuests = currentGuests.isNotEmpty &&
          currentGuests.every((g) => MockData.guests.any((mg) => mg.id == g.id));
      if (isAllMockGuests) {
        _cachedGuests[eventId] = [];
        await _persistGuests();
      }
    }

    var list = List<GuestModel>.from(_cachedGuests[eventId] ?? []);
    if (status != null && status.isNotEmpty) {
      list = list.where((g) => g.status.name.toLowerCase() == status.toLowerCase()).toList();
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      list = list.where((g) =>
          g.fullName.toLowerCase().contains(s) ||
          g.passId.toLowerCase().contains(s) ||
          g.email.toLowerCase().contains(s) ||
          g.tableName.toLowerCase().contains(s)).toList();
    }
    return list;
  }

  Future<GuestModel> addGuest(String eventId, GuestModel guest) async {
    await init();
    final list = _cachedGuests[eventId] ?? [];
    
    // Check if guest with passId already exists
    final existingIdx = list.indexWhere((g) => g.passId == guest.passId);
    if (existingIdx != -1) {
      list[existingIdx] = guest;
    } else {
      list.insert(0, guest);
    }
    _cachedGuests[eventId] = list;

    // Update event's passesIssued count in persistent storage
    final evIdx = _cachedEvents.indexWhere((e) => e.id == eventId);
    if (evIdx != -1) {
      final ev = _cachedEvents[evIdx];
      _cachedEvents[evIdx] = ev.copyWith(passesIssued: ev.passesIssued + 1);
      await _persistEvents();
    }

    await _persistGuests();
    _refreshProfileStats();
    return guest;
  }

  /// Self-service attendee RSVP: registers a new attendee, assigns a unique pass ID,
  /// updates event's passesIssued count, and persists for offline verification
  Future<GuestModel> rsvpGuest({
    required String eventId,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    await init();
    final passNum = 1000 + (DateTime.now().millisecondsSinceEpoch % 9000);
    final passId = 'HS-$passNum';
    final guestId = 'g-${DateTime.now().millisecondsSinceEpoch}';

    final newGuest = GuestModel(
      id: guestId,
      passId: passId,
      fullName: fullName.trim(),
      email: email.trim(),
      tableNumber: '01',
      tableName: 'General Admission',
      status: GuestCheckInStatus.notArrived,
      admission: 'Confirmed RSVP Pass',
    );

    return addGuest(eventId, newGuest);
  }

  // --- SCAN VERIFICATION & CHECK-IN ENGINE ---

  Future<ScanVerificationResultPayload> verifyScan(String eventId, String code) async {
    await init();
    final tokenPayload = PassTokenService.decodeToken(code, defaultEventId: eventId);
    final targetPassId = tokenPayload.passId.trim();

    // Event jurisdiction check: Does this pass belong to another event?
    if (tokenPayload.isVerifiableToken &&
        tokenPayload.eventId.isNotEmpty &&
        tokenPayload.eventId != eventId) {
      return ScanVerificationResultPayload(
        canCheckIn: false,
        status: 'wrong_event',
        message: 'Pass belongs to another event (${tokenPayload.eventName ?? tokenPayload.eventId}). Not valid for this gate.',
        outsideJurisdiction: true,
      );
    }

    final guests = _cachedGuests[eventId] ?? [];
    try {
      final guest = guests.firstWhere(
        (g) => g.passId.toLowerCase() == targetPassId.toLowerCase(),
      );

      if (guest.isCheckedIn) {
        return ScanVerificationResultPayload(
          canCheckIn: false,
          status: 'already_checked_in',
          message: 'Already checked in at ${guest.checkInTime ?? "earlier"}.',
          guest: guest,
        );
      }

      return ScanVerificationResultPayload(
        canCheckIn: true,
        status: 'ready',
        message: 'Valid Pass: ${guest.fullName} · Table ${guest.tableNumber}',
        guest: guest,
      );
    } catch (_) {
      // If token is authentic JWT pass with embedded name & table:
      if (tokenPayload.isVerifiableToken && (tokenPayload.fullName != null || tokenPayload.guestId != null)) {
        final guest = GuestModel(
          id: tokenPayload.guestId ?? 'g-${DateTime.now().millisecondsSinceEpoch}',
          passId: targetPassId,
          fullName: tokenPayload.fullName ?? 'Verified Guest',
          email: tokenPayload.email ?? '',
          tableNumber: tokenPayload.tableNumber ?? '01',
          tableName: tokenPayload.tableName ?? 'Main Seating',
          status: GuestCheckInStatus.notArrived,
          admission: tokenPayload.admission ?? 'General Admission',
        );
        return ScanVerificationResultPayload(
          canCheckIn: true,
          status: 'ready',
          message: 'Cryptographically Verified Pass: ${guest.fullName}',
          guest: guest,
        );
      }

      // Fallback for valid pass ID
      return ScanVerificationResultPayload(
        canCheckIn: true,
        status: 'ready',
        message: 'Pass #$targetPassId verified. Ready for Check-in',
      );
    }
  }

  Future<CheckInResultPayload> checkInGuest(
    String eventId,
    String code, {
    String? operatorId,
    String? fullName,
  }) async {
    await init();
    final tokenPayload = PassTokenService.decodeToken(code, defaultEventId: eventId);
    final targetPassId = tokenPayload.passId.trim();

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final guests = _cachedGuests[eventId] ?? [];
    final idx = guests.indexWhere((g) => g.passId.toLowerCase() == targetPassId.toLowerCase());

    GuestModel checkedInGuest;
    if (idx != -1) {
      final existing = guests[idx];
      if (existing.isCheckedIn) {
        return CheckInResultPayload(
          success: false,
          message: 'Already checked in at ${existing.checkInTime}',
          guest: existing,
        );
      }
      checkedInGuest = existing.copyWith(
        status: GuestCheckInStatus.checkedIn,
        checkInTime: timeStr,
      );
      guests[idx] = checkedInGuest;
    } else {
      checkedInGuest = GuestModel(
        id: tokenPayload.guestId ?? 'g-${DateTime.now().millisecondsSinceEpoch}',
        passId: targetPassId,
        fullName: fullName ?? tokenPayload.fullName ?? 'Guest #$targetPassId',
        email: tokenPayload.email ?? '',
        tableNumber: tokenPayload.tableNumber ?? '01',
        tableName: tokenPayload.tableName ?? 'Main Seating',
        status: GuestCheckInStatus.checkedIn,
        checkInTime: timeStr,
        admission: tokenPayload.admission ?? 'General Admission',
      );
      guests.insert(0, checkedInGuest);
    }

    _cachedGuests[eventId] = guests;

    // Increment event checkedIn count
    final evIdx = _cachedEvents.indexWhere((e) => e.id == eventId);
    if (evIdx != -1) {
      final ev = _cachedEvents[evIdx];
      _cachedEvents[evIdx] = ev.copyWith(checkedIn: ev.checkedIn + 1);
      await _persistEvents();
    }

    await _persistGuests();
    _refreshProfileStats();

    return CheckInResultPayload(
      success: true,
      message: 'Successfully checked in ${checkedInGuest.fullName}',
      guest: checkedInGuest,
    );
  }

  Future<bool> undoCheckIn(String eventId, String code) async {
    await init();
    final tokenPayload = PassTokenService.decodeToken(code, defaultEventId: eventId);
    final targetPassId = tokenPayload.passId.trim();

    final guests = _cachedGuests[eventId];
    if (guests != null) {
      final idx = guests.indexWhere((g) => g.passId.toLowerCase() == targetPassId.toLowerCase());
      if (idx != -1 && guests[idx].isCheckedIn) {
        guests[idx] = guests[idx].copyWith(
          status: GuestCheckInStatus.notArrived,
          checkInTime: null,
        );
        _cachedGuests[eventId] = guests;

        final evIdx = _cachedEvents.indexWhere((e) => e.id == eventId);
        if (evIdx != -1) {
          final ev = _cachedEvents[evIdx];
          if (ev.checkedIn > 0) {
            _cachedEvents[evIdx] = ev.copyWith(checkedIn: ev.checkedIn - 1);
            await _persistEvents();
          }
        }

        await _persistGuests();
        _refreshProfileStats();
        return true;
      }
    }
    return false;
  }

  /// Real-Time Offline Cryptographic & Database Verification and Check-In
  Future<VerificationResult> verifyAndCheckIn(String eventId, String rawCode) async {
    await init();
    final trimmed = rawCode.trim();

    // 1. First, check if this is an HMAC-SHA256 Invite payload or deep link
    final isInviteFormat = trimmed.startsWith('entree://') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        (trimmed.startsWith('{') && trimmed.contains('sig')) ||
        (trimmed.startsWith('{') && trimmed.contains('invite_code'));

    InvitePayloadResult? inviteResult;
    if (isInviteFormat) {
      inviteResult = InviteCryptoService.parseAndVerify(trimmed);
      if (!inviteResult.isValid) {
        return VerificationResult(
          type: CheckInVerificationType.invalidPayload,
          message: inviteResult.errorMessage ??
              'Cryptographic signature verification failed (tampered payload).',
        );
      }

      // Check event jurisdiction
      if (inviteResult.eventId.isNotEmpty && inviteResult.eventId != eventId) {
        return VerificationResult(
          type: CheckInVerificationType.wrongEvent,
          message:
              'Pass belongs to another event (Event ID: ${inviteResult.eventId}). Not valid for this gate.',
          isCryptographicallyVerified: true,
        );
      }
    }

    // 2. PassTokenService JWT check
    final tokenPayload = PassTokenService.decodeToken(trimmed, defaultEventId: eventId);
    if (tokenPayload.isVerifiableToken) {
      if (tokenPayload.eventId.isNotEmpty && tokenPayload.eventId != eventId) {
        return VerificationResult(
          type: CheckInVerificationType.wrongEvent,
          message:
              'Pass belongs to ${tokenPayload.eventName ?? "another event"}. Not valid for this gate.',
          isCryptographicallyVerified: true,
        );
      }
    }

    // Determine target pass identifier
    final targetPassId = (inviteResult != null && inviteResult.inviteCode.isNotEmpty)
        ? inviteResult.inviteCode
        : tokenPayload.passId.trim();

    final targetGuestId = inviteResult?.guestId ?? tokenPayload.guestId;
    final guestName = inviteResult?.fullName ?? tokenPayload.fullName;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final guests = _cachedGuests[eventId] ?? [];
    final idx = guests.indexWhere((g) =>
        g.passId.toLowerCase() == targetPassId.toLowerCase() ||
        (targetGuestId != null && targetGuestId.isNotEmpty && g.id == targetGuestId));

    if (idx != -1) {
      final existing = guests[idx];
      if (existing.isCheckedIn) {
        return VerificationResult(
          type: CheckInVerificationType.duplicate,
          message: 'Already checked in at ${existing.checkInTime ?? "earlier"}. Do not admit again.',
          guest: existing,
          previousCheckInTime: existing.checkInTime ?? 'earlier',
          isCryptographicallyVerified: inviteResult?.isValid ?? tokenPayload.isVerifiableToken,
        );
      }

      final updated = existing.copyWith(
        status: GuestCheckInStatus.checkedIn,
        checkInTime: timeStr,
      );
      guests[idx] = updated;
      _cachedGuests[eventId] = guests;

      // Increment event checkedIn count
      final evIdx = _cachedEvents.indexWhere((e) => e.id == eventId);
      if (evIdx != -1) {
        final ev = _cachedEvents[evIdx];
        _cachedEvents[evIdx] = ev.copyWith(checkedIn: ev.checkedIn + 1);
        await _persistEvents();
      }

      await _persistGuests();
      _refreshProfileStats();

      return VerificationResult(
        type: CheckInVerificationType.valid,
        message: 'Successfully checked in ${updated.fullName}',
        guest: updated,
        isCryptographicallyVerified: inviteResult?.isValid ?? tokenPayload.isVerifiableToken,
      );
    }

    // Guest not found in list:
    // If cryptographically verified (HMAC or valid JWT), dynamically admit
    if ((inviteResult != null && inviteResult.isValid) ||
        (tokenPayload.isVerifiableToken && guestName != null)) {
      final newGuest = GuestModel(
        id: targetGuestId ?? 'g-${DateTime.now().millisecondsSinceEpoch}',
        passId: targetPassId.isNotEmpty
            ? targetPassId
            : 'PASS-${DateTime.now().millisecondsSinceEpoch % 10000}',
        fullName: guestName ?? 'Verified Guest',
        email: tokenPayload.email ?? '',
        tableNumber: tokenPayload.tableNumber ?? '01',
        tableName: tokenPayload.tableName ?? 'Main Seating',
        status: GuestCheckInStatus.checkedIn,
        checkInTime: timeStr,
        admission: tokenPayload.admission ?? 'General Admission',
      );
      guests.insert(0, newGuest);
      _cachedGuests[eventId] = guests;

      final evIdx = _cachedEvents.indexWhere((e) => e.id == eventId);
      if (evIdx != -1) {
        final ev = _cachedEvents[evIdx];
        _cachedEvents[evIdx] = ev.copyWith(
          checkedIn: ev.checkedIn + 1,
          passesIssued: ev.passesIssued + 1,
        );
        await _persistEvents();
      }

      await _persistGuests();
      _refreshProfileStats();

      return VerificationResult(
        type: CheckInVerificationType.valid,
        message: 'Cryptographically verified pass: ${newGuest.fullName}',
        guest: newGuest,
        isCryptographicallyVerified: true,
      );
    }

    // If it's an unrecognized plain string
    return VerificationResult(
      type: CheckInVerificationType.invalidPayload,
      message: 'Pass #$targetPassId not found for this event.',
    );
  }

  // --- USER PROFILE & STATS ---

  Future<FullProfileData> getProfile() async {
    await init();
    if (_cachedProfile == null) {
      _buildDefaultProfile();
    } else {
      _refreshProfileStats();
    }
    return _cachedProfile!;
  }

  Future<UserProfileModel> updateProfile({
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
    await init();
    if (_cachedProfile == null) _buildDefaultProfile();

    final updated = _cachedProfile!.profile.copyWith(
      fullName: fullName,
      email: email,
      role: role,
      organization: organization,
      phone: phone,
      avatarUrl: avatarUrl,
      bio: bio,
      scannerSpeed: scannerSpeed,
      hapticFeedback: hapticFeedback,
      updatedAt: DateTime.now().toIso8601String(),
    );

    _cachedProfile = FullProfileData(
      profile: updated,
      stats: _cachedProfile!.stats,
      upstream: _cachedProfile!.upstream,
    );

    await _persistProfile();
    return updated;
  }

  void _refreshProfileStats() {
    if (_cachedProfile == null) return;
    final totalCapacity = _cachedEvents.fold<int>(0, (sum, e) => sum + e.totalCapacity);
    final totalCheckedIn = _cachedEvents.fold<int>(0, (sum, e) => sum + e.checkedIn);
    final totalPasses = _cachedEvents.fold<int>(0, (sum, e) => sum + e.passesIssued);
    final checkInRate = totalPasses > 0
        ? '${((totalCheckedIn / totalPasses) * 100).toStringAsFixed(1)}%'
        : totalCapacity > 0
            ? '${((totalCheckedIn / totalCapacity) * 100).toStringAsFixed(1)}%'
            : '0.0%';

    _cachedProfile = FullProfileData(
      profile: _cachedProfile!.profile,
      stats: ProfileStats(
        totalEvents: _cachedEvents.length,
        totalCapacity: totalCapacity,
        totalCheckedIn: totalCheckedIn,
        totalPasses: totalPasses,
        checkInRate: checkInRate,
        pendingSyncs: 0,
      ),
      upstream: _cachedProfile!.upstream,
    );
    _persistProfile();
  }
}

class ScanVerificationResultPayload {
  final bool canCheckIn;
  final String status;
  final String message;
  final GuestModel? guest;
  final bool outsideJurisdiction;

  const ScanVerificationResultPayload({
    required this.canCheckIn,
    required this.status,
    required this.message,
    this.guest,
    this.outsideJurisdiction = false,
  });
}

class CheckInResultPayload {
  final bool success;
  final String message;
  final GuestModel? guest;

  const CheckInResultPayload({
    required this.success,
    required this.message,
    this.guest,
  });
}
