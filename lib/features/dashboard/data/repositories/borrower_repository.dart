// ============================================================================
// Architectural Data Flow Diagram:
//
//                     +-----------------------------------+
//                     |      borrowers_provider.dart      |
//                     |  (Notifier triggers mutations)   |
//                     +-----------------+-----------------+
//                                       |
//                                       v
//                     +-----------------+-----------------+
//                     |      borrower_repository.dart     |
//                     | (Handles encryption & DB writes)  |
//                     +--------+-----------------+--------+
//                              |                 |
//             (PII Cryptography) |                 | (Local SQLite DB Writes)
//                              v                 v
//             +----------------+-------+ +-------+----------------+
//             |   encryption_service   | |    database_service    |
//             |  (AES/CBC PII Shield)  | |  (borrowers/audit_logs)|
//             +------------------------+ +------------------------+
// ============================================================================

// Dart Core & FFI Packages
import 'dart:convert';

// Third-Party Packages
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core Services (Shared across features)
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/security/encryption_service.dart';

// Feature Domain Layer (Holds immutable data models)
import '../../domain/models/borrower.dart';

/// Repository class that manages [Borrower] local data operations with SQLite.
///
/// It handles symmetric PII encryption before insertions/updates, PII decryption on queries,
/// and maintains compliance by writing redacted mutation logs to the audit log table.
class BorrowerRepository {
  final DatabaseService _dbService;
  final EncryptionService _encryption;
  final _uuid = const Uuid();

  BorrowerRepository(this._dbService, this._encryption);

  /// Saves a new borrower into the SQLite database.
  ///
  /// Encrypts PII fields ([Borrower.firstName], [Borrower.lastName], [Borrower.nationalId],
  /// [Borrower.phone]) and writes a sanitised audit record.
  Future<void> saveBorrower(Borrower borrower) async {
    final db = await _dbService.database;
    final encryptedBorrower = await _encryptBorrower(borrower);

    // Execute SQLite inserts in a single transaction for data integrity
    await db.transaction((txn) async {
      // 1. Insert the encrypted borrower record into the borrowers table
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

  /// Updates an existing borrower's details in the local SQLite database.
  ///
  /// Encrypts updated PII fields and logs the mutation details (redacted of PII) to the audit table.
  Future<void> updateBorrower(Borrower borrower) async {
    final db = await _dbService.database;

    // 1. Retrieve the existing record from the database to log the pre-mutation state
    final existingList = await db.query(
      'borrowers',
      where: 'id = ?',
      whereArgs: [borrower.id],
    );

    final oldStateJson = _existingRedactedState(existingList);
    final encryptedBorrower = await _encryptBorrower(borrower);

    // 3. Execute updates in a single transaction
    await db.transaction((txn) async {
      // Update the borrowers table record
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

  /// Deletes a borrower's record from the local SQLite database.
  ///
  /// Logs the deletion details (redacted of PII) to the audit table.
  Future<void> deleteBorrower(String id) async {
    final db = await _dbService.database;

    // 1. Retrieve the existing record from the database to log the pre-deletion state
    final existingList = await db.query(
      'borrowers',
      where: 'id = ?',
      whereArgs: [id],
    );

    final oldStateJson = _existingRedactedState(existingList);

    // 2. Perform deletion and write audit entry in a single transaction
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

  /// Retrieves and decrypts the list of borrowers from the SQLite database.
  Future<List<Borrower>> getBorrowers() async {
    final db = await _dbService.database;

    // Query rows ordered by newest creation date
    final maps = await db.query('borrowers', orderBy: 'created_at DESC');

    final List<Borrower> decryptedList = [];
    for (final map in maps) {
      final borrower = Borrower.fromMap(map);

      // Decrypt PII fields back into plain text
      final decFirstName = await _encryption.decrypt(borrower.firstName);
      final decLastName = await _encryption.decrypt(borrower.lastName);
      final decNationalId = await _encryption.decrypt(borrower.nationalId);
      final decPhone = await _encryption.decrypt(borrower.phone);

      // Reconstruct model with original plain text values
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

/// Provider exposing [BorrowerRepository].
final borrowerRepositoryProvider = Provider<BorrowerRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final encryption = ref.watch(encryptionServiceProvider);
  return BorrowerRepository(dbService, encryption);
});
