import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_database_service.dart';
import 'session.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? type;

  const ApiException(this.message, {this.statusCode, this.type});

  @override
  String toString() => message;
}

class ApiService {
  static String? _customBaseUrl;

  static void setBaseUrl(String url) {
    _customBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://192.168.101.8:3000';

      default:
        return 'http://localhost:3000';
    }
  }

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (Session.accessToken != null)
      'Authorization': 'Bearer ${Session.accessToken}',
  };

  static const Duration _timeout = Duration(seconds: 15);

  static Future<http.Response> _send(
    Future<http.Response> Function() requestCall,
  ) async {
    try {
      final response = await requestCall().timeout(_timeout);
      return response;
    } on TimeoutException {
      throw ApiException(
        'Server took too long to respond. Please make sure the backend server is running at $baseUrl.',
        type: 'timeout',
      );
    } catch (e) {
      if (e is ApiException) rethrow;

      final err = e.toString().toLowerCase();

      if (err.contains('clientexception') ||
          err.contains('failed to fetch') ||
          err.contains('socketexception') ||
          err.contains('connection refused') ||
          err.contains('network is unreachable')) {
        throw ApiException(
          'Unable to reach server at $baseUrl. Ensure backend is running and accessible from this device.',
          type: 'network',
        );
      }

      throw ApiException(
        'Network error: ${e.toString().replaceFirst('Exception: ', '')}',
        type: 'network',
      );
    }
  }

  static Map<String, dynamic> _parseJsonResponse(http.Response response) {
    Map<String, dynamic> data = {};

    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Body was not JSON.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message = (data['message'] as String?)?.trim() ?? '';

    if (response.statusCode == 409) {
      throw ApiException(
        message.isNotEmpty ? message : 'Email is already registered.',
        statusCode: 409,
        type: 'duplicate',
      );
    } else if (response.statusCode == 401) {
      throw ApiException(
        message.isNotEmpty ? message : 'Invalid email or password.',
        statusCode: 401,
        type: 'unauthorized',
      );
    } else if (response.statusCode == 403) {
      throw ApiException(
        message.isNotEmpty
            ? message
            : 'Access denied. Head Volunteer privileges require administrator approval.',
        statusCode: 403,
        type: 'forbidden',
      );
    } else if (response.statusCode == 400) {
      throw ApiException(
        message.isNotEmpty
            ? message
            : 'Please check your information and try again.',
        statusCode: 400,
        type: 'validation',
      );
    } else if (response.statusCode >= 500) {
      throw ApiException(
        message.isNotEmpty
            ? message
            : 'Server encountered an error. Please try again later.',
        statusCode: response.statusCode,
        type: 'server',
      );
    }

    throw ApiException(
      message.isNotEmpty
          ? message
          : 'Request failed with status ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  // ===============================
  // HEALTH CHECK
  // ===============================

  static Future<Map<String, dynamic>> checkHealth() async {
    final response = await _send(
      () => http.get(uri('/api/health'), headers: _headers),
    );

    return _parseJsonResponse(response);
  }

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
    final response = await _send(
      () => http.post(
        uri('/api/register'),
        headers: _headers,
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim(),
          'student_id': studentId.trim(),
          'password': password,
          'role': role.trim(),
          'role_requested': role.trim(),
        }),
      ),
    );

    return _parseJsonResponse(response);
  }

  // ===============================
  // LOGIN USER
  // ===============================

  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      () => http.post(
        uri('/api/login'),
        headers: _headers,
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );

    final data = _parseJsonResponse(response);

    if (data['user'] is Map) {
      return {
        ...Map<String, dynamic>.from(data['user'] as Map),
        'access_token': data['token'],
      };
    }

    throw const ApiException('Invalid server response format.');
  }

  // ===============================
  // GET CURRENT AUTH USER
  // ===============================

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _send(
      () => http.get(uri('/api/auth/me'), headers: _headers),
    );

    final data = _parseJsonResponse(response);

    if (data['user'] is Map) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }

    throw const ApiException('Failed to load user profile');
  }

  // ===============================
  // GET ALL EVENTS (WITH SQLITE CACHE)
  // ===============================

  static Future<List<dynamic>> getEvents() async {
    try {
      final response = await _send(
        () => http.get(uri('/api/events'), headers: _headers),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          unawaited(LocalDatabaseService.instance.cacheEvents(decoded));

          return decoded;
        }
      }

      throw ApiException(
        'Failed to load events',
        statusCode: response.statusCode,
      );
    } catch (e) {
      final cached = await LocalDatabaseService.instance.getCachedEvents();

      if (cached.isNotEmpty) {
        debugPrint(
          '[ApiService] Serving ${cached.length} events from SQLite cache.',
        );

        return cached;
      }

      rethrow;
    }
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
    final response = await _send(
      () => http.post(
        uri('/api/events'),
        headers: _headers,
        body: jsonEncode({
          'name': name.trim(),
          'date': date.trim(),
          'location': location.trim(),
          'description': description.trim(),
          'volunteers_needed': volunteersNeeded,
        }),
      ),
    );

    return _parseJsonResponse(response);
  }

  // ===============================
  // GET TASKS FOR EVENT (WITH SQLITE CACHE)
  // ===============================

  static Future<List<dynamic>> getTasks(int eventId) async {
    try {
      final response = await _send(
        () => http.get(uri('/api/events/$eventId/tasks'), headers: _headers),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          unawaited(LocalDatabaseService.instance.cacheTasks(eventId, decoded));

          return decoded;
        }
      }

      throw ApiException(
        'Failed to load tasks',
        statusCode: response.statusCode,
      );
    } catch (e) {
      final cached = await LocalDatabaseService.instance.getCachedTasks(
        eventId,
      );

      if (cached.isNotEmpty) {
        debugPrint(
          '[ApiService] Serving ${cached.length} tasks from SQLite cache.',
        );

        return cached;
      }

      rethrow;
    }
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
    final response = await _send(
      () => http.post(
        uri('/api/tasks'),
        headers: _headers,
        body: jsonEncode({
          'event_id': eventId,
          'task_name': taskName.trim(),
          'date': date.trim(),
          'start_time': startTime.trim(),
          'end_time': endTime.trim(),
          'location': location.trim(),
          'instructions': instructions.trim(),
          'volunteers_required': volunteersRequired,
        }),
      ),
    );

    return _parseJsonResponse(response);
  }

  // ===============================
  // ENROLL IN A TASK
  // ===============================

  static Future<Map<String, dynamic>> enroll(int userId, int taskId) async {
    final response = await _send(
      () => http.post(
        uri('/api/enroll'),
        headers: _headers,
        body: jsonEncode({'user_id': userId, 'task_id': taskId}),
      ),
    );

    return _parseJsonResponse(response);
  }

  // ===============================
  // GET ENROLLED TASKS FOR A USER (MY TASKS)
  // ===============================

  static Future<List<dynamic>> getUserTasks(int userId) async {
    final response = await _send(
      () => http.get(uri('/api/users/$userId/tasks'), headers: _headers),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw ApiException(
      'Failed to load your tasks',
      statusCode: response.statusCode,
    );
  }

  // ===============================
  // UPDATE PROFILE
  // ===============================

  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String name,
    required String studentId,
  }) async {
    final response = await _send(
      () => http.put(
        uri('/api/users/$userId/profile'),
        headers: _headers,
        body: jsonEncode({'name': name.trim(), 'student_id': studentId.trim()}),
      ),
    );

    final data = _parseJsonResponse(response);

    if (data['user'] is Map) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }

    throw const ApiException('Failed to update profile');
  }

  // ===============================
  // GET ALL ENROLLMENTS (VOLUNTEER REQUESTS)
  // ===============================

  static Future<List<dynamic>> getEnrollments({String? status}) async {
    final query = status == null ? '' : '?status=$status';

    final response = await _send(
      () => http.get(uri('/api/enrollments$query'), headers: _headers),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw ApiException(
      'Failed to load volunteer requests',
      statusCode: response.statusCode,
    );
  }

  // ===============================
  // GET VOLUNTEERS FOR A TASK
  // ===============================

  static Future<List<dynamic>> getTaskVolunteers(int taskId) async {
    final response = await _send(
      () => http.get(uri('/api/tasks/$taskId/volunteers'), headers: _headers),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw ApiException(
      'Failed to load volunteers',
      statusCode: response.statusCode,
    );
  }

  // ===============================
  // UPDATE ENROLLMENT STATUS (APPROVE / REJECT)
  // ===============================

  static Future<Map<String, dynamic>> updateEnrollmentStatus(
    int enrollmentId,
    String status,
  ) async {
    final response = await _send(
      () => http.put(
        uri('/api/enrollments/$enrollmentId/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      ),
    );

    return _parseJsonResponse(response);
  }

  // ===============================
  // GET ROLE REQUESTS (HEAD VOLUNTEER APPROVALS)
  // ===============================

  static Future<List<dynamic>> getRoleRequests() async {
    final response = await _send(
      () => http.get(uri('/api/role-requests'), headers: _headers),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw ApiException('Failed to load role requests');
  }

  static Future<Map<String, dynamic>> updateRoleRequest(
    int targetUserId,
    String action,
  ) async {
    final response = await _send(
      () => http.put(
        uri('/api/role-requests/$targetUserId'),
        headers: _headers,
        body: jsonEncode({'action': action}),
      ),
    );

    return _parseJsonResponse(response);
  }

  // ===============================
  // GET ANNOUNCEMENTS (WITH SQLITE CACHE)
  // ===============================

  static Future<List<dynamic>> getAnnouncements() async {
    try {
      final response = await _send(
        () => http.get(uri('/api/announcements'), headers: _headers),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          unawaited(LocalDatabaseService.instance.cacheAnnouncements(decoded));

          return decoded;
        }
      }

      throw ApiException(
        'Failed to load announcements',
        statusCode: response.statusCode,
      );
    } catch (e) {
      final cached = await LocalDatabaseService.instance
          .getCachedAnnouncements();

      if (cached.isNotEmpty) {
        debugPrint(
          '[ApiService] Serving ${cached.length} announcements from SQLite cache.',
        );

        return cached;
      }

      rethrow;
    }
  }

  // ===============================
  // GET ANNOUNCEMENTS FOR AN EVENT
  // ===============================

  static Future<List<dynamic>> getEventAnnouncements(int eventId) async {
    final response = await _send(
      () => http.get(
        uri('/api/events/$eventId/announcements'),
        headers: _headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw ApiException(
      'Failed to load announcements',
      statusCode: response.statusCode,
    );
  }

  // ===============================
  // CREATE ANNOUNCEMENT
  // ===============================

  static Future<Map<String, dynamic>> createAnnouncement({
    required int eventId,
    required String title,
    required String message,
  }) async {
    final response = await _send(
      () => http.post(
        uri('/api/announcements'),
        headers: _headers,
        body: jsonEncode({
          'event_id': eventId,
          'title': title.trim(),
          'message': message.trim(),
        }),
      ),
    );

    return _parseJsonResponse(response);
  }

  // ===============================
  // SUBMIT HELP REQUEST
  // ===============================

  static Future<Map<String, dynamic>> submitHelpRequest({
    required int userId,
    required int eventId,
    required String message,
  }) async {
    final response = await _send(
      () => http.post(
        uri('/api/help-requests'),
        headers: _headers,
        body: jsonEncode({
          'user_id': userId,
          'event_id': eventId,
          'message': message.trim(),
        }),
      ),
    );

    return _parseJsonResponse(response);
  }

  // ===============================
  // GET ALL HELP REQUESTS
  // ===============================

  static Future<List<dynamic>> getHelpRequests({String? status}) async {
    final query = status == null ? '' : '?status=$status';

    final response = await _send(
      () => http.get(uri('/api/help-requests$query'), headers: _headers),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw ApiException(
      'Failed to load help requests',
      statusCode: response.statusCode,
    );
  }

  // ===============================
  // UPDATE HELP REQUEST STATUS
  // ===============================

  static Future<Map<String, dynamic>> updateHelpRequestStatus(
    int requestId,
    String status,
  ) async {
    final response = await _send(
      () => http.put(
        uri('/api/help-requests/$requestId/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      ),
    );

    return _parseJsonResponse(response);
  }
}
