import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/analytics_summary_data.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';

/// Owner analytics (petpooja18–20 content): headline KPIs, revenue trend,
/// collection + service-wise split, profit estimate and popular dishes. Reuses
/// the reduced-vocabulary backend (Gross/Net Sales, Collection, Prep Cost,
/// Wastage, Gross Profit). Missing metrics are hidden, never zero-filled.
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
          _segment(),
        ],
      ),
    );
  }

  Widget _segment() {
    const options = [('today', 'Today'), ('week', '7 days'), ('month', '30 days')];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in options)
            GestureDetector(
              onTap: () => _setRange(value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _range == value ? PosColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _range == value
                            ? Colors.white
                            : PosColors.ink2)),
              ),
            ),
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
          Text('Analytics unavailable',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _stat('Orders', '${d.ordersCompleted}'),
              _stat('Gross sales', money(context, d.grossSales)),
              _stat('Net sales', money(context, d.netSales)),
              _stat('Collection', money(context, d.totalCollection)),
            ],
          ),
          if (d.trend.length > 1) ...[
            const SizedBox(height: 22),
            _panel('Revenue trend', _trend(d.trend)),
          ],
          const SizedBox(height: 22),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (d.collection.isNotEmpty)
                _panel('Collection', _moneyRows(d.collection), width: 320),
              if (d.serviceWise.isNotEmpty)
                _panel('Service-wise sales', _moneyRows(d.serviceWise),
                    width: 320),
              if (d.popular.isNotEmpty)
                _panel('Popular dishes', _dishes(d.popular), width: 320),
              _panel('Profit estimate', _profit(d.profit), width: 320),
            ],
          ),
        ],
      ),
    );
  }

  // ── pieces ──
  Widget _stat(String label, String value) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: _deco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: PosColors.primaryDark)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, color: PosColors.muted)),
        ],
      ),
    );
  }

  Widget _panel(String title, Widget child, {double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: _deco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _moneyRows(List<AnalyticsMoneyRow> rows) {
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(r.label, style: TextStyle(color: PosColors.ink2)),
                const Spacer(),
                Text(money(context, r.value),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dishes(List<AnalyticsDish> dishes) {
    return Column(
      children: [
        for (final dish in dishes.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: PosColors.ink2)),
                ),
                Text(money(context, dish.salesBdt),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
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

  Widget _trend(List<AnalyticsTrendPoint> points) {
    final maxRev =
        points.map((p) => p.revenue).fold<double>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: maxRev <= 0
                          ? 2
                          : (110 * (p.revenue / maxRev)).clamp(2, 110),
                      decoration: BoxDecoration(
                        color: PosColors.primary,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _deco() => BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
        boxShadow: PosShadows.soft,
      );
}
