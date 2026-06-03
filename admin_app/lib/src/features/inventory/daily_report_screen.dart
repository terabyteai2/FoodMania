import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/daily_report.dart';
import 'stock_in_screen.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  Future<DailyReport>? _future;
  final DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() {
    setState(() {
      _future = AppScope.of(context).fetchDailyReport(date: _date);
    });
  }

  void _share(DailyReport report, AppStrings text) {
    final lines = StringBuffer();
    lines.writeln('${text.dailyReport} — ${report.date}');
    lines.writeln(
      '${text.unexplainedVariance}: ৳${report.unexplainedVarianceBdt.toStringAsFixed(0)} '
      '${text.acrossItems(report.varianceItemCount)}',
    );
    for (final row in report.breakdown) {
      lines.writeln(
        '• ${row.nameEn}  ${row.varianceQty > 0 ? '+' : ''}${row.varianceQty.toStringAsFixed(2)} ${row.unit} '
        '(${text.expectedCountedLabel}: ${row.expectedQty.toStringAsFixed(1)} / ${row.actualQty.toStringAsFixed(1)})',
      );
    }
    Clipboard.setData(ClipboardData(text: lines.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TfText(
          text.isBn
              ? 'রিপোর্ট ক্লিপবোর্ডে কপি হয়েছে'
              : 'Report copied to clipboard',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final dateFmt = DateFormat('MMM d');
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TfText(
              text.dailyReport,
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w500,
              ),
            ),
            TfText(
              '${text.isBn ? 'শেয়ার রিপোর্ট' : 'Share report'} · ${dateFmt.format(_date)}',
              style: TextStyle(
                color: PosColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (_future != null)
            FutureBuilder<DailyReport>(
              future: _future,
              builder: (context, snap) {
                final report = snap.data;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: TfButton(
                    label: text.share,
                    icon: Icons.ios_share_rounded,
                    variant: TfButtonVariant.ghost,
                    size: TfButtonSize.sm,
                    fullWidth: false,
                    onPressed: report == null
                        ? null
                        : () => _share(report, text),
                  ),
                );
              },
            ),
        ],
      ),
      body: FutureBuilder<DailyReport>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: TfText(
                  snapshot.error.toString(),
                  style: TextStyle(color: PosColors.danger),
                ),
              ),
            );
          }
          final report = snapshot.data!;
          return RefreshIndicator(
            color: PosColors.primaryDark,
            backgroundColor: PosColors.primary,
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _AlertCard(report: report, text: text),
                const SizedBox(height: 18),
                _ReportSnapshot(report: report),
                const SizedBox(height: 18),
                TfSectionHeader(
                  label: text.varianceBreakdown,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                if (report.breakdown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: TfText(
                      text.isBn
                          ? 'কোনো ভ্যারিয়েন্স নেই।'
                          : 'No variance — everything balances.',
                      style: TextStyle(color: PosColors.muted),
                    ),
                  )
                else
                  for (final row in report.breakdown)
                    _BreakdownCard(row: row, text: text),
                if (report.reorderSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  for (final r in report.reorderSuggestions)
                    _ReorderCta(suggestion: r, text: text),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportSnapshot extends StatelessWidget {
  const _ReportSnapshot({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TfSectionHeader(
          label: 'STOCK FLOW · TODAY',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        TfCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ReportMetric(
                label: 'STOCK IN',
                value: '+${report.stockFlow.inQty.toStringAsFixed(1)}',
                color: PosColors.success,
              ),
              _ReportMetric(
                label: 'USED',
                value: '−${report.stockFlow.outQty.toStringAsFixed(1)}',
                color: PosColors.warning,
              ),
              _ReportMetric(
                label: 'SPEND',
                value: fmt.format(report.stockFlow.spendBdt),
              ),
            ],
          ),
        ),
        if (report.revenueSplit.isNotEmpty) ...[
          const SizedBox(height: 18),
          const TfSectionHeader(
            label: 'REVENUE SPLIT',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          TfCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: report.revenueSplit
                  .map(
                    (row) => _ReportMetric(
                      label: row.label.toUpperCase(),
                      value: '${row.pct}%',
                      detail: fmt.format(row.valueBdt),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
        if (report.topSellers.isNotEmpty) ...[
          const SizedBox(height: 18),
          const TfSectionHeader(label: 'TOP SELLERS', padding: EdgeInsets.zero),
          const SizedBox(height: 8),
          TfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: report.topSellers
                  .map(
                    (row) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: PosColors.line, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TfText(
                              row.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TfText(
                            '${row.qty} sold',
                            style: const TextStyle(
                              color: PosColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TfText(
                            fmt.format(row.salesBdt),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    this.detail,
    this.color = PosColors.primaryDark,
  });
  final String label;
  final String value;
  final String? detail;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfText(
          label,
          style: const TextStyle(
            color: PosColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        TfText(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (detail != null)
          TfText(
            detail!,
            style: const TextStyle(color: PosColors.muted, fontSize: 10),
          ),
      ],
    ),
  );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.report, required this.text});

  final DailyReport report;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final variance = report.unexplainedVarianceBdt;
    final isDown = variance < 0;
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final color = isDown ? PosColors.danger : PosColors.success;
    return TfCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: isDown ? PosColors.dangerSoft : PosColors.successSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            '${text.unexplainedVariance.toUpperCase()} · ${text.isBn ? 'আজ' : 'TODAY'}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              letterSpacing: 0,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TfText(
            variance == 0
                ? '৳0'
                : '${isDown ? '−' : '+'}${fmt.format(variance.abs())}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          TfText(
            text.acrossItems(report.varianceItemCount),
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (report.headlineEn.isNotEmpty) ...[
            const SizedBox(height: 8),
            TfText(
              report.headlineEn,
              style: TextStyle(
                fontSize: 13,
                color: PosColors.slate,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.row, required this.text});

  final VarianceBreakdown row;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final variance = row.varianceQty;
    final isDown = variance < 0;
    final color = isDown ? PosColors.danger : PosColors.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TfCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TfText(
                        row.nameEn,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: PosColors.slate,
                        ),
                      ),
                      if (row.nameBn.isNotEmpty)
                        TfText(
                          row.nameBn,
                          style: TextStyle(
                            fontSize: 12,
                            color: PosColors.muted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TfText(
                    '${variance > 0 ? '+' : ''}${variance.toStringAsFixed(1)} ${row.unit}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TfText(
              '${text.expectedCountedLabel}: '
              '${row.expectedQty.toStringAsFixed(1)} ${row.unit} · '
              '${row.actualQty.toStringAsFixed(1)} ${row.unit}',
              style: TextStyle(color: PosColors.muted, fontSize: 12),
            ),
            if (row.recurringWeeks >= 2) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: PosColors.warning.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TfText(
                      text.recurringWeeks(row.recurringWeeks),
                      style: TextStyle(
                        color: PosColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (row.noteEn.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TfText(
                        row.noteEn,
                        style: TextStyle(
                          color: PosColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReorderCta extends StatelessWidget {
  const _ReorderCta({required this.suggestion, required this.text});

  final ReorderSuggestion suggestion;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockInScreen(preseedItemId: suggestion.itemId),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: PosColors.warningSoft,
            borderRadius: BorderRadius.circular(PosRadii.md),
            border: Border.all(
              color: PosColors.warning.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: PosColors.warning,
                  borderRadius: BorderRadius.circular(PosRadii.xs),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfSectionHeader(
                      label: text.reorderSuggestion,
                      color: PosColors.warning,
                      padding: EdgeInsets.zero,
                    ),
                    TfText(
                      suggestion.ctaEn,
                      style: TextStyle(
                        color: PosColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PosColors.warning),
            ],
          ),
        ),
      ),
    );
  }
}
