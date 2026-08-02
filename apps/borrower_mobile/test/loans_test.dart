import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/loans/data/loan_local_cache.dart';
import 'package:borrower_mobile/features/loans/data/loan_repository.dart';
import 'package:borrower_mobile/features/loans/loan_detail_screen.dart';
import 'package:borrower_mobile/features/loans/loans_screen.dart';
import 'package:borrower_mobile/features/loans/models/borrower_loan.dart';
import 'package:borrower_mobile/features/loans/providers/loans_provider.dart';

class FakeLoansApiClient implements ApiClient {
  final Map<String, dynamic> listResponse;
  final Map<String, dynamic> detailResponse;
  final bool shouldThrow;

  FakeLoansApiClient({
    required this.listResponse,
    required this.detailResponse,
    this.shouldThrow = false,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      if (shouldThrow) {
        throw Exception('Network error');
      }
      final String path = invocation.positionalArguments.first as String;
      if (path.contains('/schedule')) {
        return Future.value({
          'loanId': 'loan-123',
          'loanReference': 'LN-2026-000123',
          'items': [
            {
              'id': 'inst-1',
              'installmentNumber': 1,
              'dueDate': '2026-09-01T00:00:00.000',
              'expectedPayment': 1020.00,
              'expectedPrincipal': 1000.00,
              'expectedInterest': 20.00,
              'paidAmount': 0.00,
              'remainingBalance': 1020.00,
              'status': 'scheduled',
            }
          ],
          'totalInstallments': 1,
          'paidInstallmentsCount': 0,
        });
      }
      if (path.contains('/loans/loan-123')) {
        return Future.value(detailResponse);
      }
      return Future.value(listResponse);
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeLoanLocalCache implements LoanLocalCache {
  final Map<String, dynamic> _store = {};

  @override
  Future<BorrowerLoanListResponse?> getCachedLoansList(
    String borrowerAccountId, {
    String? statusFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    final status = statusFilter?.toLowerCase() ?? 'all';
    final key = 'list_${borrowerAccountId}_$status';
    return _store[key] as BorrowerLoanListResponse?;
  }

  @override
  Future<void> saveCachedLoansList(
    String borrowerAccountId,
    BorrowerLoanListResponse response, {
    String? statusFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    final status = statusFilter?.toLowerCase() ?? 'all';
    final key = 'list_${borrowerAccountId}_$status';
    _store[key] = response;
  }

  @override
  Future<BorrowerLoanDetail?> getCachedLoanDetail(
    String borrowerAccountId,
    String loanId,
  ) async {
    final key = 'detail_${borrowerAccountId}_$loanId';
    return _store[key] as BorrowerLoanDetail?;
  }

  @override
  Future<void> saveCachedLoanDetail(
    String borrowerAccountId,
    BorrowerLoanDetail detail,
  ) async {
    final key = 'detail_${borrowerAccountId}_${detail.id}';
    _store[key] = detail;
  }

  @override
  Future<BorrowerInstallmentSchedule?> getCachedLoanSchedule(
    String borrowerAccountId,
    String loanId,
  ) async {
    final key = 'schedule_${borrowerAccountId}_$loanId';
    return _store[key] as BorrowerInstallmentSchedule?;
  }

  @override
  Future<void> saveCachedLoanSchedule(
    String borrowerAccountId,
    BorrowerInstallmentSchedule schedule,
  ) async {
    final key = 'schedule_${borrowerAccountId}_${schedule.loanId}';
    _store[key] = schedule;
  }

  @override
  Future<void> clearAllCachedLoans() async {
    _store.clear();
  }
}

void main() {
  final sampleListJson = {
    'items': [
      {
        'id': 'loan-123',
        'loanReference': 'LN-2026-000123',
        'status': 'active',
        'principalAmount': 10000.0,
        'totalRepayable': 12000.0,
        'amountPaid': 3500.0,
        'outstandingBalance': 8500.0,
        'installmentAmount': 1000.0,
        'paymentFrequency': 'monthly',
        'startDate': '2026-05-01T00:00:00.000Z',
        'maturityDate': '2027-05-01T00:00:00.000Z',
        'nextDueDate': '2026-08-15T00:00:00.000Z',
        'nextPaymentAmount': 1000.0,
        'isOverdue': false,
        'overdueAmount': 0.0,
        'updatedAt': '2026-08-02T10:00:00.000Z',
      }
    ],
    'total': 1,
    'offset': 0,
    'limit': 20,
  };

  final sampleDetailJson = {
    'id': 'loan-123',
    'loanReference': 'LN-2026-000123',
    'status': 'active',
    'financialSummary': {
      'principalAmount': 10000.0,
      'interestAmount': 2000.0,
      'feesAmount': 0.0,
      'totalRepayable': 12000.0,
      'amountPaid': 3500.0,
      'outstandingBalance': 8500.0,
      'overdueAmount': 0.0,
    },
    'terms': {
      'paymentFrequency': 'monthly',
      'installmentCount': 12,
      'installmentAmount': 1000.0,
      'interestRate': 3.0,
      'startDate': '2026-05-01T00:00:00.000Z',
      'maturityDate': '2027-05-01T00:00:00.000Z',
    },
    'nextInstallment': {
      'installmentNumber': 5,
      'dueDate': '2026-08-15T00:00:00.000Z',
      'amountDue': 1000.0,
      'amountPaid': 0.0,
      'remainingAmount': 1000.0,
      'status': 'upcoming',
    },
    'lastUpdated': '2026-08-02T10:00:00.000Z',
  };

  group('BorrowerLoan Models Tests', () {
    test('deserialize and serialize BorrowerLoanListResponse', () {
      final response = BorrowerLoanListResponse.fromJson(sampleListJson);
      expect(response.total, 1);
      expect(response.items.first.loanReference, 'LN-2026-000123');
      expect(response.items.first.outstandingBalance, 8500.0);

      final json = response.toJson();
      expect(json['total'], 1);
    });

    test('deserialize and serialize BorrowerLoanDetail', () {
      final detail = BorrowerLoanDetail.fromJson(sampleDetailJson);
      expect(detail.id, 'loan-123');
      expect(detail.financialSummary.principalAmount, 10000.0);
      expect(detail.terms.installmentCount, 12);
      expect(detail.nextInstallment?.installmentNumber, 5);

      final json = detail.toJson();
      expect(json['id'], 'loan-123');
    });
  });

  group('Cache Isolation Tests', () {
    test('cache enforces borrower account identity isolation', () async {
      final fakeCache = FakeLoanLocalCache();
      final responseA = BorrowerLoanListResponse.fromJson(sampleListJson);

      await fakeCache.saveCachedLoansList('account-A', responseA);

      final cachedA = await fakeCache.getCachedLoansList('account-A');
      final cachedB = await fakeCache.getCachedLoansList('account-B');

      expect(cachedA, isNotNull);
      expect(cachedB, isNull);
    });
  });

  group('LoanRepository Tests', () {
    test('online fetch saves data to cache', () async {
      final api = FakeLoansApiClient(
        listResponse: sampleListJson,
        detailResponse: sampleDetailJson,
      );
      final cache = FakeLoanLocalCache();
      final repo = LoanRepository(apiClient: api, localCache: cache);

      final list = await repo.getLoans(borrowerAccountId: 'acct-1');
      expect(list.items.length, 1);

      final cached = await cache.getCachedLoansList('acct-1');
      expect(cached, isNotNull);
      expect(cached?.items.first.loanReference, 'LN-2026-000123');
    });

    test('network failure returns cached data', () async {
      final api = FakeLoansApiClient(
        listResponse: sampleListJson,
        detailResponse: sampleDetailJson,
        shouldThrow: true,
      );
      final cache = FakeLoanLocalCache();
      await cache.saveCachedLoansList(
        'acct-1',
        BorrowerLoanListResponse.fromJson(sampleListJson),
      );

      final repo = LoanRepository(apiClient: api, localCache: cache);
      final list = await repo.getLoans(borrowerAccountId: 'acct-1');
      expect(list.items.first.loanReference, 'LN-2026-000123');
    });
  });

  group('LoansScreen Widget Tests', () {
    testWidgets('renders loan list cards correctly', (tester) async {
      final api = FakeLoansApiClient(
        listResponse: sampleListJson,
        detailResponse: sampleDetailJson,
      );
      final cache = FakeLoanLocalCache();
      final repo = LoanRepository(apiClient: api, localCache: cache);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loansListNotifierProvider.overrideWith(
              (ref) => LoansListNotifier(
                repository: repo,
                borrowerAccountId: 'account-123',
              ),
            ),
          ],
          child: const MaterialApp(
            home: LoansScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My Loans'), findsOneWidget);
      expect(find.text('LN-2026-000123'), findsOneWidget);
      expect(find.text('₱ 8,500.00'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('direct My Loans back returns to dashboard', (tester) async {
      final api = FakeLoansApiClient(
        listResponse: sampleListJson,
        detailResponse: sampleDetailJson,
      );
      final cache = FakeLoanLocalCache();
      final repo = LoanRepository(apiClient: api, localCache: cache);
      final router = GoRouter(
        initialLocation: '/loans',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Dashboard Home')),
          ),
          GoRoute(
            path: '/loans',
            builder: (_, __) => const LoansScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loansListNotifierProvider.overrideWith(
              (ref) => LoansListNotifier(
                repository: repo,
                borrowerAccountId: 'account-123',
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back to dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Home'), findsOneWidget);
    });
  });

  group('LoanDetailScreen Widget Tests', () {
    testWidgets('renders loan detail screen correctly', (tester) async {
      final api = FakeLoansApiClient(
        listResponse: sampleListJson,
        detailResponse: sampleDetailJson,
      );
      final cache = FakeLoanLocalCache();
      final repo = LoanRepository(apiClient: api, localCache: cache);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loanDetailNotifierProvider('loan-123').overrideWith(
              (ref) => LoanDetailNotifier(
                repository: repo,
                borrowerAccountId: 'account-123',
                loanId: 'loan-123',
              ),
            ),
            loanScheduleNotifierProvider('loan-123').overrideWith(
              (ref) => LoanScheduleNotifier(
                repository: repo,
                borrowerAccountId: 'account-123',
                loanId: 'loan-123',
              ),
            ),
          ],
          child: const MaterialApp(
            home: LoanDetailScreen(loanId: 'loan-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LN-2026-000123'), findsNWidgets(2));
      expect(find.text('Financial Summary'), findsOneWidget);
      expect(find.text('₱ 10,000.00'), findsOneWidget);
      expect(find.text('₱ 12,000.00'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Loan Terms'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Loan Terms'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Next Payment Preview'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Next Payment Preview'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Installment Schedule'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Installment Schedule'), findsOneWidget);
    });
  });
}
