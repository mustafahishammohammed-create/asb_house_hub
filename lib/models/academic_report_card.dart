import 'package:cloud_firestore/cloud_firestore.dart';

/// Individual subject grade and performance metrics.
class SubjectGrade {
  final String subject;
  final double score;
  final double maxScore;
  final String gradeLetter;
  final String teacherComment;
  final int credits;

  const SubjectGrade({
    required this.subject,
    required this.score,
    this.maxScore = 100.0,
    required this.gradeLetter,
    this.teacherComment = '',
    this.credits = 4,
  });

  double get percentage => maxScore > 0 ? (score / maxScore) * 100.0 : 0.0;
  double get marksObtained => score;
  double get maxMarks => maxScore;
  String get remarks => teacherComment;
  String get letterGrade => gradeLetter;
  String get code => subject.length >= 3 ? subject.substring(0, 3).toUpperCase() : subject.toUpperCase();
  double get gradePoints => maxScore > 0 ? (score / maxScore) * 10.0 : 0.0;

  SubjectGrade copyWith({
    String? subject,
    double? score,
    double? maxScore,
    String? gradeLetter,
    String? teacherComment,
    int? credits,
  }) {
    return SubjectGrade(
      subject: subject ?? this.subject,
      score: score ?? this.score,
      maxScore: maxScore ?? this.maxScore,
      gradeLetter: gradeLetter ?? this.gradeLetter,
      teacherComment: teacherComment ?? this.teacherComment,
      credits: credits ?? this.credits,
    );
  }

  Map<String, dynamic> toMap() => {
    'subject': subject,
    'score': score,
    'max_score': maxScore,
    'grade_letter': gradeLetter,
    'teacher_comment': teacherComment,
    'credits': credits,
  };

  factory SubjectGrade.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic val, double fallback) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? fallback;
      return fallback;
    }

    final rawScore = parseDouble(map['score'], 0.0);
    final rawMax = parseDouble(map['max_score'] ?? map['maxScore'], 100.0);
    final letter = (map['grade_letter'] ?? map['gradeLetter'] ?? map['grade'] ?? '').toString().trim();

    return SubjectGrade(
      subject: (map['subject'] ?? '').toString().trim(),
      score: rawScore,
      maxScore: rawMax > 0 ? rawMax : 100.0,
      gradeLetter: letter.isNotEmpty ? letter : _computeGradeLetter(rawScore, rawMax),
      teacherComment: (map['teacher_comment'] ?? map['teacherComment'] ?? map['comment'] ?? '').toString().trim(),
      credits: (map['credits'] as num?)?.toInt() ?? 4,
    );
  }

  static String computeGradeLetter(double score, double max) {
    final pct = max > 0 ? (score / max) * 100.0 : 0.0;
    if (pct >= 95.0) return 'A+';
    if (pct >= 90.0) return 'A';
    if (pct >= 85.0) return 'B+';
    if (pct >= 80.0) return 'B';
    if (pct >= 75.0) return 'C+';
    if (pct >= 70.0) return 'C';
    if (pct >= 60.0) return 'D';
    return 'F';
  }

  static String _computeGradeLetter(double score, double max) => computeGradeLetter(score, max);
}

/// Official academic term report card entity with GPA,
/// subject breakdown, attendance, and teacher remarks.
class AcademicReportCard implements Comparable<AcademicReportCard> {
  final String id;
  final String scholarNo;
  final String studentName;
  final String termName; // e.g. "Term 1 Mid-Term", "Term 2 Final"
  final String academicYear; // e.g. "2026-2027"
  final String classLevel; // e.g. "Grade 10"
  final double overallGpa; // e.g. 3.85 (out of 4.0)
  final double overallPercentage; // e.g. 92.4%
  final double attendanceRate; // e.g. 98.5%
  final String teacherRemarks; // e.g. "Exemplary analytical aptitude..."
  final List<SubjectGrade> subjectGrades;
  final DateTime publishedAt;
  final bool isMeritClaimed;
  final String? imageUrl;
  final String status;
  final String? section;
  final String? principalRemarks;

  const AcademicReportCard({
    required this.id,
    required this.scholarNo,
    required this.studentName,
    required this.termName,
    this.academicYear = '2026-2027',
    this.classLevel = 'Grade 10',
    required this.overallGpa,
    required this.overallPercentage,
    this.attendanceRate = 100.0,
    this.teacherRemarks = '',
    this.subjectGrades = const [],
    required this.publishedAt,
    this.isMeritClaimed = false,
    this.imageUrl,
    this.status = 'Published',
    this.section,
    this.principalRemarks,
  });

  /// Evaluates whether student achieved academic distinction (GPA >= 3.8).
  bool get hasDistinction => overallGpa >= 3.80;

  /// Overall letter grade representation.
  String get letterGrade {
    if (overallGpa >= 3.90 || overallPercentage >= 95.0) return 'A+';
    if (overallGpa >= 3.70 || overallPercentage >= 90.0) return 'A';
    if (overallGpa >= 3.30 || overallPercentage >= 85.0) return 'B+';
    if (overallGpa >= 3.00 || overallPercentage >= 80.0) return 'B';
    if (overallGpa >= 2.70 || overallPercentage >= 75.0) return 'C+';
    if (overallGpa >= 2.00 || overallPercentage >= 70.0) return 'C';
    if (overallGpa >= 1.00 || overallPercentage >= 60.0) return 'D';
    return 'F';
  }

  String get formattedGpa => overallGpa.toStringAsFixed(2);
  String get formattedPercentage => '${overallPercentage.toStringAsFixed(1)}%';
  String get formattedAttendance => '${attendanceRate.toStringAsFixed(1)}%';

  String get term => termName;
  bool get pointsClaimed => isMeritClaimed;
  double get attendancePercentage => attendanceRate;
  String get formattedIssueDate =>
      '${publishedAt.day.toString().padLeft(2, '0')}/${publishedAt.month.toString().padLeft(2, '0')}/${publishedAt.year}';
  List<SubjectGrade> get subjects => subjectGrades;

  Map<String, dynamic> toMap() => {
    'id': id,
    'scholar_no': scholarNo,
    'student_name': studentName,
    'term_name': termName,
    'academic_year': academicYear,
    'class_level': classLevel,
    'overall_gpa': overallGpa,
    'overall_percentage': overallPercentage,
    'attendance_rate': attendanceRate,
    'teacher_remarks': teacherRemarks,
    'subject_grades': subjectGrades.map((g) => g.toMap()).toList(),
    'published_at': publishedAt.toIso8601String(),
    'is_merit_claimed': isMeritClaimed,
    'status': status,
    if (section != null && section!.isNotEmpty) 'section': section,
    if (principalRemarks != null && principalRemarks!.isNotEmpty) 'principal_remarks': principalRemarks,
    if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
  };

  Map<String, dynamic> toJson() => toMap();

  factory AcademicReportCard.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? fallback;
      }
      return fallback;
    }

    double parseDouble(dynamic val, double fallback) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? fallback;
      return fallback;
    }

    final gradesList = (map['subject_grades'] ?? map['subjectGrades'] ?? map['grades']);
    final parsedGrades = <SubjectGrade>[];
    if (gradesList is List) {
      for (final item in gradesList) {
        if (item is Map) {
          parsedGrades.add(SubjectGrade.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Auto-compute GPA and percentage if not explicitly provided
    double gpa = parseDouble(map['overall_gpa'] ?? map['overallGpa'] ?? map['gpa'], -1.0);
    double percentage = parseDouble(map['overall_percentage'] ?? map['overallPercentage'] ?? map['percentage'], -1.0);

    if (parsedGrades.isNotEmpty) {
      if (percentage < 0) {
        double totalScore = 0;
        double totalMax = 0;
        for (final g in parsedGrades) {
          totalScore += g.score;
          totalMax += g.maxScore;
        }
        percentage = totalMax > 0 ? (totalScore / totalMax) * 100.0 : 0.0;
      }
      if (gpa < 0) {
        double weightedScore = 0.0;
        int totalCredits = 0;
        for (final g in parsedGrades) {
          final maxScore = g.maxScore > 0 ? g.maxScore : 100.0;
          final pct = (g.score / maxScore).clamp(0.0, 1.0);
          final subjectGpa = pct * 4.0;
          weightedScore += subjectGpa * g.credits;
          totalCredits += g.credits;
        }
        gpa = totalCredits > 0
            ? (weightedScore / totalCredits)
            : (percentage > 0 ? (percentage / 100.0) * 4.0 : 0.0);
        if (gpa.isNaN || gpa.isInfinite) gpa = 0.0;
      }
    } else {
      if (gpa < 0 || gpa.isNaN || gpa.isInfinite) gpa = 0.0;
      if (percentage < 0 || percentage.isNaN || percentage.isInfinite) percentage = 0.0;
    }

    return AcademicReportCard(
      id: (map['id'] ?? docId ?? '').toString().trim(),
      scholarNo: (map['scholar_no'] ?? map['scholarNo'] ?? '').toString().trim(),
      studentName: (map['student_name'] ?? map['studentName'] ?? '').toString().trim(),
      termName: (map['term_name'] ?? map['termName'] ?? map['term'] ?? 'Term 1 Mid-Term').toString().trim(),
      academicYear: (map['academic_year'] ?? map['academicYear'] ?? '2026-2027').toString().trim(),
      classLevel: (map['class_level'] ?? map['classLevel'] ?? 'Grade 10').toString().trim(),
      overallGpa: gpa,
      overallPercentage: percentage,
      attendanceRate: parseDouble(map['attendance_rate'] ?? map['attendanceRate'] ?? map['attendance'], 100.0),
      teacherRemarks: (map['teacher_remarks'] ?? map['teacherRemarks'] ?? map['remarks'] ?? '').toString().trim(),
      subjectGrades: parsedGrades,
      publishedAt: parseDate(map['published_at'] ?? map['publishedAt'] ?? map['date'], DateTime.now()),
      isMeritClaimed: (map['is_merit_claimed'] ?? map['isMeritClaimed'] ?? false) == true,
      imageUrl: (map['image_url'] ?? map['imageUrl'])?.toString().trim(),
      status: (map['status'] ?? 'Published').toString().trim(),
      section: (map['section'] ?? map['class_section'])?.toString().trim(),
      principalRemarks: (map['principal_remarks'] ?? map['principalRemarks'])?.toString().trim(),
    );
  }

  factory AcademicReportCard.fromJson(Map<String, dynamic> json) => AcademicReportCard.fromMap(json);

  factory AcademicReportCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AcademicReportCard.fromMap(data, doc.id);
  }

  AcademicReportCard copyWith({
    String? id,
    String? scholarNo,
    String? studentName,
    String? termName,
    String? term,
    String? academicYear,
    String? classLevel,
    double? overallGpa,
    double? overallPercentage,
    double? attendanceRate,
    double? attendancePercentage,
    String? teacherRemarks,
    List<SubjectGrade>? subjectGrades,
    List<SubjectGrade>? subjects,
    DateTime? publishedAt,
    bool? isMeritClaimed,
    bool? pointsClaimed,
    String? imageUrl,
    String? status,
    String? section,
    String? principalRemarks,
  }) {
    return AcademicReportCard(
      id: id ?? this.id,
      scholarNo: scholarNo ?? this.scholarNo,
      studentName: studentName ?? this.studentName,
      termName: term ?? termName ?? this.termName,
      academicYear: academicYear ?? this.academicYear,
      classLevel: classLevel ?? this.classLevel,
      overallGpa: overallGpa ?? this.overallGpa,
      overallPercentage: overallPercentage ?? this.overallPercentage,
      attendanceRate: attendancePercentage ?? attendanceRate ?? this.attendanceRate,
      teacherRemarks: teacherRemarks ?? this.teacherRemarks,
      subjectGrades: subjects ?? subjectGrades ?? this.subjectGrades,
      publishedAt: publishedAt ?? this.publishedAt,
      isMeritClaimed: pointsClaimed ?? isMeritClaimed ?? this.isMeritClaimed,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      section: section ?? this.section,
      principalRemarks: principalRemarks ?? this.principalRemarks,
    );
  }

  @override
  int compareTo(AcademicReportCard other) => other.publishedAt.compareTo(publishedAt);
}
