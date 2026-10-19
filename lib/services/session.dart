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

  static bool get isLoggedIn => currentUser != null;

  static bool get isHeadVolunteer => role == 'Head Volunteer';
}