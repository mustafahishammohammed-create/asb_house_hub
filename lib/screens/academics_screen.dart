import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../models/timetable_period.dart';
import '../models/academic_assignment.dart';
import '../models/exam_schedule_item.dart';
import '../models/academic_report_card.dart';
import '../models/attendance_record.dart';
import '../models/medical_leave_request.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../widgets/managed_modal_scope.dart';
import 'home_screen.dart';

/// School days in The Asian School Bahrain (Sunday through Thursday).
const List<String> kBahrainSchoolDays = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
];

/// Academic curriculum subjects taught at ASB.
const List<String> kAcademicSubjects = [
  'All',
  'Mathematics',
  'Physics',
  'Chemistry',
  'Computer Science',
  'English',
];

/// Full Academics Screen with Quint-Segment Tab Switcher for Class Timetable,
/// Homework Tracker, Mid-Term Examination Schedule, Term Report Cards, and Attendance Registry.
/// Provides pure dynamic period scheduling, live class indicators, and Frame-1 offline pre-hydration.
class AcademicsScreen extends StatefulWidget {
  final String? initialDay;
  final String? classLevel;
  final DateTime? mockNow;
  final List<TimetablePeriod>? initialPeriods;
  final String initialTab; // 'timetable', 'homework', 'exams', 'reports', 'attendance'
  final List<AcademicAssignment>? initialAssignments;
  final List<ExamScheduleItem>? initialExams;
  final List<AcademicReportCard>? initialReportCards;
  final List<AttendanceRecord>? initialAttendance;
  final String? scholarNo;
  final String? selectedSubject;
  final String? studentName;
  final String? userHouse;

  const AcademicsScreen({
    super.key,
    this.initialDay,
    this.classLevel,
    this.mockNow,
    this.initialPeriods,
    this.initialTab = 'timetable',
    this.initialAssignments,
    this.initialExams,
    this.initialReportCards,
    this.initialAttendance,
    this.scholarNo,
    this.selectedSubject,
    this.studentName,
    this.userHouse,
  });

  @override
  State<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends State<AcademicsScreen> {
  late String _activeTab;

  @override
  void initState() {
    super.initState();
    _resolveActiveTab(widget.initialTab);
  }

  @override
  void didUpdateWidget(AcademicsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _resolveActiveTab(widget.initialTab);
    }
  }

  void _resolveActiveTab(String initialTab) {
    final tab = initialTab.toLowerCase();
    if (tab == 'homework') {
      _activeTab = 'homework';
    } else if (tab == 'exams' || tab == 'exam') {
      _activeTab = 'exams';
    } else if (tab == 'reports' ||
        tab == 'report' ||
        tab == 'report_cards' ||
        tab == 'reportcards' ||
        tab == 'grades') {
      _activeTab = 'reports';
    } else if (tab == 'attendance' || tab == 'attend') {
      _activeTab = 'attendance';
    } else {
      _activeTab = 'timetable';
    }
  }

  Widget _buildResponsiveAcademicTabs(bool isDark) {
    final tabs = [
      (key: 'timetable', label: 'Class Timetable', semantics: 'Timetable Tab'),
      (key: 'homework', label: 'Homework Tracker', semantics: 'Homework Tab'),
      (key: 'exams', label: 'Exam Schedule', semantics: 'Exams Tab'),
      (key: 'reports', label: 'Report Cards', semantics: 'Report Cards Tab'),
      (key: 'attendance', label: 'Attendance', semantics: 'Attendance Tab'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _activeTab == tab.key;
            return Expanded(
              child: Semantics(
                button: true,
                selected: isSelected,
                label: tab.semantics,
                child: InkWell(
                  onTap: () => setState(() => _activeTab = tab.key),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF4338CA))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? (isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.white)
                                  : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cachedProfile = AuthService.getCachedProfile();
    final effectiveClass = widget.classLevel ??
        cachedProfile?['class_level']?.toString() ??
        'Grade 10';

    final tabSubtitle = _activeTab == 'timetable'
        ? 'Class Schedule'
        : (_activeTab == 'homework'
            ? 'Homework Tracker'
            : (_activeTab == 'exams'
                ? 'Exam Schedule'
                : (_activeTab == 'reports'
                    ? 'Term Report Cards'
                    : 'Attendance Registry')));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Campus Academics',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              '$effectiveClass • $tabSubtitle',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildResponsiveAcademicTabs(isDark),
        ),
      ),
      body: _activeTab == 'timetable'
          ? TimetableTab(
              classLevel: effectiveClass,
              initialDay: widget.initialDay,
              mockNow: widget.mockNow,
              initialPeriods: widget.initialPeriods,
            )
          : (_activeTab == 'homework'
              ? AssignmentsTab(
                  classLevel: effectiveClass,
                  selectedSubject: widget.selectedSubject,
                  mockNow: widget.mockNow,
                  initialAssignments: widget.initialAssignments,
                )
              : (_activeTab == 'exams'
                  ? ExamsTab(
                      classLevel: effectiveClass,
                      selectedSubject: widget.selectedSubject,
                      mockNow: widget.mockNow,
                      initialExams: widget.initialExams,
                    )
                  : (_activeTab == 'reports'
                      ? ReportCardTab(
                          classLevel: effectiveClass,
                          scholarNo: widget.scholarNo,
                          initialReportCards: widget.initialReportCards,
                        )
                      : AcademicAttendanceTab(
                          classLevel: effectiveClass,
                          scholarNo: widget.scholarNo,
                          initialAttendance: widget.initialAttendance,
                        )))),
    );
  }
}

/// Timetable Tab & Period Scheduler.
class TimetableTab extends StatefulWidget {
  final String? classLevel;
  final String? initialDay;
  final DateTime? mockNow;
  final List<TimetablePeriod>? initialPeriods;

  const TimetableTab({
    super.key,
    this.classLevel,
    this.initialDay,
    this.mockNow,
    this.initialPeriods,
  });

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  final AuthService _authService = AuthService();
  late String _selectedDay;
  late String _effectiveClass;
  Timer? _tickerTimer;
  int? _lastActivePeriodNumber;

  @override
  void initState() {
    super.initState();
    final profile = AuthService.getCachedProfile();
    _effectiveClass = widget.classLevel ?? profile?['class_level']?.toString() ?? 'Grade 10';

    if (widget.initialDay != null && kBahrainSchoolDays.contains(widget.initialDay)) {
      _selectedDay = widget.initialDay!;
    } else {
      _selectedDay = _getCurrentOrNextSchoolDay(widget.mockNow ?? DateTime.now());
    }

    _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  static String _getCurrentOrNextSchoolDay(DateTime now) {
    switch (now.weekday) {
      case DateTime.sunday:
        return 'Sunday';
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      default:
        return 'Sunday';
    }
  }

  DateTime get _currentTime => widget.mockNow ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = _currentTime;

    final cachedPeriods = (widget.initialPeriods != null && widget.initialPeriods!.isNotEmpty)
        ? widget.initialPeriods!
        : AuthService.getCachedTimetable(
            classLevel: _effectiveClass,
            dayOfWeek: _selectedDay,
          );

    return Column(
      children: [
        _buildWeekdaySelector(isDark),
        Expanded(
          child: StreamBuilder<List<TimetablePeriod>>(
            stream: _authService.getTimetableStream(
              classLevel: _effectiveClass,
              dayOfWeek: _selectedDay,
            ),
            initialData: cachedPeriods.isNotEmpty ? cachedPeriods : null,
            builder: (context, snapshot) {
              final periods = (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty)
                  ? snapshot.data!
                  : cachedPeriods;

              TimetablePeriod? activePeriod;
              TimetablePeriod? nextUpcomingPeriod;

              for (final p in periods) {
                if (p.isCurrentPeriod(now, true)) {
                  activePeriod = p;
                  break;
                }
              }

              if (activePeriod == null) {
                for (final p in periods) {
                  if (p.isUpcomingPeriod(now, true)) {
                    nextUpcomingPeriod = p;
                    break;
                  }
                }
              }

              if (activePeriod != null &&
                  _lastActivePeriodNumber != null &&
                  activePeriod.periodNumber != _lastActivePeriodNumber) {
                final view = View.maybeOf(context);
                if (view != null) {
                  SemanticsService.sendAnnouncement(
                    view,
                    'Period ${activePeriod.periodNumber}: ${activePeriod.subject} is now in progress in Room ${activePeriod.room}',
                    TextDirection.ltr,
                  );
                }
              }
              _lastActivePeriodNumber = activePeriod?.periodNumber;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activePeriod != null)
                      _buildActivePeriodCard(activePeriod, now, isDark)
                    else if (nextUpcomingPeriod != null)
                      _buildUpcomingPeriodCard(nextUpcomingPeriod, now, isDark)
                    else
                      _buildSchoolDaySummaryCard(periods, now, isDark),

                    const SizedBox(height: 20),

                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          '$_selectedDay Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (periods.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFEEF2F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${periods.length} Periods',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            FilledButton.icon(
                              key: const Key('add_period_button'),
                              onPressed: () => _showAddEditPeriodModal(),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                              style: FilledButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (periods.isEmpty)
                      _buildEmptyState(isDark)
                    else
                      ...periods.map((p) {
                        final isCurrent = activePeriod?.periodNumber == p.periodNumber;
                        return _buildPeriodCard(p, isCurrent, isDark);
                      }),

                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdaySelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: kBahrainSchoolDays.map((day) {
            final isSelected = _selectedDay == day;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                button: true,
                selected: isSelected,
                label: '$day Timetable',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDay = day),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA))
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA))
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          day.substring(0, 3).toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: isSelected
                                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActivePeriodCard(TimetablePeriod period, DateTime now, bool isDark) {
    final remainingStr = period.formattedRemaining(now);

    return Semantics(
      liveRegion: true,
      container: true,
      readOnly: true,
      label:
          'Period ${period.periodNumber}: ${period.subject} with ${period.teacherName} in Room ${period.room}. ${period.timeSlot}. Currently in progress. $remainingStr',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF132A24) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF34D399),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF34D399).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.play_circle_fill, size: 14, color: Color(0xFF064E3B)),
                        SizedBox(width: 5),
                        Text(
                          'IN PROGRESS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF064E3B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          remainingStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'P${period.periodNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        period.subject,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF064E3B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        period.timeSlot,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildInfoBadge(
                  icon: Icons.meeting_room_rounded,
                  label: period.room,
                  isDark: isDark,
                  badgeColor: const Color(0xFF059669),
                ),
                _buildInfoBadge(
                  icon: Icons.person_rounded,
                  label: period.teacherName,
                  isDark: isDark,
                  badgeColor: const Color(0xFF059669),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingPeriodCard(TimetablePeriod period, DateTime now, bool isDark) {
    final start = period.getStartDateTime(now);
    final diff = start?.difference(now);
    final countdownStr = (diff != null && diff.inMinutes > 0)
        ? 'Starts in ${diff.inMinutes}m'
        : 'Starting soon';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0284C7) : const Color(0xFF4338CA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.next_plan_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT: Period ${period.periodNumber} • ${period.subject}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${period.room} • $countdownStr (${period.timeSlot})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolDaySummaryCard(List<TimetablePeriod> periods, DateTime now, bool isDark) {
    final hasPeriods = periods.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasPeriods ? Icons.schedule_rounded : Icons.info_outline_rounded,
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasPeriods
                  ? 'No active period right now. Check individual times below.'
                  : 'No scheduled timetable for this day.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(TimetablePeriod period, bool isCurrent, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        readOnly: true,
        label:
            'Period ${period.periodNumber}: ${period.subject} with ${period.teacherName} in Room ${period.room}. ${period.timeSlot}.${isCurrent ? " Currently in progress" : ""}',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent
                ? (isDark ? const Color(0xFF132A24) : const Color(0xFFF0FDF4))
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFF34D399)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isCurrent ? 2 : 1,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF34D399)
                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'P${period.periodNumber}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isCurrent
                            ? const Color(0xFF064E3B)
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            period.subject,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34D399).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Teacher: ${period.teacherName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                period.timeSlot,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.meeting_room_outlined,
                                size: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                period.room,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.black54,
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'Edit Period ${period.periodNumber}',
                    child: IconButton(
                      key: Key('edit_period_${period.periodNumber}'),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                      tooltip: 'Edit Period',
                      onPressed: () => _showAddEditPeriodModal(period),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Delete Period ${period.periodNumber}',
                    child: IconButton(
                      key: Key('delete_period_${period.periodNumber}'),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.redAccent.withValues(alpha: 0.8),
                      ),
                      tooltip: 'Delete Period',
                      onPressed: () => _confirmDeletePeriod(period),
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

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 14),
          Text(
            'No timetable scheduled for this day.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Dynamic period schedules will appear automatically once published by school administration.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('empty_add_period_button'),
                onPressed: () => _showAddEditPeriodModal(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('+ Add Period', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('empty_load_cbse_button'),
                onPressed: _populateCBSETemplate,
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Auto-Load CBSE Timetable', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: BorderSide(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: badgeColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _standardTimings = [
    '07:45 - 08:30',
    '08:30 - 09:15',
    '09:15 - 10:00',
    '10:00 - 10:20',
    '10:20 - 11:05',
    '11:05 - 11:50',
    '11:50 - 12:35',
    '12:35 - 01:20',
  ];

  Future<void> _populateCBSETemplate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-Load CBSE Timetable?'),
        content: Text('This will populate a complete 8-period CBSE weekly schedule (Sunday to Thursday) for $_effectiveClass.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Load Timetable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.populateDefaultCBSEWeeklyTimetable(classLevel: _effectiveClass);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CBSE Weekly Timetable Loaded Successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeletePeriod(TimetablePeriod period) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Period P${period.periodNumber}?'),
        content: Text('Are you sure you want to remove ${period.subject} from $_selectedDay\'s timetable?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deleted = await _authService.deleteTimetablePeriod(
        dayOfWeek: _selectedDay,
        periodNumber: period.periodNumber,
        classLevel: _effectiveClass,
      );
      if (mounted) {
        if (deleted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Period P${period.periodNumber} deleted.'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete period. Please check connection.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  void _showAddEditPeriodModal([TimetablePeriod? existing]) {
    final isEdit = existing != null;
    int selectedPeriodNumber = existing?.periodNumber ?? 1;
    String selectedDay = (existing != null && existing.dayOfWeek.isNotEmpty) ? existing.dayOfWeek : _selectedDay;
    String selectedTimeSlot = existing?.timeSlot ?? '07:45 - 08:30';
    bool isBreak = existing?.isBreak ?? false;

    final subjectController = TextEditingController(text: existing?.subject ?? '');
    final teacherController = TextEditingController(text: existing?.teacherName ?? '');
    final roomController = TextEditingController(text: existing?.room ?? '');
    final customTimeSlotController = TextEditingController(
      text: (existing != null && !_standardTimings.contains(existing.timeSlot)) ? existing.timeSlot : '',
    );
    bool isCustomTiming = existing != null && !_standardTimings.contains(existing.timeSlot);

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return ManagedModalScope(
          controllers: [
            subjectController,
            teacherController,
            roomController,
            customTimeSlotController,
          ],
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
            return Material(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit ? 'Edit Period P${existing.periodNumber}' : 'Add Timetable Period',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Close dialog',
                            child: IconButton(
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      Text(
                        'Day of Week',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: kBahrainSchoolDays.map((d) {
                            final sel = selectedDay == d;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(d),
                                selected: sel,
                                onSelected: (val) {
                                  if (val) setModalState(() => selectedDay = d);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Period Number',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(8, (i) {
                          final num = i + 1;
                          final sel = selectedPeriodNumber == num;
                          return ChoiceChip(
                            label: Text('P$num'),
                            selected: sel,
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  selectedPeriodNumber = num;
                                  if (!isCustomTiming && i < _standardTimings.length) {
                                    selectedTimeSlot = _standardTimings[i];
                                  }
                                });
                              }
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Subject',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'Mathematics',
                            'Physics',
                            'Chemistry',
                            'Biology',
                            'English',
                            'Social Science',
                            'Computer Science',
                            'Morning Recess',
                            'Physical Education',
                            'Library',
                          ].map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(s),
                                onPressed: () {
                                  setModalState(() {
                                    subjectController.text = s;
                                    if (s == 'Morning Recess') {
                                      isBreak = true;
                                      if (roomController.text.isEmpty) roomController.text = 'Courtyard';
                                      if (teacherController.text.isEmpty) teacherController.text = 'Duty Staff';
                                    }
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Mathematics',
                          labelText: 'Subject Name',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter subject' : null,
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Time Slot',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!isCustomTiming)
                        DropdownButtonFormField<String>(
                          initialValue: _standardTimings.contains(selectedTimeSlot) ? selectedTimeSlot : _standardTimings.first,
                          items: [
                            ..._standardTimings.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                            const DropdownMenuItem(value: 'custom', child: Text('Custom Time Slot...')),
                          ],
                          onChanged: (val) {
                            if (val == 'custom') {
                              setModalState(() {
                                isCustomTiming = true;
                              });
                            } else if (val != null) {
                              setModalState(() {
                                selectedTimeSlot = val;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: customTimeSlotController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 07:45 - 08:30',
                                  labelText: 'Custom Time Slot',
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter time slot' : null,
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'Use Standard Timings',
                              child: IconButton(
                                icon: const Icon(Icons.undo_rounded),
                                tooltip: 'Use Standard Timings',
                                onPressed: () {
                                  setModalState(() {
                                    isCustomTiming = false;
                                    selectedTimeSlot = _standardTimings.first;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: roomController,
                              decoration: InputDecoration(
                                hintText: 'e.g. Room 101',
                                labelText: 'Room / Venue',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter room' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: teacherController,
                              decoration: InputDecoration(
                                hintText: 'e.g. Mr. Sharma',
                                labelText: 'Teacher Name',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter teacher' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Recess / Break Period', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: const Text('Mark this slot as an interval/break', style: TextStyle(fontSize: 11)),
                        value: isBreak,
                        onChanged: (v) => setModalState(() => isBreak = v),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          key: const Key('save_period_button'),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final slot = isCustomTiming
                                ? customTimeSlotController.text.trim()
                                : selectedTimeSlot;
                            final period = TimetablePeriod(
                              periodNumber: selectedPeriodNumber,
                              timeSlot: slot,
                              subject: subjectController.text.trim(),
                              teacherName: teacherController.text.trim(),
                              room: roomController.text.trim(),
                              isBreak: isBreak,
                              dayOfWeek: selectedDay,
                              classLevel: _effectiveClass,
                            );

                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(ctx);

                            final saved = await _authService.saveTimetablePeriod(
                              period: period,
                              classLevel: _effectiveClass,
                            );

                            if (mounted) {
                              if (saved) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                });
                                nav.pop();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Period P$selectedPeriodNumber ($selectedDay) saved successfully!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              } else {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to persist period to database. Please check connection.'),
                                    backgroundColor: Color(0xFFEF4444),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            isEdit ? 'Update Period' : 'Save Period',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                            foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          },
        ),
      );
    },
  );
}
}

/// Alias for AssignmentsTab per blueprint specification.
typedef AcademicHomeworkTab = AssignmentsTab;

/// Academic Homework Tracker & Points Claim Tab.
/// Real-time status cycling (PENDING ➔ SUBMITTED ➔ GRADED), due date countdown, and merit awards.
class AssignmentsTab extends StatefulWidget {
  final String? classLevel;
  final String? selectedSubject;
  final DateTime? mockNow;
  final List<AcademicAssignment>? initialAssignments;
  final Function(AcademicAssignment)? onStatusChanged;

  const AssignmentsTab({
    super.key,
    this.classLevel,
    this.selectedSubject,
    this.mockNow,
    this.initialAssignments,
    this.onStatusChanged,
  });

  @override
  State<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<AssignmentsTab> {
  final AuthService _authService = AuthService();
  late String _currentSubject;
  late String _effectiveClass;
  final Map<String, AssignmentStatus> _optimisticStatus = {};

  @override
  void initState() {
    super.initState();
    final profile = AuthService.getCachedProfile();
    _effectiveClass = widget.classLevel ?? profile?['class_level']?.toString() ?? 'Grade 10';
    _currentSubject = widget.selectedSubject ?? 'All';
  }

  DateTime get _currentTime => widget.mockNow ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = _currentTime;

    final initialList = widget.initialAssignments;
    final List<AcademicAssignment> cachedAssignments;
    if (initialList != null && initialList.isNotEmpty) {
      if (_currentSubject == 'All') {
        cachedAssignments = initialList;
      } else {
        cachedAssignments = initialList
            .where((a) => a.subject.toLowerCase() == _currentSubject.toLowerCase())
            .toList();
      }
    } else {
      cachedAssignments = AuthService.getCachedAssignments(
        classLevel: _effectiveClass,
        subject: _currentSubject,
      );
    }

    return Column(
      children: [
        // Subject Filter Bar (All, Mathematics, Physics, etc.)
        _buildSubjectFilterBar(isDark),

        // Main Assignments Stream List
        Expanded(
          child: StreamBuilder<List<AcademicAssignment>>(
            stream: _authService.getAssignmentsStream(
              classLevel: _effectiveClass,
              subject: _currentSubject,
            ),
            initialData: cachedAssignments.isNotEmpty ? cachedAssignments : null,
            builder: (context, snapshot) {
              final rawAssignments = (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty)
                  ? snapshot.data!
                  : cachedAssignments;

              // Apply optimistic statuses if mutated
              final assignments = rawAssignments.map((a) {
                if (_optimisticStatus.containsKey(a.id)) {
                  return a.copyWith(status: _optimisticStatus[a.id]);
                }
                return a;
              }).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Summary HUD (Pending, Submitted, Graded counts)
                    if (assignments.isNotEmpty)
                      _buildStatusSummaryHUD(assignments, isDark),

                    const SizedBox(height: 16),

                    // Section Heading
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          _currentSubject == 'All' ? 'All Assignments' : '$_currentSubject Homework',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (assignments.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${assignments.length} Tasks',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            FilledButton.icon(
                              key: const Key('add_assignment_button'),
                              onPressed: _showAddAssignmentModal,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Task', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                              style: FilledButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Empty State or Assignment Cards
                    if (assignments.isEmpty)
                      _buildEmptyState(isDark)
                    else
                      ...assignments.map((assignment) => _buildAssignmentCard(assignment, now, isDark)),

                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Subject Filter Bar with WCAG 2.5.5 minimum 48x48 dp touch targets.
  Widget _buildSubjectFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: kAcademicSubjects.map((subject) {
            final isSelected = _currentSubject.toLowerCase() == subject.toLowerCase();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                button: true,
                selected: isSelected,
                label: '$subject Filter',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: InkWell(
                    onTap: () => setState(() => _currentSubject = subject),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA))
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA))
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          subject,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Status Summary HUD with task distribution.
  Widget _buildStatusSummaryHUD(List<AcademicAssignment> assignments, bool isDark) {
    final pendingCount = assignments.where((a) => a.status == AssignmentStatus.pending).length;
    final submittedCount = assignments.where((a) => a.status == AssignmentStatus.submitted).length;
    final gradedCount = assignments.where((a) => a.status == AssignmentStatus.graded).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          _buildHUDStatPill(
            label: 'Pending',
            count: pendingCount,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildHUDStatPill(
            label: 'Submitted',
            count: submittedCount,
            color: const Color(0xFF38BDF8),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildHUDStatPill(
            label: 'Graded',
            count: gradedCount,
            color: const Color(0xFF34D399),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildHUDStatPill({
    required String label,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Individual Assignment Card with Live Region & 48dp cycle button.
  Widget _buildAssignmentCard(AcademicAssignment assignment, DateTime now, bool isDark) {
    final isUrgent = assignment.isUrgent(now);
    final isOverdue = assignment.isOverdue(now);
    final remainingStr = assignment.formattedRemaining(now);
    final currentStatus = assignment.status;

    return Padding(
      key: Key('assignment_card_${assignment.id}'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        key: Key('assignment_semantics_${assignment.id}'),
        container: true,
        readOnly: true,
        liveRegion: isUrgent,
        label:
            'Homework: ${assignment.title} in ${assignment.subject} with ${assignment.teacherName}. $remainingStr.${isUrgent ? " Urgent deadline." : ""} Reward: +${assignment.pointsReward} Points. Status: ${currentStatus.displayName}.',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOverdue
                  ? const Color(0xFFEF4444)
                  : (isUrgent
                      ? const Color(0xFFF59E0B)
                      : (currentStatus == AssignmentStatus.graded
                          ? const Color(0xFF34D399)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)))),
              width: (isUrgent || isOverdue || currentStatus == AssignmentStatus.graded) ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Subject Badge + Points Reward Pill
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        assignment.subject.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 4),
                              Text(
                                '+${assignment.pointsReward} Pts',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Delete Assignment',
                        child: IconButton(
                          key: Key('delete_assignment_${assignment.id}'),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.redAccent.withValues(alpha: 0.8),
                          ),
                          tooltip: 'Delete Assignment',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _confirmDeleteAssignment(assignment),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Assignment Title
              Text(
                assignment.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Teacher Info
              Text(
                'Instructor: ${assignment.teacherName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 14),

              // Bottom Actions: Urgency Countdown Chip & Status Cycle Button
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  // Urgency / Due Date Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? const Color(0xFF450A0A)
                          : (isUrgent
                              ? const Color(0xFF451A03)
                              : (currentStatus == AssignmentStatus.graded
                                  ? const Color(0xFF064E3B)
                                  : (isDark ? const Color(0xFF082F49) : const Color(0xFFF0F9FF)))),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOverdue
                                ? Icons.warning_amber_rounded
                                : (isUrgent ? Icons.alarm_rounded : Icons.schedule_rounded),
                            size: 14,
                            color: isOverdue
                                ? const Color(0xFFEF4444)
                                : (isUrgent
                                    ? const Color(0xFFF59E0B)
                                    : (currentStatus == AssignmentStatus.graded
                                        ? const Color(0xFF34D399)
                                        : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)))),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            remainingStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isOverdue
                                  ? const Color(0xFFEF4444)
                                  : (isUrgent
                                      ? const Color(0xFFFBBF24)
                                      : (currentStatus == AssignmentStatus.graded
                                          ? const Color(0xFF34D399)
                                          : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Status Transition Button (WCAG 2.5.5 minimum 48x120 dp target)
                  Semantics(
                    button: true,
                    label: '${assignment.title} status: ${currentStatus.displayName.toUpperCase()}. Tap to cycle to next status.',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48, minWidth: 120),
                      child: InkWell(
                        onTap: () => _cycleAssignmentStatus(assignment),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: currentStatus.containerColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: currentStatus.textColor.withValues(alpha: 0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: currentStatus.textColor.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    currentStatus == AssignmentStatus.pending
                                        ? Icons.hourglass_empty_rounded
                                        : (currentStatus == AssignmentStatus.submitted
                                            ? Icons.upload_file_rounded
                                            : Icons.verified_rounded),
                                    size: 16,
                                    color: currentStatus.textColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentStatus.displayName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: currentStatus.textColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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

  void _cycleAssignmentStatus(AcademicAssignment assignment) {
    final nextStatus = assignment.status.nextStatus;
    setState(() {
      _optimisticStatus[assignment.id] = nextStatus;
    });

    final updated = assignment.copyWith(status: nextStatus);
    widget.onStatusChanged?.call(updated);

    _authService.updateAssignmentStatus(
      assignmentId: assignment.id,
      newStatus: nextStatus,
      classLevel: _effectiveClass,
      pointsReward: assignment.pointsReward,
    );

    final view = View.maybeOf(context);
    if (view != null) {
      SemanticsService.sendAnnouncement(
        view,
        '${assignment.title} marked as ${nextStatus.displayName}',
        TextDirection.ltr,
      );
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 48,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 14),
          Text(
            'No homework assignments pending for this subject.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Assignments will appear automatically once assigned by your course instructors.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('empty_add_assignment_button'),
            onPressed: _showAddAssignmentModal,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('+ Add Homework Task', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAssignment(AcademicAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assignment?'),
        content: Text('Are you sure you want to delete "${assignment.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.deleteAssignment(
        assignmentId: assignment.id,
        classLevel: _effectiveClass,
        subject: assignment.subject,
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment deleted successfully.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showAddAssignmentModal() {
    final titleController = TextEditingController();
    final teacherController = TextEditingController(text: 'Mr. Sharma');
    final descController = TextEditingController();
    String selectedSubject = _currentSubject != 'All' ? _currentSubject : 'Mathematics';
    DateTime selectedDue = DateTime.now().add(const Duration(days: 1));
    int selectedPoints = 20;

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return ManagedModalScope(
          controllers: [
            titleController,
            teacherController,
            descController,
          ],
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
            return Material(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Homework / Task',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Close dialog',
                            child: IconButton(
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      Text(
                        'Subject',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: kAcademicSubjects.where((s) => s != 'All').map((s) {
                            final sel = selectedSubject == s;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(s),
                                selected: sel,
                                onSelected: (val) {
                                  if (val) setModalState(() => selectedSubject = s);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Chapter 4 Integration Exercises',
                          labelText: 'Task Title',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter task title' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: teacherController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Mr. Sharma',
                          labelText: 'Teacher / Faculty',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter teacher name' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDue,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 90)),
                                );
                                if (d != null) {
                                  setModalState(() {
                                    selectedDue = DateTime(d.year, d.month, d.day, 23, 59);
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: Text('Due: ${selectedDue.day}/${selectedDue.month}/${selectedDue.year}'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedPoints,
                              decoration: InputDecoration(
                                labelText: 'Merit Points',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 10, child: Text('+10 Pts')),
                                DropdownMenuItem(value: 20, child: Text('+20 Pts')),
                                DropdownMenuItem(value: 30, child: Text('+30 Pts')),
                                DropdownMenuItem(value: 50, child: Text('+50 Pts')),
                              ],
                              onChanged: (v) {
                                if (v != null) setModalState(() => selectedPoints = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Solve questions 1 to 20 from textbook page 112.',
                          labelText: 'Description / Instructions',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          key: const Key('publish_assignment_button'),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final newAssignment = AcademicAssignment(
                              id: 'hw_${DateTime.now().millisecondsSinceEpoch}',
                              title: titleController.text.trim(),
                              subject: selectedSubject,
                              teacherName: teacherController.text.trim(),
                              dueDateTime: selectedDue,
                              pointsReward: selectedPoints,
                              status: AssignmentStatus.pending,
                              description: descController.text.trim(),
                              classLevel: _effectiveClass,
                            );

                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(ctx);

                            await _authService.publishAssignment(
                              assignment: newAssignment,
                              classLevel: _effectiveClass,
                            );

                            if (mounted) {
                              setState(() {});
                              nav.pop();
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Homework task published successfully!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Publish Homework', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                            foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          },
        ),
      );
    },
  );
}
}

/// Mid-Term Examination Schedule Tab.
/// Authoritative schedule of upcoming exams with countdown telemetry,
/// syllabus revision vault, and exam hall/desk directory.
class ExamsTab extends StatefulWidget {
  final String? classLevel;
  final String? selectedSubject;
  final DateTime? mockNow;
  final List<ExamScheduleItem>? initialExams;

  const ExamsTab({
    super.key,
    this.classLevel,
    this.selectedSubject,
    this.mockNow,
    this.initialExams,
  });

  @override
  State<ExamsTab> createState() => _ExamsTabState();
}

typedef ExamScheduleTab = ExamsTab;

class _ExamsTabState extends State<ExamsTab> {
  final AuthService _authService = AuthService();
  late String _currentSubject;
  late String _effectiveClass;
  final Set<String> _expandedExamIds = {};

  @override
  void initState() {
    super.initState();
    final profile = AuthService.getCachedProfile();
    _effectiveClass = widget.classLevel ?? profile?['class_level']?.toString() ?? 'Grade 10';
    _currentSubject = widget.selectedSubject ?? 'All';
  }

  DateTime get _currentTime => widget.mockNow ?? DateTime.now();

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = _currentTime;

    final initialList = widget.initialExams;
    final List<ExamScheduleItem> cachedExams;
    if (initialList != null) {
      if (_currentSubject == 'All') {
        cachedExams = initialList;
      } else {
        cachedExams = initialList
            .where((e) => e.subject.toLowerCase() == _currentSubject.toLowerCase())
            .toList();
      }
    } else {
      cachedExams = AuthService.getCachedExamSchedule(
        classLevel: _effectiveClass,
        subject: _currentSubject,
      );
    }

    return Column(
      children: [
        // Subject Filter Bar (All, Mathematics, Physics, etc.)
        _buildSubjectFilterBar(isDark),

        // Main Exams Stream List
        Expanded(
          child: StreamBuilder<List<ExamScheduleItem>>(
            stream: _authService.getExamScheduleStream(
              classLevel: _effectiveClass,
              subject: _currentSubject,
            ),
            initialData: cachedExams.isNotEmpty ? cachedExams : null,
            builder: (context, snapshot) {
              final exams = (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty)
                  ? snapshot.data!
                  : cachedExams;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teacher / Faculty Exam Publisher Action (for Teachers/Admins)
                    Builder(
                      builder: (context) {
                        final profile = AuthService.getCachedProfile();
                        final isTeacherOrAdmin = HierarchyService.isTeacherOrFaculty(
                              role: profile?['role'],
                              scholarNo: profile?['scholar_no'],
                            ) ||
                            HierarchyService.isSuperAdmin(
                              role: profile?['role'],
                              scholarNo: profile?['scholar_no'],
                            );
                        if (isTeacherOrAdmin) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTeacherExamPublisherAction(isDark),
                              const SizedBox(height: 16),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // Section Heading
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          _currentSubject == 'All' ? 'Mid-Term Examinations' : '$_currentSubject Exams',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (exams.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${exams.length} Papers Scheduled',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Empty State or Exam Cards
                    if (exams.isEmpty)
                      _buildEmptyState(isDark)
                    else
                      ...exams.map((exam) => _buildExamCard(exam, now, isDark)),

                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Subject Filter Bar with WCAG 2.5.5 minimum 48x48 dp touch targets.
  Widget _buildSubjectFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: kAcademicSubjects.map((subject) {
            final isSelected = _currentSubject.toLowerCase() == subject.toLowerCase();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                button: true,
                selected: isSelected,
                label: '$subject Filter',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: InkWell(
                    onTap: () => setState(() => _currentSubject = subject),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA))
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA))
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          subject,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected
                                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Individual Mid-Term Exam Card Component.
  Widget _buildExamCard(ExamScheduleItem exam, DateTime now, bool isDark) {
    final isUrgent = exam.isUrgent(now);
    final isInProgress = exam.isInProgress(now);
    final isConcluded = exam.isConcluded(now);
    final isExpanded = _expandedExamIds.contains(exam.id);

    final dateStr =
        '${_monthName(exam.examDateTime.month)} ${exam.examDateTime.day}, ${exam.examDateTime.year} • ${_formatTime(exam.examDateTime)}';

    return Padding(
      key: Key('exam_card_${exam.id}'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isInProgress
                ? const Color(0xFF10B981)
                : (isUrgent
                    ? const Color(0xFFF59E0B)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            width: (isInProgress || isUrgent) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Subject Badge + Marks / Duration Pill
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      exam.subject.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assessment_rounded, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 4),
                        Text(
                          '${exam.maxMarks} Marks • ${exam.durationMinutes}m',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Paper Title
            Text(
              exam.paperTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Exam Date & Time
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Telemetry Countdown HUD
            if (isInProgress)
              Semantics(
                liveRegion: true,
                label: 'Exam in progress: ${exam.paperTitle} in ${exam.examHall}',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.play_circle_fill, size: 14, color: Color(0xFF34D399)),
                        SizedBox(width: 6),
                        Text(
                          'IN PROGRESS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF34D399),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (isUrgent)
              Semantics(
                key: Key('exam_urgent_${exam.id}'),
                liveRegion: true,
                container: true,
                label:
                    'Urgent examination alert: ${exam.subject} ${exam.paperTitle} starts in ${exam.formattedCountdown(now)} at ${exam.examHall}',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF451A03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.alarm_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Text(
                          exam.formattedCountdown(now),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (isConcluded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Concluded',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF082F49) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        exam.formattedCountdown(now),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Exam Hall & Seating Desk Directory Navigator
            Semantics(
              label: 'Exam location: ${exam.examHall}, desk allocation: ${exam.seatRow}',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFFEF4444)),
                          const SizedBox(width: 5),
                          Text(
                            exam.examHall,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_seat_rounded, size: 15, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 5),
                          Text(
                            exam.seatRow,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Attached Timetable / Circular Photo Preview
            if (exam.imageUrl != null && exam.imageUrl!.isNotEmpty) ...[
              InkWell(
                onTap: () => _showFullImagePreview(context, exam.imageUrl!, exam.paperTitle),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildExamImage(exam.imageUrl!),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'View Timetable Circular',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
              const SizedBox(height: 12),
            ],

            // Expandable Syllabus Revision Vault Accordion
            Semantics(
              button: true,
              expanded: isExpanded,
              label: 'Syllabus topics for ${exam.paperTitle}, ${exam.syllabusTopics.length} topics',
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D31) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Column(
                  children: [
                    // Accordion Header (WCAG 2.5.5 minimum 48dp hit area)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: InkWell(
                        key: Key('syllabus_accordion_${exam.id}'),
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedExamIds.remove(exam.id);
                            } else {
                              _expandedExamIds.add(exam.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.menu_book_rounded,
                                        size: 16,
                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Syllabus Vault (${exam.syllabusTopics.length} Topics)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Accordion Body (Expanded Content)
                    if (isExpanded)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 16),
                            if (exam.syllabusTopics.isEmpty)
                              Text(
                                'Detailed chapter outline will be released shortly by the department.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white60 : Colors.grey[600],
                                ),
                              )
                            else
                              ...exam.syllabusTopics.asMap().entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 14,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${entry.key + 1}. ${entry.value}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            if (exam.readingMaterials.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Recommended Study References:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: exam.readingMaterials.map((ref) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.bookmark_border_rounded, size: 12, color: Color(0xFF38BDF8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            ref,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 48,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 14),
          Text(
            'No Examinations Scheduled',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Mid-term examination timetables and hall allocations will appear once released by the school administration.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherExamPublisherAction(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.post_add_rounded,
              color: Color(0xFF6366F1),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Faculty Exam Scheduler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Publish timetable dates, halls & circulars across grade ranges',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            onPressed: _showPublishExamDialog,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: const Text(
              'Publish',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showPublishExamDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gradeLevels = [
      'Grade 5',
      'Grade 6',
      'Grade 7',
      'Grade 8',
      'Grade 9',
      'Grade 10',
      'Grade 11',
      'Grade 12',
    ];

    String fromGrade = _effectiveClass.isNotEmpty && gradeLevels.contains(_effectiveClass)
        ? _effectiveClass
        : 'Grade 8';
    String toGrade = 'Grade 12';
    String selectedSubject = 'Mathematics';
    final paperController = TextEditingController(text: 'Mid-Term Assessment Paper 1');
    final hallController = TextEditingController(text: 'Main Examination Hall');
    final syllabusController = TextEditingController(text: 'Chapters 1 to 5 Revision');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 30);
    int selectedDuration = 90;
    int selectedMarks = 100;
    String? photoBase64;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => ManagedModalScope(
        controllers: [
          paperController,
          hallController,
          syllabusController,
        ],
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
          int fIdx = gradeLevels.indexOf(fromGrade);
          int tIdx = gradeLevels.indexOf(toGrade);
          if (fIdx == -1) fIdx = 0;
          if (tIdx == -1) tIdx = gradeLevels.length - 1;
          if (fIdx > tIdx) {
            final tmp = fIdx;
            fIdx = tIdx;
            tIdx = tmp;
          }
          final cohort = gradeLevels.sublist(fIdx, tIdx + 1);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📝 Publish Mid-Term Exam Schedule',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Close dialog',
                        child: IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Grade Range Selector ("From Grade" to "To Grade")
                  Text(
                    'Target Grade Range',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: fromGrade,
                          decoration: InputDecoration(
                            labelText: 'From Grade',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: gradeLevels
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                fromGrade = val;
                                if (gradeLevels.indexOf(toGrade) < gradeLevels.indexOf(fromGrade)) {
                                  toGrade = fromGrade;
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF6366F1), size: 20),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: toGrade,
                          decoration: InputDecoration(
                            labelText: 'To Grade',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: gradeLevels
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                toGrade = val;
                                if (gradeLevels.indexOf(fromGrade) > gradeLevels.indexOf(toGrade)) {
                                  fromGrade = toGrade;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.groups_rounded, size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cohort Broadcast: ${cohort.join(', ')} (${cohort.length} Grades)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Subject Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedSubject,
                    decoration: InputDecoration(
                      labelText: 'Curriculum Subject',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      'Mathematics',
                      'Physics',
                      'Chemistry',
                      'Computer Science',
                      'English',
                      'Biology',
                      'Social Studies',
                      'Hindi',
                      'Arabic',
                      'French',
                      'Business Studies',
                      'Economics',
                      'Accountancy',
                    ]
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedSubject = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Paper Title
                  TextField(
                    controller: paperController,
                    decoration: InputDecoration(
                      labelText: 'Paper Title',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Exam Date & Time Pickers
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setModalState(() => selectedTime = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Time', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 6),
                                    Text(
                                      selectedTime.format(context),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Duration & Max Marks Selectors
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedDuration,
                          decoration: InputDecoration(
                            labelText: 'Duration',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: 45, child: Text('45 Mins')),
                            DropdownMenuItem(value: 60, child: Text('1 Hour')),
                            DropdownMenuItem(value: 90, child: Text('1.5 Hours')),
                            DropdownMenuItem(value: 120, child: Text('2 Hours')),
                            DropdownMenuItem(value: 180, child: Text('3 Hours')),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedDuration = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedMarks,
                          decoration: InputDecoration(
                            labelText: 'Max Marks',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: 40, child: Text('40 Marks')),
                            DropdownMenuItem(value: 50, child: Text('50 Marks')),
                            DropdownMenuItem(value: 80, child: Text('80 Marks')),
                            DropdownMenuItem(value: 100, child: Text('100 Marks')),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedMarks = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Hall / Venue
                  TextField(
                    controller: hallController,
                    decoration: InputDecoration(
                      labelText: 'Exam Hall / Venue',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Syllabus Notes
                  TextField(
                    controller: syllabusController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Syllabus Topics (comma-separated)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Circular / Timetable Photo Upload
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📸 Timetable / Circular Photo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      if (photoBase64 != null)
                        TextButton(
                          onPressed: () => setModalState(() => photoBase64 = null),
                          child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (photoBase64 != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
                        ),
                        child: _buildExamImage(photoBase64!),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final xfile = await ImagePicker().pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 80,
                                  maxWidth: 1200,
                                );
                                if (xfile != null) {
                                  final bytes = await xfile.readAsBytes();
                                  setModalState(() {
                                    photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                  });
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Camera unavailable: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.camera_alt_rounded, size: 16),
                            label: const Text('Take Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final xfile = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                  maxWidth: 1200,
                                );
                                if (xfile != null) {
                                  final bytes = await xfile.readAsBytes();
                                  setModalState(() {
                                    photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                  });
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gallery unavailable: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.photo_library_rounded, size: 16),
                            label: const Text('Choose Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              final fullDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );

                              final topics = syllabusController.text
                                  .split(',')
                                  .map((t) => t.trim())
                                  .where((t) => t.isNotEmpty)
                                  .toList();

                              try {
                                await _authService.publishExamScheduleRange(
                                  fromGrade: fromGrade,
                                  toGrade: toGrade,
                                  subject: selectedSubject,
                                  paperTitle: paperController.text.trim().isNotEmpty
                                      ? paperController.text.trim()
                                      : '$selectedSubject Examination',
                                  examDateTime: fullDateTime,
                                  durationMinutes: selectedDuration,
                                  examHall: hallController.text.trim().isNotEmpty
                                      ? hallController.text.trim()
                                      : 'Main Examination Hall',
                                  maxMarks: selectedMarks,
                                  syllabusTopics: topics,
                                  imageUrl: photoBase64,
                                );

                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 Exam schedule published for $fromGrade to $toGrade!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                                setState(() {});
                              } catch (e) {
                                if (ctx.mounted) {
                                  setModalState(() => isSaving = false);
                                }
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to publish exam schedule: $e'),
                                    backgroundColor: const Color(0xFFEF4444),
                                  ),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Publish Exam Schedule',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

  static Widget _buildExamImage(String imageUrl, {BoxFit fit = BoxFit.cover}) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        return Image.memory(
          base64Decode(base64Str),
          fit: fit,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.grey),
          ),
        );
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey));
      }
    } else {
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.grey),
        ),
      );
    }
  }

  void _showFullImagePreview(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Close dialog',
                  child: IconButton(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: _buildExamImage(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pinch or drag to zoom timetable circular',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Term Report Cards Tab & Grade Registry.
/// Displays student term performance, GPA honours calculation, subject breakdown analytics,
/// and verified honours merit claims (+50 House Points).
class ReportCardTab extends StatefulWidget {
  final String? classLevel;
  final String? scholarNo;
  final List<AcademicReportCard>? initialReportCards;
  final Function(AcademicReportCard)? onHonoursClaimed;

  const ReportCardTab({
    super.key,
    this.classLevel,
    this.scholarNo,
    this.initialReportCards,
    this.onHonoursClaimed,
  });

  @override
  State<ReportCardTab> createState() => _ReportCardTabState();
}

typedef AcademicReportCardTab = ReportCardTab;

class _ReportCardTabState extends State<ReportCardTab> {
  final AuthService _authService = AuthService();
  late String _effectiveClass;
  late String _effectiveScholarNo;
  String _selectedTerm = 'All';
  final Set<String> _claimedCardIds = {};
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    final profile = AuthService.getCachedProfile();
    _effectiveClass = widget.classLevel ?? profile?['class_level']?.toString() ?? 'Grade 10';
    _effectiveScholarNo = widget.scholarNo ??
        profile?['scholar_no']?.toString() ??
        profile?['student_id']?.toString() ??
        'ASB-2024-8841';
  }

  Color _getGradeColor(String grade, bool isDark) {
    final g = grade.toUpperCase();
    if (g.startsWith('A')) {
      return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    } else if (g.startsWith('B')) {
      return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    } else if (g.startsWith('C')) {
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    } else if (g.startsWith('D')) {
      return isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
    } else {
      return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    }
  }

  Future<void> _handleClaimMerit(AcademicReportCard card) async {
    if (_isClaiming || card.pointsClaimed || _claimedCardIds.contains(card.id)) return;
    setState(() {
      _isClaiming = true;
      _claimedCardIds.add(card.id);
    });

    final success = await _authService.claimReportCardHonoursMerit(
      reportCardId: card.id,
      gpa: card.overallGpa,
      scholarNo: card.scholarNo,
    );

    if (!mounted) return;

    setState(() {
      _isClaiming = false;
    });

    if (success) {
      final view = View.maybeOf(context);
      if (view != null) {
        SemanticsService.sendAnnouncement(
          view,
          'Claimed 50 House Points for Academic Distinction in ${card.term}!',
          TextDirection.ltr,
        );
      }
      widget.onHonoursClaimed?.call(card.copyWith(pointsClaimed: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initialList = widget.initialReportCards;
    if (initialList != null) {
      final List<AcademicReportCard> filtered;
      if (_selectedTerm == 'All') {
        filtered = initialList;
      } else {
        filtered = initialList
            .where((c) => c.term.toLowerCase() == _selectedTerm.toLowerCase())
            .toList();
      }
      return _buildView(context, filtered, initialList, isDark);
    }

    final cachedCards = AuthService.getCachedReportCards(
      scholarNo: _effectiveScholarNo,
      classLevel: _effectiveClass,
      term: _selectedTerm,
    );

    return StreamBuilder<List<AcademicReportCard>>(
      stream: _authService.getReportCardsStream(
        scholarNo: _effectiveScholarNo,
        classLevel: _effectiveClass,
        term: _selectedTerm,
      ),
      initialData: cachedCards,
      builder: (context, snapshot) {
        final cards = snapshot.data ?? cachedCards;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          AuthService.cacheReportCards(
            snapshot.data!,
            scholarNo: _effectiveScholarNo,
            classLevel: _effectiveClass,
          );
        }
        return _buildView(context, cards, cards, isDark);
      },
    );
  }

  Widget _buildView(
    BuildContext context,
    List<AcademicReportCard> cards,
    List<AcademicReportCard> allCards,
    bool isDark,
  ) {
    final terms = <String>['All'];
    for (final c in allCards) {
      if (!terms.contains(c.term)) {
        terms.add(c.term);
      }
    }

    return Column(
      children: [
        // Teacher / Faculty Report Card Publisher Action
        Builder(
          builder: (context) {
            final profile = AuthService.getCachedProfile();
            final isTeacherOrAdmin = HierarchyService.isTeacherOrFaculty(
                  role: profile?['role'],
                  scholarNo: profile?['scholar_no'],
                ) ||
                HierarchyService.isSuperAdmin(
                  role: profile?['role'],
                  scholarNo: profile?['scholar_no'],
                );
            if (isTeacherOrAdmin) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: _buildTeacherReportCardPublisherAction(isDark),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        if (terms.length > 1) ...[
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: terms.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final term = terms[index];
                final isSelected = _selectedTerm.toLowerCase() == term.toLowerCase();
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: 'Filter by $term Term',
                  child: InkWell(
                    onTap: () => setState(() => _selectedTerm = term),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA))
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA))
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Text(
                        term,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                              : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        Expanded(
          child: cards.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildEmptyState(isDark),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    return _buildReportCard(context, cards[index], isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportCard(BuildContext context, AcademicReportCard card, bool isDark) {
    final isClaimed = card.pointsClaimed || _claimedCardIds.contains(card.id);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: card.hasDistinction
              ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: card.hasDistinction ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Academic Honours HUD
          Semantics(
            container: true,
            label:
                'Academic Honours Summary for ${card.term}. GPA ${card.overallGpa.toStringAsFixed(2)} out of 4.00, overall percentage ${card.overallPercentage.toStringAsFixed(1)} percent, attendance ${card.attendancePercentage.toStringAsFixed(1)} percent.',
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2338) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.term,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${card.classLevel} • Section ${card.section} • ${card.academicYear}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                          ),
                        ),
                        child: Text(
                          card.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  card.overallGpa.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: card.overallGpa >= 3.8
                                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                        : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '/ 4.00 GPA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${card.overallPercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Overall Marks',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${card.attendancePercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: card.attendancePercentage >= 90
                                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Attendance',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (card.hasDistinction) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF78350F).withValues(alpha: 0.4),
                                  const Color(0xFF451A03).withValues(alpha: 0.3)
                                ]
                              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'ACADEMIC HONOURS DISTINCTION',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                          color: isDark
                                              ? const Color(0xFFFDE68A)
                                              : const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Eligible for +50 House Merit Points (GPA ≥ 3.80)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : const Color(0xFF78350F),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: isClaimed
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF064E3B)
                                          : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF10B981),
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: isDark
                                                ? const Color(0xFF34D399)
                                                : const Color(0xFF047857),
                                          ),
                                          const SizedBox(width: 8),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'CLAIMED (+50 PTS)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                                color: isDark
                                                    ? const Color(0xFF34D399)
                                                    : const Color(0xFF047857),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Semantics(
                                    button: true,
                                    label: 'Claim 50 House Points for Academic Distinction',
                                    child: ElevatedButton(
                                      key: Key('claim_honours_merit_${card.id}'),
                                      onPressed: _isClaiming ? null : () => _handleClaimMerit(card),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFD97706),
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _isClaiming
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                          strokeWidth: 2, color: Colors.black),
                                                    )
                                                  : const Icon(Icons.military_tech_rounded, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                _isClaiming
                                                    ? 'VERIFYING...'
                                                    : 'CLAIM HONOURS MERIT (+50 PTS)',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF4338CA),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Class Teacher Remarks',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"${card.teacherRemarks}"',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        if (card.principalRemarks != null &&
                            card.principalRemarks!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Principal: "${card.principalRemarks}"',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Issued: ${card.formattedIssueDate}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Subject Performance Analytics
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Subject Performance Analytics',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${card.subjects.length} Subjects',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4338CA),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: card.subjects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, sIdx) {
                    final subj = card.subjects[sIdx];
                    final gradeColor = _getGradeColor(subj.letterGrade, isDark);

                    return Semantics(
                      container: true,
                      label:
                          '${subj.subject}: ${subj.marksObtained.toStringAsFixed(1)} out of ${subj.maxMarks.toStringAsFixed(1)}, Grade ${subj.letterGrade}',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subj.subject,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'Code: ${subj.code} • ${subj.gradePoints.toStringAsFixed(1)} GP',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white60
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: gradeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: gradeColor),
                                  ),
                                  child: Text(
                                    subj.letterGrade,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: gradeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Marks: ${subj.marksObtained.toStringAsFixed(1)} / ${subj.maxMarks.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF334155),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${subj.percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: gradeColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (subj.percentage / 100.0).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                              ),
                            ),
                            if (subj.remarks.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                subj.remarks,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.school_outlined,
            size: 48,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 14),
          Text(
            'No Term Report Cards Published Yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Official CBSE term report cards and grade records will be displayed once finalized and published by school administration.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherReportCardPublisherAction(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_turned_in_rounded,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Faculty Report Card Desk',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Issue official report card & grades for any student Scholar No',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            onPressed: _showPublishReportCardDialog,
            icon: const Icon(Icons.add_task_rounded, size: 16),
            label: const Text(
              'Issue',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showPublishReportCardDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gradeLevels = [
      'Grade 5',
      'Grade 6',
      'Grade 7',
      'Grade 8',
      'Grade 9',
      'Grade 10',
      'Grade 11',
      'Grade 12',
    ];

    const termOptions = [
      'Term 1 Mid-Term',
      'Term 1 Final',
      'Term 2 Mid-Term',
      'Term 2 Final',
      'Annual Examination',
    ];

    final scholarController = TextEditingController(
      text: _effectiveScholarNo.isNotEmpty ? _effectiveScholarNo : '2310910',
    );
    final nameController = TextEditingController();
    String selectedGrade = _effectiveClass.isNotEmpty && gradeLevels.contains(_effectiveClass)
        ? _effectiveClass
        : 'Grade 10';
    String selectedTerm = 'Term 1 Mid-Term';
    final gpaController = TextEditingController(text: '3.85');
    final pctController = TextEditingController(text: '92.5');
    final attController = TextEditingController(text: '98.0');
    final remarksController = TextEditingController(
      text: 'Exemplary academic effort and analytical diligence in all subjects.',
    );
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => ManagedModalScope(
        controllers: [
          scholarController,
          nameController,
          gpaController,
          pctController,
          attController,
          remarksController,
        ],
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🎓 Issue Official Report Card',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Close dialog',
                        child: IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Student Scholar Number
                  TextField(
                    controller: scholarController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Student Scholar Number *',
                      hintText: 'e.g. 2310910',
                      prefixIcon: const Icon(Icons.badge_rounded, size: 20, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Student Name
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Student Full Name (Optional)',
                      hintText: 'e.g. Aryan Sharma',
                      prefixIcon: const Icon(Icons.person_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grade Level & Term Dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedGrade,
                          decoration: InputDecoration(
                            labelText: 'Class / Grade',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: gradeLevels
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedGrade = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedTerm,
                          decoration: InputDecoration(
                            labelText: 'Term Assessment',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: termOptions
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedTerm = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // GPA, Percentage & Attendance Rate
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pctController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Percentage (%)',
                            hintText: '92.5',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (val) {
                            final p = double.tryParse(val);
                            if (p != null) {
                              final autoGpa = ((p / 100.0) * 4.0).clamp(0.0, 4.0);
                              gpaController.text = autoGpa.toStringAsFixed(2);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: gpaController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'GPA (out of 4.0)',
                            hintText: '3.85',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: attController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Attendance %',
                            hintText: '98.0',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Teacher Remarks
                  TextField(
                    controller: remarksController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Teacher Remarks / Recommendation',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final scholarNo = scholarController.text.trim();
                              if (scholarNo.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a valid Student Scholar Number.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);

                              final pct = double.tryParse(pctController.text.trim()) ?? 90.0;
                              final gpa = double.tryParse(gpaController.text.trim()) ?? ((pct / 100.0) * 4.0);
                              final att = double.tryParse(attController.text.trim()) ?? 98.0;

                              // Generate standard balanced subject grades
                              final subjects = [
                                SubjectGrade(
                                  subject: 'Mathematics',
                                  score: (pct + 2).clamp(0.0, 100.0),
                                  maxScore: 100.0,
                                  gradeLetter: SubjectGrade.computeGradeLetter((pct + 2).clamp(0.0, 100.0), 100.0),
                                  teacherComment: 'Strong problem-solving capability.',
                                ),
                                SubjectGrade(
                                  subject: 'Physics',
                                  score: (pct - 1).clamp(0.0, 100.0),
                                  maxScore: 100.0,
                                  gradeLetter: SubjectGrade.computeGradeLetter((pct - 1).clamp(0.0, 100.0), 100.0),
                                  teacherComment: 'Good grasp of physical principles.',
                                ),
                                SubjectGrade(
                                  subject: 'Chemistry',
                                  score: pct.clamp(0.0, 100.0),
                                  maxScore: 100.0,
                                  gradeLetter: SubjectGrade.computeGradeLetter(pct.clamp(0.0, 100.0), 100.0),
                                  teacherComment: 'Active laboratory work participation.',
                                ),
                                SubjectGrade(
                                  subject: 'Computer Science',
                                  score: (pct + 4).clamp(0.0, 100.0),
                                  maxScore: 100.0,
                                  gradeLetter: SubjectGrade.computeGradeLetter((pct + 4).clamp(0.0, 100.0), 100.0),
                                  teacherComment: 'Exceptional programming and logic.',
                                ),
                                SubjectGrade(
                                  subject: 'English',
                                  score: (pct - 2).clamp(0.0, 100.0),
                                  maxScore: 100.0,
                                  gradeLetter: SubjectGrade.computeGradeLetter((pct - 2).clamp(0.0, 100.0), 100.0),
                                  teacherComment: 'Fluent analytical comprehension.',
                                ),
                              ];

                              try {
                                await _authService.publishStudentReportCard(
                                  scholarNo: scholarNo,
                                  studentName: nameController.text.trim().isNotEmpty
                                      ? nameController.text.trim()
                                      : 'Scholar #$scholarNo',
                                  classLevel: selectedGrade,
                                  termName: selectedTerm,
                                  overallGpa: gpa,
                                  overallPercentage: pct,
                                  attendanceRate: att,
                                  teacherRemarks: remarksController.text.trim(),
                                  subjectGrades: subjects,
                                );

                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 Report card issued for Scholar #$scholarNo in $selectedGrade!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                                setState(() {});
                              } catch (e) {
                                if (ctx.mounted) {
                                  setModalState(() => isSaving = false);
                                }
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to publish report card: $e'),
                                    backgroundColor: const Color(0xFFEF4444),
                                  ),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Issue Report Card',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
}

/// Academic Attendance Tab & Absence Audit.
typedef AttendanceTab = AcademicAttendanceTab;

class AcademicAttendanceTab extends StatefulWidget {
  final String? classLevel;
  final String? scholarNo;
  final List<AttendanceRecord>? initialAttendance;

  const AcademicAttendanceTab({
    super.key,
    this.classLevel,
    this.scholarNo,
    this.initialAttendance,
  });

  @override
  State<AcademicAttendanceTab> createState() => _AcademicAttendanceTabState();
}

class _AcademicAttendanceTabState extends State<AcademicAttendanceTab> {
  late List<AttendanceRecord> _records;
  StreamSubscription<List<AttendanceRecord>>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialAttendance != null) {
      _records = widget.initialAttendance!;
    } else {
      _records = AuthService.getCachedAttendanceRecords(
        classLevel: widget.classLevel,
        scholarNo: widget.scholarNo,
      );
      _subscription = AuthService()
          .getAttendanceStream(
            classLevel: widget.classLevel,
            scholarNo: widget.scholarNo,
          )
          .listen((data) {
        if (mounted) {
          setState(() {
            _records = data;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = AttendanceSummary.fromRecords(_records);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(summary, isDark),
          if (summary.isCriticalThreshold && _records.isNotEmpty) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              label:
                  'Warning: Academic attendance at ${summary.percentage.toStringAsFixed(1)} percent is below the mandatory 75 percent Ministry threshold',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ministry Attendance Critical Warning',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Attendance is below the mandatory 75% statutory Ministry threshold or safety buffer. Please submit excused medical passes or consult academic guidance.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Builder(
            builder: (context) {
              final profile = AuthService.getCachedProfile();
              final isTeacherOrAdmin = HierarchyService.isTeacherOrFaculty(
                    role: profile?['role'],
                    scholarNo: profile?['scholar_no'],
                  ) ||
                  HierarchyService.isSuperAdmin(
                    role: profile?['role'],
                    scholarNo: profile?['scholar_no'],
                  );
              if (isTeacherOrAdmin) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTeacherMarkAttendanceAction(isDark),
                    const SizedBox(height: 16),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _buildLeavePassAction(isDark),
          _buildMedicalLeavesHistory(isDark),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Daily Attendance History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_records.length} Logs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_records.isEmpty)
            _buildEmptyState(isDark)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _records.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = _records[index];
                return _buildRecordCard(record, isDark);
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMedicalLeavesHistory(bool isDark) {
    final sNo = widget.scholarNo ?? (AuthService.getCachedScholarNo() ?? '2310910');
    return StreamBuilder<List<MedicalLeaveRequest>>(
      stream: AuthService().getMedicalLeavesStream(scholarNo: sNo),
      builder: (context, snapshot) {
        final leaves = snapshot.data ?? AuthService.getCachedMedicalLeaves(scholarNo: sNo);
        if (leaves.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🏥 Approved Medical Leaves & Excuses',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${leaves.length} Filed',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leaves.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final item = leaves[idx];
                final isApproved = item.status == MedicalLeaveStatus.approved;
                final isPending = item.status == MedicalLeaveStatus.pending;
                final statusColor = isApproved
                    ? const Color(0xFF10B981)
                    : (isPending ? Colors.amber : const Color(0xFFEF4444));
                final statusText = isApproved
                    ? 'Approved (Excused)'
                    : (isPending ? 'Pending Review' : 'Declined');

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151D2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isApproved
                                    ? Icons.check_circle_rounded
                                    : (isPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded),
                                color: statusColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.formattedRange,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (item.doctorName.isNotEmpty) ...[
                        Text(
                          'Clinic / Doctor: ${item.doctorName}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        'Reason: ${item.reason}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      if (item.adminRemark != null && item.adminRemark!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Admin Feedback: ${item.adminRemark}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(AttendanceSummary summary, bool isDark) {
    final compliant = summary.isMinistryCompliant;
    final badgeColor = compliant ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Attendance Telemetry',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        compliant ? Icons.verified : Icons.error_outline,
                        size: 14,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        compliant
                            ? 'Ministry 75% Met'
                            : 'Below 75% Threshold',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (summary.percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatPill('Present', '${summary.presentDays} d',
                  const Color(0xFF10B981), isDark),
              const SizedBox(width: 8),
              _buildStatPill('Absent', '${summary.absentDays} d',
                  const Color(0xFFEF4444), isDark),
              const SizedBox(width: 8),
              _buildStatPill(
                  'Late', '${summary.lateDays} d', Colors.amber, isDark),
              const SizedBox(width: 8),
              _buildStatPill('Excused', '${summary.excusedDays} d',
                  const Color(0xFF6366F1), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
      String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherMarkAttendanceAction(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.how_to_reg_rounded,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Faculty Attendance Desk',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Record student present, late, or absent for ${widget.classLevel}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            onPressed: _showMarkAttendanceDialog,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text(
              'Mark',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showMarkAttendanceDialog() {
    final defaultScholar = widget.scholarNo ?? (AuthService.getCachedScholarNo() ?? '2310910');
    final scholarController = TextEditingController(text: defaultScholar);
    final remarksController = TextEditingController();
    AttendanceStatus selectedStatus = AttendanceStatus.present;

    showDialog(
      context: context,
      builder: (ctx) => ManagedModalScope(
        controllers: [scholarController, remarksController],
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.how_to_reg_rounded, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 8),
                Text(
                  'Mark Attendance',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Level: ${widget.classLevel}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scholarController,
                    decoration: InputDecoration(
                      labelText: 'Student Scholar / Admission No.',
                      hintText: 'e.g. 2310910',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Attendance Status:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      AttendanceStatus.present,
                      AttendanceStatus.late,
                      AttendanceStatus.absent,
                      AttendanceStatus.excused,
                    ].map((st) {
                      final isSel = selectedStatus == st;
                      Color stColor;
                      switch (st) {
                        case AttendanceStatus.present:
                          stColor = const Color(0xFF10B981);
                          break;
                        case AttendanceStatus.late:
                          stColor = Colors.amber[700]!;
                          break;
                        case AttendanceStatus.absent:
                          stColor = const Color(0xFFEF4444);
                          break;
                        case AttendanceStatus.excused:
                          stColor = const Color(0xFF6366F1);
                          break;
                      }
                      return ChoiceChip(
                        label: Text(
                          st.name.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: isSel ? Colors.white : stColor,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: stColor,
                        backgroundColor: stColor.withValues(alpha: 0.12),
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedStatus = st);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: remarksController,
                    decoration: InputDecoration(
                      labelText: 'Remarks / Period Notes (Optional)',
                      hintText: 'e.g. Present in all 8 periods',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final targetScholar = scholarController.text.trim();
                  if (targetScholar.isEmpty) return;

                  Navigator.pop(ctx);
                  await AuthService().markStudentAttendance(
                    classLevel: widget.classLevel ?? 'Grade 10',
                    scholarNo: targetScholar,
                    status: selectedStatus,
                    remarks: remarksController.text.trim().isNotEmpty
                        ? remarksController.text.trim()
                        : null,
                  );

                  if (mounted) {
                    setState(() {
                      _records = AuthService.getCachedAttendanceRecords(
                        classLevel: widget.classLevel,
                        scholarNo: targetScholar,
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Attendance marked: #$targetScholar is ${selectedStatus.name.toUpperCase()}',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Save Attendance', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildLeavePassAction(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Color(0xFF6366F1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Leave Pass',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Submit sick leave & doctor notes',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Apply for Medical Leave Pass',
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _showLeavePassDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 0,
                ),
                child: const Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_task_rounded, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(AttendanceRecord record, bool isDark) {
    Color statusColor;
    switch (record.status) {
      case AttendanceStatus.present:
        statusColor = const Color(0xFF10B981);
        break;
      case AttendanceStatus.absent:
        statusColor = const Color(0xFFEF4444);
        break;
      case AttendanceStatus.late:
        statusColor = Colors.amber;
        break;
      case AttendanceStatus.excused:
        statusColor = const Color(0xFF6366F1);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                record.formattedDate,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    record.status.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (record.periodBreakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Period Breakdown Audit:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: record.periodBreakdown.entries.map((entry) {
                Color pColor;
                switch (entry.value) {
                  case AttendanceStatus.present:
                    pColor = const Color(0xFF10B981);
                    break;
                  case AttendanceStatus.absent:
                    pColor = const Color(0xFFEF4444);
                    break;
                  case AttendanceStatus.late:
                    pColor = Colors.amber;
                    break;
                  case AttendanceStatus.excused:
                    pColor = const Color(0xFF6366F1);
                    break;
                }

                return Semantics(
                  label: 'Period ${entry.key}: ${entry.value.displayName}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: pColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: pColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Period ${entry.key}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: pColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.value.shortCode,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (record.excusedReason != null &&
              record.excusedReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Note: ${record.excusedReason}',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
          if (record.certificateUrl != null &&
              record.certificateUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: HomeScreen.buildResilientImage(
                record.certificateUrl!,
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLeavePassDialog(BuildContext context) {
    final parentMessenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reasonController = TextEditingController();
    final doctorController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    String? photoBase64;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ManagedModalScope(
          controllers: [reasonController, doctorController],
          child: StatefulBuilder(
            builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🏥 Submit Medical Leave & Report',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Close dialog',
                          child: IconButton(
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Attach a photo of the Doctor\'s Prescription or Medical Certificate for administrative review and statutory attendance excuse.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  startDate = picked;
                                  if (endDate.isBefore(startDate)) endDate = startDate;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From Date', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('${startDate.day}/${startDate.month}/${startDate.year}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime.now().add(const Duration(days: 60)),
                              );
                              if (picked != null) {
                                setModalState(() => endDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('To Date', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('${endDate.day}/${endDate.month}/${endDate.year}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: doctorController,
                      decoration: InputDecoration(
                        labelText: 'Doctor / Clinic / Hospital Name',
                        hintText: 'e.g. Salmaniya Medical Complex',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Medical Reason / Diagnosis Notes',
                        hintText: 'e.g. Viral fever and respiratory rest prescribed',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '📸 Doctor Prescription / Medical Photo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (photoBase64 != null) ...[
                      Stack(
                        children: [
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(photoBase64!.split(',').last),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Semantics(
                              button: true,
                              label: 'Remove attached photo',
                              child: Material(
                                color: Colors.black87,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  padding: const EdgeInsets.all(12),
                                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                                  tooltip: 'Remove photo',
                                  onPressed: () => setModalState(() => photoBase64 = null),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final xfile = await picker.pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 80,
                                    maxWidth: 1200,
                                  );
                                  if (xfile != null) {
                                    final bytes = await xfile.readAsBytes();
                                    setModalState(() {
                                      photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Camera unavailable: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.camera_alt_rounded, size: 18),
                              label: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final xfile = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 80,
                                    maxWidth: 1200,
                                  );
                                  if (xfile != null) {
                                    final bytes = await xfile.readAsBytes();
                                    setModalState(() {
                                      photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Gallery picker failed: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.photo_library_rounded, size: 18),
                              label: const Text('Upload Image', style: TextStyle(fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (reasonController.text.trim().isEmpty) {
                            parentMessenger.showSnackBar(
                              const SnackBar(content: Text('Please provide medical reason / diagnosis notes.')),
                            );
                            return;
                          }
                          Navigator.of(ctx).pop();

                          final profile = AuthService.getCachedProfile();
                          final sNo = widget.scholarNo ?? (profile?['scholar_no'] ?? '2310910').toString();
                          final sName = (profile?['full_name'] ?? 'Mohammed Ayaan').toString();
                          final sHouse = AuthService.getCachedHouse() ?? 'ruby';
                          final sClass = widget.classLevel ?? (profile?['class_level'] ?? 'Grade 10').toString();

                          await AuthService().submitMedicalLeaveRequest(
                            scholarNo: sNo,
                            studentName: sName,
                            house: sHouse,
                            classLevel: sClass,
                            startDate: startDate,
                            endDate: endDate,
                            reason: reasonController.text,
                            doctorName: doctorController.text,
                            certificatePhotoBase64: photoBase64,
                          );

                          if (!mounted) return;
                          parentMessenger.showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Medical Leave Pass & Doctor Prescription submitted directly to Administration for approval!',
                              ),
                              backgroundColor: Colors.green[700],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Submit Medical Certificate to Admin',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 14),
          Text(
            'No Attendance Records Logged Yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Official school attendance registers and period absence records will appear here once submitted by faculty.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

