import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notes/notes_provider.dart';
import '../../../notes/notes_repository.dart';
import '../../../notes/officer_note.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/presentation/design_system/design_system.dart';

class NotesTabView extends ConsumerWidget {
  const NotesTabView({super.key, required this.borrowerId, this.loanId});
  final String borrowerId;
  final String? loanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (borrowerId: borrowerId, loanId: loanId);
    final notes = ref.watch(notesProvider(scope));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref, scope),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Add Note'),
      ),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(notesProvider(scope)),
            child: Text('${ApiErrorMapper.message(error)} Retry'),
          ),
        ),
        data: (items) => _NotesList(items: items, scope: scope),
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    NotesScope scope,
  ) async {
    final content = await showDialog<String>(
      context: context,
      builder: (_) => const _AddNoteDialog(),
    );
    if (content == null || !context.mounted) return;
    try {
      await ref
          .read(notesRepositoryProvider)
          .create(
            borrowerId,
            loanId: scope.loanId,
            content: content,
            category: scope.loanId == null ? 'Borrower' : 'Loan',
          );
      ref.invalidate(notesProvider(scope));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiErrorMapper.message(error))));
      }
    }
  }
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog();

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _controller = TextEditingController();
  bool _canSave = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Officer Note'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        maxLength: 4000,
        autofocus: true,
        onChanged: (value) {
          final canSave = value.trim().isNotEmpty;
          if (canSave != _canSave) setState(() => _canSave = canSave);
        },
        decoration: const InputDecoration(
          hintText: 'Enter an observation or collection note',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text('Save Note'),
        ),
      ],
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({required this.items, required this.scope});
  final List<OfficerNote> items;
  final NotesScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(child: Text('No officer notes recorded'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final note = items[index];
        return Card(
          child: ListTile(
            title: Text(note.authorName),
            subtitle: Text(note.content),
            leading: const Icon(Icons.person_pin_outlined),
            trailing: note.canDelete
                ? IconButton(
                    tooltip: 'Delete note',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final confirmed = await AppDeleteDialog.show(
                        context,
                        title: 'Delete note?',
                        content:
                            'This permanently removes the selected officer note.',
                      );
                      if (confirmed != true || !context.mounted) return;
                      try {
                        await ref.read(notesRepositoryProvider).delete(note.id);
                        ref.invalidate(notesProvider(scope));
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ApiErrorMapper.message(error)),
                            ),
                          );
                        }
                      }
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}
