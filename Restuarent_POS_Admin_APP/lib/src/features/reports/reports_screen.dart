import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
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
    final report = app.salesReportForDays(_days);
    return AppScaffold(
      title: 'Reports',
      subtitle: 'Sales, orders, and PDF export.',
      showDatePill: false,
      centerHeader: true,
      actions: [
        PrimaryButton(
          label: 'Export PDF',
          icon: Icons.picture_as_pdf_outlined,
          busy: _exporting,
          onPressed: report.totalOrders == 0 ? null : () => _sharePdf(report),
        ),
        PrimaryButton(
          label: 'Print',
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
              title: 'No orders in this period',
              message:
                  'Orders will appear here after customers or staff create them.',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Print failed: $error')));
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(6),
        child: SegmentedButton<int>(
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          segments: [
            ButtonSegment(
              value: 1,
              label: Text('1 Day'),
              icon: Icon(Icons.today_outlined, size: 15),
            ),
            ButtonSegment(
              value: 7,
              label: Text('7 Days'),
              icon: Icon(Icons.date_range_outlined, size: 15),
            ),
            ButtonSegment(
              value: 30,
              label: Text('30 Days'),
              icon: Icon(Icons.calendar_month_outlined, size: 15),
            ),
          ],
          selected: {value},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
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
              label: 'Total sales',
              value: currency.format(report.totalSales),
              icon: Icons.payments_outlined,
            ),
            _ReportTile(
              label: 'Orders',
              value: report.totalOrders.toString(),
              icon: Icons.receipt_long_outlined,
            ),
            _ReportTile(
              label: 'Avg order',
              value: currency.format(report.averageOrderValue),
              icon: Icons.trending_up_outlined,
            ),
            _ReportTile(
              label: 'Items sold',
              value: report.totalItemsSold.toString(),
              icon: Icons.local_dining_outlined,
            ),
            _ReportTile(
              label: 'Open',
              value: report.openOrders.toString(),
              icon: Icons.pending_actions_outlined,
            ),
            _ReportTile(
              label: 'Completed',
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
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
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: PosColors.slate,
                      fontWeight: FontWeight.w800,
                      fontSize: 8.7,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PosColors.slate,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      title: 'Daily breakdown',
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
      title: 'Top selling items',
      icon: Icons.emoji_events_outlined,
      child: report.topItems.isEmpty
          ? Text(
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
    return Card(
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: PosColors.primary, size: 17),
                SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    color: PosColors.slate,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            child,
          ],
        ),
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
                Text(
                  title,
                  style: TextStyle(
                    color: PosColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              color: PosColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
