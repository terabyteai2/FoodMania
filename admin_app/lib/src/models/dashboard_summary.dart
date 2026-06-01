class DashboardSummary {
  DashboardSummary({
    required this.asOf,
    required this.moneyFirst,
    required this.rightNow,
    this.review,
  });

  final DateTime asOf;
  final MoneyFirstSection moneyFirst;
  final RightNowSection rightNow;

  /// Review-tab payload. Nullable so responses from older backends still parse.
  final ReviewSection? review;

  factory DashboardSummary.fromJson(Map<String, Object?> json) {
    final reviewJson = (json['review'] as Map?)?.cast<String, Object?>();
    return DashboardSummary(
      asOf: _parseDate(json['asOf']),
      moneyFirst: MoneyFirstSection.fromJson(
        (json['moneyFirst'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      rightNow: RightNowSection.fromJson(
        (json['rightNow'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      review: reviewJson == null ? null : ReviewSection.fromJson(reviewJson),
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

// ── Review tab ────────────────────────────────────────────────────────────────

class ReviewSection {
  ReviewSection({
    required this.hero,
    required this.kpis,
    required this.revenueByHour,
    required this.itemsSold,
    required this.bySource,
    required this.issues,
    required this.staff,
    required this.fleet,
  });

  final ReviewHero hero;
  final ReviewKpis kpis;
  final RevenueByHour revenueByHour;
  final List<ReviewItem> itemsSold;
  final List<SourceSlice> bySource;
  final List<ReviewIssue> issues;
  final List<StaffScore> staff;
  final FleetSection fleet;

  factory ReviewSection.fromJson(Map<String, Object?> json) {
    return ReviewSection(
      hero: ReviewHero.fromJson(
        (json['hero'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      kpis: ReviewKpis.fromJson(
        (json['kpis'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      revenueByHour: RevenueByHour.fromJson(
        (json['revenueByHour'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      itemsSold: _mapList(json['itemsSold'], ReviewItem.fromJson),
      bySource: _mapList(json['bySource'], SourceSlice.fromJson),
      issues: _mapList(json['issues'], ReviewIssue.fromJson),
      staff: _mapList(json['staff'], StaffScore.fromJson),
      fleet: FleetSection.fromJson(
        (json['fleet'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
    );
  }
}

class ReviewHero {
  ReviewHero({
    required this.earnedTodayBdt,
    required this.earnedYesterdayBdt,
    required this.avg7Bdt,
    required this.deltaPct,
    required this.deltaUp,
    required this.periodNote,
  });

  final double earnedTodayBdt;
  final double earnedYesterdayBdt;
  final double avg7Bdt;
  final double deltaPct;
  final bool deltaUp;
  final String periodNote;

  factory ReviewHero.fromJson(Map<String, Object?> json) {
    return ReviewHero(
      earnedTodayBdt: _parseDouble(json['earnedTodayBdt']),
      earnedYesterdayBdt: _parseDouble(json['earnedYesterdayBdt']),
      avg7Bdt: _parseDouble(json['avg7Bdt']),
      deltaPct: _parseDouble(json['deltaPct']),
      deltaUp: json['deltaUp'] == true,
      periodNote: (json['periodNote'] as String?) ?? '',
    );
  }
}

class ReviewKpis {
  ReviewKpis({
    required this.orders,
    required this.covers,
    required this.avgTicketBdt,
    required this.foodCostPct,
  });

  final int orders;
  final int covers;
  final double avgTicketBdt;

  /// Null when no sold item has a cost price set — UI renders a neutral dash.
  final double? foodCostPct;

  factory ReviewKpis.fromJson(Map<String, Object?> json) {
    return ReviewKpis(
      orders: _parseInt(json['orders']),
      covers: _parseInt(json['covers']),
      avgTicketBdt: _parseDouble(json['avgTicketBdt']),
      foodCostPct: _parseNullableDouble(json['foodCostPct']),
    );
  }
}

class RevenueByHour {
  RevenueByHour({
    required this.startHour,
    required this.today,
    required this.avg7,
    required this.peakIndex,
    required this.peakLabel,
  });

  final int startHour;
  final List<double> today;
  final List<double> avg7;
  final int peakIndex;
  final String peakLabel;

  bool get hasData => today.any((v) => v > 0);

  factory RevenueByHour.fromJson(Map<String, Object?> json) {
    return RevenueByHour(
      startHour: _parseInt(json['startHour']),
      today: ((json['today'] as List?) ?? const []).map(_parseDouble).toList(growable: false),
      avg7: ((json['avg7'] as List?) ?? const []).map(_parseDouble).toList(growable: false),
      peakIndex: _parseInt(json['peakIndex']),
      peakLabel: (json['peakLabel'] as String?) ?? '',
    );
  }
}

class ReviewItem {
  ReviewItem({
    required this.nameEn,
    required this.nameBn,
    required this.qty,
    required this.salesBdt,
    required this.marginBdt,
    required this.foodCostPct,
    required this.lowMargin,
  });

  final String nameEn;
  final String nameBn;
  final int qty;
  final double salesBdt;
  final double? marginBdt;
  final double? foodCostPct;
  final bool lowMargin;

  factory ReviewItem.fromJson(Map<String, Object?> json) {
    return ReviewItem(
      nameEn: (json['nameEn'] as String?) ?? '',
      nameBn: (json['nameBn'] as String?) ?? '',
      qty: _parseInt(json['qty']),
      salesBdt: _parseDouble(json['salesBdt']),
      marginBdt: _parseNullableDouble(json['marginBdt']),
      foodCostPct: _parseNullableDouble(json['foodCostPct']),
      lowMargin: json['lowMargin'] == true,
    );
  }
}

class SourceSlice {
  SourceSlice({
    required this.key,
    required this.label,
    required this.valueBdt,
    required this.pct,
  });

  final String key;
  final String label;
  final double valueBdt;
  final int pct;

  factory SourceSlice.fromJson(Map<String, Object?> json) {
    return SourceSlice(
      key: (json['key'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      valueBdt: _parseDouble(json['valueBdt']),
      pct: _parseInt(json['pct']),
    );
  }
}

class ReviewIssue {
  ReviewIssue({required this.tag, required this.title, required this.body});

  final String tag;
  final String title;
  final String body;

  factory ReviewIssue.fromJson(Map<String, Object?> json) {
    return ReviewIssue(
      tag: (json['tag'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
    );
  }
}

class StaffScore {
  StaffScore({
    required this.name,
    required this.role,
    required this.covers,
    required this.ordersToday,
    required this.avgTicketBdt,
  });

  final String name;
  final String role;
  final int covers;
  final int ordersToday;
  final double avgTicketBdt;

  factory StaffScore.fromJson(Map<String, Object?> json) {
    return StaffScore(
      name: (json['name'] as String?) ?? 'Staff',
      role: (json['role'] as String?) ?? '',
      covers: _parseInt(json['covers']),
      ordersToday: _parseInt(json['ordersToday']),
      avgTicketBdt: _parseDouble(json['avgTicketBdt']),
    );
  }
}

class FleetSection {
  FleetSection({
    required this.outlets,
    required this.kpis,
    required this.revenueByHour,
    required this.capacity,
    required this.topMovers,
  });

  final List<FleetOutlet> outlets;
  final FleetKpis kpis;
  final RevenueByHour revenueByHour;
  final List<CapacityRow> capacity;
  final List<ReviewItem> topMovers;

  factory FleetSection.fromJson(Map<String, Object?> json) {
    return FleetSection(
      outlets: _mapList(json['outlets'], FleetOutlet.fromJson),
      kpis: FleetKpis.fromJson(
        (json['kpis'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      revenueByHour: RevenueByHour.fromJson(
        (json['revenueByHour'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      capacity: _mapList(json['capacity'], CapacityRow.fromJson),
      topMovers: _mapList(json['topMovers'], ReviewItem.fromJson),
    );
  }
}

class FleetKpis {
  FleetKpis({
    required this.outletCount,
    required this.revBdt,
    required this.deltaPct,
    required this.deltaUp,
    required this.avg7Bdt,
    required this.covers,
    required this.avgTicketBdt,
    required this.foodCostPct,
    required this.onGoalCount,
  });

  final int outletCount;
  final double revBdt;
  final double deltaPct;
  final bool deltaUp;
  final double avg7Bdt;
  final int covers;
  final double avgTicketBdt;
  final double? foodCostPct;
  final int onGoalCount;

  factory FleetKpis.fromJson(Map<String, Object?> json) {
    return FleetKpis(
      outletCount: _parseInt(json['outletCount']),
      revBdt: _parseDouble(json['revBdt']),
      deltaPct: _parseDouble(json['deltaPct']),
      deltaUp: json['deltaUp'] == true,
      avg7Bdt: _parseDouble(json['avg7Bdt']),
      covers: _parseInt(json['covers']),
      avgTicketBdt: _parseDouble(json['avgTicketBdt']),
      foodCostPct: _parseNullableDouble(json['foodCostPct']),
      onGoalCount: _parseInt(json['onGoalCount']),
    );
  }
}

class FleetOutlet {
  FleetOutlet({
    required this.rank,
    required this.name,
    required this.area,
    required this.revBdt,
    required this.covers,
    required this.deltaPct,
    required this.deltaUp,
    required this.foodCostPct,
    required this.health,
  });

  final int rank;
  final String name;
  final String area;
  final double revBdt;
  final int covers;
  final double deltaPct;
  final bool deltaUp;
  final double? foodCostPct;
  final List<HealthChip> health;

  factory FleetOutlet.fromJson(Map<String, Object?> json) {
    return FleetOutlet(
      rank: _parseInt(json['rank']),
      name: (json['name'] as String?) ?? '',
      area: (json['area'] as String?) ?? '',
      revBdt: _parseDouble(json['revBdt']),
      covers: _parseInt(json['covers']),
      deltaPct: _parseDouble(json['deltaPct']),
      deltaUp: json['deltaUp'] == true,
      foodCostPct: _parseNullableDouble(json['foodCostPct']),
      health: _mapList(json['health'], HealthChip.fromJson),
    );
  }
}

class HealthChip {
  HealthChip({required this.tone, required this.label, required this.value});

  final String tone;
  final String label;
  final String value;

  factory HealthChip.fromJson(Map<String, Object?> json) {
    return HealthChip(
      tone: (json['tone'] as String?) ?? 'late',
      label: (json['label'] as String?) ?? '',
      value: (json['value'] as String?) ?? '',
    );
  }
}

class CapacityRow {
  CapacityRow({required this.name, required this.pct, required this.status});

  final String name;
  final int pct;
  final String status;

  factory CapacityRow.fromJson(Map<String, Object?> json) {
    return CapacityRow(
      name: (json['name'] as String?) ?? '',
      pct: _parseInt(json['pct']),
      status: (json['status'] as String?) ?? '',
    );
  }
}

List<T> _mapList<T>(Object? value, T Function(Map<String, Object?>) fromJson) {
  return ((value as List?) ?? const [])
      .whereType<Map>()
      .map((row) => fromJson(row.cast<String, Object?>()))
      .toList(growable: false);
}

double? _parseNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
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
