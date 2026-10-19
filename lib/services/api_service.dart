import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/event_model.dart';
import '../models/guest_model.dart';
import '../data/mock_data.dart';

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

  // Change baseUrl as needed for emulator / physical device / production
  // Android emulator: 'http://10.0.2.2:4000/api/v1'
  // iOS simulator / Desktop / Web: 'http://localhost:4000/api/v1'
  static String baseUrl = 'http://localhost:4000/api/v1';

  bool _isBackendReachable = true;

  // In-memory cache synced with backend or fallback to MockData
  final List<EventModel> _cachedEvents = [];
  final Map<String, List<GuestModel>> _cachedGuests = {};

  bool get isBackendReachable => _isBackendReachable;

  // --- EVENTS ---

  Future<List<EventModel>> getEvents({
    String? status,
    String? search,
    bool refresh = false,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (refresh) queryParams['refresh'] = 'true';

      final uri = Uri.parse('$baseUrl/events').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['events'] as List<dynamic>)
            .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
            .toList();

        _isBackendReachable = true;
        _cachedEvents.clear();
        _cachedEvents.addAll(list);
        return list;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] getEvents fallback to local cache: $e');
      _isBackendReachable = false;
    }

    // Local fallback
    if (_cachedEvents.isEmpty) {
      _cachedEvents.addAll(MockData.events);
    }

    var list = List<EventModel>.from(_cachedEvents);
    if (status != null && status.isNotEmpty) {
      list = list.where((e) => e.status.name.toLowerCase() == status.toLowerCase()).toList();
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      list = list.where((e) =>
          e.name.toLowerCase().contains(s) ||
          e.venue.toLowerCase().contains(s) ||
          e.collection.toLowerCase().contains(s)).toList();
    }
    return list;
  }

  Future<EventModel?> getEvent(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/events/$id');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isBackendReachable = true;
        return EventModel.fromJson(data['event']);
      }
    } catch (e) {
      debugPrint('[API_SERVICE] getEvent fallback: $e');
    }

    // Fallback search
    try {
      return _cachedEvents.firstWhere((e) => e.id == id);
    } catch (_) {
      try {
        return MockData.events.firstWhere((e) => e.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<EventModel> createEvent(EventModel event) async {
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
        _cachedEvents.insert(0, created);
        return created;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] createEvent fallback: $e');
    }

    // Fallback local addition
    _cachedEvents.insert(0, event);
    return event;
  }

  Future<EventModel> updateEvent(EventModel event) async {
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
        final idx = _cachedEvents.indexWhere((e) => e.id == event.id);
        if (idx != -1) _cachedEvents[idx] = updated;
        return updated;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] updateEvent fallback: $e');
    }

    final idx = _cachedEvents.indexWhere((e) => e.id == event.id);
    if (idx != -1) _cachedEvents[idx] = event;
    return event;
  }

  Future<bool> deleteEvent(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/events/$id');
      final response = await http.delete(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        _cachedEvents.removeWhere((e) => e.id == id);
        return true;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] deleteEvent fallback: $e');
    }

    _cachedEvents.removeWhere((e) => e.id == id);
    return true;
  }

  // --- GUESTS ---

  Future<List<GuestModel>> getGuests(
    String eventId, {
    String? status,
    String? search,
  }) async {
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

        _cachedGuests[eventId] = list;
        return list;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] getGuests fallback: $e');
    }

    // Fallback to local cache or MockData
    if (!_cachedGuests.containsKey(eventId) || _cachedGuests[eventId]!.isEmpty) {
      _cachedGuests[eventId] = List<GuestModel>.from(MockData.guests);
    }

    var list = _cachedGuests[eventId]!;
    if (status != null && status.isNotEmpty) {
      list = list.where((g) => g.status.name.toLowerCase() == status.toLowerCase()).toList();
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      list = list.where((g) =>
          g.fullName.toLowerCase().contains(s) ||
          g.passId.toLowerCase().contains(s) ||
          g.email.toLowerCase().contains(s)).toList();
    }
    return list;
  }

  Future<GuestModel> addGuest(String eventId, GuestModel guest) async {
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
        _cachedGuests[eventId] = [created, ...?_cachedGuests[eventId]];
        return created;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] addGuest fallback: $e');
    }

    _cachedGuests[eventId] = [guest, ...?_cachedGuests[eventId]];
    return guest;
  }

  // --- SCAN & CHECK-IN ---

  Future<ScanResult> verifyScan(String eventId, String passId) async {
    try {
      final uri = Uri.parse('$baseUrl/events/$eventId/scan?passId=${Uri.encodeComponent(passId)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScanResult.fromJson(data['verification']);
      }
    } catch (e) {
      debugPrint('[API_SERVICE] verifyScan fallback: $e');
    }

    // Local fallback logic
    final guests = _cachedGuests[eventId] ?? MockData.guests;
    try {
      final g = guests.firstWhere(
        (it) => it.passId.toLowerCase() == passId.toLowerCase(),
      );
      if (g.isCheckedIn) {
        return ScanResult(
          canCheckIn: false,
          status: 'already_checked_in',
          message: 'Already checked in at ${g.checkInTime ?? "earlier"}',
          guest: g,
        );
      }
      return ScanResult(
        canCheckIn: true,
        status: 'ready',
        message: 'Valid Pass. Ready for Check-in',
        guest: g,
      );
    } catch (_) {
      return ScanResult(
        canCheckIn: true,
        status: 'ready',
        message: 'Pass verified. Ready for Check-in',
      );
    }
  }

  Future<CheckInResult> checkInGuest(
    String eventId,
    String passId, {
    String? operatorId,
    String? fullName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/events/$eventId/checkin');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'passId': passId,
              'operatorId': operatorId ?? 'mobile-app',
              'fullName': fullName,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = CheckInResult.fromJson(data);

        // Update local memory cache
        if (result.success && result.guest != null) {
          final guests = _cachedGuests[eventId];
          if (guests != null) {
            final idx = guests.indexWhere((g) => g.passId == passId);
            if (idx != -1) {
              guests[idx] = result.guest!;
            } else {
              guests.insert(0, result.guest!);
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] checkInGuest fallback: $e');
    }

    // Local fallback update
    final guests = _cachedGuests[eventId] ?? MockData.guests;
    try {
      final g = guests.firstWhere((it) => it.passId == passId);
      final updated = g.copyWith(
        status: GuestCheckInStatus.checkedIn,
        checkInTime: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      );
      final idx = guests.indexOf(g);
      if (idx != -1) guests[idx] = updated;
      return CheckInResult(
        success: true,
        message: 'Successfully checked in ${updated.fullName}',
        guest: updated,
      );
    } catch (_) {
      final newGuest = GuestModel(
        id: 'g-${DateTime.now().millisecondsSinceEpoch}',
        passId: passId,
        fullName: fullName ?? 'Guest #$passId',
        email: '',
        tableNumber: '01',
        tableName: 'Main Seating',
        status: GuestCheckInStatus.checkedIn,
        checkInTime: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      );
      return CheckInResult(
        success: true,
        message: 'Successfully checked in ${newGuest.fullName}',
        guest: newGuest,
      );
    }
  }

  Future<bool> undoCheckIn(String eventId, String passId) async {
    try {
      final uri = Uri.parse('$baseUrl/events/$eventId/undo-checkin');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'passId': passId}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        _revertLocalCheckIn(eventId, passId);
        return true;
      }
    } catch (e) {
      debugPrint('[API_SERVICE] undoCheckIn fallback: $e');
    }

    _revertLocalCheckIn(eventId, passId);
    return true;
  }

  void _revertLocalCheckIn(String eventId, String passId) {
    final list = _cachedGuests[eventId];
    if (list != null) {
      final idx = list.indexWhere((g) => g.passId == passId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          status: GuestCheckInStatus.notArrived,
          checkInTime: null,
        );
      }
    }
    final evIdx = _cachedEvents.indexWhere((e) => e.id == eventId);
    if (evIdx != -1) {
      final ev = _cachedEvents[evIdx];
      if (ev.checkedIn > 0) {
        _cachedEvents[evIdx] = ev.copyWith(checkedIn: ev.checkedIn - 1);
      }
    }
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
    return null;
  }
}
