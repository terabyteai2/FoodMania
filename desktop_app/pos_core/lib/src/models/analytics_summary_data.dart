class AnalyticsSummaryData {
  AnalyticsSummaryData({
    required this.ordersCompleted,
    required this.grossSales,
    required this.discountByStaff,
    required this.netSales,
    required this.totalCollection,
    required this.collection,
    required this.serviceWise,
    required this.profit,
    required this.popular,
    required this.itemWise,
    required this.trend,
    required this.discountAndCommission,
    required this.otherIncome,
    required this.taxAndDuty,
    required this.rawKeys,
    required this.missingKeys,
    this.dueReceivable,
    this.duePaid,
  });

  final int ordersCompleted;
  final double grossSales;
  final double discountByStaff;
  final double netSales;
  final double totalCollection;
  final List<AnalyticsMoneyRow> collection;
  final List<AnalyticsMoneyRow> serviceWise;
  final AnalyticsProfitSummary profit;
  final List<AnalyticsDish> popular;
  final List<AnalyticsItemCategory> itemWise;
  final List<AnalyticsTrendPoint> trend;
  final double discountAndCommission;
  final double otherIncome;
  final double taxAndDuty;
  final double? dueReceivable;
  final double? duePaid;
  final List<String> rawKeys;
  final List<String> missingKeys;

  bool get hasNoData {
    final collectionTotal = collection.fold<double>(
      0,
      (sum, row) => sum + row.value.abs(),
    );
    return ordersCompleted == 0 &&
        grossSales == 0 &&
        netSales == 0 &&
        totalCollection == 0 &&
        collectionTotal == 0 &&
        itemWise.isEmpty;
  }

  String get diagnosticSummary {
    final missing = missingKeys.isEmpty ? 'none' : missingKeys.join(',');
    return [
      'keys=${rawKeys.join(",")}',
      'missing=$missing',
      'ordersCompleted=$ordersCompleted',
      'grossSales=$grossSales',
      'netSales=$netSales',
      'totalCollection=$totalCollection',
      'collection=${collection.length}',
      'serviceWise=${serviceWise.length}',
      'popularDishes=${popular.length}',
      'itemWise=${itemWise.length}',
      'trend=${trend.length}',
      'hasNoData=$hasNoData',
    ].join(' ');
  }

  factory AnalyticsSummaryData.fromJson(Map<String, Object?> json) {
    final rawKeys = json.keys.map((key) => key.toString()).toList()..sort();
    const expectedKeys = [
      'salesSummary',
      'totalCollection',
      'collection',
      'serviceWise',
      'profit',
      'popularDishes',
      'itemWise',
    ];
    final missingKeys = [
      for (final key in expectedKeys)
        if (!json.containsKey(key)) key,
    ];
    final summary = _map(json['salesSummary']);
    final profit = _map(json['profit']);

    return AnalyticsSummaryData(
      ordersCompleted: _i(summary['ordersCompleted']),
      grossSales: _d(summary['grossSales']),
      discountByStaff: _d(summary['discountByStaff']),
      netSales: _d(summary['netSales']),
      totalCollection: _d(json['totalCollection']),
      collection: _moneyRows(json['collection']),
      serviceWise: _moneyRows(json['serviceWise']),
      profit: AnalyticsProfitSummary(
        netSales: _d(profit['netSales']),
        serviceCharge: _d(profit['serviceCharge']),
        deliveryCharge: _d(profit['deliveryCharge']),
        preparationCost: _d(profit['preparationCost']),
        wastage: _d(profit['wastage']),
        paymentFee: _d(profit['paymentFee']),
        taxes: _d(profit['taxes']),
        grossProfit: _d(profit['grossProfit']),
      ),
      popular: _list(json['popularDishes'])
          .map(
            (m) => AnalyticsDish(
              name: (m['name'] ?? '').toString(),
              salesBdt: _d(m['salesBdt']),
            ),
          )
          .toList(growable: false),
      itemWise: _list(json['itemWise'])
          .map(
            (c) => AnalyticsItemCategory(
              category: (c['category'] ?? '').toString(),
              units: _i(c['units']),
              totalPrice: _d(c['totalPrice']),
              items: _list(c['items'])
                  .map(
                    (i) => AnalyticsSummaryItem(
                      menuItemId: (i['menuItemId'] ?? '').toString(),
                      name: (i['name'] ?? '').toString(),
                      units: _i(i['units']),
                      avgUnitPrice: _d(i['avgUnitPrice']),
                      totalPrice: _d(i['totalPrice']),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      trend: _list(json['trend'])
          .map(
            (m) => AnalyticsTrendPoint(
              date: (m['date'] ?? '').toString(),
              revenue: _d(m['revenue']),
              orders: _i(m['orders']),
            ),
          )
          .toList(growable: false),
      discountAndCommission: _d(json['discountAndCommission']),
      otherIncome: _d(json['otherIncome']),
      taxAndDuty: _d(json['taxAndDuty']),
      dueReceivable: _nd(json['dueReceivable']),
      duePaid: _nd(json['duePaid']),
      rawKeys: rawKeys,
      missingKeys: missingKeys,
    );
  }

  static Map<String, Object?> _map(Object? raw) {
    if (raw is Map) return Map<String, Object?>.from(raw);
    return const {};
  }

  static List<Map<String, Object?>> _list(Object? raw) {
    return ((raw as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, Object?>.from(m))
        .toList(growable: false);
  }

  static List<AnalyticsMoneyRow> _moneyRows(Object? raw) {
    return _list(raw)
        .map(
          (m) => AnalyticsMoneyRow(
            label: (m['label'] ?? '').toString(),
            value: _d(m['valueBdt']),
          ),
        )
        .toList(growable: false);
  }

  static double _d(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value
          .trim()
          .replaceAll('৳', '')
          .replaceAll(',', '')
          .replaceAll('(', '-')
          .replaceAll(')', '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  static double? _nd(Object? value) {
    if (value == null) return null;
    return _d(value);
  }

  static int _i(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim().replaceAll(',', '')) ??
          double.tryParse(value.trim().replaceAll(',', ''))?.toInt() ??
          0;
    }
    return 0;
  }
}

class AnalyticsTrendPoint {
  const AnalyticsTrendPoint({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  final String date;
  final double revenue;
  final int orders;
}

class AnalyticsMoneyRow {
  const AnalyticsMoneyRow({required this.label, required this.value});

  final String label;
  final double value;
}

class AnalyticsProfitSummary {
  const AnalyticsProfitSummary({
    required this.netSales,
    required this.serviceCharge,
    required this.deliveryCharge,
    required this.preparationCost,
    required this.wastage,
    required this.paymentFee,
    required this.taxes,
    required this.grossProfit,
  });

  final double netSales;
  final double serviceCharge;
  final double deliveryCharge;
  final double preparationCost;
  final double wastage;
  final double paymentFee;
  final double taxes;
  final double grossProfit;
}

class AnalyticsDish {
  const AnalyticsDish({required this.name, required this.salesBdt});

  final String name;
  final double salesBdt;
}

class AnalyticsItemCategory {
  const AnalyticsItemCategory({
    required this.category,
    required this.units,
    required this.totalPrice,
    required this.items,
  });

  final String category;
  final int units;
  final double totalPrice;
  final List<AnalyticsSummaryItem> items;
}

class AnalyticsSummaryItem {
  const AnalyticsSummaryItem({
    required this.menuItemId,
    required this.name,
    required this.units,
    required this.avgUnitPrice,
    required this.totalPrice,
  });

  final String menuItemId;
  final String name;
  final int units;
  final double avgUnitPrice;
  final double totalPrice;
}
