import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../core/widgets/tf_timeframe_selector.dart';
import '../../models/pos_notification.dart';
import 'performance_report_screen.dart';

// ===========================================================================
// Reports hub — the top-level owner Reports tab. A strict launcher: the
// Performance Report plus order-bucket summary cards (Success · Cancelled ·
// Complimentary · Payment Information) from /reports/order-buckets. Sales
// Breakdown & Item-wise live on the Analytics tab, not here.
// ===========================================================================
class ReportsHubScreen extends StatefulWidget {
  const ReportsHubScreen({this.onNavigateToTarget, super.key});

  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen> {
  String _range = 'today';
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  Future<_Buckets>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_Buckets> _load() async {
    final app = AppScope.read(context);
    final custom = _range == TfPeriodWithCalendar.customValue;
    final start = _rangeStart;
    final end = _rangeEnd;
    final json = await app.fetchOrderBuckets(
      range: _range,
      start: custom && start != null ? start.toUtc().toIso8601String() : null,
      end: custom && end != null
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
    return _Buckets.fromJson(json);
  }

  void _setRange(String r, DateTime? start, DateTime? end) {
    if (r == _range && start == _rangeStart && end == _rangeEnd) return;
    setState(() {
      _range = r;
      _rangeStart = start;
      _rangeEnd = end;
      _future = _load();
    });
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final ranges = <(String, String)>[
      ('today', text.rangeToday),
      ('week', text.range7Days),
      ('month', text.range30Days),
    ];
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TfGlobalTopBar(
              title: text.reports,
              subtitle: text.reportsHubSubtitle,
              onNavigateToTarget: widget.onNavigateToTarget,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TfPeriodWithCalendar(
                options: ranges,
                value: _range,
                start: _rangeStart,
                end: _rangeEnd,
                onChanged: _setRange,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                children: [
                  _LaunchCard(
                    icon: Icons.insights_outlined,
                    tint: PosColors.tintGreen,
                    iconColor: PosColors.iconGreen,
                    title: text.performanceReport,
                    subtitle: text.performanceReportHint,
                    onTap: () => _push(const PerformanceReportScreen()),
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<_Buckets>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: TfLoading(),
                        );
                      }
                      if (snap.hasError || snap.data == null) {
                        return const SizedBox.shrink();
                      }
                      final b = snap.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final entry in _bucketCards(text, b)) ...[
                            entry,
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _bucketCards(AppStrings text, _Buckets b) {
    final labels = <String, String>{
      'success': text.successOrders,
      'cancelled': text.cancelledOrders,
      'complimentary': text.complimentaryOrders,
    };
    final cards = <Widget>[
      for (final bucket in b.buckets)
        _AmountCard(
          title: labels[bucket.key] ?? bucket.label,
          amount: bucket.total,
          count: bucket.count,
          text: text,
        ),
    ];
    final paymentTotal = b.payments.fold<double>(0, (s, p) => s + p.total);
    cards.add(
      _AmountCard(
        title: text.paymentInformation,
        amount: paymentTotal,
        count: null,
        text: text,
      ),
    );
    return cards;
  }
}

class _LaunchCard extends StatelessWidget {
  const _LaunchCard({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfText(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: PosColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TfText(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PosColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: PosColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.title,
    required this.amount,
    required this.count,
    required this.text,
  });

  final String title;
  final double amount;
  final int? count;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: PosColors.neutralSoft,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(height: 2),
                  TfText(
                    '${text.ordersCount}: ${tfFormatNumber(context, count!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: PosColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TfText(
            tfFormatCurrency(context, amount),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: PosColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Buckets {
  _Buckets({required this.buckets, required this.payments});
  final List<_Bucket> buckets;
  final List<_Bucket> payments;

  factory _Buckets.fromJson(Map<String, Object?> json) {
    List<_Bucket> parse(Object? raw) => ((raw as List?) ?? const [])
        .whereType<Map>()
        .map(
          (m) => _Bucket(
            key: (m['key'] ?? '').toString(),
            label: (m['label'] ?? '').toString(),
            count: (m['count'] as num?)?.toInt() ?? 0,
            total: (m['totalBdt'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false);
    return _Buckets(
      buckets: parse(json['buckets']),
      payments: parse(json['payments']),
    );
  }
}

class _Bucket {
  const _Bucket({
    required this.key,
    required this.label,
    required this.count,
    required this.total,
  });
  final String key;
  final String label;
  final int count;
  final double total;
}
