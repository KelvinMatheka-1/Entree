import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../models/guest_model.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'guest_invitation_screen.dart';
import 'event_rsvp_screen.dart';

class SendInvitationScreen extends StatefulWidget {
  final EventModel event;
  final GuestModel? guest;

  const SendInvitationScreen({
    super.key,
    required this.event,
    this.guest,
  });

  @override
  State<SendInvitationScreen> createState() => _SendInvitationScreenState();
}

class _SendInvitationScreenState extends State<SendInvitationScreen> {
  GuestModel? _selectedGuest;
  List<GuestModel> _guests = [];

  @override
  void initState() {
    super.initState();
    _selectedGuest = widget.guest;
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    try {
      final list = await ApiService.instance.getGuests(widget.event.id);
      if (mounted) {
        setState(() {
          _guests = list;
          if (_selectedGuest == null) {
            _selectedGuest = list.isNotEmpty ? list.first : null;
          } else {
            // Match with latest guest object if available
            final found = list.where((g) => g.id == _selectedGuest!.id || g.passId == _selectedGuest!.passId);
            if (found.isNotEmpty) _selectedGuest = found.first;
          }
        });
      }
    } catch (_) {
      // Ignored
    }
  }

  void _showTablePickerModal(BuildContext context, GuestModel guest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalTables = widget.event.tables > 0 ? widget.event.tables : 10;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assign Table',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${widget.event.seatsPerTable} seats/table',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: totalTables,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final tableNum = (idx + 1).toString();
                    final tableName = 'VIP Table $tableNum';
                    final isCurrent = guest.tableNumber == tableNum;

                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isCurrent
                              ? (isDark ? AppTheme.accentLime : AppTheme.primaryPurple)
                              : (isDark ? AppTheme.darkCardBorder : AppTheme.borderLight),
                        ),
                      ),
                      tileColor: isCurrent
                          ? (isDark
                              ? AppTheme.accentLime.withValues(alpha: 0.12)
                              : AppTheme.primaryPurple.withValues(alpha: 0.08))
                          : (isDark ? AppTheme.darkCard : const Color(0xFFF9FAFB)),
                      leading: Icon(
                        Icons.table_restaurant_outlined,
                        size: 20,
                        color: isCurrent
                            ? (isDark ? AppTheme.accentLime : AppTheme.primaryPurple)
                            : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                      ),
                      title: Text(
                        'Table $tableNum',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      trailing: isCurrent
                          ? Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                            )
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        final updated = guest.copyWith(
                          tableNumber: tableNum,
                          tableName: tableName,
                        );
                        await ApiService.instance.addGuest(widget.event.id, updated);
                        if (!mounted) return;
                        setState(() {
                          _selectedGuest = updated;
                          final idx = _guests.indexWhere((g) => g.id == updated.id || g.passId == updated.passId);
                          if (idx >= 0) {
                            _guests[idx] = updated;
                          }
                        });
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Assigned ${updated.fullName} to Table $tableNum'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final selectedGuest = _selectedGuest ?? widget.guest;
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
          'Send invitations',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event header
            EventHeaderCompact(event: event),
            const SizedBox(height: 20),

            // 1. General Public Event RSVP Link card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : const Color(0xFFDDD6FE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.accentLime.withValues(alpha: 0.15)
                              : AppTheme.primaryPurple.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Public Event RSVP Link',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Share anywhere. Attendees self-register and get their QR pass.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            InviteCryptoService.generateEventRsvpLink(event.id),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          onPressed: () {
                            final link = InviteCryptoService.generateEventRsvpLink(event.id);
                            Clipboard.setData(ClipboardData(text: link));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Public RSVP link copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final link = InviteCryptoService.generateEventRsvpLink(event.id);
                            final shareText =
                                "🎟️ You're invited to ${event.name}!\n\n"
                                "📅 ${event.dayString} ${event.monthShort} ${event.date.year} · ${event.startTime}–${event.endTime}\n"
                                "📍 ${event.venue}\n\n"
                                "👉 RSVP and get your digital entry pass here:\n$link";

                            await Share.share(
                              shareText,
                              subject: "RSVP to ${event.name}",
                            );
                          },
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Share RSVP Link'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                            side: BorderSide(
                              color: isDark
                                  ? AppTheme.accentLime.withValues(alpha: 0.6)
                                  : AppTheme.primaryPurple.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                            backgroundColor: isDark
                                ? AppTheme.accentLime.withValues(alpha: 0.08)
                                : AppTheme.primaryPurple.withValues(alpha: 0.06),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventRsvpScreen(event: event),
                            ),
                          );
                          _loadGuests();
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Preview RSVP'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : AppTheme.textPrimary,
                          side: BorderSide(color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const SectionLabel(text: 'INDIVIDUAL VIP PASSES'),
            const SizedBox(height: 8),

            if (selectedGuest == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 36,
                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No individual passes issued yet',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share the public RSVP link above, or add a guest manually in the Guests tab to issue an individual VIP pass.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (_guests.length > 1) ...[
                const SectionLabel(text: 'SELECT GUEST PASS'),
              Container(
                height: 38,
                margin: const EdgeInsets.only(bottom: 20),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _guests.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final g = _guests[idx];
                    final isSel = selectedGuest.id == g.id || selectedGuest.passId == g.passId;
                    return ChoiceChip(
                      label: Text(g.fullName),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() {
                          _selectedGuest = g;
                        });
                      },
                      selectedColor: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                        color: isSel
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Heading
            Text(
              'A seat with their name on it.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              "Share ${selectedGuest.fullName}'s personal pass. The QR invitation includes the event and assigned table.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),

            // Guest Details Section
            const SectionLabel(text: 'GUEST DETAILS'),
            Text('Full name',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: selectedGuest.fullName),
              readOnly: true,
            ),
            const SizedBox(height: 16),

            Text('Email address',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: selectedGuest.email),
              readOnly: true,
              decoration: InputDecoration(
                suffixIcon: Icon(Icons.email_outlined,
                    size: 18, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 16),

            Text('Assigned table',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    )),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showTablePickerModal(context, selectedGuest),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  border: Border.all(color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.table_restaurant_outlined,
                          size: 18,
                          color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Table ${selectedGuest.tableNumber} · ${selectedGuest.tableName}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Table assignment info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : const Color(0xFFF1EFFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : const Color(0xFFDDD8FE),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.event_seat_outlined,
                    size: 20,
                    color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedGuest.tableName} · Assigned Table',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Tap the table card above to reassign ${selectedGuest.fullName}'s table.",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.primaryPurple.withAlpha(200),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pass info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                border: Border.all(color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Personal pass',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        selectedGuest.passId,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Admission',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${selectedGuest.guestCount} guest · ${selectedGuest.admission}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Builder(
              builder: (context) {
                final signedLink = InviteCryptoService.generateDeepLink(
                  eventId: event.id,
                  guestId: selectedGuest.id,
                  inviteCode: selectedGuest.passId,
                  fullName: selectedGuest.fullName,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                      // Action buttons
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final shareText =
                                "🎟️ You're invited to ${event.name}!\n\n"
                                "📅 ${event.dayString} ${event.monthShort} ${event.date.year} · ${event.startTime}–${event.endTime}\n"
                                "📍 ${event.venue}\n"
                                "👤 Guest: ${selectedGuest.fullName} (Table ${selectedGuest.tableNumber})\n\n"
                                "👉 Open your personal ticket pass:\n$signedLink";

                            await Share.share(
                              shareText,
                              subject:
                                  "Invitation to ${event.name} for ${selectedGuest.fullName}",
                            );
                          },
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Send invitation'),
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
                                builder: (_) => GuestInvitationScreen(
                                  event: event,
                                  guest: selectedGuest,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_rounded, size: 18),
                          label: const Text('View & share visual ticket pass'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    ),
  ),
);
  }
}
