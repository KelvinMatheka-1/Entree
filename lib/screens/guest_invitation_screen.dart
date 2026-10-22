import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../models/guest_model.dart';
import '../services/api_service.dart';
import '../services/invite_crypto_service.dart';
import '../widgets/common_widgets.dart';
import 'registered_guests_screen.dart';
import 'scan_entry_screen.dart';

class TicketValidationScreen extends StatelessWidget {
  final EventModel event;
  final GuestModel guest;

  const TicketValidationScreen({
    super.key,
    required this.event,
    required this.guest,
  });

  @override
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.surfaceWhite,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        foregroundColor:
            isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ticket validation',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              'Done',
              style: TextStyle(
                color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                // Event header
                EventHeaderCompact(event: event),
                const SizedBox(height: 32),

            // Success indicator
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F7F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 36,
                color: AppTheme.liveGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ticket valid',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Welcome in. Check-in is confirmed.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 28),

            // Guest card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GUEST',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              guest.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${guest.passId} · ${guest.admission} · ${guest.guestCount} guest',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.upcomingPurpleBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TABLE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryPurple,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              guest.tableNumber,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                            Text(
                              guest.tableName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppTheme.liveGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Checked in at ${guest.checkInTime ?? "18:42"}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.liveGreen,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Entry QR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScanEntryScreen(event: event),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan next pass'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisteredGuestsScreen(event: event),
                    ),
                  );
                },
                icon: const Icon(Icons.person_search_outlined, size: 18),
                label: const Text('Manual check-in another guest'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${event.checkedIn} of ${event.passesIssued} checked in · Verify identity for manual entry',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),

            // Other validation outcomes
            const Align(
              alignment: Alignment.centerLeft,
              child: SectionLabel(text: 'OTHER VALIDATION OUTCOMES · EXAMPLES'),
            ),
            const SizedBox(height: 8),

            // Outcome 1: Already used (Amber tint matching Figma)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, size: 18, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Already used · do not admit again',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${guest.fullName} · ${guest.passId} · checked in at ${guest.checkInTime ?? "18:42"}. This pass has already been used.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB45309),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegisteredGuestsScreen(event: event),
                        ),
                      );
                    },
                    child: const Text(
                      'View check-in record →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Outcome 2: Wrong event (Red tint matching Figma)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Wrong event · entry not recorded',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "FT-0028 belongs to Founders' Table, 30 Oct. It is not valid for ${event.name}.",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScanEntryScreen(event: event),
                        ),
                      );
                    },
                    child: const Text(
                      'Choose the correct event or scan again →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sample validation states · no real ticket has been issued',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  ),
);
  }
}

// Guest Invitation / Pass Preview Screen
// Guest Invitation / Pass Preview Screen
class GuestInvitationScreen extends StatefulWidget {
  final EventModel event;
  final GuestModel guest;

  const GuestInvitationScreen({
    super.key,
    required this.event,
    required this.guest,
  });

  @override
  State<GuestInvitationScreen> createState() => _GuestInvitationScreenState();
}

class _GuestInvitationScreenState extends State<GuestInvitationScreen> {
  final GlobalKey _passCardKey = GlobalKey();
  bool _isSharing = false;

  String get _deepLink => InviteCryptoService.generateDeepLink(
        eventId: widget.event.id,
        guestId: widget.guest.id,
        inviteCode: widget.guest.passId,
        fullName: widget.guest.fullName,
      );

  Future<void> _sharePassCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary =
          _passCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Pass card boundary not found in tree');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode raster pass image');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final safePassId =
          widget.guest.passId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${tempDir.path}/entree_pass_$safePassId.png');
      await file.writeAsBytes(pngBytes);

      final shareText = "🎟️ You're invited to ${widget.event.name}!\n\n"
          "📅 ${widget.event.dayString} ${widget.event.monthShort} ${widget.event.date.year} · ${widget.event.startTime}–${widget.event.endTime}\n"
          "📍 ${widget.event.venue}${widget.event.venueAddress.isNotEmpty ? " · ${widget.event.venueAddress}" : ""}\n"
          "👤 Guest: ${widget.guest.fullName} (Table ${widget.guest.tableNumber})\n\n"
          "👉 Open your personal ticket pass:\n$_deepLink\n\n"
          "Show this QR pass at the entrance gate for quick check-in.";

      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        subject: "Your Ticket to ${widget.event.name} - ${widget.guest.fullName}",
      );
    } catch (e) {
      debugPrint('[SHARE_PASS] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share pass: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _deepLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard!'),
        backgroundColor: AppTheme.primaryPurple,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final guest = widget.guest;
    final canPop = Navigator.canPop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deepLink = _deepLink;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFEDE9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  // Top Bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (canPop)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.darkSurface
                                          : Colors.white.withAlpha(200),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.arrow_back,
                                      size: 18,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            Text(
                              'Digital Entry Pass',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 15,
                              color: isDark
                                  ? AppTheme.accentLime
                                  : AppTheme.primaryPurple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Verified Pass',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.accentLime
                                    : AppTheme.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // RepaintBoundary wrapping the visual Digital Ticket Pass Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: RepaintBoundary(
                      key: _passCardKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkCardBorder
                                : AppTheme.borderLight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 80 : 18),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cover banner
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(19),
                              ),
                              child: SafeNetworkImage(
                                imageUrl: event.imageUrl,
                                width: double.infinity,
                                height: 160,
                                fit: BoxFit.cover,
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        "YOU'RE INVITED",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppTheme.accentLime
                                              : AppTheme.primaryPurple,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.black
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.white24
                                                    : AppTheme.borderLight,
                                                width: 1,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(2.5),
                                                child: Image.asset(
                                                  isDark
                                                      ? 'assets/images/app_logo_cropped.png'
                                                      : 'assets/images/app_logo_light_cropped.png',
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'entrée',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? AppTheme.darkTextPrimary
                                                  : AppTheme.textPrimary,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    event.name,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${event.dayString} ${event.monthShort} ${event.date.year} · ${event.startTime}–${event.endTime}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${event.venue}${event.venueAddress.isNotEmpty ? " · ${event.venueAddress}" : ""}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Cryptographic QR Code Container
                                  Center(
                                    child: Container(
                                      width: 220,
                                      height: 220,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: AppTheme.borderLight,
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(12),
                                            blurRadius: 18,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: QrImageView(
                                        data: deepLink,
                                        version: QrVersions.auto,
                                        size: 192,
                                        backgroundColor: Colors.white,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: Color(0xFF1E1B4B),
                                        ),
                                        dataModuleStyle:
                                            const QrDataModuleStyle(
                                          dataModuleShape:
                                              QrDataModuleShape.square,
                                          color: Color(0xFF1E1B4B),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),


                                  Center(
                                    child: Text(
                                      'Pass ID: ${guest.passId} · ${guest.fullName}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 16),

                                  // Guest & Table Information
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'GUEST',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? AppTheme.darkTextTertiary
                                                    : AppTheme.textTertiary,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              guest.fullName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? AppTheme.darkTextPrimary
                                                    : AppTheme.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              '${guest.passId} · ${guest.admission} · ${guest.guestCount} guest',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppTheme.darkTextSecondary
                                                    : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.upcomingPurpleBg,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              'TABLE',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primaryPurple,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            Text(
                                              guest.tableNumber,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.primaryPurple,
                                              ),
                                            ),
                                            Text(
                                              guest.tableName,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.primaryPurple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? AppTheme.darkCardBorder
                                            : AppTheme.borderLight,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: Image.asset(
                                              isDark
                                                  ? 'assets/images/app_logo_cropped.png'
                                                  : 'assets/images/app_logo_light_cropped.png',
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Official Digital Entry Pass · Powered by entrée',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppTheme.darkTextSecondary
                                                : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
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
                  const SizedBox(height: 16),

                  // Info instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 15,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Doors open at ${event.doorsOpenTime}. Have your personal pass ready at entry; the host will guide you to Table ${guest.tableNumber}.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Share Actions: PNG capture + Deep link sharing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSharing ? null : _sharePassCard,
                            icon: _isSharing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.share_outlined, size: 18),
                            label: Text(
                              _isSharing
                                  ? 'Generating pass image...'
                                  : 'Send & Share Ticket Pass',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppTheme.accentLime
                                  : AppTheme.primaryPurple,
                              foregroundColor:
                                  isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Deep link preview box
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      onTap: _copyLink,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurface
                              : Colors.white.withAlpha(180),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkCardBorder
                                : AppTheme.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: AppTheme.primaryPurple,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                deepLink,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Tap to copy',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer
                  Text(
                    'Hosted by The Glasshouse Collection · Powered by entrée',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
