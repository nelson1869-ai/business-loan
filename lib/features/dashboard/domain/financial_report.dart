/// Database-backed financial totals for a requested reporting window.
class FinancialReport {
  const FinancialReport({
    required this.dateFrom,
    required this.dateTo,
    required this.outstandingPortfolio,
    required this.collections,
    required this.interestEarned,
    required this.principalCollected,
    required this.unappliedCredits,
    required this.overdueAmount,
    required this.portfolioAtRisk,
    required this.overdueLoanCount,
    required this.loanAging,
    required this.collectorPerformance,
  });

  final String dateFrom;
  final String dateTo;
  final String outstandingPortfolio;
  final String collections;
  final String interestEarned;
  final String principalCollected;
  final String unappliedCredits;
  final String overdueAmount;
  final String portfolioAtRisk;
  final int overdueLoanCount;
  final Map<String, String> loanAging;
  final Map<String, String> collectorPerformance;

  factory FinancialReport.fromJson(Map<String, dynamic> json) {
    String money(String key) => json[key]?.toString() ?? '0.00';
    Map<String, String> moneyMap(String key) {
      final value = json[key];
      if (value is! Map) return const {};
      return value.map(
        (mapKey, mapValue) =>
            MapEntry(mapKey.toString(), mapValue?.toString() ?? '0.00'),
      );
    }

    return FinancialReport(
      dateFrom: json['dateFrom']?.toString() ?? '',
      dateTo: json['dateTo']?.toString() ?? '',
      outstandingPortfolio: money('outstandingPortfolio'),
      collections: money('collections'),
      interestEarned: money('interestEarned'),
      principalCollected: money('principalCollected'),
      unappliedCredits: money('unappliedCredits'),
      overdueAmount: money('overdueAmount'),
      portfolioAtRisk: money('portfolioAtRisk'),
      overdueLoanCount: (json['overdueLoanCount'] as num?)?.toInt() ?? 0,
      loanAging: moneyMap('loanAging'),
      collectorPerformance: moneyMap('collectorPerformance'),
    );
  }
}
