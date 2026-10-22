import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entree_app/services/local_storage_service.dart';
import 'package:entree_app/services/api_service.dart';
import 'package:entree_app/models/guest_model.dart';
import 'package:entree_app/models/event_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.instance.init();
  });

  group('InviteCryptoService - Cryptographic QR & Deep Link Payload Engine', () {
    test('generates valid HMAC-SHA256 signed payload map and JSON matching spec', () {
      final payload = InviteCryptoService.createSignedPayload(
        eventId: 'ev-test-1',
        guestId: 'guest-100',
        inviteCode: 'PASS-777',
        fullName: 'Kelvin Matheka',
      );

      expect(payload['v'], equals(1));
      expect(payload['event_id'], equals('ev-test-1'));
      expect(payload['guest_id'], equals('guest-100'));
      expect(payload['invite_code'], equals('PASS-777'));
      expect(payload['name'], equals('Kelvin Matheka'));
      expect(payload['sig'], isNotNull);
      expect(payload['sig'].toString().length, equals(64)); // SHA-256 hex string

      expect(InviteCryptoService.verifyPayload(payload), isTrue);
    });

    test('detects tampered payload map', () {
      final payload = InviteCryptoService.createSignedPayload(
        eventId: 'ev-test-1',
        guestId: 'guest-100',
        inviteCode: 'PASS-777',
      );

      // Tamper with invite_code
      final tampered = Map<String, dynamic>.from(payload);
      tampered['invite_code'] = 'PASS-FORGED';

      expect(InviteCryptoService.verifyPayload(tampered), isFalse);
    });

    test('generates and parses universal and custom scheme deep links', () {
      final universalLink = InviteCryptoService.generateDeepLink(
        eventId: 'ev-crypto-2',
        guestId: 'guest-200',
        inviteCode: 'HS-8822',
        fullName: 'Amara Vance',
        useUniversalLink: true,
      );

      expect(universalLink.startsWith('https://machinenova.com/invite?data='), isTrue);

      final universalResult = InviteCryptoService.parseAndVerify(universalLink);
      expect(universalResult.isValid, isTrue);
      expect(universalResult.eventId, equals('ev-crypto-2'));
      expect(universalResult.guestId, equals('guest-200'));
      expect(universalResult.inviteCode, equals('HS-8822'));
      expect(universalResult.fullName, equals('Amara Vance'));

      final customSchemeLink = InviteCryptoService.generateDeepLink(
        eventId: 'ev-crypto-2',
        guestId: 'guest-200',
        inviteCode: 'HS-8822',
        useUniversalLink: false,
      );

      expect(customSchemeLink.startsWith('entree://invite?data='), isTrue);
      final customResult = InviteCryptoService.parseAndVerify(customSchemeLink);
      expect(customResult.isValid, isTrue);
      expect(customResult.eventId, equals('ev-crypto-2'));
    });

    test('rejects tampered deep link', () {
      final validLink = InviteCryptoService.generateDeepLink(
        eventId: 'ev-crypto-2',
        guestId: 'guest-200',
        inviteCode: 'HS-8822',
      );

      final tamperedLink = '${validLink}tamperedBytes';
      final result = InviteCryptoService.parseAndVerify(tamperedLink);
      expect(result.isValid, isFalse);
    });
  });

  group('Real-Time QR Scanner Verification Pipeline & 3 UI States', () {
    test('State 1: Valid check-in marks guest checked in and increments counter', () async {
      final event = EventModel(
        id: 'ev-scan-test-1',
        name: 'Gala Night',
        date: DateTime(2026, 10, 24),
        venue: 'Grand Hall',
        venueAddress: '14 Riverside Lane',
        description: 'Annual VIP Gala',
        doorsOpenTime: '18:00',
        startTime: '19:00',
        endTime: '23:00',
        tables: 10,
        seatsPerTable: 8,
        collection: 'Founders',
        checkedIn: 0,
        passesIssued: 1,
        totalCapacity: 80,
        status: EventStatus.live,
      );
      await LocalStorageService.instance.createEvent(event);

      final guest = GuestModel(
        id: 'g-scan-1',
        passId: 'PASS-VALID-01',
        fullName: 'Elena Fisher',
        email: 'elena@example.com',
        tableNumber: '02',
        tableName: 'VIP Section',
        status: GuestCheckInStatus.notArrived,
        admission: 'VIP Pass',
      );
      await LocalStorageService.instance.addGuest(event.id, guest);

      // Generate HMAC-signed deep link
      final deepLink = InviteCryptoService.generateDeepLink(
        eventId: event.id,
        guestId: guest.id,
        inviteCode: guest.passId,
        fullName: guest.fullName,
      );

      // Verify and check in
      final result = await ApiService.instance.verifyAndCheckIn(event.id, deepLink);
      expect(result.isValid, isTrue);
      expect(result.type, equals(CheckInVerificationType.valid));
      expect(result.guest, isNotNull);
      expect(result.guest!.fullName, equals('Elena Fisher'));
      expect(result.guest!.isCheckedIn, isTrue);
      expect(result.guest!.checkInTime, isNotNull);
      expect(result.isCryptographicallyVerified, isTrue);

      // Event checkedIn counter must be incremented
      final updatedEvent = await LocalStorageService.instance.getEvent(event.id);
      expect(updatedEvent?.checkedIn, equals(1));
    });

    test('State 2: Duplicate scan detects already checked in pass with timestamp', () async {
      final event = EventModel(
        id: 'ev-scan-test-2',
        name: 'Exclusive Dinner',
        date: DateTime(2026, 10, 24),
        venue: 'The Atrium',
        venueAddress: '14 Riverside Lane',
        description: 'Dinner banquet',
        doorsOpenTime: '18:00',
        startTime: '19:00',
        endTime: '22:00',
        tables: 5,
        seatsPerTable: 6,
        collection: 'Banquet',
        checkedIn: 1,
        passesIssued: 1,
        totalCapacity: 30,
        status: EventStatus.live,
      );
      await LocalStorageService.instance.createEvent(event);

      final guest = GuestModel(
        id: 'g-scan-2',
        passId: 'PASS-DUP-02',
        fullName: 'Nathan Drake',
        email: 'nathan@example.com',
        tableNumber: '04',
        tableName: 'Explorer Table',
        status: GuestCheckInStatus.checkedIn,
        checkInTime: '18:15',
        admission: 'Standard Pass',
      );
      await LocalStorageService.instance.addGuest(event.id, guest);

      final result = await ApiService.instance.verifyAndCheckIn(event.id, guest.passId);
      expect(result.isDuplicate, isTrue);
      expect(result.type, equals(CheckInVerificationType.duplicate));
      expect(result.previousCheckInTime, equals('18:15'));
      expect(result.message, contains('Already checked in'));
    });

    test('State 3a: Wrong event pass is rejected with jurisdiction error', () async {
      final eventCurrent = EventModel(
        id: 'ev-current',
        name: 'Current Event',
        date: DateTime(2026, 10, 24),
        venue: 'Current Venue',
        venueAddress: '14 Riverside Lane',
        description: 'Current desc',
        doorsOpenTime: '18:00',
        startTime: '19:00',
        endTime: '22:00',
        tables: 5,
        seatsPerTable: 6,
        collection: 'Current',
        checkedIn: 0,
        passesIssued: 1,
        totalCapacity: 30,
        status: EventStatus.live,
      );
      await LocalStorageService.instance.createEvent(eventCurrent);

      // Generate signed pass for another event ID
      final foreignLink = InviteCryptoService.generateDeepLink(
        eventId: 'ev-foreign-event',
        guestId: 'foreign-guest',
        inviteCode: 'PASS-FOREIGN',
      );

      final result = await ApiService.instance.verifyAndCheckIn(eventCurrent.id, foreignLink);
      expect(result.isWrongEvent, isTrue);
      expect(result.type, equals(CheckInVerificationType.wrongEvent));
      expect(result.message, contains('Pass belongs to another event'));
    });

    test('State 3b: Tampered payload is rejected with cryptographic failure message', () async {
      const tamperedJson = '{"v":1,"event_id":"ev-01","guest_id":"g-1","invite_code":"PASS-1","sig":"forged-fake-sig"}';

      final result = await ApiService.instance.verifyAndCheckIn('ev-01', tamperedJson);
      expect(result.isInvalid, isTrue);
      expect(result.type, equals(CheckInVerificationType.invalidPayload));
      expect(result.message, contains('Cryptographic signature verification failed'));
    });
  });
}
