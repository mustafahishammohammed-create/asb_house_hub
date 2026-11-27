import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/campus_event.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Screen for displaying Campus House Events, filters, the live-event HUD, and details.
class EventsScreen extends StatefulWidget {
  final String userHouse;
  final DateTime? mockNow;

  const EventsScreen({super.key, this.userHouse = 'emerald', this.mockNow});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _authService = AuthService();
  final _searchController = TextEditingController();
  late final bool _isStaff;
  late final String _uid;
  late final String _studentName;
  late final String _scholarNo;
  late final int? _viewerGrade;
  late Stream<List<CampusEvent>> _eventsStream;
  Timer? _tickerTimer;
  EventCategory _selectedCategory = EventCategory.all;
  String _searchQuery = '';
  String _selectedHouse = 'any';

  @override
  void initState() {
    super.initState();
    final profile = AuthService.getCachedProfile();
    final role = AuthService.getCachedRole();
    final scholarNo = AuthService.getCachedScholarNo();
    _isStaff =
        HierarchyService.isSuperAdmin(scholarNo: scholarNo, role: role) ||
        HierarchyService.isTeacherOrFaculty(scholarNo: scholarNo, role: role);
    _uid = AuthService.getCachedUid() ?? _authService.currentUser?.uid ?? '';
    _studentName =
        (profile?['full_name'] ?? _authService.currentUser?.displayName ?? '')
            .toString();
    _scholarNo = scholarNo ?? '';
    _viewerGrade = _isStaff ? null : AuthService.getViewerGradeIndex();
    _eventsStream = _authService.getEventsStream(
      house: widget.userHouse,
      includeDrafts: _isStaff,
      gradeIndex: _viewerGrade,
    );
    if (widget.mockNow == null) {
      _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  DateTime get _now => widget.mockNow ?? DateTime.now();

  Future<void> _reloadEvents({required bool seedSamples}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (seedSamples) {
      await AuthService.cacheEvents(AuthService.getFoundationalEvents());
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sample campus events loaded on this device only.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Reloading campus events from Firestore...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
      if (mounted) {
        _eventsStream = _authService.getEventsStream(
          house: widget.userHouse,
          includeDrafts: _isStaff,
          gradeIndex: _viewerGrade,
        );
        setState(() {});
      }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final houseColor = HouseColors.getHouseColor(widget.userHouse);
    final viewerHouse = AuthService.normalizeCampusHouse(widget.userHouse);
    final cachedEvents = AuthService.getCachedEvents()
        .where(
          (event) =>
              (event.status != CampusEventStatus.draft || _isStaff) &&
              (_isStaff ||
                  (AuthService.normalizeCampusHouse(event.houseScope) ==
                          'all' ||
                      AuthService.normalizeCampusHouse(event.houseScope) ==
                          viewerHouse)) &&
              AuthService.eventMatchesGrade(event, _viewerGrade),
        )
        .toList();
    final now = _now;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Campus House Events',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload Campus Events',
            onPressed: () =>
                _reloadEvents(seedSamples: !AuthService.isFirebaseLive),
          ),
          if (_isStaff)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Publish Campus Event',
              onPressed: () => _showEventComposer(context, houseColor),
            ),
        ],
      ),
      body: StreamBuilder<List<CampusEvent>>(
        initialData: cachedEvents,
        stream: _eventsStream,
        builder: (context, snapshot) {
          final events = snapshot.data ?? cachedEvents;
          final filtered = events.where((e) {
            final matchesCat =
                _selectedCategory == EventCategory.all ||
                e.category == _selectedCategory;
            final matchesHouse =
                _selectedHouse == 'any' ||
                AuthService.normalizeCampusHouse(e.houseScope) ==
                    _selectedHouse;
            final matchesSearch =
                _searchQuery.isEmpty ||
                e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.venue.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
            return matchesCat && matchesHouse && matchesSearch;
          }).toList()
            ..sort((a, b) {
              int rank(CampusEvent ev) {
                if (ev.isLiveAt(now) || ev.isOngoingAt(now)) return 0;
                if (ev.isDraft) return 2;
                if (ev.isCancelled) return 3;
                if (ev.isConcludedAt(now)) return 4;
                return 1; // Upcoming
              }

              final rA = rank(a);
              final rB = rank(b);
              if (rA != rB) return rA.compareTo(rB);
              if (rA == 4) return b.startTime.compareTo(a.startTime);
              return a.startTime.compareTo(b.startTime);
            });

          final liveEvents = events
              .where((e) => e.isLiveAt(now) || e.isOngoingAt(now))
              .toList();
          final upcomingCount = events
              .where(
                (e) =>
                    !e.isCancelled &&
                    !e.isDraft &&
                    !e.isConcludedAt(now) &&
                    !e.isLiveAt(now) &&
                    !e.isOngoingAt(now),
              )
              .length;
          final hasActiveFilters =
              _selectedCategory != EventCategory.all ||
              _selectedHouse != 'any' ||
              _searchQuery.isNotEmpty;

          return FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPad = constraints.maxWidth > 1020
                    ? (constraints.maxWidth - 980) / 2
                    : 0.0;
                final isWide = constraints.maxWidth - (horizontalPad * 2) >= 720;

                return CustomScrollView(
                  slivers: [
                    // Campus Events Overview Strip
                    if (events.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16 + horizontalPad,
                            6,
                            16 + horizontalPad,
                            6,
                          ),
                          child: _buildOverviewBanner(
                            houseColor: houseColor,
                            isDark: isDark,
                            totalCount: events.length,
                            liveCount: liveEvents.length,
                            upcomingCount: upcomingCount,
                            hasActiveFilters: hasActiveFilters,
                          ),
                        ),
                      ),

                    // Live event HUD. This is a schedule indicator, not a media
                    // stream: tapping it opens the normal event details.
                    if (liveEvents.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16 + horizontalPad,
                            vertical: 8,
                          ),
                          child: _buildLiveStageHUD(
                            liveEvents,
                            houseColor,
                            isDark,
                            now,
                          ),
                        ),
                      ),

                    if (snapshot.hasError)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: _buildStreamError(isDark),
                        ),
                      ),

                    // Category Filter Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          8,
                          horizontalPad,
                          8,
                        ),
                        child: _buildCategoryFilterBar(
                          events,
                          houseColor,
                          isDark,
                        ),
                      ),
                    ),

                    // House Scope Filter Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          0,
                          horizontalPad,
                          4,
                        ),
                        child: _buildHouseFilterBar(houseColor, isDark),
                      ),
                    ),

                    // Search Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16 + horizontalPad,
                          vertical: 8,
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search events, stages, venues...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: houseColor,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (v) =>
                              setState(() => _searchQuery = v.trim()),
                        ),
                      ),
                    ),

                    // Events List / Responsive Desktop 2-Column Rows / Empty State
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: _buildEmptyState(
                            isDark,
                            hasActiveFilters:
                                hasActiveFilters && events.isNotEmpty,
                          ),
                        ),
                      )
                    else if (isWide)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16 + horizontalPad,
                          10,
                          16 + horizontalPad,
                          24,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, rowIndex) {
                              final firstIdx = rowIndex * 2;
                              final secondIdx = firstIdx + 1;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildEventCard(
                                      filtered[firstIdx],
                                      houseColor,
                                      isDark,
                                      now,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: secondIdx < filtered.length
                                        ? _buildEventCard(
                                            filtered[secondIdx],
                                            houseColor,
                                            isDark,
                                            now,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              );
                            },
                            childCount: (filtered.length + 1) ~/ 2,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16 + horizontalPad,
                          10,
                          16 + horizontalPad,
                          24,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final event = filtered[index];
                              return _buildEventCard(
                                event,
                                houseColor,
                                isDark,
                                now,
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewBanner({
    required Color houseColor,
    required bool isDark,
    required int totalCount,
    required int liveCount,
    required int upcomingCount,
    required bool hasActiveFilters,
  }) {
    final houseLabel = widget.userHouse.trim().isEmpty
        ? 'Campus'
        : '${widget.userHouse[0].toUpperCase()}${widget.userHouse.substring(1).toLowerCase()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), houseColor.withValues(alpha: 0.22)]
              : [Colors.white, houseColor.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: houseColor.withValues(alpha: isDark ? 0.35 : 0.22),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: houseColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.campaign_rounded, color: houseColor, size: 20),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$houseLabel Events Pulse',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '$totalCount scheduled • $upcomingCount upcoming${liveCount > 0 ? ' • $liveCount live' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasActiveFilters)
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = EventCategory.all;
                  _selectedHouse = 'any';
                });
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text(
                'Reset filters',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStreamError(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Live campus schedule unavailable. Showing previously loaded events.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseFilterBar(Color houseColor, bool isDark) {
    const houses = <String>[
      'any',
      'all',
      'ruby',
      'sapphire',
      'emerald',
      'topaz',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'House:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
          ...houses.map((scope) {
            final selected = _selectedHouse == scope;
            final cleanScope = scope.trim();
            final label = cleanScope == 'any'
                ? 'All'
                : cleanScope == 'all'
                ? 'School-wide'
                : cleanScope.isEmpty
                ? 'House'
                : '${cleanScope[0].toUpperCase()}${cleanScope.substring(1)}';
            final color = scope == 'any' || scope == 'all'
                ? houseColor
                : HouseColors.getHouseColor(scope);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: selected,
                label: scope == 'any'
                    ? 'Show events from every house'
                    : scope == 'all'
                    ? 'Show school-wide events'
                    : 'Show $label house events',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedHouse = scope),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? color
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? color
                              : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155)),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLiveStageHUD(
    List<CampusEvent> liveEvents,
    Color houseColor,
    bool isDark,
    DateTime now,
  ) {
    final firstLive = liveEvents.first;
    return Semantics(
      liveRegion: true,
      label:
          'Live event: ${firstLive.title} is ongoing now at ${firstLive.venue}. Tap for event details.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _showEventDetailsModal(context, firstLive, houseColor, now),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade900.withValues(alpha: 0.85),
                  isDark ? const Color(0xFF1E293B) : Colors.red.shade700,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'HAPPENING NOW',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      firstLive.formattedRemaining,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  firstLive.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        firstLive.venue,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (liveEvents.length > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${liveEvents.length - 1} more live',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                    if (firstLive.pointsMultiplier > 1.0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${firstLive.pointsMultiplier}x Points',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar(
    List<CampusEvent> events,
    Color houseColor,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: EventCategory.values.map((cat) {
          final isSelected = _selectedCategory == cat;
          final count = cat == EventCategory.all
              ? events.length
              : events.where((e) => e.category == cat).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              label: 'Filter by ${cat.displayName}',
              selected: isSelected,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: InkWell(
                  onTap: () => setState(() => _selectedCategory = cat),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? houseColor
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? houseColor
                            : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: houseColor.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat.displayName,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF334155)),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF334155)),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(CampusEvent event, DateTime now) {
    late final String label;
    late final Color color;
    if (event.isCancelled) {
      label = 'CANCELLED';
      color = Colors.red;
    } else if (event.isDraft) {
      label = 'DRAFT';
      color = Colors.orange;
    } else if (event.isConcludedAt(now)) {
      label = 'CONCLUDED';
      color = Colors.blueGrey;
    } else if (event.isLiveAt(now)) {
      label = 'LIVE NOW';
      color = Colors.redAccent;
    } else if (now.isBefore(event.startTime)) {
      label = 'UPCOMING';
      color = Colors.blue;
    } else {
      label = 'ONGOING';
      color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 9.5,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  String _remainingLabel(CampusEvent event, DateTime now) {
    if (event.isCancelled) return 'Cancelled';
    if (event.isDraft) return 'Draft';
    if (event.isConcludedAt(now)) return 'Concluded';
    if (now.isBefore(event.startTime)) {
      final until = event.startTime.difference(now);
      if (until.inDays > 0) return 'Starts in ${until.inDays}d';
      if (until.inHours > 0) return 'Starts in ${until.inHours}h';
      return 'Starts in ${until.inMinutes}m';
    }
    final rem = event.endTime.difference(now);
    if (rem.inHours > 0) {
      return '${rem.inHours}h ${rem.inMinutes % 60}m remaining';
    }
    return '${rem.inMinutes}m remaining';
  }

  Widget _buildEventCard(
    CampusEvent event,
    Color houseColor,
    bool isDark,
    DateTime now,
  ) {
    final normalizedScope = AuthService.normalizeCampusHouse(event.houseScope);
    final accentColor = normalizedScope != 'all'
        ? HouseColors.getHouseColor(event.houseScope)
        : houseColor;
    final startLocal = event.startTime.toLocal();
    const months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final monthShort = months[startLocal.month - 1];
    final dayNumber = startLocal.day.toString().padLeft(2, '0');
    final isLive = event.isLiveAt(now) || event.isOngoingAt(now);
    final isConcluded = event.isConcludedAt(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isLive ? Colors.redAccent : Colors.black).withValues(
              alpha: isLive ? 0.14 : (isDark ? 0.25 : 0.05),
            ),
            blurRadius: isLive ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isLive
              ? Colors.redAccent.withValues(alpha: 0.55)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showEventDetailsModal(context, event, houseColor, now),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Image (using Resilient Photo Engine) or clean accent strip
              if (event.bannerUrl.isNotEmpty)
                HomeScreen.buildResilientImage(
                  event.bannerUrl,
                  height: 164,
                )
              else
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.category.displayName.toUpperCase(),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : accentColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (normalizedScope != 'all')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${event.houseScope.toUpperCase()} EXCLUSIVE',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        if (!event.targetsAllGrades)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              event.gradeRangeLabel.toUpperCase(),
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF2DD4BF)
                                    : const Color(0xFF0F766E),
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        _buildStatusBadge(event, now),
                        if (event.pointsMultiplier > 1.0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(
                                alpha: isDark ? 0.2 : 0.18,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: Text(
                              '${event.pointsMultiplier}x Points',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.amber
                                    : const Color(0xFF92400E),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Calendar Date Tile + Event Title & Schedule
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: const BoxConstraints(minWidth: 50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isConcluded
                                ? (isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9))
                                : accentColor.withValues(
                                    alpha: isDark ? 0.16 : 0.09,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isConcluded
                                  ? (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1))
                                  : accentColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                monthShort,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: isConcluded
                                      ? (isDark
                                            ? Colors.white54
                                            : const Color(0xFF64748B))
                                      : accentColor,
                                ),
                              ),
                              Text(
                                dayNumber,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  color: isConcluded
                                      ? (isDark
                                            ? Colors.white60
                                            : const Color(0xFF475569))
                                      : (isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
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
                              Text(
                                event.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16.5,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatDateTime(event.startTime),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        event.description,
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : const Color(0xFF475569),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.venue,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _remainingLabel(event, now),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (event.pointsAwarded > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${event.pointsAwarded} PTS',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.greenAccent
                                      : const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  void _showEventDetailsModal(
    BuildContext context,
    CampusEvent event,
    Color houseColor,
    DateTime now,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var registrationBusy = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(ctx).viewInsets.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (event.bannerUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: HomeScreen.buildResilientImage(
                              event.bannerUrl,
                              height: 160,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: houseColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  event.category.displayName.toUpperCase(),
                                  style: TextStyle(
                                    color: houseColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (AuthService.normalizeCampusHouse(
                                    event.houseScope,
                                  ) !=
                                  'all')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HouseColors.getHouseColor(
                                      event.houseScope,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${event.houseScope.toUpperCase()} EXCLUSIVE',
                                    style: TextStyle(
                                      color: HouseColors.getHouseColor(
                                        event.houseScope,
                                      ),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              if (!event.targetsAllGrades)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    event.gradeRangeLabel.toUpperCase(),
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF2DD4BF)
                                          : const Color(0xFF0F766E),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              _buildStatusBadge(event, now),
                              if (event.pointsMultiplier > 1.0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber),
                                  ),
                                  child: Text(
                                    '${event.pointsMultiplier}x Points',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.amber
                                          : const Color(0xFF92400E),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 12),
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _remainingLabel(event, now),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      event.description.isNotEmpty
                          ? event.description
                          : 'A campus event hosted at The Asian School Bahrain. Contact the organising staff for participation details.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${_formatDateTime(event.startTime)} – ${_formatDateTime(event.endTime)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (event.isCancelled) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        event.cancelledReason.isNotEmpty
                            ? 'This event was cancelled by the organising staff. '
                                  'Reason: ${event.cancelledReason}. '
                                  'Registration is closed.'
                            : 'This event was cancelled by the organising staff. Registration is closed.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                  if (event.isDraft) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Private staff draft. Students cannot see this event until it is published.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                  if (_isStaff) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Staff controls',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit_rounded, size: 17),
                            label: const Text(
                              'Edit Event',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _showEventComposer(
                                context,
                                houseColor,
                                existing: event,
                              );
                            },
                          ),
                        ),
                        if (!event.isCancelled) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.event_busy_rounded,
                                size: 17,
                              ),
                              label: const Text(
                                'Cancel Event',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _confirmCancelEvent(event);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildAttendeesSection(event, isDark),
                  ] else if (!event.isDraft) ...[
                    const SizedBox(height: 20),
                    StreamBuilder<bool>(
                      stream: _uid.isEmpty
                          ? Stream.value(false)
                          : _authService.getEventRegistrationStream(
                              eventId: event.id,
                              uid: _uid,
                            ),
                      builder: (context, regSnapshot) {
                        if (regSnapshot.hasError) {
                          return const Text(
                            'Could not load your registration status.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }
                        final isRegistered = regSnapshot.data ?? false;
                        final blocked =
                            event.isCancelled ||
                            event.isConcludedAt(now) ||
                            registrationBusy ||
                            _uid.isEmpty;
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: registrationBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isRegistered
                                        ? Icons.check_circle_rounded
                                        : Icons.how_to_reg_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              _uid.isEmpty
                                  ? 'Sign in to register'
                                  : event.isCancelled
                                  ? 'Registration closed'
                                  : event.isConcludedAt(now)
                                  ? 'Event concluded'
                                  : isRegistered
                                  ? 'Registered — tap to withdraw'
                                  : 'Register / RSVP',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRegistered
                                  ? Colors.green
                                  : houseColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: blocked
                                ? null
                                : () async {
                                    setModalState(
                                      () => registrationBusy = true,
                                    );
                                    final ok = await _authService
                                        .setEventRegistration(
                                          eventId: event.id,
                                          uid: _uid,
                                          register: !isRegistered,
                                          studentName: _studentName,
                                          scholarNo: _scholarNo,
                                        );
                                    if (ctx.mounted) {
                                      setModalState(
                                        () => registrationBusy = false,
                                      );
                                    }
                                    if (!mounted) return;
                                    _showMessage(
                                      !ok
                                          ? 'Could not update your registration. Check your connection and try again.'
                                          : isRegistered
                                          ? 'Registration withdrawn for "${event.title}".'
                                          : 'Registration confirmed for "${event.title}".',
                                      error: !ok,
                                    );
                                  },
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text(
                        'Copy event details',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () async {
                        final eventInfo =
                            'Event: ${event.title}\n'
                            'Venue: ${event.venue}\n'
                            'Starts: ${event.startTime.toLocal()}\n'
                            'Ends: ${event.endTime.toLocal()}\n'
                            'House: ${event.houseScope} • Reward: +${event.pointsAwarded} PTS\n'
                            'Grades: ${event.gradeRangeLabel}\n'
                            'Brief: ${event.description}';
                        await Clipboard.setData(ClipboardData(text: eventInfo));
                        if (!mounted) return;
                        _showMessage('Event details copied to clipboard.');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
          ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, $hour:$minute $suffix';
  }

  Widget _buildAttendeesSection(CampusEvent event, bool isDark) {
    if (!AuthService.isFirebaseLive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Participant records are stored in Firebase. Local sample events cannot collect RSVPs.',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      );
    }
    return StreamBuilder<List<EventRegistration>>(
      stream: _authService.getEventAttendeesStream(event.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Could not load the participant list.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Loading registrations...',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          );
        }
        final attendees = snapshot.data ?? const <EventRegistration>[];
        if (attendees.isEmpty) {
          return const Text(
            'No student registrations yet.',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          );
        }
        final shown = attendees.take(25).toList();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.04,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${attendees.length} registered participant${attendees.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              ...shown.map(
                (registration) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    registration.scholarNo.isNotEmpty
                        ? '${registration.studentName} (${registration.scholarNo})'
                        : registration.studentName,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
              if (attendees.length > shown.length)
                Text(
                  '+${attendees.length - shown.length} more',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmCancelEvent(CampusEvent event) async {
    if (!_isStaff || event.id.isEmpty) {
      _showMessage('Only staff can cancel a campus event.', error: true);
      return;
    }
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${event.title}" will remain visible with a cancelled badge. '
              'Students will no longer be able to register.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Venue unavailable',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Event'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text('Cancel Event'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;

    final ok = await _authService.cancelCampusEvent(event.id, reason: reason);
    if (!mounted) return;
    _showMessage(
      ok
          ? 'Event cancelled. Students can no longer register.'
          : 'Could not cancel the event. Check your staff access and try again.',
      error: !ok,
    );
    if (ok) setState(() {});
  }

  Widget _buildEmptyState(bool isDark, {bool hasActiveFilters = false}) {
    final houseColor = HouseColors.getHouseColor(widget.userHouse);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasActiveFilters
                  ? Icons.filter_list_off_rounded
                  : Icons.event_busy_rounded,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Events Scheduled',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'No events match your current search or filter selection.'
                  : 'Check back later for upcoming House competitions and campus rallies.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (hasActiveFilters)
                  ElevatedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedCategory = EventCategory.all;
                        _selectedHouse = 'any';
                      });
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text(
                      'Clear Filters',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: houseColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () async {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedCategory = EventCategory.all;
                        _selectedHouse = 'any';
                      });
                      await _reloadEvents(
                        seedSamples: !AuthService.isFirebaseLive,
                      );
                    },
                    icon: Icon(
                      AuthService.isFirebaseLive
                          ? Icons.refresh_rounded
                          : Icons.event_available_rounded,
                      size: 18,
                    ),
                    label: Text(
                      AuthService.isFirebaseLive
                          ? 'Retry Campus Events'
                          : 'Load Sample Events',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: houseColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                if (_isStaff)
                  OutlinedButton.icon(
                    onPressed: () => _showEventComposer(context, houseColor),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Publish Event',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Staff composer for creating, drafting, editing and publishing events.
  /// Students never reach this method; the entry points are staff-gated and
  /// the method guards again in case it is called indirectly.
  void _showEventComposer(
    BuildContext context,
    Color houseColor, {
    CampusEvent? existing,
  }) {
    if (!_isStaff) {
      _showMessage(
        'Only staff can publish or edit campus events.',
        error: true,
      );
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final venueController = TextEditingController(text: existing?.venue ?? '');
    final descController = TextEditingController(
      text: existing?.description ?? '',
    );
    final pointsController = TextEditingController(
      text: '${existing?.pointsAwarded ?? 150}',
    );
    final now = DateTime.now();
    final initialStart =
        existing?.startTime ??
        DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
        ).add(const Duration(hours: 2));
    var startTime = initialStart;
    var endTime =
        existing?.endTime ?? initialStart.add(const Duration(hours: 2));
    var selectedCat = existing != null && existing.category != EventCategory.all
        ? existing.category
        : EventCategory.cultural;
    var selectedScope = AuthService.normalizeCampusHouse(
      existing?.houseScope ?? 'all',
    );
    var selectedMultiplier = existing?.pointsMultiplier ?? 1.0;
    var isLiveEvent = existing?.isLive ?? false;
    var limitGrades = existing != null && !existing.targetsAllGrades;
    var selectedGradeMin = limitGrades ? existing.gradeMin : 1;
    var selectedGradeMax = limitGrades ? existing.gradeMax : 12;
    var saving = false;

    String scopeLabel(String scope) {
      final clean = scope.trim();
      if (clean == 'all') return 'School-wide';
      if (clean.isEmpty) return 'House';
      return '${clean[0].toUpperCase()}${clean.substring(1)} House';
    }

    String gradeLabel(int grade) => grade <= 0 ? 'LKG/UKG' : 'Grade $grade';

    String gradeRangeLabel(int min, int max) => min == max
        ? gradeLabel(min)
        : '${gradeLabel(min)} – ${gradeLabel(max)}';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<DateTime?> pickDateTime(DateTime initial) async {
            final minDate = DateTime(now.year - 1);
            final maxDate = DateTime(now.year + 3);
            final clampedInitial = initial.isBefore(minDate)
                ? minDate
                : (initial.isAfter(maxDate) ? maxDate : initial);
            final date = await showDatePicker(
              context: ctx,
              initialDate: clampedInitial,
              firstDate: minDate,
              lastDate: maxDate,
            );
            if (date == null) return null;
            if (!ctx.mounted) return null;
            final time = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay.fromDateTime(clampedInitial),
            );
            if (time == null) return null;
            return DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
          }

          Future<void> persist(CampusEventStatus status) async {
            if (saving) return;
            final points = int.tryParse(pointsController.text.trim());
            if (points == null) {
              _showMessage('Enter points as a whole number.', error: true);
              return;
            }
            final draftEvent = CampusEvent(
              id: existing?.id ?? '',
              title: titleController.text.trim(),
              description: descController.text.trim(),
              category: selectedCat,
              houseScope: selectedScope,
              startTime: startTime,
              endTime: endTime,
              venue: venueController.text.trim(),
              pointsAwarded: points,
              pointsMultiplier: selectedMultiplier,
              bannerUrl: existing?.bannerUrl ?? '',
              isLive: isLiveEvent,
              status: status,
              createdAt: existing?.createdAt,
              authorUid: existing?.authorUid ?? _uid,
              authorName: existing?.authorName ?? _studentName,
              gradeMin: limitGrades ? selectedGradeMin : 0,
              gradeMax: limitGrades ? selectedGradeMax : 12,
            );
            final validation = AuthService.validateCampusEvent(draftEvent);
            if (validation != null) {
              _showMessage(validation, error: true);
              return;
            }
            if (!AuthService.isFirebaseLive &&
                status == CampusEventStatus.draft) {
              _showMessage(
                'Private drafts need a live Firebase connection. '
                'Publish to save this event on the device instead.',
                error: true,
              );
              return;
            }
            setModalState(() => saving = true);
            final wasLive = AuthService.isFirebaseLive;
            final ok = existing == null
                ? await _authService.createCampusEvent(draftEvent)
                : await _authService.updateCampusEvent(draftEvent);
            if (!ctx.mounted) return;
            setModalState(() => saving = false);
            if (!ok) {
              _showMessage(
                'Could not save "${draftEvent.title}". Check your staff '
                'access, required fields, and connection.',
                error: true,
              );
              return;
            }
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
            final action = status == CampusEventStatus.draft
                ? 'Draft saved. Only staff can see it.'
                : wasLive
                ? (existing == null
                      ? 'Event published to the campus schedule.'
                      : 'Event changes saved.')
                : 'Event saved on this device only. '
                      'Campus sync needs Firebase.';
            _showMessage(action);
            setState(() {});
          }

          Future<void> previewAndPublish() async {
            final points = int.tryParse(pointsController.text.trim());
            final preview = CampusEvent(
              id: existing?.id ?? 'preview',
              title: titleController.text.trim(),
              description: descController.text.trim(),
              category: selectedCat,
              houseScope: selectedScope,
              startTime: startTime,
              endTime: endTime,
              venue: venueController.text.trim(),
              pointsAwarded: points ?? 0,
              pointsMultiplier: selectedMultiplier,
              status: CampusEventStatus.published,
              gradeMin: limitGrades ? selectedGradeMin : 0,
              gradeMax: limitGrades ? selectedGradeMax : 12,
            );
            final needsPreview =
                existing == null || existing.isDraft || existing.isCancelled;
            if (!needsPreview) {
              await persist(existing.status);
              return;
            }
            final validation = AuthService.validateCampusEvent(preview);
            if (validation != null) {
              _showMessage(validation, error: true);
              return;
            }
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Publish this event?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text('Venue: ${preview.venue}'),
                    Text('Starts: ${_formatDateTime(preview.startTime)}'),
                    Text('Ends: ${_formatDateTime(preview.endTime)}'),
                    Text('Audience: ${scopeLabel(selectedScope)}'),
                    Text(
                      'Grades: ${limitGrades ? gradeRangeLabel(selectedGradeMin, selectedGradeMax) : 'All grades'}',
                    ),
                    Text('Category: ${preview.category.displayName}'),
                    Text(
                      'Reward: +${preview.pointsAwarded} points '
                      '(x${preview.pointsMultiplier.toStringAsFixed(1)})',
                    ),
                    if (preview.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        preview.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Keep Editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Publish'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            await persist(CampusEventStatus.published);
          }

          final primaryLabel = existing == null
              ? 'Preview & Publish'
              : existing.isDraft || existing.isCancelled
              ? 'Preview & Publish'
              : 'Save Changes';
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    existing == null
                        ? 'Publish Campus Event'
                        : existing.isDraft
                        ? 'Edit Private Draft'
                        : 'Edit Campus Event',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    existing == null
                        ? 'Staff-only. Preview, save a private draft, or publish to the campus schedule.'
                        : 'Changes are validated against the same rules as publication.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: 'Event Title',
                      hintText: 'e.g. Inter-House Debate Championship',
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<EventCategory>(
                          initialValue: selectedCat,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: EventCategory.values
                              .where((c) => c != EventCategory.all)
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.displayName),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => selectedCat = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedScope,
                          decoration: InputDecoration(
                            labelText: 'House Scope',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('School-wide'),
                            ),
                            DropdownMenuItem(
                              value: 'ruby',
                              child: Text('Ruby'),
                            ),
                            DropdownMenuItem(
                              value: 'sapphire',
                              child: Text('Sapphire'),
                            ),
                            DropdownMenuItem(
                              value: 'emerald',
                              child: Text('Emerald'),
                            ),
                            DropdownMenuItem(
                              value: 'topaz',
                              child: Text('Topaz'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => selectedScope = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      value: limitGrades,
                      onChanged: (value) {
                        setModalState(() {
                          limitGrades = value;
                          if (value) {
                            selectedGradeMin = 1;
                            selectedGradeMax = 12;
                          }
                        });
                      },
                      title: const Text(
                        'Limit to a grade range',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        limitGrades
                            ? gradeRangeLabel(
                                selectedGradeMin,
                                selectedGradeMax,
                              )
                            : 'All grades can see this event',
                        style: const TextStyle(fontSize: 12),
                      ),
                      dense: true,
                    ),
                  ),
                  if (limitGrades) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('grade_from_$selectedGradeMin'),
                            initialValue: selectedGradeMin,
                            decoration: InputDecoration(
                              labelText: 'From grade',
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: List<DropdownMenuItem<int>>.generate(
                              13,
                              (index) => DropdownMenuItem(
                                value: index,
                                child: Text(gradeLabel(index)),
                              ),
                            ),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() {
                                selectedGradeMin = value;
                                if (selectedGradeMax < value) {
                                  selectedGradeMax = value;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('grade_to_$selectedGradeMax'),
                            initialValue: selectedGradeMax,
                            decoration: InputDecoration(
                              labelText: 'To grade',
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: List<DropdownMenuItem<int>>.generate(
                              13,
                              (index) => DropdownMenuItem(
                                value: index,
                                child: Text(gradeLabel(index)),
                              ),
                            ),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() {
                                selectedGradeMax = value;
                                if (selectedGradeMin > value) {
                                  selectedGradeMin = value;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: venueController,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: 'Venue / Stage',
                            hintText: 'e.g. Auditorium Stage A',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: pointsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Points Awarded',
                            hintText: '150',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          initialValue: selectedMultiplier,
                          decoration: InputDecoration(
                            labelText: 'Points Multiplier',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 1.0,
                              child: Text('1.0x Normal'),
                            ),
                            DropdownMenuItem(
                              value: 1.5,
                              child: Text('1.5x Derby'),
                            ),
                            DropdownMenuItem(
                              value: 2.0,
                              child: Text('2.0x Feature'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => selectedMultiplier = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_rounded, size: 17),
                          label: Text(
                            'Starts\n${_formatDateTime(startTime)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await pickDateTime(startTime);
                            if (picked == null || !ctx.mounted) return;
                            setModalState(() {
                              startTime = picked;
                              if (!endTime.isAfter(startTime)) {
                                endTime = startTime.add(
                                  const Duration(hours: 2),
                                );
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_busy_rounded, size: 17),
                          label: Text(
                            'Ends\n${_formatDateTime(endTime)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await pickDateTime(endTime);
                            if (picked == null || !ctx.mounted) return;
                            setModalState(() => endTime = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    maxLength: 3000,
                    decoration: InputDecoration(
                      labelText: 'Description & House Guidelines',
                      hintText:
                          'Rules, participant criteria, and schedule brief...',
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      title: const Text(
                        'Highlight as live while it is running',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'The live badge only shows between the start and end time.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isLiveEvent,
                      onChanged: (val) =>
                          setModalState(() => isLiveEvent = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (!AuthService.isFirebaseLive) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Local mode: published events stay on this device. '
                      'Private drafts require Firebase.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              existing == null ||
                                      existing.isDraft ||
                                      existing.isCancelled
                                  ? Icons.send_rounded
                                  : Icons.save_rounded,
                              size: 18,
                            ),
                      label: Text(
                        primaryLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: houseColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: saving ? null : previewAndPublish,
                    ),
                  ),
                  if (existing == null || existing.isDraft) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 17),
                        label: const Text(
                          'Save Private Draft',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: saving || !AuthService.isFirebaseLive
                            ? null
                            : () => persist(CampusEventStatus.draft),
                      ),
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      titleController.dispose();
      venueController.dispose();
      descController.dispose();
      pointsController.dispose();
    });
  }
}
