import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/widgets/tf_design_system.dart';
import 'package:image/image.dart' as img;

/// Returns a centered square PNG for menu thumbnails.
class SquareImageCropperPage extends StatefulWidget {
  const SquareImageCropperPage({required this.imageBytes, super.key});

  final Uint8List imageBytes;

  @override
  State<SquareImageCropperPage> createState() => _SquareImageCropperPageState();
}

class _SquareImageCropperPageState extends State<SquareImageCropperPage> {
  bool _busy = false;

  Future<void> _useSquareCrop() async {
    setState(() => _busy = true);
    try {
      final decoded = img.decodeImage(widget.imageBytes);
      if (decoded == null) {
        throw const FormatException('Could not read the selected image.');
      }
      final edge = decoded.width < decoded.height
          ? decoded.width
          : decoded.height;
      final cropped = img.copyCrop(
        decoded,
        x: (decoded.width - edge) ~/ 2,
        y: (decoded.height - edge) ~/ 2,
        width: edge,
        height: edge,
      );
      if (!mounted) return;
      Navigator.pop(context, Uint8List.fromList(img.encodePng(cropped)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TfText('Crop menu photo'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TfButton(
              label: 'Use',
              variant: TfButtonVariant.ghost,
              size: TfButtonSize.sm,
              fullWidth: false,
              busy: _busy,
              onPressed: _busy ? null : _useSquareCrop,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(widget.imageBytes, fit: BoxFit.cover),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
