import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_unit.dart';
import '../../models/receipt_scan.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';

class EndOfDayCountScreen extends StatefulWidget {
  const EndOfDayCountScreen({this.initialScan, super.key});

  /// When the user arrives from the unified Inventory-page Scan (the backend
  /// classified the photo as a count sheet), the parsed lines are passed in so
  /// matched quantities pre-fill without a second OCR round-trip.
  final StockScanResult? initialScan;

  @override
  State<EndOfDayCountScreen> createState() => _EndOfDayCountScreenState();
}

class _EndOfDayCountScreenState extends State<EndOfDayCountScreen> {
  final Map<String, TextEditingController> _controllers = {};

  /// inventoryItemId -> counted qty read from a scan (overrides the on-hand
  /// prefill). Populated from `initialScan` and any in-screen re-scan.
  final Map<String, double> _scannedQty = {};

  /// Scanned names that didn't match any inventory item — surfaced in a banner,
  /// never silently dropped or auto-created (hide-don't-fabricate invariant).
  final List<String> _unmatched = [];

  bool _saving = false;
  bool _scanning = false;
  final MenuImageService _imageService = MenuImageService();

  @override
  void initState() {
    super.initState();
    _applyScan(widget.initialScan);
  }

  void _applyScan(StockScanResult? scan) {
    if (scan == null) return;
    for (final line in scan.items) {
      final id = line.matchedInventoryItemId;
      if (id != null && id.isNotEmpty) {
        _scannedQty[id] = line.qty;
      } else {
        final name = line.nameEn.isNotEmpty ? line.nameEn : line.nameBn;
        if (name.trim().isNotEmpty) _unmatched.add(name.trim());
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(InventoryItem item) =>
      _controllers.putIfAbsent(item.id, () {
        final seeded = _scannedQty[item.id];
        return TextEditingController(text: _fmtQty(seeded ?? item.quantity));
      });

  static String _fmtQty(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  Future<void> _pickAndScan() async {
    if (_scanning) return;
    final app = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _scanning = true);
    try {
      final page = await _imageService.captureMenuScanPage(pageNumber: 1);
      if (page == null) {
        setState(() => _scanning = false);
        return;
      }
      final result = await app.scanInventoryStock([
        MenuScanPageUpload(
          bytes: page.bytes,
          fileName: page.fileName,
          mimeType: page.mimeType,
        ),
      ], category: StockScanCategory.count);
      setState(() {
        _scannedQty.clear();
        _unmatched.clear();
        _applyScan(result);
        // Push freshly-scanned counts into any controllers already built.
        for (final entry in _scannedQty.entries) {
          _controllers[entry.key]?.text = _fmtQty(entry.value);
        }
      });
    } on CloudApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on MenuImageException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final app = AppScope.of(context);
    try {
      for (final item in app.inventoryItems) {
        final value = double.tryParse(_controller(item).text.trim());
        if (value != null) {
          await app.setInventoryEndOfDayCount(
            inventoryItemId: item.id,
            quantity: value,
          );
        }
      }
      await app.refreshInventorySummary();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.background,
        title: const TfText(
          'End-of-day count',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PosColors.primaryWash,
              borderRadius: BorderRadius.circular(PosRadii.card),
            ),
            child: const TfText(
              'Count what is physically on hand. Differences are recorded as count corrections.',
              style: TextStyle(color: PosColors.primaryDark, fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
            ),
          ),
          if (_unmatched.isNotEmpty) ...[
            const SizedBox(height: 12),
            _UnmatchedBanner(title: text.countScanUnmatched, names: _unmatched),
          ],
          const SizedBox(height: 16),
          for (final item in app.inventoryItems)
            _CountLine(item: item, controller: _controller(item)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(
          color: PosColors.surface,
          boxShadow: PosShadows.bar,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              SizedBox(
                width: 130,
                child: TfButton(
                  label: _scanning ? text.scanningStock : text.scanStock,
                  icon: Icons.document_scanner_outlined,
                  variant: TfButtonVariant.ghost,
                  size: TfButtonSize.lg,
                  busy: _scanning,
                  onPressed: _scanning ? null : _pickAndScan,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TfButton(
                  label: 'Save count',
                  size: TfButtonSize.lg,
                  busy: _saving,
                  onPressed: _saving || _scanning ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnmatchedBanner extends StatelessWidget {
  const _UnmatchedBanner({required this.title, required this.names});

  final String title;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PosColors.warningSoft,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.help_outline_rounded, size: 19, color: PosColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  title,
                  style: const TextStyle(
                    color: PosColors.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                TfText(
                  names.join(', '),
                  style: const TextStyle(
                    color: PosColors.slate,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountLine extends StatelessWidget {
  const _CountLine({required this.item, required this.controller});
  final InventoryItem item;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final unit = InventoryUnits.displayLabel(item.unit, isBn: tfIsBn(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TfCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: TfText(
                item.localizedName(AppScope.of(context).language),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(
              width: 104,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.end,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(suffixText: unit, isDense: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
