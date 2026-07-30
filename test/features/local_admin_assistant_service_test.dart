import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:lending_nelson/features/dashboard/data/local_admin_assistant_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService databaseService;
  late LocalAdminAssistantService service;

  setUp(() async {
    databaseService = DatabaseService(dbPath: inMemoryDatabasePath);
    service = LocalAdminAssistantService(
      databaseService,
      _FakeEncryptionService(),
    );
    final db = await databaseService.database;
    await db.insert('borrowers', <String, Object?>{
      'id': 'borrower-1',
      'first_name': 'Alex',
      'last_name': 'Morgan',
      'national_id': 'encrypted',
      'phone': 'encrypted',
      'date_of_birth': '1990-01-01',
      'status': 'Active',
      'created_at': '2026-07-01T00:00:00Z',
      'last_synced_at': '2026-07-28T10:00:00Z',
    });
    await db.insert('loans', <String, Object?>{
      'id': 'loan-1',
      'borrower_id': 'borrower-1',
      'original_principal': '1000.00',
      'outstanding_principal': '750.00',
      'monthly_rate': '0.10',
      'term_months': 5,
      'payments_per_month': 1,
      'start_date': '2026-07-01',
      'first_due_date': '2026-08-01',
      'final_due_date': '2026-12-01',
      'status': 'Active',
      'created_at': '2026-07-01T00:00:00Z',
      'last_synced_at': '2026-07-28T10:00:00Z',
    });
    await db.insert('loan_schedules', <String, Object?>{
      'id': 'schedule-1',
      'loan_id': 'loan-1',
      'installment_number': 1,
      'due_date': '2026-08-01',
      'expected_payment': '250.00',
      'interest_amount': '25.00',
      'principal_amount': '225.00',
      'paid_amount': '0.00',
      'status': 'Scheduled',
      'created_at': '2026-07-01T00:00:00Z',
    });
    await db.insert('repayments', <String, Object?>{
      'id': 'payment-1',
      'loan_id': 'loan-1',
      'entry_type': 'Payment',
      'amount': '250.00',
      'effective_date': '2026-07-15',
      'created_at': '2026-07-15T00:00:00Z',
    });
  });

  tearDown(() => databaseService.close());

  test('offline portfolio answer uses synchronized SQLite data', () async {
    final reply = await service.answer('What is our outstanding portfolio?');

    expect(reply.answer, contains('PHP 750.00'));
    expect(reply.answerSource, 'offline');
    expect(reply.aiUsed, isFalse);
    expect(reply.lastSyncedAt, isNotNull);
  });

  test('unsupported offline information never invents an answer', () async {
    final reply = await service.answer('Tell me tomorrow winning numbers');

    expect(reply.answer, contains('not available offline'));
    expect(reply.answerSource, 'offline');
  });

  test('offline borrower directory uses synchronized records', () async {
    final reply = await service.answer('Show me the list of borrowers');

    expect(reply.answer, contains('1 synchronized borrower'));
    expect(reply.records, hasLength(1));
    expect(reply.records.single.borrowerName, 'Alex Morgan');
    expect(reply.records.single.recordType, 'borrower');
    expect(reply.answerSource, 'offline');
  });

  test('offline natural borrower wording returns original principal', () async {
    final reply = await service.answer('How much did Alex Morgan borrow?');

    expect(reply.answer, contains('original principal'));
    expect(reply.answer, contains('PHP 1000.00'));
    expect(reply.answerSource, 'offline');
  });

  test(
    'offline ungrammatical borrow query with first name returns principal',
    () async {
      final reply = await service.answer('how much borrow of Alex?');

      expect(reply.answer, contains('original principal'));
      expect(reply.answer, contains('PHP 1000.00'));
      expect(reply.answerSource, 'offline');
    },
  );

  test('offline collections query returns collection total', () async {
    final reply = await service.answer('collections');

    expect(reply.answer, contains('collections this month'));
    expect(reply.answerSource, 'offline');
  });

  test('offline borrower next payment uses synchronized schedule', () async {
    final reply = await service.answer('When is Alex Morgan next payment?');

    expect(reply.answer, contains('PHP 250.00'));
    expect(reply.records, hasLength(1));
    expect(reply.records.single.dueDate, '2026-08-01');
  });

  test('offline borrower payment history uses synchronized ledger', () async {
    final reply = await service.answer('Show Alex Morgan payment history');

    expect(reply.records, hasLength(1));
    expect(reply.records.single.recordType, 'payment');
    expect(reply.records.single.amountPaid, '250.00');
  });

  test('offline assistant decrypts borrower names only in memory', () async {
    final db = await databaseService.database;
    await db.insert('borrowers', <String, Object?>{
      'id': 'borrower-2',
      'first_name': 'secure:Jamie',
      'last_name': 'secure:Santos',
      'national_id': 'secure:id',
      'phone': 'secure:phone',
      'date_of_birth': '1992-01-01',
      'status': 'Active',
      'created_at': '2026-07-02T00:00:00Z',
    });

    final reply = await service.answer('Find borrower Jamie Santos');

    expect(reply.records, hasLength(1));
    expect(reply.records.single.borrowerName, 'Jamie Santos');
  });
}

class _FakeEncryptionService extends EncryptionService {
  _FakeEncryptionService() : super(const FlutterSecureStorage());

  @override
  Future<String> decrypt(String value) async {
    return value.startsWith('secure:') ? value.substring(7) : value;
  }

  @override
  Future<String> encrypt(String value) async => 'secure:$value';
}
