import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/security/encryption_service.dart';
import '../../domain/models/borrower.dart';

/// Repository class that manages [Borrower] local data operations with SQLite.
///
/// It handles symmetric PII encryption before insertions, PII decryption on queries,
/// and maintains compliance by writing mutations to the audit log table.
///
/// File: `lib/features/dashboard/data/repositories/borrower_repository.dart`
///
/// Data Flow Diagram:
/// ```text
///  +---------------------------+     +--------------------------+
///  | borrowers_provider.dart   | --> | borrower_repository.dart |
///  +---------------------------+     +------------+-------------+
///                                                |
///                         +----------------------+--------------------+
///                         v                                           v
///              database_provider.dart                    encryption_service.dart
/// ```
class BorrowerRepository {
  final DatabaseService _dbService;
  final EncryptionService _encryption;
  final _uuid = const Uuid();

  BorrowerRepository(this._dbService, this._encryption);

  /// Saves a borrower into the SQLite database.
  ///
  /// Encrypts PII fields ([Borrower.firstName], [Borrower.lastName], [Borrower.nationalId],
  /// [Borrower.phone]) and writes a sanitised audit record.
  Future<void> saveBorrower(Borrower borrower) async {
    final db = await _dbService.database;

    // Encrypt sensitive Personally Identifiable Information (PII) before storage
    final encFirstName = await _encryption.encrypt(borrower.firstName);
    final encLastName = await _encryption.encrypt(borrower.lastName);
    final encNationalId = await _encryption.encrypt(borrower.nationalId);
    final encPhone = await _encryption.encrypt(borrower.phone);

    // Create a new borrower object holding the encrypted text
    final encryptedBorrower = Borrower(
      id: borrower.id,
      firstName: encFirstName,
      lastName: encLastName,
      nationalId: encNationalId,
      phone: encPhone,
      dateOfBirth: borrower.dateOfBirth,
      status: borrower.status,
      createdAt: borrower.createdAt,
    );

    // Execute SQLite inserts in a single transaction for data integrity
    await db.transaction((txn) async {
      // 1. Insert the encrypted borrower record into the borrowers table
      await txn.insert('borrowers', encryptedBorrower.toMap());

      // 2. Create and write an audit log entry for compliance
      final auditLog = {
        'id': _uuid.v4(),
        'user_id':
            'system-officer', // Default system user (auth details will bind here later)
        'action': 'CREATE_BORROWER',
        'entity_name': 'borrowers',
        'entity_id': borrower.id,
        'timestamp': DateTime.now().toIso8601String(),
        'old_state_json': null,
        // Redact PII fields in audit log payloads to prevent logs leakage
        'new_state_json': jsonEncode({
          'id': borrower.id,
          'status': borrower.status,
          'first_name': '[REDACTED]',
          'last_name': '[REDACTED]',
          'national_id': '[REDACTED]',
          'phone': '[REDACTED]',
        }),
      };
      await txn.insert('audit_logs', auditLog);
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
}

/// Provider exposing [BorrowerRepository].
final borrowerRepositoryProvider = Provider<BorrowerRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final encryption = ref.watch(encryptionServiceProvider);
  return BorrowerRepository(dbService, encryption);
});
