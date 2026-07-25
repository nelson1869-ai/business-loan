import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../network/api_client.dart';

enum DownloadStatus { idle, running, paused, completed, failed, cancelled }

class ManagedDownload {
  ManagedDownload({
    required this.id,
    required this.endpoint,
    required this.fileName,
  });

  final String id;
  final String endpoint;
  final String fileName;
  DownloadStatus status = DownloadStatus.idle;
  int receivedBytes = 0;
  int? totalBytes;
  String? localPath;
  CancelToken? cancelToken;
}

/// Android-friendly download manager with progress, pause/resume, retry,
/// cancellation, opening, sharing, and Storage Access Framework export.
class DownloadManager {
  DownloadManager(this._dio);

  final Dio _dio;
  final Map<String, ManagedDownload> _downloads = {};

  ManagedDownload create({
    required String id,
    required String endpoint,
    required String fileName,
  }) {
    return _downloads.putIfAbsent(
      id,
      () => ManagedDownload(id: id, endpoint: endpoint, fileName: fileName),
    );
  }

  Future<void> start(
    ManagedDownload download, {
    void Function(ManagedDownload download)? onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final target = File(
      path.join(directory.path, _safeFileName(download.fileName)),
    );
    final existing = await target.exists() ? await target.length() : 0;
    download.localPath = target.path;
    download.cancelToken = CancelToken();
    download.status = DownloadStatus.running;
    try {
      final response = await _dio.download(
        download.endpoint,
        target.path,
        options: Options(
          headers: existing > 0 ? {'Range': 'bytes=$existing-'} : null,
        ),
        cancelToken: download.cancelToken,
        deleteOnError: false,
        fileAccessMode: existing > 0
            ? FileAccessMode.append
            : FileAccessMode.write,
        onReceiveProgress: (received, total) {
          download.receivedBytes = existing + received;
          download.totalBytes = total > 0 ? existing + total : null;
          onProgress?.call(download);
        },
      );
      final partial = response.statusCode == HttpStatus.partialContent;
      if (existing > 0 && !partial) {
        // The server ignored the Range request. Restart from zero so the
        // retained partial file cannot be duplicated or corrupted.
        await target.delete();
        download.receivedBytes = 0;
        return start(download, onProgress: onProgress);
      }
      download.receivedBytes = await target.length();
      download.status = DownloadStatus.completed;
      onProgress?.call(download);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        if (download.status != DownloadStatus.paused) {
          download.status = DownloadStatus.cancelled;
        }
      } else {
        download.status = DownloadStatus.failed;
      }
      onProgress?.call(download);
      rethrow;
    }
  }

  void pause(ManagedDownload download) {
    download.status = DownloadStatus.paused;
    download.cancelToken?.cancel('Paused');
  }

  Future<void> resume(
    ManagedDownload download, {
    void Function(ManagedDownload download)? onProgress,
  }) {
    return start(download, onProgress: onProgress);
  }

  Future<void> cancel(ManagedDownload download) async {
    download.status = DownloadStatus.cancelled;
    download.cancelToken?.cancel('Cancelled');
    final localPath = download.localPath;
    if (localPath != null) {
      final file = File(localPath);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> open(ManagedDownload download) async {
    final localPath = download.localPath;
    if (localPath == null) return;
    await OpenFilex.open(localPath);
  }

  Future<void> share(ManagedDownload download) async {
    final localPath = download.localPath;
    if (localPath == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(localPath)], title: download.fileName),
    );
  }

  Future<String?> saveAs(ManagedDownload download) async {
    final localPath = download.localPath;
    if (localPath == null) return null;
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save document',
      fileName: download.fileName,
      bytes: await File(localPath).readAsBytes(),
    );
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_');
  }
}

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager(ref.watch(apiClientProvider));
});
