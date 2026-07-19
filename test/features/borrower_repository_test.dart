import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:lending_nelson/features/dashboard/data/repositories/borrower_repository.dart';
import 'package:lending_nelson/features/dashboard/domain/models/borrower.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestEncryptionService extends EncryptionService {
  _TestEncryptionService() : super(const FlutterSecureStorage());

  @override
  Future<String> encrypt(String plainText) async => 'encrypted:$plainText';

  @override
  Future<String> decrypt(String cipherTextWithIv) async {
    return cipherTextWithIv.replaceFirst('encrypted:', '');
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService databaseService;
  late BorrowerRepository repository;

  setUp(() {
    databaseService = DatabaseService(dbPath: inMemoryDatabasePath);
    repository = BorrowerRepository(databaseService, _TestEncryptionService());
  });

  tearDown(() => databaseService.close());

  test('CRUD encrypts PII and writes consistently redacted audits', () async {
    const borrower = Borrower(
      id: '00000000-0000-4000-8000-000000000001',
      firstName: 'Jane',
      lastName: 'Doe',
      nationalId: '12345678',
      phone: '+254712345678',
      dateOfBirth: '1990-01-01',
      status: 'Pending',
      createdAt: '2026-01-01T00:00:00.000Z',
    );

    await repository.saveBorrower(borrower);
    final database = await databaseService.database;
    final stored = (await database.query('borrowers')).single;
    expect(stored['first_name'], 'encrypted:Jane');
    expect(stored['national_id'], 'encrypted:12345678');

    final loaded = await repository.getBorrowers();
    expect(loaded.single.firstName, 'Jane');
    expect(loaded.single.nationalId, '12345678');

    final updated = Borrower(
      id: borrower.id,
      firstName: 'Janet',
      lastName: borrower.lastName,
      nationalId: borrower.nationalId,
      phone: borrower.phone,
      dateOfBirth: borrower.dateOfBirth,
      status: 'Active',
      createdAt: borrower.createdAt,
    );
    await repository.updateBorrower(updated);
    await repository.deleteBorrower(borrower.id);

    expect(await database.query('borrowers'), isEmpty);
    final audits = await database.query('audit_logs', orderBy: 'timestamp ASC');
    expect(audits.map((row) => row['action']), [
      'CREATE_BORROWER',
      'UPDATE_BORROWER',
      'DELETE_BORROWER',
    ]);
    for (final audit in audits) {
      final states = '${audit['old_state_json']} ${audit['new_state_json']}';
      expect(states, isNot(contains('Jane')));
      expect(states, isNot(contains('12345678')));
    }
  });
}
