import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../models/menu_item.dart';
import '../../models/order_model.dart';
import '../../models/order_service_type.dart';
import '../../models/pos_notification.dart';
import '../desktop_pos/widgets/menu_line_customizer.dart';
import '../orders/menu_order_widgets.dart';
import '../orders/orders_screen.dart';
import 'pos_table_cell.dart';

/// QuickBytes Tables / FOH tab. Dine-in · Parcel · Delivery via underline
/// tabs (TfTabs); table tiles carry the Petpooja state model (DESIGN.md v4
/// §5.3, target9/10): white vacant, saturated-yellow occupied with live
/// elapsed time + running amount + ⋮, mint dot when a KOT is in the kitchen.
/// In counter mode (More → service mode) the tab becomes a quick-sell entry
/// point.
class TablesScreen extends StatefulWidget {
  const TablesScreen({
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    super.key,
  });

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

enum _TableSeg { dineIn, parcel, delivery }

class _TablesScreenState extends State<TablesScreen> {
  _TableSeg _seg = _TableSeg.dineIn;
  bool _parcelFormOpen = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Occupied tiles show live elapsed minutes (v4 §5.3); one screen-level
    // tick keeps every tile fresh without per-tile timers.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.selectMany(context, const [
      AppAspect.orders,
      AppAspect.settings,
      AppAspect.language,
    ]);
    final text = app.strings;
    final counterMode = app.isCounterOutlet;
    return AppScaffold(
      title: text.tables,
      headerWidget: TfGlobalTopBar(
        title: text.tables,
        onNavigateToOrders: widget.onNavigateToOrders,
        onNavigateToTarget: widget.onNavigateToTarget,
        color: PosColors.primary,
      ),
      pinHeader: true,
      fillBody: true,
      removeHorizontalPadding: counterMode,
      child: counterMode
          ? _CounterMode(onNavigateToOrders: widget.onNavigateToOrders)
          : _FullService(
              app: app,
              text: text,
              seg: _seg,
              onSeg: _onSegChanged,
              onNavigateToOrders: widget.onNavigateToOrders,
            ),
    );
  }

  void _onSegChanged(_TableSeg seg) {
    setState(() => _seg = seg);
    if (seg == _TableSeg.parcel && !_parcelFormOpen) {
      _parcelFormOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        openNewOrderForm(
          context,
          onCreated: widget.onNavigateToOrders,
          initialServiceType: OrderServiceType.takeaway,
          startAtMenu: true,
        ).whenComplete(() {
          if (mounted) setState(() => _parcelFormOpen = false);
        });
      });
    }
  }
}

class _FullService extends StatelessWidget {
  const _FullService({
    required this.app,
    required this.text,
    required this.seg,
    required this.onSeg,
    required this.onNavigateToOrders,
  });

  final PosAppController app;
  final AppStrings text;
  final _TableSeg seg;
  final ValueChanged<_TableSeg> onSeg;
  final VoidCallback? onNavigateToOrders;

  @override
  Widget build(BuildContext context) {
    final openOrders = app.ordersFor().where((o) => o.status.isOpen).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TfTabs(
          activeIndex: _TableSeg.values.indexOf(seg),
          onChanged: (i) => onSeg(_TableSeg.values[i]),
          items: [
            TfTabItem(
              label: OrderServiceType.dineIn.localized(false),
              labelBn: OrderServiceType.dineIn.localized(true),
            ),
            TfTabItem(
              label: OrderServiceType.takeaway.localized(false),
              labelBn: OrderServiceType.takeaway.localized(true),
            ),
            TfTabItem(
              label: OrderServiceType.delivery.localized(false),
              labelBn: OrderServiceType.delivery.localized(true),
            ),
          ],
        ),
        const SizedBox(height: PosDensity.sectionGap),
        Expanded(
          child: switch (seg) {
            _TableSeg.dineIn => _DineInGrid(
              app: app,
              text: text,
              openOrders: openOrders,
              onNavigateToOrders: onNavigateToOrders,
            ),
            _TableSeg.parcel => _OrderTypeList(
              text: text,
              orders: openOrders
                  .where((o) => o.serviceType == OrderServiceType.takeaway)
                  .toList(),
              emptyLabel: text.noOpenParcels,
            ),
            _TableSeg.delivery => _OrderTypeList(
              text: text,
              orders: openOrders
                  .where((o) => o.serviceType == OrderServiceType.delivery)
                  .toList(),
              emptyLabel: text.noOpenDeliveries,
            ),
          },
        ),
      ],
    );
  }
}

class _DineInGrid extends StatelessWidget {
  const _DineInGrid({
    required this.app,
    required this.text,
    required this.openOrders,
    required this.onNavigateToOrders,
  });

  final PosAppController app;
  final AppStrings text;
  final List<OrderModel> openOrders;
  final VoidCallback? onNavigateToOrders;

  @override
  Widget build(BuildContext context) {
    final tableCount = app.serverConfig.tableCount;
    // Map "T{n}" -> the open dine-in order seated there.
    final byTable = <String, OrderModel>{};
    final occupiedTableKeys = <String>{};
    for (final o in openOrders) {
      final raw = (o.tableNo ?? '').trim();
      if (raw.isEmpty) continue;
      occupiedTableKeys.add(raw.startsWith('T') ? raw.substring(1) : raw);
      byTable[raw] = o;
      if (raw.startsWith('T')) {
        byTable[raw.substring(1)] = o;
      } else {
        byTable['T$raw'] = o;
      }
    }
    final occupied = occupiedTableKeys.length;
    final free = (tableCount - occupied).clamp(0, tableCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // v4 §5.3: no legend row — tiles are self-explanatory (target9/10).
        TfText(
          text.tablesOccupiedFree(occupied, free),
          style: TfTextStyles.bodyMuted.copyWith(
            fontWeight: FontWeight.w600,
            color: PosColors.textSec,
          ),
        ),
        const SizedBox(height: PosDensity.gridGap),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: PosSpacing.sp2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: PosDensity.gridGap,
              crossAxisSpacing: PosDensity.gridGap,
              childAspectRatio: PosDensity.tileTableAspect,
            ),
            itemCount: tableCount,
            itemBuilder: (_, i) {
              final label = 'T${i + 1}';
              final order = byTable[label];
              return PosTableCell(
                label: label,
                order: order,
                onTap: () {
                  if (order != null) {
                    openEditOrderSheet(context, order);
                  } else {
                    openNewOrderForm(
                      context,
                      onCreated: onNavigateToOrders,
                      initialServiceType: OrderServiceType.dineIn,
                      initialTableNo: '${i + 1}',
                      startAtMenu: true,
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Table tile + state lookup live in pos_table_cell.dart (PosTableCell /
// tableStateStyle), shared with the order wizard's dine-in picker.

class _OrderTypeList extends StatelessWidget {
  const _OrderTypeList({
    required this.text,
    required this.orders,
    required this.emptyLabel,
  });

  final AppStrings text;
  final List<OrderModel> orders;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: TfText(
          emptyLabel,
          style: TfTextStyles.body.copyWith(color: PosColors.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = orders[i];
        final mins = DateTime.now().difference(o.createdAt.toLocal()).inMinutes;
        final subtitle = [
          (o.customerName ?? '').trim(),
          (o.deliveryAddress ?? '').trim(),
        ].where((s) => s.isNotEmpty).join(' · ');
        return TfCard(
          child: InkWell(
            onTap: () => openEditOrderSheet(context, o),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TfText(
                        o.displaySequence,
                        style: TfTextStyles.orderSerial.copyWith(
                          color: PosColors.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      TfText(
                        subtitle.isEmpty ? text.agoMinutes(mins) : subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TfTextStyles.bodyMuted.copyWith(
                          fontWeight: FontWeight.w500,
                          color: PosColors.textSec,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PosSpacing.sp3),
                TfText(
                  tfFormatCurrency(context, o.totalAfterDiscount),
                  style: TfTextStyles.price.copyWith(
                    fontWeight: FontWeight.w800,
                    color: PosColors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CounterMode extends StatefulWidget {
  const _CounterMode({required this.onNavigateToOrders});

  final VoidCallback? onNavigateToOrders;

  @override
  State<_CounterMode> createState() => _CounterModeState();
}

class _CounterModeState extends State<_CounterMode> {
  final List<DesktopMenuLineSelection> _cartLines = [];
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _codeMode = false;

  // ── Computed ──────────────────────────────────────────────────

  // Menu memo: the favourite partition, category list, and per-item lowercased
  // search blob are computed once per menu identity (the controller replaces
  // the list wholesale on change) instead of on every build/keystroke.
  List<MenuItem>? _menuMemoKey;
  List<MenuItem> _partitionedMenu = const [];
  List<String> _categoriesMemo = const ['All'];
  Map<String, String> _searchBlobs = const {};

  void _ensureMenuMemo(List<MenuItem> items) {
    if (identical(_menuMemoKey, items)) return;
    _menuMemoKey = items;
    // Stable partition: favourites first, otherwise menu order. Filtering
    // below preserves this order.
    _partitionedMenu = [
      ...items.where((i) => i.isFavorite),
      ...items.where((i) => !i.isFavorite),
    ];
    final cats = items.map((i) => i.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _categoriesMemo = ['All', ...cats];
    // A stale category selection (menu edited/synced since) would filter
    // EVERYTHING out and leave an inexplicably empty grid — fall back to All.
    if (_selectedCategory != 'All' &&
        !_categoriesMemo.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }
    _searchBlobs = {
      for (final i in items)
        i.id: [
          i.name,
          i.nameEn,
          i.nameBn,
          i.category,
          i.description,
        ].whereType<String>().join(' ').toLowerCase(),
    };
  }

  List<String> _categories(List<MenuItem> items) {
    _ensureMenuMemo(items);
    return _categoriesMemo;
  }

  List<MenuItem> _visibleItems(List<MenuItem> items) {
    _ensureMenuMemo(items);
    final rawQuery = _query.trim();
    final lowerQuery = rawQuery.toLowerCase();
    final selectedCategory = _selectedCategory;
    final codeMode = _codeMode;
    return _partitionedMenu
        .where((i) {
          if (selectedCategory != 'All' && i.category != selectedCategory) {
            return false;
          }
          if (rawQuery.isEmpty) return true;
          if (codeMode) {
            return (i.shortCode?.toString() ?? '').startsWith(rawQuery);
          }
          return (_searchBlobs[i.id] ?? '').contains(lowerQuery);
        })
        .toList(growable: false);
  }

  Map<String, int> get _cartQtyByItemId {
    final out = <String, int>{};
    for (final line in _cartLines) {
      out[line.item.id] = (out[line.item.id] ?? 0) + line.qty;
    }
    return out;
  }

  int get _totalQty => _cartLines.fold(0, (s, line) => s + line.qty);

  double get _total {
    final subtotal = _cartLines.fold<double>(
      0,
      (sum, line) => sum + line.lineTotal,
    );
    return double.parse(subtotal.toStringAsFixed(2));
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _tap(MenuItem item) async {
    HapticFeedback.lightImpact();
    final selections = desktopMenuNeedsCustomization(item)
        ? await showDesktopMenuLineCustomizerLines(
            context,
            item: item,
            isBn: AppScope.read(context).strings.isBn,
          )
        : [desktopRegularMenuLine(item)];
    if (selections == null || selections.isEmpty || !mounted) return;
    setState(() {
      for (final selection in selections) {
        final index = _cartLines.indexWhere(
          (line) => line.lineKey == selection.lineKey,
        );
        if (index >= 0) {
          final current = _cartLines[index];
          _cartLines[index] = DesktopMenuLineSelection(
            item: current.item,
            option: current.option,
            addOns: current.addOns,
            qty: current.qty + selection.qty,
            note: current.note,
          );
        } else {
          _cartLines.add(selection);
        }
      }
    });
  }

  void _decrement(String id) {
    setState(() {
      final index = _cartLines.lastIndexWhere((line) => line.item.id == id);
      if (index < 0) return;
      final line = _cartLines[index];
      if (line.qty <= 1) {
        _cartLines.removeAt(index);
      } else {
        _cartLines[index] = DesktopMenuLineSelection(
          item: line.item,
          option: line.option,
          addOns: line.addOns,
          qty: line.qty - 1,
          note: line.note,
        );
      }
    });
  }

  void _toggleCodeMode() {
    setState(() {
      _codeMode = !_codeMode;
      _query = '';
      _searchCtrl.clear();
    });
  }

  void _onCodeSubmit(String raw) {
    final code = int.tryParse(raw.trim());
    if (code == null) return;
    final items = AppScope.read(context).menuItems;
    MenuItem? match;
    for (final item in items) {
      if (item.shortCode == code && item.isAvailable) {
        match = item;
        break;
      }
    }
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(AppScope.read(context).strings.noItemForCode(raw)),
        ),
      );
      return;
    }
    unawaited(_tap(match));
    setState(() => _query = '');
    _searchCtrl.clear();
  }

  Future<void> _toggleFavorite(MenuItem item) async {
    HapticFeedback.selectionClick();
    await AppScope.read(context).setMenuItemFavorite(item.id, !item.isFavorite);
  }

  static const String _kClearShortCode = '__clear__';

  Future<void> _setShortCode(MenuItem item) async {
    final scope = AppScope.read(context);
    final text = scope.strings;
    final controller = TextEditingController(
      text: item.shortCode?.toString() ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: TfText(text.setShortCode),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: text.shortCodeFieldHint),
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _kClearShortCode),
            child: TfText(text.clearShortCode),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: TfText(text.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: TfText(text.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return; // dismissed
    final code = result == _kClearShortCode ? null : int.tryParse(result);
    if (result != _kClearShortCode && result.isNotEmpty && code == null) {
      return; // non-numeric input — ignore
    }
    await scope.setMenuItemShortCode(item.id, code);
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _openReviewWizard() {
    openNewOrderForm(
      context,
      onCreated: () {
        if (mounted) {
          setState(() {
            _cartLines.clear();
            _searchCtrl.clear();
            _query = '';
            _selectedCategory = 'All';
          });
        }
      },
      startAtReview: true,
      initialCartLines: List.from(_cartLines),
      initialServiceType: OrderServiceType.takeaway,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Counter mode only reads the menu here (cart is local state); localized
    // item names are resolved by MenuStep's own widgets. The full menu is
    // passed (86'd items render dimmed) — also keeps the memo identity stable.
    final app = AppScope.select(context, AppAspect.menu);
    final menuItems = app.menuItems;
    final cartQty = _cartQtyByItemId;
    final categoryCounts = <String, int>{'All': menuItems.length};
    for (final item in menuItems) {
      categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
    }

    return Column(
      children: [
        Expanded(
          child: MenuStep(
            visibleItems: _visibleItems(menuItems),
            categories: _categories(menuItems),
            categoryLabels: categoryLabelsFor(menuItems),
            selectedCategory: _selectedCategory,
            cart: cartQty,
            lineCount: _cartLines.length,
            total: _total,
            totalQty: _totalQty,
            searchCtrl: _searchCtrl,
            query: _query,
            codeMode: _codeMode,
            categoryCounts: categoryCounts,
            onSearchChanged: _onSearchChanged,
            onToggleCodeMode: _toggleCodeMode,
            onCodeSubmit: _onCodeSubmit,
            onCategorySelected: (c) => setState(() => _selectedCategory = c),
            onTap: _tap,
            onDecrement: _decrement,
            onToggleFavorite: (item) => unawaited(_toggleFavorite(item)),
            onSetShortCode: (item) => unawaited(_setShortCode(item)),
            onSubmit: _cartLines.isNotEmpty ? _openReviewWizard : null,
            onResetFilters: () => setState(() {
              _selectedCategory = 'All';
              _query = '';
              _searchCtrl.clear();
            }),
          ),
        ),
      ],
    );
  }
}
