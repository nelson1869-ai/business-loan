import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lending_nelson/core/database/database_service.dart';
import 'package:lending_nelson/core/security/encryption_service.dart';
import 'package:lending_nelson/features/dashboard/data/admin_assistant_repository.dart';
import 'package:lending_nelson/features/dashboard/data/local_admin_assistant_service.dart';
import 'package:lending_nelson/features/dashboard/pages/admin_assistant_page.dart';

void main() {
  testWidgets(
    'admin assistant shows suggestions and verified response source',
    (tester) async {
      await _pump(tester, _verifiedReply);

      expect(find.text('Who has not paid today?'), findsOneWidget);
      await tester.tap(find.text('Who has not paid today?'));
      await tester.pump();
      expect(find.textContaining('Checking verified records'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(
        find.text('Two installments remain unpaid today.'),
        findsOneWidget,
      );
      expect(find.textContaining('Verified database records'), findsOneWidget);
      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.text('Verified local answer'), findsOneWidget);
    },
  );

  testWidgets('assistant labels AI-enhanced responses', (tester) async {
    await _pump(
      tester,
      const AdminAssistantReply(
        answer: 'Verified summary with optional wording enhancement.',
        records: [],
        asOf: '2026-07-28',
        source: 'Verified database records',
        disclaimer: 'Read-only assistant.',
        answerSource: 'ai_enhanced',
        aiUsed: true,
        aiStatus: 'enhanced',
      ),
    );

    await tester.tap(find.text('How much was collected this month?'));
    await tester.pumpAndSettle();

    expect(find.text('AI-enhanced answer'), findsOneWidget);
  });

  testWidgets('offline answer shows synchronization and retry controls', (
    tester,
  ) async {
    await _pump(
      tester,
      AdminAssistantReply(
        answer: 'Offline verified answer.',
        records: const [],
        asOf: '2026-07-28',
        source: 'Synchronized local database',
        disclaimer: 'Offline result may be stale.',
        answerSource: 'offline',
        lastSyncedAt: DateTime.utc(2026, 7, 28, 10),
      ),
    );

    await tester.tap(find.text('How much was collected this month?'));
    await tester.pumpAndSettle();

    expect(find.text('Offline local answer'), findsOneWidget);
    expect(find.textContaining('Last synchronized:'), findsOneWidget);
    expect(find.text('Retry server connection'), findsOneWidget);
  });

  testWidgets('selected borrower context is visible and clearable', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminAssistantReply(
        answer: 'Which borrower do you mean?',
        records: [],
        asOf: '2026-07-28',
        source: 'Verified database records',
        disclaimer: 'Read-only assistant.',
        clarification: [
          BorrowerClarificationOption(
            borrowerId: 'borrower-1',
            displayName: 'Alex Morgan',
            maskedReference: 'Borrower ••••0001',
          ),
          BorrowerClarificationOption(
            borrowerId: 'borrower-2',
            displayName: 'Sam Morgan',
            maskedReference: 'Borrower ••••0002',
          ),
        ],
      ),
    );

    await tester.tap(find.text('How much was collected this month?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Morgan'));
    await tester.pumpAndSettle();

    expect(find.text('Asking about Alex Morgan'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Asking about Alex Morgan'), findsNothing);
  });

  testWidgets('financial metrics render as structured cards', (tester) async {
    await _pump(
      tester,
      const AdminAssistantReply(
        answer: 'Verified portfolio summary.',
        records: [],
        asOf: '2026-07-28',
        source: 'Verified database records',
        disclaimer: 'Read-only assistant.',
        currency: 'PHP',
        metrics: {'outstandingBalance': '12500.00', 'activeLoans': '3'},
      ),
    );

    await tester.tap(find.text('How much was collected this month?'));
    await tester.pumpAndSettle();

    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('₱12,500.00'), findsOneWidget);
    expect(find.text('Active loans'), findsOneWidget);
  });

  testWidgets('load more requests the next bounded page', (tester) async {
    final repository = _FakeAdminAssistantRepository(
      const AdminAssistantReply(
        answer: 'More borrower records are available.',
        records: [],
        asOf: '2026-07-28',
        source: 'Verified database records',
        disclaimer: 'Read-only assistant.',
        intent: 'borrower_directory',
        totalMatchingCount: 75,
        hasMore: true,
        nextOffset: 50,
      ),
    );
    await _pumpWithRepository(tester, repository);

    await tester.tap(find.text('How much was collected this month?'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Load more'));
    await tester.pumpAndSettle();

    expect(repository.offsets, containsAllInOrder([0, 50]));
  });

  testWidgets('small screen supports 200 percent text scaling', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAssistantRepositoryProvider.overrideWithValue(
            _FakeAdminAssistantRepository(_verifiedReply),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AdminAssistantPage(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Admin Assistant'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, AdminAssistantReply reply) async {
  await _pumpWithRepository(tester, _FakeAdminAssistantRepository(reply));
}

Future<void> _pumpWithRepository(
  WidgetTester tester,
  _FakeAdminAssistantRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAssistantRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: AdminAssistantPage()),
    ),
  );
}

class _FakeAdminAssistantRepository extends AdminAssistantRepository {
  _FakeAdminAssistantRepository(this.reply)
    : super(
        Dio(),
        LocalAdminAssistantService(
          DatabaseService(),
          EncryptionService(const FlutterSecureStorage()),
        ),
      );

  final AdminAssistantReply reply;
  final List<int> offsets = [];

  @override
  Future<AdminAssistantReply> ask(
    String message, {
    String? selectedBorrowerId,
    int offset = 0,
  }) async {
    offsets.add(offset);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return reply;
  }
}

const _verifiedReply = AdminAssistantReply(
  answer: 'Two installments remain unpaid today.',
  records: [
    AdminAssistantRecord(
      borrowerId: 'borrower-1',
      borrowerName: 'Alex Morgan',
      loanId: 'loan-1',
      amountDue: '300.00',
      dueDate: '2026-07-28',
      status: 'Scheduled',
    ),
  ],
  asOf: '2026-07-28',
  source: 'Verified database records',
  disclaimer: 'Read-only assistant.',
);
