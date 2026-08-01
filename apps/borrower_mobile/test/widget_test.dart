import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borrower_mobile/app/app.dart';

void main() {
  testWidgets('BorrowerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BorrowerApp(),
      ),
    );
    expect(find.byType(BorrowerApp), findsOneWidget);
  });
}
