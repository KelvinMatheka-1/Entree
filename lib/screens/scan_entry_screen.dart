import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../models/guest_model.dart';
import '../data/mock_data.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'guest_invitation_screen.dart';
import 'registered_guests_screen.dart';

class ScanEntryScreen extends StatefulWidget {
  final EventModel event;

  const ScanEntryScreen({super.key, required this.event});

  @override
  State<ScanEntryScreen> createState() => _ScanEntryScreenState();
}

class _ScanEntryScreenState extends State<ScanEntryScreen> {
  MobileScannerController? _scannerController;
  late EventModel _currentEvent;
  bool _flashOn = false;
  bool _isProcessingScan = false;

  bool get _supportsMobileScanner =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _refreshEvent();
    if (_supportsMobileScanner) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    }
  }

  Future<void> _refreshEvent() async {
    try {
      final latest = await ApiService.instance.getEvent(_currentEvent.id);
      if (latest != null && mounted) {
        setState(() {
          _currentEvent = latest;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_supportsMobileScanner) {
      _scannerController?.dispose();
    }
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessingScan) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _isProcessingScan = true;
        _processScannedValue(rawValue.trim());
        break;
      }
    }
  }

  Future<void> _processScannedValue(String code) async {
    // 1. Verify offline signature first & check-in against repository
    final result = await ApiService.instance.verifyAndCheckIn(_currentEvent.id, code);

    // 2. Dynamic Haptic feedback
    if (result.isValid) {
      HapticFeedback.mediumImpact();
    } else if (result.isDuplicate) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.vibrate();
    }

    if (!mounted) return;

    if (result.isValid) {
      await _refreshEvent();
    }

    // 3. Display dedicated styled UI state
    await _showVerificationModal(result, code);

    if (mounted) {
      await _refreshEvent();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isProcessingScan = false;
          });
        }
      });
    }
  }

  Future<void> _showVerificationModal(VerificationResult result, String code) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final guest = result.guest;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 90 : 30),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull bar indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              if (result.isValid) ...[
                // --- 1. VALID CHECK-IN STATE ---
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F7F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 38,
                    color: AppTheme.liveGreen,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Valid Check-In',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pass verified. Guest admitted.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                // Guest Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AvatarCircle(
                            initials: guest?.initials ?? 'G',
                            size: 44,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  guest?.fullName ?? 'Verified Attendee',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${guest?.passId ?? code} · ${guest?.admission ?? "General Admission"}',
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.upcomingPurpleBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'TABLE',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryPurple,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  guest?.tableNumber ?? '01',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: AppTheme.liveGreen,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Checked in at ${guest?.checkInTime ?? "Just now"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.liveGreen,
                                ),
                              ),
                            ],
                          ),
                          if (result.isCryptographicallyVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_outlined, size: 11, color: AppTheme.liveGreen),
                                  SizedBox(width: 4),
                                  Text(
                                    'HMAC Verified',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.liveGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Primary button: Scan next pass
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan next pass'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (guest != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TicketValidationScreen(
                              event: _currentEvent,
                              guest: guest,
                            ),
                          ),
                        ).then((_) => _refreshEvent());
                      },
                      child: const Text('View full pass details'),
                    ),
                  ),
                ],
              ] else if (result.isDuplicate) ...[
                // --- 2. DUPLICATE SCAN STATE (AMBER) ---
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 38,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Duplicate Scan · Already Used',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Do not admit again. This pass has already entered.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history_toggle_off_rounded,
                              size: 16, color: Color(0xFF92400E)),
                          const SizedBox(width: 6),
                          Text(
                            'Previous Check-in: ${result.previousCheckInTime ?? result.guest?.checkInTime ?? "Earlier today"}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${guest?.fullName ?? "Attendee"} (${guest?.passId ?? code}) was previously recorded at this gate. Verify attendee photo ID before allowing re-entry.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFB45309),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB45309),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Acknowledge & Scan Next',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ] else ...[
                // --- 3. INVALID / TAMPERED / WRONG EVENT STATE (CRIMSON) ---
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.cancel_outlined,
                    size: 38,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  result.isWrongEvent
                      ? 'Wrong Event · Entry Denied'
                      : 'Scan Rejected · Invalid Pass',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.red.shade300 : const Color(0xFF991B1B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  result.isWrongEvent
                      ? 'Pass does not match this event.'
                      : 'Signature verification failed or payload altered.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              result.isWrongEvent ? 'Jurisdiction Mismatch' : 'Tampered / Unrecognized Credential',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.message,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFB91C1C),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Dismiss & Try Again',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _onSimulateScan() async {
    if (_isProcessingScan) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Simulate Scan Verification',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a scan state to test the real-time verification pipeline:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F7F0),
                    child: Icon(Icons.check, color: AppTheme.liveGreen),
                  ),
                  title: const Text('1. Valid Attendee Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Cryptographically signed pass confirms admission'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _simulateValidScan();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
                  ),
                  title: const Text('2. Duplicate Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pass already admitted with prior timestamp'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _simulateDuplicateScan();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
                  ),
                  title: const Text('3. Tampered / Corrupt Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('HMAC-SHA256 signature verification fails'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _simulateTamperedScan();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.wrong_location_outlined, color: Color(0xFFDC2626)),
                  ),
                  title: const Text('4. Wrong Event Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pass belongs to another event jurisdiction'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _simulateWrongEventScan();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _simulateValidScan() async {
    _isProcessingScan = true;
    try {
      final guests = await ApiService.instance.getGuests(_currentEvent.id);
      final candidate = guests.firstWhere(
        (g) => !g.isCheckedIn,
        orElse: () => guests.isNotEmpty ? guests.first : MockData.guests.first,
      );
      // Generate genuine signed invite deep link for candidate
      final deepLink = InviteCryptoService.generateDeepLink(
        eventId: _currentEvent.id,
        guestId: candidate.id,
        inviteCode: candidate.passId,
        fullName: candidate.fullName,
      );
      await _processScannedValue(deepLink);
    } catch (_) {
      if (mounted) setState(() => _isProcessingScan = false);
    }
  }

  Future<void> _simulateDuplicateScan() async {
    _isProcessingScan = true;
    try {
      final guests = await ApiService.instance.getGuests(_currentEvent.id);
      GuestModel candidate = guests.firstWhere(
        (g) => g.isCheckedIn,
        orElse: () => guests.first,
      );
      if (!candidate.isCheckedIn) {
        // Check them in first so we can test duplicate scan
        await ApiService.instance.checkInGuest(_currentEvent.id, candidate.passId);
        final refreshed = await ApiService.instance.getGuests(_currentEvent.id);
        candidate = refreshed.firstWhere((g) => g.id == candidate.id);
      }
      await _processScannedValue(candidate.passId);
    } catch (_) {
      if (mounted) setState(() => _isProcessingScan = false);
    }
  }

  Future<void> _simulateTamperedScan() async {
    _isProcessingScan = true;
    // Construct an invite payload with a falsified HMAC signature
    const tamperedPayload = '{"v":1,"event_id":"ev-01","guest_id":"g-test","invite_code":"PASS-999","sig":"forged-fake-signature"}';
    await _processScannedValue(tamperedPayload);
  }

  Future<void> _simulateWrongEventScan() async {
    _isProcessingScan = true;
    // Generate authentic HMAC signature but for a different event
    final wrongEventDeepLink = InviteCryptoService.generateDeepLink(
      eventId: 'different-foreign-event-999',
      guestId: 'guest-foreign-1',
      inviteCode: 'FOREIGN-PASS-88',
      fullName: 'Foreign Attendee',
    );
    await _processScannedValue(wrongEventDeepLink);
  }

  @override
  Widget build(BuildContext context) {
    final event = _currentEvent;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Entry check-in',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final previewHeight =
                (constraints.maxHeight * 0.44).clamp(240.0, 380.0);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Checking-in event card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkCardBorder
                                : AppTheme.borderLight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.25 : 0.03,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SafeNetworkImage(
                              imageUrl: event.imageUrl,
                              width: 44,
                              height: 44,
                              borderRadius: BorderRadius.circular(10),
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CHECKING IN FOR',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppTheme.darkTextTertiary
                                          : AppTheme.textTertiary,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${event.dayString} ${event.monthShort} ${event.date.year} · ${event.venue}',
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
                            Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : AppTheme.textTertiary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Live Camera viewfinder container with reticle & controls
                      Container(
                        height: previewHeight,
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkCardBorder
                                : AppTheme.borderMedium,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Live MobileScanner Camera
                            Positioned.fill(
                              child: _supportsMobileScanner && _scannerController != null
                                  ? MobileScanner(
                                      controller: _scannerController!,
                                      fit: BoxFit.cover,
                                      onDetect: _onDetect,
                                      errorBuilder: (context, error) {
                                        return _buildScannerPlaceholder(error.errorCode.name);
                                      },
                                    )
                                  : _buildScannerPlaceholder('Simulator mode active'),
                            ),

                            // Reticle Frame
                            CustomPaint(
                              size: Size(
                                (previewHeight * 0.72).clamp(160.0, 220.0),
                                (previewHeight * 0.72).clamp(160.0, 220.0),
                              ),
                              painter: _ScanReticlePainter(),
                            ),

                            // Camera hint badge at top
                            Positioned(
                              top: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(160),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.center_focus_strong,
                                      size: 13,
                                      color: AppTheme.accentLime,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Align QR code within reticle',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Camera controls (Flashlight & Switch Camera)
                            Positioned(
                              bottom: 14,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildCameraControl(
                                    icon: _flashOn
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    onTap: () async {
                                      if (_supportsMobileScanner && _scannerController != null) {
                                        await _scannerController!.toggleTorch();
                                      }
                                      setState(() {
                                        _flashOn = !_flashOn;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 24),
                                  _buildCameraControl(
                                    icon: Icons.flip_camera_ios_outlined,
                                    onTap: () async {
                                      if (_supportsMobileScanner && _scannerController != null) {
                                        await _scannerController!.switchCamera();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Instruction text
                      Text(
                        'Place the QR inside the frame',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Only ${event.name} passes are accepted.\nA valid scan confirms check-in automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Manual Check-in Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RegisteredGuestsScreen(event: _currentEvent),
                              ),
                            );
                            _refreshEvent();
                          },
                          icon: const Icon(Icons.person_search_outlined,
                              size: 20),
                          label: const Text(
                            'Manual check-in',
                            style: TextStyle(
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
                      const SizedBox(height: 14),

                      // Status line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            event.isCheckInFull
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline,
                            size: 15,
                            color: event.isCheckInFull
                                ? const Color(0xFF10B981)
                                : (isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 6),
                          if (event.isCheckInFull) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'FULL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          Text(
                            event.isCheckInFull
                                ? '${event.checkedIn}/${event.passesIssued} Checked In · Full House'
                                : '${event.checkedIn} checked in · ${event.expected} still expected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: event.isCheckInFull
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: event.isCheckInFull
                                  ? const Color(0xFF10B981)
                                  : (isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCameraControl({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(140),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildScannerPlaceholder(String message) {
    return Container(
      color: const Color(0xFF121212),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white54,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            'Camera preview unavailable\n($message)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _onSimulateScan,
            icon: const Icon(
              Icons.qr_code_scanner,
              size: 16,
              color: AppTheme.accentLime,
            ),
            label: const Text(
              'Tap to simulate scan',
              style: TextStyle(
                color: AppTheme.accentLime,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFA5B4FC)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cornerLength = 36.0;
    const radius = 16.0;

    // Top-left
    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..arcToPoint(
        const Offset(radius, 0),
        radius: const Radius.circular(radius),
      )
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // Top-right
    final pathTR = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width, radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(pathTR, paint);

    // Bottom-left
    final pathBL = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - radius)
      ..arcToPoint(
        Offset(radius, size.height),
        radius: const Radius.circular(radius),
      )
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(pathBL, paint);

    // Bottom-right
    final pathBR = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - radius, size.height)
      ..arcToPoint(
        Offset(size.width, size.height - radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(pathBR, paint);

    // Center horizontal scanning line
    final linePaint = Paint()
      ..color = const Color(0xFFA5B4FC).withAlpha(220)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(16, size.height / 2),
      Offset(size.width - 16, size.height / 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
