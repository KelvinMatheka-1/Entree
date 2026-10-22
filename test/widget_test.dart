import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entree_app/main.dart';
import 'package:entree_app/screens/home_screen.dart';
import 'package:entree_app/theme/app_theme.dart';

final _transparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpRequest();
}

class _MockHttpRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {}

class _MockHttpResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  testWidgets('App renders onboarding splash screen smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EntreeApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Host & Manage'), findsOneWidget);
    expect(find.text('Enter Dashboard'), findsOneWidget);
  });

  testWidgets('Modern home screen displays all core elements',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const EntreeApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify "Host Portal" header
    expect(find.text('Host Portal'), findsOneWidget);

    // Verify "Featured Event" section
    expect(find.text('Featured Event'), findsOneWidget);

    // Verify "Ongoing Splits" section is removed
    expect(find.text('Ongoing Splits'), findsNothing);

    // Verify "Upcoming Events" section
    expect(find.text('Upcoming Events'), findsOneWidget);

    // Verify upcoming events vertical list scrolls within its box
    final upcomingList = find.byType(ListView);
    expect(upcomingList, findsOneWidget);
    await tester.drag(upcomingList, const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(upcomingList, const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify bottom navigation items
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Check-in'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches to Check-in and Profile hubs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EntreeApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Check-in nav item
    await tester.tap(find.text('Check-in'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Entry Check-in'), findsOneWidget);
    expect(find.text('Select Event to Check-in'), findsOneWidget);

    // Tap Profile nav item
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Kelvin Matheka'), findsOneWidget);

    // Tap Events nav item to return
    await tester.tap(find.text('Events'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Featured Event'), findsOneWidget);
  });

  testWidgets('Tapping popular event opens EventDetailsScreen with check-in hub',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const EntreeApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap hero event card
    await tester.tap(find.textContaining('AI Frontier Summit').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Event Details screen opened
    expect(find.text('Event Details'), findsOneWidget);
    expect(find.text('Check-in Management'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Guests'), findsOneWidget);
  });

  testWidgets('Theme verification test', (WidgetTester tester) async {
    await tester.pumpWidget(const EntreeApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.backgroundWhite);
  });

  testWidgets('Verify chat icon removed, PRO removed, and profile contains toggle-only theme mode',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      AppTheme.setThemeMode(ThemeMode.light);
    });

    await tester.pumpWidget(const EntreeApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Verify chat icon is removed from home page
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);

    // 2. Navigate to Profile page
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify PRO badge is removed next to Kelvin Matheka
    expect(find.text('Kelvin Matheka'), findsOneWidget);
    expect(find.text('PRO'), findsNothing);

    // 3. Verify Appearance & Display section and Theme Mode toggle
    expect(find.text('Appearance & Display'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);
    // Verify segmented option cards are removed (toggle only)
    expect(find.text('Light Mode'), findsNothing);

    // 4. Tap toggle switch to enable Dark Mode
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(AppTheme.themeMode.value, ThemeMode.dark);

    // 5. Tap toggle switch again to return to Light Mode
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(AppTheme.themeMode.value, ThemeMode.light);
  });

  testWidgets('Normal calendar displays event icons and tapping opens event details',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const EntreeApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Navigate to Calendar
    await tester.tap(find.text('Calendar'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify calendar header and month title
    expect(find.text('Event Calendar'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);

    // Verify weekday headers
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);

    // Verify event icon exists on calendar grid
    expect(find.byIcon(Icons.smart_toy_rounded), findsWidgets);

    // Tap on date 24 or on the event card to open EventDetailsScreen
    await tester.tap(find.text('AI Frontier Summit: Global Tech Keynote').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Event Details'), findsOneWidget);
    expect(find.text('Check-in Management'), findsOneWidget);
  });

  testWidgets('Responsive layouts render cleanly across small phone, tablet, and desktop',
      (WidgetTester tester) async {
    // 1. Small phone (320 x 580)
    tester.view.physicalSize = const Size(320 * 2.0, 580 * 2.0);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(const EntreeApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Featured Event'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 2. Tablet view (800 x 1200)
    tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Featured Event'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 3. Desktop / wide view (1440 x 900)
    tester.view.physicalSize = const Size(1440 * 1.5, 900 * 1.5);
    tester.view.devicePixelRatio = 1.5;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Featured Event'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Add event page renders correctly in dark mode',
      (WidgetTester tester) async {
    AppTheme.setThemeMode(ThemeMode.dark);
    addTearDown(() {
      AppTheme.setThemeMode(ThemeMode.light);
    });

    await tester.pumpWidget(const EntreeApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap + button to open CreateEventScreen
    final addBtn = find.byIcon(Icons.add_rounded);
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify CreateEventScreen contents
    expect(find.text('Create event'), findsWidgets);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Event image'), findsOneWidget);
    expect(find.text('Upload Event Cover Image'), findsOneWidget);
    expect(find.text('Event name'), findsOneWidget);
    expect(find.text('WHEN & WHERE'), findsOneWidget);
    expect(find.text('SEATING & PASSES'), findsOneWidget);
    expect(find.text('Capacity not configured'), findsOneWidget);

    // Verify no exceptions thrown
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Entry check-in list displays stylish background image cards and opens scanner',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const EntreeApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Check-in nav item
    await tester.tap(find.text('Check-in'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Entry Check-in'), findsOneWidget);
    expect(find.text('Select Event to Check-in'), findsOneWidget);

    // Verify checked-in capsules and event names
    expect(
        find.text('AI Frontier Summit: Global Tech Keynote'), findsOneWidget);
    expect(find.text('52/86 checked in'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);

    // Tap on the event card to open ScanEntryScreen
    await tester.tap(find.text('AI Frontier Summit: Global Tech Keynote'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Entry check-in'), findsOneWidget);
    expect(find.text('Place the QR inside the frame'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
