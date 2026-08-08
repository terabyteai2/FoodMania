import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_unit.dart';
import '../../models/receipt_scan.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';

class StockInScreen extends StatefulWidget {
  const StockInScreen({this.preseedItemId, this.initialScan, super.key});

  final String? preseedItemId;

  /// When the user arrives here from the unified Inventory-page Scan (the
  /// backend already classified the photo as a supplier bill), the parsed lines
  /// are passed in so we skip a second OCR round-trip.
  final StockScanResult? initialScan;

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final List<_StockInLine> _lines = [];
  final Map<String, TextEditingController> _existingCtrls = {};
  bool _scanning = false;
  bool _saving = false;
  String? _scanError;
  String? _scanProvider;
  final MenuImageService _imageService = MenuImageService();
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    final scan = widget.initialScan;
    if (scan != null && scan.items.isNotEmpty) {
      // Already scanned upstream — seed the editor and light up the scanned
      // confirm UI without re-running OCR.
      _scanProvider = scan.provider;
      for (final line in scan.items) {
        _lines.add(_StockInLine.fromScan(line));
      }
    } else if (widget.preseedItemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _seedFromItem());
    } else {
      _lines.add(_StockInLine.blank());
    }
  }

  void _seedFromItem() {
    final app = AppScope.of(context);
    final item = app.inventoryItems
        .where((i) => i.id == widget.preseedItemId)
        .firstOrNull;
    if (item != null) {
      setState(() {
        _lines.add(_StockInLine.fromItem(item, language: app.language));
      });
    } else if (_lines.isEmpty) {
      setState(() => _lines.add(_StockInLine.blank()));
    }
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    for (final ctrl in _existingCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onExistingChanged() {
    if (mounted) setState(() {});
  }

  void _removeLine(_StockInLine line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
      if (_lines.isEmpty) {
        _lines.add(_StockInLine.blank());
      }
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
      final result = await app.scanInventoryStock(
        uploads,
        category: StockScanCategory.stockIn,
      );
      setState(() {
        _scanProvider = result.provider;
        _lines.removeWhere((line) {
          final blank = line.isBlank;
          if (blank) line.dispose();
          return blank;
        });
        for (final line in result.items) {
          _lines.add(_StockInLine.fromScan(line));
        }
        if (_lines.isEmpty) {
          _lines.add(_StockInLine.blank());
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
    if (valid.isEmpty &&
        _existingCtrls.values.every((c) => c.text.trim().isEmpty)) {
      return;
    }
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
          final existing = app.inventoryItems
              .where((i) => i.id == matchedId)
              .firstOrNull;
          if (existing != null) {
            var updatedExisting = existing;
            final mergedName = line.inventoryNameForExisting(existing.name);
            if (mergedName != existing.name) {
              updatedExisting = updatedExisting.copyWith(name: mergedName);
            }
            final unitPrice = line.parsedUnitPrice;
            if (unitPrice != null &&
                unitPrice > 0 &&
                (existing.costPerUnit - unitPrice).abs() > 0.001) {
              updatedExisting = updatedExisting.copyWith(
                costPerUnit: unitPrice,
              );
            }
            if (updatedExisting.name != existing.name ||
                (updatedExisting.costPerUnit - existing.costPerUnit).abs() >
                    0.001) {
              await app.saveInventoryItem(updatedExisting);
            }
          }
          await app.recordInventoryPurchase(
            inventoryItemId: matchedId,
            quantity: qty,
            totalCostBdt: total,
            supplierId: null,
            supplierName: '',
            billRef: '',
          );
        } else {
          final newItem = InventoryItem(
            id: _uuid.v4(),
            name: line.inventoryNameForSave,
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
            supplierId: null,
            supplierName: '',
            billRef: '',
          );
        }
      }
      // Save existing-item quick entries
      for (final entry in _existingCtrls.entries) {
        final qty = double.tryParse(entry.value.text.trim());
        if (qty == null || qty <= 0) continue;
        final existing = app.inventoryItems
            .where((i) => i.id == entry.key)
            .firstOrNull;
        if (existing == null) continue;
        await app.recordInventoryPurchase(
          inventoryItemId: entry.key,
          quantity: qty,
          totalCostBdt: qty * existing.costPerUnit,
          supplierId: null,
          supplierName: '',
          billRef: '',
        );
      }
      await app.refreshInventorySummary();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addLine() {
    setState(() => _lines.add(_StockInLine.blank()));
  }

  String? _matchExistingItem(List<InventoryItem> items, _StockInLine line) {
    final name = line.nameCtrl.text.trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final item in items) {
      final itemNames = [item.name, item.nameEn, item.nameBn]
          .expand(_StockInLine.splitMatchableNames)
          .toSet()
          .toList(growable: false);
      for (final itemName in itemNames) {
        if (itemName == name) return item.id;
        if (name.contains(itemName) || itemName.contains(name)) {
          return item.id;
        }
      }
      for (final lineName in line.matchableNames) {
        if (lineName.isEmpty) continue;
        if (itemNames.contains(lineName)) {
          return item.id;
        }
        if (itemNames.any(
          (itemName) =>
              lineName.contains(itemName) || itemName.contains(lineName),
        )) {
          return item.id;
        }
      }
      if (name.contains(item.name.toLowerCase()) ||
          item.name.toLowerCase().contains(name)) {
        return item.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final scanned = _scanProvider != null;
    final preseedTitle = widget.preseedItemId == null || _lines.isEmpty
        ? null
        : _lines.first.nameCtrl.text.trim();
    final subtitle = scanned
        ? [
            text.stockInScanSubtitle,
            if ((_scanProvider ?? '').trim().isNotEmpty) _scanProvider!.trim(),
          ].join(' · ')
        : (preseedTitle?.isNotEmpty ?? false)
        ? preseedTitle!
        : text.stockInSubtitle;
    final total = _lines.fold<double>(
      0,
      (sum, line) => sum + line.computedTotal,
    );
    final hasExisting = _existingCtrls.values.any((c) {
      final v = double.tryParse(c.text.trim());
      return v != null && v > 0;
    });
    final canSave = _lines.any((line) => line.canSave) || hasExisting;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Shared slim pushed bar (v4 §5.1).
            TfGlobalTopBar.leaf(
              title: scanned ? text.stockInConfirmTitle : text.stockInTitle,
              subtitle: subtitle,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TfText(
                      text.stockInInstruction,
                      style: TfTextStyles.bodyMuted.copyWith(
                        color: PosColors.muted,
                      ),
                    ),
                  ),
                  if (_scanning || _scanError != null || _scanProvider != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ScanCallout(
                        text: text,
                        busy: _scanning,
                        error: _scanError,
                        provider: _scanProvider,
                        lineCount: _lines.where((line) => !line.isBlank).length,
                      ),
                    ),
                  for (var i = 0; i < _lines.length; i++) ...[
                    _LineCard(
                      key: ValueKey(
                        'stock-in-line-${_lines[i].linkedItemId ?? _lines[i].identity}',
                      ),
                      index: i,
                      line: _lines[i],
                      text: text,
                      showRemove: _lines.length > 1,
                      onRemove: () => _removeLine(_lines[i]),
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _AddAnotherLineButton(text: text, onPressed: _addLine),
                  const SizedBox(height: 8),
                  _ExistingItemsSection(
                    items: app.inventoryItems,
                    text: text,
                    controllers: _existingCtrls,
                    onChanged: _onExistingChanged,
                  ),
                ],
              ),
            ),
            _StockInBottomBar(
              text: text,
              total: total,
              saving: _saving,
              scanning: _scanning,
              canSave: canSave,
              onScan: () => _pickAndScan(fromCamera: true),
              onSave: _saveAll,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _ScanCallout extends StatelessWidget {
  const _ScanCallout({
    required this.text,
    required this.busy,
    required this.error,
    required this.provider,
    required this.lineCount,
  });

  final AppStrings text;
  final bool busy;
  final String? error;
  final String? provider;
  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final isError = error != null;
    final message = busy
        ? text.scanningReceipt
        : isError
        ? error!
        : '${tfFormatNumber(context, lineCount)} ${text.stockInScanReadHint}';

    return TfCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      color: isError ? PosColors.dangerSoft : PosColors.neutralSoft,
      borderColor: isError ? PosColors.danger : PosColors.neutralWash,
      child: Row(
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.auto_awesome_rounded,
              size: 19,
              color: isError ? PosColors.danger : PosColors.primaryDark,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: TfText(
              provider == null || busy || isError
                  ? message
                  : '$message · $provider',
              style: TfTextStyles.bodyMuted.copyWith(
                color: PosColors.slate,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockInBottomBar extends StatelessWidget {
  const _StockInBottomBar({
    required this.text,
    required this.total,
    required this.saving,
    required this.scanning,
    required this.canSave,
    required this.onScan,
    required this.onSave,
  });

  final AppStrings text;
  final double total;
  final bool saving;
  final bool scanning;
  final bool canSave;
  final VoidCallback onScan;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    // Chrome (surface + bar shadow + SafeArea) comes from TfStickyCTA;
    // paired footer = navy secondary + primary, both Expanded (v4 §5.5).
    return TfStickyCTA(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TfText(
                  text.totalStockInValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TfTextStyles.bodyMuted.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TfText(
                tfFormatCurrency(context, total),
                style: TfTextStyles.rowMoney.copyWith(
                  color: PosColors.slate,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TfButton(
                  label: text.scanBill,
                  icon: Icons.camera_alt_outlined,
                  variant: TfButtonVariant.dark,
                  size: TfButtonSize.lg,
                  busy: scanning,
                  onPressed: scanning ? null : onScan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TfButton(
                  label: text.addToInventory,
                  icon: Icons.check_rounded,
                  size: TfButtonSize.lg,
                  busy: saving,
                  onPressed: saving || !canSave ? null : onSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.text,
    required this.showRemove,
    required this.onRemove,
    required this.onChanged,
    required this.index,
    super.key,
  });

  final _StockInLine line;
  final AppStrings text;
  final bool showRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final int index;

  @override
  Widget build(BuildContext context) {
    final unitLabel = InventoryUnits.displayLabel(line.unit, isBn: text.isBn);
    return TfCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TfText(
              'Item ${index + 1}',
              style: TfTextStyles.rowTitle.copyWith(
                color: PosColors.text,
              ),
            ),
          ),
          Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PosColors.surfaceSunk,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 19,
                      color: PosColors.slate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: ValueKey('stock-in-name-${line.identity}'),
                      controller: line.nameCtrl,
                      onChanged: (_) => onChanged(),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Item name',
                        isDense: true,
                      ),
                      style: TfTextStyles.rowTitle.copyWith(
                        color: PosColors.slate,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (showRemove)
                    SizedBox.square(
                      dimension: 30,
                      child: IconButton(
                        key: ValueKey('stock-in-remove-${line.identity}'),
                        padding: EdgeInsets.zero,
                        tooltip: text.cancel,
                        icon: const Icon(Icons.close_rounded, size: 17),
                        color: PosColors.muted,
                        onPressed: onRemove,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuantityField(
                      line: line,
                      label: text.stockInQuantityLabel,
                      text: text,
                      onChanged: onChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CostField(
                      controller: line.unitPriceCtrl,
                      label: text.stockInCostPerUnit(unitLabel),
                      fieldKey: ValueKey('stock-in-cost-${line.identity}'),
                      onChanged: (_) {
                        line.recomputeTotalFromUnitPrice();
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

class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.line,
    required this.label,
    required this.text,
    required this.onChanged,
  });

  final _StockInLine line;
  final String label;
  final AppStrings text;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _FieldColumn(
      label: label,
      child: _SourceFieldFrame(
        child: Row(
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: ValueKey('stock-in-unit-${line.identity}'),
                value: InventoryUnits.normalize(line.unit),
                isDense: true,
                borderRadius: BorderRadius.circular(10),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                style: TfTextStyles.bodyMuted.copyWith(
                  color: PosColors.slate,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
                items: InventoryUnits.all
                    .map(
                      (unit) => DropdownMenuItem<String>(
                        value: unit,
                        child: TfText(
                          InventoryUnits.displayLabel(unit, isBn: text.isBn),
                          style: TfTextStyles.bodyMuted.copyWith(
                            color: PosColors.slate,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (unit) {
                  if (unit == null) return;
                  line.unit = InventoryUnits.normalize(unit);
                  line.recomputeTotalFromUnitPrice();
                  onChanged();
                },
              ),
            ),
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: PosColors.line,
            ),
            Expanded(
              child: TextField(
                key: ValueKey('stock-in-qty-${line.identity}'),
                controller: line.qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) {
                  line.recomputeTotalFromUnitPrice();
                  onChanged();
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: TfTextStyles.rowTitle.copyWith(
                  color: PosColors.slate,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostField extends StatelessWidget {
  const _CostField({
    required this.controller,
    required this.label,
    required this.fieldKey,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final Key fieldKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FieldColumn(
      label: label,
      child: _SourceFieldFrame(
        child: Row(
          children: [
            TfText(
              '৳',
              style: TfTextStyles.rowMoney.copyWith(
                color: PosColors.muted,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                style: TfTextStyles.rowTitle.copyWith(
                  color: PosColors.slate,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldColumn extends StatelessWidget {
  const _FieldColumn({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfText(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TfTextStyles.label.copyWith(
            color: PosColors.muted,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _SourceFieldFrame extends StatelessWidget {
  const _SourceFieldFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.lineStrong),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _AddAnotherLineButton extends StatelessWidget {
  const _AddAnotherLineButton({required this.text, required this.onPressed});

  final AppStrings text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: CustomPaint(
            painter: _DashedBorderPainter(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: PosColors.primaryDark,
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: TfText(
                      text.addAnotherLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TfTextStyles.rowTitle.copyWith(
                        color: PosColors.primaryDark,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Existing items quick-stock-in section ─────────────────────────────────────

class _ExistingItemsSection extends StatelessWidget {
  const _ExistingItemsSection({
    required this.items,
    required this.text,
    required this.controllers,
    required this.onChanged,
  });

  final List<InventoryItem> items;
  final AppStrings text;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TfText(
            text.inventory.toUpperCase(),
            style: TfTextStyles.eyebrow.copyWith(
              color: PosColors.text,
              letterSpacing: 0.8,
            ),
          ),
        ),
        for (final item in items)
          _ExistingStockInRow(
            item: item,
            controller: controllers.putIfAbsent(item.id, () {
              final ctrl = TextEditingController();
              ctrl.addListener(onChanged);
              return ctrl;
            }),
            text: text,
          ),
      ],
    );
  }
}

class _ExistingStockInRow extends StatelessWidget {
  const _ExistingStockInRow({
    required this.item,
    required this.controller,
    required this.text,
  });

  final InventoryItem item;
  final TextEditingController controller;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final unit = InventoryUnits.displayLabel(item.unit, isBn: text.isBn);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.card),
          border: Border.all(color: PosColors.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PosColors.surfaceSunk,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.grid_on_rounded,
                size: 16,
                color: PosColors.inkSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TfText(
                item.localizedName(AppScope.of(context).language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TfTextStyles.rowTitle.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: PosColors.text,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: TextField(
                controller: controller,
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

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 5.0;
    const gap = 4.0;
    final rect = Offset.zero & size;
    final radius = Radius.circular(PosRadii.md);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = PosColors.lineStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    var distance = 0.0;
    while (distance < metric.length) {
      final next = distance + dash;
      canvas.drawPath(metric.extractPath(distance, next), paint);
      distance = next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StockInLine {
  _StockInLine({
    String? unit,
    this.linkedItemId,
    String? scannedNameEn,
    String? scannedNameBn,
  }) : identity = _nextIdentity++,
       scannedNameEn = scannedNameEn?.trim() ?? '',
       scannedNameBn = scannedNameBn?.trim() ?? '',
       nameCtrl = TextEditingController(),
       qtyCtrl = TextEditingController(),
       unitPriceCtrl = TextEditingController(),
       totalCtrl = TextEditingController(),
       unit = InventoryUnits.normalize(unit ?? InventoryUnits.kg);

  factory _StockInLine.blank() => _StockInLine();

  factory _StockInLine.fromScan(ReceiptScanLine line) {
    final nameEn = line.nameEn.trim();
    final nameBn = line.nameBn.trim();
    final entry = _StockInLine(
      unit: line.unit,
      scannedNameEn: nameEn,
      scannedNameBn: nameBn,
    );
    entry.nameCtrl.text = nameEn.isNotEmpty ? nameEn : nameBn;
    entry.qtyCtrl.text = _formatNumber(line.qty);
    entry.unitPriceCtrl.text = _formatNumber(line.unitPriceBdt);
    entry.totalCtrl.text = _formatNumber(line.totalBdt);
    return entry;
  }

  factory _StockInLine.fromItem(InventoryItem item, {AppLanguage? language}) {
    final entry = _StockInLine(unit: item.unit, linkedItemId: item.id);
    entry.nameCtrl.text = language == null
        ? item.name
        : item.localizedName(language);
    if (item.costPerUnit > 0) {
      entry.unitPriceCtrl.text = _formatNumber(item.costPerUnit);
    }
    return entry;
  }

  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitPriceCtrl;
  final TextEditingController totalCtrl;
  final int identity;
  String unit;
  final String? linkedItemId;
  final String scannedNameEn;
  final String scannedNameBn;

  static int _nextIdentity = 0;

  double? get parsedQty => double.tryParse(qtyCtrl.text.trim());
  double? get parsedUnitPrice => double.tryParse(unitPriceCtrl.text.trim());
  double? get parsedTotal {
    final qty = parsedQty;
    final unitPrice = parsedUnitPrice;
    if (qty != null && unitPrice != null) return qty * unitPrice;
    return double.tryParse(totalCtrl.text.trim());
  }

  double get computedTotal => parsedTotal ?? 0;

  bool get isBlank =>
      linkedItemId == null &&
      nameCtrl.text.trim().isEmpty &&
      qtyCtrl.text.trim().isEmpty &&
      unitPriceCtrl.text.trim().isEmpty &&
      scannedNameEn.isEmpty &&
      scannedNameBn.isEmpty;

  bool get canSave {
    final qty = parsedQty;
    final name = nameCtrl.text.trim();
    return name.isNotEmpty && qty != null && qty > 0;
  }

  String get inventoryNameForSave {
    final entered = nameCtrl.text.trim();
    if (entered.isEmpty || entered.contains('/')) return entered;

    final scannedEn = scannedNameEn.trim();
    final scannedBn = scannedNameBn.trim();
    if (_containsBengali(entered)) {
      if (scannedEn.isNotEmpty &&
          !_containsBengali(scannedEn) &&
          scannedEn.toLowerCase() != entered.toLowerCase()) {
        return '$scannedEn / $entered';
      }
      return entered;
    }

    if (scannedBn.isNotEmpty &&
        _containsBengali(scannedBn) &&
        scannedBn.toLowerCase() != entered.toLowerCase()) {
      return '$entered / $scannedBn';
    }
    return entered;
  }

  String inventoryNameForExisting(String currentName) {
    final current = currentName.trim();
    if (current.isEmpty) return inventoryNameForSave;
    if (current.contains('/') || _containsBengali(current)) return current;
    final merged = inventoryNameForSave;
    if (merged.contains('/') && _containsBengali(merged)) return merged;
    return current;
  }

  List<String> get matchableNames {
    return [
      nameCtrl.text,
      inventoryNameForSave,
      scannedNameEn,
      scannedNameBn,
    ].expand(_StockInLine.splitMatchableNames).toSet().toList(growable: false);
  }

  static List<String> splitMatchableNames(String value) {
    final raw = value.trim().toLowerCase();
    if (raw.isEmpty) return const [];
    if (!raw.contains('/')) return [raw];
    final parts = raw
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return [raw, ...parts];
  }

  static bool _containsBengali(String value) {
    return RegExp(r'[\u0980-\u09FF]').hasMatch(value);
  }

  void recomputeTotalFromUnitPrice() {
    final qty = parsedQty;
    final unitPrice = parsedUnitPrice;
    if (qty != null && unitPrice != null) {
      final total = qty * unitPrice;
      totalCtrl.text = _formatNumber(total);
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
