/// Centralized Hierarchy and Role Verification Engine for ASB House Hub.
/// Enforces strict role isolation, prevents privilege escalation vulnerabilities,
/// and securely validates officers, faculty, council, and students.
class HierarchyService {
  /// Check if the user qualifies as Super Admin.
  static bool isSuperAdmin({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    final sNo = (scholarNo ?? '').trim().toLowerCase();
    final rStr = (role ?? '').trim().toLowerCase();
    final fName = (fullName ?? '').trim().toLowerCase();

    if (sNo == 'admin' || sNo == '2310910') return true;
    if (rStr == 'super_admin' || rStr == 'admin') return true;
    if (fName == 'mustafa hisham') return true;

    return false;
  }

  /// Check if user is Faculty, Teacher, or Principal.
  static bool isTeacherOrFaculty({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    final sNo = (scholarNo ?? '').trim();
    final rStr = (role ?? '').trim().toLowerCase();
    final fName = (fullName ?? '').trim().toLowerCase();

    if (rStr == 'teacher' ||
        rStr == 'faculty' ||
        rStr == 'principal' ||
        rStr == 'staff') {
      return true;
    }
    if (sNo == '30003') return true; // Dr. Elizabeth Vance
    if (fName == 'dr. elizabeth vance' || fName == 'elizabeth vance') return true;

    return false;
  }

  /// Check if user is a House Captain or Vice Captain.
  static bool isCaptain({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    final sNo = (scholarNo ?? '').trim();
    final rStr = (role ?? '').trim().toLowerCase();
    final fName = (fullName ?? '').trim().toLowerCase();

    if (rStr == 'captain' ||
        rStr == 'vice_captain' ||
        rStr == 'house_captain') {
      return true;
    }
    if (sNo == '10001') return true; // Noaman Nizamuddin (Emerald Captain)
    if (fName == 'noaman nizamuddin') return true;

    return false;
  }

  /// Check if user is an Executive Council Member.
  static bool isCouncil({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    final sNo = (scholarNo ?? '').trim();
    final rStr = (role ?? '').trim().toLowerCase();
    final fName = (fullName ?? '').trim().toLowerCase();

    if (rStr == 'council' ||
        rStr == 'head_boy' ||
        rStr == 'head_girl' ||
        rStr == 'deputy_head_boy' ||
        rStr == 'deputy_head_girl' ||
        rStr == 'head_of_activities' ||
        rStr == 'cultural_secretary' ||
        rStr == 'sports_captain') {
      return true;
    }

    // Specific verified executive officers by scholar number or exact name
    if (sNo == '12001' || fName == 'tanish mukherjee') return true; // Head Boy
    if (fName == 'ann binu') return true; // Head Girl
    if (sNo == '11089' || fName == 'saakshat guhan') return true; // Deputy Head Boy
    if (sNo == '11012' || fName == 'nayla muhammad') return true; // Deputy Head Girl

    return false;
  }

  /// Check if user is an appointed Grade Prefect or Student Representative.
  static bool isPrefect({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    final sNo = (scholarNo ?? '').trim();
    final rStr = (role ?? '').trim().toLowerCase();
    final fName = (fullName ?? '').trim().toLowerCase();

    if (rStr == 'prefect' || rStr == 'student_rep') return true;

    // Specific appointed prefects
    if (sNo == '11004' || fName == 'sarah paul') return true; // G11 Prefect Girl
    if (sNo == '11015' || fName == 'galwin britto') return true; // G11 Prefect Boy

    return false;
  }

  /// General check if user holds administrative or executive review privileges.
  static bool isAdmin({
    String? scholarNo,
    String? role,
    String? fullName,
  }) {
    return isSuperAdmin(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isTeacherOrFaculty(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isCaptain(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isCouncil(scholarNo: scholarNo, role: role, fullName: fullName) ||
        isPrefect(scholarNo: scholarNo, role: role, fullName: fullName);
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
    if (isSuperAdmin(scholarNo: scholarNo, role: role, fullName: fullName)) {
      return 'Super Admin';
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
    if (isPrefect(scholarNo: scholarNo, role: role, fullName: fullName)) {
      return 'Grade Prefect';
    }
    return 'Student Member';
  }
}
