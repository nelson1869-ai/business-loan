import 'package:flutter/material.dart';

/// Documents Tab View presenting attached verification & legal paperwork.
class DocumentsTabView extends StatelessWidget {
  const DocumentsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final docs = const [
      _DocItem(
        'Government ID (Front & Back)',
        'PDF • 1.2 MB',
        Icons.badge_outlined,
      ),
      _DocItem(
        'Loan Contract Agreement',
        'PDF • 3.4 MB',
        Icons.description_outlined,
      ),
      _DocItem('Promissory Note', 'PDF • 850 KB', Icons.assignment_outlined),
      _DocItem(
        'Collateral Proof Photos',
        'PNG • 4.1 MB',
        Icons.photo_library_outlined,
      ),
      _DocItem(
        'Proof of Income / Payslip',
        'PDF • 920 KB',
        Icons.request_quote_outlined,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                doc.icon,
                color: theme.colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            title: Text(
              doc.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              doc.subtitle,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                  tooltip: 'Preview Document',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening preview for ${doc.title}'),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined, size: 18),
                  tooltip: 'Download',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloading ${doc.title}...')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DocItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const _DocItem(this.title, this.subtitle, this.icon);
}
