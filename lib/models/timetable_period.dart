import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Pure Dynamic Model representing an academic period in The Asian School Bahrain.
/// Zero hardcoded fallbacks; maps directly to Firestore documents and local JSON cache.
class TimetablePeriod implements Comparable<TimetablePeriod> {
  final int periodNumber;
  final String timeSlot;
  final String subject;
  final String teacherName;
  final String room;
  final bool isBreak;
  final String dayOfWeek;
  final String classLevel;

  const TimetablePeriod({
    required this.periodNumber,
    required this.timeSlot,
    required this.subject,
    required this.teacherName,
    required this.room,
    this.isBreak = false,
    this.dayOfWeek = '',
    this.classLevel = '',
  });

  /// Parse timeSlot string into (startTime, endTime) TimeOfDay pair.
  /// Supports: '07:45 - 08:35', '7:45 AM - 8:35 AM', '12:30 PM - 01:20 PM', '07:45-08:35'.
  static (TimeOfDay, TimeOfDay)? parseTimeSlot(String slot) {
    try {
      final parts = slot.split(RegExp(r'\s*-\s*'));
      if (parts.length != 2) return null;
      final start = _parseSingleTime(parts[0].trim());
      final end = _parseSingleTime(parts[1].trim());
      if (start != null && end != null) {
        return (start, end);
      }
    } catch (_) {}
    return null;
  }

  static TimeOfDay? _parseSingleTime(String str) {
    try {
      final upper = str.toUpperCase();
      final isPm = upper.contains('PM');
      final isAm = upper.contains('AM');
      final clean = str.replaceAll(RegExp(r'[AaPp][Mm]'), '').trim();
      final timeParts = clean.split(':');
      if (timeParts.length < 2) return null;
      int hour = int.parse(timeParts[0].trim());
      final minute = int.parse(timeParts[1].trim());
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {}
    return null;
  }

  /// Start time of period as TimeOfDay.
  TimeOfDay? get startTimeOfDay => parseTimeSlot(timeSlot)?.$1;

  /// End time of period as TimeOfDay.
  TimeOfDay? get endTimeOfDay => parseTimeSlot(timeSlot)?.$2;

  /// Start time as DateTime on given [date] (defaults to today).
  DateTime? getStartDateTime([DateTime? date]) {
    final tod = startTimeOfDay;
    if (tod == null) return null;
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, tod.hour, tod.minute);
  }

  /// End time as DateTime on given [date] (defaults to today).
  DateTime? getEndDateTime([DateTime? date]) {
    final tod = endTimeOfDay;
    if (tod == null) return null;
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, tod.hour, tod.minute);
  }

  /// Evaluates whether a given weekday integer (1=Mon ... 7=Sun) matches this period's dayOfWeek.
  static bool matchesDayOfWeek(String dayName, int weekday) {
    final d = dayName.trim().toLowerCase();
    if (d.isEmpty) return true;
    switch (weekday) {
      case DateTime.sunday:
        return d.startsWith('sun');
      case DateTime.monday:
        return d.startsWith('mon');
      case DateTime.tuesday:
        return d.startsWith('tue');
      case DateTime.wednesday:
        return d.startsWith('wed');
      case DateTime.thursday:
        return d.startsWith('thu');
      case DateTime.friday:
        return d.startsWith('fri');
      case DateTime.saturday:
        return d.startsWith('sat');
      default:
        return false;
    }
  }

  /// Evaluates whether the given timestamp [now] falls within this period's time window.
  bool isCurrentPeriod([DateTime? now, bool checkDayOfWeek = false]) {
    final target = now ?? DateTime.now();
    if (checkDayOfWeek && dayOfWeek.isNotEmpty && !matchesDayOfWeek(dayOfWeek, target.weekday)) {
      return false;
    }
    final start = getStartDateTime(target);
    final end = getEndDateTime(target);
    if (start == null || end == null) return false;
    return !target.isBefore(start) && target.isBefore(end);
  }

  /// Evaluates whether this period is in the future relative to [now].
  bool isUpcomingPeriod([DateTime? now, bool checkDayOfWeek = false]) {
    final target = now ?? DateTime.now();
    if (checkDayOfWeek && dayOfWeek.isNotEmpty && !matchesDayOfWeek(dayOfWeek, target.weekday)) {
      return false;
    }
    final start = getStartDateTime(target);
    if (start == null) return false;
    return target.isBefore(start);
  }

  /// Returns the remaining duration of this period relative to [now].
  Duration timeRemaining([DateTime? now]) {
    final target = now ?? DateTime.now();
    final end = getEndDateTime(target);
    if (end == null || target.isAfter(end)) return Duration.zero;
    return end.difference(target);
  }

  /// Human-readable remaining time string.
  String formattedRemaining([DateTime? now]) {
    final rem = timeRemaining(now);
    if (rem == Duration.zero) return 'Ended';
    final m = rem.inMinutes;
    if (m >= 60) {
      final h = rem.inHours;
      final restM = m % 60;
      return '${h}h ${restM}m remaining';
    }
    return '${m}m remaining';
  }

  /// Serialization to JSON / Firestore map.
  Map<String, dynamic> toMap() => {
    'period_number': periodNumber,
    'time_slot': timeSlot,
    'subject': subject,
    'teacher_name': teacherName,
    'room': room,
    'is_break': isBreak,
    'day_of_week': dayOfWeek,
    'class_level': classLevel,
  };

  Map<String, dynamic> toJson() => toMap();

  factory TimetablePeriod.fromMap(Map<String, dynamic> map, [String? id]) {
    final rawNum = map['period_number'] ?? map['periodNumber'] ?? map['period'];
    int pNum = 0;
    if (rawNum is num) {
      pNum = rawNum.toInt();
    } else if (rawNum is String) {
      pNum = int.tryParse(rawNum) ?? 0;
    } else if (id != null) {
      pNum = int.tryParse(id) ?? 0;
    }

    return TimetablePeriod(
      periodNumber: pNum,
      timeSlot: (map['time_slot'] ?? map['timeSlot'] ?? map['time'] ?? '').toString().trim(),
      subject: (map['subject'] ?? map['name'] ?? '').toString().trim(),
      teacherName: (map['teacher_name'] ?? map['teacherName'] ?? map['teacher'] ?? '').toString().trim(),
      room: (map['room'] ?? map['room_number'] ?? map['roomNumber'] ?? '').toString().trim(),
      isBreak: map['is_break'] == true || map['isBreak'] == true,
      dayOfWeek: (map['day_of_week'] ?? map['dayOfWeek'] ?? map['day'] ?? '').toString().trim(),
      classLevel: (map['class_level'] ?? map['classLevel'] ?? map['class'] ?? '').toString().trim(),
    );
  }

  factory TimetablePeriod.fromJson(Map<String, dynamic> json) => TimetablePeriod.fromMap(json);

  factory TimetablePeriod.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TimetablePeriod.fromMap(data, doc.id);
  }

  TimetablePeriod copyWith({
    int? periodNumber,
    String? timeSlot,
    String? subject,
    String? teacherName,
    String? room,
    bool? isBreak,
    String? dayOfWeek,
    String? classLevel,
  }) {
    return TimetablePeriod(
      periodNumber: periodNumber ?? this.periodNumber,
      timeSlot: timeSlot ?? this.timeSlot,
      subject: subject ?? this.subject,
      teacherName: teacherName ?? this.teacherName,
      room: room ?? this.room,
      isBreak: isBreak ?? this.isBreak,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      classLevel: classLevel ?? this.classLevel,
    );
  }

  @override
  int compareTo(TimetablePeriod other) => periodNumber.compareTo(other.periodNumber);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimetablePeriod &&
        other.periodNumber == periodNumber &&
        other.timeSlot == timeSlot &&
        other.subject == subject &&
        other.teacherName == teacherName &&
        other.room == room &&
        other.isBreak == isBreak &&
        other.dayOfWeek == dayOfWeek &&
        other.classLevel == classLevel;
  }

  @override
  int get hashCode => Object.hash(
    periodNumber,
    timeSlot,
    subject,
    teacherName,
    room,
    isBreak,
    dayOfWeek,
    classLevel,
  );

  @override
  String toString() {
    return 'TimetablePeriod(P$periodNumber: $subject, $timeSlot, Room: $room, Teacher: $teacherName, Day: $dayOfWeek)';
  }
}
