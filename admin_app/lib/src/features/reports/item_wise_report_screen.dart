import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/report_section.dart';
import '../../core/widgets/tf_design_system.dart';
import '../analytics/analytics_screen.dart';
import 'report_export.dart';

// ===========================================================================
// Item-wise Sales report (QS) — category-subtotal table (Item Name | Avg Unit
// Price | Total Price) with in-table search, plus per-item drill-down. Backed
// by /analytics/summary (itemWise block).
// ===========================================================================
class ItemWiseReportScreen extends StatefulWidget {
  const ItemWiseReportScreen({this.range = 'today', super.key});

  final String range;

  @override
  State<ItemWiseReportScreen> createState() => _ItemWiseReportScreenState();
}

class _ItemWiseReportScreenState extends State<ItemWiseReportScreen> {
  late String _range = widget.range;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Future<List<_Cat>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<_Cat>> _load() async {
    final app = AppScope.read(context);
    final json = await app.fetchAnalyticsSummary(range: _range);
    return ((json['itemWise'] as List?) ?? const [])
        .whereType<Map>()
        .map(_Cat.fromJson)
        .toList(growable: false);
  }

  void _setRange(String r) {
    if (r == _range) return;
    setState(() {
      _range = r;
      _future = _load();
    });
  }

  void _openItem(_Row r) {
    if (r.menuItemId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDrillDownScreen(
          menuItemId: r.menuItemId,
          name: r.name,
          range: _range,
        ),
      ),
    );
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
      appBar: AppBar(title: Text(text.itemWiseReport)),
      body: SafeArea(
        child: FutureBuilder<List<_Cat>>(
          future: _future,
          builder: (context, snap) {
            final cats = snap.data ?? const <_Cat>[];
            final filtered = _query.isEmpty
                ? cats
                : [
                    for (final c in cats)
                      if (c.filtered(_query).isNotEmpty)
                        c.copyWith(c.filtered(_query)),
                  ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                TfCard(
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
                              onTap: () => _setRange(k),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TfSearchField(
                        controller: _searchCtrl,
                        hintText: text.search,
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _header(text),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: TfLoading(),
                  )
                else if (filtered.isEmpty)
                  TfEmptyState(
                    title: text.analyticsNoItemsTitle,
                    message: text.analyticsNoItemsMessage,
                    icon: Icons.fastfood_rounded,
                  )
                else ...[
                  for (final c in filtered) _CatCard(cat: c, onTap: _openItem),
                  const SizedBox(height: 12),
                  TfButton(
                    label: text.downloadExcel,
                    variant: TfButtonVariant.ghost,
                    icon: Icons.table_view_outlined,
                    onPressed: () => _exportCsv(context, text, filtered),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(AppStrings text) {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: PosColors.muted,
    );
    // Mirror the data-row layout exactly (gap → avg → total → chevron gutter)
    // so the labels sit directly over their numbers.
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: TfText(
              text.itemName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PosColors.muted,
              ),
            ),
          ),
          const SizedBox(width: PosSpacing.sp2),
          SizedBox(
            width: kReportAvgColWidth,
            child: TfText(
              text.avgUnitPrice,
              textAlign: TextAlign.right,
              maxLines: 2,
              style: headerStyle,
            ),
          ),
          SizedBox(
            width: kReportTotalColWidth,
            child: TfText(
              text.totalPrice,
              textAlign: TextAlign.right,
              maxLines: 2,
              style: headerStyle,
            ),
          ),
          const SizedBox(width: kReportRowChevron),
        ],
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    AppStrings text,
    List<_Cat> cats,
  ) async {
    final rows = <List<String>>[
      [text.itemName, text.avgUnitPrice, text.totalPrice],
    ];
    for (final c in cats) {
      rows.add([
        '${c.category} (${c.units})',
        '',
        c.totalPrice.toStringAsFixed(2),
      ]);
      for (final r in c.rows) {
        rows.add([
          '${r.name} (${r.units})',
          r.avgUnitPrice.toStringAsFixed(2),
          r.totalPrice.toStringAsFixed(2),
        ]);
      }
    }
    await ReportExport.copyCsv(rows);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(text.downloadExcel)));
    }
  }
}

class _CatCard extends StatelessWidget {
  const _CatCard({required this.cat, required this.onTap});
  final _Cat cat;
  final ValueChanged<_Row> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TfCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: PosColors.surfaceSunk,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(PosRadii.lg),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: TfText(
                      '${cat.category} (${cat.units})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PosColors.text,
                      ),
                    ),
                  ),
                  TfText(
                    tfFormatCurrency(context, cat.totalPrice),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: PosColors.text,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (final r in cat.rows)
                    InkWell(
                      onTap: () => onTap(r),
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: PosColors.line),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          children: [
                            Expanded(
                              child: TfText(
                                '${r.name} (${r.units})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: PosColors.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: PosSpacing.sp2),
                            SizedBox(
                              width: kReportAvgColWidth,
                              child: TfText(
                                tfFormatCurrency(context, r.avgUnitPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: PosColors.muted,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: kReportTotalColWidth,
                              child: TfText(
                                tfFormatCurrency(context, r.totalPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: PosColors.text,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
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
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cat {
  _Cat({
    required this.category,
    required this.units,
    required this.totalPrice,
    required this.rows,
  });
  final String category;
  final int units;
  final double totalPrice;
  final List<_Row> rows;

  _Cat copyWith(List<_Row> rows) => _Cat(
    category: category,
    units: units,
    totalPrice: totalPrice,
    rows: rows,
  );

  List<_Row> filtered(String q) {
    final lower = q.toLowerCase();
    return [
      for (final r in rows)
        if (r.name.toLowerCase().contains(lower)) r,
    ];
  }

  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;

  factory _Cat.fromJson(Map raw) {
    return _Cat(
      category: (raw['category'] ?? '').toString(),
      units: _i(raw['units']),
      totalPrice: _d(raw['totalPrice']),
      rows: ((raw['items'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (i) => _Row(
              menuItemId: (i['menuItemId'] ?? '').toString(),
              name: (i['name'] ?? '').toString(),
              units: _i(i['units']),
              avgUnitPrice: _d(i['avgUnitPrice']),
              totalPrice: _d(i['totalPrice']),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _Row {
  const _Row({
    required this.menuItemId,
    required this.name,
    required this.units,
    required this.avgUnitPrice,
    required this.totalPrice,
  });
  final String menuItemId;
  final String name;
  final int units;
  final double avgUnitPrice;
  final double totalPrice;
}
