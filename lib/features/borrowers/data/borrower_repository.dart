import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/database_service.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/validation/phone_number.dart';

import '../domain/borrower_model.dart';

class BorrowerHasOpenLoansException implements Exception {
  const BorrowerHasOpenLoansException();

  String get message =>
      'This borrower cannot be deleted while an active loan remains open.';
}

class DuplicateBorrowerPhoneException implements Exception {
  const DuplicateBorrowerPhoneException();

  String get message => 'A borrower with this phone number already exists.';

  @override
  String toString() => message;
}

class BorrowerRepository {
  final DatabaseService _dbService;
  final EncryptionService _encryption;
  final _uuid = const Uuid();

  BorrowerRepository(this._dbService, this._encryption);

  Future<void> saveBorrower(
    Borrower borrower, {
    String syncStatus = 'pending',
  }) async {
    final db = await _dbService.database;
    await _ensureUniquePhone(db, borrower.phone, excludingId: borrower.id);
    final encryptedBorrower = await _encryptBorrower(borrower);

    final map = encryptedBorrower.toMap();
    map['sync_status'] = syncStatus;
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(
        'borrowers',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        'audit_logs',
        _auditLog(
          action: 'CREATE_BORROWER',
          borrowerId: borrower.id,
          newStateJson: _redactedStateJson(borrower.id, borrower.status),
        ),
      );
    });
  }

  Future<void> syncRemoteBorrowers(List<Borrower> remote) async {
    final db = await _dbService.database;
    final remoteIds = remote.map((b) => b.id).toSet();

    final protectedRows = await db.query(
      'borrowers',
      columns: ['id', 'sync_status', 'deleted_at'],
      where: "sync_status != 'synced' OR deleted_at IS NOT NULL",
    );
    final protectedIds = protectedRows
        .map((row) => row['id'] as String)
        .toSet();

    // Only delete local borrowers that are already marked 'synced' and missing from remote
    final localMaps = await db.query(
      'borrowers',
      columns: ['id'],
      where: "sync_status = 'synced'",
    );
    for (final map in localMaps) {
      final id = map['id'] as String;
      if (!remoteIds.contains(id)) {
        await db.delete('borrowers', where: 'id = ?', whereArgs: [id]);
      }
    }
    for (final borrower in remote) {
      if (protectedIds.contains(borrower.id)) {
        continue;
      }
      final encryptedBorrower = await _encryptBorrower(borrower);
      final map = encryptedBorrower.toMap();
      map['sync_status'] = 'synced';
      map['last_synced_at'] = DateTime.now().toUtc().toIso8601String();

      await db.insert(
        'borrowers',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> updateBorrower(
    Borrower borrower, {
    String syncStatus = 'pending',
  }) async {
    final db = await _dbService.database;
    await _ensureUniquePhone(db, borrower.phone, excludingId: borrower.id);

    final existingList = await db.query(
      'borrowers',
      where: 'id = ?',
      whereArgs: [borrower.id],
    );

    final oldStateJson = _existingRedactedState(existingList);
    final encryptedBorrower = await _encryptBorrower(borrower);
    final map = encryptedBorrower.toMap();
    map['sync_status'] = syncStatus;
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'borrowers',
        map,
        where: 'id = ?',
        whereArgs: [borrower.id],
      );

      await txn.insert(
        'audit_logs',
        _auditLog(
          action: 'UPDATE_BORROWER',
          borrowerId: borrower.id,
          oldStateJson: oldStateJson,
          newStateJson: _redactedStateJson(borrower.id, borrower.status),
        ),
      );
    });
  }

  Future<void> deleteBorrower(String id, {bool softDeleteOnly = false}) async {
    final db = await _dbService.database;

    final loanRows = await db.query(
      'loans',
      columns: ['data_json'],
      where: 'borrower_id = ?',
      whereArgs: [id],
    );
    final hasOpenLoan = loanRows.any((row) {
      final dataStr = row['data_json'] as String?;
      if (dataStr == null) return false;
      final loan = jsonDecode(dataStr) as Map<String, dynamic>;
      return loan['status'] != 'Paid' && loan['status'] != 'Cancelled';
    });
    if (hasOpenLoan) {
      throw const BorrowerHasOpenLoansException();
    }

    final existingList = await db.query(
      'borrowers',
      where: 'id = ?',
      whereArgs: [id],
    );

    final oldStateJson = _existingRedactedState(existingList);
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      if (softDeleteOnly) {
        await txn.update(
          'borrowers',
          {'deleted_at': now, 'sync_status': 'pending'},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.delete('borrowers', where: 'id = ?', whereArgs: [id]);
      }

      await txn.insert(
        'audit_logs',
        _auditLog(
          action: 'DELETE_BORROWER',
          borrowerId: id,
          oldStateJson: oldStateJson,
        ),
      );
    });
  }

  Future<Borrower?> getBorrower(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'borrowers',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final borrower = Borrower.fromMap(maps.first);
    final decFirstName = await _encryption.decrypt(borrower.firstName);
    final decLastName = await _encryption.decrypt(borrower.lastName);
    final decNationalId = await _encryption.decrypt(borrower.nationalId);
    final decPhone = await _encryption.decrypt(borrower.phone);
    return Borrower(
      id: borrower.id,
      firstName: decFirstName,
      lastName: decLastName,
      nationalId: decNationalId,
      phone: decPhone,
      dateOfBirth: borrower.dateOfBirth,
      status: borrower.status,
      createdAt: borrower.createdAt,
      syncStatus: (maps.first['sync_status'] ?? 'synced').toString(),
    );
  }

  Future<bool> isBorrowerServerVerified(String id) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'borrowers',
      columns: ['sync_status', 'deleted_at'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final row = rows.first;
    return row['sync_status'] == 'synced' && row['deleted_at'] == null;
  }

  Future<List<Borrower>> getBorrowers() async {
    final db = await _dbService.database;

    final maps = await db.query(
      'borrowers',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );

    final List<Borrower> decryptedList = [];
    for (final map in maps) {
      final borrower = Borrower.fromMap(map);

      final decFirstName = await _encryption.decrypt(borrower.firstName);
      final decLastName = await _encryption.decrypt(borrower.lastName);
      final decNationalId = await _encryption.decrypt(borrower.nationalId);
      final decPhone = await _encryption.decrypt(borrower.phone);

      decryptedList.add(
        Borrower(
          id: borrower.id,
          firstName: decFirstName,
          lastName: decLastName,
          nationalId: decNationalId,
          phone: decPhone,
          dateOfBirth: borrower.dateOfBirth,
          status: borrower.status,
          createdAt: borrower.createdAt,
          syncStatus: (map['sync_status'] ?? 'synced').toString(),
        ),
      );
    }
    return decryptedList;
  }

  Future<Borrower> _encryptBorrower(Borrower borrower) async {
    return Borrower(
      id: borrower.id,
      firstName: await _encryption.encrypt(borrower.firstName),
      lastName: await _encryption.encrypt(borrower.lastName),
      nationalId: await _encryption.encrypt(borrower.nationalId),
      phone: await _encryption.encrypt(borrower.phone),
      dateOfBirth: borrower.dateOfBirth,
      status: borrower.status,
      createdAt: borrower.createdAt,
      syncStatus: borrower.syncStatus,
    );
  }

  Future<void> _ensureUniquePhone(
    Database db,
    String phone, {
    required String excludingId,
  }) async {
    final normalized = normalizePhilippineMobileNumber(phone);
    final rows = await db.query(
      'borrowers',
      columns: ['id', 'phone'],
      where: 'id != ? AND deleted_at IS NULL',
      whereArgs: [excludingId],
    );
    for (final row in rows) {
      final storedPhone = await _encryption.decrypt(row['phone']! as String);
      try {
        if (normalizePhilippineMobileNumber(storedPhone) == normalized) {
          throw const DuplicateBorrowerPhoneException();
        }
      } on FormatException {
        continue;
      }
    }
  }

  String? _existingRedactedState(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return null;
    final row = rows.first;
    return _redactedStateJson(row['id']! as String, row['status']! as String);
  }

  String _redactedStateJson(String borrowerId, String status) {
    return jsonEncode({
      'id': borrowerId,
      'status': status,
      'first_name': '[REDACTED]',
      'last_name': '[REDACTED]',
      'national_id': '[REDACTED]',
      'phone': '[REDACTED]',
    });
  }

  Map<String, Object?> _auditLog({
    required String action,
    required String borrowerId,
    String? oldStateJson,
    String? newStateJson,
  }) {
    return {
      'id': _uuid.v4(),
      'user_id': 'system-officer',
      'action': action,
      'entity_name': 'borrowers',
      'entity_id': borrowerId,
      'timestamp': DateTime.now().toIso8601String(),
      'old_state_json': oldStateJson,
      'new_state_json': newStateJson,
    };
  }
}

final borrowerRepositoryProvider = Provider<BorrowerRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final encryption = ref.watch(encryptionServiceProvider);
  return BorrowerRepository(dbService, encryption);
});

final borrowerServerVerifiedProvider = FutureProvider.family<bool, String>((
  ref,
  borrowerId,
) {
  return ref
      .watch(borrowerRepositoryProvider)
      .isBorrowerServerVerified(borrowerId);
});
