import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../data/mock_data.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'event_details_screen.dart';
import 'create_event_screen.dart';
import 'scan_entry_screen.dart';

Route<T> smoothPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomNavIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  DateTime _calendarMonth = DateTime(2026, 10, 1);
  DateTime? _selectedCalendarDate = DateTime(2026, 10, 24);

  static const List<String> _calendarMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  static const List<String> _calendarWeekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  IconData _getEventCategoryIcon(EventModel event) {
    final name = event.name.toLowerCase();
    if (name.contains('ai') ||
        name.contains('frontier') ||
        name.contains('keynote') ||
        name.contains('robotics')) {
      return Icons.smart_toy_rounded;
    } else if (name.contains('cloud') ||
        name.contains('systems') ||
        name.contains('devops') ||
        name.contains('expo')) {
      return Icons.cloud_queue_rounded;
    } else if (name.contains('cyber') ||
        name.contains('crypto') ||
        name.contains('quantum') ||
        name.contains('security')) {
      return Icons.security_rounded;
    } else if (name.contains('summit') ||
        name.contains('social') ||
        name.contains('tech') ||
        name.contains('founders')) {
      return Icons.groups_rounded;
    }
    return Icons.terminal_rounded;
  }

  List<EventModel> _backendEvents = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await ApiService.instance.getEvents();
    if (mounted) {
      setState(() {
        _backendEvents = events;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // All events sorted by date ascending
  List<EventModel> get _allSortedEvents {
    final list = _backendEvents.isNotEmpty
        ? List<EventModel>.from(_backendEvents)
        : List<EventModel>.from(MockData.events);
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  bool _matchesSearch(EventModel e) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return e.name.toLowerCase().contains(q) ||
        e.venue.toLowerCase().contains(q) ||
        e.venueAddress.toLowerCase().contains(q) ||
        (e.city != null && e.city!.toLowerCase().contains(q)) ||
        e.cityOrVenue.toLowerCase().contains(q) ||
        e.description.toLowerCase().contains(q) ||
        e.collection.toLowerCase().contains(q) ||
        e.monthShort.toLowerCase().contains(q) ||
        e.dayString == q;
  }

  List<EventModel> get _searchResults {
    return _allSortedEvents.where(_matchesSearch).toList();
  }

  // Featured / Popular events
  List<EventModel> get _popularEvents {
    return _allSortedEvents
        .where((e) => e.status != EventStatus.past)
        .where(_matchesSearch)
        .toList();
  }

  // Upcoming events for vertical list
  List<EventModel> get _upcomingEvents {
    return _allSortedEvents
        .where((e) => e.status != EventStatus.past)
        .where(_matchesSearch)
        .toList();
  }


  double _horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 1100) return (width - 1040) / 2;
    if (width > 768) return 32.0;
    if (width < 360) return 14.0;
    return 20.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor:
            isDark ? Colors.black : const Color(0xFF1A1A1A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor:
            isDark ? AppTheme.darkBackground : AppTheme.backgroundWhite,
        body: SafeArea(
          bottom: false,
          child: _bottomNavIndex == 0
              ? _buildDiscoverPage()
              : _bottomNavIndex == 1
                  ? _buildCheckInHub()
                  : _bottomNavIndex == 3
                      ? _buildCalendarPage()
                      : _bottomNavIndex == 4
                          ? _buildAccountPage()
                          : _buildDiscoverPage(),
        ),
        bottomNavigationBar: _buildDarkBottomNav(),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // DISCOVER PAGE (Main Events Page — Matches Reference Design)
  // ---------------------------------------------------------------------------
  Widget _buildDiscoverPage() {
    final popular = _popularEvents;
    final upcoming = _upcomingEvents;
    final searchResults = _searchResults;
    final isSearching = _searchQuery.trim().isNotEmpty;
    final hPad = _horizontalPadding(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // Header: "Find events in Nairobi"
        SliverToBoxAdapter(child: _buildHeader(hPad)),

        // Search Bar
        SliverToBoxAdapter(child: _buildSearchBar(hPad)),

        if (isSearching) ...[
          // Search Results Section Header with count badge
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Search Results',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF222638)
                          : AppTheme.primaryBlack.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${searchResults.length} found',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (searchResults.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : AppTheme.borderLight.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search_off_rounded,
                          size: 30,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No events found',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No events match "$_searchQuery"',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildUpcomingEventRow(searchResults[index]);
                  },
                  childCount: searchResults.length,
                ),
              ),
            ),
        ] else ...[
          // "Popular Event" Section Header
          if (popular.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Popular Event',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'See All',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Popular Event Hero Card
          if (popular.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: _buildHeroEventCard(popular.first),
              ),
            ),

          // "Upcoming Events" Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Upcoming Events',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${upcoming.length} available',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // "Upcoming Events" Vertical Scrollable List (matches screenshot layout)
          if (upcoming.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyUpcomingEvents(),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final event = upcoming[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildUpcomingDiscoveryCard(event, isDark),
                    );
                  },
                  childCount: upcoming.length,
                ),
              ),
            ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER — "Find events in London" with dark icon buttons
  // ---------------------------------------------------------------------------
  Widget _buildHeader(double hPad) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: "Find events in" + City
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Find events in',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ],
                ),
                Text(
                  'Nairobi',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // Right: Notifications dark circle button with lime green indicator dot (Chat button removed)
          _buildDarkCircleButton(
            Icons.notifications_none_rounded,
            hasBadge: true,
            badgeColor: const Color(0xFFEF4444),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDarkCircleButton(
    IconData icon, {
    required VoidCallback onTap,
    double size = 42,
    bool hasBadge = false,
    Color? badgeColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassContainer(
            width: size,
            height: size,
            borderRadius: size / 2,
            blur: 16,
            color: isDark
                ? const Color(0xFF1E1E1E).withValues(alpha: 0.70)
                : AppTheme.primaryBlack.withValues(alpha: 0.82),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 19),
            ),
          ),
          if (hasBadge)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: badgeColor ?? const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isDark ? const Color(0xFF1E1E1E) : AppTheme.primaryBlack,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR — Rounded pill with dark filter button
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar(double hPad) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 4),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color:
                      isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(
                  color:
                      isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  fontSize: 14,
                ),
                cursorColor: isDark ? Colors.white : AppTheme.primaryBlack,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  hintText: 'Search',
                  hintStyle: GoogleFonts.inter(
                    color: isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.textTertiary,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.textTertiary,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Dark filter button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : AppTheme.primaryBlack,
                borderRadius: BorderRadius.circular(16),
                border: isDark
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.tune, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // HERO EVENT CARD — Large single card with circular date and pill price (matches reference)
  // ---------------------------------------------------------------------------
  Widget _buildHeroEventCard(EventModel event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          smoothPageRoute(EventDetailsScreen(event: event)),
        ).then((_) => _loadEvents());
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background Image
              SafeNetworkImage(
                imageUrl: event.imageUrl,
                height: 340,
                width: double.infinity,
                borderRadius: BorderRadius.circular(24),
              ),

              // Subtle black fade at the bottom (clean, no blur)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 155,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Top-left: Avatar row + "X Going" badge
              Positioned(
                top: 14,
                left: 14,
                child: GlassContainer(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  borderRadius: 20,
                  blur: 16,
                  color: isDark
                      ? const Color(0xFF141414).withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.75),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarStack(
                        avatars: event.attendeeAvatars,
                        size: 22,
                        maxAvatars: 3,
                        borderColor:
                            isDark ? const Color(0xFF161822) : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${event.passesIssued} Going',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom: Overlay info bar — curvy capsule pill aligned with circular date badge
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: GlassContainer(
                  padding: const EdgeInsets.all(6),
                  borderRadius: 40,
                  blur: 20,
                  color: isDark
                      ? const Color(0xFF10121A).withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.85),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  child: Row(
                    children: [
                      // Concentric Circle Date Badge
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentLime,
                          shape: BoxShape.circle,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              event.dayString,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryBlack,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              event.monthShort,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryBlack,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Event Name & Venue Location
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              event.name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    '${event.venue}, ${event.cityOrVenue}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Price Badge matching right curve alignment
                      GlassContainer(
                        height: 50,
                        borderRadius: 25,
                        blur: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : const Color(0xFFF8F9FA).withValues(alpha: 0.85),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.16)
                              : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              event.priceBadge ?? '\$1200',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.primaryBlack,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UPCOMING EVENTS — Layout from screenshot (left thumbnail, right details, stats)
  // ---------------------------------------------------------------------------
  Widget _buildEmptyUpcomingEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.event_busy,
              size: 48,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No events found',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingDiscoveryCard(EventModel event, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          smoothPageRoute(EventDetailsScreen(event: event)),
        ).then((_) => _loadEvents());
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? const Color(0xFF262626)
                : AppTheme.borderLight,
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Extended image thumbnail (extended horizontally to the right)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 140,
                height: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SafeNetworkImage(
                      imageUrl: event.imageUrl,
                      width: 140,
                      height: 104,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    // Subtle dark gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    // Date pill on image thumbnail
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          '${event.dayString} ${event.monthShort}',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentLime,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Right: Content column (Title, subtitle/venue, and Going attendees)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Text(
                    event.name,
                    style: GoogleFonts.inter(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFFFFFFF)
                          : AppTheme.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Subtitle / Venue & description
                  Text(
                    event.venue.isNotEmpty
                        ? '${event.venue} • ${event.startTime}'
                        : event.description,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? const Color(0xFFB3B3B3)
                          : AppTheme.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Bottom row: Host / Attendees avatar + name (chat, bookmark, and price removed)
                  Row(
                    children: [
                      // Profile circle with icon
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF242424)
                              : const Color(0xFFEDEDF2),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 13,
                          color: isDark
                              ? const Color(0xFFB3B3B3)
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Host / Attendee text
                      Expanded(
                        child: Text(
                          '${event.passesIssued} Going',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFFFFFFF)
                                : AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UPCOMING EVENT ROW — Clean list item with details
  // ---------------------------------------------------------------------------
  Widget _buildUpcomingEventRow(EventModel event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            smoothPageRoute(EventDetailsScreen(event: event)),
          ).then((_) => _loadEvents());
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Event image thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SafeNetworkImage(
                  imageUrl: event.imageUrl,
                  width: 70,
                  height: 70,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 14),

              // Event info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.dateFormatted} · ${event.startTime}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            event.venue,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : AppTheme.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF222638)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      event.priceLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.primaryBlack,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.passesIssued} going',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHECK-IN HUB (Bottom Nav Index 1)
  // ---------------------------------------------------------------------------
  Widget _buildCheckInHub() {
    final hPad = _horizontalPadding(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entry Check-in',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan guest passes or look up registered attendees',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Select Event to Check-in',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final event = _allSortedEvents[index];
                final hasImage =
                    event.imageUrl != null && event.imageUrl!.isNotEmpty;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      smoothPageRoute(ScanEntryScreen(event: event)),
                    ).then((_) => _loadEvents());
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF262626)
                            : const Color(0xFF222222),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.16,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Background Event Image positioned across the card
                        if (hasImage)
                          Positioned.fill(
                            child: Image.network(
                              event.imageUrl!,
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: const Color(0xFF141414),
                              ),
                            ),
                          ),

                        // Gradient fading into dark from the right towards the left for readable contents
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  const Color(0xFF141414).withValues(alpha: 0.40),
                                  const Color(0xFF141414).withValues(alpha: 0.18),
                                  const Color(0xFF141414).withValues(alpha: 0.85),
                                  const Color(0xFF141414),
                                  const Color(0xFF141414),
                                ],
                                stops: const [0.0, 0.28, 0.58, 0.78, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Card Content
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Date box with accent lime background
                              DateCalendarBox(
                                month: event.monthShort,
                                day: event.dayString,
                                width: 50,
                                height: 56,
                              ),
                              const SizedBox(width: 14),

                              // Text details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      event.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.25,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 13,
                                          color: Color(0xFFB3B3B3),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${event.venue} · ${event.startTime}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFFB3B3B3),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Check-in and Status indicators
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 3.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.16),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.how_to_reg_rounded,
                                                size: 12,
                                                color: event.status ==
                                                        EventStatus.live
                                                    ? AppTheme.accentLime
                                                    : Colors.white,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                '${event.checkedIn}/${event.passesIssued} checked in',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (event.status ==
                                            EventStatus.live) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF22C55E)
                                                  .withValues(alpha: 0.25),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: const Color(0xFF22C55E)
                                                    .withValues(alpha: 0.45),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(0xFF22C55E),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'LIVE',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        const Color(0xFF4ADE80),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Sleek glass forward icon
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: _allSortedEvents.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT PAGE (Bottom Nav Index 4 — last tab)
  // ---------------------------------------------------------------------------
  Widget _buildAccountPage() {
    final hPad = _horizontalPadding(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          // User Profile Card
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
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF262938)
                        : AppTheme.primaryBlack,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'AL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alex Morgan',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Head of Corporate Events',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        'alex.morgan@entree.corporate',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Statistics Overview
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  '${_allSortedEvents.length}',
                  'Total Events',
                  Icons.event_note,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  '520',
                  'Total Capacity',
                  Icons.people_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  '98.4%',
                  'Check-in Rate',
                  Icons.verified_rounded,
                  isVibrant: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Light & Dark Mode Option (Directly in Profile Page)
          _buildSettingsGroup('Appearance & Display', [
            _buildThemeModeSelector(isDark),
          ]),
          const SizedBox(height: 24),

          _buildSettingsGroup('Scanner & Hardware', [
            _buildSettingsTile(
              Icons.camera_alt_outlined,
              'Camera Scanner Speed',
              'High sensitivity',
            ),
            _buildSettingsTile(
              Icons.vibration_outlined,
              'Haptic Feedback on Check-in',
              'Enabled',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildThemeModeSelector(bool isDark) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, currentMode, _) {
        final isDarkMode = currentMode == ThemeMode.dark;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF222638)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: isDarkMode
                      ? Colors.white
                      : AppTheme.primaryBlack,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      isDarkMode
                          ? 'Dark theme enabled'
                          : 'Light theme enabled',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // iOS Adaptive Switch
              Switch.adaptive(
                value: isDarkMode,
                activeThumbColor: Colors.white,
                activeTrackColor: isDark
                    ? const Color(0xFF3B82F6)
                    : AppTheme.primaryBlack,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: isDark
                    ? const Color(0xFF333645)
                    : const Color(0xFFE2E8F0),
                onChanged: (val) {
                  AppTheme.setThemeMode(
                    val ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(
    String value,
    String label,
    IconData icon, {
    bool isVibrant = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryBlack,
            size: 20,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
              ),
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(
        icon,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
        size: 20,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
        size: 18,
      ),
      onTap: () {},
    );
  }

  // ---------------------------------------------------------------------------
  // DARK FLOATING BOTTOM NAV BAR (Matches Reference Design)
  // ---------------------------------------------------------------------------
  Widget _buildDarkBottomNav() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.black, // Solid pure black
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: const Color(0xFF222222),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Expanded(
                  child: _buildDarkNavItem(0, Icons.explore_outlined, 'Discover')),
              Expanded(
                  child:
                      _buildDarkNavItem(1, Icons.qr_code_scanner_rounded, 'Check-in')),
              // Center (+) button
              _buildCenterFab(),
              Expanded(
                  child: _buildDarkNavItem(
                      3, Icons.calendar_today_outlined, 'Calendar')),
              Expanded(
                  child:
                      _buildDarkNavItem(4, Icons.person_outline_rounded, 'Profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkNavItem(int index, IconData icon, String label) {
    final isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _bottomNavIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 12 : 6,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: isSelected
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  )
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 21,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CALENDAR PAGE — Event Schedule & Timelines
  // ---------------------------------------------------------------------------
  List<DateTime> _daysForMonth([DateTime? month]) {
    final targetMonth = month ?? _calendarMonth;
    final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final daysInMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final leadingOffset = (firstDayOfMonth.weekday - 1); // Monday is 1 -> 0 offset

    final days = <DateTime>[];

    // Previous month padding days
    final prevMonthLastDay = DateTime(targetMonth.year, targetMonth.month, 0).day;
    for (int i = leadingOffset - 1; i >= 0; i--) {
      days.add(DateTime(targetMonth.year, targetMonth.month - 1, prevMonthLastDay - i));
    }

    // Current month days
    for (int day = 1; day <= daysInMonth; day++) {
      days.add(DateTime(targetMonth.year, targetMonth.month, day));
    }

    // Trailing padding days to complete week rows
    final remainder = days.length % 7;
    if (remainder != 0) {
      final trailingDays = 7 - remainder;
      for (int i = 1; i <= trailingDays; i++) {
        days.add(DateTime(targetMonth.year, targetMonth.month + 1, i));
      }
    }

    return days;
  }

  String _formatDateTitle(DateTime? date) {
    if (date == null) return '';
    return '${_calendarMonthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ---------------------------------------------------------------------------
  // CALENDAR PAGE — Normal Interactive Calendar with Event Icons & Tap to Details
  // ---------------------------------------------------------------------------
  Widget _buildCalendarPage() {
    final hPad = _horizontalPadding(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthDays = _daysForMonth(_calendarMonth);

    // Events in the active month
    final monthEvents = _allSortedEvents
        .where((e) =>
            e.date.year == _calendarMonth.year &&
            e.date.month == _calendarMonth.month)
        .toList();

    // Events on the selected day
    final selectedEvents = _selectedCalendarDate == null
        ? <EventModel>[]
        : _allSortedEvents
            .where((e) =>
                e.date.year == _selectedCalendarDate!.year &&
                e.date.month == _selectedCalendarDate!.month &&
                e.date.day == _selectedCalendarDate!.day)
            .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Calendar',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap any date with an event icon to open event details',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Normal Month Calendar Card
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color:
                      isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Month navigation bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          setState(() {
                            _calendarMonth = DateTime(
                              _calendarMonth.year,
                              _calendarMonth.month - 1,
                              1,
                            );
                          });
                        },
                        color: isDark ? Colors.white : AppTheme.primaryBlack,
                        tooltip: 'Previous Month',
                      ),
                      Row(
                        children: [
                          Text(
                            '${_calendarMonthNames[_calendarMonth.month - 1]} ${_calendarMonth.year}',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          if (_calendarMonth.month != 10 ||
                              _calendarMonth.year != 2026) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _calendarMonth = DateTime(2026, 10, 1);
                                  _selectedCalendarDate =
                                      DateTime(2026, 10, 24);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF222638)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Oct 2026',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.primaryBlack,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          setState(() {
                            _calendarMonth = DateTime(
                              _calendarMonth.year,
                              _calendarMonth.month + 1,
                              1,
                            );
                          });
                        },
                        color: isDark ? Colors.white : AppTheme.primaryBlack,
                        tooltip: 'Next Month',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Weekday header (Mon - Sun)
                  Row(
                    children: _calendarWeekdays.map((day) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : AppTheme.textTertiary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // 7-column calendar grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: monthDays.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.9,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemBuilder: (context, index) {
                      final dayDate = monthDays[index];
                      final isCurrentMonth =
                          dayDate.month == _calendarMonth.month;
                      final dayEvents = _allSortedEvents
                          .where((e) =>
                              e.date.year == dayDate.year &&
                              e.date.month == dayDate.month &&
                              e.date.day == dayDate.day)
                          .toList();
                      final hasEvent = dayEvents.isNotEmpty;
                      final isSelected = _selectedCalendarDate != null &&
                          _selectedCalendarDate!.year == dayDate.year &&
                          _selectedCalendarDate!.month == dayDate.month &&
                          _selectedCalendarDate!.day == dayDate.day;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _selectedCalendarDate = dayDate;
                            if (!isCurrentMonth) {
                              _calendarMonth = DateTime(
                                dayDate.year,
                                dayDate.month,
                                1,
                              );
                            }
                          });
                          if (hasEvent) {
                            Navigator.push(
                              context,
                              smoothPageRoute(
                                EventDetailsScreen(
                                  event: dayEvents.first,
                                ),
                              ),
                            ).then((_) => _loadEvents());
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accentLime
                                : hasEvent
                                    ? (isDark
                                        ? const Color(0xFF1E2230)
                                        : const Color(0xFFF1F5F9))
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? null
                                : hasEvent
                                    ? Border.all(
                                        color: isDark
                                            ? const Color(0xFF2C2C2C)
                                            : const Color(0xFFE2E8F0),
                                        width: 1,
                                      )
                                    : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${dayDate.day}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: hasEvent || isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.primaryBlack
                                      : (isCurrentMonth
                                          ? (isDark
                                              ? AppTheme.darkTextPrimary
                                              : AppTheme.textPrimary)
                                          : (isDark
                                              ? Colors.white24
                                              : AppTheme.textTertiary
                                                  .withValues(alpha: 0.35))),
                                ),
                              ),
                              if (hasEvent) ...[
                                const SizedBox(height: 2),
                                Icon(
                                  _getEventCategoryIcon(dayEvents.first),
                                  size: 14,
                                  color: isSelected
                                      ? AppTheme.primaryBlack
                                      : (isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.textSecondary),
                                ),
                              ] else
                                const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // Section header for selected date or month events
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedEvents.isNotEmpty
                        ? 'Events on ${_formatDateTitle(_selectedCalendarDate!)}'
                        : 'Events in ${_calendarMonthNames[_calendarMonth.month - 1]}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${selectedEvents.isNotEmpty ? selectedEvents.length : monthEvents.length} scheduled',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Event cards
        if (selectedEvents.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = selectedEvents[index];
                  return _buildCalendarEventCard(event, isDark);
                },
                childCount: selectedEvents.length,
              ),
            ),
          )
        else if (monthEvents.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = monthEvents[index];
                  return _buildCalendarEventCard(event, isDark);
                },
                childCount: monthEvents.length,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(hPad),
              child: Center(
                child: Text(
                  'No events scheduled for this period',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.textTertiary,
                  ),
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildCalendarEventCard(EventModel event, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            smoothPageRoute(EventDetailsScreen(event: event)),
          ).then((_) => _loadEvents());
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          event.dayString,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentLime,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.monthShort,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentLime,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.name,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: event.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${event.startTime} - ${event.endTime}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                event.venue,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF232635) : AppTheme.divider,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${event.checkedIn}/${event.passesIssued} Checked In',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'View Event Details',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.primaryBlack,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.primaryBlack,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterFab() {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        await Navigator.push(
          context,
          smoothPageRoute(const CreateEventScreen()),
        );
        _loadEvents();
      },
      child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE2FF66),
              AppTheme.accentLime,
              Color(0xFF9ECE10),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.add_rounded,
            color: Color(0xFF0D0F18),
            size: 26,
          ),
        ),
      ),
    );
  }
}
