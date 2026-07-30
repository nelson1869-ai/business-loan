import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/features/borrower_communication/data/borrower_communication_log_repository.dart';
import 'package:lending_nelson/features/borrower_communication/domain/borrower_communication_log.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'persists offline status transitions without message or phone PII',
    () async {
      final databaseService = DatabaseService(dbPath: inMemoryDatabasePath);
      addTearDown(databaseService.close);
      final db = await databaseService.database;
      await db.insert('borrowers', {
        'id': 'borrower-1',
        'first_name': 'encrypted',
        'last_name': 'encrypted',
        'national_id': 'encrypted',
        'phone': 'encrypted',
        'date_of_birth': '1990-01-01',
        'status': 'Active',
        'created_at': '2026-01-01T00:00:00Z',
      });

      final repository = BorrowerCommunicationLogRepository(databaseService);
      final opened = await repository.record(
        borrowerId: 'borrower-1',
        messageType: 'Payment reminder',
        channel: 'SMS',
        status: BorrowerCommunicationStatus.openedInSms,
      );
      await repository.updateStatus(
        opened.id,
        BorrowerCommunicationStatus.confirmedSent,
      );

      final history = await repository.forBorrower('borrower-1');
      expect(history, hasLength(1));
      expect(history.single.status, BorrowerCommunicationStatus.confirmedSent);

      final columns = await db.rawQuery(
        "PRAGMA table_info('borrower_communication_logs')",
      );
      final names = columns.map((row) => row['name']).toSet();
      expect(names, isNot(contains('message')));
      expect(names, isNot(contains('phone')));
      expect(names, isNot(contains('delivered')));
    },
  );
}
