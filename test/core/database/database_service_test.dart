import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lending_nelson/core/database/database_service.dart';

void main() {
  // Initialize FFI for local machine testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseService Tests', () {
    late DatabaseService databaseService;

    setUp(() {
      databaseService = DatabaseService(dbPath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await databaseService.close();
    });

    test('should initialize and create tables successfully', () async {
      final db = await databaseService.database;
      expect(db.isOpen, isTrue);

      // Verify that tables are created by checking the sqlite_master schema
      final tablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );

      final tableNames = tablesResult
          .map((row) => row['name'] as String)
          .toList();

      expect(tableNames, contains('borrowers'));
      expect(tableNames, contains('audit_logs'));
      expect(tableNames, contains('offline_sync_queue'));
    });

    test('reopens transparently when the cached database handle was closed',
        () async {
      final first = await databaseService.database;
      await first.close();

      final reopened = await databaseService.database;

      expect(reopened.isOpen, isTrue);
      final tables = await reopened.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      expect(tables.map((row) => row['name']), contains('loans'));
    });

    test('closing another service does not close this service connection',
        () async {
      final otherService = DatabaseService(dbPath: inMemoryDatabasePath);
      final foregroundDb = await databaseService.database;
      await otherService.database;

      await otherService.close();

      expect(foregroundDb.isOpen, isTrue);
      final tables = await foregroundDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      expect(tables.map((row) => row['name']), contains('loans'));
    });

    test('should allow operations on borrowers table', () async {
      final db = await databaseService.database;

      final mockBorrower = {
        'id': 'test-uuid-borrower-1',
        'first_name': 'Jane',
        'last_name': 'Smith',
        'national_id': 'encrypted-national-id-here',
        'phone': 'encrypted-phone-here',
        'date_of_birth': '1995-10-10T00:00:00.000Z',
        'status': 'Pending',
        'created_at': '2026-07-18T23:00:00.000Z',
      };

      // Insert record
      final insertId = await db.insert('borrowers', mockBorrower);
      expect(insertId, isNot(-1));

      // Query record
      final results = await db.query(
        'borrowers',
        where: 'id = ?',
        whereArgs: ['test-uuid-borrower-1'],
      );

      expect(results.length, 1);
      expect(results.first['first_name'], 'Jane');
      expect(results.first['status'], 'Pending');
    });

    test('should allow operations on audit_logs table', () async {
      final db = await databaseService.database;

      final mockAuditLog = {
        'id': 'test-uuid-audit-1',
        'user_id': 'test-uuid-officer-1',
        'action': 'CREATE',
        'entity_name': 'borrowers',
        'entity_id': 'test-uuid-borrower-1',
        'timestamp': '2026-07-18T23:00:05.000Z',
        'old_state_json': null,
        'new_state_json': '{"first_name": "Jane"}',
      };

      // Insert record
      final insertId = await db.insert('audit_logs', mockAuditLog);
      expect(insertId, isNot(-1));

      // Query record
      final results = await db.query(
        'audit_logs',
        where: 'id = ?',
        whereArgs: ['test-uuid-audit-1'],
      );

      expect(results.length, 1);
      expect(results.first['action'], 'CREATE');
      expect(results.first['new_state_json'], '{"first_name": "Jane"}');
    });

    test('should allow operations on offline_sync_queue table', () async {
      final db = await databaseService.database;

      final mockSyncTask = {
        'id': 'test-uuid-sync-1',
        'transaction_uuid': 'tx-uuid-12345',
        'endpoint': '/api/borrowers',
        'method': 'POST',
        'payload_json': '{"firstName": "Jane"}',
        'created_at': '2026-07-18T23:00:10.000Z',
      };

      // Insert record
      final insertId = await db.insert('offline_sync_queue', mockSyncTask);
      expect(insertId, isNot(-1));

      // Query record
      final results = await db.query(
        'offline_sync_queue',
        where: 'transaction_uuid = ?',
        whereArgs: ['tx-uuid-12345'],
      );

      expect(results.length, 1);
      expect(results.first['endpoint'], '/api/borrowers');
      expect(results.first['method'], 'POST');
    });
  });
}
