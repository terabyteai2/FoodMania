class DashboardMetrics {
  DashboardMetrics({
    required this.todayOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.totalSales,
    required this.sevenDaySales,
    required this.thirtyDaySales,
    required this.menuItemsCount,
    required this.availableItemsCount,
    required this.pendingSyncCount,
  });

  final int todayOrders;
  final int pendingOrders;
  final int completedOrders;
  final double totalSales;
  final double sevenDaySales;
  final double thirtyDaySales;
  final int menuItemsCount;
  final int availableItemsCount;
  final int pendingSyncCount;
}
