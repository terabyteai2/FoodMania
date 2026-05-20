import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/inventory_item.dart';
import '../../models/stock_adjustment.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({this.onNavigateToOrders, super.key});

  final VoidCallback? onNavigateToOrders;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final categories = [text.allCategories, ...app.inventoryCategories];
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = text.allCategories;
    }

    final items = app.inventoryItems.where((item) {
      final matchesCat = _selectedCategory == text.allCategories ||
          item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList(growable: false);

    final lowCount = app.lowStockCount;

    return AppScaffold(
      title: text.inventory,
      subtitle: text.inventorySubtitle,
      showDatePill: false,
      centerHeader: true,
      actions: [
        HeaderNotificationBell(
          onNavigateToOrders: widget.onNavigateToOrders ?? () {},
        ),
        PrimaryButton(
          label: text.addInventoryItem,
          icon: Icons.add,
          onPressed: () => _openForm(context),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lowCount > 0) _LowStockBanner(count: lowCount, text: text),
          _SearchBar(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          if (app.inventoryItems.isNotEmpty)
            _CategoryStrip(
              categories: categories,
              selected: _selectedCategory,
              countOf: (cat) => cat == text.allCategories
                  ? app.inventoryItems.length
                  : app.inventoryItems
                      .where((i) => i.category == cat)
                      .length,
              onSelected: (v) => setState(() => _selectedCategory = v),
            ),
          SizedBox(height: 8),
          if (app.inventoryItems.isEmpty)
            EmptyState(
              title: text.noInventoryItems,
              message: text.noInventoryMessage,
              icon: Icons.inventory_2_outlined,
              action: PrimaryButton(
                label: text.addInventoryItem,
                icon: Icons.add,
                onPressed: () => _openForm(context),
              ),
            )
          else if (items.isEmpty)
            EmptyState(
              title: 'No items found',
              message: 'Try a different search or category.',
              icon: Icons.search_off,
            )
          else
            _InventoryList(
              items: items,
              text: text,
              onEdit: (item) => _openForm(context, item: item),
              onDelete: (item) => _confirmDelete(context, item),
              onAdjust: (item) => _openAdjustDialog(context, item),
              onViewHistory: (item) => _openHistory(context, item),
            ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {InventoryItem? item}) async {
    final app = AppScope.of(context);
    final result = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InventoryForm(item: item, text: app.strings),
    );
    if (result != null && context.mounted) {
      await app.saveInventoryItem(result);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    InventoryItem item,
  ) async {
    final app = AppScope.of(context);
    final text = app.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(text.deleteInventoryItem),
        content: Text('${text.deleteInventoryConfirm}\n"${item.name}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(text.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: PosColors.danger,
            ),
            child: Text(text.deleteInventoryItem),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await app.deleteInventoryItem(item.id);
    }
  }

  Future<void> _openAdjustDialog(
    BuildContext context,
    InventoryItem item,
  ) async {
    final app = AppScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdjustStockSheet(item: item, text: app.strings),
    );
  }

  Future<void> _openHistory(BuildContext context, InventoryItem item) async {
    final app = AppScope.of(context);
    final history = await app.getStockAdjustments(item.id);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(
        item: item,
        adjustments: history,
        text: app.strings,
      ),
    );
  }
}

// ── Low Stock Banner ──────────────────────────────────────────────────────────

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({required this.count, required this.text});

  final int count;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PosColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PosColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: PosColors.warning, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text.lowStockCount(count),
              style: TextStyle(
                color: PosColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search inventory...',
          prefixIcon: Icon(Icons.search, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: PosColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: PosColors.line),
          ),
        ),
      ),
    );
  }
}

// ── Category Strip ────────────────────────────────────────────────────────────

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.countOf,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final int Function(String) countOf;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onSelected(cat),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? PosColors.primary : PosColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? PosColors.primary
                      : PosColors.line,
                ),
              ),
              child: Text(
                '$cat (${countOf(cat)})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isSelected
                      ? Colors.black87
                      : PosColors.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Inventory List ────────────────────────────────────────────────────────────

class _InventoryList extends StatelessWidget {
  const _InventoryList({
    required this.items,
    required this.text,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjust,
    required this.onViewHistory,
  });

  final List<InventoryItem> items;
  final AppStrings text;
  final ValueChanged<InventoryItem> onEdit;
  final ValueChanged<InventoryItem> onDelete;
  final ValueChanged<InventoryItem> onAdjust;
  final ValueChanged<InventoryItem> onViewHistory;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: 8),
      itemBuilder: (_, i) => _InventoryCard(
        item: items[i],
        text: text,
        onEdit: () => onEdit(items[i]),
        onDelete: () => onDelete(items[i]),
        onAdjust: () => onAdjust(items[i]),
        onViewHistory: () => onViewHistory(items[i]),
      ),
    );
  }
}

// ── Inventory Card ────────────────────────────────────────────────────────────

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.text,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjust,
    required this.onViewHistory,
  });

  final InventoryItem item;
  final AppStrings text;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdjust;
  final VoidCallback onViewHistory;

  Color get _statusColor {
    if (item.isOutOfStock) return PosColors.danger;
    if (item.isLowStock) return PosColors.warning;
    return PosColors.success;
  }

  String _statusLabel(AppStrings text) {
    if (item.isOutOfStock) return text.outOfStock;
    if (item.isLowStock) return text.lowStock;
    return text.inStock;
  }

  @override
  Widget build(BuildContext context) {
    final qtyFmt = NumberFormat('#,##0.##');
    final costFmt = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final color = _statusColor;

    return Container(
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isOutOfStock || item.isLowStock
              ? color.withValues(alpha: 0.35)
              : PosColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: PosColors.slate,
                        ),
                      ),
                      if (item.category.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: PosColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusChip(label: _statusLabel(text), color: color),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _StatBox(
                  label: text.currentStock,
                  value: '${qtyFmt.format(item.quantity)} ${item.unit}',
                  valueColor: color,
                  bold: true,
                ),
                SizedBox(width: 12),
                _StatBox(
                  label: text.minThreshold,
                  value: '${qtyFmt.format(item.minThreshold)} ${item.unit}',
                ),
                SizedBox(width: 12),
                _StatBox(
                  label: text.costPerUnit,
                  value: costFmt.format(item.costPerUnit),
                ),
              ],
            ),
            if (item.notes.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                item.notes,
                style: TextStyle(
                  fontSize: 12,
                  color: PosColors.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                _ActionButton(
                  icon: Icons.tune,
                  label: text.adjustStock,
                  onTap: onAdjust,
                  primary: true,
                ),
                SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.history,
                  label: text.adjustmentHistory,
                  onTap: onViewHistory,
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: text.editInventoryItem,
                  color: PosColors.muted,
                  padding: EdgeInsets.all(6),
                  constraints: BoxConstraints(),
                ),
                SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                  tooltip: text.deleteInventoryItem,
                  color: PosColors.danger.withValues(alpha: 0.7),
                  padding: EdgeInsets.all(6),
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: PosColors.muted,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? PosColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary
              ? PosColors.primary.withValues(alpha: 0.12)
              : PosColors.line.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primary
                ? PosColors.primary.withValues(alpha: 0.4)
                : PosColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: primary ? PosColors.primary : PosColors.muted,
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.black87 : PosColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inventory Form (Add/Edit) ─────────────────────────────────────────────────

class _InventoryForm extends StatefulWidget {
  const _InventoryForm({required this.item, required this.text});

  final InventoryItem? item;
  final AppStrings text;

  @override
  State<_InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends State<_InventoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _notesCtrl;

  static const _units = ['pcs', 'kg', 'g', 'L', 'mL', 'packet', 'bottle', 'box'];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _categoryCtrl = TextEditingController(text: item?.category ?? '');
    _unitCtrl = TextEditingController(
        text: item?.unit ?? _units.first);
    _quantityCtrl = TextEditingController(
        text: item != null ? item.quantity.toString() : '0');
    _minCtrl = TextEditingController(
        text: item != null ? item.minThreshold.toString() : '0');
    _costCtrl = TextEditingController(
        text: item != null ? item.costPerUnit.toString() : '0');
    _notesCtrl = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _unitCtrl.dispose();
    _quantityCtrl.dispose();
    _minCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final isEdit = widget.item != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: PosColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _SheetHandle(),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Row(
                children: [
                  Text(
                    isEdit ? text.editInventoryItem : text.addInventoryItem,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FormField(
                        label: text.itemName,
                        controller: _nameCtrl,
                        required: true,
                        textCapitalization: TextCapitalization.words,
                      ),
                      SizedBox(height: 14),
                      _FormField(
                        label: text.itemCategory,
                        controller: _categoryCtrl,
                        hint: 'e.g. Protein, Vegetable, Beverage',
                        textCapitalization: TextCapitalization.words,
                      ),
                      SizedBox(height: 14),
                      _label(text.unit),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _units.map((u) {
                          final selected = _unitCtrl.text == u;
                          return GestureDetector(
                            onTap: () => setState(() => _unitCtrl.text = u),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected
                                    ? PosColors.primary
                                    : PosColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? PosColors.primary
                                      : PosColors.line,
                                ),
                              ),
                              child: Text(
                                u,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _FormField(
                              label: text.currentStock,
                              controller: _quantityCtrl,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                              required: true,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _FormField(
                              label: text.minThreshold,
                              controller: _minCtrl,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                              required: true,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14),
                      _FormField(
                        label: '${text.costPerUnit} (৳)',
                        controller: _costCtrl,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        required: true,
                      ),
                      SizedBox(height: 14),
                      _FormField(
                        label: text.notes,
                        controller: _notesCtrl,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: text.save,
                          icon: Icons.check,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: PosColors.slate,
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final existing = widget.item;
    final item = InventoryItem(
      id: existing?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
      quantity: double.tryParse(_quantityCtrl.text) ?? 0,
      minThreshold: double.tryParse(_minCtrl.text) ?? 0,
      costPerUnit: double.tryParse(_costCtrl.text) ?? 0,
      notes: _notesCtrl.text.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, item);
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PosColors.slate,
          ),
        ),
        SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: PosColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: PosColors.line),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Adjust Stock Sheet ────────────────────────────────────────────────────────

class _AdjustStockSheet extends StatefulWidget {
  const _AdjustStockSheet({required this.item, required this.text});

  final InventoryItem item;
  final AppStrings text;

  @override
  State<_AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends State<_AdjustStockSheet> {
  bool _isAdding = true;
  AdjustmentType _type = AdjustmentType.restock;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = widget.text;
    final qtyFmt = NumberFormat('#,##0.##');

    return Container(
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(),
          Row(
            children: [
              Text(
                text.adjustStock,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            widget.item.name,
            style: TextStyle(
              fontSize: 14,
              color: PosColors.muted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${text.currentStock}: ${qtyFmt.format(widget.item.quantity)} ${widget.item.unit}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PosColors.slate,
            ),
          ),
          SizedBox(height: 16),
          // Add / Remove toggle
          Row(
            children: [
              Expanded(
                child: _ToggleBtn(
                  label: text.addStock,
                  selected: _isAdding,
                  color: PosColors.success,
                  icon: Icons.add_circle_outline,
                  onTap: () => setState(() {
                    _isAdding = true;
                    _type = AdjustmentType.restock;
                  }),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ToggleBtn(
                  label: text.removeStock,
                  selected: !_isAdding,
                  color: PosColors.danger,
                  icon: Icons.remove_circle_outline,
                  onTap: () => setState(() {
                    _isAdding = false;
                    _type = AdjustmentType.usage;
                  }),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          // Type chips
          Text(
            text.reason,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _typesFor(_isAdding).map((t) {
              final sel = _type == t;
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? PosColors.primary
                        : PosColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel
                          ? PosColors.primary
                          : PosColors.line,
                    ),
                  ),
                  child: Text(
                    t.label(isBn: text.isBn),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              labelText:
                  '${text.amount} (${widget.item.unit})',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: PosColors.line),
              ),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: '${text.notes} (optional)',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: PosColors.line),
              ),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: text.save,
              icon: Icons.check,
              onPressed: _busy
                  ? null
                  : () async {
                      final amt =
                          double.tryParse(_amountCtrl.text);
                      if (amt == null || amt <= 0) return;
                      setState(() => _busy = true);
                      try {
                        await app.adjustStock(
                          inventoryItemId: widget.item.id,
                          delta: _isAdding ? amt : -amt,
                          type: _type,
                          note: _noteCtrl.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  List<AdjustmentType> _typesFor(bool adding) {
    return adding
        ? [AdjustmentType.restock, AdjustmentType.correction]
        : [
            AdjustmentType.usage,
            AdjustmentType.waste,
            AdjustmentType.correction,
          ];
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : PosColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : PosColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? color : PosColors.muted),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : PosColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Sheet ─────────────────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({
    required this.item,
    required this.adjustments,
    required this.text,
  });

  final InventoryItem item;
  final List<StockAdjustment> adjustments;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM, hh:mm a');
    final qtyFmt = NumberFormat('#,##0.##');

    return Container(
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            _SheetHandle(),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.adjustmentHistory,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: PosColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: adjustments.isEmpty
                  ? Center(
                      child: Text(
                        text.noHistory,
                        style: TextStyle(color: PosColors.muted),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      itemCount: adjustments.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1),
                      itemBuilder: (_, i) {
                        final adj = adjustments[i];
                        final isAdd = adj.delta >= 0;
                        final color = isAdd
                            ? PosColors.success
                            : PosColors.danger;
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isAdd
                                      ? Icons.add
                                      : Icons.remove,
                                  size: 16,
                                  color: color,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          adj.type.label(
                                              isBn: text.isBn),
                                          style: TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '${isAdd ? '+' : ''}${qtyFmt.format(adj.delta)} ${item.unit}',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight:
                                                FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (adj.note.isNotEmpty)
                                      Text(
                                        adj.note,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              PosColors.muted,
                                        ),
                                      ),
                                    Text(
                                      dateFmt.format(adj.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            PosColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: PosColors.line,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
