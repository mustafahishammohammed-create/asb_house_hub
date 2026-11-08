import 'package:cloud_firestore/cloud_firestore.dart';

import 'academic_class.dart';
import 'timetable_period.dart';

/// Six-day recurring school week for the teacher-managed timetable (spec M2).
/// Friday is a weekend; each day is configured independently and recurs weekly.
const List<String> kTimetableWeekDays = [
  'Saturday',
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
];

/// Mandated structure (spec §2.1 / M2 §5): exactly eight 45-minute teaching
/// periods plus one separate 30-minute break. Durations are fixed; teachers
/// customise start times and the system derives every end time.
const int kTeachingPeriodCount = 8;
const int kTeachingPeriodMinutes = 45;
const int kBreakMinutes = 30;
const int kDefaultBreakAfterPeriod = 4;
const int kMinutesPerDay = 24 * 60;

/// Lifecycle of a timetable version. Only [published] versions recur and are
/// visible to students; [submitted] awaits administrator approval.
class TimetableStatus {
  TimetableStatus._();

  static const String draft = 'draft';
  static const String submitted = 'submitted';
  static const String published = 'published';
  static const String rejected = 'rejected';

  static const List<String> all = [draft, submitted, published, rejected];
}

/// Maps a weekday integer (DateTime.monday=1 ... DateTime.sunday=7) to the
/// six-day school week. Friday rolls forward to Saturday (next school day).
String timetableDayForWeekday(int weekday) {
  switch (weekday) {
    case DateTime.saturday:
      return 'Saturday';
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
      return 'Saturday';
  }
}

/// One teaching period within a day version. The end time is always derived
/// from the fixed 45-minute duration; only [startMinute] is teacher-editable.
class TimetableSlot {
  final int periodNumber;
  final String subject;
  final String teacherName;
  final String teacherUid;
  final String room;
  final int startMinute;
  final String imageUrl;
  final String notes;

  const TimetableSlot({
    required this.periodNumber,
    this.subject = '',
    this.teacherName = '',
    this.teacherUid = '',
    this.room = '',
    this.startMinute = -1,
    this.imageUrl = '',
    this.notes = '',
  });

  bool get hasStart => startMinute >= 0 && startMinute < kMinutesPerDay;

  int get endMinute =>
      startMinute < 0 ? -1 : startMinute + kTeachingPeriodMinutes;

  static String formatMinute(int minute) {
    if (minute < 0) return '--:--';
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Display slot consumed by [TimetablePeriod.parseTimeSlot], e.g. '07:45 - 08:30'.
  String get timeSlot =>
      '${formatMinute(startMinute)} - ${formatMinute(endMinute)}';

  Map<String, dynamic> toMap() => {
        'period_number': periodNumber,
        'subject': subject,
        'teacher_name': teacherName,
        'teacher_uid': teacherUid,
        'room': room,
        'start_minute': startMinute,
        if (imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (notes.isNotEmpty) 'notes': notes,
      };

  factory TimetableSlot.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic v, [int fallback = 0]) {
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? fallback;
    }

    return TimetableSlot(
      periodNumber: parseInt(map['period_number'] ?? map['periodNumber']),
      subject: (map['subject'] ?? '').toString().trim(),
      teacherName: (map['teacher_name'] ?? map['teacherName'] ?? '').toString().trim(),
      teacherUid: (map['teacher_uid'] ?? map['teacherUid'] ?? '').toString().trim(),
      room: (map['room'] ?? '').toString().trim(),
      startMinute: parseInt(map['start_minute'] ?? map['startMinute'], -1),
      imageUrl: (map['image_url'] ?? map['imageUrl'] ?? '').toString().trim(),
      notes: (map['notes'] ?? '').toString().trim(),
    );
  }

  TimetableSlot copyWith({
    int? periodNumber,
    String? subject,
    String? teacherName,
    String? teacherUid,
    String? room,
    int? startMinute,
    String? imageUrl,
    String? notes,
  }) {
    return TimetableSlot(
      periodNumber: periodNumber ?? this.periodNumber,
      subject: subject ?? this.subject,
      teacherName: teacherName ?? this.teacherName,
      teacherUid: teacherUid ?? this.teacherUid,
      room: room ?? this.room,
      startMinute: startMinute ?? this.startMinute,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
    );
  }
}

/// A full, self-contained day schedule for one canonical class. Versions are
/// immutable once published; a change creates a new version with its own
/// [effectiveFrom] date, and the active version for any date is the published
/// one with the greatest effective date on or before it (spec M2 §2-4).
class ClassTimetableVersion {
  final String id;
  final String classId;
  final String dayOfWeek;
  final String status;
  final DateTime effectiveFrom;
  final int version;
  final int breakAfterPeriod;
  final int breakStartMinute;
  final List<TimetableSlot> slots;
  final String createdByUid;
  final String createdByName;
  final DateTime? publishedAt;
  final String approvedByUid;
  final String approvedByName;
  final String rejectionReason;
  final String supersedesId;
  final DateTime? createdAt;

  const ClassTimetableVersion({
    this.id = '',
    required this.classId,
    required this.dayOfWeek,
    this.status = TimetableStatus.draft,
    required this.effectiveFrom,
    this.version = 1,
    this.breakAfterPeriod = kDefaultBreakAfterPeriod,
    this.breakStartMinute = -1,
    this.slots = const [],
    this.createdByUid = '',
    this.createdByName = '',
    this.publishedAt,
    this.approvedByUid = '',
    this.approvedByName = '',
    this.rejectionReason = '',
    this.supersedesId = '',
    this.createdAt,
  });

  int get breakEndMinute =>
      breakStartMinute < 0 ? -1 : breakStartMinute + kBreakMinutes;

  bool get isPublished => status == TimetableStatus.published;

  /// A valid default day laid out sequentially from [dayStartMinute] with the
  /// break after [breakAfterPeriod]. Teachers adjust individual start times.
  factory ClassTimetableVersion.template({
    required String classId,
    required String dayOfWeek,
    int dayStartMinute = 465, // 07:45
    int breakAfterPeriod = kDefaultBreakAfterPeriod,
    String createdByUid = '',
    String createdByName = '',
    DateTime? effectiveFrom,
  }) {
    final slots = <TimetableSlot>[];
    var cursor = dayStartMinute;
    var breakStart = -1;
    for (var n = 1; n <= kTeachingPeriodCount; n++) {
      slots.add(TimetableSlot(periodNumber: n, startMinute: cursor));
      cursor += kTeachingPeriodMinutes;
      if (n == breakAfterPeriod) {
        breakStart = cursor;
        cursor += kBreakMinutes;
      }
    }
    final now = DateTime.now();
    return ClassTimetableVersion(
      classId: classId,
      dayOfWeek: dayOfWeek,
      effectiveFrom: effectiveFrom ?? DateTime(now.year, now.month, now.day),
      breakAfterPeriod: breakAfterPeriod,
      breakStartMinute: breakStart,
      slots: slots,
      createdByUid: createdByUid,
      createdByName: createdByName,
    );
  }

  /// Ordered teaching periods with the break inserted after [breakAfterPeriod],
  /// rendered through the existing [TimetablePeriod] model so current/next
  /// highlighting and photo support are preserved.
  List<TimetablePeriod> toPeriods() {
    final ordered = [...slots]
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    final result = <TimetablePeriod>[];
    for (final slot in ordered) {
      result.add(TimetablePeriod(
        periodNumber: slot.periodNumber,
        timeSlot: slot.timeSlot,
        subject: slot.subject.isEmpty ? 'Period ${slot.periodNumber}' : slot.subject,
        teacherName: slot.teacherName,
        room: slot.room,
        dayOfWeek: dayOfWeek,
        classLevel: classId,
        imageUrl: slot.imageUrl.isEmpty ? null : slot.imageUrl,
      ));
      if (slot.periodNumber == breakAfterPeriod) {
        result.add(TimetablePeriod(
          periodNumber: 0,
          timeSlot:
              '${TimetableSlot.formatMinute(breakStartMinute)} - ${TimetableSlot.formatMinute(breakEndMinute)}',
          subject: 'Break',
          teacherName: '',
          room: '',
          isBreak: true,
          dayOfWeek: dayOfWeek,
          classLevel: classId,
        ));
      }
    }
    return result;
  }

  /// Validates the mandated structure. Durations (45/30) are fixed by
  /// construction, so checks focus on count, numbering, start presence,
  /// chronology, overlap and day bounds. Empty list means valid.
  List<String> validate() {
    final errors = <String>{};
    if (slots.length != kTeachingPeriodCount) {
      errors.add('Exactly $kTeachingPeriodCount teaching periods are required.');
    }
    final ordered = [...slots]
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].periodNumber != i + 1) {
        errors.add('Teaching periods must be numbered 1 through $kTeachingPeriodCount.');
        break;
      }
    }
    if (breakAfterPeriod < 1 || breakAfterPeriod > kTeachingPeriodCount) {
      errors.add('Break must follow a teaching period (1-$kTeachingPeriodCount).');
    }
    for (final s in ordered) {
      if (!s.hasStart) errors.add('Period ${s.periodNumber} needs a valid start time.');
    }
    if (breakStartMinute < 0 || breakStartMinute >= kMinutesPerDay) {
      errors.add('The break needs a valid start time.');
    }

    final timeline = <(int, int, String)>[];
    for (final s in ordered) {
      if (s.hasStart) timeline.add((s.startMinute, s.endMinute, 'Period ${s.periodNumber}'));
      if (s.periodNumber == breakAfterPeriod && breakStartMinute >= 0) {
        timeline.add((breakStartMinute, breakEndMinute, 'Break'));
      }
    }
    var prevEnd = -1;
    for (final (start, end, name) in timeline) {
      if (start < prevEnd) {
        errors.add('$name overlaps or precedes the previous slot; timings must be chronological.');
      }
      if (end > kMinutesPerDay) errors.add('$name extends beyond midnight.');
      prevEnd = end;
    }
    return errors.toList();
  }

  bool get isValid => validate().isEmpty;

  /// Resolves the recurring active version for [date]: the published version
  /// with the greatest effective date on or before [date] (ties broken by
  /// version number). Returns null when nothing is published yet.
  static ClassTimetableVersion? activeForDate(
    List<ClassTimetableVersion> versions,
    DateTime date,
  ) {
    final target = DateTime(date.year, date.month, date.day);
    ClassTimetableVersion? best;
    DateTime? bestEff;
    for (final v in versions) {
      if (!v.isPublished) continue;
      final eff = DateTime(v.effectiveFrom.year, v.effectiveFrom.month, v.effectiveFrom.day);
      if (eff.isAfter(target)) continue;
      if (best == null ||
          eff.isAfter(bestEff!) ||
          (eff.isAtSameMomentAs(bestEff) && v.version > best.version)) {
        best = v;
        bestEff = eff;
      }
    }
    return best;
  }

  Map<String, dynamic> toMap() => {
        if (id.isNotEmpty) 'id': id,
        'class_id': classId,
        'day_of_week': dayOfWeek,
        'status': status,
        'effective_from': Timestamp.fromDate(effectiveFrom),
        'version': version,
        'break_after_period': breakAfterPeriod,
        'break_start_minute': breakStartMinute,
        'slots': slots.map((s) => s.toMap()).toList(),
        'created_by_uid': createdByUid,
        'created_by_name': createdByName,
        if (publishedAt != null) 'published_at': Timestamp.fromDate(publishedAt!),
        if (approvedByUid.isNotEmpty) 'approved_by_uid': approvedByUid,
        if (approvedByName.isNotEmpty) 'approved_by_name': approvedByName,
        if (rejectionReason.isNotEmpty) 'rejection_reason': rejectionReason,
        if (supersedesId.isNotEmpty) 'supersedes_id': supersedesId,
        if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      };

  /// JSON-safe serialization for SharedPreferences cache (converts Timestamps to ISO strings).
  Map<String, dynamic> toJsonMap() {
    final map = Map<String, dynamic>.from(toMap());
    map['effective_from'] = effectiveFrom.toIso8601String();
    if (publishedAt != null) map['published_at'] = publishedAt!.toIso8601String();
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
    return map;
  }

  factory ClassTimetableVersion.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic v, [DateTime? fallback]) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    int parseInt(dynamic v, [int fallback = 0]) {
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? fallback;
    }

    final rawSlots = map['slots'];
    final slots = <TimetableSlot>[];
    if (rawSlots is List) {
      for (final item in rawSlots.whereType<Map>()) {
        slots.add(TimetableSlot.fromMap(Map<String, dynamic>.from(item)));
      }
    }
    final classId = (map['class_id'] ?? map['classId'] ?? '').toString().trim();
    return ClassTimetableVersion(
      id: (map['id'] ?? docId ?? '').toString().trim(),
      classId: classId,
      dayOfWeek: (map['day_of_week'] ?? map['dayOfWeek'] ?? '').toString().trim(),
      status: (map['status'] ?? TimetableStatus.draft).toString().trim(),
      effectiveFrom: parseDate(map['effective_from'] ?? map['effectiveFrom']),
      version: parseInt(map['version'], 1),
      breakAfterPeriod: parseInt(map['break_after_period'] ?? map['breakAfterPeriod'], kDefaultBreakAfterPeriod),
      breakStartMinute: parseInt(map['break_start_minute'] ?? map['breakStartMinute'], -1),
      slots: slots,
      createdByUid: (map['created_by_uid'] ?? map['createdByUid'] ?? '').toString().trim(),
      createdByName: (map['created_by_name'] ?? map['createdByName'] ?? '').toString().trim(),
      publishedAt: parseNullableDate(map['published_at'] ?? map['publishedAt']),
      approvedByUid: (map['approved_by_uid'] ?? map['approvedByUid'] ?? '').toString().trim(),
      approvedByName: (map['approved_by_name'] ?? map['approvedByName'] ?? '').toString().trim(),
      rejectionReason: (map['rejection_reason'] ?? map['rejectionReason'] ?? '').toString().trim(),
      supersedesId: (map['supersedes_id'] ?? map['supersedesId'] ?? '').toString().trim(),
      createdAt: parseNullableDate(map['created_at'] ?? map['createdAt']),
    );
  }

  factory ClassTimetableVersion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClassTimetableVersion.fromMap(data, doc.id);
  }

  ClassTimetableVersion copyWith({
    String? id,
    String? classId,
    String? dayOfWeek,
    String? status,
    DateTime? effectiveFrom,
    int? version,
    int? breakAfterPeriod,
    int? breakStartMinute,
    List<TimetableSlot>? slots,
    String? createdByUid,
    String? createdByName,
    DateTime? publishedAt,
    String? approvedByUid,
    String? approvedByName,
    String? rejectionReason,
    String? supersedesId,
    DateTime? createdAt,
  }) {
    return ClassTimetableVersion(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      status: status ?? this.status,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      version: version ?? this.version,
      breakAfterPeriod: breakAfterPeriod ?? this.breakAfterPeriod,
      breakStartMinute: breakStartMinute ?? this.breakStartMinute,
      slots: slots ?? this.slots,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      publishedAt: publishedAt ?? this.publishedAt,
      approvedByUid: approvedByUid ?? this.approvedByUid,
      approvedByName: approvedByName ?? this.approvedByName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      supersedesId: supersedesId ?? this.supersedesId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Canonical class label for display, e.g. '11D · Wednesday'.
  String get displayLabel {
    final parsed = AcademicStructure.parseClassId(classId);
    final classLabel = parsed != null ? classId : classId;
    return '$classLabel · $dayOfWeek';
  }
}