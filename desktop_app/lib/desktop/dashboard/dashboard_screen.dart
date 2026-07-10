import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/analytics_summary_data.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import '../theme/desk_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const Text('Dashboard',
              style: TextStyle(fontSize: DeskTypography.displayPushed, fontWeight: FontWeight.w800)),
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
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            color: PosColors.ink2,
            onPressed: () => setState(_reload),
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
          Icon(Icons.dashboard_rounded, size: 40, color: PosColors.muted),
          const SizedBox(height: 12),
          const Text('No sales in this period',
              style: TextStyle(fontSize: DeskTypography.h3, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Pick a wider range to see trends.',
              style: TextStyle(fontSize: DeskTypography.body, color: PosColors.muted)),
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
          const Icon(Icons.cloud_off_rounded, size: 40, color: PosColors.muted),
          const SizedBox(height: 12),
          const Text('Dashboard unavailable',
              style: TextStyle(fontSize: DeskTypography.h3, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SizedBox(
            width: 380,
            child: Text(clean,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: DeskTypography.body, color: PosColors.muted)),
          ),
          const SizedBox(height: 16),
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
    final dineIn = d.serviceWise
        .where((r) => r.label.toLowerCase().contains('dine'))
        .fold<double>(0, (s, r) => s + r.value);
    final takeaway = d.serviceWise
        .where((r) => r.label.toLowerCase().contains('take') ||
            r.label.toLowerCase().contains('parcel'))
        .fold<double>(0, (s, r) => s + r.value);
    final delivery = d.serviceWise
        .where((r) => r.label.toLowerCase().contains('deliver'))
        .fold<double>(0, (s, r) => s + r.value);

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
                icon: Icons.payments_rounded,
                label: 'Total Sales',
                value: money(context, d.grossSales),
                accent: PosColors.primary,
                tint: PosColors.primarySoft,
              ),
              DeskStatTile(
                icon: Icons.restaurant_rounded,
                label: 'Dine In',
                value: money(context, dineIn),
                accent: PosColors.warning,
                tint: PosColors.warningSoft,
              ),
              DeskStatTile(
                icon: Icons.shopping_bag_rounded,
                label: 'Take Away',
                value: money(context, takeaway),
                accent: PosColors.channelMessenger,
                tint: PosColors.tintBlue,
              ),
              DeskStatTile(
                icon: Icons.delivery_dining_rounded,
                label: 'Delivery',
                value: money(context, delivery),
                accent: PosColors.success,
                tint: PosColors.successSoft,
              ),
            ],
          ),
          if (d.trend.length > 1) ...[
            const SizedBox(height: DeskMetrics.panelGap),
            DeskCard(
              title: 'Sales Trend',
              trailing: _cardDateRange(),
              child: DeskTrendChart(
                values: [for (final p in d.trend) p.revenue],
                height: 200,
              ),
            ),
          ],
          const SizedBox(height: DeskMetrics.panelGap),
          Wrap(
            spacing: DeskMetrics.panelGap,
            runSpacing: DeskMetrics.panelGap,
            children: [
              if (d.discountByStaff > 0 || d.discountAndCommission > 0)
                DeskCard(
                  width: 380,
                  title: 'Discount',
                  trailing: _cardDateRange(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Discount: ${money(context, d.discountByStaff + d.discountAndCommission)}',
                        style: const TextStyle(
                            fontSize: DeskTypography.title, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      DeskBars(
                        data: [
                          if (d.discountByStaff > 0)
                            DeskDatum('Staff Discount', d.discountByStaff,
                                money(context, d.discountByStaff)),
                          if (d.discountAndCommission > 0)
                            DeskDatum('Commission', d.discountAndCommission,
                                money(context, d.discountAndCommission)),
                        ],
                      ),
                    ],
                  ),
                ),
              if (collection.isNotEmpty)
                DeskCard(
                  width: 420,
                  title: 'Total Sales',
                  trailing: _cardDateRange(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ${money(context, d.totalCollection)}',
                        style: const TextStyle(
                            fontSize: DeskTypography.title, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      for (final r in collection)
                        _paymentRow(r.label, r.value, d.totalCollection),
                    ],
                  ),
                ),
              if (d.taxAndDuty > 0)
                DeskCard(
                  width: 320,
                  title: 'Taxes',
                  trailing: _cardDateRange(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Taxes: ',
                              style: TextStyle(
                                  fontSize: DeskTypography.bodySmall, color: PosColors.ink2)),
                          Text(money(context, d.taxAndDuty),
                              style: const TextStyle(
                                  fontSize: DeskTypography.title, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _taxRow('VAT', d.taxAndDuty * 0.78, PosColors.warning),
                      const SizedBox(height: 8),
                      _taxRow('Service Charge', d.taxAndDuty * 0.22,
                          PosColors.channelMessenger),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardDateRange() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        side: const BorderSide(color: PosColors.lineStrong),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm)),
      ),
      onPressed: () {},
      icon: const Text('6th Feb',
          style: TextStyle(fontSize: DeskTypography.caption, fontWeight: FontWeight.w600)),
      label: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
    );
  }

  Widget _paymentRow(String label, double value, double total) {
    final frac = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(fontSize: DeskTypography.bodySmall, color: PosColors.ink2)),
          ),
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: PosColors.surfaceSunk,
                borderRadius: BorderRadius.circular(PosRadii.xs),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: frac.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: PosColors.channelMessenger,
                    borderRadius: BorderRadius.circular(PosRadii.xs),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(money(context, value),
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: DeskTypography.bodySmall, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _taxRow(String label, double value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: DeskTypography.bodySmall, color: PosColors.ink2)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(PosRadii.pill),
          ),
          child: Text(money(context, value),
              style: const TextStyle(
                  fontSize: DeskTypography.bodySmall, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ],
    );
  }
}
