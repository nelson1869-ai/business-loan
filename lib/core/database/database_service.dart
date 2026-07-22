// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens, initializes, and closes the application's SQLite database.
///
/// File: `lib/core/database/database_service.dart`
///
/// Data Flow Diagram:
/// ```text
///  +------------------------+     +-----------------------+     +------------+
///  | database_provider.dart | --> | database_service.dart | --> | SQLite DB  |
///  +------------------------+     +-----------------------+     +------------+
/// ```
class DatabaseService {
  DatabaseService({Database? db, String? dbPath}) : _db = db, _dbPath = dbPath;

  Database? _db;
  final String? _dbPath;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
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
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create borrowers table
    await db.execute('''
      CREATE TABLE borrowers (
        id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        national_id TEXT NOT NULL,      -- Encrypted PII
        phone TEXT NOT NULL,            -- Encrypted PII
        date_of_birth TEXT NOT NULL,
        status TEXT NOT NULL,           -- e.g., 'Pending', 'Synced'
        created_at TEXT NOT NULL
      )
    ''');

    // Create audit_logs table
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

    // Create offline_sync_queue table
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

    // Create loans cache table
    await db.execute('''
      CREATE TABLE loans (
        id TEXT PRIMARY KEY,
        borrower_id TEXT NOT NULL,
        data_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    // Create loan_payments cache table
    await db.execute('''
      CREATE TABLE loan_payments (
        id TEXT PRIMARY KEY,
        loan_id TEXT NOT NULL,
        data_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
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
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
