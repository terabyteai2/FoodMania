import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/menu_item.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import 'cart_line.dart';

/// Blue modifier/quantity popover shown when a menu item has size options or
/// add-ons (`item.extras`). Returns a configured [CartLine], or null on cancel.
Future<CartLine?> showItemCustomizer(
  BuildContext context, {
  required MenuItem item,
}) {
  return showDialog<CartLine>(
    context: context,
    builder: (_) => _ItemCustomizerDialog(item: item),
  );
}

class _ItemCustomizerDialog extends StatefulWidget {
  const _ItemCustomizerDialog({required this.item});
  final MenuItem item;

  @override
  State<_ItemCustomizerDialog> createState() => _ItemCustomizerDialogState();
}

class _ItemCustomizerDialogState extends State<_ItemCustomizerDialog> {
  late final List<MenuOption> _options = widget.item.extras.options;
  late final List<MenuAddOn> _addOns = widget.item.extras.addOns;
  int _optionIndex = 0;
  final Set<int> _addOnIndexes = <int>{};
  int _qty = 1;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  double get _optionDelta =>
      _options.isEmpty ? 0 : _options[_optionIndex].priceDelta;

  List<MenuAddOn> get _selectedAddOns =>
      [for (var i = 0; i < _addOns.length; i++) if (_addOnIndexes.contains(i)) _addOns[i]];

  double get _unit {
    final addOnTotal = _selectedAddOns.fold<double>(0, (s, a) => s + a.price);
    final v = widget.item.price + _optionDelta + addOnTotal;
    return v < 0 ? 0 : v;
  }

  CartLine _build() => CartLine(
        item: widget.item,
        optionLabel: _options.isEmpty ? '' : _options[_optionIndex].name,
        optionPriceDelta: _optionDelta,
        addOns: _selectedAddOns,
        qty: _qty,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).language;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.xl),
      ),
      title: Text(
        widget.item.localizedName(lang),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: DeskTypography.h3),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${money(context, widget.item.price)} base',
                  style: TextStyle(fontSize: DeskTypography.caption, color: PosColors.muted)),
              if (_options.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionLabel('Size / option'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _options.length; i++) _optionChip(i),
                  ],
                ),
              ],
              if (_addOns.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionLabel('Add-ons'),
                const SizedBox(height: 4),
                for (var i = 0; i < _addOns.length; i++)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: PosColors.primary,
                    value: _addOnIndexes.contains(i),
                    title: Text(_addOns[i].name,
                        style: const TextStyle(fontSize: DeskTypography.bodySmall)),
                    secondary: _addOns[i].price == 0
                        ? null
                        : Text('+${money(context, _addOns[i].price)}',
                            style: TextStyle(color: PosColors.ink2)),
                    onChanged: (v) => setState(() {
                      if (v ?? false) {
                        _addOnIndexes.add(i);
                      } else {
                        _addOnIndexes.remove(i);
                      }
                    }),
                  ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Kitchen note',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PosRadii.md),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Quantity',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: PosColors.ink2)),
                  const Spacer(),
                  _Stepper(
                    qty: _qty,
                    onMinus: _qty <= 1 ? null : () => setState(() => _qty--),
                    onPlus: () => setState(() => _qty++),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: PosColors.ink2)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PosColors.primary),
          onPressed: () => Navigator.pop(context, _build()),
          child: Text('Add · ${money(context, _unit * _qty)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: DeskTypography.bodySmall),
      );

  Widget _optionChip(int i) {
    final option = _options[i];
    final active = i == _optionIndex;
    final delta = option.priceDelta;
    final suffix = delta == 0
        ? ''
        : ' ${delta > 0 ? '+' : ''}${money(context, delta)}';
    return InkWell(
      borderRadius: BorderRadius.circular(PosRadii.md),
      onTap: () => setState(() => _optionIndex = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? PosColors.primary : PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(
            color: active ? PosColors.primary : PosColors.lineStrong,
          ),
        ),
        child: Text(
          '${option.name}$suffix',
          style: TextStyle(
            fontSize: DeskTypography.bodySmall,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : PosColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.qty, this.onMinus, this.onPlus});
  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _circle(Icons.remove_rounded, onMinus),
        SizedBox(
          width: 36,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: DeskTypography.title)),
        ),
        _circle(Icons.add_rounded, onPlus),
      ],
    );
  }

  Widget _circle(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? PosColors.primary : PosColors.lineStrong,
            width: 1.4,
          ),
        ),
        child: Icon(icon,
            size: 17,
            color: enabled ? PosColors.primary : PosColors.mutedSoft),
      ),
    );
  }
}
