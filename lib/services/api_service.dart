import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      default:
        return 'http://localhost:3000';
    }
  }

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  // ===============================
  // REGISTER USER
  // ===============================

  static Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String studentId,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      uri('/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'student_id': studentId,
        'password': password,
        'role': role,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data;
    }

    throw Exception(data['message'] ?? 'Registration failed');
  }

  // ===============================
  // LOGIN USER
  // ===============================

  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      uri('/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['user'];
    }

    throw Exception(data['message'] ?? 'Login failed');
  }

  // ===============================
  // GET ALL EVENTS
  // ===============================

  static Future<List<dynamic>> getEvents() async {
    final response = await http.get(uri('/api/events'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load events');
  }

  // ===============================
  // CREATE EVENT
  // ===============================

  static Future<Map<String, dynamic>> createEvent({
    required String name,
    required String date,
    required String location,
    String description = '',
    int? volunteersNeeded,
  }) async {
    final response = await http.post(
      uri('/api/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'date': date,
        'location': location,
        'description': description,
        'volunteers_needed': volunteersNeeded,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data;
    }

    throw Exception(data['message'] ?? 'Failed to create event');
  }

  // ===============================
  // GET TASKS FOR EVENT
  // ===============================

  static Future<List<dynamic>> getTasks(int eventId) async {
    final response = await http.get(uri('/api/events/$eventId/tasks'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load tasks');
  }

  // ===============================
  // CREATE TASK
  // ===============================

  static Future<Map<String, dynamic>> createTask({
    required int eventId,
    required String taskName,
    required String date,
    required String startTime,
    required String endTime,
    required String location,
    String instructions = '',
    int? volunteersRequired,
  }) async {
    final response = await http.post(
      uri('/api/tasks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'event_id': eventId,
        'task_name': taskName,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'location': location,
        'instructions': instructions,
        'volunteers_required': volunteersRequired,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data;
    }

    throw Exception(data['message'] ?? 'Failed to create task');
  }

  // ===============================
  // ENROLL IN A TASK
  // ===============================

  static Future<Map<String, dynamic>> enroll(int userId, int taskId) async {
    final response = await http.post(
      uri('/api/enroll'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'task_id': taskId}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data;
    }

    if (response.statusCode == 409) {
      throw Exception(data['message'] ?? 'Already enrolled in this task');
    }

    throw Exception(data['message'] ?? 'Failed to enroll');
  }

  // ===============================
  // GET ENROLLED TASKS FOR A USER (MY TASKS)
  // ===============================

  static Future<List<dynamic>> getUserTasks(int userId) async {
    final response = await http.get(uri('/api/users/$userId/tasks'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load your tasks');
  }

  // ===============================
  // GET ALL ENROLLMENTS (VOLUNTEER REQUESTS)
  // ===============================

  static Future<List<dynamic>> getEnrollments({String? status}) async {
    final query = status == null ? '' : '?status=$status';
    final response = await http.get(uri('/api/enrollments$query'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load volunteer requests');
  }

  // ===============================
  // GET VOLUNTEERS FOR A TASK
  // ===============================

  static Future<List<dynamic>> getTaskVolunteers(int taskId) async {
    final response = await http.get(uri('/api/tasks/$taskId/volunteers'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load volunteers');
  }

  // ===============================
  // UPDATE ENROLLMENT STATUS (APPROVE / REJECT)
  // ===============================

  static Future<Map<String, dynamic>> updateEnrollmentStatus(
    int enrollmentId,
    String status,
  ) async {
    final response = await http.put(
      uri('/api/enrollments/$enrollmentId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(data['message'] ?? 'Failed to update enrollment');
  }

  // ===============================
  // GET ALL ANNOUNCEMENTS
  // ===============================

  static Future<List<dynamic>> getAnnouncements() async {
    final response = await http.get(uri('/api/announcements'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load announcements');
  }

  // ===============================
  // GET ANNOUNCEMENTS FOR AN EVENT
  // ===============================

  static Future<List<dynamic>> getEventAnnouncements(int eventId) async {
    final response = await http.get(uri('/api/events/$eventId/announcements'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load announcements');
  }

  // ===============================
  // CREATE ANNOUNCEMENT
  // ===============================

  static Future<Map<String, dynamic>> createAnnouncement({
    required int eventId,
    required String title,
    required String message,
  }) async {
    final response = await http.post(
      uri('/api/announcements'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'event_id': eventId,
        'title': title,
        'message': message,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data;
    }

    throw Exception(data['message'] ?? 'Failed to create announcement');
  }

  // ===============================
  // SUBMIT HELP REQUEST
  // ===============================

  static Future<Map<String, dynamic>> submitHelpRequest({
    required int userId,
    required int eventId,
    required String message,
  }) async {
    final response = await http.post(
      uri('/api/help-requests'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'event_id': eventId,
        'message': message,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data;
    }

    throw Exception(data['message'] ?? 'Failed to send help request');
  }

  // ===============================
  // GET ALL HELP REQUESTS
  // ===============================

  static Future<List<dynamic>> getHelpRequests({String? status}) async {
    final query = status == null ? '' : '?status=$status';
    final response = await http.get(uri('/api/help-requests$query'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load help requests');
  }

  // ===============================
  // UPDATE HELP REQUEST STATUS
  // ===============================

  static Future<Map<String, dynamic>> updateHelpRequestStatus(
    int requestId,
    String status,
  ) async {
    final response = await http.put(
      uri('/api/help-requests/$requestId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(data['message'] ?? 'Failed to update help request');
  }
}
