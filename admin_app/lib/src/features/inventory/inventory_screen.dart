import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/enums/business_tier.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_summary.dart';
import '../../models/inventory_unit.dart';
import '../../models/pos_notification.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';
import 'daily_report_screen.dart';
import 'stock_in_screen.dart';
import 'used_stock_screen.dart';
import 'end_of_day_count_screen.dart';
import 'inventory_item_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    super.key,
  });

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedCategory = 'all';
  bool _firstLoadKicked = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final summary = app.inventorySummary;
    final tier = TierScope.of(context);

    if (!_firstLoadKicked) {
      _firstLoadKicked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        app.refreshInventorySummary();
      });
    }

    // Tier-specific home screens
    if (tier == BusinessTier.simple) {
      return _InvSimple(
        app: app,
        text: text,
        summary: summary,
        onNavigateToOrders: widget.onNavigateToOrders ?? () {},
        onNavigateToTarget: widget.onNavigateToTarget,
      );
    }
    if (tier == BusinessTier.advanced || tier == BusinessTier.enterprise) {
      return _InvAdvanced(
        app: app,
        text: text,
        summary: summary,
        onNavigateToOrders: widget.onNavigateToOrders ?? () {},
        onNavigateToTarget: widget.onNavigateToTarget,
      );
    }

    return _InvStandard(
      app: app,
      text: text,
      summary: summary,
      selectedCategory: _selectedCategory,
      onCategorySelected: (key) => setState(() => _selectedCategory = key),
      onNavigateToOrders: widget.onNavigateToOrders ?? () {},
      onNavigateToTarget: widget.onNavigateToTarget,
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

// Legacy standard widgets stay available while the redesign settles.
// ignore: unused_element
class _Header extends StatelessWidget {
  const _Header({
    required this.text,
    required this.summary,
    required this.varianceOn,
    required this.onNavigateToOrders,
    required this.onNavigateToTarget,
  });

  final AppStrings text;
  final InventorySummary? summary;
  final bool varianceOn;
  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final itemCount = summary?.items.length ?? 0;
    final alerts = summary?.alerts ?? 0;
    final loss = summary?.varianceTodayBdt ?? 0;
    final hasLoss = varianceOn && loss < 0;

    final parts = <String>[
      text.isBn
          ? '${tfFormatNumber(context, itemCount)} টি আইটেম'
          : '$itemCount items',
      text.alertsCount(alerts),
      if (hasLoss)
        text.isBn
            ? '${tfFormatCurrency(context, loss.abs(), decimalDigits: 0)} অব্যাখ্যাত'
            : '${tfFormatCurrency(context, loss.abs(), decimalDigits: 0)} unexplained',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  text.inventory,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                TfText(
                  parts.join(' · '),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: hasLoss ? PosColors.danger : PosColors.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          TfIconButton(
            icon: Icons.search_rounded,
            tooltip: text.searchInventory,
            onPressed: () {},
          ),
          const SizedBox(width: 6),
          TfIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: text.dailyReport,
            onPressed: () => _showMoreMenu(context, text),
          ),
          const SizedBox(width: 6),
          const HeaderModeButton(),
          const SizedBox(width: 6),
          HeaderNotificationBell(
            onNavigateToOrders: onNavigateToOrders,
            onNavigateToTarget: onNavigateToTarget,
          ),
        ],
      ),
    );
  }
}

void _showMoreMenu(BuildContext context, AppStrings text) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _SheetShell(
        title: text.isBn ? 'অন্যান্য' : 'More',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MoreMenuRow(
              icon: Icons.assessment_outlined,
              label: text.dailyReport,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyReportScreen()),
                );
              },
            ),
            _MoreMenuRow(
              icon: Icons.fact_check_outlined,
              label: text.endOfDayCount,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EndOfDayCountScreen(),
                  ),
                );
              },
            ),
            _MoreMenuRow(
              icon: Icons.add_circle_outline,
              label: text.addInventoryItem,
              onTap: () async {
                Navigator.pop(context);
                final app = AppScope.of(context);
                final result = await Navigator.push<InventoryItem>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _ItemFormSheet(text: app.strings, fullScreen: true),
                  ),
                );
                if (result != null) {
                  await app.saveInventoryItem(result);
                  await app.refreshInventorySummary();
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

class _MoreMenuRow extends StatelessWidget {
  const _MoreMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PosRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: PosColors.slate, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: TfText(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: PosColors.slate,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: PosColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Stock value card ──────────────────────────────────────────────────────────

// ignore: unused_element
class _InventorySummaryBand extends StatelessWidget {
  const _InventorySummaryBand({
    required this.text,
    required this.summary,
    required this.varianceOn,
  });

  final AppStrings text;
  final InventorySummary? summary;
  final bool varianceOn;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return _StockValueCard(text: text, summary: summary);
    }

    final hasAlerts = summary!.items.any(
      (item) => item.varianceStatus == 'low' || item.varianceStatus == 'out',
    );

    if (varianceOn) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: text.stockValueNow,
                    value: tfFormatCurrency(context, summary!.stockValueBdt),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryTile(
                    label: text.usedTodayValue,
                    value: tfFormatCurrency(
                      context,
                      _totalSpend(summary!.items),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LossTile(text: text, summary: summary!),
                ),
              ],
            ),
          ),
          if (hasAlerts)
            _LowStockAlertCard(text: text, summary: summary!)
          else
            _StockStatusOkCard(text: text, summary: summary!),
        ],
      );
    }

    // Variance off: single stock-value card + alert/healthy card below.
    return Column(
      children: [
        _StockValueCard(text: text, summary: summary),
        if (hasAlerts)
          _LowStockAlertCard(text: text, summary: summary!)
        else
          _StockStatusOkCard(text: text, summary: summary!),
      ],
    );
  }

  static double _totalSpend(List<InventorySummaryItem> items) {
    return items.fold<double>(0, (sum, item) => sum + item.todaySpendBdt);
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
                color: PosColors.muted,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            TfText(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: PosColors.slate,
                height: 1.05,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LossTile extends StatelessWidget {
  const _LossTile({required this.text, required this.summary});

  final AppStrings text;
  final InventorySummary summary;

  @override
  Widget build(BuildContext context) {
    final loss = summary.varianceTodayBdt;
    final hasLoss = loss < 0;
    final color = hasLoss ? PosColors.danger : PosColors.muted;
    final fill = hasLoss ? PosColors.dangerSoft : PosColors.surface;
    final amount = loss == 0
        ? '৳0'
        : '${hasLoss ? '−' : '+'}${tfFormatCurrency(context, loss.abs())}';
    return TfCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      color: fill,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text.unexplainedLossToday.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
                color: color,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            TfText(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: color,
                height: 1.05,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockValueCard extends StatelessWidget {
  const _StockValueCard({required this.text, required this.summary});

  final AppStrings text;
  final InventorySummary? summary;

  @override
  Widget build(BuildContext context) {
    final stockValue = summary?.stockValueBdt ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: TfCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TfSectionHeader(
              label: text.stockValueNow,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 6),
            TfText(
              tfFormatCurrency(context, stockValue),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: PosColors.slate,
                height: 1.05,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Low stock alert ───────────────────────────────────────────────────────────

class _LowStockAlertCard extends StatelessWidget {
  const _LowStockAlertCard({required this.text, required this.summary});

  final AppStrings text;
  final InventorySummary summary;

  @override
  Widget build(BuildContext context) {
    final alerts =
        summary.items
            .where(
              (item) =>
                  item.varianceStatus == 'low' || item.varianceStatus == 'out',
            )
            .toList(growable: false)
          ..sort((a, b) {
            if (a.varianceStatus == b.varianceStatus) return 0;
            return a.varianceStatus == 'out' ? -1 : 1;
          });
    if (alerts.isEmpty) {
      return _StockStatusOkCard(text: text, summary: summary);
    }

    final isBn = text.isBn;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: PosColors.dangerSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PosColors.danger.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: PosColors.danger,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TfSectionHeader(
                    label: text.lowStockAlerts,
                    color: PosColors.danger,
                    padding: EdgeInsets.zero,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: PosColors.danger,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TfText(
                    tfFormatNumber(context, alerts.length),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in alerts.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: item.varianceStatus == 'out'
                            ? PosColors.danger
                            : PosColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TfText(
                        isBn && item.nameBn.trim().isNotEmpty
                            ? item.nameBn
                            : (item.nameEn.trim().isNotEmpty
                                  ? item.nameEn
                                  : item.nameBn),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: PosColors.slate,
                        ),
                      ),
                    ),
                    TfText(
                      '${_formatQty(context, item.onHand)} ${InventoryUnits.displayLabel(item.unit, isBn: isBn)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: PosColors.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.varianceStatus == 'out'
                            ? PosColors.danger.withValues(alpha: 0.18)
                            : PosColors.warning.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TfText(
                        item.varianceStatus == 'out'
                            ? text.statusOut
                            : text.statusLow,
                        style: TextStyle(
                          color: item.varianceStatus == 'out'
                              ? PosColors.danger
                              : PosColors.warning,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (alerts.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 14),
                child: TfText(
                  isBn
                      ? '+ আরও ${tfFormatNumber(context, alerts.length - 4)} টি আইটেম'
                      : '+ ${tfFormatNumber(context, alerts.length - 4)} more',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: PosColors.danger,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatQty(BuildContext context, double value) {
    if (value == value.roundToDouble()) return tfFormatNumber(context, value);
    return tfFormatNumber(context, value, decimalDigits: 1);
  }
}

class _StockStatusOkCard extends StatelessWidget {
  const _StockStatusOkCard({required this.text, required this.summary});

  final AppStrings text;
  final InventorySummary summary;

  @override
  Widget build(BuildContext context) {
    final isBn = text.isBn;
    final tracked = summary.items.length;
    final healthy = summary.items
        .where((i) => i.varianceStatus != 'low' && i.varianceStatus != 'out')
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: PosColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PosColors.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: PosColors.success,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TfText(
                    isBn ? 'স্টক ঠিক আছে' : 'Stock is healthy',
                    style: TextStyle(
                      color: PosColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TfText(
                    isBn
                        ? '${tfFormatNumber(context, healthy)}/${tfFormatNumber(context, tracked)} আইটেম থ্রেশহোল্ডের উপরে'
                        : '${tfFormatNumber(context, healthy)} of ${tfFormatNumber(context, tracked)} items above threshold',
                    style: TextStyle(
                      color: PosColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: PosColors.success,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TfText(
                isBn ? 'সব ঠিক' : 'ALL OK',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category chips ────────────────────────────────────────────────────────────

// ignore: unused_element
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.summary,
    required this.selected,
    required this.onSelected,
  });

  final InventorySummary summary;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: summary.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final bucket = summary.categories[index];
          final isSelected = selected == bucket.key;
          final count = tfFormatNumber(context, bucket.count);
          return TfChip(
            label: '${bucket.labelEn} $count',
            labelBn: '${bucket.labelBn} $count',
            active: isSelected,
            onTap: () => onSelected(bucket.key),
          );
        },
      ),
    );
  }
}

// ── Table header + rows ───────────────────────────────────────────────────────

// ignore: unused_element
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.text, required this.varianceOn});

  final AppStrings text;
  final bool varianceOn;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 1,
      color: PosColors.muted,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 18, 6),
      child: Row(
        children: [
          Expanded(
            flex: varianceOn ? 36 : 44,
            child: TfText(text.colItem, style: style),
          ),
          Expanded(
            flex: varianceOn ? 22 : 26,
            child: TfText(
              text.colOnHand,
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: varianceOn ? 20 : 30,
            child: TfText(
              text.colTodayIn,
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          if (varianceOn)
            Expanded(
              flex: 22,
              child: TfText(
                text.colTodayOut,
                style: style,
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ItemSliverList extends StatelessWidget {
  const _ItemSliverList({
    required this.summary,
    required this.selectedCategory,
    required this.text,
    required this.varianceOn,
  });

  final InventorySummary summary;
  final String selectedCategory;
  final AppStrings text;
  final bool varianceOn;

  @override
  Widget build(BuildContext context) {
    final filtered = selectedCategory == 'all'
        ? summary.items
        : summary.items
              .where((item) => item.category == selectedCategory)
              .toList(growable: false);
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
          child: TfEmptyState(
            icon: Icons.inventory_2_outlined,
            title: text.noMatchingItems,
            message: text.tryDifferentFilter,
          ),
        ),
      );
    }
    return SliverList.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) => _InventoryRow(
        item: filtered[index],
        text: text,
        varianceOn: varianceOn,
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.item,
    required this.text,
    required this.varianceOn,
  });

  final InventorySummaryItem item;
  final AppStrings text;
  final bool varianceOn;

  @override
  Widget build(BuildContext context) {
    final unit = InventoryUnits.displayLabel(item.unit, isBn: text.isBn);
    final primaryName = InventoryItem.localizedNameParts(
      nameEn: item.nameEn,
      nameBn: item.nameBn,
      language: text.language,
    );
    final showVariancePill = varianceOn && item.hasVariance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openInventoryDetail(context, item),
          onLongPress: () => _openQuickAdjustSheet(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: varianceOn ? 36 : 44,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: PosColors.surfaceWarm,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PosColors.line),
                        ),
                        alignment: Alignment.center,
                        child: TfText(
                          primaryName.isEmpty
                              ? '?'
                              : primaryName.characters.first.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: PosColors.slate,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TfText(
                              primaryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: PosColors.slate,
                              ),
                            ),
                            if (item.isLow || item.isOut || showVariancePill)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    if (item.isLow || item.isOut)
                                      _LowOutBadge(item: item, text: text),
                                    if (showVariancePill)
                                      _VarianceBadge(item: item, text: text),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: varianceOn ? 22 : 26,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TfText(
                        _formatQty(context, item.onHand),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: PosColors.slate,
                        ),
                      ),
                      TfText(
                        unit,
                        style: TextStyle(
                          fontSize: 11,
                          color: PosColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: varianceOn ? 20 : 30,
                  child: TfText(
                    item.todayIn > 0
                        ? '+${_formatQty(context, item.todayIn)}'
                        : '—',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      color: item.todayIn > 0
                          ? PosColors.success
                          : PosColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (varianceOn)
                  Expanded(
                    flex: 22,
                    child: TfText(
                      item.todayOut > 0
                          ? '−${_formatQty(context, item.todayOut)}'
                          : '—',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 13,
                        color: item.todayOut > 0
                            ? PosColors.danger
                            : PosColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatQty(BuildContext context, double value) {
    if (value == value.roundToDouble()) {
      return tfFormatNumber(context, value);
    }
    return tfFormatNumber(context, value, decimalDigits: 1);
  }
}

class _LowOutBadge extends StatelessWidget {
  const _LowOutBadge({required this.item, required this.text});

  final InventorySummaryItem item;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final isOut = item.varianceStatus == 'out';
    final fg = isOut ? PosColors.danger : PosColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: TfText(
        isOut ? text.statusOut : text.statusLow,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w500,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _VarianceBadge extends StatelessWidget {
  const _VarianceBadge({required this.item, required this.text});

  final InventorySummaryItem item;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final isLoss = item.varianceQty < 0;
    final color = isLoss ? PosColors.danger : PosColors.success;
    final qty = item.varianceQty;
    final unit = InventoryUnits.displayLabel(item.unit, isBn: text.isBn);
    final formatted = qty == qty.roundToDouble()
        ? tfFormatNumber(context, qty.abs())
        : tfFormatNumber(context, qty.abs(), decimalDigits: 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: TfText(
        '${isLoss ? '−' : '+'}$formatted $unit',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── FAB ──────────────────────────────────────────────────────────────────────

// ignore: unused_element
class _InventoryActionBar extends StatelessWidget {
  const _InventoryActionBar({required this.text});

  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PosColors.line, width: 0.5),
          boxShadow: PosShadows.glow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InventoryActionButton(
                label: text.stockIn,
                icon: Icons.add_rounded,
                primary: true,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StockInScreen()),
                  );
                  if (context.mounted) {
                    await AppScope.of(context).refreshInventorySummary();
                  }
                },
              ),
              const SizedBox(width: 8),
              _InventoryActionButton(
                label: text.startCount,
                icon: Icons.fact_check_outlined,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EndOfDayCountScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryActionButton extends StatelessWidget {
  const _InventoryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132, minHeight: 46),
      child: TfButton(
        onPressed: onPressed,
        icon: icon,
        label: label,
        variant: primary ? TfButtonVariant.primary : TfButtonVariant.dark,
        fullWidth: false,
      ),
    );
  }
}

// ── Sheets (preserved from previous version) ─────────────────────────────────

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PosColors.lineStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TfText(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TfIconButton(
                    icon: Icons.close,
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCountSheet extends StatefulWidget {
  const _QuickCountSheet({required this.item, required this.text});

  final InventoryItem item;
  final AppStrings text;

  @override
  State<_QuickCountSheet> createState() => _QuickCountSheetState();
}

class _QuickCountSheetState extends State<_QuickCountSheet> {
  late final TextEditingController _ctrl;
  bool _busy = false;
  double? _yesterday;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.quantity.toString());
    _loadYesterday();
  }

  Future<void> _loadYesterday() async {
    final v = await AppScope.of(
      context,
    ).yesterdayClosingQuantity(widget.item.id);
    if (mounted) setState(() => _yesterday = v);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(_ctrl.text.trim());
    if (qty == null || qty < 0) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).setInventoryEndOfDayCount(
        inventoryItemId: widget.item.id,
        quantity: qty,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TfText(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final unit = InventoryUnits.displayLabel(widget.item.unit, isBn: text.isBn);
    final itemName = widget.item.localizedName(text.language);

    return _SheetShell(
      title: '${text.setCount} — $itemName',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_yesterday != null)
            TfText(
              '${text.yesterdayLeft}: ${InventoryUnits.formatQuantity(_yesterday!, widget.item.unit, isBn: text.isBn)}',
              style: TextStyle(color: PosColors.muted, fontSize: 13),
            ),
          const SizedBox(height: 12),
          TfField(
            label: '${text.leftNow} ($unit)',
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
          ),
          const SizedBox(height: 8),
          TfButton(
            label: text.saveCount,
            onPressed: _busy ? null : _save,
            busy: _busy,
            size: TfButtonSize.lg,
          ),
        ],
      ),
    );
  }
}

class _EndOfDaySheet extends StatefulWidget {
  const _EndOfDaySheet({required this.text, required this.items});

  final AppStrings text;
  final List<InventoryItem> items;

  @override
  State<_EndOfDaySheet> createState() => _EndOfDaySheetState();
}

class _EndOfDaySheetState extends State<_EndOfDaySheet> {
  final _controllers = <String, TextEditingController>{};
  final MenuImageService _imageService = MenuImageService();
  bool _busy = false;
  bool _scanning = false;
  String? _scanError;
  String? _scanProvider;

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _controllers[item.id] = TextEditingController(
        text: item.quantity.toString(),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    setState(() => _busy = true);
    final app = AppScope.of(context);
    try {
      for (final item in widget.items) {
        final qty = double.tryParse(_controllers[item.id]!.text.trim());
        if (qty == null || qty < 0) continue;
        await app.setInventoryEndOfDayCount(
          inventoryItemId: item.id,
          quantity: qty,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TfText(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanCounts() async {
    if (_scanning) return;
    final app = AppScope.of(context);
    setState(() {
      _scanning = true;
      _scanError = null;
    });
    try {
      final page = await _imageService.captureMenuScanPage(pageNumber: 1);
      if (page == null) {
        if (mounted) setState(() => _scanning = false);
        return;
      }
      final result = await app.scanInventoryReceipt([
        MenuScanPageUpload(
          bytes: page.bytes,
          fileName: page.fileName,
          mimeType: page.mimeType,
        ),
      ]);
      var applied = 0;
      for (final scanned in result.items) {
        final matched = _matchScannedLine(scanned.nameEn, scanned.nameBn);
        if (matched == null) continue;
        _controllers[matched.id]?.text = _formatNumber(scanned.qty);
        applied += 1;
      }
      setState(() {
        _scanProvider = result.provider;
        _scanError = applied == 0
            ? (widget.text.isBn
                  ? 'মিল পাওয়া যায়নি। হাতে পরিমাণ লিখুন।'
                  : 'No matching items found. Enter counts manually.')
            : widget.text.aiCountScanApplied;
      });
    } on CloudApiException catch (error) {
      setState(() => _scanError = error.message);
    } on MenuImageException catch (error) {
      setState(() => _scanError = error.message);
    } catch (error) {
      setState(() => _scanError = error.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  InventoryItem? _matchScannedLine(String nameEn, String nameBn) {
    final candidates = [
      nameEn.trim().toLowerCase(),
      nameBn.trim().toLowerCase(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    if (candidates.isEmpty) return null;
    for (final item in widget.items) {
      final itemNames = [item.name, item.nameEn, item.nameBn]
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty);
      for (final candidate in candidates) {
        if (itemNames.any(
          (itemName) =>
              candidate == itemName ||
              candidate.contains(itemName) ||
              itemName.contains(candidate),
        )) {
          return item;
        }
      }
    }
    return null;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    return _SheetShell(
      title: text.endOfDayCount,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TfText(
            text.countAllItems,
            style: TextStyle(fontSize: 13, color: PosColors.muted),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PosColors.primaryWash,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PosColors.line, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.document_scanner_outlined,
                      color: PosColors.primaryDark,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TfText(
                        text.aiScanCount,
                        style: const TextStyle(
                          color: PosColors.primaryDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TfButton(
                      label: 'Scan',
                      labelBn: 'স্ক্যান',
                      icon: Icons.photo_camera_rounded,
                      variant: TfButtonVariant.dark,
                      size: TfButtonSize.sm,
                      fullWidth: false,
                      busy: _scanning,
                      onPressed: _scanning ? null : _scanCounts,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TfText(
                  text.aiScanCountHint,
                  style: TextStyle(
                    color: PosColors.primaryDark.withValues(alpha: 0.70),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (_scanError != null) ...[
                  const SizedBox(height: 8),
                  TfText(
                    _scanProvider == null
                        ? _scanError!
                        : '${_scanError!} · $_scanProvider',
                    style: TextStyle(
                      color: _scanError == text.aiCountScanApplied
                          ? PosColors.success
                          : PosColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...widget.items.map((item) {
            final unit = InventoryUnits.displayLabel(
              item.unit,
              isBn: text.isBn,
            );
            final name = item.localizedName(text.language);
            return TfField(
              label: '$name ($unit)',
              controller: _controllers[item.id],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
            );
          }),
          TfButton(
            label: text.saveCount,
            size: TfButtonSize.lg,
            busy: _busy,
            onPressed: _busy ? null : _saveAll,
          ),
        ],
      ),
    );
  }
}

class _ItemFormSheet extends StatefulWidget {
  // ignore: unused_element_parameter
  const _ItemFormSheet({
    required this.text,
    this.item,
    this.fullScreen = false,
  });

  final AppStrings text;
  final InventoryItem? item;
  final bool fullScreen;

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _uuid = const Uuid();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late String _unit;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _reorderCtrl;
  String? _supplierId;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _categoryCtrl = TextEditingController(text: item?.category ?? '');
    _unit = item?.unit ?? InventoryUnits.kg;
    _qtyCtrl = TextEditingController(
      text: item != null ? item.quantity.toString() : '0',
    );
    _priceCtrl = TextEditingController(
      text: item != null && item.costPerUnit > 0
          ? item.costPerUnit.toString()
          : '',
    );
    _minCtrl = TextEditingController(
      text: item != null ? item.minThreshold.toString() : '0',
    );
    _reorderCtrl = TextEditingController(
      text: item?.defaultReorderQty.toString() ?? '0',
    );
    _supplierId = item?.defaultSupplierId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _minCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final now = DateTime.now();
    final existing = widget.item;
    Navigator.pop(
      context,
      InventoryItem(
        id: existing?.id ?? _uuid.v4(),
        name: name,
        category: _categoryCtrl.text.trim(),
        unit: InventoryUnits.normalize(_unit),
        quantity: double.tryParse(_qtyCtrl.text.trim()) ?? 0,
        minThreshold: double.tryParse(_minCtrl.text.trim()) ?? 0,
        costPerUnit: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        notes: existing?.notes ?? '',
        defaultSupplierId: _supplierId,
        defaultReorderQty: double.tryParse(_reorderCtrl.text.trim()) ?? 0,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final isEdit = widget.item != null;
    final unitLabel = InventoryUnits.displayLabel(_unit, isBn: text.isBn);

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TfField(label: text.itemName, controller: _nameCtrl),
        TfField(label: text.itemCategory, controller: _categoryCtrl),
        TfText(
          text.unit,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: PosColors.slate,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: InventoryUnits.all
              .map((u) {
                final selected = _unit == u;
                return TfChip(
                  label: InventoryUnits.displayLabel(u, isBn: text.isBn),
                  active: selected,
                  small: true,
                  onTap: () => setState(() => _unit = u),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 14),
        TfField(
          label: '${text.unitPrice} ($unitLabel)',
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
        ),
        TfField(
          label: text.isBn
              ? 'ডিফল্ট অর্ডার পরিমাণ'
              : 'Default reorder quantity',
          controller: _reorderCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
        ),
        DropdownButtonFormField<String?>(
          initialValue: _supplierId,
          decoration: InputDecoration(
            labelText: text.isBn ? 'ডিফল্ট সাপ্লায়ার' : 'Default supplier',
          ),
          items: [
            const DropdownMenuItem(value: null, child: TfText('No supplier')),
            ...AppScope.of(context).inventorySuppliers.map(
              (supplier) => DropdownMenuItem(
                value: supplier.id,
                child: TfText(supplier.name),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _supplierId = value),
        ),
        const SizedBox(height: 12),
        TfField(
          label: '${text.openingStock} ($unitLabel)',
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
        ),
        TfField(
          label: '${text.lowStockAlert} ($unitLabel)',
          controller: _minCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
        ),
        const SizedBox(height: 6),
        TfButton(
          label: isEdit ? text.save : text.addInventoryItem,
          onPressed: _submit,
          size: TfButtonSize.lg,
        ),
      ],
    );
    if (widget.fullScreen) {
      return Scaffold(
        backgroundColor: PosColors.background,
        appBar: AppBar(
          backgroundColor: PosColors.background,
          title: TfText(
            isEdit ? text.editInventoryItem : text.addInventoryItem,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [form],
        ),
      );
    }
    return _SheetShell(
      title: isEdit ? text.editInventoryItem : text.addInventoryItem,
      child: form,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIER 2 — Standard inventory (small dine-in)
// KPI trio · category filter · top movers · table-style stock list
// ─────────────────────────────────────────────────────────────────────────────

class _InvStandard extends StatelessWidget {
  const _InvStandard({
    required this.app,
    required this.text,
    required this.summary,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onNavigateToOrders,
    required this.onNavigateToTarget,
  });

  final dynamic app;
  final AppStrings text;
  final InventorySummary? summary;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final items = summary?.items ?? const <InventorySummaryItem>[];
    final movers = [...items]
      ..sort((a, b) => b.todaySpendBdt.compareTo(a.todaySpendBdt));
    final filtered = selectedCategory == 'all'
        ? items
        : items
              .where((item) => item.category == selectedCategory)
              .toList(growable: false);
    final stockValue = summary?.stockValueBdt ?? 0;
    final usedToday = items.fold<double>(
      0,
      (sum, item) => sum + item.todaySpendBdt,
    );
    final variance = summary?.varianceTodayBdt ?? 0;
    final alerts = summary?.alerts ?? 0;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: PosColors.primaryDark,
          backgroundColor: PosColors.primary,
          onRefresh: () async {
            await app.refreshInventory();
            await app.refreshInventorySummary();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _InvHomeHeader(
                text: text,
                itemCount: items.length,
                alerts: alerts,
                onMore: () => _showMoreMenu(context, text),
                onNavigateToOrders: onNavigateToOrders,
                onNavigateToTarget: onNavigateToTarget,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _StandardKpiStrip(
                  stockValue: stockValue,
                  usedToday: usedToday,
                  variance: variance,
                  itemCount: items.length,
                  isBn: text.isBn,
                ),
              ),
              if (summary != null && summary!.categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _StandardCategoryStrip(
                    categories: summary!.categories,
                    selected: selectedCategory,
                    onSelected: onCategorySelected,
                  ),
                ),
              if (movers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _StandardMovers(
                    items: movers.take(3).toList(),
                    isBn: text.isBn,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: _StandardItemsCard(items: filtered, text: text),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _InvBottomActions(text: text, app: app),
    );
  }
}

class _InvHomeHeader extends StatelessWidget {
  const _InvHomeHeader({
    required this.text,
    required this.itemCount,
    required this.alerts,
    required this.onMore,
    required this.onNavigateToOrders,
    required this.onNavigateToTarget,
  });

  final AppStrings text;
  final int itemCount;
  final int alerts;
  final VoidCallback onMore;
  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  text.inventory,
                  style: const TextStyle(
                    color: PosColors.primaryDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                TfText(
                  text.isBn
                      ? '${tfFormatNumber(context, itemCount)} টি আইটেম · ${text.alertsCount(alerts)}'
                      : '$itemCount items · ${text.alertsCount(alerts)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: alerts > 0 ? PosColors.danger : PosColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const HeaderModeButton(),
          const SizedBox(width: 6),
          TfIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: text.isBn ? 'আরও অপশন' : 'More options',
            onPressed: onMore,
          ),
          const SizedBox(width: 6),
          HeaderNotificationBell(
            onNavigateToOrders: onNavigateToOrders,
            onNavigateToTarget: onNavigateToTarget,
          ),
        ],
      ),
    );
  }
}

class _StandardKpiStrip extends StatelessWidget {
  const _StandardKpiStrip({
    required this.stockValue,
    required this.usedToday,
    required this.variance,
    required this.itemCount,
    required this.isBn,
  });

  final double stockValue;
  final double usedToday;
  final double variance;
  final int itemCount;
  final bool isBn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 11,
              child: _StandardKpiCell(
                label: isBn ? 'স্টক মূল্য' : 'STOCK VALUE',
                value: tfFormatCurrency(context, stockValue),
                detail: isBn ? '$itemCount টি SKU' : '$itemCount SKUs',
              ),
            ),
            const VerticalDivider(width: 0.5, thickness: 0.5),
            Expanded(
              flex: 10,
              child: _StandardKpiCell(
                label: isBn ? 'আজ ব্যবহার' : 'USED TODAY',
                value: tfFormatCurrency(context, usedToday),
                detail: usedToday > 0
                    ? (isBn ? 'আজ' : 'TODAY')
                    : (isBn ? 'ব্যবহার নেই' : 'NO USAGE'),
                detailColor: usedToday > 0
                    ? PosColors.success
                    : PosColors.mutedSoft,
                detailFill: usedToday > 0
                    ? PosColors.successSoft
                    : PosColors.surfaceSunk,
              ),
            ),
            const VerticalDivider(width: 0.5, thickness: 0.5),
            Expanded(
              flex: 10,
              child: _StandardKpiCell(
                label: isBn ? 'ভ্যারিয়েন্স' : 'VARIANCE',
                value: variance == 0
                    ? '৳0'
                    : '${variance < 0 ? '−' : '+'}${tfFormatCurrency(context, variance.abs())}',
                valueColor: variance < 0
                    ? PosColors.danger
                    : PosColors.mutedSoft,
                detail: variance < 0
                    ? (isBn ? 'আজ ক্ষতি' : 'LOSS TODAY')
                    : (isBn ? 'আজ ক্ষতি নেই' : 'NO LOSS TODAY'),
                detailColor: variance < 0
                    ? PosColors.danger
                    : PosColors.mutedSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandardKpiCell extends StatelessWidget {
  const _StandardKpiCell({
    required this.label,
    required this.value,
    required this.detail,
    this.valueColor = PosColors.primaryDark,
    this.detailColor = PosColors.mutedSoft,
    this.detailFill,
  });

  final String label;
  final String value;
  final String detail;
  final Color valueColor;
  final Color detailColor;
  final Color? detailFill;

  @override
  Widget build(BuildContext context) {
    final detailText = Text(
      detail,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: detailColor,
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          TfText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 7),
          if (detailFill == null)
            detailText
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: detailFill,
                borderRadius: BorderRadius.circular(PosRadii.pill),
              ),
              child: detailText,
            ),
        ],
      ),
    );
  }
}

class _StandardCategoryStrip extends StatelessWidget {
  const _StandardCategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<InventoryCategoryBucket> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final active = category.key == selected;
          return Material(
            color: active ? PosColors.primarySoft : PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(PosRadii.pill),
              onTap: () => onSelected(category.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PosRadii.pill),
                  border: active
                      ? null
                      : Border.all(color: PosColors.line, width: 0.5),
                ),
                alignment: Alignment.center,
                child: TfText(
                  '${textForCategory(category, tfIsBn(context))}  ${tfFormatNumber(context, category.count)}',
                  style: TextStyle(
                    color: active ? PosColors.primaryDark : PosColors.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String textForCategory(InventoryCategoryBucket category, bool isBn) {
    if (isBn && category.labelBn.trim().isNotEmpty) return category.labelBn;
    return category.labelEn;
  }
}

class _StandardMovers extends StatelessWidget {
  const _StandardMovers({required this.items, required this.isBn});

  final List<InventorySummaryItem> items;
  final bool isBn;

  @override
  Widget build(BuildContext context) {
    final maxSpend = items.fold<double>(
      0,
      (max, item) => item.todaySpendBdt > max ? item.todaySpendBdt : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InventoryEyebrow(isBn ? 'আজকের দ্রুত ব্যবহার' : 'TOP MOVERS · TODAY'),
        const SizedBox(height: 10),
        _InventoryOutlinedCard(
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++)
                _InvMoverRow(
                  rank: index + 1,
                  name: items[index].nameEn,
                  qty:
                      '${_compactQty(items[index].todayOut)} ${items[index].unit}',
                  rev: tfFormatCurrency(context, items[index].todaySpendBdt),
                  pct: maxSpend <= 0
                      ? 0
                      : (items[index].todaySpendBdt / maxSpend).clamp(0, 1),
                  showBorder: index > 0,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StandardItemsCard extends StatelessWidget {
  const _StandardItemsCard({required this.items, required this.text});

  final List<InventorySummaryItem> items;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _InventoryEyebrow(text.isBn ? 'সব আইটেম' : 'ALL ITEMS'),
            const Spacer(),
            _InventoryEyebrow(text.isBn ? 'মজুদ · আজ' : 'ON HAND · TODAY'),
          ],
        ),
        const SizedBox(height: 8),
        _InventoryOutlinedCard(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: TfText(
                    text.noMatchingItems,
                    style: const TextStyle(
                      color: PosColors.muted,
                      fontSize: 13,
                    ),
                  ),
                )
              : Column(
                  children: [
                    _StandardItemsHeader(isBn: text.isBn),
                    for (var index = 0; index < items.length; index++)
                      _StandardItemRow(
                        item: items[index],
                        text: text,
                        showBorder: index > 0,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StandardItemsHeader extends StatelessWidget {
  const _StandardItemsHeader({required this.isBn});

  final bool isBn;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: PosColors.muted,
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.7,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: PosColors.surfaceSunk,
      child: Row(
        children: [
          Expanded(
            flex: 17,
            child: Text(isBn ? 'আইটেম' : 'ITEM', style: style),
          ),
          Expanded(
            flex: 10,
            child: Text(
              isBn ? 'মজুদ' : 'ON HAND',
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
          Expanded(
            flex: 9,
            child: Text(
              isBn ? 'আজ' : 'TODAY',
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
          Expanded(
            flex: 7,
            child: Text(
              isBn ? 'অবস্থা' : 'STATUS',
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

void _openInventoryDetail(
  BuildContext context,
  InventorySummaryItem summaryItem,
) {
  final app = AppScope.of(context);
  final item = app.inventoryItems
      .where((row) => row.id == summaryItem.id)
      .firstOrNull;
  if (item == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (detailContext) => InventoryItemDetailScreen(
        item: item,
        onEdit: app.isManager
            ? () async {
                final latest =
                    app.inventoryItems
                        .where((row) => row.id == item.id)
                        .firstOrNull ??
                    item;
                final result = await Navigator.push<InventoryItem>(
                  detailContext,
                  MaterialPageRoute(
                    builder: (_) => _ItemFormSheet(
                      text: app.strings,
                      item: latest,
                      fullScreen: true,
                    ),
                  ),
                );
                if (result != null) await app.saveInventoryItem(result);
              }
            : null,
      ),
    ),
  );
}

void _openQuickAdjustSheet(
  BuildContext context,
  InventorySummaryItem summaryItem,
) {
  final app = AppScope.of(context);
  final item = app.inventoryItems
      .where((row) => row.id == summaryItem.id)
      .firstOrNull;
  if (item == null) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuickAdjustSheet(item: item),
  ).then((_) => app.refreshInventorySummary());
}

class _QuickAdjustSheet extends StatefulWidget {
  const _QuickAdjustSheet({required this.item});
  final InventoryItem item;

  @override
  State<_QuickAdjustSheet> createState() => _QuickAdjustSheetState();
}

class _QuickAdjustSheetState extends State<_QuickAdjustSheet> {
  final _qtyCtrl = TextEditingController(text: '1');
  bool _stockIn = true;
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  double get _max => _stockIn
      ? (widget.item.quantity * 2).clamp(10, 100)
      : widget.item.quantity.clamp(1, 100);
  double get _qty => (double.tryParse(_qtyCtrl.text) ?? 0).clamp(0, _max);

  Future<void> _save() async {
    if (_qty <= 0) return;
    setState(() => _saving = true);
    final app = AppScope.of(context);
    try {
      if (_stockIn) {
        await app.recordInventoryPurchase(
          inventoryItemId: widget.item.id,
          quantity: _qty,
          totalCostBdt: _qty * widget.item.costPerUnit,
        );
      } else {
        await app.recordInventoryUsage(
          inventoryItemId: widget.item.id,
          quantity: _qty,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = InventoryUnits.displayLabel(
      widget.item.unit,
      isBn: tfIsBn(context),
    );
    return _SheetShell(
      title: widget.item.localizedName(AppScope.of(context).language),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TfChip(
                  label: 'IN',
                  active: _stockIn,
                  onTap: () => setState(() => _stockIn = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TfChip(
                  label: 'USED',
                  active: !_stockIn,
                  onTap: () => setState(() => _stockIn = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: 'Quantity ($unit)'),
          ),
          Slider(
            value: _qty,
            max: _max,
            onChanged: (value) =>
                setState(() => _qtyCtrl.text = value.toStringAsFixed(1)),
          ),
          Wrap(
            spacing: 8,
            children: [1, 2, 5, 10]
                .map(
                  (value) => ActionChip(
                    label: TfText('+$value'),
                    onPressed: () => setState(
                      () => _qtyCtrl.text = value.toStringAsFixed(0),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          TfButton(
            label: _stockIn ? 'Add to stock' : 'Record used stock',
            busy: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _StandardItemRow extends StatelessWidget {
  const _StandardItemRow({
    required this.item,
    required this.text,
    required this.showBorder,
  });

  final InventorySummaryItem item;
  final AppStrings text;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final primaryName = InventoryItem.localizedNameParts(
      nameEn: item.nameEn,
      nameBn: item.nameBn,
      language: text.language,
    );
    final secondaryName = text.isBn ? item.nameEn : item.nameBn;
    final unit = InventoryUnits.displayLabel(item.unit, isBn: text.isBn);
    return InkWell(
      onTap: () => _openInventoryDetail(context, item),
      onLongPress: () => _openQuickAdjustSheet(context, item),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(top: BorderSide(color: PosColors.line, width: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 17,
              child: Row(
                children: [
                  _InventoryAvatar(name: primaryName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TfText(
                          primaryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PosColors.primaryDark,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        if (secondaryName.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          TfText(
                            secondaryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PosColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: _InventoryQty(
                value: item.onHand,
                unit: unit,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              flex: 9,
              child: _InventoryQty(
                value: item.todayOut <= 0 ? null : -item.todayOut,
                unit: unit,
                textAlign: TextAlign.end,
                mutedWhenEmpty: true,
              ),
            ),
            Expanded(
              flex: 7,
              child: Align(
                alignment: Alignment.centerRight,
                child: item.isLow || item.isOut
                    ? _InventoryStatusPill(item: item, text: text)
                    : const _InventoryQuietStatus(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryOutlinedCard extends StatelessWidget {
  const _InventoryOutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PosRadii.md),
      child: Container(
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(color: PosColors.line, width: 0.5),
        ),
        child: child,
      ),
    );
  }
}

class _InventoryEyebrow extends StatelessWidget {
  const _InventoryEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: PosColors.muted,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _InventoryAvatar extends StatelessWidget {
  const _InventoryAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: PosColors.primaryWash,
        borderRadius: BorderRadius.circular(PosRadii.sm),
      ),
      alignment: Alignment.center,
      child: TfText(
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
        style: const TextStyle(
          color: PosColors.primaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InventoryQty extends StatelessWidget {
  const _InventoryQty({
    required this.value,
    required this.unit,
    required this.textAlign,
    this.mutedWhenEmpty = false,
  });

  final double? value;
  final String unit;
  final TextAlign textAlign;
  final bool mutedWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final empty = value == null;
    final color = empty && mutedWhenEmpty
        ? PosColors.mutedSoft
        : PosColors.primaryDark;
    return TfText(
      empty
          ? '—'
          : '${value! < 0 ? '−' : ''}${_compactQty(value!.abs())} $unit',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        color: color,
        fontSize: empty ? 13 : 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InventoryStatusPill extends StatelessWidget {
  const _InventoryStatusPill({required this.item, required this.text});

  final InventorySummaryItem item;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final out = item.isOut;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: out ? PosColors.dangerSoft : PosColors.warningSoft,
        borderRadius: BorderRadius.circular(PosRadii.xs),
      ),
      child: TfText(
        out ? text.statusOut : text.statusLow,
        style: TextStyle(
          color: out ? PosColors.danger : PosColors.warning,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InventoryQuietStatus extends StatelessWidget {
  const _InventoryQuietStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: PosColors.mutedSoft,
        shape: BoxShape.circle,
      ),
    );
  }
}

String _compactQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// TIER 1 — Simple inventory (counter / juice bar)
// KPI duo · top movers · stock-in + count CTAs
// ─────────────────────────────────────────────────────────────────────────────

class _InvSimple extends StatelessWidget {
  const _InvSimple({
    required this.app,
    required this.text,
    required this.summary,
    required this.onNavigateToOrders,
    required this.onNavigateToTarget,
  });

  final dynamic app;
  final AppStrings text;
  final InventorySummary? summary;
  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final items = summary?.items ?? [];
    final stockValue = summary?.stockValueBdt ?? 0.0;
    final usedToday = items.fold<double>(0, (s, i) => s + i.todaySpendBdt);
    final moneyFmt = NumberFormat('#,##0', 'en');

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: PosColors.primaryDark,
          backgroundColor: PosColors.primary,
          onRefresh: () async {
            await app.refreshInventorySummary();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TfText(
                            text.inventory,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: PosColors.primaryDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${items.length} items · counter',
                            style: const TextStyle(
                              fontSize: 12,
                              color: PosColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const HeaderModeButton(),
                  ],
                ),
              ),

              // KPI duo — Stock value | Used today
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: PosColors.surface,
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    border: Border.all(color: PosColors.line, width: 0.5),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'STOCK VALUE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: PosColors.mutedSoft,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '৳${moneyFmt.format(stockValue)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.primaryDark,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${items.length} SKUs',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: PosColors.mutedSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 0.5, color: PosColors.line),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'USED TODAY',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: PosColors.mutedSoft,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '৳${moneyFmt.format(usedToday)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.primaryDark,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PosColors.successSoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'vs avg',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: PosColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Top movers
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOP MOVERS · TODAY',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: PosColors.mutedSoft,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: PosColors.surface,
                          borderRadius: BorderRadius.circular(PosRadii.md),
                          border: Border.all(color: PosColors.line, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < items.take(4).length; i++)
                              _InvMoverRow(
                                rank: i + 1,
                                name: items[i].nameEn,
                                qty:
                                    '${items[i].onHand.toStringAsFixed(1)} ${items[i].unit}',
                                rev:
                                    '৳${moneyFmt.format(items[i].todaySpendBdt)}',
                                pct:
                                    items.isNotEmpty &&
                                        items.first.todaySpendBdt > 0
                                    ? (items[i].todaySpendBdt /
                                              items.first.todaySpendBdt)
                                          .clamp(0, 1)
                                    : 0,
                                showBorder: i > 0,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _InvBottomActions(text: text, app: app),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIER 3 — Advanced inventory (full-service)
// 3-KPI strip · reorder · reconciliation · menu costing
// ─────────────────────────────────────────────────────────────────────────────

class _InvAdvanced extends StatelessWidget {
  const _InvAdvanced({
    required this.app,
    required this.text,
    required this.summary,
    required this.onNavigateToOrders,
    required this.onNavigateToTarget,
  });

  final dynamic app;
  final AppStrings text;
  final InventorySummary? summary;
  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final items = summary?.items ?? [];
    final stockValue = summary?.stockValueBdt ?? 0.0;
    final alerts = summary?.alerts ?? 0;
    final lowItems = items.where((i) => i.isLow).toList();
    final outItems = items.where((i) => i.isOut).toList();
    final reorderItems = items
        .where((i) => i.isLow || i.isOut)
        .take(3)
        .toList();
    final moneyFmt = NumberFormat('#,##0', 'en');
    final healthOk = items.length - lowItems.length - outItems.length;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: PosColors.primaryDark,
          backgroundColor: PosColors.primary,
          onRefresh: () async {
            await app.refreshInventory();
            await app.refreshInventorySummary();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TfText(
                            text.inventory,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: PosColors.primaryDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${items.length} SKUs${alerts > 0 ? " · $alerts alerts" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: alerts > 0
                                  ? PosColors.danger
                                  : PosColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const HeaderModeButton(),
                    const SizedBox(width: 6),
                    TfIconButton(
                      icon: Icons.search_rounded,
                      tooltip: text.searchInventory,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 6),
                    HeaderNotificationBell(
                      onNavigateToOrders: onNavigateToOrders,
                      onNavigateToTarget: onNavigateToTarget,
                    ),
                  ],
                ),
              ),

              // 3-KPI strip — Stock value | Health | Food cost
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: PosColors.surface,
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    border: Border.all(color: PosColors.line, width: 0.5),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 11,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'STOCK VALUE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: PosColors.mutedSoft,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '৳${moneyFmt.format(stockValue)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.primaryDark,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${items.length} SKUs',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: PosColors.mutedSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 0.5, color: PosColors.line),
                        Expanded(
                          flex: 10,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'HEALTH',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: PosColors.mutedSoft,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$healthOk',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: PosColors.primaryDark,
                                        letterSpacing: -0.5,
                                        height: 1.0,
                                      ),
                                    ),
                                    Text(
                                      '/${items.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: PosColors.mutedSoft,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (lowItems.isNotEmpty || outItems.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: PosColors.warningSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${lowItems.length} LOW · ${outItems.length} OUT',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: PosColors.warning,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  )
                                else
                                  const Text(
                                    'All stocked',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: PosColors.success,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 0.5, color: PosColors.line),
                        Expanded(
                          flex: 10,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FOOD COST',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: PosColors.mutedSoft,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '—',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.primaryDark,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PosColors.successSoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    '▼ target',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: PosColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Reorder suggestions
              if (reorderItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'REORDER · 7-DAY USAGE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: PosColors.mutedSoft,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${reorderItems.length} items',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: PosColors.mutedSoft,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: PosColors.surface,
                          borderRadius: BorderRadius.circular(PosRadii.md),
                          border: Border.all(color: PosColors.line, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < reorderItems.length; i++)
                              _ReorderRow(
                                item: reorderItems[i],
                                showBorder: i > 0,
                                moneyFmt: moneyFmt,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // All items list (same as standard but without category filter for T3)
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'ALL ITEMS',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: PosColors.mutedSoft,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'On hand · today',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: PosColors.mutedSoft,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: PosColors.surface,
                          borderRadius: BorderRadius.circular(PosRadii.md),
                          border: Border.all(color: PosColors.line, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            // Column header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: const BoxDecoration(
                                color: PosColors.surfaceSunk,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(PosRadii.md),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 17,
                                    child: Text(
                                      'ITEM',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: PosColors.mutedSoft,
                                        letterSpacing: 0.7,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 10,
                                    child: Text(
                                      'ON HAND',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: PosColors.mutedSoft,
                                        letterSpacing: 0.7,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 7,
                                    child: Text(
                                      'STATUS',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: PosColors.mutedSoft,
                                        letterSpacing: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (int i = 0; i < items.length; i++)
                              _AdvancedItemRow(
                                item: items[i],
                                showBorder: i > 0,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _InvBottomActions(text: text, app: app),
    );
  }
}

// Shared inventory row components

class _InvMoverRow extends StatelessWidget {
  const _InvMoverRow({
    required this.rank,
    required this.name,
    required this.qty,
    required this.rev,
    required this.pct,
    required this.showBorder,
  });

  final int rank;
  final String name;
  final String qty;
  final String rev;
  final double pct;
  final bool showBorder;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      border: showBorder
          ? const Border(top: BorderSide(color: PosColors.line, width: 0.5))
          : null,
    ),
    child: Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            rank.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: PosColors.mutedSoft,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: PosColors.primaryDark,
                    ),
                  ),
                  Text(
                    rev,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: PosColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: PosColors.surfaceSunk,
                        color: PosColors.inkSoft,
                        minHeight: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    qty,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: PosColors.mutedSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({
    required this.item,
    required this.showBorder,
    required this.moneyFmt,
  });

  final InventorySummaryItem item;
  final bool showBorder;
  final NumberFormat moneyFmt;

  @override
  Widget build(BuildContext context) {
    final isOut = item.isOut;
    final bgColor = isOut ? PosColors.dangerSoft : PosColors.warningSoft;
    final fgColor = isOut ? PosColors.danger : PosColors.warning;
    final label = isOut ? 'OUT' : 'LOW';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(top: BorderSide(color: PosColors.line, width: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(PosRadii.sm),
            ),
            child: Center(
              child: Text(
                item.nameEn.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PosColors.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.nameEn,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: PosColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: fgColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'on hand ${item.onHand.toStringAsFixed(1)} ${item.unit}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: PosColors.mutedSoft,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Reorder',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: PosColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'TAP TO ORDER',
                style: TextStyle(
                  fontSize: 10,
                  color: PosColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdvancedItemRow extends StatelessWidget {
  const _AdvancedItemRow({required this.item, required this.showBorder});

  final InventorySummaryItem item;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isOut
        ? PosColors.danger
        : item.isLow
        ? PosColors.warning
        : PosColors.mutedSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(top: BorderSide(color: PosColors.line, width: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 17,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: PosColors.primaryDark,
                    height: 1.15,
                  ),
                ),
                if (item.nameBn.isNotEmpty)
                  Text(
                    item.nameBn,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PosColors.mutedSoft,
                      fontFamily: 'Hind Siliguri',
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              '${item.onHand.toStringAsFixed(1)} ${item.unit}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PosColors.primaryDark,
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: item.isLow || item.isOut
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.isOut
                            ? PosColors.dangerSoft
                            : PosColors.warningSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.isOut ? 'OUT' : 'LOW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: PosColors.mutedSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Bottom action bar — Stock in + Start count
class _InvBottomActions extends StatelessWidget {
  const _InvBottomActions({required this.text, required this.app});
  final AppStrings text;
  final dynamic app;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: TfButton(
            label: text.stockIn,
            icon: Icons.add,
            variant: TfButtonVariant.primary,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockInScreen()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TfButton(
            label: text.isBn ? 'ব্যবহৃত' : 'Used',
            icon: Icons.remove_circle_outline,
            variant: TfButtonVariant.paper,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UsedStockScreen()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TfButton(
            label: text.endOfDayCount,
            icon: Icons.fact_check_outlined,
            variant: TfButtonVariant.dark,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EndOfDayCountScreen()),
            ),
          ),
        ),
      ],
    ),
  );
}
