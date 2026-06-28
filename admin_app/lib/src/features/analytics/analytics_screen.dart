import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/report_section.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../models/analytics_summary_data.dart';
import '../../models/pos_notification.dart';

// ===========================================================================
// Owner Analytics — QuicklyServices plain-BD metric set (redesign spec Part B).
// Two tabs: Sales Breakdown (the money story) and Item-wise Sales (what sold).
// Deliberately NO AOV / cohort / LTV / forecast jargon. Money figures only.
// Backed by GET /outlets/{id}/analytics/summary.
// ===========================================================================

const bool _analyticsDiagnosticsEnabled = bool.fromEnvironment(
  'QB_ANALYTICS_DIAG',
);

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({this.onNavigateToTarget, super.key});

  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _tab = 0; // 0 = Sales Breakdown, 1 = Item-wise Sales
  String _range = 'today';
  Future<AnalyticsSummaryData>? _future;
  final ScrollController _scrollController = ScrollController();
  String? _lastDiagnostics;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<AnalyticsSummaryData> _load() async {
    final app = AppScope.read(context);
    final prefix =
        'range=$_range cloudReady=${app.isCloudReady} canSync=${app.cloudConfig.canSync}';
    try {
      final json = await app.fetchAnalyticsSummary(range: _range);
      final data = AnalyticsSummaryData.fromJson(json);
      _recordDiagnostics('$prefix ${data.diagnosticSummary}');
      return data;
    } catch (error, stack) {
      _recordDiagnostics('$prefix error=${error.runtimeType}: $error');
      developer.log(
        'Sales Breakdown load failed',
        name: 'analytics.summary',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  void _recordDiagnostics(String message) {
    _lastDiagnostics = message;
    developer.log(message, name: 'analytics.summary');
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
              child: _RangeChips(
                range: _range,
                onChanged: _setRange,
                text: text,
              ),
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
                  TfTabItem(label: text.itemWiseTab, labelBn: text.itemWiseTab),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<AnalyticsSummaryData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const TfLoading();
                  }
                  if (snap.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      children: [
                        TfEmptyState(
                          title: text.analyticsErrorTitle,
                          message: text.analyticsErrorMessage,
                          icon: Icons.cloud_off_rounded,
                        ),
                        ..._diagnosticWidgets(),
                      ],
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
                      controller: _scrollController,
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
    AnalyticsSummaryData d,
  ) {
    if (d.hasNoData) {
      return [
        ..._diagnosticWidgets(),
        const SizedBox(height: PosSpacing.sp8),
        TfEmptyState(
          title: text.analyticsNoDataTitle,
          message: text.analyticsNoDataMessage,
          icon: Icons.bar_chart_outlined,
        ),
      ];
    }
    try {
      return [
        ..._diagnosticWidgets(),
        if (d.trend.isNotEmpty) ...[
          _RevenueChartCard(trend: d.trend, text: text),
          const SizedBox(height: PosSpacing.sp3),
        ],
        _StatGrid(tiles: _statTiles(context, text, d)),
        Padding(
          padding: const EdgeInsets.only(top: PosSpacing.sp2),
          child: TfText(
            text.otherIncomeNote,
            style: const TextStyle(fontSize: 11, color: PosColors.muted),
          ),
        ),
        const SizedBox(height: PosSpacing.sp4),
        ReportSection(
          title: text.salesSummary,
          rows: [
            ReportRow(
              text.ordersCompleted,
              tfFormatNumber(context, d.ordersCompleted),
            ),
            ReportRow(text.grossSales, tfFormatCurrency(context, d.grossSales)),
            ReportRow(
              text.discountByStaff,
              parenCurrency(context, d.discountByStaff),
              deduction: true,
              indent: true,
            ),
            ReportRow(
              text.netSales,
              tfFormatCurrency(context, d.netSales),
              bold: true,
            ),
          ],
        ),
        const SizedBox(height: PosSpacing.sp3),
        ReportSection(
          title: text.collectionSummary,
          rows: d.collection.isEmpty
              ? [ReportRow(text.noData, tfFormatCurrency(context, 0))]
              : [
                  for (final c in d.collection)
                    ReportRow(c.label, tfFormatCurrency(context, c.value)),
                ],
        ),
        const SizedBox(height: PosSpacing.sp3),
        if (d.serviceWise.any((s) => s.value > 0)) ...[
          _ServiceWiseChartCard(rows: d.serviceWise, text: text),
          const SizedBox(height: PosSpacing.sp3),
        ],
        ReportSection(
          title: text.serviceWiseSales,
          rows: d.serviceWise.isEmpty
              ? [ReportRow(text.noData, tfFormatCurrency(context, 0))]
              : [
                  for (final s in d.serviceWise)
                    ReportRow(s.label, tfFormatCurrency(context, s.value)),
                ],
        ),
        const SizedBox(height: PosSpacing.sp3),
        ReportSection(
          title: text.profitEstimation,
          rows: [
            ReportRow(
              text.netSales,
              tfFormatCurrency(context, d.profit.netSales),
            ),
            ReportRow(
              text.serviceCharge,
              tfFormatCurrency(context, d.profit.serviceCharge),
            ),
            ReportRow(
              text.deliveryCharge,
              tfFormatCurrency(context, d.profit.deliveryCharge),
            ),
            ReportRow(
              text.preparationCost,
              parenCurrency(context, d.profit.preparationCost),
              deduction: true,
            ),
            ReportRow(
              text.wastage,
              parenCurrency(context, d.profit.wastage),
              deduction: true,
            ),
            ReportRow(
              text.paymentFee,
              parenCurrency(context, d.profit.paymentFee),
              deduction: true,
            ),
            ReportRow(
              text.taxesIncl,
              parenCurrency(context, d.profit.taxes),
              deduction: true,
            ),
            ReportRow(
              text.grossProfit,
              tfFormatCurrency(context, d.profit.grossProfit),
              bold: true,
              positive: d.profit.grossProfit >= 0,
            ),
          ],
        ),
        const SizedBox(height: PosSpacing.sp3),
        _MiniStatRow(
          title:
              '${text.costOfGoodsSold} (${tfFormatCurrency(context, d.profit.preparationCost + d.profit.wastage + d.profit.paymentFee)})',
          cells: [
            (
              text.preparationCost,
              tfFormatCurrency(context, d.profit.preparationCost),
            ),
            (text.wastage, tfFormatCurrency(context, d.profit.wastage)),
            (text.paymentFee, tfFormatCurrency(context, d.profit.paymentFee)),
          ],
        ),
        const SizedBox(height: PosSpacing.sp3),
        _MiniStatRow(
          title: text.profitEstimation,
          cells: [
            (text.netSales, tfFormatCurrency(context, d.profit.netSales)),
            (
              text.costOfGoodsSold,
              tfFormatCurrency(
                context,
                d.profit.preparationCost +
                    d.profit.wastage +
                    d.profit.paymentFee,
              ),
            ),
            (text.grossProfit, tfFormatCurrency(context, d.profit.grossProfit)),
          ],
        ),
        const SizedBox(height: PosSpacing.sp3),
        _PopularDishes(dishes: d.popular, text: text),
      ];
    } catch (e, st) {
      _recordDiagnostics('renderError=${e.runtimeType}: $e');
      developer.log(
        'Sales Breakdown render failed',
        name: 'analytics.summary',
        error: e,
        stackTrace: st,
      );
      return [
        ..._diagnosticWidgets(),
        TfCard(
          padding: const EdgeInsets.all(12),
          child: TfText('Build error: $e'),
        ),
      ];
    }
  }

  List<_TileSpec> _statTiles(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) {
    return [
      _TileSpec(
        PosColors.tintPurple,
        Icons.receipt_long_rounded,
        PosColors.iconPurple,
        tfFormatNumber(context, d.ordersCompleted),
        text.ordersCompleted,
      ),
      _TileSpec(
        PosColors.tintBlue,
        Icons.trending_up_rounded,
        PosColors.iconBlue,
        tfFormatCurrency(context, d.grossSales),
        text.grossSales,
      ),
      _TileSpec(
        PosColors.tintPurple,
        Icons.local_offer_outlined,
        PosColors.iconPurple,
        parenCurrency(context, d.discountAndCommission),
        text.discountAndCommission,
      ),
      _TileSpec(
        PosColors.tintBlue,
        Icons.bar_chart_rounded,
        PosColors.iconBlue,
        tfFormatCurrency(context, d.netSales),
        text.netSales,
      ),
      _TileSpec(
        PosColors.tintGreen,
        Icons.add_card_outlined,
        PosColors.iconGreen,
        tfFormatCurrency(context, d.otherIncome),
        text.otherIncome,
      ),
      _TileSpec(
        PosColors.tintAmber,
        Icons.receipt_outlined,
        PosColors.iconAmber,
        tfFormatCurrency(context, d.taxAndDuty),
        text.taxAndDuty,
      ),
      if (d.dueReceivable != null)
        _TileSpec(
          PosColors.tintRed,
          Icons.schedule_outlined,
          PosColors.iconRed,
          parenCurrency(context, d.dueReceivable!),
          text.dueReceivable,
        ),
      if (d.duePaid != null)
        _TileSpec(
          PosColors.tintGreen,
          Icons.check_circle_outline,
          PosColors.iconGreen,
          tfFormatCurrency(context, d.duePaid!),
          text.duePaid,
        ),
      _TileSpec(
        PosColors.tintGreen,
        Icons.account_balance_wallet_rounded,
        PosColors.iconGreen,
        tfFormatCurrency(context, d.totalCollection),
        text.totalCollection,
      ),
    ];
  }

  void _openItem(BuildContext context, AnalyticsSummaryItem item) {
    if (item.menuItemId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDrillDownScreen(
          menuItemId: item.menuItemId,
          name: item.name,
          range: _range,
        ),
      ),
    );
  }

  List<Widget> _itemWise(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) {
    if (d.itemWise.isEmpty) {
      return [
        ..._diagnosticWidgets(),
        const SizedBox(height: PosSpacing.sp8),
        TfEmptyState(
          title: text.analyticsNoItemsTitle,
          message: text.analyticsNoItemsMessage,
          icon: Icons.fastfood_rounded,
        ),
      ];
    }
    return [
      ..._diagnosticWidgets(),
      for (final cat in d.itemWise) ...[
        _ItemCategoryCard(
          category: cat,
          text: text,
          onTapItem: (item) => _openItem(context, item),
        ),
        const SizedBox(height: PosSpacing.sp3),
      ],
    ];
  }

  List<Widget> _diagnosticWidgets() {
    if (!_analyticsDiagnosticsEnabled) return const [];
    final message = _lastDiagnostics;
    if (message == null || message.trim().isEmpty) return const [];
    return [
      TfCard(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            height: 1.3,
            color: PosColors.muted,
          ),
        ),
      ),
      const SizedBox(height: PosSpacing.sp3),
    ];
  }
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
    return Wrap(
      spacing: PosSpacing.sp2,
      runSpacing: PosSpacing.sp2,
      children: [
        for (final (key, label) in options)
          TfChip(
            label: label,
            active: range == key,
            small: true,
            onTap: () => onChanged(key),
          ),
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

class _PopularDishes extends StatelessWidget {
  const _PopularDishes({required this.dishes, required this.text});
  final List<AnalyticsDish> dishes;
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
  const _ItemCategoryCard({
    required this.category,
    required this.text,
    required this.onTapItem,
  });
  final AnalyticsItemCategory category;
  final AppStrings text;
  final ValueChanged<AnalyticsSummaryItem> onTapItem;

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
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(PosRadii.lg),
              ),
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
                  InkWell(
                    onTap: () => onTapItem(item),
                    child: Container(
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
                          const SizedBox(width: PosSpacing.sp2),
                          SizedBox(
                            width: kReportAvgColWidth,
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
                            width: kReportTotalColWidth,
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
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: PosColors.muted,
                          ),
                        ],
                      ),
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

// ---------------------------------------------------------------------------
// QS analytics building blocks (charts, stat grid, mini-rows, drill-down).
// ---------------------------------------------------------------------------

class _TileSpec {
  const _TileSpec(this.tint, this.icon, this.iconColor, this.value, this.label);
  final Color tint;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
}

/// 3-per-row stat-tile grid; trailing slots stay empty (null tiles dropped
/// upstream so dataless figures never zero-fill).
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});
  final List<_TileSpec> tiles;

  @override
  Widget build(BuildContext context) {
    const cols = 3;
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += cols) {
      final slice = tiles.skip(i).take(cols).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int j = 0; j < cols; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              Expanded(
                child: j < slice.length
                    ? _StatTile(
                        tint: slice[j].tint,
                        icon: slice[j].icon,
                        iconColor: slice[j].iconColor,
                        value: slice[j].value,
                        label: slice[j].label,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      if (i + cols < tiles.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

class _RevenueChartCard extends StatefulWidget {
  const _RevenueChartCard({required this.trend, required this.text});
  final List<AnalyticsTrendPoint> trend;
  final AppStrings text;

  @override
  State<_RevenueChartCard> createState() => _RevenueChartCardState();
}

class _RevenueChartCardState extends State<_RevenueChartCard> {
  int _metric = 0; // 0 = Revenue, 1 = No of Orders

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final p in widget.trend)
        _metric == 0 ? p.revenue : p.orders.toDouble(),
    ];
    final labels = [for (final p in widget.trend) _shortDate(p.date)];
    return TfCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
      child: Column(
        children: [
          TfAreaChart(values: values, xLabels: labels, money: _metric == 0),
          const SizedBox(height: 10),
          TfChartMetricToggle(
            options: [widget.text.revenue, widget.text.noOfOrders],
            selectedIndex: _metric,
            onChanged: (i) => setState(() => _metric = i),
          ),
        ],
      ),
    );
  }
}

class _ServiceWiseChartCard extends StatelessWidget {
  const _ServiceWiseChartCard({required this.rows, required this.text});
  final List<AnalyticsMoneyRow> rows;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: TfText(
              text.serviceWiseSales,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PosColors.text,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TfBarChart(
            bars: [
              for (final r in rows) TfBarDatum(label: r.label, value: r.value),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2–3 numbers side by side with hairline dividers and a caption under each
/// (spec §5 mini-stat row: COGS = Prep Cost | Wastage | Payment Fee).
class _MiniStatRow extends StatelessWidget {
  const _MiniStatRow({required this.title, required this.cells});
  final String title;
  final List<(String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TfText(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: PosColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cells.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(width: 1, color: PosColors.line),
                    ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TfText(
                          cells[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: PosColors.text,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        TfText(
                          cells[i].$1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: PosColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item drill-down — daily sales chart + "Sales of last N days" zebra list.
// Backed by GET /outlets/{id}/analytics/item/{menuItemId}.
// ---------------------------------------------------------------------------
class ItemDrillDownScreen extends StatefulWidget {
  const ItemDrillDownScreen({
    required this.menuItemId,
    required this.name,
    required this.range,
    super.key,
  });
  final String menuItemId;
  final String name;
  final String range;

  @override
  State<ItemDrillDownScreen> createState() => _ItemDrillDownScreenState();
}

class _ItemDrillDownScreenState extends State<ItemDrillDownScreen> {
  Future<_ItemDetail>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_ItemDetail> _load() async {
    final app = AppScope.read(context);
    final json = await app.fetchItemAnalytics(
      menuItemId: widget.menuItemId,
      range: widget.range,
    );
    return _ItemDetail.fromJson(json);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(title: Text(widget.name)),
      body: SafeArea(
        child: FutureBuilder<_ItemDetail>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const TfLoading();
            }
            if (snap.hasError || snap.data == null) {
              return TfEmptyState(
                title: text.analyticsErrorTitle,
                message: text.analyticsErrorMessage,
                icon: Icons.cloud_off_rounded,
              );
            }
            final d = snap.data!;
            final reversed = d.daily.reversed.toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                TfCard(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: TfText(
                          text.performance,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: PosColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TfAreaChart(
                        height: 180,
                        values: [for (final p in d.daily) p.salesBdt],
                        xLabels: [for (final p in d.daily) _shortDate(p.date)],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TfText(
                  text.salesOfLastDays(d.daily.length),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                TfCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < reversed.length; i++)
                        Container(
                          color: i.isOdd
                              ? PosColors.surfaceSunk
                              : PosColors.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TfText(
                                  _dayLabel(reversed[i].date),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: PosColors.ink2,
                                  ),
                                ),
                              ),
                              TfText(
                                tfFormatCurrency(context, reversed[i].salesBdt),
                                style: const TextStyle(
                                  fontSize: 13.5,
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ItemDetail {
  _ItemDetail({
    required this.name,
    required this.totalBdt,
    required this.daily,
  });
  final String name;
  final double totalBdt;
  final List<_DayPoint> daily;

  factory _ItemDetail.fromJson(Map<String, Object?> json) {
    return _ItemDetail(
      name: (json['name'] ?? '').toString(),
      totalBdt: (json['totalBdt'] as num?)?.toDouble() ?? 0,
      daily: ((json['dailySales'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) => _DayPoint(
              date: (m['date'] ?? '').toString(),
              salesBdt: (m['salesBdt'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DayPoint {
  const _DayPoint({required this.date, required this.salesBdt});
  final String date;
  final double salesBdt;
}

const _monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _shortDate(String iso) {
  final p = iso.split('-');
  if (p.length == 3) {
    return '${int.tryParse(p[2]) ?? p[2]}/${int.tryParse(p[1]) ?? p[1]}';
  }
  return iso;
}

String _dayLabel(String iso) {
  final p = iso.split('-');
  if (p.length == 3) {
    final m = int.tryParse(p[1]) ?? 1;
    final dd = int.tryParse(p[2]) ?? 0;
    final mon = (m >= 1 && m <= 12) ? _monthAbbr[m - 1] : p[1];
    return '$dd $mon';
  }
  return iso;
}
