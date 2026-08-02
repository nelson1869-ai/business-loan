import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/core/auth/auth_state.dart';
import 'package:borrower_mobile/core/storage/secure_token_storage.dart';
import 'package:borrower_mobile/features/dashboard/data/dashboard_local_cache.dart';
import 'package:borrower_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:borrower_mobile/features/dashboard/models/borrower_dashboard.dart';
import 'package:borrower_mobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:borrower_mobile/features/loans/data/loan_local_cache.dart';
import 'package:borrower_mobile/features/loans/data/loan_repository.dart';
import 'package:borrower_mobile/features/loans/models/borrower_loan.dart';
import 'package:borrower_mobile/features/loans/providers/loans_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      return Future<Map<String, dynamic>>.error(Exception('offline'));
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeTokenStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SwitchableAuthNotifier extends AuthNotifier {
  _SwitchableAuthNotifier()
      : super(
          storage: _FakeTokenStorage(),
          apiClient: _OfflineApiClient(),
          checkAuthOnInit: false,
        );

  void authenticate(String accountId) {
    state = AuthState.authenticated(
      borrowerAccountId: accountId,
      borrowerId: 'profile-$accountId',
    );
  }

  void unauthenticate() {
    state = AuthState.unauthenticated();
  }
}

const _dashboardAJson = <String, dynamic>{
  'borrower': {'id': 'profile-A', 'firstName': 'Alice', 'lastName': 'A'},
  'summary': {
    'activeLoanCount': 0,
    'totalOutstandingBalance': 0.0,
    'nextPaymentAmount': 0.0,
    'nextDueDate': null,
    'overdueAmount': 0.0,
    'loanStatus': 'none',
    'paymentStatus': 'current',
  },
  'recentPayment': null,
  'lastUpdated': '2026-08-02T10:00:00.000Z',
};

const _loanListAJson = <String, dynamic>{
  'items': [
    {
      'id': 'loan-A',
      'loanReference': 'A-LOAN',
      'status': 'active',
      'principalAmount': 100.0,
      'totalRepayable': 110.0,
      'amountPaid': 0.0,
      'outstandingBalance': 110.0,
      'installmentAmount': 10.0,
      'paymentFrequency': 'monthly',
      'startDate': '2026-01-01T00:00:00.000Z',
      'maturityDate': '2027-01-01T00:00:00.000Z',
      'nextDueDate': '2026-09-01T00:00:00.000Z',
      'nextPaymentAmount': 10.0,
      'isOverdue': false,
      'overdueAmount': 0.0,
      'updatedAt': '2026-08-02T10:00:00.000Z',
    }
  ],
  'total': 1,
  'offset': 0,
  'limit': 20,
};

const _loanDetailAJson = <String, dynamic>{
  'id': 'loan-A',
  'loanReference': 'A-LOAN',
  'status': 'active',
  'financialSummary': {
    'principalAmount': 100.0,
    'interestAmount': 10.0,
    'feesAmount': 0.0,
    'totalRepayable': 110.0,
    'amountPaid': 0.0,
    'outstandingBalance': 110.0,
    'overdueAmount': 0.0,
  },
  'terms': {
    'paymentFrequency': 'monthly',
    'installmentCount': 11,
    'installmentAmount': 10.0,
    'interestRate': 10.0,
    'startDate': '2026-01-01T00:00:00.000Z',
    'maturityDate': '2027-01-01T00:00:00.000Z',
  },
  'nextInstallment': null,
  'lastUpdated': '2026-08-02T10:00:00.000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('dashboard cache is isolated by borrower account', () async {
    final cache = DashboardLocalCache();
    final dashboardA = BorrowerDashboard.fromJson(_dashboardAJson);

    await cache.saveCachedDashboard(
      borrowerAccountId: 'account-A',
      dashboard: dashboardA,
    );

    expect(
      (await cache.getCachedDashboard(borrowerAccountId: 'account-A'))
          ?.borrower
          .firstName,
      'Alice',
    );
    expect(
      await cache.getCachedDashboard(borrowerAccountId: 'account-B'),
      isNull,
    );
  });

  test('legacy global dashboard is deleted and never returned', () async {
    FlutterSecureStorage.setMockInitialValues({
      'cached_borrower_dashboard':
          '{"borrower":{"id":"unknown","firstName":"Legacy"}}',
    });
    const storage = FlutterSecureStorage();
    final cache = DashboardLocalCache(storage: storage);

    expect(
      await cache.getCachedDashboard(borrowerAccountId: 'account-B'),
      isNull,
    );
    expect(await storage.read(key: 'cached_borrower_dashboard'), isNull);
  });

  test('empty borrower identity is rejected without cache access', () async {
    final dashboardCache = DashboardLocalCache();
    final loanCache = LoanLocalCache();

    expect(
      () => dashboardCache.getCachedDashboard(borrowerAccountId: '  '),
      throwsArgumentError,
    );
    expect(
      () => dashboardCache.saveCachedDashboard(
        borrowerAccountId: '',
        dashboard: BorrowerDashboard.fromJson(_dashboardAJson),
      ),
      throwsArgumentError,
    );
    expect(
      () => loanCache.getCachedLoansList(''),
      throwsArgumentError,
    );
    expect(
      () => loanCache.getCachedLoanDetail('', 'loan-A'),
      throwsArgumentError,
    );
  });

  test('loan list and detail caches are isolated by borrower account',
      () async {
    final cache = LoanLocalCache();
    final list = BorrowerLoanListResponse.fromJson(_loanListAJson);
    final detail = BorrowerLoanDetail.fromJson(_loanDetailAJson);

    await cache.saveCachedLoansList('account-A', list);
    await cache.saveCachedLoanDetail('account-A', detail);

    expect((await cache.getCachedLoansList('account-A'))?.total, 1);
    expect(await cache.getCachedLoansList('account-B'), isNull);
    expect(
      (await cache.getCachedLoanDetail('account-A', 'loan-A'))?.id,
      'loan-A',
    );
    expect(
      await cache.getCachedLoanDetail('account-B', 'loan-A'),
      isNull,
    );
  });

  test('offline account switch resets all feature providers', () async {
    final dashboardCache = DashboardLocalCache();
    final loanCache = LoanLocalCache();
    await dashboardCache.saveCachedDashboard(
      borrowerAccountId: 'account-A',
      dashboard: BorrowerDashboard.fromJson(_dashboardAJson),
    );
    await loanCache.saveCachedLoansList(
      'account-A',
      BorrowerLoanListResponse.fromJson(_loanListAJson),
    );
    await loanCache.saveCachedLoanDetail(
      'account-A',
      BorrowerLoanDetail.fromJson(_loanDetailAJson),
    );

    final auth = _SwitchableAuthNotifier()..authenticate('account-A');
    final api = _OfflineApiClient();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith((ref) => auth),
        dashboardRepositoryProvider.overrideWithValue(
          DashboardRepository(apiClient: api, localCache: dashboardCache),
        ),
        loanRepositoryProvider.overrideWithValue(
          LoanRepository(apiClient: api, localCache: loanCache),
        ),
      ],
    );
    addTearDown(container.dispose);

    final dashboardA = container.read(dashboardNotifierProvider.notifier);
    final loansA = container.read(loansListNotifierProvider.notifier);
    final detailA =
        container.read(loanDetailNotifierProvider('loan-A').notifier);
    await Future.wait([
      dashboardA.loadDashboard(),
      loansA.loadLoans(),
      detailA.loadDetail(),
    ]);
    expect(dashboardA.state.dashboard?.borrower.firstName, 'Alice');
    expect(loansA.state.items.single.loanReference, 'A-LOAN');
    expect(detailA.state.detail?.loanReference, 'A-LOAN');

    auth.unauthenticate();
    auth.authenticate('account-B');
    await Future<void>.delayed(Duration.zero);

    final dashboardB = container.read(dashboardNotifierProvider.notifier);
    final loansB = container.read(loansListNotifierProvider.notifier);
    final detailB =
        container.read(loanDetailNotifierProvider('loan-A').notifier);
    await Future.wait([
      dashboardB.loadDashboard(),
      loansB.loadLoans(),
      detailB.loadDetail(),
    ]);

    expect(dashboardB, isNot(same(dashboardA)));
    expect(loansB, isNot(same(loansA)));
    expect(detailB, isNot(same(detailA)));
    expect(dashboardB.state.dashboard, isNull);
    expect(loansB.state.items, isEmpty);
    expect(detailB.state.detail, isNull);
    expect(dashboardB.state.errorMessage, isNotNull);
    expect(loansB.state.errorMessage, isNotNull);
    expect(detailB.state.errorMessage, isNotNull);
  });
}
