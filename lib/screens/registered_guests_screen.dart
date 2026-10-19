import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../models/guest_model.dart';
import '../data/mock_data.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'send_invitation_screen.dart';
import 'scan_entry_screen.dart';
import 'guest_invitation_screen.dart';

class RegisteredGuestsScreen extends StatefulWidget {
  final EventModel event;

  const RegisteredGuestsScreen({super.key, required this.event});

  @override
  State<RegisteredGuestsScreen> createState() => _RegisteredGuestsScreenState();
}

class _RegisteredGuestsScreenState extends State<RegisteredGuestsScreen> {
  int _selectedFilter = 0; // 0=All, 1=Expected, 2=Arrived
  int _visibleCount = 5;
  String _searchQuery = '';
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<GuestModel> _guestsList = [];

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    final guests = await ApiService.instance.getGuests(widget.event.id);
    if (mounted) {
      setState(() {
        _guestsList = guests;
        _isLoading = false;
      });
    }
  }

  List<GuestModel> get _allGuests =>
      _guestsList.isNotEmpty ? _guestsList : (_isLoading ? MockData.guests : []);

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<GuestModel> get _filteredGuests {
    final guests = _allGuests;
    var list = switch (_selectedFilter) {
      1 => guests.where((g) => !g.isCheckedIn).toList(),
      2 => guests.where((g) => g.isCheckedIn).toList(),
      _ => guests,
    };

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((g) {
        return g.fullName.toLowerCase().contains(q) ||
            g.passId.toLowerCase().contains(q) ||
            g.tableNumber.toLowerCase().contains(q) ||
            g.tableName.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

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
          'Registered guests',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SendInvitationScreen(event: event),
                ),
              );
              _loadGuests();
            },
            child: const Text('Invite'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // Event header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: EventHeaderCompact(event: event),
              ),

              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _buildStatItem('${_allGuests.length}', 'Registered')),
                    Expanded(child: _buildStatItem('${_allGuests.where((g) => g.isCheckedIn).length}', 'Checked in')),
                    Expanded(child: _buildStatItem('${_allGuests.where((g) => !g.isCheckedIn).length}', 'Expected')),
                  ],
                ),
              ),
          const SizedBox(height: 16),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search name, pass ID or table',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filter tabs (pills matching Figma screenshot)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('All · ${_allGuests.length}', 0),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Expected · ${_allGuests.where((g) => !g.isCheckedIn).length}',
                  1,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Arrived · ${_allGuests.where((g) => g.isCheckedIn).length}',
                  2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'GUEST / TABLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'CHECK-IN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Guest list
          Expanded(
            child: _filteredGuests.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 44,
                            color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty ? 'No matching guests' : 'No guests registered yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try searching by another name or pass number.'
                                : 'Invite attendees or scan passes to add guests.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredGuests.length <= _visibleCount
                        ? _filteredGuests.length
                        : _visibleCount + 1,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == _visibleCount &&
                          _filteredGuests.length > _visibleCount) {
                        return _buildLoadMore();
                      }
                      return _buildGuestRow(_filteredGuests[index]);
                    },
                  ),
          ),

          // Bottom actions
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: BoxDecoration(
              color:
                  isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppTheme.darkCardBorder
                      : AppTheme.borderLight,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 40 : 12),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ScanEntryScreen(event: widget.event),
                        ),
                      );
                      _loadGuests();
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan a guest pass'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _searchFocus.requestFocus();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Search by name or pass ID above to verify identity.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_search_outlined, size: 18),
                    label: const Text('Manual check-in · find a guest'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manual check-in verifies a name or pass ID first.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECEBFE) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryPurple : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildGuestRow(GuestModel guest) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SendInvitationScreen(
              event: widget.event,
              guest: guest,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            AvatarCircle(initials: guest.initials, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guest.fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${guest.passId} · Table ${guest.tableNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (guest.isCheckedIn) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Checked in',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.liveGreen,
                            ),
                          ),
                          if (guest.checkInTime != null)
                            Text(
                              guest.checkInTime!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.undo_rounded, size: 16, color: AppTheme.textTertiary),
                        tooltip: 'Undo check-in',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _undoCheckIn(guest),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Not arrived',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _checkInGuest(guest),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Check in',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkInGuest(GuestModel guest) async {
    final res = await ApiService.instance.checkInGuest(widget.event.id, guest.passId);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty ? res.message : 'Guest ${guest.fullName} checked in.'),
          backgroundColor: AppTheme.liveGreen,
          duration: const Duration(seconds: 2),
        ),
      );
      await _loadGuests();
      if (mounted) {
        final updatedGuest = _guestsList.firstWhere(
          (g) => g.id == guest.id || g.passId == guest.passId,
          orElse: () => res.guest ?? guest.copyWith(status: GuestCheckInStatus.checkedIn, checkInTime: 'Just now'),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketValidationScreen(
              event: widget.event,
              guest: updatedGuest,
            ),
          ),
        ).then((_) => _loadGuests());
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _undoCheckIn(GuestModel guest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revert Check-in'),
        content: Text('Revert check-in for ${guest.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revert', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ApiService.instance.undoCheckIn(widget.event.id, guest.passId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reverted check-in for ${guest.fullName}'),
            duration: const Duration(seconds: 2),
          ),
        );
        await _loadGuests();
      }
    }
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $_visibleCount of ${_filteredGuests.length} guests',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _visibleCount = _filteredGuests.length;
            }),
            child: const Text(
              'Load more',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
