import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/financial_report_repository.dart';
import '../domain/financial_report.dart';

final financialReportProvider = FutureProvider.autoDispose
    .family<FinancialReport, String>((ref, period) {
      final now = DateTime.now();
      final from = switch (period) {
        'Today' => DateTime(now.year, now.month, now.day),
        'This Week' => DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1)),
        'This Quarter' => DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1),
        'This Year' => DateTime(now.year),
        _ => DateTime(now.year, now.month),
      };
      return ref
          .watch(financialReportRepositoryProvider)
          .load(dateFrom: from, dateTo: now);
    });
