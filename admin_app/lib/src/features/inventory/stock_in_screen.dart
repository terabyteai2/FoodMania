import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_unit.dart';
import '../../models/receipt_scan.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';

class StockInScreen extends StatefulWidget {
  const StockInScreen({this.preseedItemId, super.key});

  final String? preseedItemId;

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final List<_StockInLine> _lines = [];
  final DateTime _date = DateTime.now();
  bool _scanning = false;
  bool _saving = false;
  String? _scanError;
  String? _scanProvider;
  final MenuImageService _imageService = MenuImageService();
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    if (widget.preseedItemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _seedFromItem());
    }
  }

  void _seedFromItem() {
    final app = AppScope.of(context);
    final item = app.inventoryItems
        .where((i) => i.id == widget.preseedItemId)
        .firstOrNull;
    if (item != null) {
      setState(() {
        _lines.add(_StockInLine.fromItem(item));
      });
    }
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addBlankLine() {
    setState(() => _lines.add(_StockInLine.blank()));
  }

  void _removeLine(_StockInLine line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  Future<void> _pickAndScan({required bool fromCamera}) async {
    if (_scanning) return;
    final app = AppScope.of(context);
    setState(() {
      _scanning = true;
      _scanError = null;
    });
    try {
      final pages = <PickedMenuScanPage>[];
      if (fromCamera) {
        final page = await _imageService.captureMenuScanPage(
          pageNumber: _lines.length + 1,
        );
        if (page != null) pages.add(page);
      } else {
        pages.addAll(await _imageService.pickMenuScanPages());
      }
      if (pages.isEmpty) {
        setState(() => _scanning = false);
        return;
      }
      final uploads = pages
          .map(
            (page) => MenuScanPageUpload(
              bytes: page.bytes,
              fileName: page.fileName,
              mimeType: page.mimeType,
            ),
          )
          .toList(growable: false);
      final result = await app.scanInventoryReceipt(uploads);
      setState(() {
        _scanProvider = result.provider;
        for (final line in result.items) {
          _lines.add(_StockInLine.fromScan(line));
        }
      });
    } on CloudApiException catch (error) {
      setState(() => _scanError = error.message);
    } on MenuImageException catch (error) {
      setState(() => _scanError = error.message);
    } catch (error) {
      setState(() => _scanError = error.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _saveAll() async {
    if (_saving) return;
    final valid = _lines.where((l) => l.canSave).toList(growable: false);
    if (valid.isEmpty) return;
    setState(() => _saving = true);
    final app = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final line in valid) {
        final qty = line.parsedQty!;
        final total = line.parsedTotal ?? 0;
        final matchedId = _matchExistingItem(app.inventoryItems, line);
        if (matchedId != null) {
          await app.recordInventoryPurchase(
            inventoryItemId: matchedId,
            quantity: qty,
            totalCostBdt: total,
          );
        } else {
          final newItem = InventoryItem(
            id: _uuid.v4(),
            name: line.nameCtrl.text.trim(),
            category: '',
            unit: InventoryUnits.normalize(line.unit),
            quantity: 0,
            minThreshold: 0,
            costPerUnit: line.parsedUnitPrice ?? 0,
            notes: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await app.saveInventoryItem(newItem);
          await app.recordInventoryPurchase(
            inventoryItemId: newItem.id,
            quantity: qty,
            totalCostBdt: total,
          );
        }
      }
      await app.refreshInventorySummary();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _matchExistingItem(
    List<InventoryItem> items,
    _StockInLine line,
  ) {
    final name = line.nameCtrl.text.trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final item in items) {
      if (item.name.toLowerCase() == name) return item.id;
      if (name.contains(item.name.toLowerCase()) ||
          item.name.toLowerCase().contains(name)) {
        return item.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final total = _lines.fold<double>(
      0,
      (sum, line) => sum + (line.parsedTotal ?? 0),
    );
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.stockInTitle,
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              text.stepXofY(1, 2),
              style: TextStyle(
                fontSize: 11,
                color: PosColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
          children: [
            _DateRow(date: _date, text: text),
            const SizedBox(height: 14),
            _ScanCard(
              text: text,
              busy: _scanning,
              error: _scanError,
              provider: _scanProvider,
              onPickGallery: () => _pickAndScan(fromCamera: false),
              onCapture: () => _pickAndScan(fromCamera: true),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${text.isBn ? 'আইটেম' : 'ITEMS'} · ${_lines.length}',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                    color: PosColors.muted,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addBlankLine,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('+ ${text.addManually}'),
                ),
              ],
            ),
            for (final line in _lines)
              _LineCard(
                line: line,
                text: text,
                onRemove: () => _removeLine(line),
                onChanged: () => setState(() {}),
              ),
            if (_lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  text.isBn
                      ? 'রিসিট স্ক্যান করুন বা হাতে যোগ করুন।'
                      : 'Scan a receipt or add items manually.',
                  style: TextStyle(color: PosColors.muted),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: PosColors.primaryDark,
            border: Border(top: BorderSide(color: PosColors.line)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text.totalPaid.toUpperCase(),
                    style: TextStyle(
                      color: PosColors.muted,
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    fmt.format(total),
                    style: TextStyle(
                      color: PosColors.slate,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving || _lines.where((l) => l.canSave).isEmpty
                    ? null
                    : _saveAll,
                style: FilledButton.styleFrom(
                  backgroundColor: PosColors.primary,
                  foregroundColor: PosColors.primaryDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(text.saveAndAddToStock),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.text});

  final DateTime date;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, h:mm a');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, color: PosColors.muted, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text.dateLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: PosColors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                fmt.format(date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: PosColors.slate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.text,
    required this.busy,
    required this.error,
    required this.provider,
    required this.onPickGallery,
    required this.onCapture,
  });

  final AppStrings text;
  final bool busy;
  final String? error;
  final String? provider;
  final VoidCallback onPickGallery;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PosShadows.glow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.document_scanner_outlined,
                color: PosColors.primaryDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text.scanSupplierBill,
                  style: TextStyle(
                    color: PosColors.primaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text.aiReadsItemsQtyPrices,
            style: TextStyle(
              color: PosColors.primaryDark.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onCapture,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: Text(text.isBn ? 'ক্যামেরা' : 'Camera'),
                  style: FilledButton.styleFrom(
                    backgroundColor: PosColors.primaryDark,
                    foregroundColor: PosColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(text.isBn ? 'গ্যালারি' : 'Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PosColors.primaryDark,
                    side: BorderSide(color: PosColors.primaryDark),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  text.scanningReceipt,
                  style: TextStyle(
                    color: PosColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          if (error != null && !busy) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: TextStyle(
                color: PosColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (provider != null && error == null && !busy) ...[
            const SizedBox(height: 6),
            Text(
              text.isBn
                  ? 'AI ($provider) সফলভাবে পড়েছে'
                  : 'AI ($provider) read it',
              style: TextStyle(
                color: PosColors.primaryDark.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.text,
    required this.onRemove,
    required this.onChanged,
  });

  final _StockInLine line;
  final AppStrings text;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: line.nameCtrl,
                  onChanged: (_) => onChanged(),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Item name',
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                fmt.format(line.parsedTotal ?? 0),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: PosColors.slate,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: PosColors.muted,
                onPressed: onRemove,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: line.qtyCtrl,
                  label: '${text.qtyLabel} (${line.unit})',
                  onChanged: (_) {
                    line.recomputeTotalFromUnitPrice();
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  controller: line.unitPriceCtrl,
                  label: text.pricePerUnit(line.unit),
                  onChanged: (_) {
                    line.recomputeTotalFromUnitPrice();
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  controller: line.totalCtrl,
                  label: text.newStockLabel,
                  onChanged: (_) {
                    line.recomputeUnitPriceFromTotal();
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 0,
        ),
        labelStyle: TextStyle(fontSize: 11, color: PosColors.muted),
      ),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }
}

class _StockInLine {
  _StockInLine({String? unit})
      : nameCtrl = TextEditingController(),
        qtyCtrl = TextEditingController(),
        unitPriceCtrl = TextEditingController(),
        totalCtrl = TextEditingController(),
        unit = unit ?? 'kg';

  factory _StockInLine.blank() => _StockInLine();

  factory _StockInLine.fromScan(ReceiptScanLine line) {
    final entry = _StockInLine(unit: line.unit);
    entry.nameCtrl.text = line.nameEn.isNotEmpty ? line.nameEn : line.nameBn;
    entry.qtyCtrl.text = _formatNumber(line.qty);
    entry.unitPriceCtrl.text = _formatNumber(line.unitPriceBdt);
    entry.totalCtrl.text = _formatNumber(line.totalBdt);
    return entry;
  }

  factory _StockInLine.fromItem(InventoryItem item) {
    final entry = _StockInLine(unit: item.unit);
    entry.nameCtrl.text = item.name;
    entry.unitPriceCtrl.text = _formatNumber(item.costPerUnit);
    return entry;
  }

  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitPriceCtrl;
  final TextEditingController totalCtrl;
  final String unit;

  double? get parsedQty => double.tryParse(qtyCtrl.text.trim());
  double? get parsedUnitPrice => double.tryParse(unitPriceCtrl.text.trim());
  double? get parsedTotal => double.tryParse(totalCtrl.text.trim());

  bool get canSave {
    final qty = parsedQty;
    final name = nameCtrl.text.trim();
    return name.isNotEmpty && qty != null && qty > 0;
  }

  void recomputeTotalFromUnitPrice() {
    final qty = parsedQty;
    final unitPrice = parsedUnitPrice;
    if (qty != null && unitPrice != null) {
      final total = qty * unitPrice;
      if (parsedTotal == null ||
          (parsedTotal! - total).abs() / (total + 0.0001) > 0.02) {
        totalCtrl.text = _formatNumber(total);
      }
    }
  }

  void recomputeUnitPriceFromTotal() {
    final qty = parsedQty;
    final total = parsedTotal;
    if (qty != null && qty > 0 && total != null) {
      final unitPrice = total / qty;
      unitPriceCtrl.text = _formatNumber(unitPrice);
    }
  }

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    unitPriceCtrl.dispose();
    totalCtrl.dispose();
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
