import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class MenuImageService {
  MenuImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Long edge capped at 1024px for menu/hero uploads.
  static const int maxEdgePx = 1024;
  static const int menuPhotoEdgePx = 720;
  static const int menuPhotoJpegQuality = 82;
  static int maxBinaryBytes = 1200 * 1024;

  /// Cap multi-pick scans so we don't accumulate too many byte buffers in RAM.
  static const int maxScanPages = 6;

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
    if (images.length > maxScanPages) {
      throw MenuImageException(
        'Select up to $maxScanPages menu photos at a time.',
      );
    }
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

  Future<PickedMenuScanPage?> captureMenuScanPage({
    required int pageNumber,
  }) async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      requestFullMetadata: false,
    );
    if (image == null) return null;

    var bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final oriented = img.bakeOrientation(decoded);
      final longest = oriented.width > oriented.height ? oriented.width : oriented.height;
      final resized = longest > maxEdgePx
          ? img.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? maxEdgePx : null,
              height: oriented.height > oriented.width ? maxEdgePx : null,
              interpolation: img.Interpolation.average,
            )
          : oriented;
      bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 88));
    }
    if (bytes.length > maxBinaryBytes) {
      throw MenuImageException(
        'Captured menu photo is too large after compression. Please retake it a little farther away.',
      );
    }
    final fallbackName = 'menu-page-$pageNumber.jpg';
    final mimeType = image.mimeType ?? _mimeTypeFromPath(image.name);
    return PickedMenuScanPage(
      bytes: bytes,
      mimeType: mimeType.startsWith('image/') ? mimeType : 'image/jpeg',
      fileName: image.name.trim().isEmpty ? fallbackName : image.name,
    );
  }

  /// Wraps already-encoded bytes in a `data:` URL, enforcing the same size cap.
  String encodeDataUrl(Uint8List bytes, {String mimeType = 'image/jpeg'}) {
    if (bytes.length > maxBinaryBytes) {
      throw MenuImageException(
        'Cropped image is too large. Please choose a smaller photo.',
      );
    }
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  /// Decodes any selected/cropped menu photo, bakes EXIF orientation, resizes
  /// to the thumbnail size used by customer menus, and returns a JPEG data URL.
  ///
  /// This intentionally compresses after crop rather than trusting picker
  /// quality hints. Android gallery providers sometimes ignore those hints for
  /// large originals, which caused normal photos to trip the upload size cap.
  String encodeMenuPhotoDataUrl(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw MenuImageException('Could not read the selected image.');
    }
    final oriented = img.bakeOrientation(decoded);
    final longest = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final normalized = longest > menuPhotoEdgePx
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? menuPhotoEdgePx : null,
            height: oriented.height > oriented.width ? menuPhotoEdgePx : null,
            interpolation: img.Interpolation.average,
          )
        : oriented;

    for (final quality in const [menuPhotoJpegQuality, 74, 66, 58, 50]) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(normalized, quality: quality),
      );
      if (encoded.length <= maxBinaryBytes) {
        return 'data:image/jpeg;base64,${base64Encode(encoded)}';
      }
    }
    throw MenuImageException(
      'Cropped image is too large. Please choose a smaller photo.',
    );
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
