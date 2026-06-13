import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_summary.dart';

/// Daily variance drill-down (spec §4.7 advanced). System (expected) vs
/// counted, with the value of the loss. Derived from the inventory summary's
/// per-item `varianceQty` (signed; counted − system): system = onHand − var.
class StockVarianceScreen extends StatefulWidget {
  const StockVarianceScreen({super.key});

  @override
  State<StockVarianceScreen> createState() => _StockVarianceScreenState();
}

class _StockVarianceScreenState extends State<StockVarianceScreen> {
  bool _kicked = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    if (!_kicked) {
      _kicked = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => app.refreshInventorySummary(),
      );
    }

    final items = app.inventorySummary?.items ?? const <InventorySummaryItem>[];
    final rows = items.where((i) => i.varianceQty != 0).toList(growable: false)
      ..sort((a, b) => a.varianceQty.compareTo(b.varianceQty));
    final lossVal = rows.fold<double>(
      0,
      (s, r) => s + (r.varianceQty < 0 ? r.varianceQty * r.costPerUnit : 0),
    );

    return AppScaffold(
      title: text.dailyVariance,
      subtitle: text.expectedVsCounted,
      showDatePill: false,
      showBackButton: true,
      pinHeader: true,
      fillBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: text.varianceLoss,
                  value: lossVal == 0
                      ? '৳0'
                      : '−${tfFormatCurrency(context, lossVal.abs())}',
                  valueColor: lossVal < 0 ? PosColors.danger : PosColors.text,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: text.itemsOff,
                  value: tfFormatNumber(context, rows.length),
                  valueColor: PosColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: TfEmptyState(
                      icon: Icons.check_circle_outline,
                      title: text.noVarianceToday,
                      message: 'Counted quantities match the system.',
                      messageBn: 'গণনাকৃত পরিমাণ সিস্টেমের সাথে মিলে গেছে।',
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _VarianceTable(text: text, rows: rows),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PosColors.muted,
            ),
          ),
          const SizedBox(height: 3),
          TfText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _VarianceTable extends StatelessWidget {
  const _VarianceTable({required this.text, required this.rows});

  final AppStrings text;
  final List<InventorySummaryItem> rows;

  @override
  Widget build(BuildContext context) {
    final headerStyle = const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: PosColors.muted,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PosColors.lineStrong, width: 1.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: TfText(text.colItem, style: headerStyle)),
                SizedBox(
                  width: 56,
                  child: TfText(
                    text.colSystem,
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: TfText(
                    text.colCounted,
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: TfText(
                    text.colDiff,
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            _VarianceRow(text: text, item: rows[i], last: i == rows.length - 1),
        ],
      ),
    );
  }
}

class _VarianceRow extends StatelessWidget {
  const _VarianceRow({
    required this.text,
    required this.item,
    required this.last,
  });

  final AppStrings text;
  final InventorySummaryItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final counted = item.onHand;
    final system = item.onHand - item.varianceQty;
    final diff = item.varianceQty;
    final name = InventoryItem.localizedNameParts(
      nameEn: item.nameEn,
      nameBn: item.nameBn,
      language: text.language,
    );
    final diffColor = diff < 0 ? PosColors.danger : PosColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: last ? Colors.transparent : PosColors.line),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TfText(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PosColors.text,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: TfText(
              _fmt(context, system),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                color: PosColors.muted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: TfText(
              _fmt(context, counted),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: PosColors.text,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: TfText(
              '${diff > 0
                  ? '+'
                  : diff < 0
                  ? '−'
                  : ''}${_fmt(context, diff.abs())}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: diffColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(BuildContext context, double value) {
    if (value == value.roundToDouble()) return tfFormatNumber(context, value);
    return tfFormatNumber(context, value, decimalDigits: 1);
  }
}
