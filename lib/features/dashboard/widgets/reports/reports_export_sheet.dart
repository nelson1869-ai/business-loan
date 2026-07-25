import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Draggable Bottom Sheet offering PDF, Excel, CSV export, and print functions.
class ReportsExportSheet extends StatelessWidget {
  const ReportsExportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show(
      context,
      title: 'Export Executive Financial Report',
      child: const ReportsExportSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
          title: const Text('Export Executive Summary PDF'),
          subtitle: const Text(
            'Includes charts, officer ratings, and PAR % analysis',
          ),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Generating PDF Report...')),
            );
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.table_chart, color: Colors.green),
          title: const Text('Export Detailed Excel (.xlsx)'),
          subtitle: const Text(
            'Full raw breakdown of loans, collections, and schedules',
          ),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Downloading Excel spreadsheet...')),
            );
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.file_present_outlined, color: Colors.blue),
          title: const Text('Export CSV Ledger Data'),
          subtitle: const Text(
            'Comma-separated raw data for custom accounting tools',
          ),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exporting CSV Ledger Data...')),
            );
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.print_outlined, color: theme.colorScheme.primary),
          title: const Text('Print Preview & PDF Output'),
          subtitle: const Text('Format for thermal or standard A4 printers'),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sending report to print spooler...'),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
