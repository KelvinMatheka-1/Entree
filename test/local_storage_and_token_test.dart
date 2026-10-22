import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entree_app/models/event_model.dart';
import 'package:entree_app/models/guest_model.dart';
import 'package:entree_app/models/user_profile_model.dart';
import 'package:entree_app/services/local_storage_service.dart';
import 'package:entree_app/services/pass_token_service.dart';
import 'package:entree_app/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.instance.init();
  });

  group('PassTokenService - Verifiable QR & JWT Engine', () {
    final testEvent = EventModel(
      id: 'test-evt-101',
      name: 'Global Tech Keynote 2026',
      venue: 'Innovation Dome',
      venueAddress: '100 Silicon Way',
      collection: 'KEYNOTE',
      description: 'Exclusive keynote session',
      date: DateTime(2026, 10, 24),
      startTime: '18:00',
      endTime: '22:00',
      doorsOpenTime: '17:30',
      tables: 10,
      seatsPerTable: 10,
      totalCapacity: 100,
      passesIssued: 1,
      checkedIn: 0,
      status: EventStatus.upcoming,
      imageUrl: 'assets/images/event_keynote_stage.jpg',
      latitude: 51.5074,
      longitude: -0.1278,
      geoNode: 'London-West',
    );

    final testGuest = const GuestModel(
      id: 'g-999',
      passId: 'HS-7788',
      fullName: 'Sophia Thorne',
      email: 'sophia@example.com',
      tableNumber: '04',
      tableName: 'Maple Tier',
      status: GuestCheckInStatus.notArrived,
      admission: 'VIP Pass',
    );

    test('generates valid verifiable JWT token with signature', () {
      final token = PassTokenService.generatePassToken(
        event: testEvent,
        guest: testGuest,
      );

      expect(token, isNotEmpty);
      expect(token.contains('.'), isTrue);
      expect(token.split('.').length, equals(3));

      final decoded = PassTokenService.decodeToken(token);
      expect(decoded.isVerifiableToken, isTrue);
      expect(decoded.isSignatureValid, isTrue);
      expect(decoded.eventId, equals('test-evt-101'));
      expect(decoded.passId, equals('HS-7788'));
      expect(decoded.fullName, equals('Sophia Thorne'));
      expect(decoded.admission, equals('VIP Pass'));
    });

    test('decodes plain passId correctly without crashing', () {
      const plainId = 'HS-0086';
      final decoded = PassTokenService.decodeToken(plainId, defaultEventId: 'test-evt-101');

      expect(decoded.passId, equals('HS-0086'));
      expect(decoded.eventId, equals('test-evt-101'));
      expect(decoded.isVerifiableToken, isFalse);
    });

    test('detects tampered JWT signature', () {
      final token = PassTokenService.generatePassToken(
        event: testEvent,
        guest: testGuest,
      );
      final parts = token.split('.');
      final tampered = '${parts[0]}.${parts[1]}.invalidsignaturexyz';

      final decoded = PassTokenService.decodeToken(tampered);
      expect(decoded.isSignatureValid, isFalse);
    });
  });

  group('LocalStorageService - Persistent Offline Engine', () {
    test('initializes and seeds mock data when storage is empty', () async {
      final events = await LocalStorageService.instance.getEvents();
      expect(events, isNotEmpty);

      final profile = await LocalStorageService.instance.getProfile();
      expect(profile.profile.fullName, equals('Kelvin Matheka'));
    });

    test('creates event with location coordinates and image path and persists', () async {
      final newEvent = EventModel(
        id: 'evt-custom-001',
        name: 'AI Robotics Expo',
        venue: 'ExCeL London',
        venueAddress: 'Royal Victoria Dock',
        collection: 'ROBOTICS',
        description: 'Next gen humanoid robotics demo',
        date: DateTime(2026, 11, 15),
        startTime: '09:00',
        endTime: '18:00',
        doorsOpenTime: '08:30',
        tables: 20,
        seatsPerTable: 8,
        totalCapacity: 160,
        passesIssued: 0,
        checkedIn: 0,
        status: EventStatus.upcoming,
        imageUrl: 'assets/images/japanese_samurai.jpg',
        latitude: 51.5074,
        longitude: 0.0298,
        geoNode: 'London-Docklands-01',
      );

      final created = await LocalStorageService.instance.createEvent(newEvent);
      expect(created.id, equals('evt-custom-001'));
      expect(created.latitude, equals(51.5074));
      expect(created.imageUrl, equals('assets/images/japanese_samurai.jpg'));

      final fetched = await LocalStorageService.instance.getEvent('evt-custom-001');
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('AI Robotics Expo'));

      // Newly created event MUST have empty guests list, NOT mock data
      final initialGuests = await LocalStorageService.instance.getGuests('evt-custom-001');
      expect(initialGuests, isEmpty);
    });

    test('adds guest, verifies scan, and processes check-in', () async {
      const eventId = 'evt-custom-001';
      final guest = const GuestModel(
        id: 'g-test-1',
        passId: 'VIP-999',
        fullName: 'Marcus Vance',
        email: 'marcus@vance.com',
        tableNumber: '02',
        tableName: 'VIP Terrace',
        status: GuestCheckInStatus.notArrived,
        admission: 'All-Access',
      );

      await LocalStorageService.instance.addGuest(eventId, guest);

      // Verify scan before check-in
      final scanBefore = await LocalStorageService.instance.verifyScan(eventId, 'VIP-999');
      expect(scanBefore.canCheckIn, isTrue);
      expect(scanBefore.status, equals('ready'));

      // Perform check-in
      final checkInResult = await LocalStorageService.instance.checkInGuest(eventId, 'VIP-999');
      expect(checkInResult.success, isTrue);
      expect(checkInResult.guest?.status, equals(GuestCheckInStatus.checkedIn));
      expect(checkInResult.guest?.checkInTime, isNotNull);

      // Verify scan after check-in -> already_checked_in
      final scanAfter = await LocalStorageService.instance.verifyScan(eventId, 'VIP-999');
      expect(scanAfter.canCheckIn, isFalse);
      expect(scanAfter.status, equals('already_checked_in'));

      // Undo check-in
      final undoSuccess = await LocalStorageService.instance.undoCheckIn(eventId, 'VIP-999');
      expect(undoSuccess, isTrue);

      final scanAfterUndo = await LocalStorageService.instance.verifyScan(eventId, 'VIP-999');
      expect(scanAfterUndo.canCheckIn, isTrue);
    });

    test('detects scan of pass belonging to another event', () async {
      final otherEvent = EventModel(
        id: 'other-evt-888',
        name: 'Another Event',
        venue: 'Other Venue',
        venueAddress: 'Other Address',
        collection: 'OTHER',
        description: '',
        date: DateTime.now(),
        startTime: '10:00',
        endTime: '12:00',
        doorsOpenTime: '09:30',
        tables: 5,
        seatsPerTable: 5,
        totalCapacity: 25,
        passesIssued: 1,
        checkedIn: 0,
        status: EventStatus.upcoming,
      );

      final otherGuest = const GuestModel(
        id: 'g-other-1',
        passId: 'PASS-OTHER',
        fullName: 'Wrong Event Attendee',
        email: 'other@test.com',
        tableNumber: '01',
        tableName: 'Main',
        status: GuestCheckInStatus.notArrived,
      );

      final tokenForOtherEvent = PassTokenService.generatePassToken(
        event: otherEvent,
        guest: otherGuest,
      );

      // Scanning this token at 'evt-custom-001' should fail with wrong_event / outside jurisdiction
      final scanResult = await LocalStorageService.instance.verifyScan('evt-custom-001', tokenForOtherEvent);
      expect(scanResult.canCheckIn, isFalse);
      expect(scanResult.status, equals('wrong_event'));
      expect(scanResult.outsideJurisdiction, isTrue);
    });
  });

  group('ApiService - MachineNova Toggle & Fallback', () {
    test('defaults to useMachineNovaLive = false', () {
      expect(ApiService.isMachineNovaLiveEnabled, isFalse);
    });

    test('can toggle useMachineNovaLive at runtime', () async {
      await ApiService.setUseMachineNovaLive(true);
      expect(ApiService.isMachineNovaLiveEnabled, isTrue);

      await ApiService.setUseMachineNovaLive(false);
      expect(ApiService.isMachineNovaLiveEnabled, isFalse);
    });

    test('CRUD operations return identical models in local standalone mode', () async {
      final events = await ApiService.instance.getEvents();
      expect(events, isA<List<EventModel>>());
      expect(events.isNotEmpty, isTrue);

      final profile = await ApiService.instance.getProfile();
      expect(profile, isA<FullProfileData?>());
      expect(profile?.profile.fullName, equals('Kelvin Matheka'));

      final updatedProfile = await ApiService.instance.updateProfile(
        organization: 'Entrée Global Events',
      );
      expect(updatedProfile?.organization, equals('Entrée Global Events'));
    });
  });
}
