import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/models/analytics_summary_data.dart';

void main() {
  test('parses a complete analytics summary payload', () {
    final data = AnalyticsSummaryData.fromJson({
      'salesSummary': {
        'ordersCompleted': 3,
        'grossSales': 1200,
        'discountByStaff': 50,
        'netSales': 1150,
      },
      'totalCollection': 1190,
      'discountAndCommission': 50,
      'otherIncome': 40,
      'taxAndDuty': 20,
      'collection': [
        {'key': 'cash', 'label': 'Cash', 'valueBdt': 900},
      ],
      'serviceWise': [
        {'key': 'dineIn', 'label': 'Dine-in', 'valueBdt': 1200},
      ],
      'profit': {
        'netSales': 1150,
        'serviceCharge': 10,
        'deliveryCharge': 30,
        'preparationCost': 400,
        'wastage': 20,
        'paymentFee': 5,
        'taxes': 20,
        'grossProfit': 745,
      },
      'popularDishes': [
        {'name': 'Rice', 'salesBdt': 700},
      ],
      'itemWise': [
        {
          'category': 'Main',
          'units': 2,
          'totalPrice': 700,
          'items': [
            {
              'menuItemId': 'm1',
              'name': 'Rice',
              'units': 2,
              'avgUnitPrice': 350,
              'totalPrice': 700,
            },
          ],
        },
      ],
      'trend': [
        {'date': '2026-06-26', 'revenue': 1190, 'orders': 3},
      ],
    });

    expect(data.ordersCompleted, 3);
    expect(data.grossSales, 1200);
    expect(data.netSales, 1150);
    expect(data.collection.single.label, 'Cash');
    expect(data.itemWise.single.items.single.menuItemId, 'm1');
    expect(data.hasNoData, isFalse);
    expect(data.diagnosticSummary, contains('ordersCompleted=3'));
  });

  test('tolerates missing optional sections and reports missing keys', () {
    final data = AnalyticsSummaryData.fromJson({
      'salesSummary': {'ordersCompleted': 0},
      'totalCollection': 0,
    });

    expect(data.collection, isEmpty);
    expect(data.serviceWise, isEmpty);
    expect(data.profit.grossProfit, 0);
    expect(data.missingKeys, contains('collection'));
    expect(data.hasNoData, isTrue);
  });

  test('parses numeric strings and parenthesized money values', () {
    final data = AnalyticsSummaryData.fromJson({
      'salesSummary': {
        'ordersCompleted': '2',
        'grossSales': '৳1,200.50',
        'discountByStaff': '(৳50.25)',
        'netSales': '1,150.25',
      },
      'totalCollection': '1,150.25',
      'collection': [
        {'label': 'Cash', 'valueBdt': '1,150.25'},
      ],
    });

    expect(data.ordersCompleted, 2);
    expect(data.grossSales, 1200.5);
    expect(data.discountByStaff, -50.25);
    expect(data.collection.single.value, 1150.25);
    expect(data.hasNoData, isFalse);
  });

  test('does not hide non-empty totals just because itemWise is empty', () {
    final data = AnalyticsSummaryData.fromJson({
      'salesSummary': {'ordersCompleted': 0, 'grossSales': 0, 'netSales': 0},
      'totalCollection': 42,
      'itemWise': [],
    });

    expect(data.itemWise, isEmpty);
    expect(data.hasNoData, isFalse);
  });
}
