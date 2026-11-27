import '../models/academic_class.dart';

/// Centralized Hierarchy and Role Verification Engine for ASB House Hub.
/// Enforces strict role isolation, prevents privilege escalation vulnerabilities,
/// and securely validates officers, faculty, council, and students.
class HierarchyService {
  /// Check if the user qualifies as Super Admin.
  static bool isSuperAdmin({
    String? scholarNo,
    String? role,
    String? fullName, // retained for API compatibility
  }) {
    final sNo = (scholarNo ?? '').trim().toLowerCase();
    final rStr = (role ?? '').trim().toLowerCase();

    if (sNo == 'admin' || sNo == '11209') return true;
    if (rStr == 'super_admin' || rStr == 'admin' || rStr == 'administrator') return true;

    return false;
  }

  /// Check if user is Faculty, Teacher, or Principal.
  static bool isTeacherOrFaculty({
    String? scholarNo,
    String? role,
    String? fullName, // retained for API compatibility — NOT used for authorization
  }) {
    final rStr = (role ?? '').trim().toLowerCase();

    if (rStr == 'teacher' ||
        rStr == 'faculty' ||
        rStr == 'principal' ||
        rStr == 'staff' ||
        rStr == 'faculty_advisor' ||
        rStr == 'teacher_lead' ||
        rStr == 'class_teacher' ||
        rStr == 'subject_teacher') {
      return true;
    }

    return false;
  }

  /// Check if user is a House Captain or Vice Captain.
  static bool isCaptain({
    String? scholarNo,
    String? role,
    String? fullName, // retained for API compatibility — NOT used for authorization
  }) {
    final rStr = (role ?? '').trim().toLowerCase();

    if (rStr == 'captain' ||
        rStr == 'vice_captain' ||
        rStr == 'house_captain' ||
        rStr == 'house_vice_captain') {
      return true;
    }

    return false;
  }

  /// Check if user is an Executive Council Member.
  static bool isCouncil({
    String? scholarNo,
    String? role,
    String? fullName, // retained for API compatibility — NOT used for authorization
  }) {
    final rStr = (role ?? '').trim().toLowerCase();

    if (rStr == 'council' ||
        rStr == 'head_boy' ||
        rStr == 'head_girl' ||
        rStr == 'deputy_head_boy' ||
        rStr == 'deputy_head_girl' ||
        rStr == 'head_of_activities' ||
        rStr == 'cultural_secretary' ||
        rStr == 'sports_captain' ||
        rStr == 'sports_vice_captain' ||
        rStr == 'executive_council') {
      return true;
    }

    return false;
  }

  /// Check if user is an appointed Grade Prefect or Student Representative.
  static bool isPrefect({
    String? scholarNo,
    String? role,
    String? fullName, // retained for API compatibility — NOT used for authorization
  }) {
    final rStr = (role ?? '').trim().toLowerCase();

    if (rStr == 'prefect' ||
        rStr == 'student_rep' ||
        rStr == 'grade_prefect') {
      return true;
    }

    return false;
  }

  /// Check if user is a class teacher (ownership is verified against the
  /// `academic_classes` registry by the class-group rules, not by this role
  /// alone).
  static bool isClassTeacher({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    return (role ?? '').trim().toLowerCase() == 'class_teacher';
  }

  /// Check if user is a subject teacher (assigned classes are verified against
  /// `academic_classes/{classId}.subject_teacher_uids` by the rules).
  static bool isSubjectTeacher({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    return (role ?? '').trim().toLowerCase() == 'subject_teacher';
  }

  /// Check if user is a class representative or vice representative. The
  /// class scope still comes from the verified `class_id` on the profile.
  static bool isClassRepresentative({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    final rStr = (role ?? '').trim().toLowerCase();
    return rStr == 'class_representative' ||
        rStr == 'vice_class_representative';
  }

  /// Check if user is a parent account.
  static bool isParent({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    return (role ?? '').trim().toLowerCase() == 'parent';
  }

  /// General check if user holds administrative or executive review privileges.
  static bool isAdmin({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    return isSeniorAdmin(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isSuperAdmin(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isTeacherOrFaculty(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isCaptain(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isCouncil(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isPrefect(scholarNo: scholarNo, role: role, fullName: fullName);
  }

  /// Canonical check whether an account is authorized to grade assignments and award academic merit points.
  /// Requirement R1 & Audit G4: Staff, Teachers, Principal, Head, Management, and Council officers have grading authority.
  /// Strictly Prohibited: Regular Students and non-council student accounts.
  static bool canGradeAcademics({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    return isSeniorAdmin(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isSuperAdmin(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isTeacherOrFaculty(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isCouncil(scholarNo: scholarNo, role: role, fullName: fullName);
  }

  /// Canonical check whether an account is authorized to manage elections
  /// (create drafts, configure candidate slates, publish ballots, certify outcomes).
  /// Authorized: Super Admin, Administrators, Principal, Head, Management, Faculty/Teachers, Staff, Council, House Captains.
  /// Strictly Prohibited: Regular Students.
  static bool canManageElections({
    String? scholarNo,
    String? role,
    Map<String, dynamic>? capabilities,
    String? email,
  }) {
    final sNo = (scholarNo ?? '').trim().toLowerCase();
    final rStr = (role ?? '').trim().toLowerCase();
    final em = (email ?? '').trim().toLowerCase();

    if (sNo == 'admin' || sNo == '11209') return true;
    if (isSeniorAdmin(scholarNo: sNo, role: rStr)) return true;
    if (em.contains('admin@asianschool.bh') ||
        em.contains('superadmin@asianschool.bh') ||
        em.contains('principal@asianschool.bh')) {
      return true;
    }
    if (isSuperAdmin(scholarNo: sNo, role: rStr)) return true;
    if (isTeacherOrFaculty(scholarNo: sNo, role: rStr)) return true;
    if (isCouncil(scholarNo: sNo, role: rStr)) return true;
    if (isCaptain(scholarNo: sNo, role: rStr)) return true;
    if (capabilities != null &&
        (capabilities['manage_elections'] == true || capabilities['is_admin'] == true)) {
      return true;
    }

    return false;
  }

  /// Check if user is a Senior Admin (Super Admin, Administrator, School Head, or Management).
  static bool isSeniorAdmin({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    final sNo = (scholarNo ?? '').trim().toLowerCase();
    final rStr = (role ?? '').trim().toLowerCase();
    if (sNo == 'admin' || sNo == '11209') return true;
    if (rStr == 'super_admin' ||
        rStr == 'admin' ||
        rStr == 'administrator' ||
        rStr == 'principal' ||
        rStr == 'vice_principal' ||
        rStr == 'head' ||
        rStr == 'school_head' ||
        rStr == 'head_of_school' ||
        rStr == 'management' ||
        rStr == 'school_management' ||
        rStr == 'director') {
      return true;
    }
    return false;
  }

  /// Canonical check whether an account is authorized to edit a class timetable (M2b).
  ///
  /// Authorized:
  /// - Super Admin is always authorized.
  /// - A teacher/faculty member who is assigned as [academicClass.classTeacherUid] or
  ///   listed in [academicClass.timetableEditorUids], provided [academicClass.timetableEditingEnabled] is true.
  ///
  /// Prohibited (Spec §9.2, Acceptance Test 35):
  /// - Regular students, council officers, house captains (timetables are teacher-managed).
  /// - Teachers not assigned to this class section (no global teacher access).
  /// - Any teacher when timetable editing is explicitly disabled for the class by administration.
  static bool canEditTimetable({
    required Map<String, dynamic>? profile,
    required String classId,
    AcademicClass? academicClass,
  }) {
    if (profile == null) return false;
    final sNo = (profile['scholar_no'] ?? profile['scholarNo'] ?? '').toString();
    final role = (profile['role'] ?? '').toString();
    final uid = (profile['uid'] ?? profile['id'] ?? '').toString().trim();

    if (isSuperAdmin(scholarNo: sNo, role: role)) return true;

    // Must be verified faculty/teacher
    if (!isTeacherOrFaculty(scholarNo: sNo, role: role)) return false;

    // If no academicClass is passed or classId doesn't match, deny
    if (academicClass == null) return false;
    if (academicClass.classId.toUpperCase() != classId.trim().toUpperCase()) return false;

    // Administration locked editing for this section
    if (!academicClass.timetableEditingEnabled) return false;

    // Check teacher UID authority
    if (uid.isNotEmpty) {
      if (academicClass.classTeacherUid != null && academicClass.classTeacherUid == uid) {
        return true;
      }
      if (academicClass.timetableEditorUids.contains(uid)) {
        return true;
      }
    }

    // Name-based fallback for legacy entries where classTeacherUid is not yet set
    final fullName = (profile['full_name'] ?? profile['name'] ?? profile['displayName'] ?? '').toString().trim();
    if (academicClass.classTeacherUid == null &&
        academicClass.classTeacher.isNotEmpty &&
        fullName.isNotEmpty &&
        academicClass.classTeacher.toLowerCase() == fullName.toLowerCase()) {
      return true;
    }

    return false;
  }

  /// General check if user is Council or Faculty.
  static bool isCouncilOrTeacher({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    return isAdmin(scholarNo: scholarNo, role: role, fullName: fullName);
  }

  /// Get display title for the user based on hierarchy.
  static String getRoleDisplayTitle({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    final sNo = (scholarNo ?? '').trim().toLowerCase();
    final rStr = (role ?? '').trim().toLowerCase();
    if (isSuperAdmin(scholarNo: scholarNo, role: role, fullName: fullName) ||
        sNo == '11209' ||
        sNo == 'admin') {
      return 'Super Admin';
    }
    if (rStr == 'principal' ||
        rStr == 'vice_principal' ||
        rStr == 'head' ||
        rStr == 'school_head' ||
        rStr == 'head_of_school') {
      return 'School Head';
    }
    if (rStr == 'management' ||
        rStr == 'school_management' ||
        rStr == 'director') {
      return 'School Management';
    }
    if (isTeacherOrFaculty(scholarNo: scholarNo, role: role, fullName: fullName)) {
      return 'Faculty Lead';
    }
    if (isCaptain(scholarNo: scholarNo, role: role, fullName: fullName)) {
      return 'House Captain';
    }
    if (isCouncil(scholarNo: scholarNo, role: role, fullName: fullName)) {
      return 'Student Council';
    }
    if (isClassRepresentative(
      scholarNo: scholarNo,
      role: role,
      fullName: fullName,
    )) {
      return 'Class Representative';
    }
    if (isParent(scholarNo: scholarNo, role: role, fullName: fullName)) {
      return 'Parent';
    }
    if (isPrefect(scholarNo: scholarNo, role: role, fullName: fullName)) {
      return 'Grade Prefect';
    }
    return 'Student Member';
  }
}
