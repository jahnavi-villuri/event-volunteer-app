import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_factory.dart';

/// Local SQLite Database Service
///
/// Provides local caching, bookmarking, and offline persistence
/// on supported platforms (Android, iOS, Windows, macOS, Linux, and tests).
/// Gracefully falls back to memory cache on Flutter Web where native SQLite is not available.
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  static const String _dbName = 'volunteer_app_local.db';
  static const int _dbVersion = 1;

  Database? _db;
  final Map<String, dynamic> _webMemoryStore = {};

  bool get isInitialized => _db != null || kIsWeb;

  /// Initializes the SQLite database.
  Future<void> initialize() async {
    if (isInitialized) return;

    if (kIsWeb) {
      debugPrint(
        '[LocalDatabaseService] Running on Web - using local in-memory fallback.',
      );
      return;
    }

    try {
      _db = await openAppDatabase(
        _dbName,
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await db.transaction((txn) async {
            // Cached events from backend for offline viewing
            await txn.execute('''
              CREATE TABLE cached_events (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                date TEXT NOT NULL,
                location TEXT NOT NULL,
                description TEXT,
                volunteers_needed INTEGER,
                cached_at TEXT DEFAULT CURRENT_TIMESTAMP
              );
            ''');

            // Cached tasks for events
            await txn.execute('''
              CREATE TABLE cached_tasks (
                id INTEGER PRIMARY KEY,
                event_id INTEGER NOT NULL,
                task_name TEXT NOT NULL,
                date TEXT NOT NULL,
                start_time TEXT NOT NULL,
                end_time TEXT NOT NULL,
                location TEXT NOT NULL,
                instructions TEXT,
                volunteers_required INTEGER,
                FOREIGN KEY (event_id) REFERENCES cached_events(id) ON DELETE CASCADE
              );
            ''');

            // User bookmarks / saved events
            await txn.execute('''
              CREATE TABLE saved_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                event_id INTEGER NOT NULL,
                notes TEXT,
                saved_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, event_id)
              );
            ''');

            // Cached announcements
            await txn.execute('''
              CREATE TABLE cached_announcements (
                id INTEGER PRIMARY KEY,
                event_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                created_at TEXT
              );
            ''');

            // Metadata & preferences
            await txn.execute('''
              CREATE TABLE app_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              );
            ''');

            await txn.execute(
              'CREATE INDEX idx_cached_events_date ON cached_events(date);',
            );
            await txn.execute(
              'CREATE INDEX idx_cached_tasks_event_id ON cached_tasks(event_id);',
            );
            await txn.execute(
              'CREATE INDEX idx_saved_events_user_id ON saved_events(user_id);',
            );
          });
        },
      );
      debugPrint(
        '[LocalDatabaseService] SQLite initialized successfully at ${_db!.path}',
      );
    } catch (e, stack) {
      debugPrint(
        '[LocalDatabaseService] SQLite initialization warning: $e\n$stack',
      );
    }
  }

  // ============================================================
  // CACHED EVENTS
  // ============================================================

  Future<void> cacheEvents(List<dynamic> events) async {
    await initialize();
    if (kIsWeb || _db == null) {
      _webMemoryStore['events'] = events;
      return;
    }

    final db = _db!;
    await db.transaction((txn) async {
      await txn.delete('cached_events');
      final batch = txn.batch();
      for (final raw in events) {
        if (raw is Map) {
          final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
          if (id > 0) {
            batch.insert('cached_events', {
              'id': id,
              'name': raw['name']?.toString() ?? '',
              'date': raw['date']?.toString() ?? '',
              'location': raw['location']?.toString() ?? '',
              'description': raw['description']?.toString(),
              'volunteers_needed':
                  int.tryParse(raw['volunteers_needed']?.toString() ?? '') ?? 0,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> getCachedEvents() async {
    await initialize();
    if (kIsWeb || _db == null) {
      final list = _webMemoryStore['events'];
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }

    final rows = await _db!.query('cached_events', orderBy: 'date ASC');
    return rows;
  }

  // ============================================================
  // CACHED TASKS
  // ============================================================

  Future<void> cacheTasks(int eventId, List<dynamic> tasks) async {
    await initialize();
    if (kIsWeb || _db == null) {
      _webMemoryStore['tasks_$eventId'] = tasks;
      return;
    }

    final db = _db!;
    await db.transaction((txn) async {
      await txn.delete(
        'cached_tasks',
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      final batch = txn.batch();
      for (final raw in tasks) {
        if (raw is Map) {
          final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
          if (id > 0) {
            batch.insert('cached_tasks', {
              'id': id,
              'event_id': eventId,
              'task_name': raw['task_name']?.toString() ?? '',
              'date': raw['date']?.toString() ?? '',
              'start_time': raw['start_time']?.toString() ?? '',
              'end_time': raw['end_time']?.toString() ?? '',
              'location': raw['location']?.toString() ?? '',
              'instructions': raw['instructions']?.toString(),
              'volunteers_required':
                  int.tryParse(raw['volunteers_required']?.toString() ?? '') ??
                  0,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> getCachedTasks(int eventId) async {
    await initialize();
    if (kIsWeb || _db == null) {
      final list = _webMemoryStore['tasks_$eventId'];
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }

    final rows = await _db!.query(
      'cached_tasks',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'start_time ASC',
    );
    return rows;
  }

  // ============================================================
  // SAVED EVENTS (BOOKMARKS)
  // ============================================================

  Future<void> saveEvent(int userId, int eventId, {String? notes}) async {
    await initialize();
    if (kIsWeb || _db == null) {
      final set = (_webMemoryStore['saved_$userId'] as Set<int>?) ?? <int>{};
      set.add(eventId);
      _webMemoryStore['saved_$userId'] = set;
      return;
    }

    await _db!.insert('saved_events', {
      'user_id': userId,
      'event_id': eventId,
      'notes': notes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> unsaveEvent(int userId, int eventId) async {
    await initialize();
    if (kIsWeb || _db == null) {
      final set = (_webMemoryStore['saved_$userId'] as Set<int>?);
      set?.remove(eventId);
      return;
    }

    await _db!.delete(
      'saved_events',
      where: 'user_id = ? AND event_id = ?',
      whereArgs: [userId, eventId],
    );
  }

  Future<bool> isEventSaved(int userId, int eventId) async {
    await initialize();
    if (kIsWeb || _db == null) {
      final set = (_webMemoryStore['saved_$userId'] as Set<int>?);
      return set?.contains(eventId) ?? false;
    }

    final rows = await _db!.query(
      'saved_events',
      where: 'user_id = ? AND event_id = ?',
      whereArgs: [userId, eventId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<int>> getSavedEventIds(int userId) async {
    await initialize();
    if (kIsWeb || _db == null) {
      final set = (_webMemoryStore['saved_$userId'] as Set<int>?);
      return set?.toList() ?? [];
    }

    final rows = await _db!.query(
      'saved_events',
      columns: ['event_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((r) => r['event_id'] as int).toList();
  }

  // ============================================================
  // CACHED ANNOUNCEMENTS
  // ============================================================

  Future<void> cacheAnnouncements(List<dynamic> announcements) async {
    await initialize();
    if (kIsWeb || _db == null) {
      _webMemoryStore['announcements'] = announcements;
      return;
    }

    final db = _db!;
    await db.transaction((txn) async {
      await txn.delete('cached_announcements');
      final batch = txn.batch();
      for (final raw in announcements) {
        if (raw is Map) {
          final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
          if (id > 0) {
            batch.insert('cached_announcements', {
              'id': id,
              'event_id': int.tryParse(raw['event_id']?.toString() ?? '') ?? 0,
              'title': raw['title']?.toString() ?? '',
              'message': raw['message']?.toString() ?? '',
              'created_at': raw['created_at']?.toString(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> getCachedAnnouncements() async {
    await initialize();
    if (kIsWeb || _db == null) {
      final list = _webMemoryStore['announcements'];
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }

    final rows = await _db!.query('cached_announcements', orderBy: 'id DESC');
    return rows;
  }

  // ============================================================
  // METADATA
  // ============================================================

  Future<void> setMetadata(String key, String value) async {
    await initialize();
    if (kIsWeb || _db == null) {
      _webMemoryStore['meta_$key'] = value;
      return;
    }

    await _db!.insert('app_metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMetadata(String key) async {
    await initialize();
    if (kIsWeb || _db == null) {
      return _webMemoryStore['meta_$key'] as String?;
    }

    final rows = await _db!.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> clearAll() async {
    await initialize();
    if (kIsWeb || _db == null) {
      _webMemoryStore.clear();
      return;
    }
    final db = _db!;
    await db.transaction((txn) async {
      await txn.delete('cached_events');
      await txn.delete('cached_tasks');
      await txn.delete('saved_events');
      await txn.delete('cached_announcements');
      await txn.delete('app_metadata');
    });
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _webMemoryStore.clear();
  }
}
