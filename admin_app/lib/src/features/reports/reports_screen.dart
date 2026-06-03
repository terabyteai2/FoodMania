import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/sales_report.dart';
import '../../services/report_pdf_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportPdfService _pdfService = ReportPdfService();
  final NumberFormat _currency = NumberFormat.currency(
    symbol: '৳',
    decimalDigits: 2,
  );
  final DateFormat _date = DateFormat('MMM d');
  int _days = 1;
  bool _exporting = false;
  bool _printing = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final report = app.salesReportForDays(_days);
    return AppScaffold(
      title: text.reports,
      subtitle: text.reportsSubtitle,
      showDatePill: false,
      showBackButton: true,
      centerHeader: true,
      actions: [
        PrimaryButton(
          label: text.exportPdf,
          icon: Icons.picture_as_pdf_outlined,
          busy: _exporting,
          onPressed: report.totalOrders == 0 ? null : () => _sharePdf(report),
        ),
        PrimaryButton(
          label: text.printBillAction,
          icon: Icons.print_outlined,
          secondary: true,
          busy: _printing,
          onPressed: report.totalOrders == 0 ? null : () => _printPdf(report),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PeriodSelector(value: _days, onChanged: _setDays),
          SizedBox(height: 8),
          _ReportSummary(report: report, currency: _currency),
          SizedBox(height: 8),
          if (report.totalOrders == 0)
            EmptyState(
              title: text.noOrdersInThisPeriod,
              message: text.ordersAppearInReports,
              icon: Icons.assessment_outlined,
            )
          else ...[
            _DailyBreakdown(report: report, currency: _currency, date: _date),
            SizedBox(height: 8),
            _TopItems(report: report, currency: _currency),
          ],
        ],
      ),
    );
  }

  void _setDays(int days) {
    if (_days == days) return;
    setState(() => _days = days);
  }

  Future<void> _sharePdf(SalesReport report) async {
    final app = AppScope.of(context);
    setState(() => _exporting = true);
    try {
      await _pdfService.shareSalesReport(
        report: report,
        serverConfig: app.serverConfig,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText('${app.strings.pdfExportFailed}: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _printPdf(SalesReport report) async {
    final app = AppScope.of(context);
    setState(() => _printing = true);
    try {
      await _pdfService.printSalesReport(
        report: report,
        serverConfig: app.serverConfig,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText('${app.strings.printFailed}: $error')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return TfCard(
      padding: EdgeInsets.all(6),
      child: SegmentedButton<int>(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        segments: [
          ButtonSegment(
            value: 1,
            label: TfText(text.oneDay),
            icon: Icon(Icons.today_outlined, size: 15),
          ),
          ButtonSegment(
            value: 7,
            label: TfText(text.sevenDays),
            icon: Icon(Icons.date_range_outlined, size: 15),
          ),
          ButtonSegment(
            value: 30,
            label: TfText(text.thirtyDays),
            icon: Icon(Icons.calendar_month_outlined, size: 15),
          ),
        ],
        selected: {value},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report, required this.currency});

  final SalesReport report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 4
            : constraints.maxWidth >= 620
            ? 3
            : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: constraints.maxWidth >= 620 ? 2.55 : 1.95,
          children: [
            _ReportTile(
              label: text.totalSales,
              value: currency.format(report.totalSales),
              icon: Icons.payments_outlined,
            ),
            _ReportTile(
              label: text.orders,
              value: report.totalOrders.toString(),
              icon: Icons.receipt_long_outlined,
            ),
            _ReportTile(
              label: text.avgOrder,
              value: currency.format(report.averageOrderValue),
              icon: Icons.trending_up_outlined,
            ),
            _ReportTile(
              label: text.itemsSold,
              value: report.totalItemsSold.toString(),
              icon: Icons.local_dining_outlined,
            ),
            _ReportTile(
              label: text.openOrders,
              value: report.openOrders.toString(),
              icon: Icons.pending_actions_outlined,
            ),
            _ReportTile(
              label: text.completed,
              value: report.completedOrders.toString(),
              icon: Icons.done_all,
            ),
          ],
        );
      },
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      clip: true,
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.circular(PosRadii.md),
              border: Border.all(color: PosColors.slate),
            ),
            child: Icon(icon, color: PosColors.slate, size: 16),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfSectionHeader(
                  label: label,
                  color: PosColors.slate,
                  padding: EdgeInsets.zero,
                ),
                SizedBox(height: 3),
                TfText(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosColors.slate,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1,
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

class _DailyBreakdown extends StatelessWidget {
  const _DailyBreakdown({
    required this.report,
    required this.currency,
    required this.date,
  });

  final SalesReport report;
  final NumberFormat currency;
  final DateFormat date;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      title: AppScope.of(context).strings.dailyBreakdown,
      icon: Icons.bar_chart_outlined,
      child: Column(
        children: [
          for (final day in report.dailyBreakdown.reversed)
            _LineRow(
              title: date.format(day.date),
              subtitle: '${day.orders} orders',
              trailing: currency.format(day.sales),
            ),
        ],
      ),
    );
  }
}

class _TopItems extends StatelessWidget {
  const _TopItems({required this.report, required this.currency});

  final SalesReport report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      title: AppScope.of(context).strings.topSellingItems,
      icon: Icons.emoji_events_outlined,
      child: report.topItems.isEmpty
          ? TfText(
              'No item sales yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: [
                for (final item in report.topItems)
                  _LineRow(
                    title: item.name,
                    subtitle: '${item.qty} sold',
                    trailing: currency.format(item.sales),
                  ),
              ],
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PosColors.primary, size: 17),
              SizedBox(width: 7),
              TfText(
                title,
                style: TextStyle(
                  color: PosColors.slate,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  title,
                  style: TextStyle(
                    color: PosColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                SizedBox(height: 2),
                TfText(
                  subtitle,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          TfText(
            trailing,
            style: TextStyle(
              color: PosColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
