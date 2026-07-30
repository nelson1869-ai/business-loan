// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens, initializes, and manages the local SQLite database schema.
///
/// File: `lib/core/database/database_service.dart`
class DatabaseService {
  DatabaseService({Database? db, String? dbPath}) : _db = db, _dbPath = dbPath;

  Database? _db;
  final String? _dbPath;

  Future<Database> get database async {
    // sqflite may return the same cached database handle to multiple service
    // instances. A disposed owner (or a debug engine restart) can therefore
    // close a handle still referenced here. Never hand callers a closed
    // connection; reopen it transparently.
    if (_db case final db? when db.isOpen) return db;
    _db = null;
    _db = await _initDatabase();
    await _ensureColumnsExist(_db!);
    return _db!;
  }

  Future<void> _ensureColumnsExist(Database db) async {
    try {
      final info = await db.rawQuery("PRAGMA table_info('loans')");
      final existing = info.map((r) => r['name'] as String).toSet();

      final requiredLoanCols = <String, String>{
        'server_id': 'TEXT',
        'borrower_id': "TEXT NOT NULL DEFAULT ''",
        'request_id': 'TEXT',
        'original_principal': "TEXT NOT NULL DEFAULT '0.00'",
        'monthly_rate': "TEXT NOT NULL DEFAULT '0.00'",
        'term_months': 'INTEGER NOT NULL DEFAULT 1',
        'payments_per_month': 'INTEGER NOT NULL DEFAULT 1',
        'start_date': "TEXT NOT NULL DEFAULT ''",
        'first_due_date': "TEXT NOT NULL DEFAULT ''",
        'final_due_date': "TEXT NOT NULL DEFAULT ''",
        'outstanding_principal': "TEXT NOT NULL DEFAULT '0.00'",
        'status': "TEXT NOT NULL DEFAULT 'Active'",
        'data_json': 'TEXT',
        'cached_at': 'TEXT',
        'created_at': "TEXT NOT NULL DEFAULT ''",
        'updated_at': 'TEXT',
        'deleted_at': 'TEXT',
        'sync_status': "TEXT NOT NULL DEFAULT 'pending'",
        'sync_error': 'TEXT',
        'version': 'INTEGER NOT NULL DEFAULT 1',
        'device_id': 'TEXT',
        'last_synced_at': 'TEXT',
      };

      for (final entry in requiredLoanCols.entries) {
        if (!existing.contains(entry.key)) {
          try {
            await db.execute(
              "ALTER TABLE loans ADD COLUMN ${entry.key} ${entry.value}",
            );
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<Database> _initDatabase() async {
    final String path;
    if (_dbPath != null) {
      path = _dbPath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, 'lending_nelson.db');
    }

    return await openDatabase(
      path,
      version: 11,
      // Foreground UI and WorkManager run in separate provider containers.
      // They must not share sqflite's cached handle because disposing the
      // background container would otherwise close the foreground connection.
      singleInstance: false,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. borrowers table
    await db.execute('''
      CREATE TABLE borrowers (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        national_id TEXT NOT NULL,      -- Encrypted PII
        phone TEXT NOT NULL,            -- Encrypted PII
        date_of_birth TEXT NOT NULL,
        status TEXT NOT NULL,           -- e.g., 'Active', 'Pending', 'Synced'
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        sync_error TEXT,
        version INTEGER NOT NULL DEFAULT 1,
        device_id TEXT,
        last_synced_at TEXT
      )
    ''');

    // 2. loans table
    await db.execute('''
      CREATE TABLE loans (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        borrower_id TEXT NOT NULL,
        request_id TEXT UNIQUE,
        original_principal TEXT NOT NULL DEFAULT '0.00',
        monthly_rate TEXT NOT NULL DEFAULT '0.00',
        term_months INTEGER NOT NULL DEFAULT 1,
        payments_per_month INTEGER NOT NULL DEFAULT 1,
        start_date TEXT NOT NULL DEFAULT '',
        first_due_date TEXT NOT NULL DEFAULT '',
        final_due_date TEXT NOT NULL DEFAULT '',
        outstanding_principal TEXT NOT NULL DEFAULT '0.00',
        status TEXT NOT NULL DEFAULT 'Active',
        data_json TEXT,
        cached_at TEXT,
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        sync_error TEXT,
        version INTEGER NOT NULL DEFAULT 1,
        device_id TEXT,
        last_synced_at TEXT,
        FOREIGN KEY (borrower_id) REFERENCES borrowers (id) ON DELETE CASCADE
      )
    ''');

    // 3. loan_schedules table
    await db.execute('''
      CREATE TABLE loan_schedules (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        loan_id TEXT NOT NULL,
        installment_number INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        expected_payment TEXT NOT NULL,
        interest_amount TEXT NOT NULL,
        principal_amount TEXT NOT NULL,
        paid_amount TEXT NOT NULL DEFAULT '0.00',
        status TEXT NOT NULL DEFAULT 'Scheduled',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (loan_id) REFERENCES loans (id) ON DELETE CASCADE
      )
    ''');

    // 4. repayments table
    await db.execute('''
      CREATE TABLE repayments (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        loan_id TEXT NOT NULL,
        installment_id TEXT,
        entry_type TEXT NOT NULL DEFAULT 'Payment',
        request_id TEXT UNIQUE,
        reversal_of_payment_id TEXT,
        amount TEXT NOT NULL,
        effective_date TEXT NOT NULL,
        note TEXT,
        allocation_json TEXT,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        sync_error TEXT,
        FOREIGN KEY (loan_id) REFERENCES loans (id) ON DELETE CASCADE
      )
    ''');

    // Legacy loan_payments cache alias
    await db.execute('''
      CREATE TABLE loan_payments (
        id TEXT PRIMARY KEY,
        loan_id TEXT NOT NULL,
        data_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    // 5. guarantors table
    await db.execute('''
      CREATE TABLE guarantors (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        borrower_id TEXT NOT NULL,
        name TEXT NOT NULL,
        relationship TEXT NOT NULL,
        phone TEXT NOT NULL,
        national_id TEXT,
        status TEXT NOT NULL DEFAULT 'Active',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (borrower_id) REFERENCES borrowers (id) ON DELETE CASCADE
      )
    ''');

    // 6. emergency_contacts table
    await db.execute('''
      CREATE TABLE emergency_contacts (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        borrower_id TEXT NOT NULL,
        name TEXT NOT NULL,
        relationship TEXT NOT NULL,
        phone TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (borrower_id) REFERENCES borrowers (id) ON DELETE CASCADE
      )
    ''');

    // 7. borrower_notes table
    await db.execute('''
      CREATE TABLE borrower_notes (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        borrower_id TEXT NOT NULL,
        note_text TEXT NOT NULL,
        author_id TEXT NOT NULL DEFAULT 'system-officer',
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (borrower_id) REFERENCES borrowers (id) ON DELETE CASCADE
      )
    ''');

    // 8. documents table
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        borrower_id TEXT NOT NULL,
        loan_id TEXT,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (borrower_id) REFERENCES borrowers (id) ON DELETE CASCADE
      )
    ''');

    // 9. users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'officer',
        token_expires_at TEXT,
        cached_at TEXT NOT NULL
      )
    ''');

    // 10. audit_logs table
    await db.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        entity_name TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        old_state_json TEXT,
        new_state_json TEXT
      )
    ''');

    // 11. offline_sync_queue table
    await db.execute('''
      CREATE TABLE offline_sync_queue (
        id TEXT PRIMARY KEY,
        transaction_uuid TEXT UNIQUE NOT NULL,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        entity_type TEXT NOT NULL DEFAULT 'unknown',
        entity_local_id TEXT,
        operation_type TEXT NOT NULL DEFAULT 'create',
        dependency_ids_json TEXT,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at TEXT,
        last_error_code TEXT,
        last_error_message TEXT,
        next_retry_at TEXT,
        server_resource_id TEXT,
        user_id TEXT,
        drain_lease_id TEXT,
        lease_acquired_at TEXT
      )
    ''');

    // 12. sync_conflicts table
    await db.execute('''
      CREATE TABLE sync_conflicts (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        local_id TEXT NOT NULL,
        server_id TEXT,
        local_data_json TEXT NOT NULL,
        server_data_json TEXT NOT NULL,
        detected_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'unresolved'
      )
    ''');

    // 13. sync_metadata table
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await _createLocalJsonCache(db);
    await _createAssistantIndexes(db);
    await _createBorrowerCommunicationLog(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS deleted_borrowers');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS loans (
          id TEXT PRIMARY KEY,
          borrower_id TEXT NOT NULL,
          data_json TEXT NOT NULL,
          cached_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS loan_payments (
          id TEXT PRIMARY KEY,
          loan_id TEXT NOT NULL,
          data_json TEXT NOT NULL,
          cached_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await _upgradeToVersion5(db);
    }
    if (oldVersion < 6) {
      await _upgradeToVersion6(db);
    }
    if (oldVersion < 7) {
      await _upgradeToVersion7(db);
    }
    if (oldVersion < 8) {
      await _createLocalJsonCache(db);
    }
    if (oldVersion < 9) {
      await _createAssistantIndexes(db);
    }
    if (oldVersion < 10) {
      await _upgradeToVersion10(db);
    }
    if (oldVersion < 11) {
      await _createBorrowerCommunicationLog(db);
    }
  }

  Future<void> _createBorrowerCommunicationLog(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS borrower_communication_logs (
        id TEXT PRIMARY KEY,
        borrower_id TEXT NOT NULL,
        loan_id TEXT,
        payment_id TEXT,
        message_type TEXT NOT NULL,
        channel TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (borrower_id) REFERENCES borrowers (id) ON DELETE CASCADE,
        FOREIGN KEY (loan_id) REFERENCES loans (id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_communication_borrower_created '
      'ON borrower_communication_logs (borrower_id, created_at DESC)',
    );
  }

  Future<void> _upgradeToVersion10(Database db) async {
    final queueCols = [
      "ALTER TABLE offline_sync_queue ADD COLUMN user_id TEXT",
      "ALTER TABLE offline_sync_queue ADD COLUMN drain_lease_id TEXT",
      "ALTER TABLE offline_sync_queue ADD COLUMN lease_acquired_at TEXT",
    ];
    for (final sql in queueCols) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status_user '
      'ON offline_sync_queue (status, user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_lease '
      'ON offline_sync_queue (drain_lease_id, lease_acquired_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_entity '
      'ON offline_sync_queue (entity_type, entity_local_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_tx_uuid '
      'ON offline_sync_queue (transaction_uuid)',
    );
  }

  Future<void> _createAssistantIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_loans_borrower_status '
      'ON loans (borrower_id, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_schedules_status_due '
      'ON loan_schedules (status, due_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_repayments_loan_effective '
      'ON repayments (loan_id, effective_date)',
    );
  }

  Future<void> _createLocalJsonCache(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_json_cache (
        cache_key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeToVersion7(Database db) async {
    final loanCols = [
      "ALTER TABLE loans ADD COLUMN server_id TEXT",
      "ALTER TABLE loans ADD COLUMN request_id TEXT",
      "ALTER TABLE loans ADD COLUMN original_principal TEXT NOT NULL DEFAULT '0.00'",
      "ALTER TABLE loans ADD COLUMN monthly_rate TEXT NOT NULL DEFAULT '0.00'",
      "ALTER TABLE loans ADD COLUMN term_months INTEGER NOT NULL DEFAULT 1",
      "ALTER TABLE loans ADD COLUMN payments_per_month INTEGER NOT NULL DEFAULT 1",
      "ALTER TABLE loans ADD COLUMN start_date TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE loans ADD COLUMN first_due_date TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE loans ADD COLUMN final_due_date TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE loans ADD COLUMN outstanding_principal TEXT NOT NULL DEFAULT '0.00'",
      "ALTER TABLE loans ADD COLUMN status TEXT NOT NULL DEFAULT 'Active'",
      "ALTER TABLE loans ADD COLUMN data_json TEXT",
      "ALTER TABLE loans ADD COLUMN cached_at TEXT",
      "ALTER TABLE loans ADD COLUMN created_at TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE loans ADD COLUMN updated_at TEXT",
      "ALTER TABLE loans ADD COLUMN deleted_at TEXT",
      "ALTER TABLE loans ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending'",
      "ALTER TABLE loans ADD COLUMN sync_error TEXT",
      "ALTER TABLE loans ADD COLUMN version INTEGER NOT NULL DEFAULT 1",
      "ALTER TABLE loans ADD COLUMN device_id TEXT",
      "ALTER TABLE loans ADD COLUMN last_synced_at TEXT",
    ];
    for (final sql in loanCols) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }
  }

  Future<void> _upgradeToVersion5(Database db) async {
    final columns = [
      "ALTER TABLE offline_sync_queue ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'",
      "ALTER TABLE offline_sync_queue ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE offline_sync_queue ADD COLUMN last_attempt_at TEXT",
      "ALTER TABLE offline_sync_queue ADD COLUMN last_error_code TEXT",
      "ALTER TABLE offline_sync_queue ADD COLUMN last_error_message TEXT",
      "ALTER TABLE offline_sync_queue ADD COLUMN next_retry_at TEXT",
      "ALTER TABLE offline_sync_queue ADD COLUMN server_resource_id TEXT",
    ];

    for (final sql in columns) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }
  }

  Future<void> _upgradeToVersion6(Database db) async {
    final borrowerCols = [
      "ALTER TABLE borrowers ADD COLUMN server_id TEXT",
      "ALTER TABLE borrowers ADD COLUMN updated_at TEXT",
      "ALTER TABLE borrowers ADD COLUMN deleted_at TEXT",
      "ALTER TABLE borrowers ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending'",
      "ALTER TABLE borrowers ADD COLUMN sync_error TEXT",
      "ALTER TABLE borrowers ADD COLUMN version INTEGER NOT NULL DEFAULT 1",
      "ALTER TABLE borrowers ADD COLUMN device_id TEXT",
      "ALTER TABLE borrowers ADD COLUMN last_synced_at TEXT",
    ];
    for (final sql in borrowerCols) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    final queueCols = [
      "ALTER TABLE offline_sync_queue ADD COLUMN entity_type TEXT NOT NULL DEFAULT 'unknown'",
      "ALTER TABLE offline_sync_queue ADD COLUMN entity_local_id TEXT",
      "ALTER TABLE offline_sync_queue ADD COLUMN operation_type TEXT NOT NULL DEFAULT 'create'",
      "ALTER TABLE offline_sync_queue ADD COLUMN dependency_ids_json TEXT",
    ];
    for (final sql in queueCols) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS loan_schedules (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        loan_id TEXT NOT NULL,
        installment_number INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        expected_payment TEXT NOT NULL,
        interest_amount TEXT NOT NULL,
        principal_amount TEXT NOT NULL,
        paid_amount TEXT NOT NULL DEFAULT '0.00',
        status TEXT NOT NULL DEFAULT 'Scheduled',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS repayments (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        loan_id TEXT NOT NULL,
        installment_id TEXT,
        entry_type TEXT NOT NULL DEFAULT 'Payment',
        request_id TEXT UNIQUE,
        reversal_of_payment_id TEXT,
        amount TEXT NOT NULL,
        effective_date TEXT NOT NULL,
        note TEXT,
        allocation_json TEXT,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        sync_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS guarantors (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        borrower_id TEXT NOT NULL,
        name TEXT NOT NULL,
        relationship TEXT NOT NULL,
        phone TEXT NOT NULL,
        national_id TEXT,
        status TEXT NOT NULL DEFAULT 'Active',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_contacts (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        borrower_id TEXT NOT NULL,
        name TEXT NOT NULL,
        relationship TEXT NOT NULL,
        phone TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS borrower_notes (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        borrower_id TEXT NOT NULL,
        note_text TEXT NOT NULL,
        author_id TEXT NOT NULL DEFAULT 'system-officer',
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        server_id TEXT,
        borrower_id TEXT NOT NULL,
        loan_id TEXT,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'officer',
        token_expires_at TEXT,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        local_id TEXT NOT NULL,
        server_id TEXT,
        local_data_json TEXT NOT NULL,
        server_data_json TEXT NOT NULL,
        detected_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'unresolved'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
