import 'dart:io';
import 'package:path/path.dart';
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

    test(
      'should initialize and create all required v11 tables successfully',
      () async {
        final db = await databaseService.database;
        expect(db.isOpen, isTrue);

        final tablesResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        );

        final tableNames = tablesResult
            .map((row) => row['name'] as String)
            .toSet();

        final expectedTables = [
          'borrowers',
          'loans',
          'loan_schedules',
          'repayments',
          'loan_payments',
          'guarantors',
          'emergency_contacts',
          'borrower_notes',
          'documents',
          'users',
          'audit_logs',
          'offline_sync_queue',
          'sync_conflicts',
          'sync_metadata',
          'local_json_cache',
          'borrower_communication_logs',
        ];

        for (final table in expectedTables) {
          expect(tableNames, contains(table), reason: 'Missing table: $table');
        }
      },
    );

    test(
      'reopens transparently when the cached database handle was closed',
      () async {
        final first = await databaseService.database;
        await first.close();

        final reopened = await databaseService.database;

        expect(reopened.isOpen, isTrue);
        final tables = await reopened.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        expect(tables.map((row) => row['name']), contains('loans'));
      },
    );

    test(
      'closing another service does not close this service connection',
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
      },
    );

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

      final insertId = await db.insert('borrowers', mockBorrower);
      expect(insertId, isNot(-1));

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

      final insertId = await db.insert('audit_logs', mockAuditLog);
      expect(insertId, isNot(-1));

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

      final insertId = await db.insert('offline_sync_queue', mockSyncTask);
      expect(insertId, isNot(-1));

      final results = await db.query(
        'offline_sync_queue',
        where: 'transaction_uuid = ?',
        whereArgs: ['tx-uuid-12345'],
      );

      expect(results.length, 1);
      expect(results.first['endpoint'], '/api/borrowers');
      expect(results.first['method'], 'POST');
    });

    test(
      'enforces foreign key constraints (ON DELETE CASCADE and ON DELETE SET NULL)',
      () async {
        final db = await databaseService.database;
        await db.execute('PRAGMA foreign_keys = ON');

        await db.insert('borrowers', {
          'id': 'b-fk-1',
          'first_name': 'FK',
          'last_name': 'Tester',
          'national_id': 'enc_nat_id',
          'phone': 'enc_phone',
          'date_of_birth': '1990-01-01',
          'status': 'Active',
          'created_at': '2026-07-31T00:00:00Z',
        });

        await db.insert('loans', {
          'id': 'loan-fk-1',
          'borrower_id': 'b-fk-1',
          'original_principal': '1000.00',
          'monthly_rate': '0.05',
          'created_at': '2026-07-31T00:00:00Z',
        });

        await db.insert('borrower_communication_logs', {
          'id': 'comm-fk-1',
          'borrower_id': 'b-fk-1',
          'loan_id': 'loan-fk-1',
          'message_type': 'due_reminder',
          'channel': 'sms',
          'status': 'openedInSms',
          'created_at': '2026-07-31T00:00:00Z',
          'updated_at': '2026-07-31T00:00:00Z',
        });

        await db.delete('loans', where: 'id = ?', whereArgs: ['loan-fk-1']);
        final commLogsAfterLoanDelete = await db.query(
          'borrower_communication_logs',
          where: 'id = ?',
          whereArgs: ['comm-fk-1'],
        );
        expect(commLogsAfterLoanDelete.single['loan_id'], isNull);

        await db.insert('loans', {
          'id': 'loan-fk-1',
          'borrower_id': 'b-fk-1',
          'original_principal': '1000.00',
          'monthly_rate': '0.05',
          'created_at': '2026-07-31T00:00:00Z',
        });

        await db.delete('borrowers', where: 'id = ?', whereArgs: ['b-fk-1']);
        final loansAfterBorrowerDelete = await db.query(
          'loans',
          where: 'id = ?',
          whereArgs: ['loan-fk-1'],
        );
        expect(loansAfterBorrowerDelete, isEmpty);
        final commLogsAfterBorrowerDelete = await db.query(
          'borrower_communication_logs',
          where: 'id = ?',
          whereArgs: ['comm-fk-1'],
        );
        expect(commLogsAfterBorrowerDelete, isEmpty);
      },
    );

    test(
      'upgrade from v10 to v11 preserves data and adds borrower_communication_logs table',
      () async {
        final dbPath = join(
          await getDatabasesPath(),
          'test_v10_v11_upgrade.db',
        );
        final dbFile = File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }

        final dbV10 = await openDatabase(
          dbPath,
          version: 10,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE borrowers (
              id TEXT PRIMARY KEY,
              server_id TEXT,
              first_name TEXT NOT NULL,
              last_name TEXT NOT NULL,
              national_id TEXT NOT NULL,
              phone TEXT NOT NULL,
              date_of_birth TEXT NOT NULL,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
            await db.execute('''
            CREATE TABLE loans (
              id TEXT PRIMARY KEY,
              borrower_id TEXT NOT NULL,
              created_at TEXT NOT NULL DEFAULT ''
            )
          ''');
            await db.execute('''
            CREATE TABLE offline_sync_queue (
              id TEXT PRIMARY KEY,
              transaction_uuid TEXT UNIQUE NOT NULL,
              endpoint TEXT NOT NULL,
              method TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          },
        );

        await dbV10.insert('borrowers', {
          'id': 'b-v10-1',
          'first_name': 'Existing',
          'last_name': 'Borrower',
          'national_id': 'enc_id',
          'phone': 'enc_phone',
          'date_of_birth': '1985-05-05',
          'status': 'Active',
          'created_at': '2026-07-01T00:00:00Z',
        });
        await dbV10.close();

        final service = DatabaseService(dbPath: dbPath);
        final upgradedDb = await service.database;

        final borrowers = await upgradedDb.query(
          'borrowers',
          where: 'id = ?',
          whereArgs: ['b-v10-1'],
        );
        expect(borrowers.length, 1);
        expect(borrowers.first['first_name'], 'Existing');

        final commLogs = await upgradedDb.query('borrower_communication_logs');
        expect(commLogs, isEmpty);

        await service.close();
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      },
    );

    test('communication log CRUD operations work properly', () async {
      final db = await databaseService.database;

      await db.insert('borrowers', {
        'id': 'b-comm-test',
        'first_name': 'Comm',
        'last_name': 'Log',
        'national_id': 'nat_id',
        'phone': 'phone',
        'date_of_birth': '1990-01-01',
        'status': 'Active',
        'created_at': '2026-07-31T00:00:00Z',
      });

      final logMap = {
        'id': 'log-1',
        'borrower_id': 'b-comm-test',
        'message_type': 'due_reminder',
        'channel': 'sms',
        'status': 'openedInSms',
        'created_at': '2026-07-31T10:00:00Z',
        'updated_at': '2026-07-31T10:00:00Z',
      };
      await db.insert('borrower_communication_logs', logMap);

      var logs = await db.query(
        'borrower_communication_logs',
        where: 'id = ?',
        whereArgs: ['log-1'],
      );
      expect(logs.single['status'], 'openedInSms');

      await db.update(
        'borrower_communication_logs',
        {'status': 'confirmedSent', 'updated_at': '2026-07-31T10:05:00Z'},
        where: 'id = ?',
        whereArgs: ['log-1'],
      );

      logs = await db.query(
        'borrower_communication_logs',
        where: 'id = ?',
        whereArgs: ['log-1'],
      );
      expect(logs.single['status'], 'confirmedSent');

      await db.delete(
        'borrower_communication_logs',
        where: 'id = ?',
        whereArgs: ['log-1'],
      );
      logs = await db.query(
        'borrower_communication_logs',
        where: 'id = ?',
        whereArgs: ['log-1'],
      );
      expect(logs, isEmpty);
    });
  });
}
