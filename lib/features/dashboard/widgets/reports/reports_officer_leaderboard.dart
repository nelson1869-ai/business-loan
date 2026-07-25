import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Officer Performance Leaderboard Table widget.
class ReportsOfficerLeaderboard extends StatelessWidget {
  const ReportsOfficerLeaderboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final officers = [
      _OfficerRow(
        'Maria Santos',
        '₱42,500.00',
        '18',
        '98.5%',
        '100%',
        Colors.green,
      ),
      _OfficerRow(
        'Juan Dela Cruz',
        '₱38,200.00',
        '15',
        '96.2%',
        '95%',
        Colors.green,
      ),
      _OfficerRow(
        'Pedro Penduko',
        '₱29,800.00',
        '12',
        '91.0%',
        '88%',
        Colors.teal,
      ),
      _OfficerRow(
        'Elena Adarna',
        '₱24,100.00',
        '10',
        '85.4%',
        '80%',
        Colors.orange,
      ),
    ];

    return AppSectionCard(
      title: 'Officer Collection Performance Leaderboard',
      icon: Icons.leaderboard_outlined,
      children: [
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
              DataColumn(
                label: Text(
                  'Loans Managed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Recovery Rate',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'On-Time %',
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
                            off.name[0],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          off.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      off.collections,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(Text(off.loansManaged)),
                  DataCell(
                    Text(
                      off.recoveryRate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: off.badgeColor,
                      ),
                    ),
                  ),
                  DataCell(
                    AppStatusChip(status: off.onTimePct, isCompact: true),
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

class _OfficerRow {
  final String name;
  final String collections;
  final String loansManaged;
  final String recoveryRate;
  final String onTimePct;
  final Color badgeColor;

  _OfficerRow(
    this.name,
    this.collections,
    this.loansManaged,
    this.recoveryRate,
    this.onTimePct,
    this.badgeColor,
  );
}
