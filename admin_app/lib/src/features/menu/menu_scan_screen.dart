import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';

class MenuScanScreen extends StatefulWidget {
  const MenuScanScreen({super.key});

  @override
  State<MenuScanScreen> createState() => _MenuScanScreenState();
}

enum _Mode { capture, preview }

class _MenuScanScreenState extends State<MenuScanScreen> {
  final MenuImageService _imageService = MenuImageService();
  final List<PickedMenuScanPage> _pages = [];
  final List<Uint8List> _thumbnails = [];
  int _selectedIndex = 0;
  CameraController? _cameraController;
  bool _cameraReady = false;
  _Mode _mode = _Mode.capture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _pickFromGallery();
        return;
      }
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (_) {
      if (!mounted) return;
      _pickFromGallery();
    }
  }

  void _addPage(PickedMenuScanPage page) {
    setState(() {
      _pages.add(page);
      _thumbnails.add(_makeThumb(page.bytes));
      _selectedIndex = _pages.length - 1;
      _mode = _Mode.preview;
    });
  }

  void _removePage(int index) {
    setState(() {
      _pages.removeAt(index);
      _thumbnails.removeAt(index);
      if (_selectedIndex >= _pages.length) {
        _selectedIndex = _pages.length - 1;
      }
      if (_pages.isEmpty) {
        _mode = _Mode.capture;
      }
    });
  }

  Uint8List _makeThumb(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final thumb = img.copyResize(decoded, width: 200);
    return Uint8List.fromList(img.encodeJpg(thumb, quality: 85));
  }

  Uint8List _processCapture(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final oriented = img.bakeOrientation(decoded);
    final longest =
        oriented.width > oriented.height ? oriented.width : oriented.height;
    final resized = longest > MenuImageService.maxEdgePx
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height
                ? MenuImageService.maxEdgePx
                : null,
            height: oriented.height > oriented.width
                ? MenuImageService.maxEdgePx
                : null,
            interpolation: img.Interpolation.average,
          )
        : oriented;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
  }

  Future<void> _capture() async {
    if (_cameraController == null || !_cameraReady) return;
    try {
      final xFile = await _cameraController!.takePicture();
      var bytes = await xFile.readAsBytes();
      bytes = _processCapture(bytes);
      _addPage(PickedMenuScanPage(
        bytes: bytes,
        mimeType: 'image/jpeg',
        fileName: 'scan-page-${_pages.length + 1}.jpg',
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TfText('Capture failed')),
      );
    }
  }

  void _addMore() {
    setState(() => _mode = _Mode.capture);
  }

  Future<void> _pickFromGallery() async {
    final pages = await _imageService.pickMenuScanPages();
    if (!mounted) return;
    for (final page in pages) {
      if (_pages.length >= MenuImageService.maxScanPages) break;
      _addPage(page);
    }
  }

  Future<void> _scanAll() async {
    if (_pages.isEmpty) return;

    // Fire-and-forget: pop immediately with the captured pages. The caller
    // launches the upload in the background; the backend streams progress via
    // realtime events.
    final uploads = _pages
        .map(
          (page) => MenuScanPageUpload(
            bytes: page.bytes,
            fileName: page.fileName,
            mimeType: page.mimeType,
          ),
        )
        .toList(growable: false);
    Navigator.of(context).pop(uploads);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;

    return Scaffold(
      backgroundColor:
          _mode == _Mode.capture ? Colors.black : PosColors.background,
      appBar: _mode == _Mode.preview
          ? AppBar(
              backgroundColor: PosColors.surface,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: PosColors.text),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: TfText(text.menuScan, style: TfTextStyles.appBarTitle),
            )
          : null,
      body: _mode == _Mode.capture ? _captureBody() : _previewBody(),
      bottomNavigationBar: _mode == _Mode.preview
          ? TfStickyCTA(
              child: TfButton(
                label: text.menuScanPages(_pages.length),
                size: TfButtonSize.lg,
                onPressed: _scanAll,
              ),
            )
          : null,
    );
  }

  Widget _captureBody() {
    final padTop = MediaQuery.of(context).padding.top;
    final padBottom = MediaQuery.of(context).padding.bottom;
    final text = AppScope.of(context).strings;

    return Stack(
      children: [
        if (_cameraReady)
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          )
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.document_scanner_outlined,
                    size: 64, color: Colors.white54),
                const SizedBox(height: PosSpacing.sp3),
                TfText(
                  text.isBn
                      ? 'ক্যামেরা শুরু করা যায়নি'
                      : 'Could not start camera',
                  style: TfTextStyles.body.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: PosSpacing.sp3),
                TfButton(
                  label: text.isBn
                      ? 'গ্যালারি থেকে বেছে নিন'
                      : 'Pick from gallery',
                  size: TfButtonSize.sm,
                  fullWidth: false,
                  onPressed: _pickFromGallery,
                ),
              ],
            ),
          ),
        Positioned(
          top: padTop + PosSpacing.sp2,
          left: PosSpacing.sp4,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: padBottom + PosSpacing.sp6,
          child: Center(
            child: GestureDetector(
              onTap: _pages.length < MenuImageService.maxScanPages
                  ? _capture
                  : null,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _pages.length < MenuImageService.maxScanPages
                      ? Colors.white
                      : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.black87,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewBody() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(PosSpacing.sp4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PosRadii.card),
              child: InteractiveViewer(
                child: Image.memory(
                  _pages[_selectedIndex].bytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: PosSpacing.sp4,
              vertical: PosSpacing.sp2,
            ),
            itemCount: _pages.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _MThumbnailTile(
                  onTap: _pages.length < MenuImageService.maxScanPages
                      ? _pickFromGallery
                      : null,
                  child: Icon(Icons.photo_library_outlined,
                      color: PosColors.primary, size: 28),
                );
              }
              if (index == _pages.length + 1) {
                return _MThumbnailTile(
                  onTap: _pages.length < MenuImageService.maxScanPages
                      ? _addMore
                      : null,
                  child: Icon(Icons.add_rounded,
                      color: PosColors.primary, size: 28),
                );
              }
              final pageIndex = index - 1;
              return _MPageThumbnail(
                thumb: _thumbnails[pageIndex],
                isSelected: pageIndex == _selectedIndex,
                onTap: () => setState(() {
                  _selectedIndex = pageIndex;
                  _mode = _Mode.preview;
                }),
                onRemove: () => _removePage(pageIndex),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MThumbnailTile extends StatelessWidget {
  const _MThumbnailTile({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: PosSpacing.sp2),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Material(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(PosRadii.card),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PosRadii.card),
                border: Border.all(color: PosColors.line),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _MPageThumbnail extends StatelessWidget {
  const _MPageThumbnail({
    required this.thumb,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
  });
  final Uint8List thumb;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: PosSpacing.sp2),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Material(
              color: PosColors.surface,
              borderRadius: BorderRadius.circular(PosRadii.card),
              child: InkWell(
                borderRadius: BorderRadius.circular(PosRadii.card),
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PosRadii.card),
                    border: Border.all(
                      color: isSelected ? PosColors.primary : PosColors.line,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(thumb, fit: BoxFit.cover),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: PosColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: PosColors.accentInk),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
