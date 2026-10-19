import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../models/guest_model.dart';
import '../data/mock_data.dart';
import '../services/api_service.dart';
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
    final verification = await ApiService.instance.verifyScan(_currentEvent.id, code);

    if (!verification.canCheckIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(verification.message),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _isProcessingScan = false);
      });
      return;
    }

    final checkInRes = await ApiService.instance.checkInGuest(_currentEvent.id, code);
    if (!mounted) return;

    final guest = checkInRes.guest ??
        verification.guest ??
        GuestModel(
          id: 'QR-${code.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)}',
          passId: code.length > 20 ? '${code.substring(0, 17)}...' : code,
          fullName: 'Pass Holder (${code.length > 12 ? code.substring(0, 10) : code})',
          email: 'guest@entree-pass.com',
          tableNumber: 'A-12',
          tableName: 'Verified Admission',
          status: GuestCheckInStatus.checkedIn,
          checkInTime: 'Just now',
          admission: 'General Admission',
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketValidationScreen(
          event: _currentEvent,
          guest: guest,
        ),
      ),
    ).then((_) {
      _refreshEvent();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _isProcessingScan = false;
          });
        }
      });
    });
  }

  Future<void> _onSimulateScan() async {
    if (_isProcessingScan) return;
    _isProcessingScan = true;
    try {
      final guests = await ApiService.instance.getGuests(_currentEvent.id);
      final candidate = guests.firstWhere(
        (g) => !g.isCheckedIn,
        orElse: () => guests.isNotEmpty ? guests.first : MockData.guests.first,
      );
      await _processScannedValue(candidate.passId);
    } catch (_) {
      if (mounted) setState(() => _isProcessingScan = false);
    }
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                event.imageUrl ??
                                    'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=100&h=100&fit=crop',
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 44,
                                  height: 44,
                                  color: isDark
                                      ? AppTheme.darkSurface
                                      : AppTheme.draftGrayBg,
                                  child: const Icon(Icons.smart_toy_rounded,
                                      color: AppTheme.textTertiary),
                                ),
                              ),
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
                            Icons.check_circle_outline,
                            size: 14,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${event.checkedIn} checked in · ${event.expected} still expected',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
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
