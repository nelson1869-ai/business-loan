import 'package:flutter/material.dart';

/// Notes Tab View displaying field officer observations and notes.
class LoanNotesTab extends StatefulWidget {
  const LoanNotesTab({super.key});

  @override
  State<LoanNotesTab> createState() => _LoanNotesTabState();
}

class _LoanNotesTabState extends State<LoanNotesTab> {
  final List<_NoteItem> _notes = [
    _NoteItem(
      officer: 'Credit Risk Officer',
      date: '2026-07-20',
      category: 'Collection',
      content:
          'Borrower requested date extension for July payment. Approved 3-day grace window.',
    ),
    _NoteItem(
      officer: 'Field Collector Nelson',
      date: '2026-06-15',
      category: 'Verification',
      content:
          'Initial credit recommendation verified. Collateral physically inspected and logged.',
    ),
  ];

  void _showAddNoteDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Officer Note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter observation or collection notes...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _notes.insert(
                    0,
                    _NoteItem(
                      officer: 'Loan Officer',
                      date: DateTime.now().toString().substring(0, 10),
                      category: 'General Observation',
                      content: controller.text.trim(),
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddNoteDialog,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Add Note'),
      ),
      body: _notes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.speaker_notes_off_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Officer Notes Recorded',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap below to record loan inspection notes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_pin,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  note.officer,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              note.date,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            note.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const Divider(height: 16),
                        Text(note.content, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NoteItem {
  final String officer;
  final String date;
  final String category;
  final String content;

  const _NoteItem({
    required this.officer,
    required this.date,
    required this.category,
    required this.content,
  });
}
