import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/report_section.dart';
import '../../core/widgets/tf_design_system.dart';
import 'report_export.dart';

// ===========================================================================
// Sales Breakdown report (QS) — filterable Sales Summary · Collection Summary
// · Service-wise Sales · Profit Estimation, driven by /analytics/summary with
// optional service/payment-mode filters, plus PDF/CSV export.
// ===========================================================================
class SalesBreakdownReportScreen extends StatefulWidget {
  const SalesBreakdownReportScreen({this.range = 'today', super.key});

  final String range;

  @override
  State<SalesBreakdownReportScreen> createState() =>
      _SalesBreakdownReportScreenState();
}

class _SalesBreakdownReportScreenState
    extends State<SalesBreakdownReportScreen> {
  late String _range = widget.range;
  String? _service; // null = all
  String? _payment; // null = all
  Future<_Breakdown>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_Breakdown> _load() async {
    final app = AppScope.read(context);
    final json = await app.fetchAnalyticsSummary(
      range: _range,
      service: _service,
      paymentMethod: _payment,
    );
    return _Breakdown.fromJson(json);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(title: Text(text.salesBreakdownReport)),
      body: SafeArea(
        child: FutureBuilder<_Breakdown>(
          future: _future,
          builder: (context, snap) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _filters(text),
                const SizedBox(height: PosSpacing.sp3),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: TfLoading(),
                  )
                else if (snap.hasError || snap.data == null)
                  TfEmptyState(
                    title: text.analyticsErrorTitle,
                    message: text.analyticsErrorMessage,
                    icon: Icons.cloud_off_rounded,
                  )
                else
                  ..._content(context, text, snap.data!),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filters(AppStrings text) {
    final ranges = <(String, String)>[
      ('today', text.rangeToday),
      ('week', text.range7Days),
      ('month', text.range30Days),
    ];
    return TfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (k, l) in ranges)
                TfChip(
                  label: l,
                  active: _range == k,
                  small: true,
                  onTap: () {
                    if (_range == k) return;
                    setState(() => _range = k);
                    _refresh();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  value: _service,
                  hint: text.allServices,
                  options: const [
                    ('dineIn', 'Dine-in'),
                    ('takeaway', 'Takeaway'),
                    ('delivery', 'Delivery'),
                  ],
                  onChanged: (v) {
                    setState(() => _service = v);
                    _refresh();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Dropdown(
                  value: _payment,
                  hint: text.allPaymentModes,
                  options: const [
                    ('cash', 'Cash'),
                    ('card', 'Card'),
                    ('bkash', 'bKash'),
                    ('nagad', 'Nagad'),
                  ],
                  onChanged: (v) {
                    setState(() => _payment = v);
                    _refresh();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, AppStrings text, _Breakdown d) {
    if (d.hasNoData) {
      return [
        const SizedBox(height: PosSpacing.sp8),
        TfEmptyState(
          title: text.analyticsNoDataTitle,
          message: text.analyticsNoDataMessage,
          icon: Icons.bar_chart_outlined,
        ),
      ];
    }
    return [
      ReportSection(
        title: text.salesSummary,
        rows: [
          ReportRow(
            text.ordersCompleted,
            tfFormatNumber(context, d.ordersCompleted),
          ),
          ReportRow(text.grossSales, tfFormatCurrency(context, d.grossSales)),
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
                  ReportRow(c.label, tfFormatCurrency(context, c.value)),
              ],
      ),
      const SizedBox(height: PosSpacing.sp3),
      ReportSection(
        title: text.serviceWiseSales,
        rows: d.serviceWise.isEmpty
            ? [ReportRow(text.noData, tfFormatCurrency(context, 0))]
            : [
                for (final s in d.serviceWise)
                  ReportRow(s.label, tfFormatCurrency(context, s.value)),
              ],
      ),
      const SizedBox(height: PosSpacing.sp3),
      ReportSection(
        title: text.profitEstimation,
        rows: [
          ReportRow(text.netSales, tfFormatCurrency(context, d.profitNetSales)),
          ReportRow(
            text.serviceCharge,
            tfFormatCurrency(context, d.serviceCharge),
          ),
          ReportRow(
            text.deliveryCharge,
            tfFormatCurrency(context, d.deliveryCharge),
          ),
          ReportRow(
            text.preparationCost,
            parenCurrency(context, d.preparationCost),
            deduction: true,
          ),
          ReportRow(
            text.wastage,
            parenCurrency(context, d.wastage),
            deduction: true,
          ),
          ReportRow(
            text.paymentFee,
            parenCurrency(context, d.paymentFee),
            deduction: true,
          ),
          ReportRow(
            text.taxesIncl,
            parenCurrency(context, d.taxes),
            deduction: true,
          ),
          ReportRow(
            text.grossProfit,
            tfFormatCurrency(context, d.grossProfit),
            bold: true,
            positive: d.grossProfit >= 0,
          ),
        ],
      ),
      const SizedBox(height: PosSpacing.sp4),
      _ExportRow(
        onPdf: () => _exportPdf(context, text, d),
        onCsv: () => _exportCsv(context, text, d),
        text: text,
      ),
    ];
  }

  Future<void> _exportPdf(
    BuildContext context,
    AppStrings text,
    _Breakdown d,
  ) async {
    String c(double v) => tfFormatCurrency(context, v);
    await ReportExport.sharePdf(
      title: text.salesBreakdownReport,
      subtitle: AppScope.read(context).outletName,
      sections: [
        (
          text.salesSummary,
          [
            (text.ordersCompleted, '${d.ordersCompleted}'),
            (text.grossSales, c(d.grossSales)),
            (text.discountByStaff, c(d.discountByStaff)),
            (text.netSales, c(d.netSales)),
          ],
        ),
        (
          text.collectionSummary,
          [for (final r in d.collection) (r.label, c(r.value))],
        ),
        (
          text.serviceWiseSales,
          [for (final r in d.serviceWise) (r.label, c(r.value))],
        ),
        (
          text.profitEstimation,
          [
            (text.netSales, c(d.profitNetSales)),
            (text.serviceCharge, c(d.serviceCharge)),
            (text.deliveryCharge, c(d.deliveryCharge)),
            (text.preparationCost, c(d.preparationCost)),
            (text.wastage, c(d.wastage)),
            (text.paymentFee, c(d.paymentFee)),
            (text.taxesIncl, c(d.taxes)),
            (text.grossProfit, c(d.grossProfit)),
          ],
        ),
      ],
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    AppStrings text,
    _Breakdown d,
  ) async {
    String c(double v) => tfFormatCurrency(context, v);
    await ReportExport.copyCsv([
      [text.salesBreakdownReport, ''],
      [text.ordersCompleted, '${d.ordersCompleted}'],
      [text.grossSales, c(d.grossSales)],
      [text.netSales, c(d.netSales)],
      [text.grossProfit, c(d.grossProfit)],
      for (final r in d.serviceWise) [r.label, c(r.value)],
    ]);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(text.downloadExcel)));
    }
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.onPdf,
    required this.onCsv,
    required this.text,
  });
  final VoidCallback onPdf;
  final VoidCallback onCsv;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TfButton(
            label: text.downloadPdf,
            variant: TfButtonVariant.ghost,
            icon: Icons.picture_as_pdf_outlined,
            onPressed: onPdf,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TfButton(
            label: text.downloadExcel,
            variant: TfButtonVariant.ghost,
            icon: Icons.table_view_outlined,
            onPressed: onCsv,
          ),
        ),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });
  final String? value;
  final String hint;
  final List<(String, String)> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.lineStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          hint: TfText(
            hint,
            style: const TextStyle(fontSize: 13, color: PosColors.muted),
          ),
          items: [
            DropdownMenuItem<String?>(value: null, child: TfText(hint)),
            for (final (k, l) in options)
              DropdownMenuItem<String?>(value: k, child: TfText(l)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MoneyRow {
  const _MoneyRow(this.label, this.value);
  final String label;
  final double value;
}

class _Breakdown {
  _Breakdown({
    required this.ordersCompleted,
    required this.grossSales,
    required this.discountByStaff,
    required this.netSales,
    required this.collection,
    required this.serviceWise,
    required this.profitNetSales,
    required this.serviceCharge,
    required this.deliveryCharge,
    required this.preparationCost,
    required this.wastage,
    required this.paymentFee,
    required this.taxes,
    required this.grossProfit,
  });

  final int ordersCompleted;
  final double grossSales;
  final double discountByStaff;
  final double netSales;
  final List<_MoneyRow> collection;
  final List<_MoneyRow> serviceWise;
  final double profitNetSales;
  final double serviceCharge;
  final double deliveryCharge;
  final double preparationCost;
  final double wastage;
  final double paymentFee;
  final double taxes;
  final double grossProfit;

  /// True when the filtered query returned nothing to report — show the
  /// "No analytics yet" empty state instead of zeroed sections.
  bool get hasNoData =>
      ordersCompleted == 0 &&
      grossSales == 0 &&
      netSales == 0 &&
      collection.isEmpty;

  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

  factory _Breakdown.fromJson(Map<String, Object?> json) {
    final summary = (json['salesSummary'] as Map?) ?? const {};
    final profit = (json['profit'] as Map?) ?? const {};
    List<_MoneyRow> rows(Object? raw) => ((raw as List?) ?? const [])
        .whereType<Map>()
        .map((m) => _MoneyRow((m['label'] ?? '').toString(), _d(m['valueBdt'])))
        .toList(growable: false);
    return _Breakdown(
      ordersCompleted: (summary['ordersCompleted'] as num?)?.toInt() ?? 0,
      grossSales: _d(summary['grossSales']),
      discountByStaff: _d(summary['discountByStaff']),
      netSales: _d(summary['netSales']),
      collection: rows(json['collection']),
      serviceWise: rows(json['serviceWise']),
      profitNetSales: _d(profit['netSales']),
      serviceCharge: _d(profit['serviceCharge']),
      deliveryCharge: _d(profit['deliveryCharge']),
      preparationCost: _d(profit['preparationCost']),
      wastage: _d(profit['wastage']),
      paymentFee: _d(profit['paymentFee']),
      taxes: _d(profit['taxes']),
      grossProfit: _d(profit['grossProfit']),
    );
  }
}
