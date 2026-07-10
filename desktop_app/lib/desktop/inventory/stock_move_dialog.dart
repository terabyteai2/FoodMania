import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/inventory_item.dart';
import 'package:local_pos/src/models/inventory_unit.dart';

import '../theme/desk_theme.dart';

enum StockMoveKind { stockIn, use }

/// Stock-in (purchase) or usage/waste for one inventory item. Returns true when
/// the movement was recorded.
Future<bool?> showStockMoveDialog(
  BuildContext context, {
  required InventoryItem item,
  required StockMoveKind kind,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _StockMoveDialog(item: item, kind: kind),
  );
}

class _StockMoveDialog extends StatefulWidget {
  const _StockMoveDialog({required this.item, required this.kind});
  final InventoryItem item;
  final StockMoveKind kind;

  @override
  State<_StockMoveDialog> createState() => _StockMoveDialogState();
}

class _StockMoveDialogState extends State<_StockMoveDialog> {
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  final _supplier = TextEditingController();
  String _reason = 'kitchen';
  bool _busy = false;
  String? _error;

  bool get _isStockIn => widget.kind == StockMoveKind.stockIn;

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    _supplier.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qty.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final app = AppScope.read(context);
      if (_isStockIn) {
        await app.recordInventoryPurchase(
          inventoryItemId: widget.item.id,
          quantity: qty,
          totalCostBdt: double.tryParse(_cost.text.trim()) ?? 0,
          supplierName: _supplier.text.trim(),
        );
      } else {
        await app.recordInventoryUsage(
          inventoryItemId: widget.item.id,
          quantity: qty,
          reason: _reason,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = InventoryUnits.displayLabel(widget.item.unit);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.xl),
      ),
      title: Text(_isStockIn ? 'Stock in' : 'Record usage',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('On hand: ${widget.item.quantity} $unit',
                style: TextStyle(fontSize: DeskTypography.caption, color: PosColors.muted)),
            const SizedBox(height: 14),
            _field('Quantity ($unit)', _qty),
            if (_isStockIn) ...[
              const SizedBox(height: 12),
              _field('Total cost (৳)', _cost),
              const SizedBox(height: 12),
              _field('Supplier (optional)', _supplier, numeric: false),
            ] else ...[
              const SizedBox(height: 12),
              _label('Reason'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _reasonChip('kitchen', 'Kitchen use'),
                  _reasonChip('waste', 'Waste'),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: PosColors.danger, fontSize: DeskTypography.caption)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: PosColors.ink2)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor:
                  _isStockIn ? PosColors.primary : PosColors.warning),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white))
              : Text(_isStockIn ? 'Add stock' : 'Record',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _reasonChip(String value, String label) {
    final active = _reason == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _reason = value),
      selectedColor: PosColors.primary,
      labelStyle: TextStyle(
          color: active ? Colors.white : PosColors.primaryDark,
          fontWeight: FontWeight.w600,
          fontSize: DeskTypography.caption),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          fontSize: DeskTypography.caption, fontWeight: FontWeight.w600, color: PosColors.ink2));

  Widget _field(String label, TextEditingController controller,
      {bool numeric = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          inputFormatters: numeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadii.md),
            ),
          ),
        ),
      ],
    );
  }
}
