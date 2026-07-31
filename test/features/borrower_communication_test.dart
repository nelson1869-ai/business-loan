import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/notifications/local_notification_service.dart';
import 'package:lending_nelson/features/borrower_communication/data/borrower_communication_service.dart';
import 'package:lending_nelson/features/borrower_communication/data/borrower_document_service.dart';
import 'package:lending_nelson/features/borrower_communication/data/borrower_due_reminder_scheduler.dart';
import 'package:lending_nelson/features/borrower_communication/domain/borrower_communication_context.dart';
import 'package:lending_nelson/features/borrower_communication/domain/borrower_message_template_service.dart';
import 'package:lending_nelson/features/borrower_communication/domain/phone_number.dart';
import 'package:lending_nelson/features/borrower_communication/presentation/message_preview_dialog.dart';
import 'package:lending_nelson/features/borrower_communication/presentation/send_to_borrower_sheet.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_model.dart';
import 'package:lending_nelson/features/loans/domain/models/installment.dart';
import 'package:lending_nelson/features/loans/domain/models/loan.dart';
import 'package:lending_nelson/features/loans/domain/models/payment.dart';
import 'package:lending_nelson/features/loans/data/repositories/local_loan_repository.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final templates = const BorrowerMessageTemplateService();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('borrower message templates', () {
    test(
      'generates payment reminder with existing currency and date formats',
      () {
        final message = templates.paymentReminder(
          _context(dueDate: '2026-08-05'),
          now: DateTime(2026, 8, 1),
        );
        expect(message, contains('Hello Ana,'));
        expect(message, contains('₱1,250.00'));
        expect(message, contains('8/5/2026'));
        expect(message, contains('₱8,750.00'));
        expect(message, contains('Please disregard'));
      },
    );

    test('generates respectful overdue reminder', () {
      final message = templates.paymentReminder(
        _context(dueDate: '2026-07-05', status: 'Overdue'),
        now: DateTime(2026, 7, 30),
      );
      expect(message, contains('currently overdue'));
      expect(message, contains('need assistance'));
      expect(message, isNot(contains('threat')));
    });

    test('loan summary uses persisted loan and installment values', () {
      final message = templates.loanSummary(_context());
      expect(message, contains('Loan amount: ₱10,000.00'));
      expect(message, contains('Remaining balance: ₱8,750.00'));
      expect(message, contains('Next payment: ₱1,250.00'));
    });

    test('payment receipt uses immutable payment reference and allocation', () {
      final message = templates.paymentReceipt(_context(withPayment: true));
      expect(message, contains('Reference number: local-request-1'));
      expect(message, contains('Remaining balance: ₱8,750.00'));
    });

    test('missing optional payment produces no receipt and excludes PII', () {
      final context = _context();
      expect(templates.paymentReceipt(context), isEmpty);
      for (final message in <String>[
        templates.paymentReminder(context, now: DateTime(2026, 7, 1)),
        templates.loanSummary(context),
        templates.scheduleSummary(context),
      ]) {
        expect(message, isNot(contains(context.borrower.nationalId)));
        expect(message, isNot(contains(context.borrower.phone)));
        expect(message, isNot(contains(context.borrower.dateOfBirth)));
        expect(message, isNot(contains(context.borrower.id)));
      }
    });
  });

  group('phone normalization', () {
    test('accepts supported Philippine formats', () {
      expect(
        PhilippinePhoneNumber.tryParse('0917 123 4567')?.e164,
        '+639171234567',
      );
      expect(
        PhilippinePhoneNumber.tryParse('639171234567')?.e164,
        '+639171234567',
      );
      expect(
        PhilippinePhoneNumber.tryParse('+63 (917) 123-4567')?.e164,
        '+639171234567',
      );
      expect(
        PhilippinePhoneNumber.tryParse('09171234567')?.masked,
        '+63 ••• ••• 4567',
      );
    });

    test('rejects missing or invalid numbers without guessing', () {
      expect(PhilippinePhoneNumber.tryParse(''), isNull);
      expect(PhilippinePhoneNumber.tryParse('0917123456'), isNull);
      expect(PhilippinePhoneNumber.tryParse('+15551234567'), isNull);
    });
  });

  test('currency and date formatting are borrower-facing and exact', () {
    expect(formatCurrency('467000.28'), '₱467,000.28');
    expect(formatCurrency('-500.00'), '-₱500.00');
    expect(formatDateShort('2026-08-05'), '8/5/2026');
  });

  test('action visibility follows selected local data', () {
    final full = availableSendToBorrowerActions(_context(withPayment: true));
    expect(full, contains(SendToBorrowerAction.paymentSchedule));
    expect(full, contains(SendToBorrowerAction.paymentReceipt));
    final noLoan = availableSendToBorrowerActions(
      BorrowerCommunicationContext(borrower: _borrower),
    );
    expect(noLoan, isNot(contains(SendToBorrowerAction.paymentSchedule)));
    expect(noLoan, isNot(contains(SendToBorrowerAction.paymentReceipt)));
  });

  test('SMS launch failure is returned without sending', () async {
    Uri? captured;
    final service = BorrowerCommunicationService(
      canLaunch: (uri) async {
        captured = uri;
        return false;
      },
      launch: (uri, {mode = LaunchMode.platformDefault}) async =>
          throw StateError('must not launch'),
    );
    final result = await service.openSmsDraft(
      PhilippinePhoneNumber.tryParse('09171234567')!,
      'Editable message',
    );
    expect(result, isFalse);
    expect(captured?.scheme, 'sms');
    expect(captured?.queryParameters['body'], 'Editable message');
  });

  testWidgets('message can be edited and copied before external action', (
    tester,
  ) async {
    String? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard =
                (call.arguments as Map<Object?, Object?>)['text'] as String;
          }
          return null;
        });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MessagePreviewDialog(initialMessage: 'Original')),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('borrower-message-editor')),
      'Edited',
    );
    await tester.tap(find.byKey(const Key('copy-edited-message')));
    await tester.pump();
    expect(clipboard, 'Edited');
  });

  testWidgets(
    'missing phone disables SMS but keeps general sharing available',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessagePreviewDialog(
              initialMessage: 'Message',
              smsEnabled: false,
            ),
          ),
        ),
      );
      final sms = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Continue to SMS'),
      );
      final share = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Share'),
      );
      expect(sms.onPressed, isNull);
      expect(share.onPressed, isNotNull);
    },
  );

  group('borrower PDFs', () {
    late Directory directory;
    late BorrowerDocumentService service;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'borrower-documents-test-',
      );
      service = BorrowerDocumentService(
        directoryProvider: () async => directory,
      );
    });
    tearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    for (final type in BorrowerDocumentType.values) {
      test('generates non-empty ${type.name} PDF offline', () async {
        final file = await service.generate(type, _context(withPayment: true));
        final bytes = await file.readAsBytes();
        expect(bytes.length, greaterThan(500));
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      });
    }
  });

  test('officer reminders are scheduled from local data without PII', () async {
    final directory = await Directory.systemTemp.createTemp('reminder-test-');
    final database = DatabaseService(
      dbPath: '${directory.path}${Platform.pathSeparator}reminders.db',
    );
    final db = await database.database;
    await db.insert('borrowers', {
      'id': _borrower.id,
      'first_name': _borrower.firstName,
      'last_name': _borrower.lastName,
      'national_id': 'enc_nat_id',
      'phone': _borrower.phone,
      'date_of_birth': _borrower.dateOfBirth,
      'status': _borrower.status,
      'created_at': _borrower.createdAt,
    });
    final repository = LocalLoanRepository(database);
    await repository.saveLoan(_context().loan!, syncStatus: 'pending');
    final notifications = _FakeLocalNotificationService();
    final scheduler = BorrowerDueReminderScheduler(
      repository,
      notifications,
      now: () => DateTime(2026, 8, 1, 8),
    );

    await scheduler.refresh();

    expect(notifications.scheduled, hasLength(3));
    for (final reminder in notifications.scheduled) {
      expect(reminder.path, '/loans/internal-loan-id/send');
      expect(reminder.title, isNot(contains(_borrower.firstName)));
      expect(reminder.body, isNot(contains(_borrower.phone)));
      expect(reminder.body, isNot(contains('₱')));
    }
    await database.close();
    await directory.delete(recursive: true);
  });
}

const _borrower = Borrower(
  id: 'internal-borrower-id',
  firstName: 'Ana',
  lastName: 'Santos',
  nationalId: 'SENSITIVE-ID-123',
  phone: '09171234567',
  dateOfBirth: '1990-01-01',
  status: 'Active',
  createdAt: '2026-01-01T00:00:00Z',
);

BorrowerCommunicationContext _context({
  String dueDate = '2026-08-05',
  String status = 'Scheduled',
  bool withPayment = false,
}) {
  final installment = Installment(
    id: 'internal-installment-id',
    loanId: 'internal-loan-id',
    installmentNumber: 1,
    dueDate: dueDate,
    expectedPayment: '1250.00',
    expectedInterest: '250.00',
    expectedPrincipal: '1000.00',
    expectedRemainingPrincipal: '8750.00',
    paidAmount: '0.00',
    status: status,
    createdAt: '2026-07-01T00:00:00Z',
  );
  final loan = Loan(
    id: 'internal-loan-id',
    requestId: 'LN-2026-0001',
    borrowerId: _borrower.id,
    createdByUserId: 'internal-officer',
    originalPrincipal: '10000.00',
    outstandingPrincipal: '8750.00',
    monthlyRate: '0.05',
    termMonths: 8,
    paymentsPerMonth: 1,
    numberOfPayments: 8,
    regularPaymentAmount: '1250.00',
    calculationMethod: 'fixed_periodic_reducing_balance',
    startDate: '2026-07-01',
    firstDueDate: dueDate,
    finalDueDate: '2027-02-05',
    status: 'Active',
    createdAt: '2026-07-01T00:00:00Z',
    installments: <Installment>[installment],
  );
  final payment = LoanPayment(
    id: 'internal-payment-id',
    requestId: 'local-request-1',
    loanId: loan.id,
    installmentId: installment.id,
    entryType: 'Payment',
    reversalOfPaymentId: null,
    amount: '1250.00',
    effectiveDate: '2026-08-05',
    note: 'PRIVATE OFFICER NOTE',
    createdAt: '2026-08-05T08:00:00Z',
    allocation: const PaymentAllocation(
      appliedInterest: '250.00',
      appliedPrincipal: '1000.00',
      unappliedCredit: '0.00',
      interestAfter: '0.00',
      principalAfter: '8750.00',
      overdueDays: 0,
    ),
  );
  return BorrowerCommunicationContext(
    borrower: _borrower,
    loan: loan,
    payment: withPayment ? payment : null,
    payments: withPayment ? <LoanPayment>[payment] : const <LoanPayment>[],
  );
}

class _ScheduledReminder {
  const _ScheduledReminder({
    required this.title,
    required this.body,
    required this.path,
  });
  final String title;
  final String body;
  final String path;
}

class _FakeLocalNotificationService extends LocalNotificationService {
  _FakeLocalNotificationService() : super(FlutterLocalNotificationsPlugin());

  final scheduled = <_ScheduledReminder>[];

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required String navigationPath,
    required ReminderCategory category,
  }) async {
    scheduled.add(
      _ScheduledReminder(title: title, body: body, path: navigationPath),
    );
  }

  @override
  Future<void> cancel(int id) async {}
}
