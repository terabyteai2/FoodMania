import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_unit.dart';
import '../../models/receipt_scan.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';

class EndOfDayCountScreen extends StatefulWidget {
  const EndOfDayCountScreen({this.initialScan, super.key});

  final StockScanResult? initialScan;

  @override
  State<EndOfDayCountScreen> createState() => _EndOfDayCountScreenState();
}

class _EndOfDayCountScreenState extends State<EndOfDayCountScreen> {
  final Map<String, TextEditingController> _controllers = {};

  final Map<String, double> _scannedQty = {};

  final List<String> _unmatched = [];
  final Set<String> _touchedItemIds = {};

  bool _saving = false;
  bool _scanning = false;
  final MenuImageService _imageService = MenuImageService();

  int get _done => _touchedItemIds.length;

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
        return TextEditingController(
          text: seeded != null ? _fmtQty(seeded) : _fmtQty(item.quantity),
        );
      });

  static String _fmtQty(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

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
        for (final entry in _scannedQty.entries) {
          _controllers[entry.key]?.text = _fmtQty(entry.value);
          _touchedItemIds.add(entry.key);
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
    final items = app.inventoryItems;
    final total = items.length;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Shared slim pushed bar (v4 §5.1) instead of a Material AppBar.
            TfGlobalTopBar.leaf(
              title: text.stockCountTitle,
              subtitle: text.countedOf(_done, total),
            ),
            if (total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(color: PosColors.surfaceSunk),
                        AnimatedFractionallySizedBox(
                          widthFactor: _done / total,
                          duration: const Duration(milliseconds: 200),
                          child: Container(color: PosColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_unmatched.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _UnmatchedBanner(
                  title: text.countScanUnmatched,
                  names: _unmatched,
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TfText(
                text.endOfDayCountInstruction,
                style: TfTextStyles.bodyMuted.copyWith(
                  color: PosColors.muted,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final item in items)
                    _CountLine(
                      item: item,
                      controller: _controller(item),
                      onTouched: () =>
                          setState(() => _touchedItemIds.add(item.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Paired sticky footer (v4 §5.5): navy secondary + primary, both
      // Expanded; chrome comes from TfStickyCTA.
      bottomNavigationBar: TfStickyCTA(
        child: Row(
          children: [
            Expanded(
              child: TfButton(
                label: _scanning ? text.scanningStock : text.scanStock,
                icon: Icons.document_scanner_outlined,
                variant: TfButtonVariant.dark,
                size: TfButtonSize.lg,
                busy: _scanning,
                onPressed: _scanning ? null : _pickAndScan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TfButton(
                label: text.finishCount(_done),
                size: TfButtonSize.lg,
                busy: _saving,
                onPressed: _saving || _scanning ? null : _save,
              ),
            ),
          ],
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
          const Icon(
            Icons.help_outline_rounded,
            size: 19,
            color: PosColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  title,
                  style: TfTextStyles.bodyMuted.copyWith(
                    color: PosColors.warning,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                TfText(
                  names.join(', '),
                  style: TfTextStyles.bodyMuted.copyWith(
                    color: PosColors.slate,
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

class _CountLine extends StatefulWidget {
  const _CountLine({
    required this.item,
    required this.controller,
    this.onTouched,
  });
  final InventoryItem item;
  final TextEditingController controller;
  final VoidCallback? onTouched;

  @override
  State<_CountLine> createState() => _CountLineState();
}

class _CountLineState extends State<_CountLine> {
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_CountLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!_touched) {
      final entered = double.tryParse(widget.controller.text.trim());
      if (entered != null && entered != widget.item.quantity) {
        _touched = true;
        widget.onTouched?.call();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unit = InventoryUnits.displayLabel(item.unit, isBn: tfIsBn(context));
    final counted = _touched;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.card),
          border: Border.all(
            color: counted ? PosColors.primaryWash : PosColors.line,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: counted ? PosColors.primary : PosColors.surfaceSunk,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                counted ? Icons.check_rounded : Icons.grid_on_rounded,
                size: 16,
                color: counted ? PosColors.accentInk : PosColors.inkSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TfText(
                item.localizedName(AppScope.of(context).language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TfTextStyles.rowTitle.copyWith(
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: TextField(
                controller: widget.controller,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(
                  hintText: '—',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  hintStyle: TfTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: PosColors.mutedSoft,
                  ),
                ),
                style: TfTextStyles.rowTitle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: PosColors.text,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 26,
              child: TfText(
                unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TfTextStyles.bodyMuted.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
