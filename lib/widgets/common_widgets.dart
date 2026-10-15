import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
export 'liquid_glass_button.dart';

class StatusBadge extends StatelessWidget {
  final EventStatus status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, textColor) = switch (status) {
      EventStatus.live => (
          'Live now',
          AppTheme.accentLimeLight,
          AppTheme.accentLimeDark,
        ),
      EventStatus.upcoming => (
          'Upcoming',
          AppTheme.upcomingBg,
          AppTheme.primaryBlack,
        ),
      EventStatus.draft => (
          'Draft',
          AppTheme.draftGrayBg,
          AppTheme.textSecondary,
        ),
      EventStatus.past => (
          'Past',
          AppTheme.draftGrayBg,
          AppTheme.textSecondary,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == EventStatus.live) ...[
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppTheme.accentLimeDark,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class LiveBadge extends StatelessWidget {
  final String text;

  const LiveBadge({super.key, this.text = 'Live'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.accentLime,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

class EventHeaderCompact extends StatelessWidget {
  final EventModel event;

  const EventHeaderCompact({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppTheme.draftGrayBg,
            image: const DecorationImage(
              image: NetworkImage(
                'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=100&h=100&fit=crop',
              ),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${event.shortDate.substring(0, 6)} ${event.date.year} · ${event.venue}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (event.status == EventStatus.live) const LiveBadge(),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtext;
  final Color? color;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.subtext,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor =
        color ?? (isDark ? AppTheme.accentLime : AppTheme.primaryBlack);
    final bgColor = isDark
        ? const Color(0xFF1E212D)
        : (color != null ? color!.withAlpha(20) : const Color(0xFFF3F4F6));
    final textColor = isDark
        ? AppTheme.darkTextPrimary
        : (color != null ? color! : AppTheme.textPrimary);
    final subtextColor = isDark
        ? AppTheme.darkTextSecondary
        : (color != null ? color!.withAlpha(180) : AppTheme.textSecondary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: effectiveColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (subtext != null)
                  Text(
                    subtext!,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtextColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  final String initials;
  final double size;
  final Color? color;

  const AvatarCircle({
    super.key,
    required this.initials,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppTheme.getAvatarColor(initials);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor.withAlpha(30),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          color: bgColor,
        ),
      ),
    );
  }
}

class AvatarStack extends StatelessWidget {
  final List<String>? avatars;
  final double size;
  final double overlap;
  final Color borderColor;
  final int maxAvatars;

  const AvatarStack({
    super.key,
    this.avatars,
    this.size = 22,
    this.overlap = 7,
    this.borderColor = AppTheme.surfaceWhite,
    this.maxAvatars = 3,
  });

  static const List<Color> _iconBgColors = [
    Color(0xFF262938),
    Color(0xFF33384A),
    Color(0xFF41475E),
    Color(0xFF1E212D),
  ];

  @override
  Widget build(BuildContext context) {
    final count = maxAvatars.clamp(1, 4);
    final totalWidth = size + (count - 1) * (size - overlap);

    return SizedBox(
      height: size,
      width: totalWidth,
      child: Stack(
        children: [
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _iconBgColors[i % _iconBgColors.length],
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: size * 0.58,
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CorporateHostBadge extends StatelessWidget {
  final String collection;
  final double iconSize;

  const CorporateHostBadge({
    super.key,
    required this.collection,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlack,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: iconSize * 0.4,
            height: iconSize * 0.4,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            collection,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Dark pill-shaped status indicator (e.g. "Going On", "In 2 days")
class StatusPill extends StatelessWidget {
  final String text;
  final bool isLive;
  final Color? customColor;

  const StatusPill({
    super.key,
    required this.text,
    this.isLive = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = customColor ??
        (isLive ? AppTheme.badgeGoingOn : AppTheme.primaryBlack);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Price badge — clean minimal style
class PriceBadge extends StatelessWidget {
  final String label;
  final bool isPaid;

  const PriceBadge({
    super.key,
    required this.label,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isPaid ? AppTheme.textPrimary : AppTheme.liveGreen,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Dark rounded date badge (e.g. "16 Dec") — pill style matching the reference
class DateCalendarBox extends StatelessWidget {
  final String month;
  final String day;
  final double? width;
  final double? height;

  const DateCalendarBox({
    super.key,
    required this.month,
    required this.day,
    this.width = 54,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                day,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.accentLime,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                month.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accentLime,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadiusGeometry borderRadius;
  final BoxFit fit;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              width: width,
              height: height,
              fit: fit,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: width,
                  height: height,
                  color: AppTheme.draftGrayBg,
                  child: const Center(
                    child: Icon(
                      Icons.event_outlined,
                      color: AppTheme.borderMedium,
                      size: 24,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.event_outlined,
          color: Color(0xFF9CA3AF),
          size: 32,
        ),
      ),
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// GLASSMORPHISM / FROSTED GLASS WIDGETS
// -----------------------------------------------------------------------------

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final BorderRadiusGeometry? customBorderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final double blur;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.customBorderRadius,
    this.padding,
    this.margin,
    this.color,
    this.gradient,
    this.border,
    this.blur = 18,
    this.width,
    this.height,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        customBorderRadius ?? BorderRadius.circular(borderRadius);

    final content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF14161F).withValues(alpha: 0.72),
        gradient: gradient,
        borderRadius: effectiveRadius,
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
      ),
      child: child,
    );

    final frosted = ClipRRect(
      borderRadius: effectiveRadius,
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );

    if (boxShadow != null && boxShadow!.isNotEmpty) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: boxShadow,
        ),
        child: frosted,
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: frosted);
    }

    return frosted;
  }
}

class GlassCircleButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  final double size;
  final double blur;
  final Color? color;
  final Color? borderColor;

  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.blur = 16,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        width: size,
        height: size,
        borderRadius: size / 2,
        blur: blur,
        color: color ?? const Color(0xFF14161F).withValues(alpha: 0.65),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.16),
          width: 1,
        ),
        child: Center(child: icon),
      ),
    );
  }
}

class GlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.blur = 14,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pill = GlassContainer(
      padding: padding,
      borderRadius: 30,
      blur: blur,
      color: color ?? const Color(0xFF12141C).withValues(alpha: 0.60),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.12),
        width: 1,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: pill,
      );
    }
    return pill;
  }
}

// -----------------------------------------------------------------------------
// IOS LIQUID GLASS (Futuristic Apple Multi-layer Specular Refraction Glass)
// -----------------------------------------------------------------------------

class IosLiquidGlass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? tintColor;
  final bool showGlossRefraction;
  final List<BoxShadow>? customShadows;

  const IosLiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 36,
    this.blur = 30,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tintColor,
    this.showGlossRefraction = true,
    this.customShadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // Liquid Specular Bevel Rim — bright crystalline glass perimeter
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.65), // Gleaming top glass edge
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.10), // Subtle base edge
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        boxShadow: customShadows ??
            [
              // Soft ambient glass shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
              // Top light rim bounce
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, -1),
              ),
            ],
      ),
      padding: const EdgeInsets.all(1.2), // Physical glass bevel rim
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1.2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius - 1.2),
              // CRYSTAL-CLEAR TRANSPARENT GLASS (Items behind are visibly blurred & clear)
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (tintColor ?? Colors.white).withValues(alpha: 0.18),
                  (tintColor ?? Colors.white).withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.20),
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
            child: Stack(
              children: [
                if (showGlossRefraction)
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    height: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.65),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

