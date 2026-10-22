import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'guest_invitation_screen.dart';

class EventRsvpScreen extends StatefulWidget {
  final EventModel event;

  const EventRsvpScreen({super.key, required this.event});

  @override
  State<EventRsvpScreen> createState() => _EventRsvpScreenState();
}

class _EventRsvpScreenState extends State<EventRsvpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitRsvp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final guest = await ApiService.instance.rsvpGuest(
        eventId: widget.event.id,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('RSVP confirmed for ${guest.fullName}! Generating your pass...'),
          backgroundColor: AppTheme.liveGreen,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate directly to their visual ticket pass with signed QR code
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GuestInvitationScreen(
            event: widget.event.copyWith(
              passesIssued: widget.event.passesIssued + 1,
            ),
            guest: guest,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm RSVP: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remainingSpots = (event.totalCapacity - event.passesIssued).clamp(0, event.totalCapacity);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.surfaceWhite,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Event RSVP',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.backgroundWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      isDark
                          ? 'assets/images/app_logo_cropped.png'
                          : 'assets/images/app_logo_light_cropped.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Event Cover Banner
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SafeNetworkImage(
                    imageUrl: event.imageUrl,
                    width: double.infinity,
                    height: 200,
                    borderRadius: BorderRadius.circular(18),
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Collection & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.collection.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                      ),
                    ),
                    StatusBadge(status: event.status),
                  ],
                ),
                const SizedBox(height: 8),

                // 3. Event Title
                Text(
                  event.name,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Date & Venue Details
                Container(
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
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${event.dayString} ${event.monthShort} ${event.date.year} · ${event.startTime} – ${event.endTime}',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppTheme.accentCoral,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${event.venue} (${event.venueAddress})',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 18,
                            color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${event.passesIssued} Confirmed Attendees · $remainingSpots spots left',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. RSVP Form Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reserve Your Pass',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fill in your details below. Once confirmed, you will immediately receive your personal cryptographic QR entry pass.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Full Name
                        Text(
                          'Full Name *',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Maya Bennett',
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email
                        Text(
                          'Email Address *',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. maya@example.com',
                            prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your email address';
                            }
                            if (!val.contains('@') || !val.contains('.')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone Number (Optional)
                        Text(
                          'Phone Number (Optional)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. +254 700 000 000',
                            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitRsvp,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    ),
                                  )
                                : const Icon(Icons.qr_code_rounded, size: 20),
                            label: Text(
                              _isSubmitting ? 'Confirming RSVP...' : 'Confirm RSVP & Get Pass',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(
                          isDark
                              ? 'assets/images/app_logo_cropped.png'
                              : 'assets/images/app_logo_light_cropped.png',
                          height: 18,
                          width: 18,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Powered by entrée RSVP',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                          fontWeight: FontWeight.w500,
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
    );
  }
}
