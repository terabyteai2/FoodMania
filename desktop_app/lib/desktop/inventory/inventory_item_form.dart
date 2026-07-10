import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/inventory_item.dart';
import 'package:local_pos/src/models/inventory_unit.dart';
import 'package:uuid/uuid.dart';

import '../theme/desk_theme.dart';

const _uuid = Uuid();

/// Add / edit a raw-material (inventory) item. Returns true when saved.
Future<bool?> showInventoryItemForm(BuildContext context, {InventoryItem? item}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _InventoryItemForm(item: item),
  );
}

class _InventoryItemForm extends StatefulWidget {
  const _InventoryItemForm({this.item});
  final InventoryItem? item;

  @override
  State<_InventoryItemForm> createState() => _InventoryItemFormState();
}

class _InventoryItemFormState extends State<_InventoryItemForm> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _category =
      TextEditingController(text: widget.item?.category ?? '');
  late final _qty = TextEditingController(
      text: widget.item == null ? '' : _n(widget.item!.quantity));
  late final _min = TextEditingController(
      text: widget.item == null ? '' : _n(widget.item!.minThreshold));
  late final _cost = TextEditingController(
      text: widget.item == null ? '' : _n(widget.item!.costPerUnit));
  late String _unit = widget.item?.unit ?? InventoryUnits.pcs;
  bool _busy = false;
  String? _error;

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _qty.dispose();
    _min.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Item name is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final item = InventoryItem(
        id: widget.item?.id ?? _uuid.v4(),
        name: name,
        category: _category.text.trim(),
        unit: _unit,
        quantity: double.tryParse(_qty.text.trim()) ?? 0,
        minThreshold: double.tryParse(_min.text.trim()) ?? 0,
        costPerUnit: double.tryParse(_cost.text.trim()) ?? 0,
        createdAt: widget.item?.createdAt ?? now,
        updatedAt: now,
      );
      await AppScope.read(context).saveInventoryItem(item);
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
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.xl),
      ),
      title: Text(widget.item == null ? 'Add stock item' : 'Edit stock item',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Item name', _name),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 2, child: _field('Category', _category)),
                const SizedBox(width: 12),
                Expanded(child: _unitField()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field('On hand', _qty, numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _field('Min level', _min, numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _field('Cost/unit (৳)', _cost, numeric: true)),
              ],
            ),
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
          style: FilledButton.styleFrom(backgroundColor: PosColors.primary),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white))
              : const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _unitField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Unit'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _unit,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadii.md),
            ),
          ),
          items: [
            for (final u in InventoryUnits.all)
              DropdownMenuItem(value: u, child: Text(u)),
          ],
          onChanged: (v) => setState(() => _unit = v ?? _unit),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          fontSize: DeskTypography.caption, fontWeight: FontWeight.w600, color: PosColors.ink2));

  Widget _field(String label, TextEditingController controller,
      {bool numeric = false}) {
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
