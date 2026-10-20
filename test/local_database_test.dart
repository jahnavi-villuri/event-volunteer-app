import 'package:event_volunteer/services/local_database_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDatabaseService Tests', () {
    setUp(() async {
      await LocalDatabaseService.instance.initialize();
      await LocalDatabaseService.instance.clearAll();
    });

    test('initializes and executes cache operations without errors', () async {
      final localDb = LocalDatabaseService.instance;

      final sampleEvents = [
        {
          'id': 101,
          'name': 'Community Beach Cleanup',
          'location': 'Sunset Beach',
          'date': '2026-11-15',
          'description': 'Cleaning up plastics',
          'volunteers_needed': 25,
        },
        {
          'id': 102,
          'name': 'Food Bank Distribution',
          'location': 'Downtown Community Center',
          'date': '2026-11-20',
          'description': 'Sorting groceries',
          'volunteers_needed': 15,
        },
      ];

      // Cache events into SQLite
      await localDb.cacheEvents(sampleEvents);

      // Retrieve cached events
      final cached = await localDb.getCachedEvents();
      expect(cached.length, 2);
      expect(cached[0]['name'], 'Community Beach Cleanup');
      expect(cached[1]['name'], 'Food Bank Distribution');

      // Test event bookmarking in local SQLite
      const userId = 42;
      final isSavedInitial = await localDb.isEventSaved(userId, 101);
      expect(isSavedInitial, isFalse);

      await localDb.saveEvent(userId, 101, notes: 'Excited to attend');
      final isSavedAfter = await localDb.isEventSaved(userId, 101);
      expect(isSavedAfter, isTrue);

      final savedIds = await localDb.getSavedEventIds(userId);
      expect(savedIds.contains(101), isTrue);

      // Remove bookmark
      await localDb.unsaveEvent(userId, 101);
      final isSavedAfterRemove = await localDb.isEventSaved(userId, 101);
      expect(isSavedAfterRemove, isFalse);

      // Test metadata key-value storage
      await localDb.setMetadata('last_sync', '2026-10-20T00:00:00Z');
      final metaVal = await localDb.getMetadata('last_sync');
      expect(metaVal, '2026-10-20T00:00:00Z');

      // Clear all cache
      await localDb.clearAll();
      final emptyEvents = await localDb.getCachedEvents();
      expect(emptyEvents.isEmpty, isTrue);
    });
  });
}
