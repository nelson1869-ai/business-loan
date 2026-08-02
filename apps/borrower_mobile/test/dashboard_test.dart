import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/dashboard/data/dashboard_local_cache.dart';
import 'package:borrower_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:borrower_mobile/features/dashboard/dashboard_screen.dart';
import 'package:borrower_mobile/features/dashboard/models/borrower_dashboard.dart';
import 'package:borrower_mobile/features/dashboard/providers/dashboard_provider.dart';

class FakeApiClient implements ApiClient {
  final Map<String, dynamic> responseData;
  final bool shouldThrow;

  FakeApiClient({required this.responseData, this.shouldThrow = false});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      if (shouldThrow) {
        throw Exception('Network connection failed');
      }
      return Future.value(responseData);
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeDashboardLocalCache implements DashboardLocalCache {
  BorrowerDashboard? cached;

  @override
  Future<BorrowerDashboard?> getCachedDashboard({
    required String borrowerAccountId,
  }) async =>
      cached;

  @override
  Future<void> saveCachedDashboard({
    required String borrowerAccountId,
    required BorrowerDashboard dashboard,
  }) async {
    cached = dashboard;
  }

  @override
  Future<void> clearCachedDashboard({
    required String borrowerAccountId,
  }) async {
    cached = null;
  }

  @override
  Future<void> clearAllCachedDashboards() async {
    cached = null;
  }
}

void main() {
  final sampleJson = {
    'borrower': {
      'id': 'bor-123',
      'firstName': 'Maria',
      'lastName': 'Santos',
    },
    'summary': {
      'activeLoanCount': 1,
      'totalOutstandingBalance': 12500.50,
      'nextPaymentAmount': 1500.00,
      'nextDueDate': '2026-08-20T00:00:00.000Z',
      'overdueAmount': 0.0,
      'loanStatus': 'active',
      'paymentStatus': 'current',
    },
    'recentPayment': {
      'id': 'pay-456',
      'amount': 1500.00,
      'effectiveDate': '2026-07-20T00:00:00.000Z',
      'entryType': 'Payment',
      'receiptNumber': 'RCPT-PAY456',
    },
    'lastUpdated': '2026-08-02T10:00:00.000Z',
  };

  group('BorrowerDashboard Model Tests', () {
    test('deserialize and serialize BorrowerDashboard correctly', () {
      final dashboard = BorrowerDashboard.fromJson(sampleJson);
      expect(dashboard.borrower.id, 'bor-123');
      expect(dashboard.borrower.firstName, 'Maria');
      expect(dashboard.borrower.lastName, 'Santos');
      expect(dashboard.summary.activeLoanCount, 1);
      expect(dashboard.summary.totalOutstandingBalance, 12500.50);
      expect(dashboard.summary.nextPaymentAmount, 1500.00);
      expect(dashboard.recentPayment?.receiptNumber, 'RCPT-PAY456');
      expect(dashboard.isFromCache, false);

      final json = dashboard.toJson();
      expect(json['borrower']['firstName'], 'Maria');
      expect(json['summary']['totalOutstandingBalance'], 12500.50);
    });

    test('deserializes decimal and count values returned as strings', () {
      final stringNumericJson = {
        ...sampleJson,
        'summary': {
          ...sampleJson['summary'] as Map<String, dynamic>,
          'activeLoanCount': '1',
          'totalOutstandingBalance': '12500.50',
          'nextPaymentAmount': '1500.00',
          'overdueAmount': '0.00',
        },
        'recentPayment': {
          ...sampleJson['recentPayment'] as Map<String, dynamic>,
          'amount': '1500.00',
        },
      };

      final dashboard = BorrowerDashboard.fromJson(stringNumericJson);

      expect(dashboard.summary.activeLoanCount, 1);
      expect(dashboard.summary.totalOutstandingBalance, 12500.50);
      expect(dashboard.summary.nextPaymentAmount, 1500.00);
      expect(dashboard.summary.overdueAmount, 0.0);
      expect(dashboard.recentPayment?.amount, 1500.00);
    });
  });

  group('DashboardRepository Tests', () {
    test('fetch online dashboard saves to cache', () async {
      final fakeApi = FakeApiClient(responseData: sampleJson);
      final fakeCache = FakeDashboardLocalCache();
      final repository = DashboardRepository(
        apiClient: fakeApi,
        localCache: fakeCache,
      );

      final dashboard = await repository.getDashboard(
        borrowerAccountId: 'account-123',
      );
      expect(dashboard.borrower.firstName, 'Maria');
      expect(dashboard.isFromCache, false);
      expect(fakeCache.cached, isNotNull);
      expect(fakeCache.cached?.borrower.firstName, 'Maria');
    });

    test('network failure returns cached dashboard with isFromCache true',
        () async {
      final fakeApi =
          FakeApiClient(responseData: sampleJson, shouldThrow: true);
      final fakeCache = FakeDashboardLocalCache();
      fakeCache.cached = BorrowerDashboard.fromJson(sampleJson);

      final repository = DashboardRepository(
        apiClient: fakeApi,
        localCache: fakeCache,
      );

      final dashboard = await repository.getDashboard(
        borrowerAccountId: 'account-123',
      );
      expect(dashboard.borrower.firstName, 'Maria');
      expect(dashboard.isFromCache, true);
    });

    test('network failure with no cache rethrows exception', () async {
      final fakeApi =
          FakeApiClient(responseData: sampleJson, shouldThrow: true);
      final fakeCache = FakeDashboardLocalCache();

      final repository = DashboardRepository(
        apiClient: fakeApi,
        localCache: fakeCache,
      );

      expect(
        () => repository.getDashboard(borrowerAccountId: 'account-123'),
        throwsException,
      );
    });
  });

  group('DashboardScreen Widget Tests', () {
    testWidgets('renders online borrower dashboard correctly', (tester) async {
      final fakeApi = FakeApiClient(responseData: sampleJson);
      final fakeCache = FakeDashboardLocalCache();
      final repository = DashboardRepository(
        apiClient: fakeApi,
        localCache: fakeCache,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardNotifierProvider.overrideWith(
              (ref) => DashboardNotifier(
                repository: repository,
                borrowerAccountId: 'account-123',
              ),
            ),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hello, Maria Santos'), findsOneWidget);
      expect(find.text('₱ 12,500.50'), findsOneWidget);
      expect(find.text('₱ 1,500.00'), findsNWidgets(2));
      expect(find.text('Receipt: RCPT-PAY456'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('My Loans'), 100);
      expect(find.text('My Loans'), findsOneWidget);
    });

    testWidgets('renders offline banner when data is cached', (tester) async {
      final fakeApi =
          FakeApiClient(responseData: sampleJson, shouldThrow: true);
      final fakeCache = FakeDashboardLocalCache();
      fakeCache.cached = BorrowerDashboard.fromJson(sampleJson);
      final repository = DashboardRepository(
        apiClient: fakeApi,
        localCache: fakeCache,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardNotifierProvider.overrideWith(
              (ref) => DashboardNotifier(
                repository: repository,
                borrowerAccountId: 'account-123',
              ),
            ),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Offline Mode'), findsOneWidget);
      expect(find.text('Hello, Maria Santos'), findsOneWidget);
    });
  });
}
