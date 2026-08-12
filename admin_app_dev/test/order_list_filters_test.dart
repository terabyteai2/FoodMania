import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/features/orders/order_list_filters.dart';

void main() {
  group('OrderListFilters.shiftBoundsFor', () {
    final noon = DateTime(2026, 8, 11, 13, 0);

    test('no shift configured falls back to today from local midnight', () {
      final bounds = OrderListFilters.shiftBoundsFor(
        noon,
        startMinute: null,
        endMinute: null,
      );
      expect(bounds.startInclusive, DateTime(2026, 8, 11));
      expect(bounds.endExclusive, isNull);
    });

    test('start only opens today at that hour with no end bound', () {
      final bounds = OrderListFilters.shiftBoundsFor(
        noon,
        startMinute: 10 * 60,
        endMinute: null,
      );
      expect(bounds.startInclusive, DateTime(2026, 8, 11, 10));
      expect(bounds.endExclusive, isNull);
    });

    test('end after start stays on the same day', () {
      final bounds = OrderListFilters.shiftBoundsFor(
        noon,
        startMinute: 9 * 60,
        endMinute: 17 * 60,
      );
      expect(bounds.startInclusive, DateTime(2026, 8, 11, 9));
      expect(bounds.endExclusive, DateTime(2026, 8, 11, 17));
    });

    test('end before start wraps into the next day', () {
      final bounds = OrderListFilters.shiftBoundsFor(
        noon,
        startMinute: 10 * 60,
        endMinute: 2 * 60,
      );
      expect(bounds.startInclusive, DateTime(2026, 8, 11, 10));
      expect(bounds.endExclusive, DateTime(2026, 8, 12, 2));
    });

    test('before the start hour the running shift anchored on yesterday', () {
      final justAfterMidnight = DateTime(2026, 8, 11, 1, 30);
      final bounds = OrderListFilters.shiftBoundsFor(
        justAfterMidnight,
        startMinute: 10 * 60,
        endMinute: 2 * 60,
      );
      expect(bounds.startInclusive, DateTime(2026, 8, 10, 10));
      expect(bounds.endExclusive, DateTime(2026, 8, 11, 2));
    });

    test('exactly at the start hour anchors on today', () {
      final atStart = DateTime(2026, 8, 11, 10, 0);
      final bounds = OrderListFilters.shiftBoundsFor(
        atStart,
        startMinute: 10 * 60,
        endMinute: 2 * 60,
      );
      expect(bounds.startInclusive, DateTime(2026, 8, 11, 10));
      expect(bounds.endExclusive, DateTime(2026, 8, 12, 2));
    });

    test('equal start and end cover a full 24 hours', () {
      final bounds = OrderListFilters.shiftBoundsFor(
        noon,
        startMinute: 0,
        endMinute: 0,
      );
      expect(bounds.startInclusive, DateTime(2026, 8, 11));
      expect(bounds.endExclusive, DateTime(2026, 8, 12));
    });

    test('minutes are clamped to a valid day', () {
      final bounds = OrderListFilters.shiftBoundsFor(
        noon,
        startMinute: 60 * 30,
        endMinute: -5,
      );
      expect(bounds.startInclusive, DateTime(2026, 8, 10, 23, 59));
      expect(bounds.endExclusive, DateTime(2026, 8, 11));
    });
  });
}