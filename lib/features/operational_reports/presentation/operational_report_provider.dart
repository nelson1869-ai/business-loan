import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/operational_report_repository.dart';

/// Query for one backend-calculated operational report.
class OperationalReportQuery {
  const OperationalReportQuery(this.type, this.dateFrom, this.dateTo);

  final String type;
  final DateTime dateFrom;
  final DateTime dateTo;

  @override
  bool operator ==(Object other) =>
      other is OperationalReportQuery &&
      other.type == type &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;

  @override
  int get hashCode => Object.hash(type, dateFrom, dateTo);
}

final operationalReportProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, OperationalReportQuery>((ref, query) {
      final repository = ref.watch(operationalReportRepositoryProvider);
      return switch (query.type) {
        'portfolio' => repository.portfolioRisk(query.dateTo),
        'collections' => repository.collectorReconciliation(
          dateFrom: query.dateFrom,
          dateTo: query.dateTo,
        ),
        _ => repository.trialBalance(query.dateTo),
      };
    });
