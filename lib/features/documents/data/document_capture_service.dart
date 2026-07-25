import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pdf;

/// Maximum raw document size accepted by the current backend.
const maxDocumentBytes = 700000;

/// Optimized document ready for preview or upload.
class CapturedDocument {
  const CapturedDocument({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final Uint8List bytes;
}

/// Camera/gallery capture, crop, orientation correction, compression, and PDF
/// composition for the existing document API.
class DocumentCaptureService {
  DocumentCaptureService(this._picker, this._cropper);

  final ImagePicker _picker;
  final ImageCropper _cropper;

  /// Captures and crops one image from the camera.
  Future<CapturedDocument?> captureCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    return _prepareImage(image);
  }

  /// Selects one or more gallery images. Multiple images become one PDF.
  Future<CapturedDocument?> captureGallery() async {
    final images = await _picker.pickMultiImage(
      requestFullMetadata: false,
      limit: 12,
    );
    if (images.isEmpty) return null;
    if (images.length == 1) return _prepareImage(images.single);

    final optimized = <Uint8List>[];
    for (final image in images) {
      final prepared = await _prepareImage(image, maxBytes: 110000);
      if (prepared == null) continue;
      optimized.add(prepared.bytes);
    }
    if (optimized.isEmpty) return null;

    final document = pdf.Document();
    for (final bytes in optimized) {
      final memoryImage = pdf.MemoryImage(bytes);
      document.addPage(
        pdf.Page(
          build: (_) => pdf.Center(
            child: pdf.Image(memoryImage, fit: pdf.BoxFit.contain),
          ),
        ),
      );
    }
    final bytes = await document.save();
    if (bytes.length > maxDocumentBytes) {
      throw const DocumentOptimizationException(
        'The combined PDF is larger than 700 KB. Select fewer pages.',
      );
    }
    return CapturedDocument(
      fileName: 'captured-document.pdf',
      contentType: 'application/pdf',
      bytes: bytes,
    );
  }

  Future<CapturedDocument?> _prepareImage(
    XFile source, {
    int maxBytes = 680000,
  }) async {
    final cropped = await _cropper.cropImage(
      sourcePath: source.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Prepare document',
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
      ],
    );
    if (cropped == null) return null;

    Uint8List? bytes;
    for (var quality = 88; quality >= 38; quality -= 10) {
      bytes = await FlutterImageCompress.compressWithFile(
        cropped.path,
        minWidth: 1200,
        minHeight: 1200,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
        autoCorrectionAngle: true,
      );
      if (bytes != null && bytes.length <= maxBytes) break;
    }
    if (bytes == null || bytes.isEmpty || bytes.length > maxBytes) {
      throw const DocumentOptimizationException(
        'The image could not be reduced below the 700 KB upload limit.',
      );
    }
    await _validateImage(bytes);
    return CapturedDocument(
      fileName: 'captured-document.jpg',
      contentType: 'image/jpeg',
      bytes: bytes,
    );
  }

  Future<void> _validateImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      throw const DocumentOptimizationException(
        'The selected image is corrupted or unsupported.',
      );
    }
  }
}

class DocumentOptimizationException implements Exception {
  const DocumentOptimizationException(this.message);
  final String message;
}

final documentCaptureServiceProvider = Provider<DocumentCaptureService>((ref) {
  return DocumentCaptureService(ImagePicker(), ImageCropper());
});
