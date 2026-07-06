import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/report_section.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../core/widgets/tf_timeframe_selector.dart';
import '../../models/analytics_summary_data.dart';
import '../../models/pos_notification.dart';
import '../reports/report_export.dart';

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
  const AnalyticsScreen({
    this.reduced = false,
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    super.key,
  });

  /// When true, renders the reduced manager "Sales Summary" cut — today-only,
  /// with no period selector / tabs / profit / charts / item-wise / export.
  final bool reduced;
  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _tab = 0; // 0 = Sales Breakdown, 1 = Item-wise Sales
  String _range = 'today';
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
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
    final start = _rangeStart;
    final end = _rangeEnd;
    try {
      final json = await app.fetchAnalyticsSummary(
        range: _range,
        start: _range == TfPeriodWithCalendar.customValue && start != null
            ? start.toUtc().toIso8601String()
            : null,
        end: _range == TfPeriodWithCalendar.customValue && end != null
            ? DateTime(
                end.year,
                end.month,
                end.day,
                23,
                59,
                59,
              ).toUtc().toIso8601String()
            : null,
      );
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

  void _setRange(String range, DateTime? start, DateTime? end) {
    if (range == _range && start == _rangeStart && end == _rangeEnd) return;
    setState(() {
      _range = range;
      _rangeStart = start;
      _rangeEnd = end;
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
              title: widget.reduced ? text.salesSummary : text.analyticsTab,
              onNavigateToOrders: widget.onNavigateToOrders,
              onNavigateToTarget: widget.onNavigateToTarget,
            ),
            if (!widget.reduced) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: TfPeriodWithCalendar(
                  options: [
                    ('today', text.rangeToday),
                    ('week', text.range7Days),
                    ('month', text.range30Days),
                  ],
                  value: _range,
                  start: _rangeStart,
                  end: _rangeEnd,
                  onChanged: _setRange,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TfTabs(
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
            ],
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
                      children: widget.reduced
                          ? _reducedSummary(context, text, data)
                          : (_tab == 0
                                ? _salesBreakdown(context, text, data)
                                : _itemWise(context, text, data)),
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
        _analyticsKpiGrid(context, text, d),
        if (d.otherIncome != 0)
          Padding(
            padding: const EdgeInsets.only(top: PosSpacing.sp2),
            child: TfText(
              text.otherIncomeNote,
              style: TfTextStyles.label.copyWith(
                fontWeight: FontWeight.w400,
                color: PosColors.muted,
              ),
            ),
          ),
        const SizedBox(height: PosSpacing.sp3),
        _collectionSection(context, text, d),
        const SizedBox(height: PosSpacing.sp3),
        if (d.serviceWise.any((s) => s.value > 0)) ...[
          _ServiceWiseChartCard(rows: d.serviceWise, text: text),
          const SizedBox(height: PosSpacing.sp3),
        ],
        _serviceWiseSection(context, text, d),
        const SizedBox(height: PosSpacing.sp3),
        TfStatStrip(
          title:
              '${text.costOfGoodsSold} (${tfFormatCurrency(context, d.profit.preparationCost + d.profit.wastage + d.profit.paymentFee)})',
          cells: [
            TfStatCell(
              label: text.preparationCost,
              value: tfFormatCurrency(context, d.profit.preparationCost),
            ),
            TfStatCell(
              label: text.wastage,
              value: tfFormatCurrency(context, d.profit.wastage),
            ),
            TfStatCell(
              label: text.paymentFee,
              value: tfFormatCurrency(context, d.profit.paymentFee),
            ),
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
        _PopularDishes(dishes: d.popular, text: text),
        const SizedBox(height: PosSpacing.sp4),
        _ExportRow(
          onPdf: () => _exportPdf(context, text, d),
          onCsv: () => _exportCsv(context, text, d),
          text: text,
        ),
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

  /// Headline KPI cells. Core figures (orders, gross, net, collection) always
  /// show; auxiliary money figures hide when zero so dataless metrics never
  /// spend screen space (zero policy, one-language pass).
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
      TfButton(
        label: text.downloadExcel,
        variant: TfButtonVariant.ghost,
        icon: Icons.table_view_outlined,
        onPressed: () => _exportItemsCsv(context, text, d),
      ),
    ];
  }

  List<Widget> _diagnosticWidgets() {
    if (!_analyticsDiagnosticsEnabled) return const [];
    final message = _lastDiagnostics;
    if (message == null || message.trim().isEmpty) return const [];
    return [
      TfCard(
        padding: const EdgeInsets.all(PosSpacing.sp3),
        child: Text(
          message,
          style: TfTextStyles.label.copyWith(
            fontFamily: 'JetBrains Mono',
            fontWeight: FontWeight.w400,
            color: PosColors.muted,
          ),
        ),
      ),
      const SizedBox(height: PosSpacing.sp3),
    ];
  }

  // -------------------------------------------------------------------------
  // Shared report sections (owner Sales Breakdown + manager reduced summary).
  // -------------------------------------------------------------------------
  ReportSection _salesSummarySection(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) {
    return ReportSection(
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
    );
  }

  ReportSection _collectionSection(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) {
    return ReportSection(
      title: text.collectionSummary,
      rows: d.collection.isEmpty
          ? [ReportRow(text.noData, tfFormatCurrency(context, 0))]
          : [
              for (final c in d.collection)
                ReportRow(c.label, tfFormatCurrency(context, c.value)),
            ],
    );
  }

  ReportSection _serviceWiseSection(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) {
    return ReportSection(
      title: text.serviceWiseSales,
      rows: d.serviceWise.isEmpty
          ? [ReportRow(text.noData, tfFormatCurrency(context, 0))]
          : [
              for (final s in d.serviceWise)
                ReportRow(s.label, tfFormatCurrency(context, s.value)),
            ],
    );
  }

  // -------------------------------------------------------------------------
  // Manager "Sales Summary" — reduced today-only cut (no profit/charts/tabs).
  // -------------------------------------------------------------------------
  List<Widget> _reducedSummary(
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
    return [
      ..._diagnosticWidgets(),
      const SizedBox(height: 4),
      _Eyebrow(text: text),
      const SizedBox(height: 10),
      _reducedStatGrid(context, text, d),
      const SizedBox(height: PosSpacing.sp3),
      _salesSummarySection(context, text, d),
      const SizedBox(height: PosSpacing.sp3),
      _collectionSection(context, text, d),
      const SizedBox(height: PosSpacing.sp3),
      _serviceWiseSection(context, text, d),
      const SizedBox(height: PosSpacing.sp3),
      _PopularDishes(dishes: d.popular, text: text, limit: 5),
    ];
  }

  /// 4-card 2×2 headline stat grid for the reduced manager cut.
  Widget _reducedStatGrid(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) {
    final tiles = [
      _StatTile(
        tint: PosColors.tintBlue,
        iconColor: PosColors.iconBlue,
        icon: Icons.receipt_long_rounded,
        value: tfFormatNumber(context, d.ordersCompleted),
        label: text.ordersCompleted,
      ),
      _StatTile(
        tint: PosColors.tintAmber,
        iconColor: PosColors.iconAmber,
        icon: Icons.sell_rounded,
        value: tfFormatCurrency(context, d.grossSales),
        label: text.grossSales,
      ),
      _StatTile(
        tint: PosColors.tintGreen,
        iconColor: PosColors.iconGreen,
        icon: Icons.trending_up_rounded,
        value: tfFormatCurrency(context, d.netSales),
        label: text.netSales,
      ),
      _StatTile(
        tint: PosColors.tintPurple,
        iconColor: PosColors.iconPurple,
        icon: Icons.account_balance_wallet_rounded,
        value: tfFormatCurrency(context, d.totalCollection),
        label: text.totalCollection,
      ),
    ];
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: PosSpacing.sp3),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: PosSpacing.sp3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: PosSpacing.sp3),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }

  /// 6-card 2×3 headline KPI grid for the analytics Sales Breakdown tab.
  Widget _analyticsKpiGrid(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) {
    final tiles = [
      _StatTile(
        tint: PosColors.tintBlue,
        iconColor: PosColors.iconBlue,
        icon: Icons.receipt_long_rounded,
        value: tfFormatNumber(context, d.ordersCompleted),
        label: text.ordersCompleted,
      ),
      _StatTile(
        tint: PosColors.tintGreen,
        iconColor: PosColors.iconGreen,
        icon: Icons.trending_up_rounded,
        value: tfFormatCurrency(context, d.netSales),
        label: text.netSales,
      ),
      _StatTile(
        tint: PosColors.tintPurple,
        iconColor: PosColors.iconPurple,
        icon: Icons.account_balance_wallet_rounded,
        value: tfFormatCurrency(context, d.totalCollection),
        label: text.totalCollection,
      ),
      _StatTile(
        tint: PosColors.tintAmber,
        iconColor: PosColors.iconAmber,
        icon: Icons.delivery_dining_rounded,
        value: tfFormatCurrency(context, d.profit.deliveryCharge),
        label: text.deliveryCharge,
      ),
      _StatTile(
        tint: PosColors.tintRed,
        iconColor: PosColors.iconRed,
        icon: Icons.discount_rounded,
        value: tfFormatCurrency(context, d.discountAndCommission),
        label: text.discountAndCommission,
      ),
      _StatTile(
        tint: const Color(0xFFE0F2F1),
        iconColor: const Color(0xFF00796B),
        icon: Icons.receipt_rounded,
        value: tfFormatCurrency(context, d.taxAndDuty),
        label: text.taxAndDuty,
      ),
    ];
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: PosSpacing.sp3),
            Expanded(child: tiles[1]),
            const SizedBox(width: PosSpacing.sp3),
            Expanded(child: tiles[2]),
          ],
        ),
        const SizedBox(height: PosSpacing.sp3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[3]),
            const SizedBox(width: PosSpacing.sp3),
            Expanded(child: tiles[4]),
            const SizedBox(width: PosSpacing.sp3),
            Expanded(child: tiles[5]),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // PDF / Excel export (owner Analytics only; reuses the Reports helper).
  // -------------------------------------------------------------------------
  Future<void> _exportPdf(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) async {
    String c(double v) => tfFormatCurrency(context, v);
    await ReportExport.sharePdf(
      title: text.salesBreakdownReport,
      subtitle: AppScope.read(context).outletName,
      sections: [
        (
          text.salesSummary,
          [
            (text.ordersCompleted, '${d.ordersCompleted}'),
            (text.grossSales, c(d.grossSales)),
            (text.discountByStaff, c(d.discountByStaff)),
            (text.netSales, c(d.netSales)),
          ],
        ),
        (
          text.collectionSummary,
          [for (final r in d.collection) (r.label, c(r.value))],
        ),
        (
          text.serviceWiseSales,
          [for (final r in d.serviceWise) (r.label, c(r.value))],
        ),
        (
          text.profitEstimation,
          [
            (text.netSales, c(d.profit.netSales)),
            (text.serviceCharge, c(d.profit.serviceCharge)),
            (text.deliveryCharge, c(d.profit.deliveryCharge)),
            (text.preparationCost, c(d.profit.preparationCost)),
            (text.wastage, c(d.profit.wastage)),
            (text.paymentFee, c(d.profit.paymentFee)),
            (text.taxesIncl, c(d.profit.taxes)),
            (text.grossProfit, c(d.profit.grossProfit)),
          ],
        ),
      ],
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) async {
    String c(double v) => tfFormatCurrency(context, v);
    await ReportExport.copyCsv([
      [text.salesBreakdownReport, ''],
      [text.ordersCompleted, '${d.ordersCompleted}'],
      [text.grossSales, c(d.grossSales)],
      [text.netSales, c(d.netSales)],
      [text.grossProfit, c(d.profit.grossProfit)],
      for (final r in d.serviceWise) [r.label, c(r.value)],
    ]);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(text.downloadExcel)));
    }
  }

  Future<void> _exportItemsCsv(
    BuildContext context,
    AppStrings text,
    AnalyticsSummaryData d,
  ) async {
    String c(double v) => tfFormatCurrency(context, v);
    final rows = <List<String>>[
      [text.itemName, text.avgUnitPrice, text.totalPrice],
    ];
    for (final cat in d.itemWise) {
      rows.add(['${cat.category} (${cat.units})', '', c(cat.totalPrice)]);
      for (final item in cat.items) {
        rows.add([
          '${item.name} (${item.units})',
          c(item.avgUnitPrice),
          c(item.totalPrice),
        ]);
      }
    }
    await ReportExport.copyCsv(rows);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(text.downloadExcel)));
    }
  }
}

/// "TODAY'S SALES · {date}" muted eyebrow above the reduced manager summary.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text});
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(DateTime.now());
    return TfText(
      '${text.todaysSales} · $date',
      style: TfTextStyles.eyebrow.copyWith(color: PosColors.muted),
    );
  }
}

/// Ghost PDF + Excel export pair for the owner Sales Breakdown tab.
class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.onPdf,
    required this.onCsv,
    required this.text,
  });
  final VoidCallback onPdf;
  final VoidCallback onCsv;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TfButton(
            label: text.downloadPdf,
            variant: TfButtonVariant.ghost,
            icon: Icons.picture_as_pdf_outlined,
            onPressed: onPdf,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TfButton(
            label: text.downloadExcel,
            variant: TfButtonVariant.ghost,
            icon: Icons.table_view_outlined,
            onPressed: onCsv,
          ),
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
  const _PopularDishes({required this.dishes, required this.text, this.limit});
  final List<AnalyticsDish> dishes;
  final AppStrings text;

  /// Cap the ranked list to the top N (null = show all).
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final shown = limit == null
        ? dishes
        : dishes.take(limit!).toList(growable: false);
    return TfCard(
      padding: const EdgeInsets.fromLTRB(
        PosDensity.cardPad,
        PosDensity.cardPad,
        PosDensity.cardPad,
        PosSpacing.sp1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TfText(
            text.popularDishes,
            style: TfTextStyles.cardTitle.copyWith(color: PosColors.text),
          ),
          const SizedBox(height: PosSpacing.sp1),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PosSpacing.sp3),
              child: TfText(
                text.noData,
                style: TfTextStyles.bodyMuted,
              ),
            )
          else
            for (final dish in shown)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: PosColors.line)),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: PosDensity.cardPad,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TfText(
                        dish.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TfTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: PosColors.text,
                        ),
                      ),
                    ),
                    TfText(
                      tfFormatCurrency(context, dish.salesBdt),
                      style: TfTextStyles.rowMoney.copyWith(
                        color: PosColors.text,
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
            padding: const EdgeInsets.symmetric(
              horizontal: PosDensity.cardPad,
              vertical: PosDensity.cardPad,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TfText(
                    '${category.category} (${category.units})',
                    style: TfTextStyles.sectionHeader.copyWith(
                      color: PosColors.text,
                    ),
                  ),
                ),
                TfText(
                  tfFormatCurrency(context, category.totalPrice),
                  style: TfTextStyles.price.copyWith(color: PosColors.text),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PosDensity.cardPad,
            ),
            child: Column(
              children: [
                for (final item in category.items)
                  InkWell(
                    onTap: () => onTapItem(item),
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: PosColors.line)),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: PosDensity.cardPad,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TfText(
                              '${item.name} (${item.units})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TfTextStyles.body.copyWith(
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
                              style: TfTextStyles.rowMoney.copyWith(
                                fontWeight: FontWeight.w500,
                                color: PosColors.muted,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: kReportTotalColWidth,
                            child: TfText(
                              tfFormatCurrency(context, item.totalPrice),
                              textAlign: TextAlign.right,
                              style: TfTextStyles.rowMoney.copyWith(
                                fontWeight: FontWeight.w700,
                                color: PosColors.text,
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
// QS analytics building blocks (charts, drill-down).
// ---------------------------------------------------------------------------

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
      padding: const EdgeInsets.fromLTRB(
        PosSpacing.sp2,
        PosSpacing.sp3,
        PosSpacing.sp2,
        PosDensity.cardPad,
      ),
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
      padding: const EdgeInsets.fromLTRB(
        PosSpacing.sp2,
        PosSpacing.sp3,
        PosSpacing.sp2,
        PosDensity.cardPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: TfText(
              text.serviceWiseSales,
              style: TfTextStyles.cardTitle.copyWith(color: PosColors.text),
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
                  padding: const EdgeInsets.fromLTRB(
                    PosSpacing.sp2,
                    PosSpacing.sp3,
                    PosSpacing.sp2,
                    PosDensity.cardPad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: TfText(
                          text.performance,
                          style: TfTextStyles.cardTitle.copyWith(
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
                const SizedBox(height: PosSpacing.sp3),
                TfText(
                  text.salesOfLastDays(d.daily.length),
                  style: TfTextStyles.cardTitle.copyWith(
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
                            horizontal: PosDensity.cardPad,
                            vertical: PosDensity.cardPad,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TfText(
                                  _dayLabel(reversed[i].date),
                                  style: TfTextStyles.body.copyWith(
                                    color: PosColors.ink2,
                                  ),
                                ),
                              ),
                              TfText(
                                tfFormatCurrency(context, reversed[i].salesBdt),
                                style: TfTextStyles.rowMoney.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: PosColors.text,
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
