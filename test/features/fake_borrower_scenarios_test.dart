import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_model.dart';
import 'package:lending_nelson/features/borrowers/domain/borrower_recommendation_service.dart';
import 'package:lending_nelson/features/loans/domain/models/loan.dart';

void main() {
  late BorrowerRecommendationService service;
  final referenceDate = DateTime(2026, 7, 25);

  setUp(() {
    service = const BorrowerRecommendationService();
  });

  test('Evaluates all fake borrower JSON scenarios successfully', () async {
    final file = File('test/fixtures/fake_borrower_scenarios.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Test fixture JSON file must exist',
    );

    final jsonString = await file.readAsString();
    final Map<String, dynamic> data =
        jsonDecode(jsonString) as Map<String, dynamic>;
    final List<dynamic> scenarios = data['scenarios'] as List<dynamic>;

    expect(scenarios.length, equals(6));

    for (final rawScenario in scenarios) {
      final scenario = rawScenario as Map<String, dynamic>;
      final name = scenario['name'] as String;
      final expectedRiskTier = scenario['expectedRiskTier'] as String;
      final expectedEligibility =
          scenario['expectedEligibilityStatus'] as String;

      final borrowerJson = scenario['borrower'] as Map<String, dynamic>;
      final borrower = Borrower.fromJson(borrowerJson);

      final loansList = (scenario['loans'] as List<dynamic>)
          .map((item) => Loan.fromJson(item as Map<String, dynamic>))
          .toList();

      final recommendation = service.evaluate(
        borrower: borrower,
        loans: loansList,
        referenceDate: referenceDate,
      );

      expect(
        recommendation.riskTier.name,
        equals(expectedRiskTier),
        reason: 'Failed riskTier check for $name',
      );

      expect(
        recommendation.eligibilityStatus.name,
        equals(expectedEligibility),
        reason: 'Failed eligibilityStatus check for $name',
      );

      if (scenario.containsKey('expectedMinScore')) {
        final minScore = scenario['expectedMinScore'] as int;
        expect(
          recommendation.creditScore,
          greaterThanOrEqualTo(minScore),
          reason: 'Failed minScore check for $name',
        );
      }

      if (scenario.containsKey('expectedMaxScore')) {
        final maxScore = scenario['expectedMaxScore'] as int;
        expect(
          recommendation.creditScore,
          lessThanOrEqualTo(maxScore),
          reason: 'Failed maxScore check for $name',
        );
      }
    }
  });
}
