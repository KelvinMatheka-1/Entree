import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'edit_event_screen.dart';
import 'registered_guests_screen.dart';
import 'scan_entry_screen.dart';
import 'send_invitation_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late EventModel _currentEvent;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _refreshEvent();
  }

  Future<void> _refreshEvent() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final latest = await ApiService.instance.getEvent(_currentEvent.id);
      if (latest != null && mounted) {
        setState(() {
          _currentEvent = latest;
        });
      }
    } catch (e) {
      debugPrint('[EventDetailsScreen] Failed to refresh event: $e');
    } finally {
      if (mounted) {
        _isRefreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _currentEvent;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: AppTheme.textPrimary),
              ),
            ),
          ),
          title: Text(
            'Event Details',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            // Organizer tools menu
            PopupMenuButton<String>(
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: const Icon(Icons.more_vert_rounded,
                    size: 18, color: AppTheme.textPrimary),
              ),
              onSelected: (val) async {
                if (val == 'scan') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScanEntryScreen(event: _currentEvent),
                    ),
                  );
                  _refreshEvent();
                } else if (val == 'guests') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisteredGuestsScreen(event: _currentEvent),
                    ),
                  );
                  _refreshEvent();
                } else if (val == 'invite') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SendInvitationScreen(event: _currentEvent),
                    ),
                  );
                  _refreshEvent();
                } else if (val == 'edit') {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditEventScreen(event: _currentEvent),
                    ),
                  );
                  if (result == 'deleted') {
                    if (context.mounted) Navigator.pop(context, true);
                  } else if (result is EventModel) {
                    setState(() => _currentEvent = result);
                  } else {
                    _refreshEvent();
                  }
                } else if (val == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Event'),
                      content: Text('Are you sure you want to delete "${_currentEvent.name}"? This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await ApiService.instance.deleteEvent(_currentEvent.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Event "${_currentEvent.name}" deleted')),
                      );
                      Navigator.pop(context, true);
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'scan',
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_scanner, size: 18),
                      SizedBox(width: 10),
                      Text('Scan Entry'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'guests',
                  child: Row(
                    children: [
                      Icon(Icons.people_outline, size: 18),
                      SizedBox(width: 10),
                      Text('Registered Guests'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'invite',
                  child: Row(
                    children: [
                      Icon(Icons.send_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Send Invitations'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit Event'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Delete Event', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: RefreshIndicator(
          color: AppTheme.accentCoral,
          onRefresh: _refreshEvent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Rounded Top Photo Banner (matches reference)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SafeNetworkImage(
                  imageUrl: event.imageUrl,
                  height: 230,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Event Title
              Text(
                event.name,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // 3. Event Description
              Text(
                event.description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),

              // 4. Date & Attendees Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${event.monthShort} ${event.dayString}, 2026 ${event.startTime} - ${event.endTime}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "8 Going" Pill with avatars
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarStack(
                        avatars: event.attendeeAvatars,
                        size: 22,
                        maxAvatars: 3,
                        borderColor: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${event.passesIssued} Going',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Google Maps Link (matches reference pink link)
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppTheme.accentCoral,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Opening maps to ${event.venue}...'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Text(
                        'https://www.google.com/maps/dir//${event.cityOrVenue.toLowerCase().replaceAll(' ', '+')}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.accentCoral,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.accentCoral,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 6. Check-in & Event Management Hub
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Check-in Management',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${event.checkedIn}/${event.passesIssued} In',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: event.checkedInPercentage,
                        minHeight: 8,
                        backgroundColor: AppTheme.borderLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.accentCoral,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(event.checkedInPercentage * 100).toInt()}% Checked In',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        Text(
                          '${event.expected} Expected',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScanEntryScreen(event: _currentEvent),
                                ),
                              );
                              _refreshEvent();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlack,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: Text(
                              'Scan QR',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
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
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: const BorderSide(
                                  color: AppTheme.borderLight),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.people_outline, size: 18),
                            label: Text(
                              'Guests',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SendInvitationScreen(event: _currentEvent),
                              ),
                            );
                            _refreshEvent();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(
                                color: AppTheme.borderLight),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Icon(Icons.send_outlined, size: 18),
                        ),
                      ],
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

