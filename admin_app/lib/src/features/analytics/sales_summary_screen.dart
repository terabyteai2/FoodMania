import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/report_section.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/analytics_summary_data.dart';
import '../../models/pos_notification.dart';

// ===========================================================================
// Manager "Sales Summary" — today's core sales figures (spec Part B §10A).
// A focused, role-accessible cut of the owner Analytics "Sales Breakdown":
// Orders Completed · Gross Sales · Discount (deduction) · Net Sales, for today.
// Backed by GET /outlets/{id}/analytics/summary?range=today.
// ===========================================================================

const bool _analyticsDiagnosticsEnabled = bool.fromEnvironment(
  'QB_ANALYTICS_DIAG',
);

class SalesSummaryScreen extends StatefulWidget {
  const SalesSummaryScreen({
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    super.key,
  });

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<SalesSummaryScreen> createState() => _SalesSummaryScreenState();
}

class _SalesSummaryScreenState extends State<SalesSummaryScreen> {
  Future<AnalyticsSummaryData>? _future;
  String? _lastDiagnostics;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<AnalyticsSummaryData> _load() async {
    final app = AppScope.read(context);
    final prefix =
        'range=today cloudReady=${app.isCloudReady} canSync=${app.cloudConfig.canSync}';
    try {
      final json = await app.fetchAnalyticsSummary(range: 'today');
      final data = AnalyticsSummaryData.fromJson(json);
      _recordDiagnostics('$prefix ${data.diagnosticSummary}');
      return data;
    } catch (error, stack) {
      _recordDiagnostics('$prefix error=${error.runtimeType}: $error');
      developer.log(
        'Sales Summary load failed',
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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return AppScaffold(
      title: text.salesSummary,
      headerWidget: AppPageHeader(
        title: text.salesSummary,
        onNavigateToOrders: widget.onNavigateToOrders,
        onNavigateToTarget: widget.onNavigateToTarget,
      ),
      pinHeader: true,
      fillBody: true,
      child: FutureBuilder<AnalyticsSummaryData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const TfLoading();
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
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
          final d = snap.data!;
          return RefreshIndicator(
            color: PosColors.primary,
            onRefresh: () async {
              final f = _load();
              setState(() => _future = f);
              await f;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
              children: [
                ..._diagnosticWidgets(),
                _Eyebrow(text: text),
                const SizedBox(height: 10),
                _HeadlineStats(summary: d, text: text),
                const SizedBox(height: PosSpacing.sp3),
                ReportSection(
                  title: text.salesSummary,
                  rows: [
                    ReportRow(
                      text.ordersCompleted,
                      tfFormatNumber(context, d.ordersCompleted),
                    ),
                    ReportRow(
                      text.grossSales,
                      tfFormatCurrency(context, d.grossSales),
                    ),
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
                            ReportRow(
                              c.label,
                              tfFormatCurrency(context, c.value),
                            ),
                        ],
                ),
                const SizedBox(height: PosSpacing.sp3),
                ReportSection(
                  title: text.serviceWiseSales,
                  rows: d.serviceWise.isEmpty
                      ? [ReportRow(text.noData, tfFormatCurrency(context, 0))]
                      : [
                          for (final s in d.serviceWise)
                            ReportRow(
                              s.label,
                              tfFormatCurrency(context, s.value),
                            ),
                        ],
                ),
                const SizedBox(height: PosSpacing.sp3),
                _PopularDishesCard(dishes: d.popular, text: text),
              ],
            ),
          );
        },
      ),
    );
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

/// "TODAY'S SALES · {date}" muted eyebrow above the report card.
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
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: PosColors.muted,
      ),
    );
  }
}

/// 2×2 headline stat-tile grid (QS stat cards): Orders Completed · Gross Sales
/// · Net Sales · Total Collection, each a tint-circle icon + big tabular number.
class _HeadlineStats extends StatelessWidget {
  const _HeadlineStats({required this.summary, required this.text});
  final AnalyticsSummaryData summary;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(
        tint: PosColors.tintBlue,
        iconColor: PosColors.iconBlue,
        icon: Icons.receipt_long_rounded,
        value: tfFormatNumber(context, summary.ordersCompleted),
        label: text.ordersCompleted,
      ),
      _StatTile(
        tint: PosColors.tintAmber,
        iconColor: PosColors.iconAmber,
        icon: Icons.sell_rounded,
        value: tfFormatCurrency(context, summary.grossSales),
        label: text.grossSales,
      ),
      _StatTile(
        tint: PosColors.tintGreen,
        iconColor: PosColors.iconGreen,
        icon: Icons.trending_up_rounded,
        value: tfFormatCurrency(context, summary.netSales),
        label: text.netSales,
      ),
      _StatTile(
        tint: PosColors.tintPurple,
        iconColor: PosColors.iconPurple,
        icon: Icons.account_balance_wallet_rounded,
        value: tfFormatCurrency(context, summary.totalCollection),
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
}

/// QS stat tile: tint-circle icon top-left, big tabular number, muted label.
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

/// Popular Dishes ranked list (spec §11): bold header, then top sellers
/// name-left / sales-right with hairline dividers.
class _PopularDishesCard extends StatelessWidget {
  const _PopularDishesCard({required this.dishes, required this.text});
  final List<AnalyticsDish> dishes;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final top = dishes.take(5).toList(growable: false);
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
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TfText(
                text.noData,
                style: const TextStyle(color: PosColors.muted, fontSize: 13),
              ),
            )
          else
            for (final dish in top)
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
