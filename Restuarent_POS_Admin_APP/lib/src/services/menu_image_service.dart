import 'dart:convert';

import 'package:image_picker/image_picker.dart';

class MenuImageService {
  MenuImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static int maxBinaryBytes = 650 * 1024;

  Future<String?> pickMenuImageDataUrl() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 68,
      requestFullMetadata: false,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    if (bytes.length > maxBinaryBytes) {
      throw MenuImageException(
        'Selected image is too large. Please choose a smaller image.',
      );
    }

    final mimeType = image.mimeType ?? _mimeTypeFromPath(image.name);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class MenuImageException implements Exception {
  MenuImageException(this.message);

  final String message;

  @override
  String toString() => message;
}
