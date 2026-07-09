import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/analytics_summary_data.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import '../theme/desk_widgets.dart';

/// Owner analytics, reset to the M3 chart-first language
/// (DESIGN_RESET_REFERENCE.md): KPI tiles, a revenue trend line, a collection
/// donut and service / dish bars, over the real reduced-vocabulary backend
/// (Gross/Net Sales, Collection, Prep Cost, Wastage, Gross Profit). Missing
/// metrics are hidden, never zero-filled.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _range = 'today';
  Future<AnalyticsSummaryData>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<AnalyticsSummaryData> _load() async {
    final app = AppScope.read(context);
    final json = await app.fetchAnalyticsSummary(range: _range);
    return AnalyticsSummaryData.fromJson(json);
  }

  void _setRange(String range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(
          child: FutureBuilder<AnalyticsSummaryData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _error(snap.error.toString());
              }
              final data = snap.data;
              if (data == null) return const SizedBox.shrink();
              if (data.hasNoData) return _empty();
              return _body(data);
            },
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const Text('Analytics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          DeskSegment<String>(
            options: const [
              ('today', 'Today'),
              ('week', '7 days'),
              ('month', '30 days'),
            ],
            value: _range,
            onChanged: _setRange,
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_rounded, size: 34, color: PosColors.muted),
          const SizedBox(height: 10),
          const Text('No sales in this period',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Pick a wider range to see trends.',
              style: TextStyle(fontSize: 12.5, color: PosColors.muted)),
        ],
      ),
    );
  }

  Widget _error(String message) {
    final clean = message.replaceFirst('CloudApiException: ', '');
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 34, color: PosColors.muted),
          const SizedBox(height: 10),
          const Text('Analytics unavailable',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SizedBox(
            width: 360,
            child: Text(clean,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: PosColors.muted)),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => setState(_reload),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _body(AnalyticsSummaryData d) {
    final collection = d.collection.where((r) => r.value > 0).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: DeskMetrics.panelGap,
            runSpacing: DeskMetrics.panelGap,
            children: [
              DeskStatTile(
                icon: Icons.receipt_long_rounded,
                label: 'Orders',
                value: '${d.ordersCompleted}',
              ),
              DeskStatTile(
                icon: Icons.payments_rounded,
                label: 'Gross sales',
                value: money(context, d.grossSales),
              ),
              DeskStatTile(
                icon: Icons.trending_up_rounded,
                label: 'Net sales',
                value: money(context, d.netSales),
              ),
              DeskStatTile(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Collection',
                value: money(context, d.totalCollection),
              ),
            ],
          ),
          if (d.trend.length > 1) ...[
            const SizedBox(height: DeskMetrics.panelGap),
            DeskCard(
              title: 'Revenue trend',
              child: DeskTrendChart(
                values: [for (final p in d.trend) p.revenue],
              ),
            ),
          ],
          const SizedBox(height: DeskMetrics.panelGap),
          Wrap(
            spacing: DeskMetrics.panelGap,
            runSpacing: DeskMetrics.panelGap,
            children: [
              if (collection.isNotEmpty)
                DeskCard(
                  width: 420,
                  title: 'Collection',
                  child: DeskDonut(
                    centerValue: money(context, d.totalCollection),
                    centerLabel: 'collected',
                    data: [
                      for (final r in collection)
                        DeskDatum(r.label, r.value, money(context, r.value)),
                    ],
                  ),
                ),
              if (d.serviceWise.isNotEmpty)
                DeskCard(
                  width: 380,
                  title: 'Service-wise sales',
                  child: DeskBars(
                    data: [
                      for (final r in d.serviceWise)
                        DeskDatum(r.label, r.value, money(context, r.value)),
                    ],
                  ),
                ),
              if (d.popular.isNotEmpty)
                DeskCard(
                  width: 380,
                  title: 'Popular dishes',
                  child: DeskBars(
                    data: [
                      for (final dish in d.popular.take(6))
                        DeskDatum(dish.name, dish.salesBdt,
                            money(context, dish.salesBdt)),
                    ],
                  ),
                ),
              DeskCard(
                width: 360,
                title: 'Profit estimate',
                child: _profit(d.profit),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profit(AnalyticsProfitSummary p) {
    return Column(
      children: [
        _ledger('Net sales', p.netSales),
        _ledger('Service charge', p.serviceCharge),
        _ledger('Delivery charge', p.deliveryCharge),
        _ledger('Prep cost', -p.preparationCost),
        _ledger('Wastage', -p.wastage),
        _ledger('Payment fee', -p.paymentFee),
        _ledger('Taxes', -p.taxes),
        const Divider(height: 18),
        _ledger('Gross profit', p.grossProfit, strong: true),
      ],
    );
  }

  Widget _ledger(String label, double value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: strong ? PosColors.primaryDark : PosColors.ink2,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w400)),
          const Spacer(),
          Text(money(context, value),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: strong
                      ? PosColors.primary
                      : (value < 0 ? PosColors.danger : PosColors.primaryDark))),
        ],
      ),
    );
  }
}
