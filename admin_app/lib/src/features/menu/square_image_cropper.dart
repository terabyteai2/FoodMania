import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';

/// Returns a user-positioned square JPEG for menu thumbnails.
class SquareImageCropperPage extends StatefulWidget {
  const SquareImageCropperPage({required this.imageBytes, super.key});

  final Uint8List imageBytes;

  @override
  State<SquareImageCropperPage> createState() => _SquareImageCropperPageState();
}

class _SquareImageCropperPageState extends State<SquareImageCropperPage> {
  static const int _outputEdgePx = 720;
  static const int _jpegQuality = 82;

  final TransformationController _transform = TransformationController();
  img.Image? _decoded;
  Uint8List? _previewBytes;
  bool _busy = false;
  double? _initializedSide;

  @override
  void initState() {
    super.initState();
    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded != null) {
      final oriented = img.bakeOrientation(decoded);
      _decoded = oriented;
      _previewBytes = Uint8List.fromList(img.encodeJpg(oriented, quality: 90));
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _ensureInitialMatrix(double side) {
    final decoded = _decoded;
    if (decoded == null || _initializedSide == side) return;
    final scale = math.max(side / decoded.width, side / decoded.height);
    final dx = (side - decoded.width * scale) / 2;
    final dy = (side - decoded.height * scale) / 2;
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
    _initializedSide = side;
  }

  Future<void> _useSquareCrop(double side) async {
    final text = AppScope.read(context).strings;
    setState(() => _busy = true);
    try {
      final decoded = _decoded;
      if (decoded == null) {
        throw FormatException(text.menuPhotoReadFailed);
      }
      final cropped = _cropVisibleSquare(decoded, side);
      final resized = cropped.width == _outputEdgePx
          ? cropped
          : img.copyResize(
              cropped,
              width: _outputEdgePx,
              height: _outputEdgePx,
              interpolation: img.Interpolation.average,
            );
      final encoded = Uint8List.fromList(
        img.encodeJpg(resized, quality: _jpegQuality),
      );
      if (!mounted) return;
      Navigator.pop(context, encoded);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(error.toString())));
      setState(() => _busy = false);
    }
  }

  img.Image _cropVisibleSquare(img.Image source, double side) {
    try {
      final inverse = Matrix4.inverted(_transform.value);
      final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
      final bottomRight = MatrixUtils.transformPoint(
        inverse,
        Offset(side, side),
      );
      final left = math
          .min(topLeft.dx, bottomRight.dx)
          .clamp(0.0, source.width.toDouble())
          .toDouble();
      final top = math
          .min(topLeft.dy, bottomRight.dy)
          .clamp(0.0, source.height.toDouble())
          .toDouble();
      final right = math
          .max(topLeft.dx, bottomRight.dx)
          .clamp(0.0, source.width.toDouble())
          .toDouble();
      final bottom = math
          .max(topLeft.dy, bottomRight.dy)
          .clamp(0.0, source.height.toDouble())
          .toDouble();
      final cropWidth = math.max(1, (right - left).round());
      final cropHeight = math.max(1, (bottom - top).round());
      final edge = math.min(cropWidth, cropHeight);
      final x = (left + (cropWidth - edge) / 2)
          .round()
          .clamp(0, math.max(0, source.width - edge))
          .toInt();
      final y = (top + (cropHeight - edge) / 2)
          .round()
          .clamp(0, math.max(0, source.height - edge))
          .toInt();
      return img.copyCrop(source, x: x, y: y, width: edge, height: edge);
    } catch (_) {
      final edge = math.min(source.width, source.height);
      return img.copyCrop(
        source,
        x: (source.width - edge) ~/ 2,
        y: (source.height - edge) ~/ 2,
        width: edge,
        height: edge,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.selectMany(context, const [AppAspect.language]).strings;
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        title: TfText(text.cropMenuPhoto),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Builder(
              builder: (context) {
                return TfButton(
                  label: text.usePhoto,
                  variant: TfButtonVariant.ghost,
                  size: TfButtonSize.sm,
                  fullWidth: false,
                  busy: _busy,
                  onPressed: _busy || _decoded == null
                      ? null
                      : () => _useSquareCrop(_initializedSide ?? 720),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                if (_decoded == null || _previewBytes == null) {
                  return TfCard(
                    child: TfText(
                      text.menuPhotoReadFailed,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                _ensureInitialMatrix(side);
                final decoded = _decoded!;
                final baseScale = math.max(
                  side / decoded.width,
                  side / decoded.height,
                );
                return SizedBox.square(
                  dimension: side,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PosColors.surface,
                        borderRadius: BorderRadius.circular(PosRadii.md),
                        border: Border.all(
                          color: PosColors.lineStrong,
                          width: 0.5,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          InteractiveViewer(
                            transformationController: _transform,
                            minScale: baseScale,
                            maxScale: baseScale * 5,
                            constrained: false,
                            boundaryMargin: EdgeInsets.all(side),
                            child: SizedBox(
                              width: decoded.width.toDouble(),
                              height: decoded.height.toDouble(),
                              child: Image.memory(
                                _previewBytes!,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  PosRadii.md,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
