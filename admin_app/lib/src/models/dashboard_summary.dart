class DashboardSummary {
  DashboardSummary({
    required this.asOf,
    required this.moneyFirst,
    required this.rightNow,
  });

  final DateTime asOf;
  final MoneyFirstSection moneyFirst;
  final RightNowSection rightNow;

  factory DashboardSummary.fromJson(Map<String, Object?> json) {
    return DashboardSummary(
      asOf: _parseDate(json['asOf']),
      moneyFirst: MoneyFirstSection.fromJson(
        (json['moneyFirst'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      rightNow: RightNowSection.fromJson(
        (json['rightNow'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
    );
  }
}

class MoneyFirstSection {
  MoneyFirstSection({
    required this.earnedToday,
    required this.earnedYesterday,
    required this.deltaPct,
    required this.deltaNote,
    required this.sparkline,
    required this.kpis,
    required this.topMovers,
    required this.closeTodayHintBdt,
  });

  final double earnedToday;
  final double earnedYesterday;
  final double deltaPct;
  final String deltaNote;
  final List<double> sparkline;
  final DashboardKpis kpis;
  final List<TopMover> topMovers;
  final double closeTodayHintBdt;

  factory MoneyFirstSection.fromJson(Map<String, Object?> json) {
    final sparkline = (json['sparkline'] as List?) ?? const [];
    return MoneyFirstSection(
      earnedToday: _parseDouble(json['earnedToday']),
      earnedYesterday: _parseDouble(json['earnedYesterday']),
      deltaPct: _parseDouble(json['deltaPct']),
      deltaNote: (json['deltaNote'] as String?) ?? '',
      sparkline: sparkline.map(_parseDouble).toList(growable: false),
      kpis: DashboardKpis.fromJson(
        (json['kpis'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      topMovers: ((json['topMovers'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => TopMover.fromJson(row.cast<String, Object?>()))
          .toList(growable: false),
      closeTodayHintBdt: _parseDouble(json['closeTodayHintBdt']),
    );
  }
}

class DashboardKpis {
  DashboardKpis({
    required this.orders,
    required this.openOrders,
    required this.avgTicket,
    required this.profitPct,
  });

  final int orders;
  final int openOrders;
  final double avgTicket;
  final double profitPct;

  factory DashboardKpis.fromJson(Map<String, Object?> json) {
    return DashboardKpis(
      orders: _parseInt(json['orders']),
      openOrders: _parseInt(json['openOrders']),
      avgTicket: _parseDouble(json['avgTicket']),
      profitPct: _parseDouble(json['profitPct']),
    );
  }
}

class TopMover {
  TopMover({
    required this.menuItemId,
    required this.nameEn,
    required this.nameBn,
    required this.qty,
    required this.salesBdt,
    required this.sharePct,
  });

  final String menuItemId;
  final String nameEn;
  final String nameBn;
  final int qty;
  final double salesBdt;
  final double sharePct;

  factory TopMover.fromJson(Map<String, Object?> json) {
    return TopMover(
      menuItemId: (json['menuItemId'] as String?) ?? '',
      nameEn: (json['nameEn'] as String?) ?? '',
      nameBn: (json['nameBn'] as String?) ?? '',
      qty: _parseInt(json['qty']),
      salesBdt: _parseDouble(json['salesBdt']),
      sharePct: _parseDouble(json['sharePct']),
    );
  }
}

class RightNowSection {
  RightNowSection({
    required this.tablesSeated,
    required this.tablesTotal,
    required this.ordersInKitchen,
    required this.lateOrders,
    required this.lateMinThreshold,
    required this.needsAttention,
    required this.todaySoFarBdt,
    required this.todaySoFarDeltaPct,
  });

  final int tablesSeated;
  final int tablesTotal;
  final int ordersInKitchen;
  final int lateOrders;
  final int lateMinThreshold;
  final List<NeedsAttentionItem> needsAttention;
  final double todaySoFarBdt;
  final double todaySoFarDeltaPct;

  factory RightNowSection.fromJson(Map<String, Object?> json) {
    return RightNowSection(
      tablesSeated: _parseInt(json['tablesSeated']),
      tablesTotal: _parseInt(json['tablesTotal']),
      ordersInKitchen: _parseInt(json['ordersInKitchen']),
      lateOrders: _parseInt(json['lateOrders']),
      lateMinThreshold: _parseInt(json['lateMinThreshold']),
      needsAttention: ((json['needsAttention'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => NeedsAttentionItem.fromJson(row.cast<String, Object?>()))
          .toList(growable: false),
      todaySoFarBdt: _parseDouble(json['todaySoFarBdt']),
      todaySoFarDeltaPct: _parseDouble(json['todaySoFarDeltaPct']),
    );
  }
}

class NeedsAttentionItem {
  NeedsAttentionItem({
    required this.kind,
    required this.title,
    required this.body,
    required this.cta,
    required this.refId,
  });

  final String kind;
  final String title;
  final String body;
  final String cta;
  final String refId;

  factory NeedsAttentionItem.fromJson(Map<String, Object?> json) {
    return NeedsAttentionItem(
      kind: (json['kind'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      cta: (json['cta'] as String?) ?? '',
      refId: (json['refId'] as String?) ?? '',
    );
  }
}

double _parseDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime _parseDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}
