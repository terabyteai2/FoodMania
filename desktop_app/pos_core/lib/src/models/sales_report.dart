import 'order_model.dart';

class SalesReport {
  SalesReport({
    required this.title,
    required this.days,
    required this.startAt,
    required this.endAt,
    required this.totalOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.openOrders,
    required this.totalSales,
    required this.averageOrderValue,
    required this.totalItemsSold,
    required this.topItems,
    required this.dailyBreakdown,
  });

  final String title;
  final int days;
  final DateTime startAt;
  final DateTime endAt;
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int openOrders;
  final double totalSales;
  final double averageOrderValue;
  final int totalItemsSold;
  final List<SalesItemSummary> topItems;
  final List<SalesDailySummary> dailyBreakdown;

  factory SalesReport.fromOrders({
    required List<OrderModel> orders,
    required int days,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final todayStart = DateTime(current.year, current.month, current.day);
    final startAt = todayStart.subtract(Duration(days: days - 1));
    final endAt = todayStart.add(Duration(days: 1));
    final scoped = orders
        .where(
          (order) =>
              !order.createdAt.isBefore(startAt) &&
              order.createdAt.isBefore(endAt),
        )
        .toList(growable: false);
    final revenueOrders = scoped
        .where((order) => !order.status.isRejected)
        .toList(growable: false);
    final totalSales = revenueOrders.fold<double>(
      0,
      (total, order) => total + order.total,
    );
    final topItems = _topItems(revenueOrders);
    return SalesReport(
      title: days == 1 ? 'Today Sales Report' : 'Last $days Days Sales Report',
      days: days,
      startAt: startAt,
      endAt: endAt,
      totalOrders: scoped.length,
      completedOrders: scoped.where((order) => order.status.isCompleted).length,
      cancelledOrders: scoped.where((order) => order.status.isRejected).length,
      openOrders: scoped.where((order) => order.status.isOpen).length,
      totalSales: totalSales,
      averageOrderValue: revenueOrders.isEmpty
          ? 0
          : totalSales / revenueOrders.length,
      totalItemsSold: topItems.fold<int>(0, (total, item) => total + item.qty),
      topItems: topItems,
      dailyBreakdown: _dailyBreakdown(revenueOrders, startAt, days),
    );
  }

  static List<SalesItemSummary> _topItems(List<OrderModel> orders) {
    final values = <String, SalesItemSummary>{};
    for (final order in orders) {
      for (final item in order.items) {
        final current = values[item.menuItemId];
        values[item.menuItemId] = SalesItemSummary(
          menuItemId: item.menuItemId,
          name: item.name,
          qty: (current?.qty ?? 0) + item.qty,
          sales: (current?.sales ?? 0) + item.lineTotal,
        );
      }
    }
    final sorted = values.values.toList()
      ..sort((a, b) => b.sales.compareTo(a.sales));
    return sorted.take(8).toList(growable: false);
  }

  static List<SalesDailySummary> _dailyBreakdown(
    List<OrderModel> orders,
    DateTime startAt,
    int days,
  ) {
    final values = <DateTime, SalesDailySummary>{
      for (var index = 0; index < days; index++)
        startAt.add(Duration(days: index)): SalesDailySummary(
          date: startAt.add(Duration(days: index)),
          orders: 0,
          sales: 0,
        ),
    };
    for (final order in orders) {
      final day = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
      final current = values[day];
      if (current == null) continue;
      values[day] = SalesDailySummary(
        date: day,
        orders: current.orders + 1,
        sales: current.sales + order.total,
      );
    }
    return values.values.toList(growable: false);
  }
}

class SalesItemSummary {
  SalesItemSummary({
    required this.menuItemId,
    required this.name,
    required this.qty,
    required this.sales,
  });

  final String menuItemId;
  final String name;
  final int qty;
  final double sales;
}

class SalesDailySummary {
  SalesDailySummary({
    required this.date,
    required this.orders,
    required this.sales,
  });

  final DateTime date;
  final int orders;
  final double sales;
}
