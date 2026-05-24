import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/menu_item.dart';
import '../../models/order_item.dart';
import '../../models/order_model.dart';
import '../../models/order_service_type.dart';
import '../../models/order_source.dart';
import '../../models/order_status.dart';
import 'order_list_filters.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int? _lastPendingCount;
  OrderListFilters _filters = OrderListFilters.none;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rawOrders = app.ordersFor();
    final allOrders = rawOrders
        .where((o) => _filters.matches(o))
        .toList(growable: false);

    final rawPendingOrders = _pendingOrders(rawOrders);
    final rawAcceptedOrders = _acceptedOrders(rawOrders);
    final pendingOrders = _pendingOrders(allOrders);
    pendingOrders.sort(_sortOrders);
    final acceptedOrders = _acceptedOrders(allOrders);
    acceptedOrders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final text = app.strings;
    final canCreate = app.menuItems.any((i) => i.isAvailable);
    final pendingShortcut = _emptyShortcut(
      context: context,
      currentFiltered: pendingOrders,
      currentUnfiltered: rawPendingOrders,
      otherFiltered: acceptedOrders,
      otherLabel: text.acceptedTab,
      otherTabIndex: 1,
    );
    final acceptedShortcut = _emptyShortcut(
      context: context,
      currentFiltered: acceptedOrders,
      currentUnfiltered: rawAcceptedOrders,
      otherFiltered: pendingOrders,
      otherLabel: text.pendingTab,
      otherTabIndex: 0,
    );
    _syncTabWithPendingOrders(pendingOrders.length, acceptedOrders.length);
    final hasAnyOpenOrders =
        pendingOrders.isNotEmpty || acceptedOrders.isNotEmpty;

    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton: canCreate && hasAnyOpenOrders
          ? TfFab(
              tooltip: text.newOrder,
              onPressed: () => _openNewOrderForm(context),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              pendingCount: pendingOrders.length,
              acceptedCount: acceptedOrders.length,
              totalFiltered: allOrders.length,
              filtersActive: _filters.isActive,
              onFilterPressed: () => _openOrderFilters(context),
            ),
            _TabStrip(
              controller: _tabs,
              pendingCount: pendingOrders.length,
              acceptedCount: acceptedOrders.length,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _OrderList(
                    orders: pendingOrders,
                    emptyTitle: text.quietForNow,
                    canCreate: canCreate,
                    onCreate: () => _openNewOrderForm(context),
                    shortcut: pendingShortcut,
                    onPrint: (o) => _printBill(context, o),
                    onStatus: (o, s) => _changeStatus(context, o, s),
                  ),
                  _OrderList(
                    orders: acceptedOrders,
                    emptyTitle: text.noAcceptedOrdersRightNow,
                    canCreate: canCreate,
                    onCreate: () => _openNewOrderForm(context),
                    shortcut: acceptedShortcut,
                    onPrint: (o) => _printBill(context, o),
                    onStatus: (o, s) => _changeStatus(context, o, s),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _sortOrders(OrderModel a, OrderModel b) {
    final priority = a.status.priority.compareTo(b.status.priority);
    if (priority != 0) return priority;
    return b.createdAt.compareTo(a.createdAt);
  }

  List<OrderModel> _pendingOrders(List<OrderModel> orders) {
    return orders
        .where((o) => o.status.adminStatus == OrderStatus.pending)
        .toList(growable: false);
  }

  List<OrderModel> _acceptedOrders(List<OrderModel> orders) {
    return orders
        .where(
          (o) =>
              o.status.adminStatus == OrderStatus.accepted ||
              o.status.adminStatus == OrderStatus.served ||
              o.status == OrderStatus.preparing ||
              o.status == OrderStatus.ready,
        )
        .toList(growable: false);
  }

  _EmptyShortcut? _emptyShortcut({
    required BuildContext context,
    required List<OrderModel> currentFiltered,
    required List<OrderModel> currentUnfiltered,
    required List<OrderModel> otherFiltered,
    required String otherLabel,
    required int otherTabIndex,
  }) {
    if (currentFiltered.isNotEmpty) return null;
    final text = AppScope.of(context).strings;
    if (_filters.isActive && currentUnfiltered.isNotEmpty) {
      return _EmptyShortcut(
        label: text.clearFiltersShortcut,
        onTap: () => setState(() => _filters = OrderListFilters.none),
      );
    }
    if (otherFiltered.isNotEmpty) {
      return _EmptyShortcut(
        label: text.viewOtherOrdersInstead(otherLabel),
        onTap: () => _tabs.animateTo(otherTabIndex),
      );
    }
    return null;
  }

  void _syncTabWithPendingOrders(int pendingCount, int acceptedCount) {
    final previousPendingCount = _lastPendingCount;
    _lastPendingCount = pendingCount;

    // Only auto-switch on actual transitions, not on every rebuild — otherwise
    // tapping into the pending tab while pendingCount is still 0 bounces the
    // user straight back to accepted.
    if (previousPendingCount == null) return;

    final pendingJustDrained =
        previousPendingCount > 0 &&
        pendingCount == 0 &&
        acceptedCount > 0 &&
        _tabs.index != 1;
    final hasNewPendingOrder =
        pendingCount > previousPendingCount && _tabs.index != 0;

    if (!pendingJustDrained && !hasNewPendingOrder) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetIndex = pendingJustDrained ? 1 : 0;
      if (_tabs.index != targetIndex) {
        _tabs.animateTo(targetIndex);
      }
    });
  }

  Future<void> _openOrderFilters(BuildContext context) async {
    final app = AppScope.of(context);
    final result = await showModalBottomSheet<OrderListFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _OrdersFilterSheet(initial: _filters, strings: app.strings),
    );
    if (result != null && mounted) {
      setState(() => _filters = result);
    }
  }

  Future<void> _openNewOrderForm(BuildContext context) async {
    final app = AppScope.of(context);
    final menuItems = app.menuItems
        .where((i) => i.isAvailable)
        .toList(growable: false);
    final tableCount = app.serverConfig.tableCount;

    // Surface a snapshot of which tables already have an active (pending or
    // accepted) order so the picker can warn the manager before they kick off
    // a new ticket for a seat that's still eating.
    final occupiedTables = <String>{
      for (final order in app.ordersFor())
        if (order.status.isOpen)
          if ((order.tableNo ?? '').trim().isNotEmpty) order.tableNo!.trim(),
    };

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NewOrderPage(
          menuItems: menuItems,
          tableCount: tableCount,
          occupiedTables: occupiedTables,
          onCreateOrder: (result) async {
            final order = await app.createManualOrder(
              requestedItems: result.items,
              tableNo: result.tableNo,
              note: result.note,
              serviceType: result.serviceType,
              paymentMethod: null,
            );
            final shouldPrint =
                app.isManager &&
                !app.printerState.autoPrintEnabled &&
                app.printerState.hasSelectedPrinter &&
                !app.printerService.hasPrintedOrder(order.id);
            if (shouldPrint) {
              await app.printOrderTicket(order);
            }
            return order;
          },
        ),
      ),
    );
  }

  Future<void> _printBill(BuildContext context, OrderModel order) async {
    final app = AppScope.of(context);
    if (!app.isManager) return;
    final text = app.strings;
    if (!app.printerState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.printerNotConnectedHint),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
      return;
    }
    final ok = await app.printCustomerInvoice(order);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TfText(          ok
              ? text.billPrinted(order.displaySequence)
              : (app.printerState.lastError ?? text.printFailed),
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    OrderModel order,
    OrderStatus status,
  ) async {
    final app = AppScope.of(context);
    if (!app.isManager) return;
    await app.updateOrderStatus(order.id, status);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pendingCount,
    required this.acceptedCount,
    required this.totalFiltered,
    required this.filtersActive,
    required this.onFilterPressed,
  });

  final int pendingCount;
  final int acceptedCount;
  final int totalFiltered;
  final bool filtersActive;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final subtitle = filtersActive
        ? text.ordersFilteredSubtitle(
            pendingCount,
            acceptedCount,
            totalFiltered,
          )
        : totalFiltered == 0
        ? text.ordersEmptySubtitle
        : text.pendingSubtitle(pendingCount, acceptedCount);
    final quietEmpty = totalFiltered == 0 && !filtersActive;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 14, 12, 7),
      child: TfAppBar(
        title: text.ordersTitle,
        subtitle: subtitle,
        trailing: [
          // Tapping the bell on this screen is a no-op for navigation,
          // since we're already on the Orders tab.
          if (!quietEmpty) HeaderLanguageButton(),
          HeaderNotificationBell(onNavigateToOrders: () {}),
          if (!quietEmpty)
            TfIconButton(
              icon: Icons.tune_rounded,
              tooltip: text.filterOrders,
              dark: filtersActive,
              onPressed: onFilterPressed,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order filters sheet
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersFilterSheet extends StatefulWidget {
  const _OrdersFilterSheet({required this.initial, required this.strings});

  final OrderListFilters initial;
  final AppStrings strings;

  @override
  State<_OrdersFilterSheet> createState() => _OrdersFilterSheetState();
}

class _OrdersFilterSheetState extends State<_OrdersFilterSheet> {
  late OrderDateRange _dateRange;
  OrderSource? _source;

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initial.dateRange;
    _source = widget.initial.source;
  }

  String _dateLabel(OrderDateRange range) {
    final t = widget.strings;
    switch (range) {
      case OrderDateRange.all:
        return t.allTime;
      case OrderDateRange.today:
        return t.today;
      case OrderDateRange.yesterday:
        return t.yesterday;
      case OrderDateRange.last7Days:
        return t.last7Days;
      case OrderDateRange.last30Days:
        return t.last30Days;
      case OrderDateRange.last3Months:
        return t.last3Months;
      case OrderDateRange.last6Months:
        return t.last6Months;
      case OrderDateRange.last12Months:
        return t.last12Months;
    }
  }

  OrderListFilters get _draft =>
      OrderListFilters(dateRange: _dateRange, source: _source);

  @override
  Widget build(BuildContext context) {
    final t = widget.strings;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: PosColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            TfText(              t.filterOrders,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
            ),
            SizedBox(height: 16),
            TfText(              t.filterByDate,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: PosColors.muted,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OrderDateRange.values.map((range) {
                final selected = _dateRange == range;
                return TfChip(
                  label: _dateLabel(range),
                  active: selected,
                  small: true,
                  onTap: () => setState(() => _dateRange = range),
                );
              }).toList(),
            ),
            SizedBox(height: 18),
            TfText(              t.filterBySource,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: PosColors.muted,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TfChip(
                  label: t.allChannels,
                  active: _source == null,
                  small: true,
                  onTap: () => setState(() => _source = null),
                ),
                ...OrderSource.values.map((source) {
                  final selected = _source == source;
                  return TfChip(
                    label: t.orderSourceLabel(source),
                    active: selected,
                    small: true,
                    onTap: () =>
                        setState(() => _source = selected ? null : source),
                  );
                }),
              ],
            ),
            SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TfButton(
                    label: t.resetFilters,
                    variant: TfButtonVariant.paper,
                    onPressed: () {
                      setState(() {
                        _dateRange = OrderDateRange.all;
                        _source = null;
                      });
                    },
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TfButton(
                    label: t.applyFilters,
                    onPressed: () => Navigator.pop(context, _draft),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill tab strip
// ─────────────────────────────────────────────────────────────────────────────

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.controller,
    required this.pendingCount,
    required this.acceptedCount,
  });

  final TabController controller;
  final int pendingCount;
  final int acceptedCount;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return TfTabs(
            activeIndex: controller.index,
            onChanged: (i) => controller.animateTo(i),
            items: [
              TfTabItem(label: text.pendingTab, count: pendingCount),
              TfTabItem(label: text.acceptedTab, count: acceptedCount),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order list
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyShortcut {
  const _EmptyShortcut({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.emptyTitle,
    required this.canCreate,
    required this.onCreate,
    required this.shortcut,
    required this.onPrint,
    required this.onStatus,
  });

  final List<OrderModel> orders;
  final String emptyTitle;
  final bool canCreate;
  final VoidCallback onCreate;
  final _EmptyShortcut? shortcut;
  final void Function(OrderModel) onPrint;
  final void Function(OrderModel, OrderStatus) onStatus;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _SmartOrdersEmptyState(
        title: emptyTitle,
        canCreate: canCreate,
        onCreate: onCreate,
        shortcut: shortcut,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _OrderCard(
        order: orders[i],
        onPrint: () => onPrint(orders[i]),
        onStatus: (s) => onStatus(orders[i], s),
      ),
    );
  }
}

class _SmartOrdersEmptyState extends StatelessWidget {
  const _SmartOrdersEmptyState({
    required this.title,
    required this.canCreate,
    required this.onCreate,
    required this.shortcut,
  });

  final String title;
  final bool canCreate;
  final VoidCallback onCreate;
  final _EmptyShortcut? shortcut;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 112),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 160)
                      .clamp(220, 420)
                      .toDouble(),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: PosColors.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        TfNavIcon.orders,
                        color: PosColors.primaryDark,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TfText(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PosColors.slate,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TfText(
                      text.quietOrdersMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PosColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                    if (!canCreate) ...[
                      const SizedBox(height: 12),
                      TfText(
                        text.addMenuItemsBeforeOrders,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: PosColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (shortcut != null) ...[
                      const SizedBox(height: 12),
                      TfButton(
                        label: shortcut!.label,
                        variant: TfButtonVariant.ghost,
                        fullWidth: false,
                        onPressed: shortcut!.onTap,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: TfButton(
                label: text.newOrder,
                icon: TfNavIcon.plus,
                size: TfButtonSize.lg,
                onPressed: canCreate ? onCreate : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order card with left accent bar
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onPrint,
    required this.onStatus,
  });

  final OrderModel order;
  final VoidCallback onPrint;
  final ValueChanged<OrderStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final canPrint = app.isManager;
    final adminStatus = order.status.adminStatus;
    final isPending = adminStatus == OrderStatus.pending;
    final isAccepted = adminStatus == OrderStatus.accepted;
    final elapsedMinutes = DateTime.now()
        .difference(order.createdAt.toLocal())
        .inMinutes;
    final lateMinutes = isPending && elapsedMinutes > 20
        ? elapsedMinutes - 20
        : 0;
    final isLate = lateMinutes > 0;

    // Rail colour: amber pending · red late pending · green in-kitchen/served.
    final railColor = switch (adminStatus) {
      OrderStatus.pending => isLate ? PosColors.danger : PosColors.primary,
      OrderStatus.cancelled => PosColors.coral,
      _ => PosColors.success,
    };

    // Status pill kind.
    final TfStatusKind? statusKind = isLate
        ? TfStatusKind.late
        : isPending
        ? TfStatusKind.pending
        : (isAccepted ||
              adminStatus == OrderStatus.preparing ||
              adminStatus == OrderStatus.ready)
        ? TfStatusKind.accepted
        : adminStatus == OrderStatus.served
        ? TfStatusKind.served
        : null;

    final statusLabel = isLate
        ? text.orderStatusLate(lateMinutes)
        : isPending
        ? text.orderStatusPending
        : (isAccepted ||
              adminStatus == OrderStatus.preparing ||
              adminStatus == OrderStatus.ready)
        ? text.orderStatusInKitchen
        : adminStatus == OrderStatus.served
        ? text.servedAction
        : null;

    final sourceLabel = _sourceLabel(order, text);
    final subline = isPending
        ? '$sourceLabel · ${text.agoMinutes(elapsedMinutes)} · ${text.orderItemsCount(order.items.length)}'
        : '${text.agoMinutes(elapsedMinutes)} · ${text.orderItemsCount(order.items.length)}';

    final nextStatus = (isPending && app.isManager)
        ? OrderStatus.accepted
        : null;

    return TfCard(
      padded: false,
      clip: true,
      child: InkWell(
        onLongPress: canPrint && isAccepted ? onPrint : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TfRail(color: railColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: #id · source · status · total
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TfText(
                                  order.displaySequence,
                                  style: TextStyle(
                                    fontFamily: tfFontFamily(context),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: PosColors.slate,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                TfText(                                  '· $sourceLabel',
                                  style: TextStyle(
                                    fontFamily: tfFontFamily(context),
                                    fontSize: 14,
                                    color: PosColors.slate,
                                  ),
                                ),
                                if (statusKind != null && statusLabel != null)
                                  TfStatusBadge(
                                    label: statusLabel,
                                    kind: statusKind,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          TfText(                            tfFormatCurrency(context, order.total),
                            style: TextStyle(
                              fontFamily: tfFontFamily(context),
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: PosColors.slate,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TfText(
                        subline,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PosColors.muted,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Items list — first 3, then "+N more".
                      ...order.items
                          .take(3)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: TfText(
                                '${tfFormatNumber(context, item.qty)}× ${item.name}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: PosColors.slate,
                                  height: 1.35,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      if (order.items.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: TfText(                            text.isBn
                                ? '+${tfFormatNumber(context, order.items.length - 3)} আরও'
                                : '+${tfFormatNumber(context, order.items.length - 3)} more',
                            style: const TextStyle(
                              fontSize: 11,
                              color: PosColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if ((order.note ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        TfText(
                          order.note!.trim(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: PosColors.muted,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Actions row.
                      if (canPrint && (isPending || isAccepted)) ...[
                        const SizedBox(height: 12),
                        if (isPending)
                          Row(
                            children: [
                              Expanded(
                                child: TfButton(
                                  label: text.rejectOrderAction,
                                  variant: TfButtonVariant.ghost,
                                  size: TfButtonSize.md,
                                  onPressed: () =>
                                      onStatus(OrderStatus.cancelled),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TfButton(
                                  label: text.acceptAndSendToKitchen,
                                  icon: TfNavIcon.check,
                                  size: TfButtonSize.md,
                                  onPressed: () => onStatus(nextStatus!),
                                ),
                              ),
                            ],
                          )
                        else
                          TfButton(
                            label: text.printBillAction,
                            icon: TfNavIcon.printer,
                            variant: TfButtonVariant.dark,
                            size: TfButtonSize.md,
                            onPressed: onPrint,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(OrderModel order, AppStrings text) {
    final table = (order.tableNo ?? '').trim();
    if (table.isNotEmpty) {
      return text.isBn ? 'টেবিল ${tfToBnNumbers(table)}' : 'Table $table';
    }
    switch (order.serviceType) {
      case OrderServiceType.takeaway:
        return text.isBn ? 'পার্সেল' : 'Parcel';
      case OrderServiceType.delivery:
        return text.isBn ? 'ডেলিভারি' : 'Delivery';
      case OrderServiceType.dineIn:
      case null:
        return text.isBn ? 'ডাইন-ইন' : 'Dine-in';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order created sheet
// ─────────────────────────────────────────────────────────────────────────────

// ignore: unused_element
class _OrderCreatedSheet extends StatelessWidget {
  // ignore: unused_element_parameter
  const _OrderCreatedSheet({
    required this.order,
    required this.autoPrinted,
    required this.canPrint,
    required this.onPrint,
    // ignore: unused_element_parameter
    this.menuUrl,
  });

  final OrderModel order;
  final bool autoPrinted;
  final bool canPrint;
  final VoidCallback onPrint;
  final String? menuUrl;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Container(
      color: PosColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header — Back to orders. Always reachable so a manager never
            // gets stuck on the receipt.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: PosColors.slate,
                    tooltip: 'Back to orders',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: TfText(                      'Receipt',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: PosColors.slate,
                      ),
                    ),
                  ),
                  if (autoPrinted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PosColors.successSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.print_rounded,
                            size: 12,
                            color: PosColors.success,
                          ),
                          const SizedBox(width: 4),
                          TfText(                            text.ticketSentToPrinter,
                            style: const TextStyle(
                              color: PosColors.success,
                              fontWeight: FontWeight.w500,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PosColors.line, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: PosColors.successSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: PosColors.success,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TfText(                          'Order created',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: PosColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Big order # focus.
                        TfText(                          order.displaySequence,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 56,
                            color: PosColors.slate,
                            height: 1,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if ((order.tableNo ?? '').isNotEmpty)
                          TfText(                            'Table ${order.tableNo}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: PosColors.muted,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: PosColors.line,
                              width: 0.5,
                            ),
                          ),
                          child: QrImageView(
                            data: menuUrl ?? order.id,
                            version: QrVersions.auto,
                            size: 130,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: PosColors.slate,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: PosColors.slate,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TfText(                          menuUrl != null
                              ? 'Scan to view the menu'
                              : order.orderNo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: PosColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Items list
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PosColors.line, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TfText(                          'ITEMS',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: PosColors.muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final item in order.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: TfText(                                    '${tfFormatNumber(context, item.qty)}×',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12.5,
                                      color: PosColors.muted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TfText(                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: PosColors.slate,
                                    ),
                                  ),
                                ),
                                TfText(                                  tfFormatCurrency(context, item.lineTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: PosColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Divider(color: PosColors.line, height: 22),
                        Row(
                          children: [
                            TfText(                              'TOTAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: PosColors.slate,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const Spacer(),
                            TfText(                              tfFormatCurrency(context, order.total),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                color: PosColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom action bar: Print bill + Back to orders.
            Container(
              decoration: BoxDecoration(
                color: PosColors.surface,
                border: Border(
                  top: BorderSide(color: PosColors.line, width: 0.5),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Row(
                children: [
                  if (canPrint)
                    Expanded(
                      child: TfButton(
                        label: 'Print bill',
                        icon: Icons.print_rounded,
                        variant: TfButtonVariant.paper,
                        size: TfButtonSize.lg,
                        onPressed: onPrint,
                      ),
                    ),
                  if (canPrint) const SizedBox(width: 10),
                  Expanded(
                    child: TfButton(
                      label: 'Back to orders',
                      size: TfButtonSize.lg,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New order page — source, items, review, success
// ─────────────────────────────────────────────────────────────────────────────

class _OrderResult {
  _OrderResult({
    required this.items,
    required this.serviceType,
    this.tableNo,
    this.note,
  });

  final List<OrderRequestItem> items;
  final OrderServiceType serviceType;
  final String? tableNo;
  final String? note;
}

class _NewOrderPage extends StatefulWidget {
  const _NewOrderPage({
    required this.menuItems,
    required this.tableCount,
    required this.occupiedTables,
    required this.onCreateOrder,
  });

  final List<MenuItem> menuItems;
  final int tableCount;
  final Set<String> occupiedTables;
  final Future<OrderModel> Function(_OrderResult result) onCreateOrder;

  @override
  State<_NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<_NewOrderPage> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const int _totalSteps = 4;

  OrderServiceType? _source;
  String? _selectedTable;

  final Map<String, int> _cart = {};
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _query = '';
  OrderModel? _createdOrder;
  bool _creating = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _goToStep(int index) {
    if (index < 0 || index >= _totalSteps) return;
    setState(() => _step = index);
    _pageCtrl.animateToPage(
      index,
      duration: Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _selectTable(String? table) {
    setState(() => _selectedTable = table);
  }

  void _selectSource(OrderServiceType src) {
    setState(() {
      _source = src;
      if (src != OrderServiceType.dineIn) {
        _selectedTable = '';
      } else {
        _selectedTable = null;
      }
    });
  }

  void _continueFromSource() {
    if (_source == null) return;
    if (_source == OrderServiceType.dineIn && _selectedTable == null) return;
    _goToStep(1);
  }

  List<String> get _categories {
    final cats = widget.menuItems.map((i) => i.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...cats];
  }

  List<MenuItem> get _visibleItems => widget.menuItems
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

  int get _totalQty => _cart.values.fold(0, (s, q) => s + q);

  double get _subtotal {
    var sum = 0.0;
    for (final entry in _cart.entries) {
      final item = widget.menuItems.firstWhere(
        (m) => m.id == entry.key,
        orElse: () => widget.menuItems.first,
      );
      sum += item.price * entry.value;
    }
    return sum;
  }

  double get _vatAmount => _roundMoney(_subtotal * 0.05);

  double get _total => _roundMoney(_subtotal + _vatAmount);

  double _roundMoney(double value) => double.parse(value.toStringAsFixed(2));

  void _tap(String id) {
    HapticFeedback.lightImpact();
    setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
  }

  void _decrement(String id) {
    setState(() {
      final current = _cart[id] ?? 0;
      if (current <= 1) {
        _cart.remove(id);
      } else {
        _cart[id] = current - 1;
      }
    });
  }

  void _goToReview() {
    if (_cart.isEmpty) return;
    _goToStep(2);
  }

  Future<void> _submit() async {
    if (_cart.isEmpty || _source == null || _creating) return;
    final items = _cart.entries
        .map((e) => OrderRequestItem(menuItemId: e.key, qty: e.value))
        .toList(growable: false);
    final isDineIn = _source == OrderServiceType.dineIn;
    final tableNo = isDineIn && (_selectedTable ?? '').isNotEmpty
        ? _selectedTable
        : null;
    setState(() => _creating = true);
    try {
      final order = await widget.onCreateOrder(
        _OrderResult(
          items: items,
          serviceType: _source!,
          tableNo: tableNo,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _createdOrder = order;
        _creating = false;
      });
      _goToStep(3);
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText('Could not create order: $error')));
    }
  }

  void _startAnotherOrder() {
    setState(() {
      _step = 0;
      _source = null;
      _selectedTable = null;
      _cart.clear();
      _selectedCategory = 'All';
      _query = '';
      _searchCtrl.clear();
      _noteCtrl.clear();
      _createdOrder = null;
      _creating = false;
    });
    _pageCtrl.jumpToPage(0);
  }

  String get _tableLabel {
    if (_source == OrderServiceType.takeaway) return 'Parcel';
    if (_source == OrderServiceType.delivery) return 'Delivery';
    if (_selectedTable == null) return '';
    if (_selectedTable!.isEmpty) return 'Parcel';
    return 'Table $_selectedTable';
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _step == 3;
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _WizardHeader(
              step: _step,
              totalSteps: _totalSteps,
              tableLabel: _tableLabel,
              onClose: () => Navigator.pop(context),
              onBack: _step > 0 && !isSuccess
                  ? () => _goToStep(_step - 1)
                  : null,
            ),
            _StepIndicator(step: _step, total: _totalSteps),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SourceAndTableStep(
                    source: _source,
                    onSelectSource: _selectSource,
                    tableCount: widget.tableCount,
                    selectedTable: _selectedTable,
                    occupiedTables: widget.occupiedTables,
                    onSelectTable: _selectTable,
                    onContinue:
                        _source != null &&
                            (_source != OrderServiceType.dineIn ||
                                _selectedTable != null)
                        ? _continueFromSource
                        : null,
                  ),
                  _MenuStep(
                    menuItems: widget.menuItems,
                    visibleItems: _visibleItems,
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    cart: _cart,
                    total: _total,
                    totalQty: _totalQty,
                    searchCtrl: _searchCtrl,
                    query: _query,
                    onSearchChanged: (value) => setState(() => _query = value),
                    onCategorySelected: (c) =>
                        setState(() => _selectedCategory = c),
                    onTap: _tap,
                    onDecrement: _decrement,
                    onSubmit: _cart.isNotEmpty ? _goToReview : null,
                  ),
                  _ReviewStep(
                    menuItems: widget.menuItems,
                    cart: _cart,
                    total: _total,
                    noteCtrl: _noteCtrl,
                    sourceLabel: _tableLabel.isEmpty ? '—' : _tableLabel,
                    onEdit: () => _goToStep(1),
                    onCreate: _submit,
                    creating: _creating,
                  ),
                  _OrderCreatedStep(
                    order: _createdOrder,
                    serviceLabel: _tableLabel,
                    total: _total,
                    onDone: () => Navigator.pop(context),
                    onNewOrder: _startAnotherOrder,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.totalSteps,
    required this.tableLabel,
    required this.onClose,
    required this.onBack,
  });

  final int step;
  final int totalSteps;
  final String tableLabel;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isBn = text.isBn;
    final stepLabels = isBn
        ? const [
            'অর্ডার কোথা থেকে?',
            'আইটেম যোগ করুন',
            'রিভিউ ও পাঠান',
            'অর্ডার তৈরি হয়েছে',
          ]
        : const [
            "Where's this order for?",
            'Add items',
            'Review & send',
            'Order created',
          ];
    final stepLabel = stepLabels[step.clamp(0, stepLabels.length - 1)];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfIconButton(
            icon: onBack != null ? TfNavIcon.back : TfNavIcon.close,
            tooltip: onBack != null
                ? (isBn ? 'পেছনে' : 'Back')
                : (isBn ? 'বাতিল' : 'Close'),
            onPressed: onBack ?? onClose,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  '${isBn ? 'ধাপ' : 'STEP'} ${step + 1} ${isBn ? 'এর' : 'OF'} $totalSteps'
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: PosColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                TfText(
                  stepLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (tableLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TfText(
                tableLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: PosColors.muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, this.total = 3});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                height: 3,
                decoration: BoxDecoration(
                  color: i <= step ? PosColors.primary : PosColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < total - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Source picker (Dine-in / Parcel) — wraps the existing
// table picker so dine-in shows tables directly underneath the source choice.
// ─────────────────────────────────────────────────────────────────────────────

class _SourceAndTableStep extends StatelessWidget {
  const _SourceAndTableStep({
    required this.source,
    required this.onSelectSource,
    required this.tableCount,
    required this.selectedTable,
    required this.occupiedTables,
    required this.onSelectTable,
    required this.onContinue,
  });

  final OrderServiceType? source;
  final ValueChanged<OrderServiceType> onSelectSource;
  final int tableCount;
  final String? selectedTable;
  final Set<String> occupiedTables;
  final ValueChanged<String> onSelectTable;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isDineIn = source == OrderServiceType.dineIn;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SourceTile(
                        icon: Icons.table_restaurant_outlined,
                        source: OrderServiceType.dineIn,
                        selected: source == OrderServiceType.dineIn,
                        onTap: () => onSelectSource(OrderServiceType.dineIn),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SourceTile(
                        icon: Icons.takeout_dining_outlined,
                        source: OrderServiceType.takeaway,
                        selected: source == OrderServiceType.takeaway,
                        onTap: () => onSelectSource(OrderServiceType.takeaway),
                      ),
                    ),
                  ],
                ),
                if (isDineIn) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TfText(
                          text.pickATable,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: PosColors.slate,
                          ),
                        ),
                      ),
                      TfText(
                        '${tfFormatNumber(context, tableCount)} ${text.isBn ? "টেবিল" : "tables"}'
                        ' · ${tfFormatNumber(context, tableCount - occupiedTables.length)} ${text.isBn ? "খালি" : "free"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PosColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 80,
                          mainAxisExtent: 80,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: tableCount,
                    itemBuilder: (_, i) {
                      final tableNo = '${i + 1}';
                      final sel = selectedTable == tableNo;
                      final occ = occupiedTables.contains(tableNo);
                      return _TableTile(
                        number: i + 1,
                        selected: sel,
                        occupied: occ,
                        onTap: () => onSelectTable(tableNo),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        TfStickyCTA(
          child: TfButton(
            label: text.continueAction,
            trailingIcon: TfNavIcon.arrow,
            size: TfButtonSize.lg,
            onPressed: onContinue,
          ),
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final OrderServiceType source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    final label = isBn ? source.banglaLabel : source.label;
    return Material(
      color: selected ? PosColors.primaryDark : PosColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? PosColors.primaryDark : PosColors.line,
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? Colors.white : PosColors.primaryDark,
              ),
              const SizedBox(height: 10),
              TfText(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : PosColors.slate,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review step with VAT, kitchen note, and create CTA.
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.menuItems,
    required this.cart,
    required this.total,
    required this.noteCtrl,
    required this.sourceLabel,
    required this.onEdit,
    required this.onCreate,
    required this.creating,
  });

  final List<MenuItem> menuItems;
  final Map<String, int> cart;
  final double total;
  final TextEditingController noteCtrl;
  final String sourceLabel;
  final VoidCallback onEdit;
  final Future<void> Function() onCreate;
  final bool creating;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              TfCard(
                padded: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      child: Row(
                        children: [
                          TfSectionHeader(
                            label: text.sourceLabel,
                            padding: EdgeInsets.zero,
                          ),
                          const Spacer(),
                          TfText(
                            sourceLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: PosColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      color: PosColors.line,
                      height: 1,
                      thickness: 0.5,
                    ),
                    ...cart.entries.map((entry) {
                      final item = menuItems.firstWhere(
                        (m) => m.id == entry.key,
                        orElse: () => menuItems.first,
                      );
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: TfText(
                                '${tfFormatNumber(context, entry.value)}×',
                                style: TextStyle(
                                  fontFamily: tfFontFamily(context),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: PosColors.slate,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TfText(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: PosColors.slate,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TfText(                              tfFormatCurrency(
                                context,
                                item.price * entry.value,
                              ),
                              style: TextStyle(
                                fontFamily: tfFontFamily(context),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: PosColors.slate,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                      child: TfButton(
                        label: text.editItemsAction,
                        icon: Icons.edit_outlined,
                        variant: TfButtonVariant.ghost,
                        size: TfButtonSize.sm,
                        fullWidth: false,
                        onPressed: onEdit,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: Row(
                  children: [
                    TfText(
                      text.kitchenNote,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: PosColors.slate,
                      ),
                    ),
                    const SizedBox(width: 6),
                    TfText(
                      text.kitchenNoteOptional,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PosColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              TfCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: TextField(
                  controller: noteCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 3,
                  style: TextStyle(
                    fontFamily: text.isBn ? 'Hind Siliguri' : 'Inter',
                    fontSize: 14,
                    color: PosColors.slate,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: text.kitchenNoteHint,
                    hintStyle: TextStyle(
                      fontFamily: text.isBn ? 'Hind Siliguri' : 'Inter',
                      color: PosColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        TfStickyCTA(
          child: Row(
            children: [
              Expanded(
                child: TfText(
                  '${text.totalLabel}: ${tfFormatCurrency(context, total)}',
                  style: const TextStyle(
                    color: PosColors.slate,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TfButton(
                  label: creating ? '...' : text.sendToKitchen,
                  icon: creating ? null : TfNavIcon.check,
                  size: TfButtonSize.lg,
                  onPressed: creating ? null : () => onCreate(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TfText(          label,
          style: TextStyle(
            fontSize: 12.5,
            color: PosColors.muted,
            fontWeight: FontWeight.w400,
          ),
        ),
        const Spacer(),
        TfText(          value,
          style: TextStyle(
            fontSize: 12.5,
            color: PosColors.slate,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _OrderCreatedStep extends StatelessWidget {
  const _OrderCreatedStep({
    required this.order,
    required this.serviceLabel,
    required this.total,
    required this.onDone,
    required this.onNewOrder,
  });

  final OrderModel? order;
  final String serviceLabel;
  final double total;
  final VoidCallback onDone;
  final VoidCallback onNewOrder;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isBn = text.isBn;
    final source = serviceLabel.isEmpty
        ? (isBn ? 'পার্সেল' : 'Parcel')
        : serviceLabel;
    final orderNo = order?.displaySequence ?? '#order';
    final qrData = order == null
        ? orderNo
        : 'terafoods://order/${order!.id}?no=$orderNo';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: PosColors.successSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 38,
                      color: PosColors.success,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TfText(
                    text.orderCreatedTitle,
                    style: const TextStyle(
                      color: PosColors.slate,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TfText(
                    orderNo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: PosColors.primaryDark,
                      fontSize: 68,
                      fontWeight: FontWeight.w500,
                      height: 0.95,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TfText(
                    '$source · ${tfFormatCurrency(context, order?.total ?? total)}',
                    style: const TextStyle(
                      color: PosColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PosColors.line, width: 0.5),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 210,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: PosColors.primaryDark,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: PosColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TfCard(
                    child: Column(
                      children: [
                        _AmountLine(label: text.orderLabel, value: orderNo),
                        const SizedBox(height: 8),
                        _AmountLine(label: text.sourceLabel, value: source),
                        const SizedBox(height: 8),
                        _AmountLine(
                          label: text.totalLabel,
                          value: tfFormatCurrency(
                            context,
                            order?.total ?? total,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TfButton(
                  label: text.takeAnotherOrder,
                  icon: TfNavIcon.plus,
                  variant: TfButtonVariant.dark,
                  size: TfButtonSize.lg,
                  onPressed: onNewOrder,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TfButton(
            label: text.backToOrders,
            icon: Icons.list_alt_outlined,
            variant: TfButtonVariant.ghost,
            size: TfButtonSize.md,
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.number,
    required this.selected,
    required this.occupied,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final bool occupied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    // Selected: amber; occupied (and not selected): muted/disabled; free: paper.
    final bg = selected
        ? PosColors.primary
        : occupied
        ? PosColors.background
        : PosColors.surface;
    final borderColor = selected ? PosColors.primaryDark : PosColors.line;
    final numberColor = selected
        ? PosColors.primaryDark
        : occupied
        ? PosColors.muted
        : PosColors.slate;
    final subColor = selected ? PosColors.primaryDark : PosColors.muted;
    final sub = selected
        ? text.isBn
              ? 'নির্বাচিত'
              : 'selected'
        : occupied
        ? text.isBn
              ? 'বসা'
              : 'busy'
        : text.isBn
        ? 'খালি'
        : 'free';
    return Opacity(
      opacity: occupied && !selected ? 0.6 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TfText(                  tfFormatNumber(context, number),
                  style: TextStyle(
                    fontFamily: tfFontFamily(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: numberColor,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                TfText(sub, style: TextStyle(fontSize: 10, color: subColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuStep extends StatelessWidget {
  const _MenuStep({
    required this.menuItems,
    required this.visibleItems,
    required this.categories,
    required this.selectedCategory,
    required this.cart,
    required this.total,
    required this.totalQty,
    required this.searchCtrl,
    required this.query,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onTap,
    required this.onDecrement,
    required this.onSubmit,
  });

  final List<MenuItem> menuItems;
  final List<MenuItem> visibleItems;
  final List<String> categories;
  final String selectedCategory;
  final Map<String, int> cart;
  final double total;
  final int totalQty;
  final TextEditingController searchCtrl;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDecrement;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: AppScope.of(context).strings.searchMenuItems,
              prefixIcon: Icon(Icons.search_rounded, color: PosColors.muted),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChanged('');
                      },
                      icon: Icon(Icons.close_rounded, color: PosColors.muted),
                    ),
            ),
          ),
        ),
        _CategoryChips(
          categories: categories,
          selected: selectedCategory,
          onSelected: onCategorySelected,
        ),
        Expanded(
          child: _MenuGrid(
            items: visibleItems,
            cart: cart,
            onTap: onTap,
            onDecrement: onDecrement,
          ),
        ),
        _CartFooter(
          cart: cart,
          menuItems: menuItems,
          total: total,
          totalQty: totalQty,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final allLabel = AppScope.of(context).strings.categoryAll;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final sel = cat == selected;
          // 'All' is a synthetic display label — localise it here only.
          final label = cat == 'All' ? allLabel : cat;
          return TfChip(
            label: label,
            active: sel,
            small: true,
            onTap: () => onSelected(cat),
          );
        },
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({
    required this.items,
    required this.cart,
    required this.onTap,
    required this.onDecrement,
  });

  final List<MenuItem> items;
  final Map<String, int> cart;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDecrement;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: TfText(          AppScope.of(context).strings.noItemsInCategory,
          style: TextStyle(color: PosColors.muted),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 112,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _MenuTile(
        item: items[i],
        qty: cart[items[i].id] ?? 0,
        onTap: () => onTap(items[i].id),
        onDecrement: () => onDecrement(items[i].id),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.qty,
    required this.onTap,
    required this.onDecrement,
  });

  final MenuItem item;
  final int qty;
  final VoidCallback onTap;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final inCart = qty > 0;
    final hasImage = (item.imageUrl ?? '').isNotEmpty;
    final extras = item.extras;
    final hasAddOns = extras.addOns.isNotEmpty;
    final iconStyle = menuIconStyleFor(extras.iconKey);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: hasImage
              ? Colors.black
              : (inCart ? PosColors.slate : PosColors.surface),
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(
            color: inCart
                ? PosColors.primary
                : (hasImage ? Colors.transparent : PosColors.line),
            width: inCart ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: inCart ? 0.12 : 0.05),
              blurRadius: inCart ? 8 : 6,
              offset: Offset(0, inCart ? 4 : 2),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background image ──────────────────────────────────────────
            if (hasImage) _ItemImage(url: item.imageUrl!),

            // ── Gradient overlay for readability ──────────────────────────
            if (hasImage)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),

            // ── Yellow tint when in cart (image mode) ─────────────────────
            if (hasImage && inCart)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: PosColors.primary.withValues(alpha: 0.22),
                ),
              ),

            // ── Text content ──────────────────────────────────────────────
            if (hasImage)
              Padding(
                padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TfText(                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TfText(                            tfFormatCurrency(context, item.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        if (hasAddOns) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.tune_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              )
            else
              _PlainMenuTileContent(
                item: item,
                qty: qty,
                inCart: inCart,
                hasAddOns: hasAddOns,
                iconStyle: iconStyle,
                onDecrement: onDecrement,
              ),

            // ── Quantity stepper (top-right) ──────────────────────────────
            if (hasImage && inCart)
              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onDecrement,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Container(
                      constraints: BoxConstraints(minWidth: 20),
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: PosColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TfText(                        tfFormatNumber(context, qty),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: PosColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlainMenuTileContent extends StatelessWidget {
  const _PlainMenuTileContent({
    required this.item,
    required this.qty,
    required this.inCart,
    required this.hasAddOns,
    required this.iconStyle,
    required this.onDecrement,
  });

  final MenuItem item;
  final int qty;
  final bool inCart;
  final bool hasAddOns;
  final MenuIconStyle iconStyle;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final fg = inCart ? Colors.white : PosColors.slate;
    final muted = inCart
        ? Colors.white.withValues(alpha: 0.78)
        : PosColors.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: inCart
                      ? Colors.white.withValues(alpha: 0.12)
                      : iconStyle.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconStyle.icon,
                  color: inCart ? PosColors.primary : iconStyle.color,
                  size: 21,
                ),
              ),
              const Spacer(),
              if (inCart) ...[
                GestureDetector(
                  onTap: onDecrement,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.remove_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: PosColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TfText(                    tfFormatNumber(context, qty),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: PosColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          TfText(            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: fg,
              height: 1.16,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: TfText(                  tfFormatCurrency(context, item.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: muted,
                  ),
                ),
              ),
              if (hasAddOns) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: inCart
                        ? Colors.white.withValues(alpha: 0.12)
                        : PosColors.surfaceWarm,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: inCart
                          ? Colors.white.withValues(alpha: 0.16)
                          : PosColors.line,
                      width: 0.5,
                    ),
                  ),
                  child: Icon(Icons.tune_rounded, size: 12, color: muted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Renders a menu item image from either a network URL or a base64 data URL.
// Network images are automatically cached to local storage via CachedNetworkImage.
class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return _placeholder();
      }
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, url) => _placeholder(),
      errorWidget: (context, url, err) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF2A2622),
    child: const Center(
      child: Icon(Icons.restaurant_rounded, color: Color(0xFF4A4642), size: 22),
    ),
  );
}

class _CartFooter extends StatelessWidget {
  const _CartFooter({
    required this.cart,
    required this.menuItems,
    required this.total,
    required this.totalQty,
    required this.onSubmit,
  });

  final Map<String, int> cart;
  final List<MenuItem> menuItems;
  final double total;
  final int totalQty;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final hasItems = cart.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: const BoxDecoration(color: PosColors.primaryDark),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Row(
          children: [
            if (hasItems) ...[
              // Amber cart badge with item count, matches the JSX hero pill.
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PosColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: TfText(
                  tfFormatNumber(context, totalQty),
                  style: TextStyle(
                    fontFamily: tfFontFamily(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PosColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TfText(
                      text.orderItemsLine(totalQty, cart.length),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 2),
                    TfText(                      tfFormatCurrency(context, total),
                      style: TextStyle(
                        fontFamily: tfFontFamily(context),
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Expanded(
                child: TfText(
                  text.tapItemsToAdd,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            TfButton(
              label: text.reviewAction,
              trailingIcon: TfNavIcon.arrow,
              size: TfButtonSize.md,
              fullWidth: false,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
