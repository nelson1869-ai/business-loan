import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/loans/presentation/loan_create_screen.dart';

void main() {
  group('calculateDefaultFirstDueDate Twice a Month (paymentsPerMonth == 2)', () {
    test('March 5 -> March 15', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 3, 5), 2);
      expect(res, DateTime(2026, 3, 15));
    });

    test('March 14 -> March 15', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 3, 14), 2);
      expect(res, DateTime(2026, 3, 15));
    });

    test('March 15 -> March 31', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 3, 15), 2);
      expect(res, DateTime(2026, 3, 31));
    });

    test('March 20 -> March 31', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 3, 20), 2);
      expect(res, DateTime(2026, 3, 31));
    });

    test('March 30 -> March 31', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 3, 30), 2);
      expect(res, DateTime(2026, 3, 31));
    });

    test('March 31 -> April 15', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 3, 31), 2);
      expect(res, DateTime(2026, 4, 15));
    });

    test('Feb 15, 2026 (non-leap) -> Feb 28', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 2, 15), 2);
      expect(res, DateTime(2026, 2, 28));
    });

    test('Feb 28, 2026 (non-leap) -> March 15', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 2, 28), 2);
      expect(res, DateTime(2026, 3, 15));
    });

    test('Feb 15, 2028 (leap year) -> Feb 29', () {
      final res = calculateDefaultFirstDueDate(DateTime(2028, 2, 15), 2);
      expect(res, DateTime(2028, 2, 29));
    });

    test('Feb 28, 2028 (leap year) -> Feb 29', () {
      final res = calculateDefaultFirstDueDate(DateTime(2028, 2, 28), 2);
      expect(res, DateTime(2028, 2, 29));
    });

    test('Feb 29, 2028 (leap year) -> March 15', () {
      final res = calculateDefaultFirstDueDate(DateTime(2028, 2, 29), 2);
      expect(res, DateTime(2028, 3, 15));
    });

    test('April 30 -> May 15', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 4, 30), 2);
      expect(res, DateTime(2026, 5, 15));
    });

    test('Dec 31, 2026 -> Jan 15, 2027 (year boundary)', () {
      final res = calculateDefaultFirstDueDate(DateTime(2026, 12, 31), 2);
      expect(res, DateTime(2027, 1, 15));
    });
  });
}
