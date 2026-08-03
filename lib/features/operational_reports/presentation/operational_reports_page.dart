import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/presentation/design_system/app_state_views.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/online_required_banner.dart';
import 'operational_report_provider.dart';

String agingBucketLabel(String key) => switch (key) {
  'current' => 'Current',
  'days17' => '1–7 days',
  'days830' => '8–30 days',
  'days3160' => '31–60 days',
  'days6190' => '61–90 days',
  'daysOver90' => 'Over 90 days',
  _ => key,
};

Widget reportSegmentLabel(String label) => FittedBox(
  fit: BoxFit.scaleDown,
  child: Text(label, maxLines: 1, softWrap: false),
);

Widget emptyCollectionReportState() => const Center(
  child: Padding(
    padding: EdgeInsets.all(24),
    child: AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No collection sessions in this period',
      description:
          'Cash collected, deposits, and collector variances will appear after sessions are recorded for the selected period.',
    ),
  ),
);

/// Backend-calculated portfolio, cash, variance, and trial-balance reports.
class OperationalReportsPage extends ConsumerStatefulWidget {
  const OperationalReportsPage({super.key});

  @override
  ConsumerState<OperationalReportsPage> createState() =>
      _OperationalReportsPageState();
}

class _OperationalReportsPageState
    extends ConsumerState<OperationalReportsPage> {
  String _type = 'portfolio';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final query = OperationalReportQuery(
      _type,
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final report = ref.watch(operationalReportProvider(query));
    return Scaffold(
      appBar: AppBar(title: const Text('Operational Reports')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const OnlineRequiredBanner(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'portfolio',
                    label: reportSegmentLabel('Portfolio'),
                  ),
                  ButtonSegment(
                    value: 'collections',
                    label: reportSegmentLabel('Cash'),
                  ),
                  ButtonSegment(
                    value: 'trial',
                    label: reportSegmentLabel('Trial Balance'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  setState(() => _type = selection.single);
                },
              ),
            ),
            Expanded(
              child: report.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: FilledButton.icon(
                    onPressed: () =>
                        ref.invalidate(operationalReportProvider(query)),
                    icon: const Icon(Icons.refresh),
                    label: Text(ApiErrorMapper.message(error)),
                  ),
                ),
                data: (data) => _ReportBody(type: _type, data: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No report data.'));
    if (type == 'portfolio') return _portfolio();
    if (type == 'collections') return _collections();
    return _trialBalance();
  }

  Widget _portfolio() {
    final aging = Map<String, dynamic>.from(data['aging'] as Map? ?? const {});
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metric('Outstanding principal', data['outstandingPrincipal']),
        _metric('Accrued interest', data['accruedInterest']),
        _metric('Interest collected', data['interestCollected']),
        _metric('PAR 1', data['par1']),
        _metric('PAR 7', data['par7']),
        _metric('PAR 30', data['par30']),
        _metric('PAR 60', data['par60']),
        _metric('PAR 90', data['par90']),
        const Divider(),
        ...aging.entries.map(
          (entry) => _metric(agingBucketLabel(entry.key), entry.value),
        ),
      ],
    );
  }

  Widget _collections() {
    final rows = data['rows'] as List<dynamic>? ?? const [];
    if (rows.isEmpty) {
      return emptyCollectionReportState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = Map<String, dynamic>.from(rows[index] as Map);
        return Card(
          child: ListTile(
            title: Text('Session ${row['sessionId']} • ${row['status']}'),
            subtitle: Text(
              'Cash ${formatCurrency(row['cashCollected'].toString())}\n'
              'Deposited ${formatCurrency(row['depositAmount'].toString())} • '
              'Variance ${formatCurrency(row['variance'].toString())}',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _trialBalance() {
    final rows = data['rows'] as List<dynamic>? ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metric('Total debit', data['totalDebit']),
        _metric('Total credit', data['totalCredit']),
        const Divider(),
        ...rows.map((item) {
          final row = Map<String, dynamic>.from(item as Map);
          return ListTile(
            title: Text('${row['accountCode']} ${row['accountName']}'),
            subtitle: Text(
              'Debit ${formatCurrency(row['debit'].toString())} • '
              'Credit ${formatCurrency(row['credit'].toString())}',
            ),
          );
        }),
      ],
    );
  }

  Widget _metric(String label, Object? value) => Card(
    child: ListTile(
      title: Text(label),
      trailing: Text(formatCurrency(value?.toString() ?? '0.00')),
    ),
  );
}
