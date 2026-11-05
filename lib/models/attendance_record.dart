import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of attendance for a full school day or individual period.
enum AttendanceStatus {
  present,
  absent,
  late,
  excused,
}

extension AttendanceStatusExt on AttendanceStatus {
  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Tardy / Late';
      case AttendanceStatus.excused:
        return 'Excused Leave';
    }
  }

  String get shortCode {
    switch (this) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.late:
        return 'L';
      case AttendanceStatus.excused:
        return 'E';
    }
  }
}

/// Comprehensive daily student attendance record with period-wise audit breakdown.
class AttendanceRecord implements Comparable<AttendanceRecord> {
  final String id;
  final String scholarNo;
  final DateTime date;
  final AttendanceStatus status;
  final Map<int, AttendanceStatus> periodBreakdown; // Period 1 to 8
  final String? excusedReason;
  final String? certificateUrl; // Base64 or URL
  final bool isApproved;
  final String classLevel;

  const AttendanceRecord({
    required this.id,
    required this.scholarNo,
    required this.date,
    required this.status,
    this.periodBreakdown = const {},
    this.excusedReason,
    this.certificateUrl,
    this.isApproved = true,
    this.classLevel = '',
  });

  bool get isFullDayPresent =>
      status == AttendanceStatus.present &&
      periodBreakdown.values.every((s) => s == AttendanceStatus.present);

  bool get hasPeriodAbsence =>
      periodBreakdown.values.any((s) => s == AttendanceStatus.absent);

  int get missedPeriodCount =>
      periodBreakdown.values.where((s) => s == AttendanceStatus.absent).length;

  /// Formatted date string (e.g. "Mon, 02 Oct 2026").
  String get formattedDate {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    return '$weekday, $day $month ${date.year}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'scholar_no': scholarNo,
        'date': date.toIso8601String(),
        'status': status.name,
        'period_breakdown':
            periodBreakdown.map((k, v) => MapEntry(k.toString(), v.name)),
        'excused_reason': excusedReason,
        'certificate_url': certificateUrl,
        'is_approved': isApproved,
        'class_level': classLevel,
      };

  Map<String, dynamic> toJson() => toMap();

  factory AttendanceRecord.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      if (val is int) {
        return DateTime.fromMillisecondsSinceEpoch(val);
      }
      return DateTime.now();
    }

    AttendanceStatus parseStatus(dynamic val) {
      final s = (val ?? 'present').toString().toLowerCase().trim();
      return AttendanceStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == s,
        orElse: () => AttendanceStatus.present,
      );
    }

    final rawPeriods =
        map['period_breakdown'] ?? map['periodBreakdown'] ?? {};
    final Map<int, AttendanceStatus> periods = {};
    if (rawPeriods is Map) {
      rawPeriods.forEach((k, v) {
        final periodNum = int.tryParse(k.toString());
        if (periodNum != null) {
          periods[periodNum] = parseStatus(v);
        }
      });
    }

    return AttendanceRecord(
      id: (map['id'] ?? docId ?? '').toString().trim(),
      scholarNo:
          (map['scholar_no'] ?? map['scholarNo'] ?? '').toString().trim(),
      date: parseDate(map['date']),
      status: parseStatus(map['status']),
      periodBreakdown: periods,
      excusedReason: map['excused_reason'] ?? map['excusedReason'],
      certificateUrl: map['certificate_url'] ?? map['certificateUrl'],
      isApproved: map['is_approved'] ?? map['isApproved'] ?? true,
      classLevel:
          (map['class_level'] ?? map['classLevel'] ?? '').toString().trim(),
    );
  }

  factory AttendanceRecord.fromJson(dynamic json) {
    if (json is String) {
      return AttendanceRecord.fromMap(jsonDecode(json) as Map<String, dynamic>);
    }
    return AttendanceRecord.fromMap(json as Map<String, dynamic>);
  }

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AttendanceRecord.fromMap(data, doc.id);
  }

  @override
  int compareTo(AttendanceRecord other) => other.date.compareTo(date); // Descending
}

/// Aggregate attendance metrics with Ministry of Education 75% threshold telemetry.
class AttendanceSummary {
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int excusedDays;

  const AttendanceSummary({
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.excusedDays,
  });

  double get percentage =>
      totalDays > 0 ? (presentDays / totalDays) * 100 : 100.0;

  bool get isMinistryCompliant => percentage >= 75.0;

  bool get isCriticalThreshold => percentage < 80.0;

  factory AttendanceSummary.fromRecords(List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return const AttendanceSummary(
        totalDays: 0,
        presentDays: 0,
        absentDays: 0,
        lateDays: 0,
        excusedDays: 0,
      );
    }

    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;

    for (final r in records) {
      switch (r.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.late:
          late++;
          break;
        case AttendanceStatus.excused:
          excused++;
          break;
      }
    }

    return AttendanceSummary(
      totalDays: records.length,
      presentDays: present,
      absentDays: absent,
      lateDays: late,
      excusedDays: excused,
    );
  }
}
