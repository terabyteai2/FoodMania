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

  static bool _inBounds(DateTime at,
      ({DateTime? startInclusive, DateTime? endExclusive}) bounds) {
    if (bounds.startInclusive != null && at.isBefore(bounds.startInclusive!)) {
      return false;
    }
    if (bounds.endExclusive != null && !at.isBefore(bounds.endExclusive!)) {
      return false;
    }
    return true;
  }

  bool matches(OrderModel order, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final bounds = boundsFor(clock);
    final at = order.createdAt.toLocal();
    if (!_inBounds(at, bounds)) return false;
    if (source != null && order.source != source) return false;
    return true;
  }

  /// Window for the completed-orders "shift" scope, keyed on local
  /// [OrderModel.createdAt]. With no shift configured (both minutes null) it
  /// falls back to the whole of today (local midnight onwards, no end bound).
  /// The window is anchored to the *running* shift: if [now] is before
  /// today's [startMinute] the shift actually began yesterday (a store open
  /// 10:00–02:00 is still the previous shift at 01:30). When [endMinute] is
  /// at or before [startMinute] the shift wraps past midnight into the next
  /// calendar day; equal minutes mean a full 24h shift.
  static ({DateTime? startInclusive, DateTime? endExclusive}) shiftBoundsFor(
    DateTime now, {
    int? startMinute,
    int? endMinute,
  }) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    if (startMinute == null) {
      return (startInclusive: startOfToday, endExclusive: null);
    }
    final startMinutes = startMinute.clamp(0, 1439);
    final anchorDay = anchorDayFor(now, startMinute);
    final start = anchorDay.add(Duration(minutes: startMinutes));
    if (endMinute == null) {
      return (startInclusive: start, endExclusive: null);
    }
    final endMinutes = endMinute.clamp(0, 1439);
    final end = endMinutes <= startMinutes
        ? anchorDay
            .add(const Duration(days: 1))
            .add(Duration(minutes: endMinutes))
        : anchorDay.add(Duration(minutes: endMinutes));
    return (startInclusive: start, endExclusive: end);
  }

  /// Calendar date of the shift that [at] falls into: the shift opened at
  /// [startMinute] on that date, so an order after midnight (before the open
  /// hour) belongs to the previous day's shift.
  static DateTime shiftDayFor(DateTime at, int startMinute) {
    final day = DateTime(at.year, at.month, at.day);
    final atMinutes = at.hour * 60 + at.minute;
    return atMinutes < startMinute.clamp(0, 1439)
        ? day.subtract(const Duration(days: 1))
        : day;
  }

  /// The calendar day on which the running shift opened, given the time now.
  static DateTime anchorDayFor(DateTime now, int startMinute) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes < startMinute.clamp(0, 1439)
        ? startOfToday.subtract(const Duration(days: 1))
        : startOfToday;
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
