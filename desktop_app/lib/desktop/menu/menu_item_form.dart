import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/menu_item.dart';

import '../theme/desk_theme.dart';

/// Add / edit a menu item. Editing preserves the item's existing `tags`
/// (options / add-ons / discount encoding) since those aren't edited here.
/// Returns true when saved.
Future<bool?> showMenuItemForm(
  BuildContext context, {
  MenuItem? item,
  List<String> categories = const [],
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _MenuItemForm(item: item, categories: categories),
  );
}

class _MenuItemForm extends StatefulWidget {
  const _MenuItemForm({this.item, required this.categories});
  final MenuItem? item;
  final List<String> categories;

  @override
  State<_MenuItemForm> createState() => _MenuItemFormState();
}

class _MenuItemFormState extends State<_MenuItemForm> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _category =
      TextEditingController(text: widget.item?.category ?? '');
  late final _price = TextEditingController(
      text: widget.item == null ? '' : _trimNum(widget.item!.price));
  late final _shortCode =
      TextEditingController(text: widget.item?.shortCode?.toString() ?? '');
  late final _description =
      TextEditingController(text: widget.item?.description ?? '');
  late bool _available = widget.item?.isAvailable ?? true;
  bool _busy = false;
  String? _error;

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _price.dispose();
    _shortCode.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Item name is required.');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = 'Enter a valid price.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final app = AppScope.read(context);
      await app.saveMenuItem(
        id: widget.item?.id,
        name: name,
        description: _description.text.trim(),
        category: _category.text.trim(),
        price: price,
        isAvailable: _available,
        shortCode: int.tryParse(_shortCode.text.trim()),
        tags: widget.item?.tags ?? const [],
        createdAt: widget.item?.createdAt,
      );
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
      title: Text(widget.item == null ? 'Add item' : 'Edit item',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Item name', _name),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _field('Category', _category)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field('Short code', _shortCode, numeric: true)),
                ],
              ),
              if (widget.categories.isNotEmpty) _categoryChips(),
              const SizedBox(height: 12),
              _field('Price (৳)', _price, numeric: true, decimal: true),
              const SizedBox(height: 12),
              _field('Description', _description, maxLines: 2),
              const SizedBox(height: 4),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: PosColors.primary,
                value: _available,
                onChanged: (v) => setState(() => _available = v),
                title: const Text('Available',
                    style: TextStyle(
                        fontSize: DeskTypography.bodySmall, fontWeight: FontWeight.w600)),
              ),
              if (_error != null)
                Text(_error!,
                    style: const TextStyle(
                        color: PosColors.danger, fontSize: DeskTypography.caption)),
            ],
          ),
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

  Widget _categoryChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in widget.categories.take(12))
            ActionChip(
              label: Text(c, style: const TextStyle(fontSize: DeskTypography.eyebrow)),
              onPressed: () => setState(() => _category.text = c),
              backgroundColor: PosColors.surfaceSunk,
              side: const BorderSide(color: PosColors.line),
            ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    bool decimal = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: DeskTypography.caption,
                fontWeight: FontWeight.w600,
                color: PosColors.ink2)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: numeric
              ? TextInputType.numberWithOptions(decimal: decimal)
              : null,
          inputFormatters: numeric
              ? [
                  FilteringTextInputFormatter.allow(
                      RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
                ]
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
