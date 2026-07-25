import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

import '../../domain/financial_report.dart';

class ReportsExportSheet extends StatelessWidget {
  const ReportsExportSheet({super.key, required this.report});

  final FinancialReport report;

  static Future<void> show(
    BuildContext context, {
    required FinancialReport report,
  }) {
    return AppBottomSheet.show(
      context,
      title: 'Export Financial Report',
      child: ReportsExportSheet(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.file_present_outlined),
          title: const Text('Export CSV report'),
          subtitle: Text('${report.dateFrom} through ${report.dateTo}'),
          onTap: () => _exportCsv(context),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            'PDF, Excel, and printing are unavailable until verified '
            'generation services are connected.',
          ),
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final rows = <List<Object?>>[
      ['Report period', '${report.dateFrom} to ${report.dateTo}'],
      ['Outstanding portfolio', report.outstandingPortfolio],
      ['Collections', report.collections],
      ['Interest earned', report.interestEarned],
      ['Principal collected', report.principalCollected],
      ['Unapplied credits', report.unappliedCredits],
      ['Overdue amount', report.overdueAmount],
      ['Portfolio at risk', report.portfolioAtRisk],
      ['Overdue loan count', report.overdueLoanCount],
      [],
      ['Loan aging bucket', 'Amount'],
      ...report.loanAging.entries.map((entry) => [entry.key, entry.value]),
      [],
      ['Collector', 'Collections'],
      ...report.collectorPerformance.entries.map(
        (entry) => [entry.key, entry.value],
      ),
    ];
    final csv = rows.map((row) => row.map(_escape).join(',')).join('\r\n');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save financial report',
      fileName: 'financial-report-${report.dateFrom}-${report.dateTo}.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    if (!context.mounted || path == null) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV report saved.')));
  }

  String _escape(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }
}
