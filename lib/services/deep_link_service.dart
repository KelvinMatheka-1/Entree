import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import '../models/event_model.dart';
import '../models/guest_model.dart';
import '../data/mock_data.dart';
import 'api_service.dart';
import '../screens/guest_invitation_screen.dart';
import '../screens/event_rsvp_screen.dart';

/// Centralized deep linking service using `app_links`
/// Listens to incoming app links (entree://invite?data=..., https://machinenova.com/invite?data=...,
/// and public RSVP links: https://machinenova.com/event/{id}/rsvp or entree://event/{id}/rsvp)
/// Cryptographically verifies the HMAC-SHA256 signature and navigates to the Guest Ticket Pass View or RSVP flow.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    if (_initialized) return;
    _navigatorKey = navigatorKey;
    _initialized = true;

    // Handle link from cold start
    _handleInitialLink();

    // Handle links while app is in foreground / background
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DEEP_LINK] Incoming stream link: $uri');
        _handleDeepLinkUri(uri);
      },
      onError: (err) {
        debugPrint('[DEEP_LINK] Stream error: $err');
      },
    );
  }

  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DEEP_LINK] Initial cold-start link: $initialUri');
        _handleDeepLinkUri(initialUri);
      }
    } catch (e) {
      debugPrint('[DEEP_LINK] Initial link error: $e');
    }
  }

  String? _extractEventId(Uri uri) {
    if (uri.queryParameters.containsKey('eventId')) {
      return uri.queryParameters['eventId'];
    }
    if (uri.queryParameters.containsKey('id')) {
      return uri.queryParameters['id'];
    }
    final segments = uri.pathSegments;
    final rsvpIdx = segments.indexOf('rsvp');
    if (rsvpIdx > 0) {
      return segments[rsvpIdx - 1];
    }
    final eventIdx = segments.indexOf('event');
    if (eventIdx >= 0 && eventIdx + 1 < segments.length) {
      return segments[eventIdx + 1];
    }
    if (uri.host.isNotEmpty &&
        uri.host != 'machinenova.com' &&
        uri.host != 'invite' &&
        uri.host != 'rsvp' &&
        uri.host != 'event') {
      return uri.host;
    }
    return null;
  }

  Future<void> _handleDeepLinkUri(Uri uri) async {
    final uriStr = uri.toString();
    debugPrint('[DEEP_LINK] Processing deep link: $uriStr');

    // Case A: Public Event RSVP link (e.g., /event/<id>/rsvp or entree://event/<id>/rsvp)
    final isRsvp = uri.path.contains('/rsvp') ||
        uri.path.endsWith('rsvp') ||
        uri.host == 'rsvp' ||
        uri.queryParameters.containsKey('rsvp');

    if (isRsvp) {
      final eventId = _extractEventId(uri);
      if (eventId != null && eventId.isNotEmpty) {
        EventModel? event = await ApiService.instance.getEvent(eventId);
        event ??= MockData.events.firstWhere(
          (e) => e.id == eventId,
          orElse: () => MockData.events.first.copyWith(id: eventId),
        );
        final navState = _navigatorKey?.currentState;
        if (navState != null) {
          navState.push(
            MaterialPageRoute(
              builder: (_) => EventRsvpScreen(event: event!),
            ),
          );
        }
        return;
      }
    }

    // Case B: Signed Ticket / VIP Pass invite link
    final isInviteUri = uri.scheme == 'entree' ||
        uri.path.contains('invite') ||
        uri.queryParameters.containsKey('data') ||
        uriStr.contains('data=');
    if (!isInviteUri) {
      debugPrint('[DEEP_LINK] Ignoring non-invite navigation URI: $uriStr');
      return;
    }

    // 1. Verify HMAC-SHA256 payload cryptographically
    final result = InviteCryptoService.parseAndVerify(uriStr);
    if (!result.isValid) {
      debugPrint('[DEEP_LINK] Signature verification failed: ${result.errorMessage}');
      final context = _navigatorKey?.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Invalid or tampered invite link'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    // 2. Resolve or find matching event
    EventModel? event;
    if (result.eventId.isNotEmpty) {
      event = await ApiService.instance.getEvent(result.eventId);
    }

    event ??= MockData.events.firstWhere(
      (e) => e.id == result.eventId,
      orElse: () => MockData.events.first.copyWith(
        id: result.eventId.isNotEmpty ? result.eventId : 'ev-vip-gathering',
        name: 'The Glasshouse Gala',
      ),
    );

    // 3. Resolve or construct guest model
    final guests = await ApiService.instance.getGuests(event.id);
    GuestModel? guest;
    final found = guests.where((g) =>
        (result.inviteCode.isNotEmpty && g.passId.toLowerCase() == result.inviteCode.toLowerCase()) ||
        (result.guestId.isNotEmpty && g.id == result.guestId));

    if (found.isNotEmpty) {
      guest = found.first;
    } else {
      guest = GuestModel(
        id: result.guestId.isNotEmpty
            ? result.guestId
            : 'g-${DateTime.now().millisecondsSinceEpoch}',
        passId: result.inviteCode.isNotEmpty ? result.inviteCode : 'HS-7720',
        fullName: result.fullName ?? 'Invited Guest',
        email: 'guest@entree.app',
        tableNumber: '01',
        tableName: 'Reserved Seating',
        status: GuestCheckInStatus.notArrived,
        admission: 'VIP Pass',
        guestCount: 1,
      );
      // Auto-register to event repository
      await ApiService.instance.addGuest(event.id, guest);
    }

    // 4. Navigate to dedicated Guest Ticket Pass View
    final navState = _navigatorKey?.currentState;
    if (navState != null) {
      navState.push(
        MaterialPageRoute(
          builder: (_) => GuestInvitationScreen(
            event: event!,
            guest: guest!,
          ),
        ),
      );
    }
  }

  void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
    _initialized = false;
  }
}
