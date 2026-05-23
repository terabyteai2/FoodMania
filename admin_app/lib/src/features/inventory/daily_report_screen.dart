import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
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
        content: Text(
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
            Text(
              text.dailyReport,
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${text.isBn ? 'শেয়ার রিপোর্ট' : 'Share report'} · ${dateFmt.format(_date)}',
              style: TextStyle(
                color: PosColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
                return TextButton.icon(
                  onPressed: report == null
                      ? null
                      : () => _share(report, text),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(text.share),
                  style: TextButton.styleFrom(
                    foregroundColor: PosColors.slate,
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
                child: Text(
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
                Text(
                  text.varianceBreakdown.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                    color: PosColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                if (report.breakdown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${text.unexplainedVariance.toUpperCase()} · ${text.isBn ? 'আজ' : 'TODAY'}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            variance == 0
                ? '৳0'
                : '${isDown ? '−' : '+'}${fmt.format(variance.abs())}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text.acrossItems(report.varianceItemCount),
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (report.headlineEn.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              report.headlineEn,
              style: TextStyle(
                fontSize: 13,
                color: PosColors.slate,
                fontWeight: FontWeight.w700,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.nameEn,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: PosColors.slate,
                      ),
                    ),
                    if (row.nameBn.isNotEmpty)
                      Text(
                        row.nameBn,
                        style: TextStyle(
                          fontSize: 12,
                          color: PosColors.muted,
                          fontWeight: FontWeight.w600,
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
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${variance > 0 ? '+' : ''}${variance.toStringAsFixed(1)} ${row.unit}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
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
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    text.recurringWeeks(row.recurringWeeks),
                    style: TextStyle(
                      color: PosColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (row.noteEn.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.noteEn,
                      style: TextStyle(
                        color: PosColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
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
            color: PosColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: PosShadows.glow,
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: PosColors.primaryDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.reorderSuggestion.toUpperCase(),
                      style: TextStyle(
                        color: PosColors.primaryDark.withValues(alpha: 0.7),
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      suggestion.ctaEn,
                      style: TextStyle(
                        color: PosColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: PosColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}
