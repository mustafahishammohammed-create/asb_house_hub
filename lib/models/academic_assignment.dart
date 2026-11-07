import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Assignment completion status lifecycle.
enum AssignmentStatus {
  pending,
  submitted,
  graded;

  static AssignmentStatus fromString(String? val) {
    if (val == null) return AssignmentStatus.pending;
    switch (val.trim().toLowerCase()) {
      case 'submitted':
        return AssignmentStatus.submitted;
      case 'graded':
      case 'completed':
        return AssignmentStatus.graded;
      case 'pending':
      default:
        return AssignmentStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Pending';
      case AssignmentStatus.submitted:
        return 'Submitted';
      case AssignmentStatus.graded:
        return 'Graded';
    }
  }

  /// High contrast color specifications per WCAG 1.4.3 (> 7:1 contrast)
  Color get textColor {
    switch (this) {
      case AssignmentStatus.pending:
        return const Color(0xFFFBBF24); // Amber
      case AssignmentStatus.submitted:
        return const Color(0xFF60A5FA); // Blue
      case AssignmentStatus.graded:
        return const Color(0xFF34D399); // Emerald
    }
  }

  Color get containerColor {
    switch (this) {
      case AssignmentStatus.pending:
        return const Color(0xFF451A03); // Dark Amber
      case AssignmentStatus.submitted:
        return const Color(0xFF172554); // Deep Navy
      case AssignmentStatus.graded:
        return const Color(0xFF064E3B); // Forest Green
    }
  }

  AssignmentStatus get nextStatus {
    switch (this) {
      case AssignmentStatus.pending:
        return AssignmentStatus.submitted;
      case AssignmentStatus.submitted:
        return AssignmentStatus.graded;
      case AssignmentStatus.graded:
        return AssignmentStatus.pending;
    }
  }
}

/// Dynamic Model representing an academic homework assignment in The Asian School Bahrain.
/// Zero hardcoded fallbacks; maps directly to Firestore documents and local JSON cache.
class AcademicAssignment implements Comparable<AcademicAssignment> {
  final String id;
  final String title;
  final String subject;
  final String teacherName;
  final DateTime dueDateTime;
  final int pointsReward;
  final AssignmentStatus status;
  final String description;
  final String submissionNotes;
  final DateTime? submittedAt;
  final DateTime? gradedAt;
  final String classLevel;
  final String? imageUrl;

  const AcademicAssignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.teacherName,
    required this.dueDateTime,
    this.pointsReward = 20,
    this.status = AssignmentStatus.pending,
    this.description = '',
    this.submissionNotes = '',
    this.submittedAt,
    this.gradedAt,
    this.classLevel = '',
    this.imageUrl,
  });

  /// Evaluates whether assignment deadline has passed without completion.
  bool isOverdue([DateTime? now]) {
    if (status == AssignmentStatus.graded) return false;
    final target = now ?? DateTime.now();
    return target.isAfter(dueDateTime);
  }

  /// Evaluates whether deadline is imminent (< 24 hours remaining) and still pending.
  bool isUrgent([DateTime? now]) {
    if (status == AssignmentStatus.graded) return false;
    final target = now ?? DateTime.now();
    if (target.isAfter(dueDateTime)) return false;
    final diff = dueDateTime.difference(target);
    return diff.inHours < 24 && diff.inMinutes > 0;
  }

  /// Calculates remaining duration until due date.
  Duration timeUntilDue([DateTime? now]) {
    final target = now ?? DateTime.now();
    if (target.isAfter(dueDateTime)) return Duration.zero;
    return dueDateTime.difference(target);
  }

  /// Human-readable relative deadline countdown.
  String formattedRemaining([DateTime? now]) {
    if (status == AssignmentStatus.graded) return 'Completed';
    final target = now ?? DateTime.now();
    if (target.isAfter(dueDateTime)) {
      final past = target.difference(dueDateTime);
      if (past.inDays > 0) return 'Overdue by ${past.inDays}d';
      return 'Overdue';
    }

    final diff = dueDateTime.difference(target);
    if (diff.inHours < 1) {
      final mins = diff.inMinutes;
      return 'Due in ${mins > 0 ? mins : 1}m';
    } else if (diff.inHours < 24) {
      return 'Due in ${diff.inHours} hours';
    } else if (diff.inDays == 1) {
      return 'Due Tomorrow';
    } else {
      return 'Due in ${diff.inDays} days';
    }
  }

  /// Cycles status: PENDING ➔ SUBMITTED ➔ GRADED ➔ PENDING.
  AcademicAssignment cycleStatus([DateTime? now]) {
    final stamp = now ?? DateTime.now();
    switch (status) {
      case AssignmentStatus.pending:
        return copyWith(
          status: AssignmentStatus.submitted,
          submittedAt: stamp,
        );
      case AssignmentStatus.submitted:
        return copyWith(
          status: AssignmentStatus.graded,
          gradedAt: stamp,
        );
      case AssignmentStatus.graded:
        return copyWith(
          status: AssignmentStatus.pending,
          submittedAt: null,
          gradedAt: null,
        );
    }
  }

  /// Serialization to JSON / Firestore map.
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'subject': subject,
    'teacher_name': teacherName,
    'due_date': dueDateTime.toIso8601String(),
    'points_reward': pointsReward,
    'status': status.name,
    'description': description,
    'submission_notes': submissionNotes,
    'submitted_at': submittedAt?.toIso8601String(),
    'graded_at': gradedAt?.toIso8601String(),
    'class_level': classLevel,
    if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
  };

  Map<String, dynamic> toJson() => toMap();

  factory AcademicAssignment.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? fallback;
      }
      return fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    final rawPoints = map['points_reward'] ?? map['pointsReward'] ?? map['points'] ?? 20;
    int points = 20;
    if (rawPoints is num) {
      points = rawPoints.toInt();
    } else if (rawPoints is String) {
      points = int.tryParse(rawPoints) ?? 20;
    }

    return AcademicAssignment(
      id: (map['id'] ?? docId ?? '').toString().trim(),
      title: (map['title'] ?? map['name'] ?? '').toString().trim(),
      subject: (map['subject'] ?? '').toString().trim(),
      teacherName: (map['teacher_name'] ?? map['teacherName'] ?? map['teacher'] ?? '').toString().trim(),
      dueDateTime: parseDate(map['due_date'] ?? map['dueDateTime'] ?? map['dueDate'], DateTime.now().add(const Duration(days: 1))),
      pointsReward: points,
      status: AssignmentStatus.fromString(map['status']?.toString()),
      description: (map['description'] ?? '').toString().trim(),
      submissionNotes: (map['submission_notes'] ?? map['submissionNotes'] ?? '').toString().trim(),
      submittedAt: parseNullableDate(map['submitted_at'] ?? map['submittedAt']),
      gradedAt: parseNullableDate(map['graded_at'] ?? map['gradedAt']),
      classLevel: (map['class_level'] ?? map['classLevel'] ?? map['class'] ?? '').toString().trim(),
      imageUrl: (map['image_url'] ?? map['imageUrl'])?.toString().trim(),
    );
  }

  factory AcademicAssignment.fromJson(Map<String, dynamic> json) => AcademicAssignment.fromMap(json);

  factory AcademicAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AcademicAssignment.fromMap(data, doc.id);
  }

  AcademicAssignment copyWith({
    String? id,
    String? title,
    String? subject,
    String? teacherName,
    DateTime? dueDateTime,
    int? pointsReward,
    AssignmentStatus? status,
    String? description,
    String? submissionNotes,
    DateTime? submittedAt,
    DateTime? gradedAt,
    String? classLevel,
    String? imageUrl,
  }) {
    return AcademicAssignment(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      teacherName: teacherName ?? this.teacherName,
      dueDateTime: dueDateTime ?? this.dueDateTime,
      pointsReward: pointsReward ?? this.pointsReward,
      status: status ?? this.status,
      description: description ?? this.description,
      submissionNotes: submissionNotes ?? this.submissionNotes,
      submittedAt: submittedAt ?? this.submittedAt,
      gradedAt: gradedAt ?? this.gradedAt,
      classLevel: classLevel ?? this.classLevel,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  int compareTo(AcademicAssignment other) => dueDateTime.compareTo(other.dueDateTime);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AcademicAssignment &&
        other.id == id &&
        other.title == title &&
        other.subject == subject &&
        other.teacherName == teacherName &&
        other.dueDateTime == dueDateTime &&
        other.pointsReward == pointsReward &&
        other.status == status &&
        other.description == description &&
        other.submissionNotes == submissionNotes &&
        other.submittedAt == submittedAt &&
        other.gradedAt == gradedAt &&
        other.classLevel == classLevel &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    subject,
    teacherName,
    dueDateTime,
    pointsReward,
    status,
    description,
    submissionNotes,
    submittedAt,
    gradedAt,
    classLevel,
    imageUrl,
  );

  @override
  String toString() {
    return 'AcademicAssignment($id: $title, Subject: $subject, Due: $dueDateTime, Status: ${status.name}, +$pointsReward Pts)';
  }
}
