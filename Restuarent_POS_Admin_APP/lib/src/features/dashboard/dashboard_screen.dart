import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/pos_compact_ui.dart';
import '../../models/inventory_item.dart';
import '../../models/menu_item.dart';
import '../../models/order_model.dart';
import '../../models/order_source.dart';
import '../../models/order_status.dart';
import '../../models/sales_report.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.onNavigate, super.key});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.initialized && app.lastError == null) {
      return LoadingView(message: 'Preparing cloud workspace...');
    }
    if (app.lastError != null && !app.initialized) {
      return Scaffold(
        backgroundColor: PosColors.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: ErrorView(message: app.lastError!),
          ),
        ),
      );
    }

    final metrics = app.metrics;
    final report7 = app.salesReportForDays(7);
    final report30 = app.salesReportForDays(30);
    final allOrders = app.ordersFor();
    final todayOrders = _todayOrders(allOrders);
    final yesterdayOrders = _yesterdayOrders(allOrders);
    final pendingNow = allOrders
        .where((o) => o.status.adminStatus == OrderStatus.pending)
        .length;
    final acceptedNow = allOrders
        .where((o) => o.status.adminStatus == OrderStatus.accepted)
        .length;
    final servedToday = todayOrders
        .where((o) => o.status.adminStatus == OrderStatus.served)
        .length;
    final cancelledToday = todayOrders
        .where((o) => o.status.adminStatus == OrderStatus.cancelled)
        .length;
    final avgTicket = metrics.todayOrders == 0
        ? 0.0
        : metrics.totalSales /
              todayOrders
                  .where((o) => o.status.adminStatus != OrderStatus.cancelled)
                  .length
                  .clamp(1, 999999);
    final topItems = _topItems(todayOrders);
    final topItem = topItems.isEmpty ? 'No item' : topItems.first.name;
    final sourceStats = _sourceStats(todayOrders);
    final hourlyStats = _hourlyStats(todayOrders);
    final inventoryRisk = _inventoryAtRisk(app.inventoryItems);
    final salesCurrency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final stockValue = app.inventoryItems.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.costPerUnit),
    );
    final staleOrders = _staleOrders(allOrders);
    final avgPrepMinutes = _avgPrepMinutes(todayOrders);
    final serviceMix = _serviceMix(todayOrders);
    final leaderboard = _staffLeaderboard(
      orders: todayOrders,
      currentAccountId: app.accountId,
      currentDisplayName: app.accountDisplayName.isEmpty
          ? app.accountEmail
          : app.accountDisplayName,
    );
    final categoryStats = _categoryStats(todayOrders, app.menuItems);
    final ordersVsYesterday = todayOrders.length - yesterdayOrders.length;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 14, 12, 18),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CompactHeader(
                      title: _greeting(),
                      subtitle:
                          '${app.restaurantName.isEmpty ? 'Restaurant dashboard' : app.restaurantName} · ${app.accountRole.label} · ${DateFormat('EEE, MMM d').format(DateTime.now())}',
                      actions: [
                        CompactIconButton(
                          icon: Icons.sync_rounded,
                          tooltip: 'Sync now',
                          onPressed: app.busy ? null : () => app.syncNow(),
                        ),
                        HeaderNotificationBell(
                          onNavigateToOrders: () => onNavigate(0),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _SalesHeroCard(
                      report: report7,
                      todaySales: metrics.totalSales,
                      currency: salesCurrency,
                    ),
                    SizedBox(height: 10),
                    _RevenuePeriodRow(
                      sevenDaySales: report7.totalSales,
                      thirtyDaySales: report30.totalSales,
                      currency: salesCurrency,
                    ),
                    SizedBox(height: 16),
                    CompactSectionLabel(label: 'Today · আজকের'),
                    SizedBox(height: 8),
                    _MetricGrid(
                      orders: metrics.todayOrders,
                      ordersVsYesterday: ordersVsYesterday,
                      open: pendingNow + acceptedNow,
                      avgTicket: avgTicket,
                      topItem: topItem,
                      currency: salesCurrency,
                      onOpenOrders: () => onNavigate(0),
                    ),
                    SizedBox(height: 16),
                    _ShiftCommandCenter(
                      pending: pendingNow,
                      inKitchen: acceptedNow,
                      served: servedToday,
                      cancelled: cancelledToday,
                      activeTables: _activeTables(allOrders),
                      totalTables: app.serverConfig.tableCount,
                      cancelRate: _cancelRate(todayOrders),
                      peakHourLabel: _peakHour(hourlyStats),
                      staffOrders: _roleOrderCount(todayOrders, 'staff'),
                      managerOrders: _roleOrderCount(todayOrders, 'manager'),
                      staleOrders: staleOrders,
                      avgPrepMinutes: avgPrepMinutes,
                    ),
                    SizedBox(height: 16),
                    CompactSectionLabel(label: 'Quick actions'),
                    SizedBox(height: 8),
                    _QuickActions(
                      onNewOrder: () => onNavigate(0),
                      onOpenReports: () => onNavigate(4),
                      onSync: app.syncNow,
                      onOpenMenu: () => onNavigate(1),
                      onOpenStock: () => onNavigate(3),
                    ),
                    SizedBox(height: 16),
                    _InsightGrid(
                      currency: salesCurrency,
                      sourceStats: sourceStats,
                      hourlyStats: hourlyStats,
                      topItems: topItems,
                      stockValue: stockValue,
                      totalOrders: todayOrders.length,
                      categoryStats: categoryStats,
                    ),
                    SizedBox(height: 16),
                    _ServiceMixCard(
                      mix: serviceMix,
                      currency: salesCurrency,
                    ),
                    SizedBox(height: 16),
                    _StaffLeaderboard(
                      rows: leaderboard,
                      currency: salesCurrency,
                    ),
                    SizedBox(height: 16),
                    _OperationsPanel(
                      pending: pendingNow,
                      accepted: acceptedNow,
                      lowStock: app.lowStockCount,
                      unavailable: app.menuItems
                          .where((item) => !item.isAvailable)
                          .length,
                      syncPending: app.syncState.pendingCount,
                      printerReady:
                          app.printerState.connected ||
                          app.printerState.hasSelectedPrinter,
                      staleOrders: staleOrders,
                    ),
                    SizedBox(height: 16),
                    _InventoryWatchlist(
                      items: inventoryRisk,
                      onOpenStock: () => onNavigate(3),
                    ),
                    SizedBox(height: 16),
                    _RecentOrders(orders: allOrders.take(6).toList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  List<OrderModel> _todayOrders(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders
        .where((order) {
          final created = order.createdAt.toLocal();
          return created.year == now.year &&
              created.month == now.month &&
              created.day == now.day;
        })
        .toList(growable: false);
  }

  List<OrderModel> _yesterdayOrders(List<OrderModel> orders) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return orders
        .where((order) {
          final created = order.createdAt.toLocal();
          return created.year == yesterday.year &&
              created.month == yesterday.month &&
              created.day == yesterday.day;
        })
        .toList(growable: false);
  }

  List<_CategoryStatData> _categoryStats(
    List<OrderModel> orders,
    List<MenuItem> menuItems,
  ) {
    final catById = <String, String>{
      for (final mi in menuItems)
        mi.id: mi.category.trim().isEmpty ? 'General' : mi.category.trim(),
    };
    final values = <String, _CategoryStatData>{};
    for (final order in orders) {
      if (order.status.adminStatus == OrderStatus.cancelled) continue;
      for (final item in order.items) {
        final cat = catById[item.menuItemId] ?? 'General';
        final current = values[cat];
        values[cat] = _CategoryStatData(
          name: cat,
          orders: (current?.orders ?? 0) + 1,
          sales: (current?.sales ?? 0) + item.lineTotal,
          qty: (current?.qty ?? 0) + item.qty,
        );
      }
    }
    final sorted = values.values.toList()
      ..sort((a, b) => b.sales.compareTo(a.sales));
    return sorted.take(6).toList(growable: false);
  }

  List<_TopItemData> _topItems(List<OrderModel> orders) {
    final values = <String, _TopItemData>{};
    for (final order in orders) {
      if (order.status.adminStatus == OrderStatus.cancelled) continue;
      for (final item in order.items) {
        final key = item.menuItemId.isEmpty ? item.name : item.menuItemId;
        final current = values[key];
        values[key] = _TopItemData(
          name: item.name,
          qty: (current?.qty ?? 0) + item.qty,
          sales: (current?.sales ?? 0) + item.lineTotal,
        );
      }
    }
    final sorted = values.values.toList()
      ..sort((a, b) => b.sales.compareTo(a.sales));
    return sorted.take(5).toList(growable: false);
  }

  Map<OrderSource, int> _sourceStats(List<OrderModel> orders) {
    final stats = <OrderSource, int>{
      for (final source in OrderSource.values) source: 0,
    };
    for (final order in orders) {
      if (order.status.adminStatus == OrderStatus.cancelled) continue;
      stats[order.source] = (stats[order.source] ?? 0) + 1;
    }
    return stats;
  }

  List<int> _hourlyStats(List<OrderModel> orders) {
    final buckets = List<int>.filled(12, 0);
    for (final order in orders) {
      if (order.status.adminStatus == OrderStatus.cancelled) continue;
      final hour = order.createdAt.toLocal().hour;
      final index = ((hour - 9).clamp(0, 11)).toInt();
      buckets[index]++;
    }
    return buckets;
  }

  List<InventoryItem> _inventoryAtRisk(List<InventoryItem> items) {
    final risk = items
        .where((item) => item.isOutOfStock || item.isLowStock)
        .toList(growable: false);
    risk.sort((a, b) {
      if (a.isOutOfStock != b.isOutOfStock) return a.isOutOfStock ? -1 : 1;
      return a.quantity.compareTo(b.quantity);
    });
    return risk.take(5).toList(growable: false);
  }

  int _activeTables(List<OrderModel> orders) {
    return orders
        .where(
          (order) =>
              order.status.isOpen && (order.tableNo ?? '').trim().isNotEmpty,
        )
        .map((order) => order.tableNo!.trim())
        .toSet()
        .length;
  }

  double _cancelRate(List<OrderModel> orders) {
    if (orders.isEmpty) return 0;
    final cancelled = orders
        .where((order) => order.status.adminStatus == OrderStatus.cancelled)
        .length;
    return (cancelled / orders.length) * 100;
  }

  String _peakHour(List<int> hourlyStats) {
    if (hourlyStats.isEmpty || hourlyStats.every((value) => value == 0)) {
      return 'No rush yet';
    }
    var maxIndex = 0;
    for (var i = 1; i < hourlyStats.length; i++) {
      if (hourlyStats[i] > hourlyStats[maxIndex]) maxIndex = i;
    }
    final hour = 9 + maxIndex;
    final labelHour = hour > 12 ? hour - 12 : hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$labelHour $period';
  }

  int _roleOrderCount(List<OrderModel> orders, String role) {
    return orders
        .where((order) => (order.createdByRole ?? '').toLowerCase() == role)
        .length;
  }

  int _staleOrders(List<OrderModel> orders) {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
    return orders
        .where((order) =>
            order.status.adminStatus == OrderStatus.pending &&
            order.createdAt.isBefore(cutoff))
        .length;
  }

  int _avgPrepMinutes(List<OrderModel> orders) {
    final served = orders
        .where((order) =>
            order.status.adminStatus == OrderStatus.served &&
            order.updatedAt.isAfter(order.createdAt))
        .toList(growable: false);
    if (served.isEmpty) return 0;
    final total = served.fold<int>(
      0,
      (sum, order) =>
          sum + order.updatedAt.difference(order.createdAt).inMinutes,
    );
    return (total / served.length).round();
  }

  _ServiceMixData _serviceMix(List<OrderModel> orders) {
    var dineIn = 0;
    var takeaway = 0;
    var dineInSales = 0.0;
    var takeawaySales = 0.0;
    for (final order in orders) {
      if (order.status.adminStatus == OrderStatus.cancelled) continue;
      final hasTable = (order.tableNo ?? '').trim().isNotEmpty;
      if (hasTable) {
        dineIn++;
        dineInSales += order.total;
      } else {
        takeaway++;
        takeawaySales += order.total;
      }
    }
    return _ServiceMixData(
      dineInOrders: dineIn,
      takeawayOrders: takeaway,
      dineInSales: dineInSales,
      takeawaySales: takeawaySales,
    );
  }

  List<_StaffRowData> _staffLeaderboard({
    required List<OrderModel> orders,
    required String currentAccountId,
    required String currentDisplayName,
  }) {
    final byAccount = <String, _StaffRowData>{};
    for (final order in orders) {
      if (order.status.adminStatus == OrderStatus.cancelled) continue;
      final id = (order.createdByAccountId ?? '').trim();
      if (id.isEmpty) continue;
      final role = (order.createdByRole ?? '').trim();
      final isCurrent = id == currentAccountId;
      final roleLabel = role.isEmpty
          ? 'Staff'
          : role[0].toUpperCase() + role.substring(1);
      final shortId = id.length > 6 ? id.substring(0, 6) : id;
      final name = isCurrent && currentDisplayName.isNotEmpty
          ? currentDisplayName
          : '$roleLabel · $shortId';
      final existing = byAccount[id];
      byAccount[id] = _StaffRowData(
        accountId: id,
        displayName: name,
        role: role,
        orders: (existing?.orders ?? 0) + 1,
        sales: (existing?.sales ?? 0) + order.total,
        isCurrent: isCurrent,
      );
    }
    final rows = byAccount.values.toList()
      ..sort((a, b) => b.sales.compareTo(a.sales));
    return rows.take(6).toList(growable: false);
  }
}

class _SalesHeroCard extends StatelessWidget {
  const _SalesHeroCard({
    required this.report,
    required this.todaySales,
    required this.currency,
  });

  final SalesReport report;
  final double todaySales;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final daily = report.dailyBreakdown;
    final values = daily.map<double>((day) => day.sales).toList();
    final yesterday = daily.length >= 2 ? daily[daily.length - 2].sales : 0.0;
    final deltaPct = yesterday <= 0
        ? 0.0
        : ((todaySales - yesterday) / yesterday) * 100;
    final positive = todaySales >= yesterday;

    return CompactSurface(
      color: PosColors.surfaceTinted,
      borderColor: PosColors.lineStrong,
      padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
      radius: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S SALES",
            style: TextStyle(
              color: PosColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'আজকের বিক্রি',
            style: TextStyle(
              color: PosColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currency.format(todaySales),
              style: TextStyle(
                color: PosColors.slate,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                height: 0.95,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (positive ? PosColors.success : PosColors.danger)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(PosRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      positive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: positive ? PosColors.success : PosColors.danger,
                      size: 10,
                    ),
                    SizedBox(width: 3),
                    Text(
                      '${positive ? '+' : ''}${deltaPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: positive ? PosColors.success : PosColors.danger,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 7),
              Text(
                'vs yesterday',
                style: TextStyle(
                  color: PosColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 13),
          RepaintBoundary(
            child: SizedBox(
              height: 66,
              width: double.infinity,
              child: CustomPaint(painter: _SalesLinePainter(values: values)),
            ),
          ),
          SizedBox(height: 3),
          _WeekDayAxis(report: report),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.orders,
    required this.ordersVsYesterday,
    required this.open,
    required this.avgTicket,
    required this.topItem,
    required this.currency,
    required this.onOpenOrders,
  });

  final int orders;
  final int ordersVsYesterday;
  final int open;
  final double avgTicket;
  final String topItem;
  final NumberFormat currency;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final vsLabel = ordersVsYesterday == 0
        ? '= same as yest.'
        : '${ordersVsYesterday > 0 ? '+' : ''}$ordersVsYesterday vs yest.';
    final metrics = [
      _MetricData('ORDERS', 'অর্ডার', orders.toString(), vsLabel),
      _MetricData('OPEN', 'চলমান', open.toString(), 'needs action'),
      _MetricData('AVG TICKET', 'গড় বিল', currency.format(avgTicket), '+৳22'),
      _MetricData('TOP ITEM', 'টপ আইটেম', topItem, 'today'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        return GridView.builder(
          itemCount: metrics.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 2 ? 1.42 : 1.55,
          ),
          itemBuilder: (context, index) {
            final item = metrics[index];
            return CompactSurface(
              padding: EdgeInsets.all(12),
              radius: 9,
              onTap: index <= 1 ? onOpenOrders : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PosColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    item.bnLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PosColors.muted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Spacer(),
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: index == 1 ? PosColors.primary : PosColors.slate,
                      fontSize: index == 3 ? 19 : 26,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    item.footer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: index == 0
                          ? (ordersVsYesterday >= 0
                              ? PosColors.success
                              : PosColors.danger)
                          : PosColors.success,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNewOrder,
    required this.onOpenReports,
    required this.onSync,
    required this.onOpenMenu,
    required this.onOpenStock,
  });

  final VoidCallback onNewOrder;
  final VoidCallback onOpenReports;
  final Future<bool> Function() onSync;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(Icons.add_rounded, 'Order', onNewOrder),
      _QuickAction(Icons.sync_rounded, 'Sync', () async => onSync()),
      _QuickAction(Icons.restaurant_menu_rounded, 'Menu', onOpenMenu),
      _QuickAction(Icons.inventory_2_outlined, 'Stock', onOpenStock),
      _QuickAction(Icons.assessment_outlined, 'Report', onOpenReports),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(
            child: Tooltip(
              message: actions[i].label,
              child: Material(
                color: PosColors.surface,
                borderRadius: BorderRadius.circular(9),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: actions[i].onTap,
                  child: SizedBox(
                    height: 42,
                    child: Icon(
                      actions[i].icon,
                      color: i == 0 ? PosColors.primary : PosColors.slate,
                      size: 17,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (i < actions.length - 1) SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ShiftCommandCenter extends StatelessWidget {
  const _ShiftCommandCenter({
    required this.pending,
    required this.inKitchen,
    required this.served,
    required this.cancelled,
    required this.activeTables,
    required this.totalTables,
    required this.cancelRate,
    required this.peakHourLabel,
    required this.staffOrders,
    required this.managerOrders,
    required this.staleOrders,
    required this.avgPrepMinutes,
  });

  final int pending;
  final int inKitchen;
  final int served;
  final int cancelled;
  final int activeTables;
  final int totalTables;
  final double cancelRate;
  final String peakHourLabel;
  final int staffOrders;
  final int managerOrders;
  final int staleOrders;
  final int avgPrepMinutes;

  @override
  Widget build(BuildContext context) {
    return CompactSurface(
      padding: EdgeInsets.all(14),
      radius: 9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Shift command',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              _TinyPill(
                icon: Icons.table_restaurant_outlined,
                label: '$activeTables/${totalTables.clamp(1, 999)} tables',
                color: PosColors.info,
              ),
            ],
          ),
          SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final items = [
                _CommandData(
                  'Pending',
                  pending.toString(),
                  Icons.notifications_active_outlined,
                  PosColors.warning,
                ),
                _CommandData(
                  'Kitchen',
                  inKitchen.toString(),
                  Icons.soup_kitchen_outlined,
                  PosColors.primary,
                ),
                _CommandData(
                  'Served',
                  served.toString(),
                  Icons.check_circle_outline_rounded,
                  PosColors.success,
                ),
                _CommandData(
                  'Cancelled',
                  cancelled.toString(),
                  Icons.cancel_outlined,
                  PosColors.danger,
                ),
              ];
              return GridView.builder(
                itemCount: items.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: compact ? 2 : 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: compact ? 1.9 : 2.05,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _CommandTile(item: item);
                },
              );
            },
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyPill(
                icon: Icons.trending_up_rounded,
                label: 'Peak $peakHourLabel',
                color: PosColors.primary,
              ),
              _TinyPill(
                icon: Icons.percent_rounded,
                label: 'Cancel ${cancelRate.toStringAsFixed(1)}%',
                color: cancelRate > 8 ? PosColors.danger : PosColors.success,
              ),
              _TinyPill(
                icon: Icons.badge_outlined,
                label: 'Staff $staffOrders',
                color: PosColors.info,
              ),
              _TinyPill(
                icon: Icons.manage_accounts_outlined,
                label: 'Manager $managerOrders',
                color: PosColors.purple,
              ),
              _TinyPill(
                icon: Icons.timer_outlined,
                label: avgPrepMinutes == 0
                    ? 'Prep —'
                    : 'Prep ${avgPrepMinutes}m',
                color: avgPrepMinutes > 25
                    ? PosColors.danger
                    : PosColors.success,
              ),
              _TinyPill(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Stale $staleOrders',
                color: staleOrders > 0
                    ? PosColors.danger
                    : PosColors.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightGrid extends StatelessWidget {
  const _InsightGrid({
    required this.currency,
    required this.sourceStats,
    required this.hourlyStats,
    required this.topItems,
    required this.stockValue,
    required this.totalOrders,
    required this.categoryStats,
  });

  final NumberFormat currency;
  final Map<OrderSource, int> sourceStats;
  final List<int> hourlyStats;
  final List<_TopItemData> topItems;
  final double stockValue;
  final int totalOrders;
  final List<_CategoryStatData> categoryStats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 780;
        final children = [
          _SourceMixCard(stats: sourceStats, totalOrders: totalOrders),
          _HourlyDemandCard(values: hourlyStats),
          _TopItemsCard(items: topItems, currency: currency),
          _CashStockCard(stockValue: stockValue, currency: currency),
          _CategoryBreakdownCard(stats: categoryStats, currency: currency),
        ];
        if (!wide) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                SizedBox(height: 172, child: children[i]),
                if (i < children.length - 1) SizedBox(height: 8),
              ],
            ],
          );
        }
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: children.length.isOdd ? 1.95 : 2.05,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _SourceMixCard extends StatelessWidget {
  const _SourceMixCard({required this.stats, required this.totalOrders});

  final Map<OrderSource, int> stats;
  final int totalOrders;

  @override
  Widget build(BuildContext context) {
    final sources = OrderSource.values
        .where((source) => (stats[source] ?? 0) > 0)
        .toList(growable: false);
    return _DashboardPanel(
      title: 'Order channels',
      icon: Icons.hub_outlined,
      child: sources.isEmpty
          ? _EmptyMiniText('No orders by channel yet.')
          : Column(
              children: [
                for (final source in sources)
                  _ProgressRow(
                    label: source.label,
                    value: stats[source] ?? 0,
                    total: totalOrders.clamp(1, 999999),
                    color: source == OrderSource.manual
                        ? PosColors.primary
                        : PosColors.info,
                  ),
              ],
            ),
    );
  }
}

class _HourlyDemandCard extends StatelessWidget {
  const _HourlyDemandCard({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 1 : values.reduce(math.max).clamp(1, 999);
    return _DashboardPanel(
      title: 'Hourly demand',
      icon: Icons.query_stats_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  Expanded(
                    child: Tooltip(
                      message: '${9 + i}:00 · ${values[i]} orders',
                      child: FractionallySizedBox(
                        heightFactor: values[i] / maxValue,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          constraints: BoxConstraints(minHeight: 4),
                          decoration: BoxDecoration(
                            color: values[i] == maxValue
                                ? PosColors.primary
                                : PosColors.primarySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (i < values.length - 1) SizedBox(width: 4),
                ],
              ],
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _AxisLabel('9'),
              Spacer(),
              _AxisLabel('12'),
              Spacer(),
              _AxisLabel('3'),
              Spacer(),
              _AxisLabel('8'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopItemsCard extends StatelessWidget {
  const _TopItemsCard({required this.items, required this.currency});

  final List<_TopItemData> items;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Best sellers',
      icon: Icons.local_fire_department_outlined,
      child: items.isEmpty
          ? _EmptyMiniText('No sales mix for today.')
          : Column(
              children: [
                for (final item in items.take(4))
                  Padding(
                    padding: EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${item.qty} · ${currency.format(item.sales)}',
                          style: TextStyle(
                            color: PosColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CashStockCard extends StatelessWidget {
  const _CashStockCard({required this.stockValue, required this.currency});

  final double stockValue;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Stock value',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currency.format(stockValue),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estimated inventory at current unit cost.',
            style: TextStyle(
              color: PosColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryWatchlist extends StatelessWidget {
  const _InventoryWatchlist({required this.items, required this.onOpenStock});

  final List<InventoryItem> items;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    return CompactSurface(
      padding: EdgeInsets.all(14),
      radius: 9,
      onTap: onOpenStock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Inventory watchlist',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: PosColors.muted),
            ],
          ),
          SizedBox(height: 8),
          if (items.isEmpty)
            _EmptyMiniText('Stock is healthy. No low-stock alerts.')
          else
            ...items.map((item) {
              final color = item.isOutOfStock
                  ? PosColors.danger
                  : PosColors.warning;
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      item.isOutOfStock
                          ? Icons.error_outline_rounded
                          : Icons.warning_amber_rounded,
                      color: color,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CompactSurface(
      padding: EdgeInsets.all(13),
      radius: 9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PosColors.primary, size: 17),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          SizedBox(height: 11),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.only(bottom: 9),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  color: PosColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: PosColors.background,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.item});

  final _CommandData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: item.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  item.value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMiniText extends StatelessWidget {
  const _EmptyMiniText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: PosColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SalesLinePainter extends CustomPainter {
  _SalesLinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final usableValues = values.length >= 2
        ? values
        : const [8000.0, 12000.0, 9000.0, 17000.0, 15000.0, 21000.0, 24000.0];
    final minValue = usableValues.reduce(math.min);
    final maxValue = usableValues.reduce(math.max);
    final range = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : maxValue - minValue;
    final chartHeight = size.height - 10;
    final step = size.width / (usableValues.length - 1);
    final points = <Offset>[];
    for (var i = 0; i < usableValues.length; i++) {
      final normalized = (usableValues[i] - minValue) / range;
      points.add(
        Offset(i * step, chartHeight - (normalized * (chartHeight - 7)) + 3),
      );
    }

    final gridPaint = Paint()
      ..color = PosColors.lineStrong
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 4),
      Offset(size.width, size.height - 4),
      gridPaint,
    );

    final fill = Path()..moveTo(points.first.dx, size.height - 4);
    for (final point in points) {
      fill.lineTo(point.dx, point.dy);
    }
    fill.lineTo(points.last.dx, size.height - 4);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()..color = PosColors.primary.withValues(alpha: 0.08),
    );

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final midX = (prev.dx + current.dx) / 2;
      line.cubicTo(midX, prev.dy, midX, current.dy, current.dx, current.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = PosColors.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SalesLinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: PosColors.mutedSoft,
        fontSize: 8,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Axis row showing short day names (Mon, Tue…) aligned under the 7-day
/// sales chart in _SalesHeroCard.
class _WeekDayAxis extends StatelessWidget {
  const _WeekDayAxis({required this.report});

  final SalesReport report;

  static const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final days = report.dailyBreakdown;
    if (days.length < 2) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const Spacer(),
          _AxisLabel(
            i == days.length - 1
                ? 'Today'
                : _dayAbbr[(days[i].date.weekday - 1) % 7],
          ),
        ],
      ],
    );
  }
}

/// Compact pill row: 7-day total  |  30-day total with trend arrow.
class _RevenuePeriodRow extends StatelessWidget {
  const _RevenuePeriodRow({
    required this.sevenDaySales,
    required this.thirtyDaySales,
    required this.currency,
  });

  final double sevenDaySales;
  final double thirtyDaySales;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PeriodPill(
            label: '7-DAY',
            bnLabel: '৭ দিন',
            value: currency.format(sevenDaySales),
            color: PosColors.info,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PeriodPill(
            label: '30-DAY',
            bnLabel: '৩০ দিন',
            value: currency.format(thirtyDaySales),
            color: PosColors.purple,
          ),
        ),
      ],
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.bnLabel,
    required this.value,
    required this.color,
  });

  final String label;
  final String bnLabel;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                bnLabel,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: PosColors.slate,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows revenue breakdown by menu category (top N).
class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.stats,
    required this.currency,
  });

  final List<_CategoryStatData> stats;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final totalSales = stats.fold<double>(0, (sum, s) => sum + s.sales);
    return _DashboardPanel(
      title: 'Category sales',
      icon: Icons.category_outlined,
      child: stats.isEmpty
          ? const _EmptyMiniText('No category data yet today.')
          : Column(
              children: [
                for (final stat in stats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stat.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              currency.format(stat.sales),
                              style: TextStyle(
                                color: PosColors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalSales <= 0
                                ? 0
                                : (stat.sales / totalSales).clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: PosColors.background,
                            color: PosColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({
    required this.pending,
    required this.accepted,
    required this.lowStock,
    required this.unavailable,
    required this.syncPending,
    required this.printerReady,
    required this.staleOrders,
  });

  final int pending;
  final int accepted;
  final int lowStock;
  final int unavailable;
  final int syncPending;
  final bool printerReady;
  final int staleOrders;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _OpsRow(Icons.pending_actions_rounded, 'Pending orders', '$pending'),
      _OpsRow(Icons.room_service_rounded, 'In preparation', '$accepted'),
      _OpsRow(
        Icons.hourglass_bottom_rounded,
        'Stale (>15 min)',
        '$staleOrders',
      ),
      _OpsRow(Icons.inventory_2_outlined, 'Low stock alerts', '$lowStock'),
      _OpsRow(
        Icons.no_meals_outlined,
        'Unavailable menu items',
        '$unavailable',
      ),
      _OpsRow(Icons.cloud_sync_rounded, 'Waiting to sync', '$syncPending'),
      _OpsRow(
        printerReady ? Icons.print_rounded : Icons.print_disabled_outlined,
        'Printer',
        printerReady ? 'Ready' : 'Not ready',
      ),
    ];
    return CompactSurface(
      padding: EdgeInsets.all(14),
      radius: 9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 680 ? 3 : 2;
              return GridView.builder(
                itemCount: rows.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: columns == 3 ? 2.75 : 2.15,
                ),
                itemBuilder: (context, index) => rows[index],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OpsRow extends StatelessWidget {
  const _OpsRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: PosColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          SizedBox(width: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.orders});

  final List<OrderModel> orders;

  @override
  Widget build(BuildContext context) {
    return CompactSurface(
      padding: EdgeInsets.all(14),
      radius: 9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent orders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          if (orders.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('No orders yet today.')),
            )
          else
            ...orders.map((order) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: PosColors.primarySoft,
                  child: Text(
                    order.sequenceNo > 0 ? '${order.sequenceNo}' : '-',
                    style: TextStyle(
                      color: PosColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  '${order.items.length} items · ৳${order.total.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${order.status.label} · ${order.source.label} · ${DateFormat('HH:mm').format(order.createdAt)}',
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ServiceMixCard extends StatelessWidget {
  const _ServiceMixCard({required this.mix, required this.currency});

  final _ServiceMixData mix;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final total = mix.dineInOrders + mix.takeawayOrders;
    final dineInPct = total == 0
        ? 0.0
        : (mix.dineInOrders / total) * 100;
    final takeawayPct = total == 0
        ? 0.0
        : (mix.takeawayOrders / total) * 100;
    return CompactSurface(
      padding: EdgeInsets.all(14),
      radius: 9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dining_outlined, color: PosColors.primary, size: 17),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Service mix',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'today',
                style: TextStyle(
                  color: PosColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ServiceMixTile(
                  icon: Icons.table_restaurant_outlined,
                  label: 'Dine-in',
                  orders: mix.dineInOrders,
                  sales: mix.dineInSales,
                  pct: dineInPct,
                  color: PosColors.primary,
                  currency: currency,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ServiceMixTile(
                  icon: Icons.takeout_dining_outlined,
                  label: 'Takeaway',
                  orders: mix.takeawayOrders,
                  sales: mix.takeawaySales,
                  pct: takeawayPct,
                  color: PosColors.info,
                  currency: currency,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceMixTile extends StatelessWidget {
  const _ServiceMixTile({
    required this.icon,
    required this.label,
    required this.orders,
    required this.sales,
    required this.pct,
    required this.color,
    required this.currency,
  });

  final IconData icon;
  final String label;
  final int orders;
  final double sales;
  final double pct;
  final Color color;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: PosColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '$orders',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 2),
          Text(
            '${currency.format(sales)} · ${pct.toStringAsFixed(0)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PosColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffLeaderboard extends StatelessWidget {
  const _StaffLeaderboard({required this.rows, required this.currency});

  final List<_StaffRowData> rows;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final maxSales = rows.isEmpty
        ? 1.0
        : rows.map((row) => row.sales).reduce(math.max).clamp(1, 1e12);
    return CompactSurface(
      padding: EdgeInsets.all(14),
      radius: 9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: PosColors.primary,
                size: 17,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Staff leaderboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'sales today',
                style: TextStyle(
                  color: PosColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No tracked orders yet today.',
                style: TextStyle(
                  color: PosColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: row.isCurrent
                            ? PosColors.primary
                            : PosColors.primarySoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: row.isCurrent
                              ? Colors.white
                              : PosColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (row.sales / maxSales).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: PosColors.background,
                              color: row.role.toLowerCase() == 'manager'
                                  ? PosColors.purple
                                  : PosColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currency.format(row.sales),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${row.orders} orders',
                          style: TextStyle(
                            color: PosColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ServiceMixData {
  const _ServiceMixData({
    required this.dineInOrders,
    required this.takeawayOrders,
    required this.dineInSales,
    required this.takeawaySales,
  });

  final int dineInOrders;
  final int takeawayOrders;
  final double dineInSales;
  final double takeawaySales;
}

class _StaffRowData {
  const _StaffRowData({
    required this.accountId,
    required this.displayName,
    required this.role,
    required this.orders,
    required this.sales,
    required this.isCurrent,
  });

  final String accountId;
  final String displayName;
  final String role;
  final int orders;
  final double sales;
  final bool isCurrent;
}

class _MetricData {
  const _MetricData(this.label, this.bnLabel, this.value, this.footer);

  final String label;
  final String bnLabel;
  final String value;
  final String footer;
}

class _TopItemData {
  const _TopItemData({
    required this.name,
    required this.qty,
    required this.sales,
  });

  final String name;
  final int qty;
  final double sales;
}

class _CommandData {
  const _CommandData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _QuickAction {
  const _QuickAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _CategoryStatData {
  const _CategoryStatData({
    required this.name,
    required this.orders,
    required this.sales,
    required this.qty,
  });

  final String name;
  final int orders;
  final double sales;
  final int qty;
}
