import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import 'db_factory.dart';

// ============================================================
// LOCAL BACKEND
// Answers the same REST routes as backend/server.js, but entirely
// on the device using SQLite, so the app works without a server.
// ApiService sends its requests here through LocalBackendClient.
// ============================================================

class _Abort implements Exception {
  final int status;
  final String message;
  const _Abort(this.status, this.message);
}

class _Res {
  final int status;
  final Object? body;
  const _Res(this.status, this.body);
}

typedef _Json = Map<String, dynamic>;

class LocalBackendClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final res = await LocalBackend.instance._handle(
      request.method,
      request.url,
      utf8.decode(bytes),
      request.headers['Authorization'],
    );
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(res.body))),
      res.status,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

class LocalBackend {
  LocalBackend._();
  static final LocalBackend instance = LocalBackend._();

  static const _dbName = 'standalone_volunteer.db';
  static final _timeRe = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$');
  static final _timeSecRe = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$');
  static const _taskStatuses = [
    'Open',
    'Assigned',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get _database => _db != null
      ? Future.value(_db)
      : (_opening ??= _open().then((d) => _db = d));

  Future<Database> _open() => openAppDatabase(
    _dbName,
    version: 1,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON;'),
    onCreate: (db, version) async {
      for (final sql in _schema) {
        await db.execute(sql);
      }
    },
  );

  static const _schema = <String>[
    '''CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT COLLATE NOCASE UNIQUE NOT NULL,
      student_id TEXT NOT NULL,
      phone TEXT,
      area TEXT,
      password TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'Volunteer',
      role_requested TEXT NOT NULL DEFAULT 'Volunteer',
      role_status TEXT NOT NULL DEFAULT 'approved',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )''',
    '''CREATE TABLE events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      date TEXT NOT NULL,
      location TEXT NOT NULL,
      description TEXT,
      volunteers_needed INTEGER,
      category TEXT,
      start_time TEXT,
      end_time TEXT,
      area TEXT,
      address TEXT,
      required_roles TEXT,
      meeting_point TEXT,
      reporting_instructions TEXT,
      instructions TEXT,
      contact_phone TEXT,
      image_url TEXT,
      registration_deadline TEXT,
      status TEXT NOT NULL DEFAULT 'published',
      published_at TEXT,
      created_by INTEGER,
      responsible_head_id INTEGER,
      admin_override INTEGER NOT NULL DEFAULT 0,
      admin_override_by INTEGER,
      admin_override_at TEXT,
      cancelled_at TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )''',
    '''CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL,
      task_name TEXT NOT NULL,
      description TEXT,
      date TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      location TEXT NOT NULL,
      instructions TEXT,
      volunteers_required INTEGER,
      status TEXT NOT NULL DEFAULT 'Open',
      location_is_independent INTEGER NOT NULL DEFAULT 1,
      compensation_type TEXT NOT NULL DEFAULT 'unpaid',
      compensation_amount NUMERIC,
      compensation_currency TEXT NOT NULL DEFAULT 'INR',
      compensation_terms TEXT,
      additional_requirements TEXT,
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE enrollments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      task_id INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending'
        CHECK(status IN ('pending','approved','rejected')),
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(user_id, task_id),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE announcements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE help_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      event_id INTEGER NOT NULL,
      message TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved')),
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE event_registrations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      selected_location TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'confirmed',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(event_id, user_id),
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      event_id INTEGER,
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      type TEXT NOT NULL,
      read_at TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE event_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL,
      actor_id INTEGER,
      entity_type TEXT NOT NULL,
      action TEXT NOT NULL,
      details TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX idx_events_date ON events(date)',
    'CREATE INDEX idx_tasks_event_id ON tasks(event_id)',
    'CREATE INDEX idx_enrollments_task_id ON enrollments(task_id)',
    'CREATE INDEX idx_announcements_event_id ON announcements(event_id)',
  ];

  // ----------------------------------------------------------
  // helpers
  // ----------------------------------------------------------

  static String _s(Object? v) => (v ?? '').toString().trim();
  static String? _sn(Object? v) {
    final t = _s(v);
    return t.isEmpty ? null : t;
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v == v.toInt() ? v.toInt() : null;
    return int.tryParse(_s(v));
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();
  static String _today() => _now().substring(0, 10);

  static bool _validDate(String v) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return false;
    final d = DateTime.tryParse('${v}T00:00:00Z');
    return d != null && d.toIso8601String().substring(0, 10) == v;
  }

  static DateTime? _start(String date, String? time) {
    var t = (time == null || time.isEmpty) ? '23:59:59' : time;
    if (t.length == 5) t = '$t:00';
    return DateTime.tryParse('${date}T${t}Z');
  }

  static bool _publishDeadlineMet(String date, String? time) {
    final s = _start(date, (time == null || time.isEmpty) ? '00:00:00' : time);
    return s != null &&
        s.difference(DateTime.now().toUtc()) >= const Duration(days: 5);
  }

  static _Json _row(Map<String, Object?> r) => Map<String, dynamic>.from(r);

  static String _salt() {
    final r = Random.secure();
    return base64Url.encode(List.generate(12, (_) => r.nextInt(256)));
  }

  static String _hash(String password, [String? salt]) {
    final s = salt ?? _salt();
    var digest = sha256.convert(utf8.encode('$s$password'));
    for (var i = 0; i < 3000; i++) {
      digest = sha256.convert([...digest.bytes, ...utf8.encode(password)]);
    }
    return 'sha256\$$s\$$digest';
  }

  static bool _verify(String password, String stored) {
    final parts = stored.split('\$');
    if (parts.length != 3 || parts[0] != 'sha256') return false;
    return _hash(password, parts[1]) == stored;
  }

  // ----------------------------------------------------------
  // entry point
  // ----------------------------------------------------------

  Future<_Res> _handle(
    String method,
    Uri url,
    String rawBody,
    String? authHeader,
  ) async {
    try {
      final db = await _database;
      _Json body = {};
      if (rawBody.trim().isNotEmpty) {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      }
      return await _route(db, method, url, body, authHeader);
    } on _Abort catch (e) {
      return _Res(e.status, {'message': e.message});
    } catch (e, st) {
      debugPrint('[LocalBackend] $method ${url.path} failed: $e\n$st');
      return const _Res(500, {'message': 'Local database error'});
    }
  }

  Future<_Res> _route(
    Database db,
    String method,
    Uri url,
    _Json body,
    String? auth,
  ) async {
    final path = url.path.replaceAll(RegExp(r'/+$'), '');
    final q = url.queryParameters;
    RegExpMatch? m(String pattern) =>
        RegExp('^$pattern\$').firstMatch('$method $path');

    if (m(r'GET /api/health') != null) {
      return _Res(200, {
        'status': 'ok',
        'database': 'on-device',
        'timestamp': _now(),
      });
    }
    if (m(r'POST /api/register') != null) return _register(db, body);
    if (m(r'POST /api/login') != null) return _login(db, body);
    if (m(r'GET /api/announcements') != null) return _announcements(db);
    var x = m(r'GET /api/events/(\d+)/announcements');
    if (x != null) return _eventAnnouncements(db, int.parse(x.group(1)!));
    if (m(r'GET /api/events') != null) return _events(db, q);

    // everything below needs a signed-in account
    final user = await _auth(db, auth);
    final uid = user['id'] as int;

    if (m(r'GET /api/auth/me') != null) return _me(db, uid);
    x = m(r'GET /api/events/(\d+)');
    if (x != null) return _eventDetails(db, int.parse(x.group(1)!));
    x = m(r'GET /api/events/(\d+)/tasks');
    if (x != null) return _tasksFor(db, int.parse(x.group(1)!), uid);
    x = m(r'POST /api/events/(\d+)/register');
    if (x != null) return _registerForEvent(db, user, int.parse(x.group(1)!), body);
    x = m(r'GET /api/users/(\d+)/events');
    if (x != null) return _userEvents(db, uid, int.parse(x.group(1)!));
    x = m(r'GET /api/users/(\d+)/tasks');
    if (x != null) return _userTasks(db, uid, int.parse(x.group(1)!));
    x = m(r'PUT /api/users/(\d+)/profile');
    if (x != null) return _profile(db, uid, int.parse(x.group(1)!), body);
    if (m(r'GET /api/notifications') != null) return _notifications(db, uid);
    x = m(r'PUT /api/notifications/(\d+)/read');
    if (x != null) return _readNotification(db, uid, int.parse(x.group(1)!));
    if (m(r'POST /api/enroll') != null) return _enroll(db, uid, body);
    if (m(r'POST /api/help-requests') != null) return _submitHelp(db, uid, body);

    // staff-only routes
    final staff = const ['Head Volunteer', 'Administrator'];
    final isStaffRoute =
        path.startsWith('/api/head') ||
        path == '/api/events' ||
        path.startsWith('/api/events/') ||
        path.startsWith('/api/tasks') ||
        path.startsWith('/api/enrollments') ||
        path.startsWith('/api/announcements') ||
        path.startsWith('/api/help-requests') ||
        path.startsWith('/api/role-requests');
    if (!isStaffRoute) throw const _Abort(404, 'Route not found');
    if (path.startsWith('/api/role-requests')) {
      if (user['role'] != 'Administrator') {
        throw const _Abort(403, 'Administrator access is required');
      }
      if (method == 'GET') return _roleRequests(db);
      x = m(r'PUT /api/role-requests/(\d+)');
      if (x != null) return _updateRole(db, int.parse(x.group(1)!), body);
    }
    if (!staff.contains(user['role'])) {
      throw const _Abort(403, 'Head Volunteer access is required');
    }

    if (m(r'GET /api/head/events') != null) return _managedEvents(db, user);
    if (m(r'POST /api/events') != null) return _createEvent(db, user, body);
    x = m(r'PUT /api/events/(\d+)');
    if (x != null) return _updateEvent(db, user, int.parse(x.group(1)!), body);
    x = m(r'PUT /api/events/(\d+)/publish');
    if (x != null) return _publish(db, user, int.parse(x.group(1)!), body);
    x = m(r'PUT /api/events/(\d+)/cancel');
    if (x != null) return _cancel(db, user, int.parse(x.group(1)!));
    if (m(r'POST /api/tasks') != null) return _createTask(db, user, body);
    x = m(r'PUT /api/tasks/(\d+)');
    if (x != null) return _updateTask(db, user, int.parse(x.group(1)!), body);
    x = m(r'GET /api/tasks/(\d+)/volunteers');
    if (x != null) return _taskVolunteers(db, user, int.parse(x.group(1)!));
    if (m(r'GET /api/enrollments') != null) return _enrollments(db, user, q);
    x = m(r'PUT /api/enrollments/(\d+)/status');
    if (x != null) {
      return _enrollmentStatus(db, user, int.parse(x.group(1)!), body);
    }
    if (m(r'POST /api/announcements') != null) {
      return _createAnnouncement(db, user, body);
    }
    if (m(r'GET /api/help-requests') != null) return _helpRequests(db, user, q);
    x = m(r'PUT /api/help-requests/(\d+)/status');
    if (x != null) return _helpStatus(db, user, int.parse(x.group(1)!), body);

    throw const _Abort(404, 'Route not found');
  }

  Future<_Json> _auth(Database db, String? header) async {
    final m = RegExp(r'^Bearer local\.(\d+)$').firstMatch(header ?? '');
    if (m == null) throw const _Abort(401, 'Authentication is required');
    final rows = await db.rawQuery(
      'SELECT id, role FROM users WHERE id = ?',
      [int.parse(m.group(1)!)],
    );
    if (rows.isEmpty) throw const _Abort(401, 'Account is no longer available');
    return _row(rows.first);
  }

  /// Returns the event row when [userId] may manage it, otherwise throws.
  Future<_Json> _manage(
    DatabaseExecutor db,
    int eventId,
    int userId,
    String denied,
  ) async {
    final rows = await db.rawQuery(
      '''SELECT id, name, date, start_time, end_time, location, status,
                created_by, responsible_head_id, volunteers_needed
         FROM events WHERE id = ?''',
      [eventId],
    );
    if (rows.isEmpty) throw const _Abort(404, 'Event not found');
    final event = _row(rows.first);
    final users = await db.rawQuery('SELECT role FROM users WHERE id = ?', [
      userId,
    ]);
    final role = users.isEmpty ? null : users.first['role'];
    final allowed =
        role == 'Administrator' ||
        event['created_by'] == userId ||
        event['responsible_head_id'] == userId;
    if (!allowed) throw _Abort(403, denied);
    return event;
  }

  Future<void> _history(
    DatabaseExecutor db,
    int eventId,
    int actor,
    String entity,
    String action, [
    Object? details,
  ]) => db.rawInsert(
    '''INSERT INTO event_history (event_id, actor_id, entity_type, action, details)
       VALUES (?, ?, ?, ?, ?)''',
    [eventId, actor, entity, action, details == null ? null : jsonEncode(details)],
  );

  Future<void> _notify(
    DatabaseExecutor db,
    int userId,
    int? eventId,
    String title,
    String message,
    String type,
  ) => db.rawInsert(
    '''INSERT INTO notifications (user_id, event_id, title, message, type)
       VALUES (?, ?, ?, ?, ?)''',
    [userId, eventId, title, message, type],
  );

  // ----------------------------------------------------------
  // accounts
  // ----------------------------------------------------------

  Future<_Res> _register(Database db, _Json b) async {
    final name = _s(b['name']);
    final email = _s(b['email']).toLowerCase();
    final studentId = _s(b['student_id']);
    final password = (b['password'] ?? '').toString();
    final role = _s(b['role'] ?? b['role_requested']);
    if (name.isEmpty || email.isEmpty || studentId.isEmpty || password.isEmpty) {
      throw const _Abort(400, 'All fields are required');
    }
    if (role != 'Volunteer' && role != 'Head Volunteer') {
      throw const _Abort(
        400,
        'A valid role is required. Please select either Volunteer or Head Volunteer.',
      );
    }
    if (name.length > 100 ||
        studentId.length > 100 ||
        email.length > 255 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const _Abort(400, 'Enter valid name, email and student ID values');
    }
    if (password.length < 6 || utf8.encode(password).length > 72) {
      throw const _Abort(
        400,
        'Password must be at least 6 characters and no more than 72 UTF-8 bytes',
      );
    }
    final existing = await db.rawQuery(
      'SELECT id FROM users WHERE LOWER(email) = ?',
      [email],
    );
    if (existing.isNotEmpty) throw const _Abort(409, 'Email already registered');
    final id = await db.rawInsert(
      '''INSERT INTO users (name, email, student_id, password, role, role_requested, role_status)
         VALUES (?, ?, ?, ?, ?, ?, 'approved')''',
      [name, email, studentId, _hash(password), role, role],
    );
    return _Res(201, {
      'message': 'Account created successfully! You can now log in.',
      'userId': id,
      'role': role,
      'role_requested': role,
      'role_status': 'approved',
    });
  }

  Future<_Res> _login(Database db, _Json b) async {
    final email = _s(b['email']).toLowerCase();
    final password = (b['password'] ?? '').toString();
    if (email.isEmpty || password.isEmpty) {
      throw const _Abort(400, 'Email and password are required');
    }
    final rows = await db.rawQuery(
      '''SELECT id, name, email, student_id, phone, area, password, role,
                COALESCE(role_requested, role) AS role_requested,
                COALESCE(role_status, 'approved') AS role_status
         FROM users WHERE LOWER(email) = ?''',
      [email],
    );
    if (rows.isEmpty || !_verify(password, rows.first['password'] as String)) {
      throw const _Abort(401, 'Invalid email or password');
    }
    final user = _row(rows.first)..remove('password');
    return _Res(200, {
      'message': 'Login successful',
      'token': 'local.${user['id']}',
      'user': user,
    });
  }

  Future<_Res> _me(Database db, int uid) async {
    final rows = await db.rawQuery(
      '''SELECT id, name, email, student_id, phone, area, role,
                COALESCE(role_requested, role) AS role_requested,
                COALESCE(role_status, 'approved') AS role_status, created_at
         FROM users WHERE id = ?''',
      [uid],
    );
    if (rows.isEmpty) throw const _Abort(404, 'User not found');
    return _Res(200, {'user': rows.first});
  }

  Future<_Res> _profile(Database db, int uid, int userId, _Json b) async {
    if (userId != uid) {
      throw const _Abort(403, 'You cannot edit another user\'s profile');
    }
    final name = _s(b['name']);
    final studentId = _s(b['student_id']);
    final phone = _s(b['phone']);
    final area = _s(b['area']);
    if (name.isEmpty || studentId.isEmpty) {
      throw const _Abort(400, 'Name and student ID are required');
    }
    if (name.length > 100 || studentId.length > 100) {
      throw const _Abort(
        400,
        'Name and student ID must be 100 characters or fewer',
      );
    }
    if (phone.length > 40 || area.length > 120) {
      throw const _Abort(
        400,
        'Phone must be 40 characters and area 120 characters or fewer',
      );
    }
    await db.rawUpdate(
      'UPDATE users SET name = ?, student_id = ?, phone = ?, area = ? WHERE id = ?',
      [name, studentId, phone.isEmpty ? null : phone, area.isEmpty ? null : area, uid],
    );
    return _Res(200, {
      'message': 'Profile updated',
      'user': {
        'id': uid,
        'name': name,
        'student_id': studentId,
        'phone': phone,
        'area': area,
      },
    });
  }

  Future<_Res> _roleRequests(Database db) async => _Res(
    200,
    await db.rawQuery('''SELECT id, name, email, student_id, role,
              COALESCE(role_requested, role) AS role_requested,
              COALESCE(role_status, 'approved') AS role_status, created_at
       FROM users WHERE role_requested = 'Head Volunteer' OR role = 'Head Volunteer'
       ORDER BY CASE WHEN role_status = 'pending' THEN 0 ELSE 1 END, created_at DESC'''),
  );

  Future<_Res> _updateRole(Database db, int target, _Json b) async {
    final action = b['action'];
    if (action != 'approve' && action != 'reject') {
      throw const _Abort(400, 'Action must be "approve" or "reject"');
    }
    final role = action == 'approve' ? 'Head Volunteer' : 'Volunteer';
    final status = action == 'approve' ? 'approved' : 'rejected';
    final n = await db.rawUpdate(
      'UPDATE users SET role = ?, role_status = ? WHERE id = ?',
      [role, status, target],
    );
    if (n == 0) throw const _Abort(404, 'User not found');
    return _Res(200, {
      'message': 'Role request ${action == 'approve' ? 'approved' : 'rejected'} successfully',
      'userId': target,
      'role': role,
      'role_status': status,
    });
  }

  // ----------------------------------------------------------
  // events
  // ----------------------------------------------------------

  static const _slotCount =
      "(SELECT COUNT(*) FROM event_registrations er WHERE er.event_id = e.id AND er.status = 'confirmed')";

  Future<_Res> _events(Database db, Map<String, String> q) async {
    final params = <Object?>[_today()];
    var sql =
        '''SELECT e.id, e.name, e.date, e.start_time, e.end_time, e.location,
               e.area, e.address, e.description, e.category, e.required_roles,
               e.meeting_point, e.reporting_instructions, e.instructions,
               e.image_url, e.registration_deadline, e.status,
               e.volunteers_needed, e.responsible_head_id,
               head.name AS head_volunteer_name,
               head.email AS head_volunteer_email,
               COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone,
               $_slotCount AS registered_count,
               CASE WHEN e.volunteers_needed IS NULL THEN NULL
                    WHEN e.volunteers_needed - $_slotCount < 0 THEN 0
                    ELSE e.volunteers_needed - $_slotCount END AS available_slots
        FROM events e
        LEFT JOIN users head ON head.id = e.responsible_head_id
        WHERE e.status = 'published' AND e.date >= ?''';
    if ((q['area'] ?? '').isNotEmpty) {
      sql += ' AND LOWER(COALESCE(e.area, e.location)) LIKE ?';
      params.add('%${q['area']!.trim().toLowerCase()}%');
    }
    if ((q['category'] ?? '').isNotEmpty) {
      sql += " AND LOWER(COALESCE(e.category, '')) = ?";
      params.add(q['category']!.trim().toLowerCase());
    }
    for (final entry in {'date': '=', 'from': '>=', 'to': '<='}.entries) {
      final v = q[entry.key];
      if (v != null && v.isNotEmpty) {
        if (!_validDate(v)) {
          throw const _Abort(400, 'Enter a valid event date filter');
        }
        sql += ' AND e.date ${entry.value} ?';
        params.add(v);
      }
    }
    if (q['available'] == 'true') {
      sql +=
          ' AND (e.volunteers_needed IS NULL OR $_slotCount < e.volunteers_needed)';
    }
    sql += ' ORDER BY e.date ASC, e.start_time ASC';
    return _Res(200, await db.rawQuery(sql, params));
  }

  Future<_Res> _managedEvents(Database db, _Json user) async {
    final admin = user['role'] == 'Administrator';
    final rows = await db.rawQuery('''SELECT e.*, head.name AS head_volunteer_name,
             head.email AS head_volunteer_email,
             COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone,
             $_slotCount AS registered_count,
             CASE WHEN e.volunteers_needed IS NULL THEN NULL
                  WHEN e.volunteers_needed - $_slotCount < 0 THEN 0
                  ELSE e.volunteers_needed - $_slotCount END AS available_slots
      FROM events e LEFT JOIN users head ON head.id = e.responsible_head_id
      ${admin ? '' : 'WHERE e.created_by = ? OR e.responsible_head_id = ?'}
      ORDER BY e.date ASC, e.start_time ASC''', admin ? [] : [user['id'], user['id']]);
    return _Res(200, rows);
  }

  Future<_Res> _eventDetails(Database db, int id) async {
    final rows = await db.rawQuery(
      '''SELECT e.id, e.name, e.date, e.start_time, e.end_time, e.location,
              e.description, e.volunteers_needed, e.category, e.area, e.address,
              e.required_roles, e.meeting_point, e.reporting_instructions,
              e.instructions, e.contact_phone, e.image_url,
              e.registration_deadline, e.status,
              head.name AS head_volunteer_name,
              head.email AS head_volunteer_email,
              head.role AS head_volunteer_role,
              COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone,
              $_slotCount AS registered_count
       FROM events e LEFT JOIN users head ON head.id = e.responsible_head_id
       WHERE e.id = ? AND e.status = 'published' ''',
      [id],
    );
    if (rows.isEmpty) throw const _Abort(404, 'Event not found');
    return _Res(200, rows.first);
  }

  Future<_Res> _createEvent(Database db, _Json user, _Json b) async {
    final name = _s(b['name']);
    final location = _s(b['location']);
    final date = _s(b['date']);
    final start = _sn(b['start_time']);
    final end = _sn(b['end_time']);
    final hasLimit =
        b['volunteers_needed'] != null && _s(b['volunteers_needed']).isNotEmpty;
    final limit = hasLimit ? _int(b['volunteers_needed']) : null;
    final status = b['status'] == null ? 'draft' : _s(b['status']);
    final override = b['admin_override'] == true;
    final isAdmin = user['role'] == 'Administrator';

    if (name.isEmpty || date.isEmpty || location.isEmpty) {
      throw const _Abort(400, 'Event name, date and location are required');
    }
    if (!['draft', 'published'].contains(status) ||
        name.length > 200 ||
        location.length > 255 ||
        !_validDate(date) ||
        ((start != null || end != null) &&
            (start == null ||
                end == null ||
                !_timeRe.hasMatch(start) ||
                !_timeRe.hasMatch(end) ||
                start.compareTo(end) >= 0))) {
      throw const _Abort(400, 'Enter a valid event name, date and location');
    }
    if (hasLimit && (limit == null || limit <= 0)) {
      throw const _Abort(400, 'Volunteers needed must be a positive whole number');
    }
    if (override && !isAdmin) {
      throw const _Abort(
        403,
        'Only an Administrator may override the publishing deadline',
      );
    }
    if (override && status != 'published') {
      throw const _Abort(
        400,
        'Deadline overrides can only be recorded when publishing an event',
      );
    }
    if (status == 'published' && !_publishDeadlineMet(date, start) && !override) {
      throw const _Abort(
        400,
        'Events must be published at least 5 full days before they begin. Save this event as a draft or ask an Administrator to record an exceptional override.',
      );
    }
    final imageUrl = _sn(b['image_url']);
    if (imageUrl != null &&
        (!RegExp(r'^https?://', caseSensitive: false).hasMatch(imageUrl) ||
            imageUrl.length > 2048)) {
      throw const _Abort(400, 'Enter a valid event image URL');
    }
    final headId = isAdmin ? (_int(b['responsible_head_id']) ?? 0) : user['id'] as int;
    if (headId <= 0) {
      throw const _Abort(400, 'Select a Head Volunteer responsible for this event');
    }
    final heads = await db.rawQuery(
      'SELECT id FROM users WHERE id = ? AND role = ?',
      [headId, 'Head Volunteer'],
    );
    if (heads.isEmpty) {
      throw const _Abort(400, 'The responsible account must be a Head Volunteer');
    }
    final deadline = _s(b['registration_deadline']);
    final id = await db.rawInsert(
      '''INSERT INTO events (name, date, location, description, volunteers_needed,
           category, start_time, end_time, area, address, required_roles,
           meeting_point, reporting_instructions, instructions, contact_phone,
           image_url, registration_deadline, status, published_at, created_by,
           responsible_head_id, admin_override, admin_override_by, admin_override_at)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        name, date, location, _sn(b['description']), limit, _sn(b['category']),
        start, end, _sn(b['area']), _sn(b['address']), _sn(b['required_roles']),
        _sn(b['meeting_point']), _sn(b['reporting_instructions']),
        _sn(b['instructions']), _sn(b['contact_phone']), imageUrl,
        _validDate(deadline) ? deadline : null, status,
        status == 'published' ? _now() : null, user['id'], headId,
        override ? 1 : 0, override ? user['id'] : null, override ? _now() : null,
      ],
    );
    await _history(db, id, user['id'] as int, 'event', 'created', {
      'status': status,
      'override': override,
    });
    return _Res(201, {
      'message': status == 'published'
          ? 'Event published successfully'
          : 'Event saved as draft',
      'eventId': id,
      'status': status,
    });
  }

  Future<_Res> _updateEvent(Database db, _Json user, int id, _Json b) async {
    final uid = user['id'] as int;
    final event = await _manage(
      db,
      id,
      uid,
      'You can only manage events assigned to you or created by you',
    );
    final isAdmin = user['role'] == 'Administrator';
    final oldDate = _s(event['date']).substring(0, 10);
    final date = b['date'] == null ? oldDate : _s(b['date']);
    final start = b['start_time'] == null ? event['start_time'] as String? : _sn(b['start_time']);
    final end = b['end_time'] == null ? event['end_time'] as String? : _sn(b['end_time']);
    final name = b['name'] == null ? event['name'] as String : _s(b['name']);
    final location = b['location'] == null ? event['location'] as String : _s(b['location']);
    final status = b['status'] == null ? event['status'] as String : _s(b['status']);
    final override = b['admin_override'] == true;

    if (name.isEmpty || name.length > 200 || location.isEmpty ||
        location.length > 255 || !_validDate(date) ||
        !['draft', 'published'].contains(status) ||
        ((start != null || end != null) &&
            (start == null || end == null || !_timeRe.hasMatch(start) ||
                !_timeRe.hasMatch(end) || start.compareTo(end) >= 0))) {
      throw const _Abort(400, 'Enter valid event details and a later end time');
    }
    if (override && !isAdmin) {
      throw const _Abort(
        403,
        'Only an Administrator may override the publishing deadline',
      );
    }
    final scheduleChanged = date != oldDate || (start ?? '') != (event['start_time'] ?? '');
    if (status == 'published' &&
        (event['status'] != 'published' || scheduleChanged) &&
        !_publishDeadlineMet(date, start) &&
        !override) {
      throw const _Abort(
        400,
        'Published events must remain at least 5 full days away. Save as a draft or ask an Administrator to record an exceptional override.',
      );
    }
    final oldHead = event['responsible_head_id'] as int?;
    final newHead = b['responsible_head_id'] == null
        ? oldHead
        : _int(b['responsible_head_id']);
    if (newHead != oldHead) {
      if (!isAdmin) {
        throw const _Abort(
          403,
          'Only an Administrator may reassign the responsible Head Volunteer',
        );
      }
      final heads = await db.rawQuery(
        'SELECT id FROM users WHERE id = ? AND role = ?',
        [newHead, 'Head Volunteer'],
      );
      if (heads.isEmpty) {
        throw const _Abort(400, 'The responsible account must be a Head Volunteer');
      }
    }

    final fields = <String>[];
    final values = <Object?>[];
    final assignments = <String, Object?>{
      'name': name, 'date': date, 'location': location,
      'start_time': start, 'end_time': end,
    };
    for (final k in [
      'description', 'volunteers_needed', 'category', 'area', 'address',
      'required_roles', 'meeting_point', 'reporting_instructions',
      'instructions', 'contact_phone', 'image_url', 'registration_deadline',
    ]) {
      if (b.containsKey(k)) assignments[k] = b[k];
    }
    for (final e in assignments.entries) {
      var v = e.value;
      if (e.key == 'volunteers_needed') {
        final n = (v == null || _s(v).isEmpty) ? null : _int(v);
        if (v != null && _s(v).isNotEmpty && (n == null || n <= 0)) {
          throw const _Abort(400, 'Volunteers needed must be a positive whole number');
        }
        v = n;
      } else if (v is String) {
        v = v.trim().isEmpty ? null : v.trim();
      }
      if (e.key == 'registration_deadline' && v != null && !_validDate(v as String)) {
        throw const _Abort(400, 'Enter a valid registration deadline');
      }
      if (e.key == 'image_url' && v != null &&
          (!RegExp(r'^https?://', caseSensitive: false).hasMatch(v as String) ||
              v.length > 2048)) {
        throw const _Abort(400, 'Enter a valid event image URL');
      }
      fields.add('${e.key} = ?');
      values.add(v);
    }
    if (b['status'] != null) {
      fields.add('status = ?');
      values.add(status);
    }
    if (newHead != oldHead) {
      fields.add('responsible_head_id = ?');
      values.add(newHead);
    }
    if (status == 'published' && event['status'] != 'published') {
      fields.add('published_at = ?');
      values.add(_now());
    }
    if (override) {
      fields.addAll(['admin_override = 1', 'admin_override_by = ?', 'admin_override_at = ?']);
      values.addAll([uid, _now()]);
    }
    values.add(id);

    await db.transaction((txn) async {
      await txn.rawUpdate('UPDATE events SET ${fields.join(', ')} WHERE id = ?', values);
      if (date != oldDate) {
        await txn.rawUpdate(
          'UPDATE tasks SET date = ? WHERE event_id = ? AND date = ?',
          [date, id, oldDate],
        );
      }
      if (start != null && (start) != (event['start_time'] ?? '')) {
        await txn.rawUpdate(
          'UPDATE tasks SET start_time = ? WHERE event_id = ? AND start_time = ?',
          [start, id, event['start_time']],
        );
      }
      if (end != null && end != (event['end_time'] ?? '')) {
        await txn.rawUpdate(
          'UPDATE tasks SET end_time = ? WHERE event_id = ? AND end_time = ?',
          [end, id, event['end_time']],
        );
      }
      if (location != event['location']) {
        await txn.rawUpdate(
          'UPDATE tasks SET location = ? WHERE event_id = ? AND location_is_independent = 0',
          [location, id],
        );
      }
      await _history(txn, id, uid, 'event', 'updated', {'status': status, 'override': override});
      final changed = scheduleChanged || location != event['location'] || newHead != oldHead;
      if (changed) {
        await txn.rawInsert(
          '''INSERT INTO notifications (user_id, event_id, title, message, type)
             SELECT user_id, event_id, 'Event details updated',
               'The date, time, location, or responsible Head Volunteer for this event changed. Open the event for current details.',
               'event_updated'
             FROM event_registrations WHERE event_id = ? AND status = 'confirmed' ''',
          [id],
        );
      }
    });
    return _Res(200, {'message': 'Event updated', 'eventId': id});
  }

  Future<_Res> _publish(Database db, _Json user, int id, _Json b) async {
    final uid = user['id'] as int;
    final event = await _manage(
      db, id, uid,
      'You can only publish events assigned to you or created by you',
    );
    final override = b['admin_override'] == true;
    if (override && user['role'] != 'Administrator') {
      throw const _Abort(
        403,
        'Only an Administrator may override the publishing deadline',
      );
    }
    if (!_publishDeadlineMet(_s(event['date']).substring(0, 10), event['start_time'] as String?) &&
        !override) {
      throw const _Abort(
        400,
        'Events must be published at least 5 full days before they begin. Save this event as a draft or ask an Administrator to record an exceptional override.',
      );
    }
    await db.rawUpdate(
      '''UPDATE events SET status = 'published', published_at = ?,
         admin_override = ?, admin_override_by = ?, admin_override_at = ? WHERE id = ?''',
      [_now(), override ? 1 : 0, override ? uid : null, override ? _now() : null, id],
    );
    await _history(db, id, uid, 'event', 'published', {'override': override});
    return const _Res(200, {
      'message': 'Event published successfully',
      'status': 'published',
    });
  }

  Future<_Res> _cancel(Database db, _Json user, int id) async {
    final uid = user['id'] as int;
    await _manage(
      db, id, uid,
      'You can only cancel events assigned to you or created by you',
    );
    await db.transaction((txn) async {
      await txn.rawUpdate(
        "UPDATE events SET status = 'cancelled', cancelled_at = ? WHERE id = ?",
        [_now(), id],
      );
      await txn.rawUpdate(
        "UPDATE tasks SET status = 'Cancelled' WHERE event_id = ? AND status != 'Completed'",
        [id],
      );
      await _history(txn, id, uid, 'event', 'cancelled');
      await txn.rawInsert(
        '''INSERT INTO notifications (user_id, event_id, title, message, type)
           SELECT user_id, event_id, 'Event cancelled',
             'This event has been cancelled. Please review your dashboard for updated information.',
             'event_cancelled'
           FROM event_registrations WHERE event_id = ? AND status = 'confirmed' ''',
        [id],
      );
      await txn.rawUpdate(
        "UPDATE event_registrations SET status = 'cancelled' WHERE event_id = ? AND status = 'confirmed'",
        [id],
      );
    });
    return const _Res(200, {
      'message': 'Event cancelled and registered volunteers notified',
    });
  }

  Future<_Res> _registerForEvent(Database db, _Json user, int id, _Json b) async {
    if (user['role'] != 'Volunteer') {
      throw const _Abort(403, 'Only Volunteers can register for events');
    }
    final uid = user['id'] as int;
    final location = _s(b['selected_location']);
    if (location.isEmpty || location.length > 255) {
      throw const _Abort(400, 'A valid event and preferred location are required');
    }
    final regId = await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT id, date, start_time, status, registration_deadline, volunteers_needed FROM events WHERE id = ?',
        [id],
      );
      if (rows.isEmpty) throw const _Abort(404, 'Event not found');
      final e = rows.first;
      final s = _start(_s(e['date']).substring(0, 10), e['start_time'] as String?);
      if (e['status'] != 'published' || s == null || s.isBefore(DateTime.now().toUtc())) {
        throw const _Abort(409, 'This event is not available for registration');
      }
      final deadline = e['registration_deadline'];
      if (deadline != null && _s(deadline).substring(0, 10).compareTo(_today()) < 0) {
        throw const _Abort(409, 'The registration deadline has passed');
      }
      final dup = await txn.rawQuery(
        'SELECT id FROM event_registrations WHERE event_id = ? AND user_id = ?',
        [id, uid],
      );
      if (dup.isNotEmpty) {
        throw const _Abort(409, 'You are already registered for this event');
      }
      if (e['volunteers_needed'] != null) {
        final c = await txn.rawQuery(
          "SELECT COUNT(*) AS n FROM event_registrations WHERE event_id = ? AND status = 'confirmed'",
          [id],
        );
        if ((c.first['n'] as int) >= (e['volunteers_needed'] as int)) {
          throw const _Abort(409, 'This event has no remaining volunteer places');
        }
      }
      final rid = await txn.rawInsert(
        "INSERT INTO event_registrations (event_id, user_id, selected_location, status) VALUES (?, ?, ?, 'confirmed')",
        [id, uid, location],
      );
      await _history(txn, id, uid, 'registration', 'created', {'selected_location': location});
      await _notify(
        txn, uid, id, 'Registration confirmed',
        'Your event registration is confirmed. Open the event to see current schedule and Head Volunteer contact details.',
        'registration_confirmed',
      );
      return rid;
    });
    return _Res(201, {
      'message': 'Event registration confirmed',
      'registrationId': regId,
      'status': 'confirmed',
    });
  }

  Future<_Res> _userEvents(Database db, int uid, int userId) async {
    if (uid != userId) {
      throw const _Abort(403, 'You can only view your own event registrations');
    }
    return _Res(
      200,
      await db.rawQuery(
        '''SELECT er.id AS registration_id, er.selected_location,
                er.status AS registration_status, er.created_at AS registered_at,
                e.id AS event_id, e.name AS event_name, e.date, e.start_time,
                e.end_time, e.location, e.area, e.status AS event_status,
                e.image_url, head.name AS head_volunteer_name,
                head.email AS head_volunteer_email,
                COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone
         FROM event_registrations er JOIN events e ON e.id = er.event_id
         LEFT JOIN users head ON head.id = e.responsible_head_id
         WHERE er.user_id = ? ORDER BY e.date ASC''',
        [userId],
      ),
    );
  }

  Future<_Res> _notifications(Database db, int uid) async => _Res(
    200,
    await db.rawQuery(
      '''SELECT id, event_id, title, message, type, read_at, created_at
         FROM notifications WHERE user_id = ? ORDER BY created_at DESC, id DESC''',
      [uid],
    ),
  );

  Future<_Res> _readNotification(Database db, int uid, int id) async {
    final n = await db.rawUpdate(
      'UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ?',
      [_now(), id, uid],
    );
    if (n == 0) throw const _Abort(404, 'Notification not found');
    return const _Res(200, {'message': 'Notification marked as read'});
  }

  // ----------------------------------------------------------
  // tasks and enrollments
  // ----------------------------------------------------------

  Future<_Res> _tasksFor(Database db, int eventId, int uid) async {
    return _Res(
      200,
      await db.rawQuery(
        '''SELECT t.id, t.event_id, t.task_name, t.description, t.date, t.start_time,
               t.end_time, t.location, t.instructions, t.volunteers_required,
               t.compensation_type, t.compensation_amount, t.compensation_currency,
               t.compensation_terms, t.additional_requirements, t.status,
               (SELECT COUNT(*) FROM enrollments a WHERE a.task_id = t.id AND a.status = 'approved') AS accepted_count,
               (SELECT COUNT(*) FROM enrollments p WHERE p.task_id = t.id AND p.status = 'pending') AS pending_count,
               CASE WHEN t.volunteers_required IS NULL THEN NULL
                    WHEN t.volunteers_required - (SELECT COUNT(*) FROM enrollments o WHERE o.task_id = t.id AND o.status IN ('pending','approved')) < 0 THEN 0
                    ELSE t.volunteers_required - (SELECT COUNT(*) FROM enrollments o WHERE o.task_id = t.id AND o.status IN ('pending','approved')) END AS remaining_places,
               e.responsible_head_id, head.name AS head_volunteer_name,
               head.email AS head_volunteer_email,
               COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone
        FROM tasks t JOIN events e ON e.id = t.event_id
        LEFT JOIN users head ON head.id = e.responsible_head_id
        WHERE t.event_id = ? AND (e.status = 'published' OR e.created_by = ? OR e.responsible_head_id = ?)
        ORDER BY t.date ASC, t.start_time ASC''',
        [eventId, uid, uid],
      ),
    );
  }

  Map<String, Object?> _compensation(_Json b, [Map<String, Object?>? old]) {
    final type = b['compensation_type'] == null
        ? _s(old?['compensation_type'] ?? 'unpaid')
        : _s(b['compensation_type']);
    final rawAmount = b.containsKey('compensation_amount')
        ? b['compensation_amount']
        : old?['compensation_amount'];
    final amount = (rawAmount == null || _s(rawAmount).isEmpty)
        ? null
        : double.tryParse(_s(rawAmount));
    final currency = _s(
      b['compensation_currency'] ?? old?['compensation_currency'] ?? 'INR',
    ).toUpperCase();
    final terms = b.containsKey('compensation_terms')
        ? _sn(b['compensation_terms'])
        : _sn(old?['compensation_terms']);
    final reqs = b.containsKey('additional_requirements')
        ? _sn(b['additional_requirements'])
        : _sn(old?['additional_requirements']);
    if (!['unpaid', 'fixed', 'hourly'].contains(type)) {
      throw const _Abort(400, 'Compensation type must be unpaid, fixed, or hourly');
    }
    if (type == 'unpaid' && amount != null) {
      throw const _Abort(400, 'Unpaid tasks cannot have a compensation amount');
    }
    if (type != 'unpaid' && (amount == null || amount < 0 || amount > 99999999.99)) {
      throw const _Abort(400, 'Paid tasks require a valid non-negative compensation amount');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const _Abort(400, 'Currency must be a 3-letter code');
    }
    if ((terms?.length ?? 0) > 2000 || (reqs?.length ?? 0) > 2000) {
      throw const _Abort(
        400,
        'Compensation terms and requirements must be 2000 characters or fewer',
      );
    }
    return {
      'type': type,
      'amount': type == 'unpaid' ? null : amount,
      'currency': currency,
      'terms': terms,
      'requirements': reqs,
    };
  }

  Future<_Res> _createTask(Database db, _Json user, _Json b) async {
    final eventId = _int(b['event_id']);
    final name = _s(b['task_name']);
    final description = _s(b['description']);
    final date = _s(b['date']);
    final start = _s(b['start_time']);
    final end = _s(b['end_time']);
    final location = _s(b['location']);
    final hasLimit =
        b['volunteers_required'] != null && _s(b['volunteers_required']).isNotEmpty;
    final limit = hasLimit ? _int(b['volunteers_required']) : null;
    if (eventId == null || name.isEmpty || description.isEmpty || date.isEmpty ||
        start.isEmpty || end.isEmpty || location.isEmpty) {
      throw const _Abort(
        400,
        'Event, task name, description, date, times and location are required',
      );
    }
    if (description.length > 2000 || _s(b['instructions']).length > 2000) {
      throw const _Abort(
        400,
        'Task description and instructions must be 2000 characters or fewer',
      );
    }
    if (name.length > 200 || location.length > 255 || !_validDate(date) ||
        !_timeSecRe.hasMatch(start) || !_timeSecRe.hasMatch(end) ||
        start.compareTo(end) >= 0) {
      throw const _Abort(400, 'Enter valid task details and a later end time');
    }
    if (!hasLimit || limit == null || limit <= 0) {
      throw const _Abort(400, 'Volunteers required must be a positive whole number');
    }
    final comp = _compensation(b);
    final events = await db.rawQuery(
      'SELECT id, location, status FROM events WHERE id = ?',
      [eventId],
    );
    if (events.isEmpty) throw const _Abort(400, 'Event does not exist');
    if (events.first['status'] == 'cancelled' || events.first['status'] == 'completed') {
      throw const _Abort(409, 'Tasks cannot be added to a cancelled or completed event');
    }
    await _manage(
      db, eventId, user['id'] as int,
      'You can only add tasks to events assigned to you or created by you',
    );
    final status = _s(b['status'] ?? 'Open');
    if (!_taskStatuses.contains(status)) {
      throw const _Abort(400, 'Enter a valid task status');
    }
    final id = await db.rawInsert(
      '''INSERT INTO tasks (event_id, task_name, description, date, start_time, end_time,
           location, instructions, volunteers_required, status, location_is_independent,
           compensation_type, compensation_amount, compensation_currency,
           compensation_terms, additional_requirements)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        eventId, name, description, date, start, end, location,
        _sn(b['instructions']), limit, status,
        location == events.first['location'] ? 0 : 1,
        comp['type'], comp['amount'], comp['currency'], comp['terms'],
        comp['requirements'],
      ],
    );
    await _history(db, eventId, user['id'] as int, 'task', 'created', {
      'task_id': id, 'task_name': name, 'status': status,
    });
    return _Res(201, {
      'message': 'Task created successfully',
      'taskId': id,
      'status': status,
    });
  }

  Future<_Res> _updateTask(Database db, _Json user, int id, _Json b) async {
    final rows = await db.rawQuery(
      '''SELECT t.*, e.location AS event_location FROM tasks t
         JOIN events e ON e.id = t.event_id WHERE t.id = ?''',
      [id],
    );
    if (rows.isEmpty) throw const _Abort(404, 'Task not found');
    final task = _row(rows.first);
    final eventId = task['event_id'] as int;
    final uid = user['id'] as int;
    await _manage(
      db, eventId, uid,
      'You can only manage tasks for events assigned to you or created by you',
    );
    final name = b['task_name'] == null ? task['task_name'] as String : _s(b['task_name']);
    final date = b['date'] == null ? _s(task['date']).substring(0, 10) : _s(b['date']);
    final start = b['start_time'] == null ? task['start_time'] as String : _s(b['start_time']);
    final end = b['end_time'] == null ? task['end_time'] as String : _s(b['end_time']);
    final location = b['location'] == null ? task['location'] as String : _s(b['location']);
    final status = b['status'] == null ? task['status'] as String : _s(b['status']);
    final description = b.containsKey('description')
        ? _s(b['description'])
        : _s(task['description']);
    if (name.isEmpty || name.length > 200 || description.isEmpty ||
        description.length > 2000 || location.isEmpty || location.length > 255 ||
        !_validDate(date) || !_timeRe.hasMatch(start) || !_timeRe.hasMatch(end) ||
        start.compareTo(end) >= 0 || !_taskStatuses.contains(status)) {
      throw const _Abort(400, 'Enter valid task details and status');
    }
    final limit = !b.containsKey('volunteers_required')
        ? task['volunteers_required'] as int?
        : (b['volunteers_required'] == null || _s(b['volunteers_required']).isEmpty)
            ? null
            : _int(b['volunteers_required']);
    if (limit == null || limit <= 0) {
      throw const _Abort(400, 'Volunteers required must be a positive whole number');
    }
    final instructions = b.containsKey('instructions')
        ? _s(b['instructions'])
        : _s(task['instructions']);
    if (instructions.length > 2000) {
      throw const _Abort(400, 'Task instructions must be 2000 characters or fewer');
    }
    final comp = _compensation(b, task);
    final c = await db.rawQuery(
      "SELECT COUNT(*) AS n FROM enrollments WHERE task_id = ? AND status IN ('pending','approved')",
      [id],
    );
    if ((c.first['n'] as int) > limit) {
      throw const _Abort(
        409,
        'Volunteer limit cannot be lower than the number already enrolled',
      );
    }
    await db.transaction((txn) async {
      await txn.rawUpdate(
        '''UPDATE tasks SET task_name = ?, description = ?, date = ?, start_time = ?,
             end_time = ?, location = ?, instructions = ?, volunteers_required = ?,
             status = ?, location_is_independent = ?, compensation_type = ?,
             compensation_amount = ?, compensation_currency = ?,
             compensation_terms = ?, additional_requirements = ? WHERE id = ?''',
        [
          name, description, date, start, end, location,
          instructions.isEmpty ? null : instructions, limit, status,
          location == task['event_location'] ? 0 : 1, comp['type'],
          comp['amount'], comp['currency'], comp['terms'], comp['requirements'], id,
        ],
      );
      await _history(txn, eventId, uid, 'task', 'updated', {
        'task_id': id, 'task_name': name, 'status': status,
      });
      final cancelled = status == 'Cancelled';
      await txn.rawInsert(
        '''INSERT INTO notifications (user_id, event_id, title, message, type)
           SELECT user_id, ?, ?, ?, ? FROM enrollments
           WHERE task_id = ? AND status IN ('pending','approved')''',
        [
          eventId,
          cancelled ? 'Task cancelled' : 'Task updated',
          cancelled
              ? 'The task "$name" has been cancelled.'
              : 'The task "$name" was updated. Open My Tasks to see the latest schedule and instructions.',
          cancelled ? 'task_cancelled' : 'task_updated',
          id,
        ],
      );
    });
    return _Res(200, {'message': 'Task updated', 'taskId': id, 'status': status});
  }

  Future<_Res> _enroll(Database db, int uid, _Json b) async {
    final taskId = _int(b['task_id']);
    if (taskId == null || taskId <= 0) {
      throw const _Abort(400, 'A valid task_id is required');
    }
    if (b['user_id'] != null && _int(b['user_id']) != uid) {
      throw const _Abort(403, 'You cannot enroll another user');
    }
    final enrollmentId = await db.transaction((txn) async {
      final tasks = await txn.rawQuery(
        '''SELECT t.id, t.event_id, t.volunteers_required, t.status AS task_status,
                  e.status AS event_status, t.date AS task_date, t.start_time,
                  COALESCE(e.responsible_head_id, e.created_by) AS manager_id
           FROM tasks t JOIN events e ON e.id = t.event_id WHERE t.id = ?''',
        [taskId],
      );
      if (tasks.isEmpty) throw const _Abort(404, 'Task does not exist');
      final t = tasks.first;
      final s = _start(_s(t['task_date']).substring(0, 10), t['start_time'] as String?);
      if (t['event_status'] != 'published' ||
          !['Open', 'Assigned'].contains(t['task_status']) ||
          s == null ||
          s.isBefore(DateTime.now().toUtc())) {
        throw const _Abort(409, 'This task is not available for enrollment');
      }
      final existing = await txn.rawQuery(
        'SELECT id, status FROM enrollments WHERE user_id = ? AND task_id = ?',
        [uid, taskId],
      );
      if (existing.isNotEmpty && existing.first['status'] != 'rejected') {
        throw const _Abort(409, 'You are already enrolled in this task');
      }
      final capacity = t['volunteers_required'] as int?;
      if (capacity != null) {
        final c = await txn.rawQuery(
          "SELECT COUNT(*) AS n FROM enrollments WHERE task_id = ? AND status IN ('pending','approved')",
          [taskId],
        );
        if ((c.first['n'] as int) >= capacity) {
          throw const _Abort(409, 'This task has no remaining volunteer places');
        }
      }
      int id;
      if (existing.isNotEmpty) {
        id = existing.first['id'] as int;
        await txn.rawUpdate(
          "UPDATE enrollments SET status = 'pending', created_at = CURRENT_TIMESTAMP WHERE id = ?",
          [id],
        );
      } else {
        id = await txn.rawInsert(
          "INSERT INTO enrollments (user_id, task_id, status) VALUES (?, ?, 'pending')",
          [uid, taskId],
        );
      }
      final manager = t['manager_id'] as int?;
      if (manager != null && manager > 0 && manager != uid) {
        await _notify(
          txn, manager, t['event_id'] as int, 'New task enrollment request',
          'A volunteer requested to join task #$taskId. Review the request in your event dashboard.',
          'task_enrollment_request',
        );
      }
      return id;
    });
    return _Res(201, {
      'message': 'Enrollment submitted',
      'enrollmentId': enrollmentId,
      'status': 'pending',
    });
  }

  Future<_Res> _userTasks(Database db, int uid, int userId) async {
    if (uid != userId) {
      throw const _Abort(403, 'You cannot view another user\'s tasks');
    }
    return _Res(
      200,
      await db.rawQuery(
        '''SELECT e.id AS event_id, e.name AS event_name, t.id AS task_id, t.task_name,
                t.date, t.start_time, t.end_time, t.location, t.instructions,
                t.description, t.status AS task_status, e.status AS event_status,
                e.area, e.address, e.meeting_point, e.reporting_instructions,
                e.image_url, e.contact_phone, er.selected_location,
                head.name AS head_volunteer_name, head.email AS head_volunteer_email,
                COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone,
                en.id AS enrollment_id, en.status
         FROM enrollments en JOIN tasks t ON en.task_id = t.id
         JOIN events e ON t.event_id = e.id
         LEFT JOIN users head ON head.id = e.responsible_head_id
         LEFT JOIN event_registrations er ON er.event_id = e.id AND er.user_id = en.user_id
         WHERE en.user_id = ? ORDER BY t.date ASC, t.start_time ASC''',
        [userId],
      ),
    );
  }

  Future<_Res> _taskVolunteers(Database db, _Json user, int taskId) async {
    final t = await db.rawQuery('SELECT event_id FROM tasks WHERE id = ?', [taskId]);
    if (t.isEmpty) throw const _Abort(404, 'Task not found');
    await _manage(
      db, t.first['event_id'] as int, user['id'] as int,
      'You cannot manage volunteers for this task',
    );
    return _Res(
      200,
      await db.rawQuery(
        '''SELECT en.id AS enrollment_id, u.id AS user_id, u.name, u.email, u.student_id,
                t.task_name, t.date, e.name AS event_name, e.responsible_head_id,
                head.name AS head_volunteer_name, head.email AS head_volunteer_email,
                COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone, en.status
         FROM enrollments en JOIN users u ON en.user_id = u.id
         JOIN tasks t ON en.task_id = t.id JOIN events e ON e.id = t.event_id
         LEFT JOIN users head ON head.id = e.responsible_head_id
         WHERE en.task_id = ? ORDER BY en.status ASC, en.id DESC''',
        [taskId],
      ),
    );
  }

  Future<_Res> _enrollments(Database db, _Json user, Map<String, String> q) async {
    final params = <Object?>[user['role'], user['id'], user['id']];
    var sql = '''SELECT en.id AS enrollment_id, u.id AS user_id, u.name, u.email,
              u.student_id, t.id AS task_id, t.task_name, e.id AS event_id,
              e.name AS event_name, e.responsible_head_id,
              head.name AS head_volunteer_name, en.status
       FROM enrollments en JOIN users u ON en.user_id = u.id
       JOIN tasks t ON en.task_id = t.id JOIN events e ON t.event_id = e.id
       LEFT JOIN users head ON head.id = e.responsible_head_id
       WHERE (? = 'Administrator' OR e.created_by = ? OR e.responsible_head_id = ?)''';
    if ((q['status'] ?? '').isNotEmpty) {
      sql += ' AND en.status = ?';
      params.add(q['status']);
    }
    sql += ' ORDER BY en.id DESC';
    return _Res(200, await db.rawQuery(sql, params));
  }

  Future<_Res> _enrollmentStatus(Database db, _Json user, int id, _Json b) async {
    final status = _s(b['status']);
    if (!['pending', 'approved', 'rejected'].contains(status)) {
      throw const _Abort(400, 'Status must be one of: pending, approved, rejected');
    }
    final rows = await db.rawQuery(
      '''SELECT en.id, en.user_id, t.event_id, t.task_name FROM enrollments en
         JOIN tasks t ON t.id = en.task_id WHERE en.id = ?''',
      [id],
    );
    if (rows.isEmpty) throw const _Abort(404, 'Enrollment not found');
    final en = rows.first;
    await _manage(
      db, en['event_id'] as int, user['id'] as int,
      'You cannot update enrollments for this event',
    );
    await db.transaction((txn) async {
      await txn.rawUpdate('UPDATE enrollments SET status = ? WHERE id = ?', [status, id]);
      await _notify(
        txn, en['user_id'] as int, en['event_id'] as int,
        status == 'approved' ? 'Task enrollment confirmed' : 'Task enrollment updated',
        status == 'approved'
            ? 'Your enrollment for "${en['task_name']}" was confirmed.'
            : 'Your enrollment for "${en['task_name']}" is now $status.',
        'registration_updated',
      );
    });
    return _Res(200, {'message': 'Enrollment $status', 'enrollmentId': id});
  }

  // ----------------------------------------------------------
  // announcements and help requests
  // ----------------------------------------------------------

  Future<_Res> _announcements(Database db) async => _Res(
    200,
    await db.rawQuery(
      '''SELECT a.id, a.event_id, e.name AS event_name, a.title, a.message, a.created_at
         FROM announcements a JOIN events e ON a.event_id = e.id
         WHERE e.status = 'published' ORDER BY a.created_at DESC, a.id DESC''',
    ),
  );

  Future<_Res> _eventAnnouncements(Database db, int eventId) async => _Res(
    200,
    await db.rawQuery(
      '''SELECT id, event_id, title, message, created_at FROM announcements
         WHERE event_id = ? AND EXISTS (SELECT 1 FROM events
           WHERE events.id = announcements.event_id AND events.status = 'published')
         ORDER BY created_at DESC, id DESC''',
      [eventId],
    ),
  );

  Future<_Res> _createAnnouncement(Database db, _Json user, _Json b) async {
    final eventId = _int(b['event_id']);
    final title = _s(b['title']);
    final message = _s(b['message']);
    if (eventId == null || title.isEmpty || message.isEmpty) {
      throw const _Abort(400, 'event_id, title and message are required');
    }
    final e = await db.rawQuery('SELECT id FROM events WHERE id = ?', [eventId]);
    if (e.isEmpty) throw const _Abort(400, 'Event does not exist');
    await _manage(
      db, eventId, user['id'] as int,
      'You can only announce events assigned to you or created by you',
    );
    final id = await db.rawInsert(
      'INSERT INTO announcements (event_id, title, message) VALUES (?, ?, ?)',
      [eventId, title, message],
    );
    return _Res(201, {'message': 'Announcement published', 'announcementId': id});
  }

  Future<_Res> _submitHelp(Database db, int uid, _Json b) async {
    final eventId = _int(b['event_id']);
    final message = _s(b['message']);
    if (eventId == null || message.isEmpty) {
      throw const _Abort(400, 'event_id and message are required');
    }
    if (b['user_id'] != null && _int(b['user_id']) != uid) {
      throw const _Abort(403, 'You cannot submit a request for another user');
    }
    final e = await db.rawQuery('SELECT id FROM events WHERE id = ?', [eventId]);
    if (e.isEmpty) throw const _Abort(400, 'Event does not exist');
    final id = await db.rawInsert(
      "INSERT INTO help_requests (user_id, event_id, message, status) VALUES (?, ?, ?, 'open')",
      [uid, eventId, message],
    );
    return _Res(201, {'message': 'Help request sent', 'requestId': id});
  }

  Future<_Res> _helpRequests(Database db, _Json user, Map<String, String> q) async {
    final params = <Object?>[user['role'], user['id'], user['id']];
    var sql = '''SELECT hr.id, u.id AS user_id, u.name, u.email, u.student_id,
              e.id AS event_id, e.name AS event_name, e.responsible_head_id,
              hr.message, hr.status, hr.created_at
       FROM help_requests hr JOIN users u ON hr.user_id = u.id
       JOIN events e ON hr.event_id = e.id
       WHERE (? = 'Administrator' OR e.created_by = ? OR e.responsible_head_id = ?)''';
    if ((q['status'] ?? '').isNotEmpty) {
      sql += ' AND hr.status = ?';
      params.add(q['status']);
    }
    sql += ' ORDER BY hr.created_at DESC, hr.id DESC';
    return _Res(200, await db.rawQuery(sql, params));
  }

  Future<_Res> _helpStatus(Database db, _Json user, int id, _Json b) async {
    final status = _s(b['status']);
    if (!['open', 'resolved'].contains(status)) {
      throw const _Abort(400, 'Status must be one of: open, resolved');
    }
    final rows = await db.rawQuery(
      'SELECT event_id FROM help_requests WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) throw const _Abort(404, 'Help request not found');
    await _manage(
      db, rows.first['event_id'] as int, user['id'] as int,
      'You cannot update help requests for this event',
    );
    await db.rawUpdate('UPDATE help_requests SET status = ? WHERE id = ?', [status, id]);
    return _Res(200, {'message': 'Help request $status', 'requestId': id});
  }
}
