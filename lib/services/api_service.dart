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
            : 'Access denied. Administrator privileges are required.',
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
    } else if (response.statusCode == 404) {
      throw ApiException(
        message.isNotEmpty
            ? message
            : 'The requested event or task was not found. Refresh and try again.',
        statusCode: 404,
        type: 'not_found',
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

  static Future<List<dynamic>> getEvents({
    String? area,
    String? category,
    String? date,
    bool availableOnly = false,
  }) async {
    final query = <String, String>{
      if (area != null && area.trim().isNotEmpty) 'area': area.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (date != null && date.isNotEmpty) 'date': date,
      if (availableOnly) 'available': 'true',
    };
    final eventsUri = uri(
      '/api/events',
    ).replace(queryParameters: query.isEmpty ? null : query);
    try {
      final response = await _send(
        () => http.get(eventsUri, headers: _headers),
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
      if (e is! ApiException || !['network', 'timeout'].contains(e.type)) {
        rethrow;
      }
      final cached = await LocalDatabaseService.instance.getCachedEvents();

      if (cached.isNotEmpty) {
        debugPrint(
          '[ApiService] Serving ${cached.length} events from SQLite cache.',
        );
        return cached
            .where((event) {
              final eventArea = (event['area'] ?? event['location'] ?? '')
                  .toString()
                  .toLowerCase();
              final eventCategory = (event['category'] ?? '')
                  .toString()
                  .toLowerCase();
              final eventDate = event['date']?.toString().split(' ').first;
              return (area == null ||
                      area.trim().isEmpty ||
                      eventArea.contains(area.trim().toLowerCase())) &&
                  (category == null ||
                      category.trim().isEmpty ||
                      eventCategory == category.trim().toLowerCase()) &&
                  (date == null || date.isEmpty || eventDate == date) &&
                  (!availableOnly ||
                      event['available_slots'] == null ||
                      (event['available_slots'] as num).toInt() > 0);
            })
            .map((event) => {...event, '_is_cached': true})
            .toList();
      }

      rethrow;
    }
  }

  static Future<List<dynamic>> getManagedEvents() async {
    final response = await _send(
      () => http.get(uri('/api/head/events'), headers: _headers),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException('Failed to load your managed events');
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
    String status = 'draft',
    String category = '',
    String startTime = '',
    String endTime = '',
    String area = '',
    String address = '',
    String requiredRoles = '',
    String meetingPoint = '',
    String reportingInstructions = '',
    String instructions = '',
    String contactPhone = '',
    String imageUrl = '',
    String registrationDeadline = '',
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
          'status': status,
          'category': category.trim(),
          'start_time': startTime.trim(),
          'end_time': endTime.trim(),
          'area': area.trim(),
          'address': address.trim(),
          'required_roles': requiredRoles.trim(),
          'meeting_point': meetingPoint.trim(),
          'reporting_instructions': reportingInstructions.trim(),
          'instructions': instructions.trim(),
          'contact_phone': contactPhone.trim(),
          'image_url': imageUrl.trim(),
          'registration_deadline': registrationDeadline.trim(),
        }),
      ),
    );

    return _parseJsonResponse(response);
  }

  static Future<Map<String, dynamic>> updateEvent({
    required int eventId,
    required Map<String, dynamic> details,
  }) async {
    final response = await _send(
      () => http.put(
        uri('/api/events/$eventId'),
        headers: _headers,
        body: jsonEncode(details),
      ),
    );
    return _parseJsonResponse(response);
  }

  static Future<Map<String, dynamic>> getEventDetails(int eventId) async {
    final response = await _send(
      () => http.get(uri('/api/events/$eventId'), headers: _headers),
    );
    return _parseJsonResponse(response);
  }

  static Future<Map<String, dynamic>> publishEvent(int eventId) async {
    final response = await _send(
      () => http.put(
        uri('/api/events/$eventId/publish'),
        headers: _headers,
        body: jsonEncode({}),
      ),
    );
    return _parseJsonResponse(response);
  }

  static Future<Map<String, dynamic>> cancelEvent(int eventId) async {
    final response = await _send(
      () => http.put(
        uri('/api/events/$eventId/cancel'),
        headers: _headers,
        body: jsonEncode({}),
      ),
    );
    return _parseJsonResponse(response);
  }

  static Future<Map<String, dynamic>> registerForEvent({
    required int eventId,
    required String selectedLocation,
  }) async {
    final response = await _send(
      () => http.post(
        uri('/api/events/$eventId/register'),
        headers: _headers,
        body: jsonEncode({'selected_location': selectedLocation.trim()}),
      ),
    );
    return _parseJsonResponse(response);
  }

  static Future<List<dynamic>> getUserEvents(int userId) async {
    final response = await _send(
      () => http.get(uri('/api/users/$userId/events'), headers: _headers),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException('Failed to load your event registrations');
  }

  static Future<List<dynamic>> getNotifications() async {
    final response = await _send(
      () => http.get(uri('/api/notifications'), headers: _headers),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException('Failed to load notifications');
  }

  static Future<void> markNotificationRead(int notificationId) async {
    final response = await _send(
      () => http.put(
        uri('/api/notifications/$notificationId/read'),
        headers: _headers,
        body: jsonEncode({}),
      ),
    );
    _parseJsonResponse(response);
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
      if (e is! ApiException || !['network', 'timeout'].contains(e.type)) {
        rethrow;
      }
      final cached = await LocalDatabaseService.instance.getCachedTasks(
        eventId,
      );

      if (cached.isNotEmpty) {
        debugPrint(
          '[ApiService] Serving ${cached.length} tasks from SQLite cache.',
        );

        return cached.map((task) => {...task, '_is_cached': true}).toList();
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
    String description = '',
    int? volunteersRequired,
    String status = 'Open',
    String compensationType = 'unpaid',
    double? compensationAmount,
    String compensationCurrency = 'INR',
    String compensationTerms = '',
    String additionalRequirements = '',
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
          'description': description.trim(),
          'volunteers_required': volunteersRequired,
          'status': status,
          'compensation_type': compensationType,
          'compensation_amount': compensationAmount,
          'compensation_currency': compensationCurrency,
          'compensation_terms': compensationTerms.trim(),
          'additional_requirements': additionalRequirements.trim(),
        }),
      ),
    );

    return _parseJsonResponse(response);
  }

  static Future<Map<String, dynamic>> updateTask({
    required int taskId,
    required Map<String, dynamic> details,
  }) async {
    final response = await _send(
      () => http.put(
        uri('/api/tasks/$taskId'),
        headers: _headers,
        body: jsonEncode(details),
      ),
    );
    return _parseJsonResponse(response);
  }

  // ===============================
  // ENROLL IN A TASK
  // ===============================

  static Future<Map<String, dynamic>> enroll(int taskId) async {
    final response = await _send(
      () => http.post(
        uri('/api/enroll'),
        headers: _headers,
        body: jsonEncode({'task_id': taskId}),
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
    String phone = '',
    String area = '',
  }) async {
    final response = await _send(
      () => http.put(
        uri('/api/users/$userId/profile'),
        headers: _headers,
        body: jsonEncode({
          'name': name.trim(),
          'student_id': studentId.trim(),
          'phone': phone.trim(),
          'area': area.trim(),
        }),
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
