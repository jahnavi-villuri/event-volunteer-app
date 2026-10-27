// ============================================================
// SESSION
// Application-level logged-in user state.
// The user map comes from POST /api/login (id, name, email,
// student_id, role). No extra packages required.
// ============================================================

class Session {
  static Map<String, dynamic>? currentUser;

  static void setUser(Map<String, dynamic>? user) {
    currentUser = user;
  }

  static void updateUser(Map<String, dynamic> fields) {
    currentUser?.addAll(fields);
  }

  static void clear() {
    currentUser = null;
  }

  static int get userId {
    final id = currentUser?['id'];
    if (id is num) return id.toInt();
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  static String get name => (currentUser?['name'] ?? '') as String;

  static String get email => (currentUser?['email'] ?? '') as String;

  static String get studentId => (currentUser?['student_id'] ?? '') as String;

  static String get role => (currentUser?['role'] ?? '') as String;

  static String get roleRequested =>
      (currentUser?['role_requested'] ?? role) as String;

  static String get roleStatus =>
      (currentUser?['role_status'] ?? 'approved') as String;

  static bool get isHeadVolunteerPending =>
      roleRequested == 'Head Volunteer' && roleStatus == 'pending';

  static String get phone => (currentUser?['phone'] ?? '') as String;

  static String get area => (currentUser?['area'] ?? '') as String;

  static String? get accessToken {
    final token = currentUser?['access_token'];
    return token is String && token.isNotEmpty ? token : null;
  }

  static bool get isLoggedIn => currentUser != null && accessToken != null;

  static bool get isHeadVolunteer => role == 'Head Volunteer';

  static bool get canApproveRoleRequests => role == 'Administrator';

  static bool get canPostTasks => isHeadVolunteer;

  static bool get canManageVolunteers => isHeadVolunteer;
}
