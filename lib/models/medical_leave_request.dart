// lib/models/medical_leave_request.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MedicalLeaveStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case MedicalLeaveStatus.pending:
        return 'Pending Review';
      case MedicalLeaveStatus.approved:
        return 'Approved (Excused)';
      case MedicalLeaveStatus.rejected:
        return 'Declined';
    }
  }

  static MedicalLeaveStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'approved':
        return MedicalLeaveStatus.approved;
      case 'rejected':
      case 'declined':
        return MedicalLeaveStatus.rejected;
      case 'pending':
      default:
        return MedicalLeaveStatus.pending;
    }
  }
}

class MedicalLeaveRequest {
  final String id;
  final String scholarNo;
  final String studentName;
  final String house;
  final String classLevel;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String doctorName;
  final String? certificatePhotoBase64;
  final DateTime submittedAt;
  final MedicalLeaveStatus status;
  final String? adminRemark;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  const MedicalLeaveRequest({
    required this.id,
    required this.scholarNo,
    required this.studentName,
    required this.house,
    required this.classLevel,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.doctorName = '',
    this.certificatePhotoBase64,
    required this.submittedAt,
    this.status = MedicalLeaveStatus.pending,
    this.adminRemark,
    this.reviewedBy,
    this.reviewedAt,
  });

  int get durationDays {
    final diff = endDate.difference(startDate).inDays;
    return diff < 0 ? 1 : diff + 1;
  }

  String get formattedDateRange {
    final s = '${startDate.day}/${startDate.month}/${startDate.year}';
    final e = '${endDate.day}/${endDate.month}/${endDate.year}';
    return s == e ? s : '$s – $e ($durationDays days)';
  }

  String get formattedRange => formattedDateRange;

  bool get hasCertificatePhoto =>
      certificatePhotoBase64 != null && certificatePhotoBase64!.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scholar_no': scholarNo,
      'student_name': studentName,
      'house': house,
      'class_level': classLevel,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'reason': reason,
      'doctor_name': doctorName,
      'certificate_photo': certificatePhotoBase64,
      'submitted_at': submittedAt.toIso8601String(),
      'status': status.name,
      'admin_remark': adminRemark,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  factory MedicalLeaveRequest.fromMap(Map<String, dynamic> map, {String? docId, String? id}) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    final now = DateTime.now();
    return MedicalLeaveRequest(
      id: id ?? docId ?? map['id']?.toString() ?? 'med_${now.millisecondsSinceEpoch}',
      scholarNo: map['scholar_no']?.toString() ?? '2310910',
      studentName: map['student_name']?.toString() ?? 'ASB Student',
      house: map['house']?.toString() ?? 'ruby',
      classLevel: map['class_level']?.toString() ?? 'Grade 10',
      startDate: parseDate(map['start_date'], now),
      endDate: parseDate(map['end_date'], now),
      reason: map['reason']?.toString() ?? 'Medical reason',
      doctorName: map['doctor_name']?.toString() ?? '',
      certificatePhotoBase64: map['certificate_photo']?.toString(),
      submittedAt: parseDate(map['submitted_at'], now),
      status: MedicalLeaveStatus.fromString(map['status']?.toString()),
      adminRemark: map['admin_remark']?.toString(),
      reviewedBy: map['reviewed_by']?.toString(),
      reviewedAt: map['reviewed_at'] != null ? parseDate(map['reviewed_at'], now) : null,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory MedicalLeaveRequest.fromJson(String source) =>
      MedicalLeaveRequest.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
