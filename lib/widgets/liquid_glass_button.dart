import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A fully responsive, hyper-realistic Liquid Glass button widget
/// translated directly from the provided HTML/CSS specification.
/// Features specular edge bevel highlights, 45-degree angle refraction sheen,
/// backdrop blur, smooth hover/press physics, and the custom vector chevron icon.
class LiquidGlassButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final double? width;
  final double height;
  final bool isFullWidth;
  final bool darkStyle;
  final double fontSize;
  final Widget? trailingIcon;
  final Color? textColor;
  final Color? iconBackgroundColor;

  const LiquidGlassButton({
    super.key,
    this.text = 'Get started',
    this.onTap,
    this.width,
    this.height = 75.0,
    this.isFullWidth = false,
    this.darkStyle = false,
    this.fontSize = 24.0,
    this.trailingIcon,
    this.textColor,
    this.iconBackgroundColor,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;

    final effectiveHeight = isCompact ? (widget.height * 0.88).clamp(56.0, 75.0) : widget.height;
    final effectiveFontSize = isCompact ? (widget.fontSize * 0.82).clamp(16.0, 22.0) : widget.fontSize;
    final effectiveIconSize = isCompact ? 34.0 : 40.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: (_isHovered && !_isPressed) ? const Offset(0, -0.04) : Offset.zero,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: widget.isFullWidth ? double.infinity : (widget.width ?? 260.0),
              height: effectiveHeight,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // 1. Ambient Drop Shadow (.box in CSS: 0 4px 8px rgba(0, 0, 0, 0.2))
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: widget.darkStyle ? 0.45 : 0.20),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: widget.darkStyle ? 0.35 : 0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Underlying blurred depth layer (box:before in CSS)
                  Positioned(
                    top: effectiveHeight * 0.35,
                    left: 8,
                    right: 8,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: widget.darkStyle ? 0.4 : 0.25),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),

                  // 3. Liquid Glass Backdrop Filter & Base Body
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9999),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9999),
                          color: widget.darkStyle
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF7F7FA).withValues(alpha: 0.50),
                          border: Border.all(
                            color: widget.darkStyle
                                ? Colors.white.withValues(alpha: 0.18)
                                : const Color(0x22333333),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 4. Inset Specular Bevel Reflection (Translating CSS multiple inset shadows)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _LiquidGlassInsetSpecularPainter(
                          borderRadius: 9999,
                          isDark: widget.darkStyle,
                        ),
                      ),
                    ),
                  ),

                  // 5. 45-Degree Angle Specular Sheen (box:after in CSS)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9999),
                          gradient: LinearGradient(
                            begin: const Alignment(-1.0, -1.0),
                            end: const Alignment(1.0, 1.0),
                            stops: const [0.0, 0.15, 0.85, 1.0],
                            colors: [
                              Colors.white.withValues(alpha: widget.darkStyle ? 0.55 : 0.80),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.white.withValues(alpha: widget.darkStyle ? 0.55 : 0.80),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 6. Circle Overlay Ring (.circle-overlay in CSS)
                  Positioned(
                    top: 4,
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: widget.darkStyle ? 0.30 : 0.45),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 7. Interactive Content: Label & Circular Action Icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Text Label
                        Flexible(
                          child: Text(
                            widget.text,
                            style: TextStyle(
                              fontSize: effectiveFontSize,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: widget.textColor ??
                                  (widget.darkStyle
                                      ? (_isPressed ? Colors.white : const Color(0xFFF1F1F4))
                                      : (_isPressed ? Colors.black : const Color(0xFF3E3E3E))),
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: widget.darkStyle ? 0.4 : 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Animated Circular Button Icon (.btn-icon in CSS)
                        AnimatedScale(
                          scale: _isHovered && !_isPressed ? 1.10 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            width: effectiveIconSize,
                            height: effectiveIconSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.iconBackgroundColor ??
                                  (widget.darkStyle
                                      ? const Color(0xFF222228)
                                      : const Color(0xFF3E3E3E)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: widget.trailingIcon ??
                                  CustomPaint(
                                    size: Size(effectiveIconSize * 0.42, effectiveIconSize * 0.42),
                                    painter: _LiquidChevronArrowPainter(
                                      color: const Color(0xFFF5F5F5),
                                    ),
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
}

/// A responsive container encapsulating the liquid glass properties of `.box`
/// from the CSS specification, perfect for floating menus, navigation bars, and headers.
class LiquidGlassMenuBox extends StatelessWidget {
  final Widget child;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isDark;
  final double blur;

  const LiquidGlassMenuBox({
    super.key,
    required this.child,
    this.width,
    this.height = 68.0,
    this.borderRadius = 9999.0,
    this.padding,
    this.margin,
    this.isDark = true,
    this.blur = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Drop Shadow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.20),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          // 2. Backdrop Blur & Frosted Base
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: isDark
                      ? const Color(0x9016161B)
                      : const Color(0x75F7F7FA),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : const Color(0x22333333),
                    width: 1.0,
                  ),
                ),
              ),
            ),
          ),

          // 3. Inset Specular Bevel Highlights
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LiquidGlassInsetSpecularPainter(
                  borderRadius: borderRadius,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // 4. 45-degree angle linear-gradient sheen
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: LinearGradient(
                    begin: const Alignment(-1.0, -1.0),
                    end: const Alignment(1.0, 1.0),
                    stops: const [0.0, 0.15, 0.85, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.40 : 0.70),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withValues(alpha: isDark ? 0.40 : 0.70),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Circle-overlay inner border
          Positioned(
            top: 3,
            left: 3,
            right: 3,
            bottom: 3,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.35),
                    width: 1.0,
                  ),
                ),
              ),
            ),
          ),

          // 6. Child Content
          Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 10),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the inner specular bevel highlights matching CSS inset box-shadows:
/// inset 2px -2px 1px -1px rgba(255, 255, 255, 0.9),
/// inset -2px 2px 1px -1px rgba(255, 255, 255, 0.9),
/// inset 6px -6px 1px -6px rgba(255, 255, 255, 0.55)...
class _LiquidGlassInsetSpecularPainter extends CustomPainter {
  final double borderRadius;
  final bool isDark;

  _LiquidGlassInsetSpecularPainter({
    required this.borderRadius,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = borderRadius > size.height / 2 ? size.height / 2 : borderRadius;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Top-Left inner specular edge (White highlight)
    final topSpecularPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = ui.Gradient.linear(
        Offset(rect.left, rect.top),
        Offset(rect.right, rect.bottom),
        [
          Colors.white.withValues(alpha: isDark ? 0.65 : 0.90),
          Colors.white.withValues(alpha: isDark ? 0.30 : 0.55),
          Colors.transparent,
          Colors.white.withValues(alpha: isDark ? 0.25 : 0.40),
        ],
        [0.0, 0.25, 0.70, 1.0],
      );

    canvas.drawRRect(rrect.deflate(0.7), topSpecularPaint);

    // Bottom dark ambient inset contour
    final darkInsetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = ui.Gradient.linear(
        Offset(rect.left, rect.top),
        Offset(rect.left, rect.bottom),
        [
          Colors.transparent,
          Colors.black.withValues(alpha: isDark ? 0.40 : 0.15),
        ],
        [0.4, 1.0],
      );

    canvas.drawRRect(rrect.deflate(1.2), darkInsetPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassInsetSpecularPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius || oldDelegate.isDark != isDark;
  }
}

/// Paints the precise SVG path from the HTML snippet:
/// d="M779.180132 473.232045 322.354755 16.406668c-21.413706-21.413706-56.121182-21.413706-77.534887 0-21.413706 21.413706-21.413706 56.122205 0 77.534887l418.057421 418.057421L244.819868 930.057421c-21.413706 21.413706-21.413706 56.122205 0 77.534887 10.706853 10.706853 24.759917 16.059767 38.767955 16.059767s28.061103-5.353938 38.767955-16.059767L779.180132 550.767955C800.593837 529.35425 800.593837 494.64575 779.180132 473.232045z"
class _LiquidChevronArrowPainter extends CustomPainter {
  final Color color;

  _LiquidChevronArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Scale from 1024x1024 viewBox to local size
    final scale = size.width / 1024.0;
    canvas.save();
    canvas.scale(scale, scale);

    final path = Path();
    path.moveTo(779.18, 473.23);
    path.lineTo(322.35, 16.41);
    path.cubicTo(300.94, -5.00, 266.23, -5.00, 244.82, 16.41);
    path.cubicTo(223.41, 37.82, 223.41, 72.53, 244.82, 93.94);
    path.lineTo(662.88, 512.00);
    path.lineTo(244.82, 930.06);
    path.cubicTo(223.41, 951.47, 223.41, 986.18, 244.82, 1007.59);
    path.cubicTo(255.53, 1018.30, 269.58, 1023.65, 283.59, 1023.65);
    path.cubicTo(297.60, 1023.65, 311.65, 1018.30, 322.35, 1007.59);
    path.lineTo(779.18, 550.77);
    path.cubicTo(800.59, 529.35, 800.59, 494.65, 779.18, 473.23);
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidChevronArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
