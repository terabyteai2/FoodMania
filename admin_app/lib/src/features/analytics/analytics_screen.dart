import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../models/pos_notification.dart';

// ===========================================================================
// Owner Analytics — QuicklyServices plain-BD metric set (redesign spec Part B).
// Two tabs: Sales Breakdown (the money story) and Item-wise Sales (what sold).
// Deliberately NO AOV / cohort / LTV / forecast jargon. Money figures only.
// Backed by GET /outlets/{id}/analytics/summary.
// ===========================================================================

/// Parsed QS analytics payload.
class _QsData {
  _QsData({
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
  });

  final int ordersCompleted;
  final double grossSales;
  final double discountByStaff;
  final double netSales;
  final double totalCollection;
  final List<_MoneyRow> collection;
  final List<_MoneyRow> serviceWise;
  final _Profit profit;
  final List<_Dish> popular;
  final List<_ItemCategory> itemWise;

  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;

  factory _QsData.fromJson(Map<String, Object?> json) {
    final summary = (json['salesSummary'] as Map?) ?? const {};
    final profit = (json['profit'] as Map?) ?? const {};
    List<_MoneyRow> rows(Object? raw) => ((raw as List?) ?? const [])
        .whereType<Map>()
        .map(
          (m) => _MoneyRow(
            label: (m['label'] ?? '').toString(),
            value: _d(m['valueBdt']),
          ),
        )
        .toList(growable: false);
    return _QsData(
      ordersCompleted: _i(summary['ordersCompleted']),
      grossSales: _d(summary['grossSales']),
      discountByStaff: _d(summary['discountByStaff']),
      netSales: _d(summary['netSales']),
      totalCollection: _d(json['totalCollection']),
      collection: rows(json['collection']),
      serviceWise: rows(json['serviceWise']),
      profit: _Profit(
        netSales: _d(profit['netSales']),
        serviceCharge: _d(profit['serviceCharge']),
        deliveryCharge: _d(profit['deliveryCharge']),
        preparationCost: _d(profit['preparationCost']),
        wastage: _d(profit['wastage']),
        paymentFee: _d(profit['paymentFee']),
        taxes: _d(profit['taxes']),
        grossProfit: _d(profit['grossProfit']),
      ),
      popular: ((json['popularDishes'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) => _Dish(
              name: (m['name'] ?? '').toString(),
              salesBdt: _d(m['salesBdt']),
            ),
          )
          .toList(growable: false),
      itemWise: ((json['itemWise'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (c) => _ItemCategory(
              category: (c['category'] ?? '').toString(),
              units: _i(c['units']),
              totalPrice: _d(c['totalPrice']),
              items: ((c['items'] as List?) ?? const [])
                  .whereType<Map>()
                  .map(
                    (i) => _Item(
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
    );
  }
}

class _MoneyRow {
  const _MoneyRow({required this.label, required this.value});
  final String label;
  final double value;
}

class _Profit {
  const _Profit({
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

class _Dish {
  const _Dish({required this.name, required this.salesBdt});
  final String name;
  final double salesBdt;
}

class _ItemCategory {
  const _ItemCategory({
    required this.category,
    required this.units,
    required this.totalPrice,
    required this.items,
  });
  final String category;
  final int units;
  final double totalPrice;
  final List<_Item> items;
}

class _Item {
  const _Item({
    required this.name,
    required this.units,
    required this.avgUnitPrice,
    required this.totalPrice,
  });
  final String name;
  final int units;
  final double avgUnitPrice;
  final double totalPrice;
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({this.onNavigateToTarget, super.key});

  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _tab = 0; // 0 = Sales Breakdown, 1 = Item-wise Sales
  String _range = 'today';
  Future<_QsData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_QsData> _load() async {
    final app = AppScope.read(context);
    final json = await app.fetchAnalyticsSummary(range: _range);
    return _QsData.fromJson(json);
  }

  void _setRange(String range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TfGlobalTopBar(
              title: text.analyticsTab,
              subtitle: text.ownerViewSubtitle(app.outletName),
              onNavigateToTarget: widget.onNavigateToTarget,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: _RangeChips(range: _range, onChanged: _setRange, text: text),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TfSegToggle(
                activeIndex: _tab,
                onChanged: (i) => setState(() => _tab = i),
                items: [
                  TfTabItem(
                    label: text.salesBreakdownTab,
                    labelBn: text.salesBreakdownTab,
                  ),
                  TfTabItem(
                    label: text.itemWiseTab,
                    labelBn: text.itemWiseTab,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<_QsData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const TfLoading();
                  }
                  if (snap.hasError) {
                    return TfEmptyState(
                      title: text.analyticsErrorTitle,
                      message: text.analyticsErrorMessage,
                      icon: Icons.cloud_off_rounded,
                    );
                  }
                  final data = snap.data!;
                  return RefreshIndicator(
                    color: PosColors.primary,
                    onRefresh: () async {
                      final f = _load();
                      setState(() => _future = f);
                      await f;
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      children: _tab == 0
                          ? _salesBreakdown(context, text, data)
                          : _itemWise(context, text, data),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _salesBreakdown(
    BuildContext context,
    AppStrings text,
    _QsData d,
  ) {
    return [
      Row(
        children: [
          Expanded(
            child: _StatTile(
              tint: PosColors.tintPurple,
              icon: Icons.receipt_long_rounded,
              iconColor: PosColors.iconPurple,
              value: tfFormatNumber(context, d.ordersCompleted),
              label: text.ordersCompleted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              tint: PosColors.tintBlue,
              icon: Icons.bar_chart_rounded,
              iconColor: PosColors.iconBlue,
              value: tfFormatCurrency(context, d.netSales),
              label: text.netSales,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              tint: PosColors.tintGreen,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: PosColors.iconGreen,
              value: tfFormatCurrency(context, d.totalCollection),
              label: text.totalCollection,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _ReportSection(
        title: text.salesSummary,
        rows: [
          _Row(text.ordersCompleted, tfFormatNumber(context, d.ordersCompleted)),
          _Row(text.grossSales, tfFormatCurrency(context, d.grossSales)),
          _Row(
            text.discountByStaff,
            _paren(context, d.discountByStaff),
            deduction: true,
            indent: true,
          ),
          _Row(text.netSales, tfFormatCurrency(context, d.netSales), bold: true),
        ],
      ),
      const SizedBox(height: 12),
      _ReportSection(
        title: text.collectionSummary,
        rows: d.collection.isEmpty
            ? [_Row(text.noData, tfFormatCurrency(context, 0))]
            : [
                for (final c in d.collection)
                  _Row(c.label, tfFormatCurrency(context, c.value)),
              ],
      ),
      const SizedBox(height: 12),
      _ReportSection(
        title: text.serviceWiseSales,
        rows: [
          for (final s in d.serviceWise)
            _Row(s.label, tfFormatCurrency(context, s.value)),
        ],
      ),
      const SizedBox(height: 12),
      _ReportSection(
        title: text.profitEstimation,
        rows: [
          _Row(text.netSales, tfFormatCurrency(context, d.profit.netSales)),
          _Row(
            text.serviceCharge,
            tfFormatCurrency(context, d.profit.serviceCharge),
          ),
          _Row(
            text.deliveryCharge,
            tfFormatCurrency(context, d.profit.deliveryCharge),
          ),
          _Row(
            text.preparationCost,
            _paren(context, d.profit.preparationCost),
            deduction: true,
          ),
          _Row(text.wastage, _paren(context, d.profit.wastage), deduction: true),
          _Row(
            text.paymentFee,
            _paren(context, d.profit.paymentFee),
            deduction: true,
          ),
          _Row(text.taxesIncl, _paren(context, d.profit.taxes), deduction: true),
          _Row(
            text.grossProfit,
            tfFormatCurrency(context, d.profit.grossProfit),
            bold: true,
            positive: d.profit.grossProfit >= 0,
          ),
        ],
      ),
      const SizedBox(height: 12),
      _PopularDishes(dishes: d.popular, text: text),
    ];
  }

  List<Widget> _itemWise(BuildContext context, AppStrings text, _QsData d) {
    if (d.itemWise.isEmpty) {
      return [
        const SizedBox(height: 40),
        TfEmptyState(
          title: text.analyticsNoItemsTitle,
          message: text.analyticsNoItemsMessage,
          icon: Icons.fastfood_rounded,
        ),
      ];
    }
    return [
      for (final cat in d.itemWise) ...[
        _ItemCategoryCard(category: cat, text: text),
        const SizedBox(height: 12),
      ],
    ];
  }

  String _paren(BuildContext context, double value) =>
      '(${tfFormatCurrency(context, value)})';
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({
    required this.range,
    required this.onChanged,
    required this.text,
  });

  final String range;
  final ValueChanged<String> onChanged;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final options = <(String, String)>[
      ('today', text.rangeToday),
      ('week', text.range7Days),
      ('month', text.range30Days),
    ];
    return Row(
      children: [
        for (final (key, label) in options) ...[
          TfChip(
            label: label,
            active: range == key,
            small: true,
            onTap: () => onChanged(key),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.tint,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final Color tint;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(height: 10),
          TfText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: PosColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          TfText(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: PosColors.muted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row {
  _Row(
    this.label,
    this.value, {
    this.bold = false,
    this.deduction = false,
    this.indent = false,
    this.positive = false,
  });
  final String label;
  final String value;
  final bool bold;
  final bool deduction;
  final bool indent;
  final bool positive;
}

/// Collapsible report-section card (spec §5 accordion).
class _ReportSection extends StatefulWidget {
  const _ReportSection({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  State<_ReportSection> createState() => _ReportSectionState();
}

class _ReportSectionState extends State<_ReportSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TfText(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PosColors.text,
                      ),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: PosColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Column(
                children: [
                  for (final row in widget.rows) _buildRow(row),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(_Row row) {
    final valueColor = row.positive
        ? PosColors.success
        : row.deduction
        ? PosColors.muted
        : PosColors.text;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PosColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(row.indent ? 14 : 0, 11, 0, 11),
      child: Row(
        children: [
          Expanded(
            child: TfText(
              row.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: row.bold ? FontWeight.w700 : FontWeight.w500,
                color: row.bold ? PosColors.text : PosColors.ink2,
              ),
            ),
          ),
          TfText(
            row.value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: row.bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularDishes extends StatelessWidget {
  const _PopularDishes({required this.dishes, required this.text});
  final List<_Dish> dishes;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TfText(
            text.popularDishes,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PosColors.text,
            ),
          ),
          const SizedBox(height: 4),
          if (dishes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TfText(
                text.noData,
                style: const TextStyle(color: PosColors.muted, fontSize: 13),
              ),
            )
          else
            for (final dish in dishes)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: PosColors.line)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TfText(
                        dish.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: PosColors.text,
                        ),
                      ),
                    ),
                    TfText(
                      tfFormatCurrency(context, dish.salesBdt),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PosColors.text,
                        fontFeatures: [FontFeature.tabularFigures()],
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

class _ItemCategoryCard extends StatelessWidget {
  const _ItemCategoryCard({required this.category, required this.text});
  final _ItemCategory category;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category subtotal header (surface-2 background).
          Container(
            decoration: const BoxDecoration(
              color: PosColors.surfaceSunk,
              borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.lg)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: TfText(
                    '${category.category} (${category.units})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PosColors.text,
                    ),
                  ),
                ),
                TfText(
                  tfFormatCurrency(context, category.totalPrice),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: PosColors.text,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final item in category.items)
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: PosColors.line)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: TfText(
                            '${item.name} (${item.units})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: PosColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 78,
                          child: TfText(
                            tfFormatCurrency(context, item.avgUnitPrice),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: PosColors.muted,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 88,
                          child: TfText(
                            tfFormatCurrency(context, item.totalPrice),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: PosColors.text,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
