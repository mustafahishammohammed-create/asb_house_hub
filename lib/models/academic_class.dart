import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical academic structure for ASB Digital Campus (LKG through Grade 12).
///
/// A class is identified by grade + section, e.g. Grade 11 Section D -> `11D`,
/// LKG Section A -> `LKG-A`. The canonical [classId] is the key used by
/// section-scoped features (timetables, class groups, announcements). Legacy
/// `class_level` ('Grade 11') and `division` ('D') profile fields are retained
/// for backward compatibility with existing academics paths.
class AcademicStructure {
  AcademicStructure._();

  /// Every supported grade level, kindergarten first.
  static const List<String> gradeLevels = [
    'LKG',
    'UKG',
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  static const List<String> kindergarten = ['LKG', 'UKG'];

  /// Normalizes a raw grade token ('11', 'Grade 11', 'lkg') to a canonical
  /// grade level string. Returns null when unrecognized.
  static String? normalizeGrade(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return null;
    final upper = s.toUpperCase();
    if (upper == 'LKG' || upper == 'UKG') return upper;
    final match = RegExp(r'\d+').firstMatch(s);
    if (match != null) {
      final n = int.tryParse(match.group(0)!);
      if (n != null && n >= 1 && n <= 12) return 'Grade $n';
    }
    return null;
  }

  /// Short grade code used inside a classId: 'LKG', 'UKG', or the grade number.
  static String gradeCode(String grade) {
    final normalized = normalizeGrade(grade) ?? grade;
    if (normalized == 'LKG' || normalized == 'UKG') return normalized;
    final match = RegExp(r'\d+').firstMatch(normalized);
    return match?.group(0) ?? normalized;
  }

  /// Builds the canonical classId from a grade and section.
  /// Grade 11 + D -> '11D'; LKG + A -> 'LKG-A'. Returns '' if grade is invalid.
  static String classIdFrom(String grade, String section) {
    final code = gradeCode(grade);
    final sec = section.trim().toUpperCase();
    if (normalizeGrade(grade) == null || sec.isEmpty) return '';
    if (code == 'LKG' || code == 'UKG') return '$code-$sec';
    return '$code$sec';
  }

  /// Parses a canonical classId back into (grade, section).
  /// '11D' -> ('Grade 11', 'D'); 'LKG-A' -> ('LKG', 'A').
  static (String, String)? parseClassId(String classId) {
    final s = classId.trim().toUpperCase();
    if (s.isEmpty) return null;
    final kg = RegExp(r'^(LKG|UKG)-?([A-Z])$').firstMatch(s);
    if (kg != null) return (kg.group(1)!, kg.group(2)!);
    final grade = RegExp(r'^(\d{1,2})([A-Z])$').firstMatch(s);
    if (grade != null) {
      final n = int.tryParse(grade.group(1)!);
      if (n != null && n >= 1 && n <= 12) return ('Grade $n', grade.group(2)!);
    }
    return null;
  }

  /// Human-friendly label, e.g. 'Grade 11 — Section D'.
  static String displayClass(String grade, String section) {
    final g = normalizeGrade(grade) ?? grade;
    final sec = section.trim().toUpperCase();
    if (sec.isEmpty) return g;
    return '$g — Section $sec';
  }
}

/// A managed class/section entry in the `academic_classes` registry.
/// Administrators create, rename, activate/deactivate, and assign class teachers.
class AcademicClass {
  final String classId;
  final String grade;
  final String section;
  final bool active;
  final String classTeacher;
  final String academicYear;
  final DateTime? createdAt;

  const AcademicClass({
    required this.classId,
    required this.grade,
    required this.section,
    this.active = true,
    this.classTeacher = '',
    this.academicYear = '2026-2027',
    this.createdAt,
  });

  String get displayLabel => AcademicStructure.displayClass(grade, section);

  Map<String, dynamic> toMap() => {
    'class_id': classId,
    'grade': grade,
    'section': section,
    'active': active,
    'class_teacher': classTeacher,
    'academic_year': academicYear,
    if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
  };

  factory AcademicClass.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime? parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    final grade = AcademicStructure.normalizeGrade(map['grade']) ??
        (map['grade'] ?? '').toString().trim();
    final section = (map['section'] ?? '').toString().trim().toUpperCase();
    final id = (map['class_id'] ?? docId ?? '').toString().trim();
    return AcademicClass(
      classId: id.isNotEmpty ? id : AcademicStructure.classIdFrom(grade, section),
      grade: grade,
      section: section,
      active: map['active'] != false,
      classTeacher: (map['class_teacher'] ?? map['classTeacher'] ?? '').toString().trim(),
      academicYear: (map['academic_year'] ?? map['academicYear'] ?? '2026-2027').toString().trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
    );
  }

  factory AcademicClass.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AcademicClass.fromMap(data, doc.id);
  }

  AcademicClass copyWith({
    String? classId,
    String? grade,
    String? section,
    bool? active,
    String? classTeacher,
    String? academicYear,
    DateTime? createdAt,
  }) {
    return AcademicClass(
      classId: classId ?? this.classId,
      grade: grade ?? this.grade,
      section: section ?? this.section,
      active: active ?? this.active,
      classTeacher: classTeacher ?? this.classTeacher,
      academicYear: academicYear ?? this.academicYear,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}