import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'services/local_storage_service.dart';
import 'services/deep_link_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.instance.init();
  await AppTheme.initTheme();

  // Fast memory caching: prevent images from ever de-allocating or re-fetching during sessions
  PaintingBinding.instance.imageCache.maximumSize = 300;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 180 * 1024 * 1024; // 180MB

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );
  runApp(const EntreeApp());
}

class EntreeApp extends StatefulWidget {
  final Widget? home;
  final GlobalKey<NavigatorState>? navigatorKey;

  const EntreeApp({super.key, this.home, this.navigatorKey});

  @override
  State<EntreeApp> createState() => _EntreeAppState();
}

class _EntreeAppState extends State<EntreeApp> {
  late final GlobalKey<NavigatorState> _navKey;

  @override
  void initState() {
    super.initState();
    _navKey = widget.navigatorKey ?? appNavigatorKey;
    DeepLinkService.instance.init(_navKey);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: _navKey,
          title: 'Entrée',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: widget.home ?? const OnboardingScreen(),
        );
      },
    );
  }
}
