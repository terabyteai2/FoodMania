import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/inventory_item.dart';
import 'package:local_pos/src/models/inventory_unit.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import '../theme/desk_widgets.dart';
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
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      _statRow(app.inventoryItems),
                      _filterPills(app.inventoryItems.length),
                      const SizedBox(height: DeskMetrics.panelGap),
                      Expanded(
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: deskCardDecoration(),
                          child: Column(
                            children: [
                              _headerRow(),
                              Expanded(
                                child: items.isEmpty
                                    ? Center(
                                        child: Text('No stock items',
                                            style: TextStyle(
                                                fontSize: 15,
                                                color: PosColors.muted)))
                                    : ListView.separated(
                                        itemCount: items.length,
                                        separatorBuilder: (_, _) =>
                                            const Divider(
                                                height: 1,
                                                color: PosColors.line),
                                        itemBuilder: (_, i) => _row(items[i]),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// Live inventory KPIs aligned to target design.
  Widget _statRow(List<InventoryItem> all) {
    final stockValue =
        all.fold<double>(0, (s, i) => s + i.quantity * i.costPerUnit);
    final low = all.where((i) => i.isLowStock).length;
    return Wrap(
      spacing: DeskMetrics.panelGap,
      runSpacing: DeskMetrics.panelGap,
      children: [
        DeskStatTile(
            icon: Icons.savings_rounded,
            label: 'Stock value',
            value: money(context, stockValue),
            width: 220),
        DeskStatTile(
            icon: Icons.warning_amber_rounded,
            label: 'Alerts',
            value: '$low',
            width: 220,
            accent: PosColors.warning,
            tint: PosColors.warnSoft),
        DeskStatTile(
            icon: Icons.trending_down_rounded,
            label: 'Variance today',
            value: '—',
            width: 220,
            accent: PosColors.danger,
            tint: PosColors.dangerSoft),
        DeskStatTile(
            icon: Icons.inventory_2_rounded,
            label: 'Materials',
            value: '${all.length}',
            width: 220),
      ],
    );
  }

  Widget _filterPills(int total) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          _filterPill('All', total, true),
          const SizedBox(width: 8),
          _filterPill('Other', total, false),
        ],
      ),
    );
  }

  Widget _filterPill(String label, int count, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? PosColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: active
            ? null
            : Border.all(color: PosColors.lineStrong),
      ),
      child: Text('$label $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : PosColors.ink2,
          )),
    );
  }

  Widget _toolbar(int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const Text('Inventory',
              style: TextStyle(fontSize: DeskTypography.displayPushed, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text('$total items',
              style: TextStyle(fontSize: DeskTypography.body, color: PosColors.muted)),
          const Spacer(),
          SizedBox(
            width: 280,
            height: 42,
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: PosColors.muted),
                hintText: 'Search items',
                filled: true,
                fillColor: PosColors.surfaceSunk,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () async {
              await showInventoryItemForm(context);
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add item',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: DeskTypography.title)),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      color: PosColors.surfaceSunk,
      child: Row(
        children: [
          Expanded(flex: 4, child: _eyebrow('MATERIAL')),
          Expanded(flex: 2, child: Center(child: _eyebrow('IN'))),
          Expanded(flex: 2, child: Center(child: _eyebrow('OUT'))),
          Expanded(flex: 2, child: Center(child: _eyebrow('NET'))),
          Expanded(flex: 2, child: Center(child: _eyebrow('ON HAND'))),
          Expanded(flex: 2, child: Center(child: _eyebrow('SPEND'))),
          const SizedBox(width: 184),
        ],
      ),
    );
  }

  Widget _row(InventoryItem item) {
    final unit = InventoryUnits.displayLabel(item.unit);
    final statusColor = item.isOutOfStock
        ? PosColors.danger
        : item.isLowStock
            ? PosColors.warning
            : PosColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      color: PosColors.surface,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: DeskTypography.title, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: PosColors.surface3,
                    borderRadius: BorderRadius.circular(PosRadii.xs),
                  ),
                  child: Text(unit,
                      style: TextStyle(
                          fontSize: DeskTypography.eyebrow,
                          fontWeight: FontWeight.w700,
                          color: PosColors.ink2)),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Center(child: _dashCell())),
          Expanded(flex: 2, child: Center(child: _dashCell())),
          Expanded(flex: 2, child: Center(child: _dashCell())),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(_n(item.quantity),
                  style: const TextStyle(
                      fontSize: DeskTypography.title, fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(flex: 2, child: Center(child: _dashCell())),
          SizedBox(
            width: 184,
            child: Row(
              children: [
                _iconBtn(Icons.arrow_upward_rounded, PosColors.primary,
                    'Stock in', () => _act(() async {
                          await showStockMoveDialog(context,
                              item: item, kind: StockMoveKind.stockIn);
                        })),
                _iconBtn(Icons.crop_square_outlined, PosColors.warning, 'Use',
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

  Widget _dashCell() {
    return Text('—',
        style: TextStyle(
            fontSize: DeskTypography.body, fontWeight: FontWeight.w600, color: PosColors.muted));
  }

  Widget _iconBtn(
      IconData icon, Color color, String tip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: color,
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  Widget _eyebrow(String text) => Text(text,
      style: TextStyle(
          fontSize: DeskTypography.eyebrow,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: PosColors.muted));

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
