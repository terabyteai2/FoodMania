import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/pos_compact_ui.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_unit.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({this.onNavigateToOrders, super.key});

  final VoidCallback? onNavigateToOrders;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).refreshInventory();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;

    return Scaffold(
      backgroundColor: PosColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: CompactHeader(
                title: text.inventory,
                actions: [
                  HeaderLanguageButton(),
                  HeaderNotificationBell(
                    onNavigateToOrders: widget.onNavigateToOrders ?? () {},
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: PosColors.slate,
              unselectedLabelColor: PosColors.muted,
              indicatorColor: PosColors.primary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: text.inventoryToday),
                Tab(text: text.inventoryItemsTab),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _TodayTab(
                    text: text,
                    spend: app.inventoryTodaySpend,
                    items: app.inventoryItems,
                    lowCount: app.lowStockCount,
                    onAddItem: () {
                      _tabs.animateTo(1);
                      _openItemForm(context);
                    },
                    onBought: () => _openBoughtSheet(context),
                    onEndOfDay: () => _openEndOfDaySheet(context),
                    onCount: (item) => _openCountSheet(context, item),
                    onUsed: (item) => _openUsedSheet(context, item),
                  ),
                  _ItemsTab(
                    text: text,
                    items: app.inventoryItems,
                    isManager: app.isManager,
                    onAdd: () => _openItemForm(context),
                    onEdit: (item) => _openItemForm(context, item: item),
                    onDelete: (item) => _confirmDelete(context, item),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBoughtSheet(BuildContext context) async {
    final app = AppScope.of(context);
    if (app.inventoryItems.isEmpty) {
      _openItemForm(context);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _BoughtStockSheet(text: app.strings, items: app.inventoryItems),
    );
  }

  Future<void> _openEndOfDaySheet(BuildContext context) async {
    final app = AppScope.of(context);
    if (app.inventoryItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(app.strings.noInventoryMessage)));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EndOfDaySheet(text: app.strings, items: app.inventoryItems),
    );
  }

  Future<void> _openCountSheet(BuildContext context, InventoryItem item) async {
    final app = AppScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickCountSheet(item: item, text: app.strings),
    );
  }

  Future<void> _openUsedSheet(BuildContext context, InventoryItem item) async {
    final app = AppScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickUsedSheet(item: item, text: app.strings),
    );
  }

  Future<void> _openItemForm(
    BuildContext context, {
    InventoryItem? item,
  }) async {
    final app = AppScope.of(context);
    final result = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemFormSheet(item: item, text: app.strings),
    );
    if (result != null && context.mounted) {
      await app.saveInventoryItem(result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, InventoryItem item) async {
    final app = AppScope.of(context);
    final text = app.strings;
    final ok = await showDialog<bool>(
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
            style: TextButton.styleFrom(foregroundColor: PosColors.danger),
            child: Text(text.deleteInventoryItem),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await app.deleteInventoryItem(item.id);
    }
  }
}

// ── Today tab ─────────────────────────────────────────────────────────────────

class _TodayTab extends StatelessWidget {
  const _TodayTab({
    required this.text,
    required this.spend,
    required this.items,
    required this.lowCount,
    required this.onAddItem,
    required this.onBought,
    required this.onEndOfDay,
    required this.onCount,
    required this.onUsed,
  });

  final AppStrings text;
  final double spend;
  final List<InventoryItem> items;
  final int lowCount;
  final VoidCallback onAddItem;
  final VoidCallback onBought;
  final VoidCallback onEndOfDay;
  final void Function(InventoryItem) onCount;
  final void Function(InventoryItem) onUsed;

  @override
  Widget build(BuildContext context) {
    final moneyFmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    if (items.isEmpty) {
      return EmptyCompactState(
        title: text.noInventoryItems,
        message: text.noInventoryMessage,
        icon: Icons.inventory_2_outlined,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CompactSurface(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.todaySpend,
                            style: TextStyle(
                              fontSize: 11,
                              color: PosColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            moneyFmt.format(spend),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: PosColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (lowCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          text.lowStockCount(lowCount),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Day-to-day inventory work happens in bulk: "Bought stock" when
              // supplies arrive, "End of day count" when the shift closes.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onBought,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: Text(text.boughtStock),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onEndOfDay,
                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                      label: Text(text.endOfDayCount),
                      style: FilledButton.styleFrom(
                        backgroundColor: PosColors.primary,
                        foregroundColor: const Color(0xFF14110E),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return _TodayItemTile(
                item: item,
                text: text,
                onCount: () => onCount(item),
                onUsed: () => onUsed(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TodayItemTile extends StatelessWidget {
  const _TodayItemTile({
    required this.item,
    required this.text,
    required this.onCount,
    required this.onUsed,
  });

  final InventoryItem item;
  final AppStrings text;
  final VoidCallback onCount;
  final VoidCallback onUsed;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isOutOfStock
        ? PosColors.danger
        : item.isLowStock
        ? const Color(0xFFB45309)
        : PosColors.success;

    return CompactSurface(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: PosColors.slate,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${text.leftNow}: ${InventoryUnits.formatQuantity(item.quantity, item.unit, isBn: text.isBn)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PosColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _TodayItemActionButton(
                  icon: Icons.edit_outlined,
                  label: text.setCount,
                  onTap: onCount,
                  background: PosColors.primary,
                  foreground: PosColors.primaryDark,
                  borderColor: PosColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TodayItemActionButton(
                  icon: Icons.remove_circle_outline,
                  label: text.usedToday,
                  onTap: onUsed,
                  background: const Color(0xFFFFF4F2),
                  foreground: PosColors.danger,
                  borderColor: const Color(0xFFF6C8C2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayItemActionButton extends StatelessWidget {
  const _TodayItemActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        height: 34,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: foreground, size: 15),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Items tab ─────────────────────────────────────────────────────────────────

class _ItemsTab extends StatelessWidget {
  const _ItemsTab({
    required this.text,
    required this.items,
    required this.isManager,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final AppStrings text;
  final List<InventoryItem> items;
  final bool isManager;
  final VoidCallback onAdd;
  final void Function(InventoryItem) onEdit;
  final void Function(InventoryItem) onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyCompactState(
                title: text.noInventoryItems,
                message: text.noInventoryMessage,
                icon: Icons.inventory_2_outlined,
              ),
              if (isManager) ...[
                const SizedBox(height: 16),
                _InventoryAddButton(label: text.inventoryAddItem, onTap: onAdd),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (isManager)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: _InventoryAddButton(
                label: text.inventoryAddItem,
                onTap: onAdd,
              ),
            ),
          ),
        CompactSurface(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: PosColors.lineStrong),
            itemBuilder: (context, index) {
              final item = items[index];
              return _InventoryRow(
                item: item,
                text: text,
                onTap: isManager ? () => onEdit(item) : null,
                onEdit: () => onEdit(item),
                onDelete: () => onDelete(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InventoryAddButton extends StatelessWidget {
  const _InventoryAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Material(
        color: PosColors.primary,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: PosColors.primaryDark, size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: PosColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.item,
    required this.text,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
  });

  final InventoryItem item;
  final AppStrings text;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final moneyFmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final qty = InventoryUnits.formatQuantity(
      item.quantity,
      item.unit,
      isBn: text.isBn,
    );
    final priceLine = item.costPerUnit > 0
        ? '${moneyFmt.format(item.costPerUnit)} / ${InventoryUnits.displayLabel(item.unit, isBn: text.isBn)}'
        : item.category;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 4, 9),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.isOutOfStock
                      ? PosColors.danger
                      : item.isLowStock
                      ? const Color(0xFFB45309)
                      : PosColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: PosColors.slate,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$qty · $priceLine',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: PosColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(text.editInventoryItem),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      text.deleteInventoryItem,
                      style: TextStyle(color: PosColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sheets ────────────────────────────────────────────────────────────────────

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFDF5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8D2C4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoughtStockSheet extends StatefulWidget {
  const _BoughtStockSheet({required this.text, required this.items});

  final AppStrings text;
  final List<InventoryItem> items;

  @override
  State<_BoughtStockSheet> createState() => _BoughtStockSheetState();
}

class _BoughtStockSheetState extends State<_BoughtStockSheet> {
  InventoryItem? _selected;
  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final item = _selected;
    if (item == null) return;
    final qty = double.tryParse(_qtyCtrl.text.trim());
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0;
    if (qty == null || qty <= 0) return;

    setState(() => _busy = true);
    try {
      await AppScope.of(context).recordInventoryPurchase(
        inventoryItemId: item.id,
        quantity: qty,
        totalCostBdt: cost,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final unitLabel = _selected != null
        ? InventoryUnits.displayLabel(_selected!.unit, isBn: text.isBn)
        : '';

    return _SheetShell(
      title: text.boughtStock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<InventoryItem>(
            initialValue: _selected,
            decoration: InputDecoration(labelText: text.itemName),
            items: widget.items
                .map((i) => DropdownMenuItem(value: i, child: Text(i.name)))
                .toList(growable: false),
            onChanged: (v) => setState(() => _selected = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(
              labelText:
                  '${text.quantityLabel}${unitLabel.isEmpty ? '' : ' ($unitLabel)'}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _costCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(labelText: text.totalPaid),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              foregroundColor: const Color(0xFF14110E),
              minimumSize: const Size.fromHeight(48),
            ),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(text.saveCount),
          ),
        ],
      ),
    );
  }
}

class _QuickCountSheet extends StatefulWidget {
  const _QuickCountSheet({required this.item, required this.text});

  final InventoryItem item;
  final AppStrings text;

  @override
  State<_QuickCountSheet> createState() => _QuickCountSheetState();
}

class _QuickCountSheetState extends State<_QuickCountSheet> {
  late final TextEditingController _ctrl;
  bool _busy = false;
  double? _yesterday;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.quantity.toString());
    _loadYesterday();
  }

  Future<void> _loadYesterday() async {
    final v = await AppScope.of(
      context,
    ).yesterdayClosingQuantity(widget.item.id);
    if (mounted) setState(() => _yesterday = v);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(_ctrl.text.trim());
    if (qty == null || qty < 0) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).setInventoryEndOfDayCount(
        inventoryItemId: widget.item.id,
        quantity: qty,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final unit = InventoryUnits.displayLabel(widget.item.unit, isBn: text.isBn);

    return _SheetShell(
      title: '${text.setCount} — ${widget.item.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_yesterday != null)
            Text(
              '${text.yesterdayLeft}: ${InventoryUnits.formatQuantity(_yesterday!, widget.item.unit, isBn: text.isBn)}',
              style: TextStyle(color: PosColors.muted, fontSize: 13),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(labelText: '${text.leftNow} ($unit)'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              foregroundColor: const Color(0xFF14110E),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(text.saveCount),
          ),
        ],
      ),
    );
  }
}

class _QuickUsedSheet extends StatefulWidget {
  const _QuickUsedSheet({required this.item, required this.text});

  final InventoryItem item;
  final AppStrings text;

  @override
  State<_QuickUsedSheet> createState() => _QuickUsedSheetState();
}

class _QuickUsedSheetState extends State<_QuickUsedSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(_ctrl.text.trim());
    if (qty == null || qty <= 0) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(
        context,
      ).recordInventoryUsage(inventoryItemId: widget.item.id, quantity: qty);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final unit = InventoryUnits.displayLabel(widget.item.unit, isBn: text.isBn);

    return _SheetShell(
      title: '${text.usedToday} — ${widget.item.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${text.currentStock}: ${InventoryUnits.formatQuantity(widget.item.quantity, widget.item.unit, isBn: text.isBn)}',
            style: TextStyle(fontSize: 13, color: PosColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(
              labelText: '${text.quantityLabel} ($unit)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(text.saveCount),
          ),
        ],
      ),
    );
  }
}

class _EndOfDaySheet extends StatefulWidget {
  const _EndOfDaySheet({required this.text, required this.items});

  final AppStrings text;
  final List<InventoryItem> items;

  @override
  State<_EndOfDaySheet> createState() => _EndOfDaySheetState();
}

class _EndOfDaySheetState extends State<_EndOfDaySheet> {
  final _controllers = <String, TextEditingController>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _controllers[item.id] = TextEditingController(
        text: item.quantity.toString(),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    setState(() => _busy = true);
    final app = AppScope.of(context);
    try {
      for (final item in widget.items) {
        final qty = double.tryParse(_controllers[item.id]!.text.trim());
        if (qty == null || qty < 0) continue;
        await app.setInventoryEndOfDayCount(
          inventoryItemId: item.id,
          quantity: qty,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    return _SheetShell(
      title: text.endOfDayCount,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text.countAllItems,
            style: TextStyle(fontSize: 13, color: PosColors.muted),
          ),
          const SizedBox(height: 16),
          ...widget.items.map((item) {
            final unit = InventoryUnits.displayLabel(
              item.unit,
              isBn: text.isBn,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[item.id],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(labelText: '${item.name} ($unit)'),
              ),
            );
          }),
          FilledButton(
            onPressed: _busy ? null : _saveAll,
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              foregroundColor: const Color(0xFF14110E),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(text.saveCount),
          ),
        ],
      ),
    );
  }
}

class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet({required this.text, this.item});

  final AppStrings text;
  final InventoryItem? item;

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _uuid = const Uuid();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late String _unit;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _minCtrl;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _categoryCtrl = TextEditingController(text: item?.category ?? '');
    _unit = item?.unit ?? InventoryUnits.kg;
    _qtyCtrl = TextEditingController(
      text: item != null ? item.quantity.toString() : '0',
    );
    _priceCtrl = TextEditingController(
      text: item != null && item.costPerUnit > 0
          ? item.costPerUnit.toString()
          : '',
    );
    _minCtrl = TextEditingController(
      text: item != null ? item.minThreshold.toString() : '0',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final now = DateTime.now();
    final existing = widget.item;
    Navigator.pop(
      context,
      InventoryItem(
        id: existing?.id ?? _uuid.v4(),
        name: name,
        category: _categoryCtrl.text.trim(),
        unit: InventoryUnits.normalize(_unit),
        quantity: double.tryParse(_qtyCtrl.text.trim()) ?? 0,
        minThreshold: double.tryParse(_minCtrl.text.trim()) ?? 0,
        costPerUnit: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        notes: existing?.notes ?? '',
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final isEdit = widget.item != null;
    final unitLabel = InventoryUnits.displayLabel(_unit, isBn: text.isBn);

    return _SheetShell(
      title: isEdit ? text.editInventoryItem : text.addInventoryItem,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: text.itemName),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryCtrl,
            decoration: InputDecoration(labelText: text.itemCategory),
          ),
          const SizedBox(height: 12),
          Text(
            text.unit,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: PosColors.slate,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: InventoryUnits.all
                .map((u) {
                  final selected = _unit == u;
                  return ChoiceChip(
                    label: Text(
                      InventoryUnits.displayLabel(u, isBn: text.isBn),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _unit = u),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(
              labelText: '${text.unitPrice} ($unitLabel)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(
              labelText: '${text.openingStock} ($unitLabel)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(
              labelText: '${text.lowStockAlert} ($unitLabel)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              foregroundColor: const Color(0xFF14110E),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(isEdit ? text.save : text.addInventoryItem),
          ),
        ],
      ),
    );
  }
}
