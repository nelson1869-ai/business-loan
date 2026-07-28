import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/design_system/design_system.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/downloads/download_manager.dart';
import '../data/document_capture_service.dart';
import '../data/document_repository.dart';
import '../domain/app_document.dart';
import '../providers/document_provider.dart';

class DocumentListView extends ConsumerStatefulWidget {
  const DocumentListView({super.key, required this.borrowerId, this.loanId});

  final String borrowerId;
  final String? loanId;

  @override
  ConsumerState<DocumentListView> createState() => _DocumentListViewState();
}

class _DocumentListViewState extends ConsumerState<DocumentListView> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final scope = (borrowerId: widget.borrowerId, loanId: widget.loanId);
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
              onPressed: _isUploading
                  ? null
                  : () => _upload(context, ref, scope),
              icon: _isUploading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(
                _isUploading ? 'Preparing upload…' : 'Upload Document',
              ),
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
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Capture with camera'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photos'),
              subtitle: const Text('Multiple photos are combined into a PDF'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Choose PDF or image file'),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    setState(() => _isUploading = true);
    try {
      if (source != 'file') {
        final capture = ref.read(documentCaptureServiceProvider);
        final prepared = source == 'camera'
            ? await capture.captureCamera()
            : await capture.captureGallery();
        if (prepared == null || !context.mounted) return;
        final accepted = await _confirmPreview(context, prepared);
        if (accepted != true || !context.mounted) return;
        await _uploadBytes(
          context,
          ref,
          scope,
          fileName: prepared.fileName,
          contentType: prepared.contentType,
          bytes: prepared.bytes,
        );
        return;
      }

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
      if (bytes.length > maxDocumentBytes) {
        _message(context, 'Select a document no larger than 700 KB.');
        return;
      }
      final extension = (file.extension ?? '').toLowerCase();
      final contentType = switch (extension) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => throw const DocumentOptimizationException(
          'Unsupported document type.',
        ),
      };
      await _uploadBytes(
        context,
        ref,
        scope,
        fileName: file.name,
        contentType: contentType,
        bytes: bytes,
      );
    } on DocumentOptimizationException catch (error) {
      if (context.mounted) _message(context, error.message);
    } on PlatformException catch (error) {
      if (context.mounted) {
        _message(
          context,
          error.message ?? 'Photo access was unavailable or denied.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        _message(context, ApiErrorMapper.message(error));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadBytes(
    BuildContext context,
    WidgetRef ref,
    DocumentScope scope, {
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    try {
      await ref
          .read(documentRepositoryProvider)
          .upload(
            borrowerId: scope.borrowerId,
            loanId: scope.loanId,
            title: fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            fileName: fileName,
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

  Future<bool?> _confirmPreview(
    BuildContext context,
    CapturedDocument document,
  ) {
    final isImage = document.contentType.startsWith('image/');
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Document preview'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420, maxWidth: 480),
          child: isImage
              ? InteractiveViewer(child: Image.memory(document.bytes))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 72),
                    const SizedBox(height: 12),
                    Text(
                      '${(document.bytes.length / 1024).ceil()} KB PDF ready',
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Retake'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    AppDocument document,
  ) async {
    final manager = ref.read(downloadManagerProvider);
    final download = manager.create(
      id: document.id,
      endpoint: ApiEndpoints.documentContent(document.id),
      fileName: document.fileName,
    );
    var dialogOpen = true;
    StateSetter? updateDialog;
    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            updateDialog = setDialogState;
            final total = download.totalBytes;
            final progress = total == null || total == 0
                ? null
                : download.receivedBytes / total;
            return AlertDialog(
              title: const Text('Downloading document'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 12),
                  Text(
                    total == null
                        ? '${(download.receivedBytes / 1024).ceil()} KB'
                        : '${(download.receivedBytes / 1024).ceil()} / '
                              '${(total / 1024).ceil()} KB',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    manager.cancel(download);
                    dialogOpen = false;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        ),
      );
    }
    try {
      await manager.start(
        download,
        onProgress: (_) {
          if (dialogOpen) updateDialog?.call(() {});
        },
      );
      if (context.mounted && dialogOpen) Navigator.of(context).pop();
      if (!context.mounted || download.status != DownloadStatus.completed) {
        return;
      }
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Open or preview'),
                onTap: () => Navigator.pop(sheetContext, 'open'),
              ),
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Save to device'),
                onTap: () => Navigator.pop(sheetContext, 'save'),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
            ],
          ),
        ),
      );
      if (action == 'open') await manager.open(download);
      if (action == 'save') await manager.saveAs(download);
      if (action == 'share') await manager.share(download);
    } catch (error) {
      if (context.mounted && dialogOpen) Navigator.of(context).pop();
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
