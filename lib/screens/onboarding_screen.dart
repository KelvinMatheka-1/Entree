import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _autoNavTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _prewarmLogo();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // GSAP power3.out silky curve
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.40, curve: Cubic(0.16, 1.0, 0.3, 1.0)),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.50, curve: Cubic(0.16, 1.0, 0.3, 1.0)),
      ),
    );

    // Start animation and auto-navigation ONLY after first frame is presented
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animController.forward();
      _autoNavTimer = Timer(const Duration(milliseconds: 3200), () {
        _navigateToHome();
      });
    });
  }

  void _prewarmLogo() {
    // Only precache the official logo so splash animation runs at locked 60/120fps with zero jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(const AssetImage('assets/images/app_logo_cropped.png'), context, onError: (e, s) {});
    });
  }

  @override
  void dispose() {
    _autoNavTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _autoNavTimer?.cancel();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 440),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // GSAP power3.out fluid motion transition
          const gsapCurve = Cubic(0.16, 1.0, 0.3, 1.0);
          final curved = CurvedAnimation(parent: animation, curve: gsapCurve);

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.035),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoCard({double size = 120}) {
    return Image.asset(
      'assets/images/app_logo_cropped.png',
      fit: BoxFit.contain,
      width: size * 1.3,
      height: size * 1.3,
      filterQuality: FilterQuality.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.height < 720;
    final cardWidth = (screenSize.width * 0.56).clamp(210.0, 270.0);
    final cardHeight = cardWidth * 1.28;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black, // Total Black
        body: GestureDetector(
          onTap: _navigateToHome,
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                    children: [
                      // Top spacing
                      SizedBox(height: isCompact ? 12 : 24),

                      // Center 3D Stacked Cards featuring App Icon/Logo with Technical Callouts
                      Expanded(
                        child: Center(
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: SizedBox(
                              width: screenSize.width,
                              height: cardHeight + (isCompact ? 90 : 130),
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // Back Tilted Card (Charcoal Black 3D depth)
                                  Transform.translate(
                                    offset: const Offset(32, -8),
                                    child: Transform.rotate(
                                      angle: 0.12,
                                      child: Container(
                                        width: cardWidth,
                                        height: cardHeight,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF141414), // Charcoal Black
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.12),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.8),
                                              blurRadius: 26,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        padding: EdgeInsets.all(
                                            isCompact ? 22 : 30),
                                        child: Center(
                                          child: Opacity(
                                            opacity: 0.35,
                                            child: _buildLogoCard(
                                                size: isCompact ? 95 : 115),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Front Upright Card displaying official App Icon/Logo
                                  Container(
                                    width: cardWidth,
                                    height: cardHeight,
                                    decoration: BoxDecoration(
                                      color: Colors.black, // Total Black
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: AppTheme.accentLime.withValues(alpha: 0.40),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accentLime.withValues(alpha: 0.15),
                                          blurRadius: 32,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.9),
                                          blurRadius: 36,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 14),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    padding: EdgeInsets.all(
                                        isCompact ? 16 : 22),
                                    child: Center(
                                      child: _buildLogoCard(
                                          size: isCompact ? 115 : 140),
                                    ),
                                  ),

                                  // Technical Callout Lines & Labels Overlay
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _CalloutPainter(
                                        cardWidth: cardWidth,
                                        cardHeight: cardHeight,
                                        isCompact: isCompact,
                                      ),
                                    ),
                                  ),

                                  // Top-Left Annotation Label
                                  Positioned(
                                    left: (screenSize.width / 2) -
                                        (cardWidth / 2) -
                                        24,
                                    top: (cardHeight + (isCompact ? 90 : 130)) /
                                            2 -
                                        (cardHeight / 2) -
                                        (isCompact ? 38 : 50),
                                    child: _buildCalloutLabel(
                                      title: 'Entrée Platform',
                                      subtitle:
                                          'Smart check-in ecosystem',
                                      alignRight: false,
                                    ),
                                  ),

                                  // Top-Right Annotation Label
                                  Positioned(
                                    right: (screenSize.width / 2) -
                                        (cardWidth / 2) -
                                        20,
                                    top: (cardHeight + (isCompact ? 90 : 130)) /
                                            2 -
                                        (cardHeight / 2) -
                                        (isCompact ? 38 : 50),
                                    child: _buildCalloutLabel(
                                      title: 'Signature Accent',
                                      subtitle: 'Live validation indicator',
                                      alignRight: true,
                                    ),
                                  ),

                                  // Bottom-Right Annotation Label
                                  Positioned(
                                    right: (screenSize.width / 2) -
                                        (cardWidth / 2) -
                                        28,
                                    bottom: (cardHeight +
                                                (isCompact ? 90 : 130)) /
                                            2 -
                                        (cardHeight / 2) -
                                        (isCompact ? 34 : 44),
                                    child: _buildCalloutLabel(
                                      title: 'Instant Entry',
                                      subtitle: 'QR passes & attendance',
                                      alignRight: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom Content Section (Brand, Headline, Subtitle, White Button)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          0,
                          28,
                          isCompact ? 16 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // App Brand mark (matches itemry styling in screenshot)
                            Text(
                              'entrée',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: isCompact ? 8 : 12),

                            // Main Headline (Owner perspective)
                            Text(
                              'Host & Manage\nYour Live Events',
                              style: GoogleFonts.inter(
                                fontSize: isCompact ? 27 : 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.15,
                                letterSpacing: -0.8,
                              ),
                            ),
                            SizedBox(height: isCompact ? 8 : 12),

                            // Subtitle (Owner perspective)
                            Text(
                              'Seamlessly organize events, manage guest check-ins, and track live gate attendance with real-time analytics.',
                              style: GoogleFonts.inter(
                                fontSize: isCompact ? 12.5 : 13.5,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.65),
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: isCompact ? 16 : 22),

                            // Auto-load Progress indicator line
                            Container(
                              height: 2.5,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: AnimatedBuilder(
                                animation: _animController,
                                builder: (context, _) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      height: 2.5,
                                      width: screenSize.width *
                                          _animController.value *
                                          0.85,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: isCompact ? 14 : 18),

                            // White Pill Button (Enter Dashboard)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _navigateToHome,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: Text(
                                  'Enter Dashboard',
                                  style: GoogleFonts.inter(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalloutLabel({
    required String title,
    required String subtitle,
    required bool alignRight,
  }) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.9),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 9.0,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the technical bracket callout lines shown in the screenshot
class _CalloutPainter extends CustomPainter {
  final double cardWidth;
  final double cardHeight;
  final bool isCompact;

  _CalloutPainter({
    required this.cardWidth,
    required this.cardHeight,
    required this.isCompact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final cardLeft = cx - (cardWidth / 2);
    final cardRight = cx + (cardWidth / 2);
    final cardTop = cy - (cardHeight / 2);
    final cardBottom = cy + (cardHeight / 2);

    // 1. Top-Left Callout Bracket:
    final tlPath = Path();
    final tlTextBottom = cardTop - (isCompact ? 16 : 22);
    final tlCornerX = cardLeft - 18;
    tlPath.moveTo(tlCornerX, tlTextBottom);
    tlPath.lineTo(tlCornerX, cardTop + 24);
    tlPath.lineTo(cardLeft + 20, cardTop + 24);
    canvas.drawPath(tlPath, paint);

    // 2. Top-Right Callout Bracket:
    final trPath = Path();
    final trCornerX = cardRight + 16;
    trPath.moveTo(trCornerX, tlTextBottom);
    trPath.lineTo(trCornerX, cardTop + 36);
    trPath.lineTo(cardRight - 16, cardTop + 36);
    canvas.drawPath(trPath, paint);

    // 3. Bottom-Right Callout Bracket:
    final brPath = Path();
    final brStartX = cardRight - 36;
    final brCornerY = cardBottom + (isCompact ? 18 : 24);
    final brEndX = cardRight + 22;
    brPath.moveTo(brStartX, cardBottom);
    brPath.lineTo(brStartX, brCornerY);
    brPath.lineTo(brEndX, brCornerY);
    canvas.drawPath(brPath, paint);
  }

  @override
  bool shouldRepaint(covariant _CalloutPainter oldDelegate) {
    return oldDelegate.cardWidth != cardWidth ||
        oldDelegate.cardHeight != cardHeight ||
        oldDelegate.isCompact != isCompact;
  }
}
