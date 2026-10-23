import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/event_model.dart';
import '../models/user_profile_model.dart';
import '../data/mock_data.dart';
import '../services/api_service.dart';
import '../services/media_helper.dart';
import '../widgets/common_widgets.dart';
import 'event_details_screen.dart';
import 'create_event_screen.dart';
import 'scan_entry_screen.dart';

Route<T> smoothPageRoute<T>(Widget page) {
  return MaterialPageRoute<T>(builder: (_) => page);
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
    if (name.contains('chameleon') ||
        name.contains('art') ||
        name.contains('graffiti') ||
        name.contains('visual') ||
        name.contains('design')) {
      return Icons.palette_rounded;
    } else if (name.contains('naivas') ||
        name.contains('food') ||
        name.contains('market') ||
        name.contains('culinary') ||
        name.contains('dining')) {
      return Icons.restaurant_rounded;
    } else if (name.contains('ai') ||
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
  bool _eventsLoaded = false;
  FullProfileData? _profileData;
  Timer? _featuredTimer;
  int _featuredIndex = 0;

  @override
  void initState() {
    super.initState();
    _startFeaturedTimer();
    _refreshAllData();
  }

  void _startFeaturedTimer() {
    _featuredTimer?.cancel();
    _featuredTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final featured = _featuredEvents;
      if (featured.length > 1) {
        setState(() {
          _featuredIndex = (_featuredIndex + 1) % featured.length;
        });
      }
    });
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      _loadEvents(),
      _loadProfile(forceRefresh: true),
    ]);
  }

  Future<void> _loadEvents() async {
    final events = await ApiService.instance.getEvents();
    if (mounted) {
      setState(() {
        _backendEvents = events;
        _eventsLoaded = true;
      });
    }
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    final data = await ApiService.instance.getProfile(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _profileData = data;
      });
    }
  }

  @override
  void dispose() {
    _featuredTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // All events sorted by date ascending
  List<EventModel> get _allSortedEvents {
    final list = _eventsLoaded
        ? List<EventModel>.from(_backendEvents)
        : (_backendEvents.isNotEmpty
            ? List<EventModel>.from(_backendEvents)
            : List<EventModel>.from(MockData.events));
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

  // Featured events: prioritize events marked isFeatured
  List<EventModel> get _featuredEvents {
    final explicitlyFeatured = _allSortedEvents
        .where((e) => e.isFeatured && e.status != EventStatus.past)
        .where(_matchesSearch)
        .toList();
    if (explicitlyFeatured.isNotEmpty) {
      return explicitlyFeatured;
    }
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
    final featured = _featuredEvents;
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
                          ? AppTheme.darkSurface
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
          // "Featured Event" Section Header
          if (featured.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Featured Event',
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

          // Featured Event Rotating Card (subtle fade blur every 4s)
          if (featured.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: _buildRotatingFeaturedCard(featured),
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
                    '${upcoming.length} scheduled',
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

          // "Upcoming Events" Vertical Scrollable List (normal up-down scroll within bounded box)
          if (upcoming.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyUpcomingEvents(),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: SizedBox(
                  height: upcoming.length == 1
                      ? 140
                      : upcoming.length == 2
                          ? 276
                          : 395,
                  child: ScrollConfiguration(
                    behavior: const _NoScrollbarBehavior(),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      primary: false,
                      physics: const BouncingScrollPhysics(),
                      itemCount: upcoming.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = upcoming[index];
                        return _buildUpcomingDiscoveryCard(event, isDark);
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER — "Host Portal" with dark icon buttons
  // ---------------------------------------------------------------------------
  Widget _buildHeader(double hPad) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left: City name, Right: App Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Nairobi',
                style: TextStyle(
                  fontFamily: 'Amsterdam Four',
                  fontFamilyFallback: const ['AmsterdamFour', 'Amsterdam Four_ttf'],
                  fontSize: 30,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
              // Right: Entrée App Logo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppTheme.borderLight,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(
                      isDark
                          ? 'assets/images/app_logo_cropped.png'
                          : 'assets/images/app_logo_light_cropped.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // True horizontal & vertical center: Host Portal label
          Center(
            child: Text(
              'Host Portal',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR — Rounded full-width pill dominating search area
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar(double hPad) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 4),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
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
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontSize: 14,
          ),
          cursorColor: isDark ? Colors.white : AppTheme.primaryBlack,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            hintText: 'Search hosted events or venues...',
            hintStyle: GoogleFonts.inter(
              color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
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
    );
  }

  // ---------------------------------------------------------------------------
  // ROTATING FEATURED EVENT CARD — 10-second carousel with slow, subtle fade + blur transition (1.2s)
  // ---------------------------------------------------------------------------
  Widget _buildRotatingFeaturedCard(List<EventModel> featured) {
    final currentEvent = featured[_featuredIndex % featured.length];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1200),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, child) {
              final blur = (1.0 - curved.value) * 6.0;
              if (blur <= 0.08) return child!;
              return ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: child,
              );
            },
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(currentEvent.id),
        child: _buildHeroEventCard(currentEvent),
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
        ).then((_) => _refreshAllData());
      },
      child: Container(
        width: double.infinity,
        height: 340,
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
              // Full-bleed Rectangular Event Cover Image
              Positioned.fill(
                child: SafeNetworkImage(
                  imageUrl: event.imageUrl,
                  fit: BoxFit.cover,
                  height: 340,
                  width: double.infinity,
                  alignment: Alignment.topCenter,
                ),
              ),

              // 3. Subtle black fade at the bottom for text readability
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 160,
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
                        Colors.black.withValues(alpha: 0.82),
                      ],
                      stops: const [0.0, 0.40, 1.0],
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
                        '${event.passesIssued} Guests',
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
                                const SizedBox(width: 4),
                                Expanded(
                                  child: SlidingMarqueeLocation(
                                    text: '${event.venue}, ${event.cityOrVenue}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.textSecondary,
                                    ),
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
        ).then((_) => _refreshAllData());
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 128),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    maxLines: 1,
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
                          '${event.passesIssued} Guests',
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
          ).then((_) => _refreshAllData());
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
                          ? AppTheme.darkSurface
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
                    '${event.passesIssued} guests',
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

  bool _isEventPast(EventModel e) {
    if (e.status == EventStatus.past) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(e.date.year, e.date.month, e.date.day);
    return eventDay.isBefore(today);
  }

  // ---------------------------------------------------------------------------
  // CHECK-IN HUB (Bottom Nav Index 1)
  // ---------------------------------------------------------------------------
  Widget _buildCheckInHub() {
    final hPad = _horizontalPadding(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeCheckInEvents =
        _allSortedEvents.where((e) => !_isEventPast(e)).toList();
    final pastCheckInEvents =
        _allSortedEvents.where((e) => _isEventPast(e)).toList();
    final checkInList = [...activeCheckInEvents, ...pastCheckInEvents];

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
                final event = checkInList[index];
                final isPast = _isEventPast(event);
                final isFirstPast = isPast && index == activeCheckInEvents.length;
                final hasImage =
                    event.imageUrl != null && event.imageUrl!.isNotEmpty;

                Widget cardWidget = GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      smoothPageRoute(ScanEntryScreen(event: event)),
                    ).then((_) => _refreshAllData());
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
                            child: SafeNetworkImage(
                              imageUrl: event.imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topRight,
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
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
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
                                            EventStatus.live)
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
                                          )
                                        else if (isPast)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.15),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              'PAST',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF94A3B8),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
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

                // ONLY already passed events have the slide to delete feature!
                if (isPast) {
                  Widget dismissibleCard = Dismissible(
                    key: ValueKey<String>('checkin_del_${event.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor:
                              isDark ? AppTheme.darkSurface : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            'Delete Past Event?',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          content: Text(
                            'Are you sure you want to delete "${event.name}" and its check-in records?',
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ??
                          false;
                    },
                    onDismissed: (_) async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ApiService.instance.deleteEvent(event.id);
                      _refreshAllData();
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Deleted past event "${event.name}"',
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    child: cardWidget,
                  );

                  if (isFirstPast) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 18, 4, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Past Events',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.swipe_left_rounded,
                                    size: 15,
                                    color: isDark
                                        ? AppTheme.darkTextTertiary
                                        : AppTheme.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Slide to delete',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextTertiary
                                          : AppTheme.textTertiary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        dismissibleCard,
                      ],
                    );
                  }

                  return dismissibleCard;
                }

                // Active events: No slide to delete
                return cardWidget;
              },
              childCount: checkInList.length,
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
    final profile = _profileData?.profile;

    // Derived dynamic metric values directly from live events list
    final totalEventsCount = _allSortedEvents.length;
    final totalCapacityCount =
        _allSortedEvents.fold<int>(0, (s, e) => s + e.totalCapacity);
    final totalCheckedInCount =
        _allSortedEvents.fold<int>(0, (s, e) => s + e.checkedIn);
    final totalPassesIssued =
        _allSortedEvents.fold<int>(0, (s, e) => s + e.passesIssued);
    final checkInRateStr = totalPassesIssued > 0
        ? '${((totalCheckedInCount / totalPassesIssued) * 100).toStringAsFixed(1)}%'
        : (totalCapacityCount > 0
            ? '${((totalCheckedInCount / totalCapacityCount) * 100).toStringAsFixed(1)}%'
            : '0.0%');

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadEvents(),
          _loadProfile(forceRefresh: true),
        ]);
      },
      color: AppTheme.accentLime,
      backgroundColor: isDark ? AppTheme.darkCard : AppTheme.primaryBlack,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 110),
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
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // User Avatar with Image or Initials
                      _buildAvatarImage(
                        avatarUrl: profile?.avatarUrl,
                        initials: profile?.initials ?? 'KM',
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.fullName ?? 'Kelvin Matheka',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              profile?.role ?? 'Event Owner',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile?.organization ?? 'Entrée',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkCardBorder : AppTheme.borderLight,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 13,
                                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    profile?.email ?? 'kelvin@entree.app',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 13,
                                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  profile?.phone ?? '+254 700 000 000',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit Profile Button
                      OutlinedButton.icon(
                        onPressed: () => _showEditProfileModal(context),
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: isDark ? AppTheme.accentLime : AppTheme.primaryBlack,
                        ),
                        label: Text(
                          'Edit',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.accentLime : AppTheme.primaryBlack,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark
                                ? AppTheme.accentLime.withValues(alpha: 0.4)
                                : AppTheme.borderLight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  if (profile?.bio != null && profile!.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        profile.bio!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Statistics Overview (Clean 3-Item Layout)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    '$totalEventsCount',
                    'Total Events',
                    Icons.event_note_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    '$totalCapacityCount',
                    'Total Capacity',
                    Icons.people_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    checkInRateStr,
                    'Check-in Rate',
                    Icons.verified_rounded,
                    isVibrant: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Appearance & Display
            _buildSettingsGroup('Appearance & Display', [
              _buildThemeModeSelector(isDark),
            ]),
            const SizedBox(height: 24),

            // Scanner & Hardware Group
            _buildSettingsGroup('Scanner & Hardware', [
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.vibration_outlined,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    size: 19,
                  ),
                ),
                title: Text(
                  'Haptic Feedback on Check-in',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  (profile?.hapticFeedback ?? true) ? 'Enabled' : 'Disabled',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: profile?.hapticFeedback ?? true,
                  activeThumbColor: AppTheme.primaryBlack,
                  activeTrackColor: AppTheme.accentLime,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
                  onChanged: (val) async {
                    if (val) HapticFeedback.mediumImpact();
                    await ApiService.instance.updateProfile(hapticFeedback: val);
                    if (mounted) {
                      setState(() {
                        if (_profileData != null) {
                          _profileData = _profileData!.copyWith(
                            profile: _profileData!.profile.copyWith(hapticFeedback: val),
                          );
                        }
                      });
                    }
                  },
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // Storage Engine & Upstream Setting
            _buildSettingsGroup('Data & Upstream Engine', [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ApiService.isMachineNovaLiveEnabled
                        ? AppTheme.accentLime.withValues(alpha: 0.15)
                        : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    ApiService.isMachineNovaLiveEnabled ? Icons.cloud_sync_rounded : Icons.save_rounded,
                    color: ApiService.isMachineNovaLiveEnabled
                        ? (isDark ? AppTheme.accentLime : AppTheme.primaryPurple)
                        : (isDark ? Colors.white70 : AppTheme.textSecondary),
                    size: 20,
                  ),
                ),
                title: Text(
                  'Live MachineNova API',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  ApiService.isMachineNovaLiveEnabled
                      ? 'Live Upstream Mode (Requires active credentials)'
                      : 'Local Persistent Mode (SharedPreferences Engine · Default)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: ApiService.isMachineNovaLiveEnabled,
                  activeThumbColor: AppTheme.primaryBlack,
                  activeTrackColor: AppTheme.accentLime,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
                  onChanged: (val) async {
                    await ApiService.setUseMachineNovaLive(val);
                    await _loadProfile(forceRefresh: true);
                    await _loadEvents();
                    if (mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val
                              ? 'Live MachineNova mode enabled.'
                              : 'Local persistent storage active (Zero 3rd-party dependencies).'),
                          backgroundColor: val ? AppTheme.primaryPurple : AppTheme.accentLime,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
              ),
              _buildSettingsTile(
                Icons.storage_rounded,
                'Storage Engine',
                'Persistent SharedPreferences + Cryptographic JWT Passes',
                trailing: const SizedBox.shrink(),
              ),
            ]),
            const SizedBox(height: 24),

            // About Entrée
            _buildSettingsGroup('About', [
              _buildSettingsTile(
                Icons.info_outline_rounded,
                'Entrée Check-in',
                'Version 1.0.0',
                trailing: const SizedBox.shrink(),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage({
    required String? avatarUrl,
    required String initials,
    double size = 58,
    double fontSize = 21,
  }) {
    ImageProvider? imageProvider;
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      final trimmed = avatarUrl.trim();
      if (trimmed.startsWith('assets/')) {
        imageProvider = AssetImage(trimmed);
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        imageProvider = NetworkImage(trimmed);
      } else if (File(trimmed).existsSync()) {
        imageProvider = FileImage(File(trimmed));
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const borderWidth = 2.4;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(borderWidth),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppTheme.accentLime,
            AppTheme.accentLime,
            Colors.white,
            Colors.white,
          ],
          stops: [0.0, 0.5, 0.5, 1.0],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppTheme.darkSurface : AppTheme.accentLime,
          image: imageProvider != null
              ? DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: imageProvider == null
            ? Text(
                initials,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : AppTheme.primaryBlack,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              )
            : null,
      ),
    );
  }

  void _showEditProfileModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = _profileData?.profile;

    final nameCtrl = TextEditingController(text: current?.fullName ?? 'Kelvin Matheka');
    final emailCtrl = TextEditingController(text: current?.email ?? 'kelvin@entree.app');
    final roleCtrl = TextEditingController(text: current?.role ?? 'Event Owner');
    final orgCtrl = TextEditingController(text: current?.organization ?? 'Entrée');
    final phoneCtrl = TextEditingController(text: current?.phone ?? '+254 700 000 000');
    final bioCtrl = TextEditingController(text: current?.bio ?? 'Senior Event Coordinator & Gate Host');
    String? currentAvatar = current?.avatarUrl;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -2)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Edit Profile',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Update your profile, bio, and avatar.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Avatar with Camera Tap Trigger
                    Center(
                      child: Stack(
                        children: [
                          _buildAvatarImage(
                            avatarUrl: currentAvatar,
                            initials: current?.initials ?? 'KM',
                            size: 80,
                            fontSize: 28,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () async {
                                final path = await MediaHelper.pickAndCropImage(
                                  context,
                                  cropType: CropPresetType.avatar,
                                );
                                if (path != null) {
                                  setModalState(() {
                                    currentAvatar = path;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkCard : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 15,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Tap camera icon to change photo (1:1 crop)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildProfileInputField('Full Name', nameCtrl, isDark, Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildProfileInputField('Email Address', emailCtrl, isDark, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildProfileInputField('Job Title / Role', roleCtrl, isDark, Icons.badge_outlined),
                    const SizedBox(height: 12),
                    _buildProfileInputField('Organization', orgCtrl, isDark, Icons.business_outlined),
                    const SizedBox(height: 12),
                    _buildProfileInputField('Phone Number', phoneCtrl, isDark, Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _buildProfileInputField('Bio / Role Notes', bioCtrl, isDark, Icons.edit_note_outlined, maxLines: 3),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                final updated = await ApiService.instance.updateProfile(
                                  fullName: nameCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  role: roleCtrl.text.trim(),
                                  organization: orgCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                  bio: bioCtrl.text.trim(),
                                  avatarUrl: currentAvatar,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                if (mounted && updated != null) {
                                  setState(() {
                                    if (_profileData != null) {
                                      _profileData = _profileData!.copyWith(profile: updated);
                                    }
                                  });
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlack, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Profile updated successfully!',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryBlack,
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppTheme.accentLime,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentLime,
                          foregroundColor: AppTheme.primaryBlack,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryBlack,
                                ),
                              )
                            : Text(
                                'Save Profile',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileInputField(
    String label,
    TextEditingController controller,
    bool isDark,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
              prefixIcon: Icon(
                icon,
                size: 18,
                color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildThemeModeSelector(bool isDark) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, currentMode, _) {
        final isDarkMode = currentMode == ThemeMode.dark ||
            (currentMode == ThemeMode.system && isDark);

        final subtitle = currentMode == ThemeMode.system
            ? 'System default (${isDark ? 'Dark' : 'Light'})'
            : (isDarkMode ? 'Dark theme enabled' : 'Light theme enabled');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppTheme.darkSurface
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
                      subtitle,
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
              // iOS Adaptive Switch in Electric Lime
              Switch.adaptive(
                value: isDarkMode,
                activeThumbColor: AppTheme.primaryBlack,
                activeTrackColor: AppTheme.accentLime,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: isDark
                    ? AppTheme.darkCardBorder
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
    final accentColor = isDark ? AppTheme.accentLime : AppTheme.accentLimeDark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVibrant
              ? AppTheme.accentLime.withValues(alpha: isDark ? 0.35 : 0.6)
              : (isDark ? AppTheme.darkCardBorder : AppTheme.borderLight),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isVibrant
                ? AppTheme.accentLime.withValues(alpha: isDark ? 0.12 : 0.08)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isVibrant
                ? accentColor
                : (isDark ? AppTheme.darkTextPrimary : AppTheme.primaryBlack),
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
                color: isVibrant
                    ? accentColor
                    : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
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

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor ?? (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
          size: 19,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
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
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
            size: 18,
          ),
      onTap: onTap,
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
                  child: _buildDarkNavItem(0, Icons.explore_outlined, 'Events')),
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
                  'Manage hosted events and gate check-in schedule',
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
                                      ? AppTheme.darkSurface
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
                            ).then((_) => _refreshAllData());
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
          ).then((_) => _refreshAllData());
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
        _refreshAllData();
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

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

// ---------------------------------------------------------------------------
// SLIDING MARQUEE LOCATION TICKER
// Continuously and slowly slides location text to the left while keeping
// the location pin intact and fixed on the left.
// ---------------------------------------------------------------------------
class SlidingMarqueeLocation extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const SlidingMarqueeLocation({
    super.key,
    required this.text,
    this.style,
  });

  @override
  State<SlidingMarqueeLocation> createState() => _SlidingMarqueeLocationState();
}

class _SlidingMarqueeLocationState extends State<SlidingMarqueeLocation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant SlidingMarqueeLocation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? const TextStyle(fontSize: 11);
    const separator = '   ·   ';
    final token = '${widget.text}$separator';

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: token, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final tokenWidth = textPainter.width;
        if (tokenWidth <= 0) {
          return Text(widget.text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
        }

        return SizedBox(
          height: textPainter.height + 4,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-_controller.value * tokenWidth, 0),
                  child: child,
                );
              },
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: textPainter.height + 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(token, style: style, maxLines: 1),
                    Text(token, style: style, maxLines: 1),
                    Text(token, style: style, maxLines: 1),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


