import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';
import 'package:lending_nelson/core/utils/formatters.dart';
import '../../domain/financial_report.dart';

/// Officer Performance Leaderboard Table widget.
class ReportsOfficerLeaderboard extends StatelessWidget {
  const ReportsOfficerLeaderboard({super.key, required this.report});

  final FinancialReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final officers = report.collectorPerformance.entries.toList()
      ..sort(
        (a, b) => (double.tryParse(b.value) ?? 0).compareTo(
          double.tryParse(a.value) ?? 0,
        ),
      );

    return AppSectionCard(
      title: 'Officer Collection Performance Leaderboard',
      icon: Icons.leaderboard_outlined,
      children: [
        if (officers.isEmpty)
          const AppEmptyState(
            icon: Icons.leaderboard_outlined,
            title: 'No Collector Activity',
            description: 'No collections were recorded in this period.',
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              headingRowHeight: 36,
              dataRowMaxHeight: 48,
              columns: [
                DataColumn(
                  label: Text(
                    'Officer Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Collections',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
              rows: officers.map((off) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              off.key.isEmpty ? '?' : off.key[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            off.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        formatCurrency(off.value),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
