import 'package:cloud_firestore/cloud_firestore.dart';

import 'academic_class.dart';
import '../services/hierarchy_service.dart';

/// Message categories supported by class groups.
const List<String> kClassGroupCategories = [
  'general',
  'announcement',
  'event',
  'sports',
];

const Map<String, String> kClassGroupCategoryLabels = {
  'general': 'General',
  'announcement': 'Announcements',
  'event': 'Events',
  'sports': 'Sports',
};

String normalizeClassGroupCategory(String value) {
  final clean = value.trim().toLowerCase();
  return kClassGroupCategories.contains(clean) ? clean : 'general';
}

String classGroupCategoryLabel(String value) =>
    kClassGroupCategoryLabels[normalizeClassGroupCategory(value)] ?? 'General';

/// Human-friendly group title, e.g. `11D Class Group`.
String classGroupDisplayTitle(String classId) {
  final id = classId.trim().toUpperCase();
  return id.isEmpty ? 'Class Group' : '$id Class Group';
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}

/// Read-only descriptor for a class group.
///
/// Membership is intentionally **not** stored here. It is derived from the
/// verified `class_id` on the user profile, so a class transfer revokes the old
/// group and grants the new one automatically. Staff access is derived from
/// the `academic_classes` registry.
class ClassGroup {
  final String classId;
  final String name;
  final String description;
  final String lastMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClassGroup({
    required this.classId,
    required this.name,
    required this.description,
    this.lastMessage = '',
    this.createdAt,
    this.updatedAt,
  });

  static ClassGroup defaultsFor(String classId) {
    final id = classId.trim().toUpperCase();
    final parsed = AcademicStructure.parseClassId(id);
    final label = parsed == null
        ? id
        : AcademicStructure.displayClass(parsed.$1, parsed.$2);
    return ClassGroup(
      classId: id,
      name: classGroupDisplayTitle(id),
      description:
          'Official class channel for $label announcements, homework, and events.',
    );
  }

  String get displayName =>
      name.trim().isNotEmpty ? name.trim() : defaultsFor(classId).name;

  Map<String, dynamic> toMap() {
    return {
      'class_id': classId,
      'name': name,
      'description': description,
      'last_message': lastMessage,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  factory ClassGroup.fromMap(String classId, Map<String, dynamic> data) {
    final fallback = defaultsFor(classId);
    return ClassGroup(
      classId: (data['class_id'] ?? classId).toString().toUpperCase(),
      name: (data['name'] ?? fallback.name).toString(),
      description: (data['description'] ?? fallback.description).toString(),
      lastMessage: (data['last_message'] ?? '').toString(),
      createdAt: _parseDateTime(data['created_at']),
      updatedAt: _parseDateTime(data['updated_at']),
    );
  }

  ClassGroup copyWith({
    String? name,
    String? description,
    String? lastMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassGroup(
      classId: classId,
      name: name ?? this.name,
      description: description ?? this.description,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A message posted in a class group.
class ClassGroupMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String senderClass;
  final String text;
  final String category;
  final String attachmentUrl;
  final bool isPinned;
  final bool isHidden;
  final String moderatedBy;
  final DateTime? timestamp;

  ClassGroupMessage({
    this.id = '',
    required this.senderId,
    required this.senderName,
    this.senderRole = 'Student Member',
    required this.senderClass,
    this.text = '',
    String category = 'general',
    this.attachmentUrl = '',
    this.isPinned = false,
    this.isHidden = false,
    this.moderatedBy = '',
    this.timestamp,
  }) : category = normalizeClassGroupCategory(category);

  bool get hasAttachment => attachmentUrl.trim().isNotEmpty;
  bool get hasText => text.trim().isNotEmpty;
  bool get isAnnouncement =>
      normalizeClassGroupCategory(category) == 'announcement';
  String get categoryLabel => classGroupCategoryLabel(category);
  String get previewText {
    if (hasText) return text.trim();
    return hasAttachment ? 'Photo attachment' : '';
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'sender_class': senderClass.toUpperCase().trim(),
      'text': text.trim(),
      'category': normalizeClassGroupCategory(category),
      'attachment_url': attachmentUrl.trim(),
      'is_pinned': isPinned,
      'is_hidden': isHidden,
      'moderated_by': moderatedBy,
      if (timestamp != null) 'timestamp': Timestamp.fromDate(timestamp!),
    };
  }

  factory ClassGroupMessage.fromMap(String id, Map<String, dynamic> data) {
    return ClassGroupMessage(
      id: id,
      senderId: (data['sender_id'] ?? '').toString(),
      senderName: (data['sender_name'] ?? 'Class Member').toString(),
      senderRole: (data['sender_role'] ?? 'Student Member').toString(),
      senderClass: (data['sender_class'] ?? '').toString().toUpperCase(),
      text: (data['text'] ?? '').toString(),
      category:
          normalizeClassGroupCategory((data['category'] ?? 'general').toString()),
      attachmentUrl: (data['attachment_url'] ?? '').toString(),
      isPinned: data['is_pinned'] == true,
      isHidden: data['is_hidden'] == true,
      moderatedBy: (data['moderated_by'] ?? '').toString(),
      timestamp: _parseDateTime(data['timestamp']),
    );
  }

  ClassGroupMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? senderClass,
    String? text,
    String? category,
    String? attachmentUrl,
    bool? isPinned,
    bool? isHidden,
    String? moderatedBy,
    DateTime? timestamp,
  }) {
    return ClassGroupMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      senderClass: senderClass ?? this.senderClass,
      text: text ?? this.text,
      category: category ?? this.category,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
      moderatedBy: moderatedBy ?? this.moderatedBy,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Client-side mirror of the class-group rules. Kept pure so tests can verify
/// every authorised role without a Firebase emulator.
///
/// Authorised senders:
/// - senior school leadership (admins, head of school / principal, and management) across any class
/// - the class teacher assigned in `academic_classes/{classId}`
/// - a subject teacher whose UID is listed in `subject_teacher_uids`
/// - the class representative / vice representative of the verified class
/// - students/prefects only when the school sets `student_posting_enabled`
class ClassGroupAccess {
  static String resolveClassId(Map<String, dynamic>? profile) {
    if (profile == null) return '';
    final raw = profile['class_id'] ?? profile['classId'];
    final direct = (raw ?? '').toString().trim().toUpperCase();
    return AcademicStructure.parseClassId(direct) != null ? direct : '';
  }

  static String uidOf(Map<String, dynamic>? profile) =>
      (profile?['uid'] ?? profile?['id'] ?? '').toString().trim();

  static String roleOf(Map<String, dynamic>? profile) =>
      (profile?['role'] ?? '').toString().trim();

  static String scholarOf(Map<String, dynamic>? profile) =>
      (profile?['scholar_no'] ?? profile?['scholarNo'] ?? '').toString().trim();

  static String nameOf(Map<String, dynamic>? profile) =>
      (profile?['full_name'] ?? profile?['name'] ?? 'Class Member')
          .toString()
          .trim();

  static bool isSeniorAdmin(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    return HierarchyService.isSeniorAdmin(
      scholarNo: scholarOf(profile),
      role: roleOf(profile),
      fullName: nameOf(profile),
    );
  }

  static bool isVerifiedMember(
    Map<String, dynamic>? profile,
    String classId,
  ) {
    if (profile == null) return false;
    final target = classId.trim().toUpperCase();
    if (target.isEmpty) return false;
    if (HierarchyService.isTeacherOrFaculty(role: roleOf(profile))) return false;
    return resolveClassId(profile) == target &&
        profile['class_verified'] == true;
  }

  static bool isClassTeacher(
    Map<String, dynamic>? profile,
    String classId,
    AcademicClass? academicClass,
  ) {
    if (profile == null || academicClass == null) return false;
    if (!HierarchyService.isTeacherOrFaculty(
      scholarNo: scholarOf(profile),
      role: roleOf(profile),
      fullName: nameOf(profile),
    )) {
      return false;
    }
    final uid = uidOf(profile);
    return uid.isNotEmpty &&
        academicClass.classId.trim().toUpperCase() ==
            classId.trim().toUpperCase() &&
        (academicClass.classTeacherUid ?? '').trim() == uid;
  }

  static bool isSubjectTeacher(
    Map<String, dynamic>? profile,
    String classId,
    AcademicClass? academicClass,
  ) {
    if (profile == null || academicClass == null) return false;
    if (!HierarchyService.isTeacherOrFaculty(
      scholarNo: scholarOf(profile),
      role: roleOf(profile),
      fullName: nameOf(profile),
    )) {
      return false;
    }
    final uid = uidOf(profile);
    return uid.isNotEmpty &&
        academicClass.classId.trim().toUpperCase() ==
            classId.trim().toUpperCase() &&
        academicClass.subjectTeacherUids.contains(uid);
  }

  static bool isClassRepresentative(
    Map<String, dynamic>? profile,
    String classId,
  ) {
    if (!isVerifiedMember(profile, classId)) return false;
    return HierarchyService.isClassRepresentative(
      scholarNo: scholarOf(profile),
      role: roleOf(profile),
      fullName: nameOf(profile),
    );
  }

  static bool studentPostingEnabled(AcademicClass? academicClass) =>
      academicClass?.studentPostingEnabled == true;

  static bool _isStudentRole(String role) {
    final r = role.trim().toLowerCase();
    return r == 'student' || r == 'prefect';
  }

  static bool canView(
    Map<String, dynamic>? profile,
    String classId, [
    AcademicClass? academicClass,
  ]) {
    if (profile == null) return false;
    return isVerifiedMember(profile, classId) ||
        isClassTeacher(profile, classId, academicClass) ||
        isSubjectTeacher(profile, classId, academicClass) ||
        isSeniorAdmin(profile);
  }

  static bool canSend(
    Map<String, dynamic>? profile,
    String classId, [
    AcademicClass? academicClass,
  ]) {
    if (profile == null) return false;
    if (isSeniorAdmin(profile) ||
        isClassTeacher(profile, classId, academicClass) ||
        isSubjectTeacher(profile, classId, academicClass) ||
        isClassRepresentative(profile, classId)) {
      return true;
    }
    return isVerifiedMember(profile, classId) &&
        _isStudentRole(roleOf(profile)) &&
        studentPostingEnabled(academicClass);
  }

  static bool canModerate(
    Map<String, dynamic>? profile,
    String classId, [
    AcademicClass? academicClass,
  ]) {
    return isSeniorAdmin(profile) ||
        isClassTeacher(profile, classId, academicClass);
  }

  static bool canAttach(
    Map<String, dynamic>? profile,
    String classId, [
    AcademicClass? academicClass,
  ]) =>
      canSend(profile, classId, academicClass);
}
