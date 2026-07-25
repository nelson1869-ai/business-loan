import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/design_system/design_system.dart';
import '../../../core/network/api_error_mapper.dart';
import '../data/document_repository.dart';
import '../domain/app_document.dart';
import '../providers/document_provider.dart';

class DocumentListView extends ConsumerWidget {
  const DocumentListView({super.key, required this.borrowerId, this.loanId});

  final String borrowerId;
  final String? loanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (borrowerId: borrowerId, loanId: loanId);
    final documents = ref.watch(documentsProvider(scope));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(documentsProvider(scope));
        await ref.read(documentsProvider(scope).future);
      },
      child: documents.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppCardSkeleton(),
            SizedBox(height: 10),
            AppCardSkeleton(),
            SizedBox(height: 10),
            AppCardSkeleton(),
          ],
        ),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppErrorState(
              error: ApiErrorMapper.message(error),
              onRetry: () => ref.invalidate(documentsProvider(scope)),
            ),
          ],
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: () => _upload(context, ref, scope),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Document'),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const AppEmptyState(
                icon: Icons.folder_open_outlined,
                title: 'No Documents',
                description:
                    'Upload a PDF or image to attach it to this record.',
              )
            else
              ...items.map(
                (document) => _DocumentCard(
                  document: document,
                  onDownload: () => _download(context, ref, document),
                  onDelete: document.canDelete
                      ? () => _delete(context, ref, scope, document)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload(
    BuildContext context,
    WidgetRef ref,
    DocumentScope scope,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || !context.mounted) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _message(context, 'The selected file could not be read.');
      return;
    }
    if (bytes.length > 700000) {
      _message(context, 'Select a document no larger than 700 KB.');
      return;
    }
    final extension = (file.extension ?? '').toLowerCase();
    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => '',
    };
    try {
      await ref
          .read(documentRepositoryProvider)
          .upload(
            borrowerId: scope.borrowerId,
            loanId: scope.loanId,
            title: file.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            fileName: file.name,
            contentType: contentType,
            bytes: bytes,
          );
      ref.invalidate(documentsProvider(scope));
      if (context.mounted) _message(context, 'Document uploaded.');
    } catch (error) {
      if (context.mounted) {
        _message(context, ApiErrorMapper.message(error));
      }
    }
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    AppDocument document,
  ) async {
    try {
      final bytes = await ref
          .read(documentRepositoryProvider)
          .download(document.id);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save document',
        fileName: document.fileName,
        bytes: bytes,
      );
      if (context.mounted && path != null) _message(context, 'Document saved.');
    } catch (error) {
      if (context.mounted) {
        _message(context, ApiErrorMapper.message(error));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DocumentScope scope,
    AppDocument document,
  ) async {
    final confirmed = await AppDeleteDialog.show(
      context,
      title: 'Delete document?',
      content: 'This permanently removes ${document.fileName}.',
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(documentRepositoryProvider).delete(document.id);
      ref.invalidate(documentsProvider(scope));
    } catch (error) {
      if (context.mounted) {
        _message(context, ApiErrorMapper.message(error));
      }
    }
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.onDownload,
    this.onDelete,
  });

  final AppDocument document;
  final VoidCallback onDownload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final size = document.sizeBytes < 1024
        ? '${document.sizeBytes} B'
        : '${(document.sizeBytes / 1024).toStringAsFixed(0)} KB';
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
        title: Text(
          document.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${document.fileName} • $size'),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Download document',
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete document',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}
