import 'package:cloud_firestore/cloud_firestore.dart';

/// Mid-term examination schedule entity with countdown telemetry,
/// syllabus outline, and exam hall/desk allocation.
class ExamScheduleItem implements Comparable<ExamScheduleItem> {
  final String id;
  final String subject;
  final String paperTitle;
  final DateTime examDateTime;
  final int durationMinutes;
  final String examHall;
  final String seatRow;
  final List<String> syllabusTopics;
  final List<String> readingMaterials;
  final int maxMarks;
  final String classLevel;
  final String? imageUrl;

  const ExamScheduleItem({
    required this.id,
    required this.subject,
    required this.paperTitle,
    required this.examDateTime,
    this.durationMinutes = 90,
    required this.examHall,
    this.seatRow = 'General Seating',
    this.syllabusTopics = const [],
    this.readingMaterials = const [],
    this.maxMarks = 100,
    this.classLevel = '',
    this.imageUrl,
  });

  /// Evaluates whether the exam is currently underway.
  bool isInProgress([DateTime? now]) {
    final target = now ?? DateTime.now();
    final examEnd = examDateTime.add(Duration(minutes: durationMinutes));
    return (target.isAfter(examDateTime) || target.isAtSameMomentAs(examDateTime)) &&
        target.isBefore(examEnd);
  }

  /// Evaluates whether the exam has already finished.
  bool isConcluded([DateTime? now]) {
    final target = now ?? DateTime.now();
    final examEnd = examDateTime.add(Duration(minutes: durationMinutes));
    return target.isAfter(examEnd) || target.isAtSameMomentAs(examEnd);
  }

  /// Evaluates whether the exam is starting within the next 24 hours and has not yet started.
  bool isUrgent([DateTime? now]) {
    final target = now ?? DateTime.now();
    if (isInProgress(target) || isConcluded(target)) return false;
    if (target.isAfter(examDateTime) || target.isAtSameMomentAs(examDateTime)) {
      return false;
    }
    final diff = examDateTime.difference(target);
    return diff > Duration.zero && diff.inHours < 24;
  }

  /// Duration until exam begins.
  Duration timeUntilExam([DateTime? now]) {
    final target = now ?? DateTime.now();
    if (target.isAfter(examDateTime)) return Duration.zero;
    return examDateTime.difference(target);
  }

  /// Human-readable relative countdown telemetry string.
  String formattedCountdown([DateTime? now]) {
    final target = now ?? DateTime.now();

    if (isInProgress(target)) {
      final examEnd = examDateTime.add(Duration(minutes: durationMinutes));
      final remainingMins = examEnd.difference(target).inMinutes;
      return remainingMins > 0 ? 'In Progress ($remainingMins min left)' : 'In Progress';
    }

    if (isConcluded(target)) {
      return 'Concluded';
    }

    final diff = examDateTime.difference(target);
    if (diff.inHours < 1) {
      final mins = diff.inMinutes;
      return 'Starts in ${mins > 0 ? mins : 1}m';
    } else if (diff.inHours < 24) {
      return 'Starts in ${diff.inHours} hours';
    } else {
      final targetDay = DateTime(target.year, target.month, target.day);
      final examDay = DateTime(examDateTime.year, examDateTime.month, examDateTime.day);
      final calendarDays = examDay.difference(targetDay).inDays;
      if (calendarDays <= 1) {
        return 'Starts Tomorrow';
      }
      return 'Starts in $calendarDays days';
    }
  }

  /// Serialization to JSON / Firestore map.
  Map<String, dynamic> toMap() => {
    'id': id,
    'subject': subject,
    'paper_title': paperTitle,
    'exam_date_time': examDateTime.toIso8601String(),
    'duration_minutes': durationMinutes,
    'exam_hall': examHall,
    'seat_row': seatRow,
    'syllabus_topics': syllabusTopics,
    'reading_materials': readingMaterials,
    'max_marks': maxMarks,
    'class_level': classLevel,
    if (imageUrl != null) 'image_url': imageUrl,
  };

  Map<String, dynamic> toJson() => toMap();

  factory ExamScheduleItem.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? fallback;
      }
      return fallback;
    }

    final rawDuration = map['duration_minutes'] ?? map['durationMinutes'] ?? map['duration'] ?? 90;
    int duration = 90;
    if (rawDuration is num) {
      duration = rawDuration.toInt();
    } else if (rawDuration is String) {
      duration = int.tryParse(rawDuration) ?? 90;
    }

    final rawMarks = map['max_marks'] ?? map['maxMarks'] ?? map['marks'] ?? 100;
    int marks = 100;
    if (rawMarks is num) {
      marks = rawMarks.toInt();
    } else if (rawMarks is String) {
      marks = int.tryParse(rawMarks) ?? 100;
    }

    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return ExamScheduleItem(
      id: (map['id'] ?? docId ?? '').toString().trim(),
      subject: (map['subject'] ?? '').toString().trim(),
      paperTitle: (map['paper_title'] ?? map['paperTitle'] ?? map['title'] ?? '').toString().trim(),
      examDateTime: parseDate(
        map['exam_date_time'] ?? map['examDateTime'] ?? map['dateTime'] ?? map['date'],
        DateTime.now().add(const Duration(days: 7)),
      ),
      durationMinutes: duration,
      examHall: (map['exam_hall'] ?? map['examHall'] ?? map['hall'] ?? 'Main Examination Hall').toString().trim(),
      seatRow: (map['seat_row'] ?? map['seatRow'] ?? map['seat'] ?? 'General Seating').toString().trim(),
      syllabusTopics: parseList(map['syllabus_topics'] ?? map['syllabusTopics'] ?? map['topics']),
      readingMaterials: parseList(map['reading_materials'] ?? map['readingMaterials'] ?? map['readings']),
      maxMarks: marks,
      classLevel: (map['class_level'] ?? map['classLevel'] ?? map['class'] ?? '').toString().trim(),
      imageUrl: (map['image_url'] ?? map['imageUrl'] ?? map['image'])?.toString().trim(),
    );
  }

  factory ExamScheduleItem.fromJson(Map<String, dynamic> json) => ExamScheduleItem.fromMap(json);

  factory ExamScheduleItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ExamScheduleItem.fromMap(data, doc.id);
  }

  ExamScheduleItem copyWith({
    String? id,
    String? subject,
    String? paperTitle,
    DateTime? examDateTime,
    int? durationMinutes,
    String? examHall,
    String? seatRow,
    List<String>? syllabusTopics,
    List<String>? readingMaterials,
    int? maxMarks,
    String? classLevel,
    String? imageUrl,
  }) {
    return ExamScheduleItem(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      paperTitle: paperTitle ?? this.paperTitle,
      examDateTime: examDateTime ?? this.examDateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      examHall: examHall ?? this.examHall,
      seatRow: seatRow ?? this.seatRow,
      syllabusTopics: syllabusTopics ?? this.syllabusTopics,
      readingMaterials: readingMaterials ?? this.readingMaterials,
      maxMarks: maxMarks ?? this.maxMarks,
      classLevel: classLevel ?? this.classLevel,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  int compareTo(ExamScheduleItem other) => examDateTime.compareTo(other.examDateTime);
}
