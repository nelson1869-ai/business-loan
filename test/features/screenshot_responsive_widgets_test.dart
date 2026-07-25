import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/borrowers/widgets/borrower_payment_behavior_card.dart';
import 'package:lending_nelson/features/borrowers/widgets/tabs/payments_tab_view.dart';
import 'package:lending_nelson/features/dashboard/widgets/notifications/notification_header_card.dart';
import 'package:lending_nelson/features/dashboard/widgets/reports/reports_header_card.dart';
import 'package:lending_nelson/features/dashboard/widgets/reports/reports_trend_charts.dart';

Widget _testApp({
  required Widget child,
  required Size size,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: Colors.teal,
    ),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('payment behavior card does not overflow narrow large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        size: const Size(320, 568),
        textScale: 1.5,
        brightness: Brightness.dark,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: BorrowerPaymentBehaviorCard(loans: []),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text('Payment Punctuality & Behavior Analytics'),
      findsOneWidget,
    );
  });

  testWidgets('notification header wraps actions at phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _testApp(
        size: const Size(360, 640),
        textScale: 1.3,
        brightness: Brightness.dark,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: NotificationHeaderCard(
            searchController: controller,
            onSearchChanged: (_) {},
            onMarkAllRead: () {},
            unreadCount: 0,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('0 Unread'), findsOneWidget);
  });

  testWidgets('empty payments state remains scrollable in a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        size: const Size(360, 220),
        textScale: 1.5,
        child: const SizedBox(height: 150, child: PaymentsTabView(loans: [])),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('reports header actions wrap at screenshot width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        size: const Size(360, 640),
        brightness: Brightness.dark,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ReportsHeaderCard(
            selectedPeriod: 'This Month',
            onPeriodChanged: (_) {},
            isOnline: true,
            report: null,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
  });

  testWidgets('monthly report chart does not present fabricated values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(
        size: const Size(360, 800),
        brightness: Brightness.dark,
        child: const ReportsTrendCharts(),
      ),
    );

    expect(find.text('Monthly Trend Unavailable'), findsOneWidget);
    expect(find.textContaining('₱52k'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
