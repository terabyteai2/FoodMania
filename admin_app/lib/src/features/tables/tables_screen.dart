import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/menu_item.dart';
import '../../models/order_model.dart';
import '../../models/order_service_type.dart';
import '../../models/pos_notification.dart';
import '../desktop_pos/widgets/menu_line_customizer.dart';
import '../orders/menu_order_widgets.dart';
import '../orders/orders_screen.dart';

/// QuickBytes Tables / FOH tab (spec §4.2). Dine-in · Parcel · Delivery
/// segments; occupied tables use the slate wash (never lime); the bottom-bar
/// primary creates a new order. In counter mode (More → service mode) the tab
/// becomes a quick-sell entry point.
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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.selectMany(context, const [
      AppAspect.orders,
      AppAspect.settings,
      AppAspect.language,
    ]);
    final text = app.strings;
    final counterMode = app.counterModeEnabled;
    return AppScaffold(
      title: text.tables,
      headerWidget: AppPageHeader(
        title: text.tables,
        onNavigateToOrders: widget.onNavigateToOrders,
        onNavigateToTarget: widget.onNavigateToTarget,
      ),
      showDatePill: false,
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
        _SegControl(value: seg, onChanged: onSeg, text: text),
        const SizedBox(height: 14),
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

class _SegControl extends StatelessWidget {
  const _SegControl({
    required this.value,
    required this.onChanged,
    required this.text,
  });

  final _TableSeg value;
  final ValueChanged<_TableSeg> onChanged;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    Widget seg(_TableSeg s, String label) {
      final on = s == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(s),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? PosColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(PosRadii.tag),
              border: on
                  ? Border.all(color: PosColors.lineStrong)
                  : Border.all(color: Colors.transparent),
            ),
            child: TfText(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: on ? PosColors.text : PosColors.textSec,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.input),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          seg(_TableSeg.dineIn, OrderServiceType.dineIn.localized(text.isBn)),
          seg(_TableSeg.parcel, OrderServiceType.takeaway.localized(text.isBn)),
          seg(
            _TableSeg.delivery,
            OrderServiceType.delivery.localized(text.isBn),
          ),
        ],
      ),
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
        TfText(
          text.tablesOccupiedFree(occupied, free),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PosColors.textSec,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemCount: tableCount,
            itemBuilder: (_, i) {
              final label = 'T${i + 1}';
              final order = byTable[label];
              return _TableCell(
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

class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.label,
    required this.order,
    required this.onTap,
  });

  final String label;
  final OrderModel? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.select(context, AppAspect.language).strings;
    final occupied = order != null;
    final mins = occupied
        ? DateTime.now().difference(order!.createdAt.toLocal()).inMinutes
        : 0;
    return Material(
      color: occupied ? PosColors.seatTint : PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.tile),
            border: Border.all(
              color: occupied ? PosColors.seatLine : PosColors.line,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TfText(
                label,
                style: TextStyle(
                  fontFamily: tfFontFamily(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: occupied ? PosColors.seatInk : PosColors.text,
                  height: 1.1,
                ),
              ),
              const Spacer(),
              if (occupied) ...[
                TfText(
                  tfFormatCurrency(context, order!.total),
                  style: TextStyle(
                    fontFamily: tfFontFamily(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: PosColors.seatInk,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                TfText(
                  text.agoMinutes(mins),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PosColors.seatInk,
                  ),
                ),
              ] else
                TfText(
                  text.tableVacant,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PosColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          style: const TextStyle(fontSize: 14, color: PosColors.muted),
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
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: PosColors.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 3),
                      TfText(
                        subtitle.isEmpty ? text.agoMinutes(mins) : subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PosColors.textSec,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TfText(
                  tfFormatCurrency(context, o.total),
                  style: TextStyle(
                    fontFamily: tfFontFamily(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PosColors.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
  MenuLayoutMode _menuLayoutMode = MenuLayoutMode.list;
  int _gridCols = 4;

  // ── Computed ──────────────────────────────────────────────────

  List<String> _categories(List<MenuItem> items) {
    final cats = items.map((i) => i.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...cats];
  }

  List<MenuItem> _visibleItems(List<MenuItem> items) => items
      .where((i) {
        final matchesCategory =
            _selectedCategory == 'All' || i.category == _selectedCategory;
        if (!matchesCategory) return false;
        final query = _query.trim().toLowerCase();
        if (query.isEmpty) return true;
        final searchable = [
          i.name,
          i.nameEn,
          i.nameBn,
          i.category,
          i.description,
        ].whereType<String>().join(' ').toLowerCase();
        return searchable.contains(query);
      })
      .toList(growable: false);

  Map<String, int> get _cartQtyByItemId {
    final out = <String, int>{};
    for (final line in _cartLines) {
      out[line.item.id] = (out[line.item.id] ?? 0) + line.qty;
    }
    return out;
  }

  int get _totalQty => _cartLines.fold(0, (s, line) => s + line.qty);

  double get _total {
    final subtotal =
        _cartLines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    return double.parse(subtotal.toStringAsFixed(2));
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _tap(MenuItem item) async {
    HapticFeedback.lightImpact();
    final selections = desktopMenuNeedsCustomization(item)
        ? await showDesktopMenuLineCustomizerLines(
            context,
            item: item,
            isBn: AppScope.of(context).strings.isBn,
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

  void _selectMenuLayout(MenuLayoutMode mode) {
    if (_menuLayoutMode == mode) return;
    setState(() => _menuLayoutMode = mode);
  }

  void _selectGridCols(int cols) {
    if (_gridCols == cols) return;
    setState(() => _gridCols = cols);
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
    final app = AppScope.of(context);
    final menuItems = app.menuItems.where((i) => i.isAvailable).toList();
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
            selectedCategory: _selectedCategory,
            cart: cartQty,
            lineCount: _cartLines.length,
            total: _total,
            totalQty: _totalQty,
            searchCtrl: _searchCtrl,
            query: _query,
            layoutMode: _menuLayoutMode,
            gridCols: _gridCols,
            categoryCounts: categoryCounts,
            onSearchChanged: _onSearchChanged,
            onLayoutChanged: _selectMenuLayout,
            onGridColsChanged: _selectGridCols,
            onCategorySelected: (c) => setState(() => _selectedCategory = c),
            onTap: _tap,
            onDecrement: _decrement,
            onSubmit: _cartLines.isNotEmpty ? _openReviewWizard : null,
          ),
        ),
      ],
    );
  }
}
