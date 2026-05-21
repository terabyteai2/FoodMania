import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class MenuImageService {
  MenuImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Long edge capped at 1024px for menu/hero uploads.
  static const int maxEdgePx = 1024;
  static int maxBinaryBytes = 1200 * 1024;

  Future<String?> pickMenuImageDataUrl() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxEdgePx.toDouble(),
      maxHeight: maxEdgePx.toDouble(),
      imageQuality: 82,
      requestFullMetadata: false,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    if (bytes.length > maxBinaryBytes) {
      throw MenuImageException(
        'Selected image is too large after compression. Please choose a smaller photo.',
      );
    }

    final mimeType = image.mimeType ?? _mimeTypeFromPath(image.name);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  /// Picks an image from the gallery and returns the raw bytes (plus a
  /// suggested mime type) without re-encoding to a data URL yet. Used by the
  /// menu item flow so we can show an in-app square cropper before saving.
  Future<PickedMenuImage?> pickRawMenuImageBytes() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxEdgePx.toDouble(),
      maxHeight: maxEdgePx.toDouble(),
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    final mimeType = image.mimeType ?? _mimeTypeFromPath(image.name);
    return PickedMenuImage(bytes: bytes, mimeType: mimeType);
  }

  /// Keeps gallery selection order so multi-page menus reach OCR page by page.
  Future<List<PickedMenuScanPage>> pickMenuScanPages() async {
    final images = await _picker.pickMultiImage(
      maxWidth: maxEdgePx.toDouble(),
      maxHeight: maxEdgePx.toDouble(),
      imageQuality: 88,
      requestFullMetadata: false,
    );
    final pages = <PickedMenuScanPage>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      if (bytes.length > maxBinaryBytes) {
        throw MenuImageException(
          'A selected menu image is too large after compression. Please choose smaller photos.',
        );
      }
      pages.add(
        PickedMenuScanPage(
          bytes: bytes,
          mimeType: image.mimeType ?? _mimeTypeFromPath(image.name),
          fileName: image.name,
        ),
      );
    }
    return pages;
  }

  /// Wraps already-encoded bytes in a `data:` URL, enforcing the same size cap
  /// as the gallery picker so the saved cropped image stays uploadable.
  String encodeDataUrl(Uint8List bytes, {String mimeType = 'image/png'}) {
    if (bytes.length > maxBinaryBytes) {
      throw MenuImageException(
        'Cropped image is too large. Please choose a smaller photo.',
      );
    }
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class PickedMenuImage {
  const PickedMenuImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class PickedMenuScanPage {
  const PickedMenuScanPage({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

class MenuImageException implements Exception {
  MenuImageException(this.message);

  final String message;

  @override
  String toString() => message;
}
