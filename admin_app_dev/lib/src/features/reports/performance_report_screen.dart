import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_timeframe_selector.dart';
import '../analytics/analytics_screen.dart';
import 'report_export.dart';

// ===========================================================================
// Performance Report (QS) — item-wise performance over a chosen window
// (Daily/Weekly/Monthly · 7/30/90 days), Apply -> results list, each item
// drilling into its daily-sales chart. Backed by /reports/performance.
// ===========================================================================
class PerformanceReportScreen extends StatefulWidget {
  const PerformanceReportScreen({super.key});

  @override
  State<PerformanceReportScreen> createState() =>
      _PerformanceReportScreenState();
}

class _PerformanceReportScreenState extends State<PerformanceReportScreen> {
  String _granularity = 'daily';
  int _days = 30;
  // Custom window: a picked date range maps to start + inclusive day span.
  bool _customWindow = false;
  DateTime? _customStart;
  DateTime? _customEnd;
  Future<List<_PerfRow>>? _future;

  Future<List<_PerfRow>> _load() async {
    final app = AppScope.read(context);
    final start = _customStart;
    final json = await app.fetchPerformanceReport(
      granularity: _granularity,
      days: _days,
      start: _customWindow && start != null
          ? DateTime(
              start.year,
              start.month,
              start.day,
            ).toUtc().toIso8601String()
          : null,
    );
    return ((json['items'] as List?) ?? const [])
        .whereType<Map>()
        .map(_PerfRow.fromJson)
        .toList(growable: false);
  }

  void _setWindow(String value, DateTime? start, DateTime? end) {
    setState(() {
      if (value == TfPeriodWithCalendar.customValue) {
        if (start == null || end == null) return;
        _customWindow = true;
        _customStart = start;
        _customEnd = end;
        _days = end.difference(start).inDays + 1;
      } else {
        _customWindow = false;
        _customStart = null;
        _customEnd = null;
        _days = int.parse(value);
      }
    });
  }

  void _apply() => setState(() => _future = _load());

  void _openItem(_PerfRow r) {
    if (r.menuItemId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDrillDownScreen(
          menuItemId: r.menuItemId,
          name: r.name,
          range: 'month',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(title: Text(text.performanceReport)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            TfText(
              text.performanceReportHint,
              style: const TextStyle(fontSize: 12.5, color: PosColors.muted),
            ),
            const SizedBox(height: PosSpacing.sp3),
            TfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TfText(
                    '${text.daily} / ${text.weekly} / ${text.monthly}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PosColors.muted,
                    ),
                  ),
                  const SizedBox(height: PosSpacing.sp2),
                  TfPeriodSelector(
                    options: [
                      ('daily', text.daily),
                      ('weekly', text.weekly),
                      ('monthly', text.monthly),
                    ],
                    value: _granularity,
                    onChanged: (k) => setState(() => _granularity = k),
                  ),
                  const SizedBox(height: PosSpacing.sp3),
                  TfPeriodWithCalendar(
                    options: [
                      for (final d in [7, 30, 90]) ('$d', '$d ${text.daysLabel}'),
                    ],
                    value: _customWindow
                        ? TfPeriodWithCalendar.customValue
                        : '$_days',
                    start: _customStart,
                    end: _customEnd,
                    onChanged: _setWindow,
                  ),
                  const SizedBox(height: PosSpacing.sp3),
                  TfButton(label: text.apply, onPressed: _apply),
                ],
              ),
            ),
            const SizedBox(height: PosSpacing.sp3),
            if (_future == null)
              const SizedBox.shrink()
            else
              FutureBuilder<List<_PerfRow>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: TfLoading(),
                    );
                  }
                  final rows = snap.data ?? const <_PerfRow>[];
                  if (rows.isEmpty) {
                    return TfEmptyState(
                      title: text.analyticsNoItemsTitle,
                      message: text.analyticsNoItemsMessage,
                      icon: Icons.fastfood_rounded,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TfCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (int i = 0; i < rows.length; i++)
                              InkWell(
                                onTap: () => _openItem(rows[i]),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: i == 0
                                        ? null
                                        : const Border(
                                            top: BorderSide(
                                              color: PosColors.line,
                                            ),
                                          ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TfText(
                                          '${rows[i].name} (${rows[i].qty})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                            color: PosColors.text,
                                          ),
                                        ),
                                      ),
                                      TfText(
                                        tfFormatCurrency(
                                          context,
                                          rows[i].salesBdt,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: PosColors.text,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
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
                          ],
                        ),
                      ),
                      const SizedBox(height: PosSpacing.sp3),
                      TfButton(
                        label: text.downloadExcel,
                        variant: TfButtonVariant.ghost,
                        icon: Icons.table_view_outlined,
                        onPressed: () => _exportCsv(context, text, rows),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    AppStrings text,
    List<_PerfRow> rows,
  ) async {
    await ReportExport.copyCsv([
      [text.itemName, text.noOfOrders, text.totalPrice],
      for (final r in rows) [r.name, '${r.qty}', r.salesBdt.toStringAsFixed(2)],
    ]);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(text.downloadExcel)));
    }
  }
}

class _PerfRow {
  const _PerfRow({
    required this.menuItemId,
    required this.name,
    required this.category,
    required this.qty,
    required this.salesBdt,
  });
  final String menuItemId;
  final String name;
  final String category;
  final int qty;
  final double salesBdt;

  factory _PerfRow.fromJson(Map raw) {
    return _PerfRow(
      menuItemId: (raw['menuItemId'] ?? '').toString(),
      name: (raw['name'] ?? '').toString(),
      category: (raw['category'] ?? '').toString(),
      qty: (raw['qty'] as num?)?.toInt() ?? 0,
      salesBdt: (raw['salesBdt'] as num?)?.toDouble() ?? 0,
    );
  }
}
