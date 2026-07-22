import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/database_service.dart';
import '../../../core/security/encryption_service.dart';

import '../domain/borrower_model.dart';

class BorrowerRepository {
  final DatabaseService _dbService;
  final EncryptionService _encryption;
  final _uuid = const Uuid();

  BorrowerRepository(this._dbService, this._encryption);

  Future<void> saveBorrower(Borrower borrower) async {
    final db = await _dbService.database;
    final encryptedBorrower = await _encryptBorrower(borrower);

    await db.transaction((txn) async {
      await txn.insert('borrowers', encryptedBorrower.toMap());

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

  Future<void> updateBorrower(Borrower borrower) async {
    final db = await _dbService.database;

    final existingList = await db.query(
      'borrowers',
      where: 'id = ?',
      whereArgs: [borrower.id],
    );

    final oldStateJson = _existingRedactedState(existingList);
    final encryptedBorrower = await _encryptBorrower(borrower);

    await db.transaction((txn) async {
      await txn.update(
        'borrowers',
        encryptedBorrower.toMap(),
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

  Future<void> deleteBorrower(String id) async {
    final db = await _dbService.database;

    final existingList = await db.query(
      'borrowers',
      where: 'id = ?',
      whereArgs: [id],
    );

    final oldStateJson = _existingRedactedState(existingList);

    await db.transaction((txn) async {
      await txn.delete('borrowers', where: 'id = ?', whereArgs: [id]);
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
      where: 'id = ?',
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
    );
  }

  Future<List<Borrower>> getBorrowers() async {
    final db = await _dbService.database;

    final maps = await db.query('borrowers', orderBy: 'created_at DESC');

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
    );
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
