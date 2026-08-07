import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/notifications/data/notifications_repository.dart';
import 'package:borrower_mobile/features/notifications/models/borrower_notification.dart';
import 'package:borrower_mobile/features/notifications/notifications_screen.dart';
import 'package:borrower_mobile/features/notifications/providers/notifications_provider.dart';

class FakeApiClient implements ApiClient {
  final List<dynamic> notificationsData;
  final int unreadCountData;
  final bool shouldThrow;

  FakeApiClient({
    this.notificationsData = const [],
    this.unreadCountData = 0,
    this.shouldThrow = false,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getList) {
      if (shouldThrow) throw Exception('Network connection error');
      return Future.value(notificationsData);
    }
    if (invocation.memberName == #get) {
      if (shouldThrow) throw Exception('Network connection error');
      return Future.value({'unreadCount': unreadCountData});
    }
    if (invocation.memberName == #post) {
      if (shouldThrow) throw Exception('Network connection error');
      return Future.value({'message': 'success'});
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  final sampleNotifications = [
    {
      'id': 'notif-1',
      'borrowerId': 'borr-1',
      'title': 'Payment Received',
      'message': 'We received your payment of ₱1,500.00.',
      'notificationType': 'payment_receipt',
      'metadataJson': '{"receiptId":"rcpt-100","entityType":"receipt"}',
      'isRead': false,
      'createdAt': '2026-08-07T10:00:00.000Z',
    },
    {
      'id': 'notif-2',
      'borrowerId': 'borr-1',
      'title': 'Loan Activated',
      'message': 'Your loan is now active.',
      'notificationType': 'loan_activated',
      'metadataJson': '{"loanId":"loan-200","entityType":"loan"}',
      'isRead': true,
      'createdAt': '2026-08-06T09:00:00.000Z',
    },
    {
      'id': 'notif-3',
      'borrowerId': 'borr-1',
      'title': 'Custom Event',
      'message': 'Unknown notification type test.',
      'notificationType': 'unknown_future_type',
      'metadataJson': null,
      'isRead': true,
      'createdAt': '2026-08-05T08:00:00.000Z',
    },
  ];

  group('BorrowerNotificationItem Model Tests', () {
    test('deserializes JSON correctly and parses metadata', () {
      final item = BorrowerNotificationItem.fromJson(sampleNotifications[0]);
      expect(item.id, 'notif-1');
      expect(item.title, 'Payment Received');
      expect(item.notificationType, 'payment_receipt');
      expect(item.receiptId, 'rcpt-100');
      expect(item.entityType, 'receipt');
      expect(item.isRead, false);
    });

    test('handles malformed metadataJson gracefully', () {
      final item = BorrowerNotificationItem(
        id: '1',
        borrowerId: 'b1',
        title: 'Test',
        message: 'Test message',
        notificationType: 'general',
        metadataJson: 'invalid-json{',
        isRead: false,
        createdAt: DateTime.now(),
      );
      expect(item.metadata, {});
      expect(item.receiptId, null);
      expect(item.loanId, null);
    });
  });

  group('NotificationsScreen Widget Tests', () {
    testWidgets('renders empty state when no notifications exist',
        (tester) async {
      final fakeApi = FakeApiClient(notificationsData: [], unreadCountData: 0);
      final repo = NotificationsRepository(apiClient: fakeApi);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(
        find.text(
          'We will notify you about payment receipts, loan updates, and account alerts here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders list of notifications with unread/read indicators',
        (tester) async {
      final fakeApi = FakeApiClient(
        notificationsData: sampleNotifications,
        unreadCountData: 1,
      );
      final repo = NotificationsRepository(apiClient: fakeApi);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment Received'), findsOneWidget);
      expect(find.text('Loan Activated'), findsOneWidget);
      expect(find.text('Custom Event'), findsOneWidget);
      expect(find.byTooltip('Mark all as read'), findsOneWidget);
    });

    testWidgets('renders unknown notification type safely without crashing',
        (tester) async {
      final fakeApi = FakeApiClient(
        notificationsData: [sampleNotifications[2]],
        unreadCountData: 0,
      );
      final repo = NotificationsRepository(apiClient: fakeApi);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Event'), findsOneWidget);
      expect(find.text('Unknown notification type test.'), findsOneWidget);

      // Tap unknown item
      await tester.tap(find.text('Custom Event'));
      await tester.pumpAndSettle();

      // No crash, screen remains intact
      expect(find.text('Custom Event'), findsOneWidget);
    });

    testWidgets('renders error state on network failure with retry button',
        (tester) async {
      final fakeApi = FakeApiClient(shouldThrow: true);
      final repo = NotificationsRepository(apiClient: fakeApi);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load notifications'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
