import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
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

  Future<void> _addItemFromPicker() async {
    final app = AppScope.of(context);
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemPickerSheet(
        items: app.inventoryItems,
        existingIds: _lines
            .map((l) => l.linkedItemId)
            .whereType<String>()
            .toSet(),
        text: app.strings,
      ),
    );
    if (result == null) return;
    setState(() {
      if (result.createNew) {
        _lines.add(_StockInLine.blank());
      } else if (result.item != null) {
        _lines.add(_StockInLine.fromItem(result.item!));
      }
    });
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
        final matchedId =
            line.linkedItemId ?? _matchExistingItem(app.inventoryItems, line);
        if (matchedId != null) {
          // Keep the saved unit price in sync if the user edited it.
          final unitPrice = line.parsedUnitPrice;
          if (unitPrice != null && unitPrice > 0) {
            final existing = app.inventoryItems
                .where((i) => i.id == matchedId)
                .firstOrNull;
            if (existing != null &&
                (existing.costPerUnit - unitPrice).abs() > 0.001) {
              await app.saveInventoryItem(
                existing.copyWith(
                  costPerUnit: unitPrice,
                  updatedAt: DateTime.now(),
                ),
              );
            }
          }
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

  String? _matchExistingItem(List<InventoryItem> items, _StockInLine line) {
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
            TfText(
              text.stockInTitle,
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w500,
              ),
            ),
            TfText(
              text.stepXofY(1, 2),
              style: TextStyle(
                fontSize: 11,
                color: PosColors.muted,
                fontWeight: FontWeight.w400,
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
              children: [
                Expanded(
                  child: TfText(
                    '${text.isBn ? 'আইটেম' : 'ITEMS'} · ${_lines.length}',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w500,
                      color: PosColors.muted,
                    ),
                  ),
                ),
                TfButton(
                  onPressed: _addItemFromPicker,
                  icon: Icons.add_rounded,
                  label: text.addItem,
                  size: TfButtonSize.sm,
                  fullWidth: false,
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
                child: TfText(
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
                  TfSectionHeader(
                    label: text.totalPaid,
                    padding: EdgeInsets.zero,
                  ),
                  TfText(
                    fmt.format(total),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              TfButton(
                label: text.saveAndAddToStock,
                busy: _saving,
                onPressed: _saving || _lines.where((l) => l.canSave).isEmpty
                    ? null
                    : _saveAll,
                size: TfButtonSize.lg,
                fullWidth: false,
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
              TfSectionHeader(
                label: text.dateLabel,
                padding: EdgeInsets.zero,
              ),
              TfText(                fmt.format(date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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
    return TfCard(
      color: PosColors.primarySoft,
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
                child: TfText(
                  text.scanSupplierBill,
                  style: TextStyle(
                    color: PosColors.primaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TfText(
            text.aiReadsItemsQtyPrices,
            style: TextStyle(
              color: PosColors.primaryDark.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TfButton(
                  onPressed: busy ? null : onCapture,
                  icon: Icons.photo_camera_rounded,
                  label: text.isBn ? 'ক্যামেরা' : 'Camera',
                  variant: TfButtonVariant.dark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TfButton(
                  onPressed: busy ? null : onPickGallery,
                  icon: Icons.photo_library_outlined,
                  label: text.isBn ? 'গ্যালারি' : 'Gallery',
                  variant: TfButtonVariant.paper,
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
                TfText(
                  text.scanningReceipt,
                  style: TextStyle(
                    color: PosColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (error != null && !busy) ...[
            const SizedBox(height: 10),
            TfText(
              error!,
              style: TextStyle(
                color: PosColors.primaryDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (provider != null && error == null && !busy) ...[
            const SizedBox(height: 6),
            TfText(
              text.isBn
                  ? 'AI ($provider) সফলভাবে পড়েছে'
                  : 'AI ($provider) read it',
              style: TextStyle(
                color: PosColors.primaryDark.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w400,
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TfCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TfText(
                  fmt.format(line.parsedTotal ?? 0),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        labelStyle: TextStyle(fontSize: 11, color: PosColors.muted),
      ),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    );
  }
}

class _StockInLine {
  _StockInLine({String? unit, this.linkedItemId})
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
    final entry = _StockInLine(unit: item.unit, linkedItemId: item.id);
    entry.nameCtrl.text = item.name;
    if (item.costPerUnit > 0) {
      entry.unitPriceCtrl.text = _formatNumber(item.costPerUnit);
    }
    return entry;
  }

  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitPriceCtrl;
  final TextEditingController totalCtrl;
  final String unit;
  final String? linkedItemId;

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

// ── Picker sheet ─────────────────────────────────────────────────────────────

class _PickerResult {
  const _PickerResult.existing(InventoryItem this.item) : createNew = false;
  const _PickerResult.createNew() : item = null, createNew = true;
  final InventoryItem? item;
  final bool createNew;
}

class _ItemPickerSheet extends StatefulWidget {
  const _ItemPickerSheet({
    required this.items,
    required this.existingIds,
    required this.text,
  });

  final List<InventoryItem> items;
  final Set<String> existingIds;
  final AppStrings text;

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final q = _query.trim().toLowerCase();
    final filtered =
        widget.items
            .where((item) {
              if (q.isEmpty) return true;
              return item.name.toLowerCase().contains(q);
            })
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PosColors.lineStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TfText(                      text.isBn ? 'আইটেম বেছে নিন' : 'Pick an item',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: text.searchInventory,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TfButton(
                label: 'Add new item',
                labelBn: 'নতুন আইটেম',
                icon: Icons.add_rounded,
                onPressed: () =>
                    Navigator.pop(context, const _PickerResult.createNew()),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: TfText(                        widget.items.isEmpty
                            ? (text.isBn
                                  ? 'কোনো সংরক্ষিত আইটেম নেই'
                                  : 'No saved items yet')
                            : text.noMatchingItems,
                        style: TextStyle(color: PosColors.muted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 0.5, indent: 16, endIndent: 16),
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        final unit = InventoryUnits.displayLabel(
                          item.unit,
                          isBn: text.isBn,
                        );
                        final alreadyAdded = widget.existingIds.contains(
                          item.id,
                        );
                        final priceText = item.costPerUnit > 0
                            ? '${fmt.format(item.costPerUnit)} / $unit'
                            : (text.isBn
                                  ? 'দাম সংরক্ষিত নেই'
                                  : 'No saved price');
                        return ListTile(
                          enabled: !alreadyAdded,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: PosColors.surfaceWarm,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: PosColors.line),
                            ),
                            alignment: Alignment.center,
                            child: TfText(                              item.name.isEmpty
                                  ? '?'
                                  : item.name.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: PosColors.slate,
                              ),
                            ),
                          ),
                          title: TfText(                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: TfText(                            priceText,
                            style: TextStyle(
                              fontSize: 12,
                              color: PosColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: alreadyAdded
                              ? TfText(                                  text.isBn ? 'যুক্ত' : 'Added',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: PosColors.muted,
                                  ),
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: PosColors.muted,
                                ),
                          onTap: alreadyAdded
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  _PickerResult.existing(item),
                                ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
