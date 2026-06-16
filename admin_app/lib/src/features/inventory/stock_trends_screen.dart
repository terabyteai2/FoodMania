import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/inventory_summary.dart';

/// Stock over time — read-only whole-inventory health (owner; spec §4.7
/// advanced). The historical time-series (value/usage/stock-in/below-par/cover
/// across periods) is served by a dedicated backend endpoint; until that ships
/// this screen surfaces the live snapshot derived from the inventory summary and
/// honours the null-safe rule — it shows a "not enough history yet" note rather
/// than fabricating a trend line.
class StockTrendsScreen extends StatelessWidget {
  const StockTrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.selectMany(context, const [
      AppAspect.inventory,
      AppAspect.language,
    ]);
    final text = app.strings;
    final items = app.inventorySummary?.items ?? const <InventorySummaryItem>[];

    // Live snapshot measures derived from the summary (no history required).
    // Each is null-safe: zero-count categories simply read 0, never fabricated.
    var stockValue = 0.0;
    var usageUnits = 0.0;
    var stockInSpend = 0.0;
    var belowPar = 0;
    var coverSum = 0.0;
    var coverCount = 0;
    for (final i in items) {
      stockValue += i.onHand * i.costPerUnit;
      usageUnits += i.todayOut;
      stockInSpend += i.todaySpendBdt;
      if (i.isLow || i.isOut) belowPar += 1;
      if (i.todayOut > 0) {
        coverSum += i.onHand / i.todayOut;
        coverCount += 1;
      }
    }
    final measures = <(String, String)>[
      (text.stockValue, tfFormatCurrency(context, stockValue)),
      (text.usedTodayValue, tfFormatNumber(context, usageUnits)),
      (text.stockIn, tfFormatCurrency(context, stockInSpend)),
      (text.belowPar, tfFormatNumber(context, belowPar)),
      if (coverCount > 0)
        (
          text.daysOfCover,
          '${tfFormatNumber(context, coverSum / coverCount, decimalDigits: 1)}d',
        ),
    ];

    return AppScaffold(
      title: text.stockOverTime,
      subtitle: text.wholeInventoryHealth,
      showBackButton: true,
      showDatePill: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: TfEmptyState(
                icon: Icons.show_chart_rounded,
                title: text.stockOverTime,
                message: text.noTrendData,
              ),
            )
          else ...[
            // Historical trend charts land here once the trends endpoint ships.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.card),
                border: Border.all(color: PosColors.line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timeline_rounded,
                    size: 18,
                    color: PosColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TfText(
                      text.noTrendData,
                      style: const TextStyle(
                        fontSize: 13,
                        color: PosColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TfText(
              text.allMeasures.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: PosColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                for (final m in measures)
                  _MeasureCard(label: m.$1, value: m.$2),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: TfText(
                text.endOfDaySnapshots,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: PosColors.mutedSoft,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MeasureCard extends StatelessWidget {
  const _MeasureCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TfText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PosColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          TfText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
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
