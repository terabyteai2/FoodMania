import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MenuImageView extends StatelessWidget {
  const MenuImageView({required this.imageUrl, this.fit = BoxFit.cover, super.key});

  final String? imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim();
    if (image == null || image.isEmpty) return _ImagePlaceholder();

    final data = _tryDecodeDataUrl(image);
    if (data != null) {
      return Image.memory(
        data,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _BrokenImage(),
      );
    }

    return Image.network(
      image,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _BrokenImage(),
    );
  }

  Uint8List? _tryDecodeDataUrl(String value) {
    final marker = ';base64,';
    if (!value.startsWith('data:image/') || !value.contains(marker)) {
      return null;
    }
    final encoded = value.substring(value.indexOf(marker) + marker.length);
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PosColors.primary.withValues(alpha: 0.08),
      child: Icon(Icons.restaurant_menu, color: PosColors.primary, size: 28),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PosColors.primary.withValues(alpha: 0.08),
      child: Icon(Icons.broken_image_outlined, color: PosColors.muted),
    );
  }
}
