import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/inventory_item.dart';
import 'package:local_pos/src/models/inventory_unit.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import 'inventory_item_form.dart';
import 'stock_move_dialog.dart';

/// Inventory / raw-materials management (petpooja21 style): a dense table with
/// on-hand + low-stock status, plus stock-in, usage/waste, add / edit / delete.
/// Receipt-scan import is intentionally excluded.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await AppScope.read(context).refreshInventory();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: PosColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _delete(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete stock item?'),
        content: Text('“${item.name}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: PosColors.ink2)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _act(() => AppScope.read(context).deleteInventoryItem(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final query = _searchCtl.text.trim().toLowerCase();
    final items = app.inventoryItems.where((i) {
      if (query.isEmpty) return true;
      return i.name.toLowerCase().contains(query) ||
          i.category.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(app.inventoryItems.length),
        _headerRow(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? Center(
                      child: Text('No stock items',
                          style: TextStyle(color: PosColors.muted)))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: PosColors.line),
                      itemBuilder: (_, i) => _row(items[i]),
                    ),
        ),
      ],
    );
  }

  Widget _toolbar(int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const Text('Inventory',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('$total items',
              style: TextStyle(fontSize: 13, color: PosColors.muted)),
          const Spacer(),
          SizedBox(
            width: 240,
            height: 38,
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: PosColors.muted),
                hintText: 'Search',
                filled: true,
                fillColor: PosColors.surfaceSunk,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              await showInventoryItemForm(context);
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add item',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: PosColors.surfaceSunk,
      child: Row(
        children: [
          Expanded(flex: 4, child: _eyebrow('ITEM')),
          Expanded(flex: 3, child: _eyebrow('CATEGORY')),
          Expanded(flex: 2, child: _eyebrow('ON HAND')),
          Expanded(flex: 2, child: _eyebrow('MIN')),
          SizedBox(width: 70, child: _eyebrow('STATUS')),
          Expanded(flex: 2, child: _eyebrow('COST/UNIT')),
          const SizedBox(width: 168),
        ],
      ),
    );
  }

  Widget _row(InventoryItem item) {
    final unit = InventoryUnits.displayLabel(item.unit);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: PosColors.surface,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(item.category.isEmpty ? '—' : item.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: PosColors.ink2)),
          ),
          Expanded(
            flex: 2,
            child: Text('${_n(item.quantity)} $unit',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Text('${_n(item.minThreshold)} $unit',
                style: TextStyle(fontSize: 13, color: PosColors.ink2)),
          ),
          SizedBox(width: 70, child: _statusChip(item)),
          Expanded(
            flex: 2,
            child: Text(money(context, item.costPerUnit),
                style: TextStyle(fontSize: 13, color: PosColors.ink2)),
          ),
          SizedBox(
            width: 168,
            child: Row(
              children: [
                _iconBtn(Icons.add_box_outlined, PosColors.primary, 'Stock in',
                    () => _act(() async {
                          await showStockMoveDialog(context,
                              item: item, kind: StockMoveKind.stockIn);
                        })),
                _iconBtn(Icons.remove_circle_outline, PosColors.warning, 'Use',
                    () => _act(() async {
                          await showStockMoveDialog(context,
                              item: item, kind: StockMoveKind.use);
                        })),
                _iconBtn(Icons.edit_outlined, PosColors.ink2, 'Edit',
                    () async {
                  await showInventoryItemForm(context, item: item);
                }),
                _iconBtn(Icons.delete_outline_rounded, PosColors.danger,
                    'Delete', () => _delete(item)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(InventoryItem item) {
    final (label, color) = item.isOutOfStock
        ? ('Out', PosColors.danger)
        : item.isLowStock
            ? ('Low', PosColors.warning)
            : ('OK', PosColors.success);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PosRadii.pill),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _iconBtn(
      IconData icon, Color color, String tip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: color,
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  Widget _eyebrow(String text) => Text(text,
      style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: PosColors.muted));

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
