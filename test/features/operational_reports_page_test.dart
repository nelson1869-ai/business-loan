import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lending_nelson/core/security/officer_session.dart';
import 'package:lending_nelson/core/widgets/online_required_banner.dart';
import 'package:lending_nelson/features/accounting/domain/journal_entry.dart';
import 'package:lending_nelson/features/accounting/presentation/accounting_provider.dart';
import 'package:lending_nelson/features/accounting/presentation/journal_list_page.dart';

import 'package:lending_nelson/features/collection_sessions/domain/collection_session.dart';
import 'package:lending_nelson/features/collection_sessions/presentation/collection_session_provider.dart';
import 'package:lending_nelson/features/collection_sessions/presentation/collection_sessions_page.dart';
import 'package:lending_nelson/features/loan_policies/domain/loan_policy.dart';
import 'package:lending_nelson/features/loan_policies/presentation/loan_policy_page.dart';
import 'package:lending_nelson/features/loan_policies/presentation/loan_policy_provider.dart';
import 'package:lending_nelson/features/operational_reports/presentation/operational_reports_page.dart';

void main() {
  test('portfolio aging keys use readable business labels', () {
    expect(agingBucketLabel('current'), 'Current');
    expect(agingBucketLabel('days17'), '1–7 days');
    expect(agingBucketLabel('days830'), '8–30 days');
    expect(agingBucketLabel('days3160'), '31–60 days');
    expect(agingBucketLabel('days6190'), '61–90 days');
    expect(agingBucketLabel('daysOver90'), 'Over 90 days');
  });

  testWidgets('report segment labels stay on one line at narrow widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 90, child: reportSegmentLabel('Trial Balance')),
      ),
    );

    final text = tester.widget<Text>(find.text('Trial Balance'));
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
    expect(find.byType(FittedBox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loan policy page uses an informative empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loanPoliciesProvider.overrideWith(
            (ref) async => const <LoanPolicy>[],
          ),
          ownerSessionProvider.overrideWith((ref) async => null),
          backendOnlineProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: LoanPolicyPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No loan policies yet'), findsOneWidget);
    expect(find.textContaining('versioned lending rules'), findsOneWidget);
    expect(find.text('No policy versions.'), findsNothing);
  });



  testWidgets('collection sessions use an informative empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionSessionsProvider.overrideWith(
            (ref) async => const <CollectionSession>[],
          ),
          ownerSessionProvider.overrideWith((ref) async => null),
          backendOnlineProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: CollectionSessionsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No collection sessions'), findsOneWidget);
    expect(find.textContaining('before accepting cash'), findsOneWidget);
    expect(find.text('No collection sessions.'), findsNothing);
  });

  testWidgets('accounting journals use an informative read-only empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalsProvider.overrideWith((ref) async => const <JournalEntry>[]),
          backendOnlineProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: JournalListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No posted journals'), findsOneWidget);
    expect(find.textContaining('Immutable journal entries'), findsOneWidget);
    expect(find.text('No posted journals.'), findsNothing);
  });

  testWidgets('cash report uses an informative empty-period state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: emptyCollectionReportState())),
    );

    expect(find.text('No collection sessions in this period'), findsOneWidget);
    expect(find.textContaining('Cash collected, deposits'), findsOneWidget);
    expect(find.text('No collection sessions in this period.'), findsNothing);
  });

  testWidgets('operational pages protect content from system navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loanPoliciesProvider.overrideWith(
            (ref) async => const <LoanPolicy>[],
          ),
          ownerSessionProvider.overrideWith((ref) async => null),
          backendOnlineProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: LoanPolicyPage()),
      ),
    );
    await tester.pumpAndSettle();

    final safeArea = tester.widget<SafeArea>(
      find.byWidgetPredicate(
        (widget) => widget is SafeArea && !widget.top && widget.bottom,
      ),
    );
    expect(safeArea.top, isFalse);
    expect(safeArea.bottom, isTrue);
  });
}
