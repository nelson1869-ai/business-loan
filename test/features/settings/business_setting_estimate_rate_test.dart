import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import 'package:lending_nelson/features/settings/domain/business_setting.dart';

/// Unit tests for the estimate-rate field in the Owner business settings.
///
/// These are pure unit tests that do not require a running server.
void main() {
  group('BusinessSetting domain model - defaultMonthlyEstimateRate', () {
    test('fromJson maps null rate to null', () {
      final json = {
        'businessName': 'Test Lending',
        'currencyCode': 'PHP',
        'receiptFooter': '',
        'updatedAt': '2026-08-07T00:00:00.000Z',
      };
      final setting = BusinessSetting.fromJson(json);
      expect(setting.defaultMonthlyEstimateRate, isNull);
    });

    test('fromJson maps decimal rate string correctly', () {
      final json = {
        'businessName': 'Test Lending',
        'currencyCode': 'PHP',
        'receiptFooter': '',
        'updatedAt': '2026-08-07T00:00:00.000Z',
        'defaultMonthlyEstimateRate': '0.10000000',
      };
      final setting = BusinessSetting.fromJson(json);
      expect(setting.defaultMonthlyEstimateRate, equals('0.10000000'));
    });

    test('toJson omits rate when null', () {
      final setting = BusinessSetting(
        businessName: 'Test',
        currencyCode: 'PHP',
        receiptFooter: '',
        updatedAt: DateTime(2026),
      );
      final json = setting.toJson();
      expect(json.containsKey('defaultMonthlyEstimateRate'), isFalse);
    });

    test('toJson includes rate when not null', () {
      final setting = BusinessSetting(
        businessName: 'Test',
        currencyCode: 'PHP',
        receiptFooter: '',
        updatedAt: DateTime(2026),
        defaultMonthlyEstimateRate: '0.10000000',
      );
      final json = setting.toJson();
      expect(json['defaultMonthlyEstimateRate'], equals('0.10000000'));
    });
  });

  group('percentageToDecimalRate conversion', () {
    test('10 percent converts to 0.10', () {
      expect(percentageToDecimalRate('10'), equals('0.1'));
    });

    test('10.00 percent converts to 0.10', () {
      expect(percentageToDecimalRate('10.00'), equals('0.1'));
    });

    test('5.5 percent converts to 0.055', () {
      expect(percentageToDecimalRate('5.5'), equals('0.055'));
    });

    test('zero converts to 0.0', () {
      expect(percentageToDecimalRate('0'), equals('0.0'));
    });
  });

  group('formatInterestRate display conversion', () {
    test('0.10 formats to 10%', () {
      expect(formatInterestRate('0.10'), equals('10%'));
    });

    test('0.05 formats to 5%', () {
      expect(formatInterestRate('0.05'), equals('5%'));
    });

    test('strip percent sign for text field display', () {
      final display = formatInterestRate('0.10').replaceAll('%', '').trim();
      expect(display, equals('10'));
    });
  });
}
