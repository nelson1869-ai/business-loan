import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:lending_nelson/features/borrowers/data/borrower_repository.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_model.dart';
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
      phone: '09171234567',
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

  test('does not delete a borrower with an open cached loan', () async {
    const borrower = Borrower(
      id: '00000000-0000-4000-8000-000000000002',
      firstName: 'John',
      lastName: 'Doe',
      nationalId: '87654321',
      phone: '09170000000',
      dateOfBirth: '1990-01-01',
      status: 'Active',
      createdAt: '2026-01-01T00:00:00.000Z',
    );
    await repository.saveBorrower(borrower);
    final database = await databaseService.database;
    await database.insert('loans', {
      'id': '00000000-0000-4000-8000-000000000003',
      'borrower_id': borrower.id,
      'data_json': '{"status":"Active"}',
      'cached_at': '2026-01-01T00:00:00.000Z',
    });

    await expectLater(
      repository.deleteBorrower(borrower.id),
      throwsA(isA<BorrowerHasOpenLoansException>()),
    );
    expect(await repository.getBorrower(borrower.id), isNotNull);
  });

  test('rejects an equivalent phone for a different borrower', () async {
    const first = Borrower(
      id: '00000000-0000-4000-8000-000000000004',
      firstName: 'First',
      lastName: 'Borrower',
      nationalId: 'PHONE-ONE',
      phone: '09916084400',
      dateOfBirth: '1990-01-01',
      status: 'Active',
      createdAt: '2026-01-01T00:00:00.000Z',
    );
    const duplicate = Borrower(
      id: '00000000-0000-4000-8000-000000000005',
      firstName: 'Second',
      lastName: 'Borrower',
      nationalId: 'PHONE-TWO',
      phone: '+639916084400',
      dateOfBirth: '1991-01-01',
      status: 'Active',
      createdAt: '2026-01-02T00:00:00.000Z',
    );

    await repository.saveBorrower(first);

    await expectLater(
      repository.saveBorrower(duplicate),
      throwsA(isA<DuplicateBorrowerPhoneException>()),
    );
    expect((await repository.getBorrowers()).single.id, first.id);
  });

  test('remote refresh preserves pending local create', () async {
    const pending = Borrower(
      id: '00000000-0000-4000-8000-000000000006',
      firstName: 'Pending',
      lastName: 'Create',
      nationalId: 'PENDING-CREATE',
      phone: '09916084401',
      dateOfBirth: '1992-01-01',
      status: 'Active',
      createdAt: '2026-01-03T00:00:00.000Z',
    );
    await repository.saveBorrower(pending);

    await repository.syncRemoteBorrowers(const []);

    expect((await repository.getBorrowers()).single.id, pending.id);
    expect(await repository.isBorrowerServerVerified(pending.id), isFalse);
  });

  test('only a synced non-deleted borrower is server verified', () async {
    const borrower = Borrower(
      id: '00000000-0000-4000-8000-000000000009',
      firstName: 'Verified',
      lastName: 'Borrower',
      nationalId: 'VERIFIED-ID',
      phone: '09916084409',
      dateOfBirth: '1990-01-01',
      status: 'Active',
      createdAt: '2026-01-06T00:00:00.000Z',
    );

    await repository.saveBorrower(borrower, syncStatus: 'synced');
    expect(await repository.isBorrowerServerVerified(borrower.id), isTrue);

    await repository.deleteBorrower(borrower.id, softDeleteOnly: true);
    expect(await repository.isBorrowerServerVerified(borrower.id), isFalse);
  });

  test('remote refresh preserves pending local update', () async {
    const original = Borrower(
      id: '00000000-0000-4000-8000-000000000007',
      firstName: 'Original',
      lastName: 'Name',
      nationalId: 'PENDING-UPDATE',
      phone: '09916084402',
      dateOfBirth: '1993-01-01',
      status: 'Active',
      createdAt: '2026-01-04T00:00:00.000Z',
    );
    final updated = Borrower(
      id: original.id,
      firstName: 'Updated',
      lastName: 'Name',
      nationalId: original.nationalId,
      phone: original.phone,
      dateOfBirth: original.dateOfBirth,
      status: original.status,
      createdAt: original.createdAt,
    );
    await repository.saveBorrower(original, syncStatus: 'synced');
    await repository.updateBorrower(updated);

    await repository.syncRemoteBorrowers(const [original]);

    expect((await repository.getBorrowers()).single.firstName, 'Updated');
  });

  test('remote refresh does not resurrect pending local deletion', () async {
    const borrower = Borrower(
      id: '00000000-0000-4000-8000-000000000008',
      firstName: 'Pending',
      lastName: 'Delete',
      nationalId: 'PENDING-DELETE',
      phone: '09916084403',
      dateOfBirth: '1994-01-01',
      status: 'Active',
      createdAt: '2026-01-05T00:00:00.000Z',
    );
    await repository.saveBorrower(borrower, syncStatus: 'synced');
    await repository.deleteBorrower(borrower.id, softDeleteOnly: true);

    await repository.syncRemoteBorrowers(const [borrower]);

    expect(await repository.getBorrowers(), isEmpty);
    final database = await databaseService.database;
    final tombstone = (await database.query('borrowers')).single;
    expect(tombstone['deleted_at'], isNotNull);
    expect(tombstone['sync_status'], 'pending');
  });
}
