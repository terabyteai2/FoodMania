import '../../models/order_model.dart';
import '../../models/order_source.dart';

/// Preset date windows for the orders list.
enum OrderDateRange {
  all,
  today,
  yesterday,
  last7Days,
  last30Days,
  last3Months,
  last6Months,
  last12Months,
}

/// Filters applied on the orders screen (date + channel).
class OrderListFilters {
  const OrderListFilters({this.dateRange = OrderDateRange.all, this.source});

  final OrderDateRange dateRange;
  final OrderSource? source;

  bool get isActive => dateRange != OrderDateRange.all || source != null;

  OrderListFilters copyWith({
    OrderDateRange? dateRange,
    OrderSource? source,
    bool clearSource = false,
  }) {
    return OrderListFilters(
      dateRange: dateRange ?? this.dateRange,
      source: clearSource ? null : (source ?? this.source),
    );
  }

  static const OrderListFilters none = OrderListFilters();

  /// Inclusive start (local calendar), exclusive end for [OrderModel.createdAt].
  ({DateTime? startInclusive, DateTime? endExclusive}) boundsFor(DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (dateRange) {
      case OrderDateRange.all:
        return (startInclusive: null, endExclusive: null);
      case OrderDateRange.today:
        return (startInclusive: startOfToday, endExclusive: null);
      case OrderDateRange.yesterday:
        return (
          startInclusive: startOfToday.subtract(const Duration(days: 1)),
          endExclusive: startOfToday,
        );
      case OrderDateRange.last7Days:
        return (
          startInclusive: startOfToday.subtract(const Duration(days: 6)),
          endExclusive: null,
        );
      case OrderDateRange.last30Days:
        return (
          startInclusive: startOfToday.subtract(const Duration(days: 29)),
          endExclusive: null,
        );
      case OrderDateRange.last3Months:
        return (
          startInclusive: _subtractCalendarMonths(startOfToday, 3),
          endExclusive: null,
        );
      case OrderDateRange.last6Months:
        return (
          startInclusive: _subtractCalendarMonths(startOfToday, 6),
          endExclusive: null,
        );
      case OrderDateRange.last12Months:
        return (
          startInclusive: _subtractCalendarMonths(startOfToday, 12),
          endExclusive: null,
        );
    }
  }

  bool matches(OrderModel order, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final bounds = boundsFor(clock);
    final at = order.createdAt.toLocal();
    if (bounds.startInclusive != null && at.isBefore(bounds.startInclusive!)) {
      return false;
    }
    if (bounds.endExclusive != null && !at.isBefore(bounds.endExclusive!)) {
      return false;
    }
    if (source != null && order.source != source) return false;
    return true;
  }

  static DateTime _subtractCalendarMonths(DateTime date, int months) {
    var year = date.year;
    var month = date.month - months;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;
    return DateTime(year, month, day);
  }
}
