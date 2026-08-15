import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/guided_tour.dart';
import '../../core/widgets/subscription_gate_card.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../core/widgets/tf_timeframe_selector.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_summary.dart';
import '../../models/inventory_unit.dart';
import '../../models/pos_notification.dart';
import '../../models/receipt_scan.dart';
import 'end_of_day_count_screen.dart';
import 'inventory_item_detail_screen.dart';
import 'stock_in_screen.dart';
import 'stock_suppliers_screen.dart';
import 'stock_variance_screen.dart';

/// QuickBytes Stock tab (spec §4.7). A single ranked white table with a
/// per-user **Advanced** toggle (cover column + variance/suppliers drill-downs
/// + tap-to-detail). A fixed-width status-dot column keeps every row aligned;
/// labeled bottom-bar actions (Count · Stock in) replace top-bar buttons.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    this.onRequestScan,
    this.pendingScan,
    this.onPendingScanResolved,
    super.key,
  });

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  /// Launches the stock scan (bill/count sheet) flow from the camera FAB.
  /// Wired by the shell to its drawer Stock ▸ Scan handler so the parsed
  /// result surfaces on the table in review mode.
  final VoidCallback? onRequestScan;

  /// A stock inventory scan (supplier bill or count sheet) awaiting
  /// confirmation. When set, the table switches to review mode: changed rows
  /// render the manual-edit preview (muted struck-through old value, green/red
  /// new value below) and a sticky Confirm/Cancel CTA replaces the bottom
  /// actions.
  final StockScanResult? pendingScan;

  /// Called when the pending scan is confirmed or cancelled so the shell can
  /// clear its review state.
  final VoidCallback? onPendingScanResolved;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

enum _StockSort { name, inOut, price, qty, status }

class _InventoryScreenState extends State<InventoryScreen> {
  _StockSort _sort = _StockSort.qty;
  int _dir = -1; // -1 desc, 1 asc
  bool _firstLoadKicked = false;
  bool _applying = false;
  final Uuid _uuid = const Uuid();

  TfTimeframe _timeframe = TfTimeframe.today;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  Future<void> _onQtyCommit(InventorySummaryItem item, double qty) async {
    final app = AppScope.read(context);
    try {
      await app.setInventoryQuantity(
        inventoryItemId: item.id,
        newQuantity: qty,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(error.toString())));
      rethrow;
    }
  }

  Future<void> _onPriceCommit(InventorySummaryItem item, double price) async {
    final app = AppScope.read(context);
    try {
      await app.setInventoryCostPrice(
        inventoryItemId: item.id,
        newCostPerUnit: price,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(error.toString())));
      rethrow;
    }
  }

  void _updateTimeframe(TfTimeframe tf) {
    setState(() {
      _timeframe = tf;
      _rangeStart = null;
      _rangeEnd = null;
    });

    final now = DateTime.now();
    String? start;
    String? end;

    if (tf == TfTimeframe.week) {
      final s = now.subtract(const Duration(days: 6));
      start = DateTime(s.year, s.month, s.day).toUtc().toIso8601String();
      end = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();
    } else if (tf == TfTimeframe.month) {
      final s = DateTime(now.year, now.month, 1);
      start = s.toUtc().toIso8601String();
      end = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();
    }

    AppScope.read(context).refreshInventorySummary(start: start, end: end);
  }

  void _onRangeChanged(DateTime? s, DateTime? e) {
    setState(() {
      _rangeStart = s;
      _rangeEnd = e;
      if (s != null && e != null) _timeframe = TfTimeframe.custom;
    });

    if (s != null && e != null) {
      final start = s.toUtc().toIso8601String();
      final end = DateTime(
        e.year,
        e.month,
        e.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();
      AppScope.read(context).refreshInventorySummary(start: start, end: end);
    }
  }

  void _toggleSort(_StockSort key) {
    setState(() {
      if (_sort == key) {
        _dir = -_dir;
      } else {
        _sort = key;
        _dir = key == _StockSort.name ? 1 : -1;
      }
    });
  }

  // Memoized sort: the inventory screen rebuilds on every controller
  // notification, but the row order only changes when the source list or the
  // sort/direction changes. Cache by source identity + sort key so we don't
  // re-sort the whole inventory each frame.
  List<InventorySummaryItem>? _sortedCache;
  List<InventorySummaryItem>? _sortedSource;
  _StockSort? _sortedKey;
  int? _sortedDir;

  List<InventorySummaryItem> _sorted(List<InventorySummaryItem> items) {
    if (_sortedCache != null &&
        identical(_sortedSource, items) &&
        _sortedKey == _sort &&
        _sortedDir == _dir) {
      return _sortedCache!;
    }
    final list = [...items];
    list.sort((a, b) {
      if (_sort == _StockSort.name) {
        return a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()) * _dir;
      }
      double r;
      switch (_sort) {
        case _StockSort.inOut:
          r = a.todayOut - b.todayOut;
          break;
        case _StockSort.price:
          r = a.costPerUnit - b.costPerUnit;
          break;
        case _StockSort.qty:
          r = a.onHand - b.onHand;
          break;
        case _StockSort.status:
          r = _ratio(a) - _ratio(b);
          break;
        case _StockSort.name:
          r = 0; // handled by the string compare above
      }
      if (r == 0) return 0;
      return (r > 0 ? 1 : -1) * _dir;
    });
    _sortedCache = list;
    _sortedSource = items;
    _sortedKey = _sort;
    _sortedDir = _dir;
    return list;
  }

  // ── Scan review mode ────────────────────────────────────────────────────

  bool get _reviewing => widget.pendingScan != null;

  InventorySummaryItem? _matchSummaryItem(
    List<InventorySummaryItem> items,
    ReceiptScanLine line,
  ) {
    final names = <String>[
      line.nameEn.trim().toLowerCase(),
      line.nameBn.trim().toLowerCase(),
    ].where((n) => n.isNotEmpty).toList(growable: false);
    if (names.isEmpty) return null;
    for (final item in items) {
      final itemNames = <String>[
        item.nameEn.trim().toLowerCase(),
        item.nameBn.trim().toLowerCase(),
      ].where((n) => n.isNotEmpty).toList(growable: false);
      for (final n in names) {
        for (final iname in itemNames) {
          if (n == iname || n.contains(iname) || iname.contains(n)) {
            return item;
          }
        }
      }
    }
    return null;
  }

  InventoryItem? _matchInventoryItem(
    List<InventoryItem> items,
    ReceiptScanLine line,
  ) {
    final names = <String>[
      line.nameEn.trim().toLowerCase(),
      line.nameBn.trim().toLowerCase(),
    ].where((n) => n.isNotEmpty).toList(growable: false);
    if (names.isEmpty) return null;
    for (final item in items) {
      final itemNames = <String>[
        item.name.trim().toLowerCase(),
        item.nameEn.trim().toLowerCase(),
        item.nameBn.trim().toLowerCase(),
      ].where((n) => n.isNotEmpty).toSet().toList(growable: false);
      for (final n in names) {
        for (final iname in itemNames) {
          if (n == iname || n.contains(iname) || iname.contains(n)) {
            return item;
          }
        }
      }
    }
    return null;
  }

  Map<String, _ScanCellPreview> _reviewData(List<InventorySummaryItem> items) {
    final scan = widget.pendingScan;
    if (scan == null) return const {};
    final previews = <String, _ScanCellPreview>{};
    switch (scan.category) {
      case StockScanCategory.count:
        for (final line in scan.items) {
          final id = line.matchedInventoryItemId;
          if (id == null || id.isEmpty) continue;
          InventorySummaryItem? item;
          for (final i in items) {
            if (i.id == id) {
              item = i;
              break;
            }
          }
          if (item == null) continue;
          previews[id] = _ScanCellPreview(
            qty: (item.onHand, line.qty),
            qtyStyle: _ScanQtyStyle.replace,
          );
        }
      case StockScanCategory.stockIn:
        for (final line in scan.items) {
          final item = _matchSummaryItem(items, line);
          if (item == null) continue;
          final prior = previews[item.id];
          final oldQty = prior?.qty.$1 ?? item.onHand;
          final newQty = (prior?.qty.$2 ?? oldQty) + line.qty;
          final price =
              line.unitPriceBdt > 0 &&
                  (item.costPerUnit - line.unitPriceBdt).abs() > 0.001
              ? (item.costPerUnit, line.unitPriceBdt)
              : prior?.price;
          previews[item.id] = _ScanCellPreview(
            qty: (oldQty, newQty),
            qtyStyle: _ScanQtyStyle.increment,
            price: price,
          );
        }
    }
    return previews;
  }

  void _cancelScan() {
    widget.onPendingScanResolved?.call();
  }

  Future<void> _confirmScan() async {
    if (_applying) return;
    final scan = widget.pendingScan;
    if (scan == null) return;
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _applying = true);
    var applied = 0;
    try {
      switch (scan.category) {
        case StockScanCategory.count:
          for (final line in scan.items) {
            final id = line.matchedInventoryItemId;
            if (id == null || id.isEmpty) continue;
            await app.setInventoryEndOfDayCount(
              inventoryItemId: id,
              quantity: line.qty,
            );
            applied++;
          }
        case StockScanCategory.stockIn:
          for (final line in scan.items) {
            final matched = _matchInventoryItem(app.inventoryItems, line);
            if (matched != null) {
              if (line.unitPriceBdt > 0 &&
                  (matched.costPerUnit - line.unitPriceBdt).abs() > 0.001) {
                await app.saveInventoryItem(
                  matched.copyWith(costPerUnit: line.unitPriceBdt),
                );
              }
              await app.recordInventoryPurchase(
                inventoryItemId: matched.id,
                quantity: line.qty,
                totalCostBdt: line.totalBdt,
                supplierId: null,
                supplierName: '',
                billRef: '',
              );
            } else {
              final name = line.nameEn.trim().isNotEmpty
                  ? line.nameEn.trim()
                  : line.nameBn.trim();
              if (name.isEmpty) continue;
              final newItem = InventoryItem(
                id: _uuid.v4(),
                name: name,
                category: '',
                unit: InventoryUnits.normalize(line.unit),
                quantity: 0,
                minThreshold: 0,
                costPerUnit: line.unitPriceBdt,
                notes: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await app.saveInventoryItem(newItem);
              await app.recordInventoryPurchase(
                inventoryItemId: newItem.id,
                quantity: line.qty,
                totalCostBdt: line.totalBdt,
                supplierId: null,
                supplierName: '',
                billRef: '',
              );
            }
            applied++;
          }
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: TfText(error.toString())));
      }
      return;
    } finally {
      if (mounted) setState(() => _applying = false);
    }
    // Clear the review state first: the table falls back to live values while
    // the summary refresh is in flight, and a second Confirm can't double-apply.
    widget.onPendingScanResolved?.call();
    await app.refreshInventorySummary();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(content: TfText(app.strings.scanReviewDone(applied))),
      );
    }
  }

  Future<void> _openStockIn(BuildContext context, {String? itemId}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => StockInScreen(preseedItemId: itemId)),
    );
    if (context.mounted) await AppScope.read(context).refreshInventorySummary();
  }

  Future<void> _openEndOfDayCount(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const EndOfDayCountScreen()),
    );
    if (context.mounted) await AppScope.read(context).refreshInventorySummary();
  }

  Future<void> _openRow(
    BuildContext context,
    PosAppController app,
    InventorySummaryItem item,
  ) async {
    if (_reviewing) return;
    final full = _resolveItem(app, item.id);
    if (full != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (detailCtx) => InventoryItemDetailScreen(
            item: full,
            onEdit: app.canManageStock
                ? () async {
                    final latest = _resolveItem(app, full.id) ?? full;
                    final result = await Navigator.push<InventoryItem>(
                      detailCtx,
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
      if (context.mounted) {
        await AppScope.read(context).refreshInventorySummary();
      }
      return;
    }
    await _openStockIn(context, itemId: item.id);
  }

  Future<void> _onLongPressRow(
    BuildContext context,
    PosAppController app,
    InventorySummaryItem item,
  ) async {
    final text = app.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: TfText(text.deleteInventoryItem),
        content: TfText(text.deleteInventoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: TfText(text.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: TfText(
              text.deleteAction,
              style: const TextStyle(color: PosColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await app.deleteInventoryItem(item.id);
      if (context.mounted) {
        await AppScope.read(context).refreshInventorySummary();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TfText(text.deleteInventoryConfirm)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.selectMany(context, const [
      AppAspect.inventory,
      AppAspect.language,
    ]);
    final text = app.strings;
    final summary = app.inventorySummary;

    if (!_firstLoadKicked) {
      _firstLoadKicked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        app.refreshInventorySummary();
      });
    }

    final items = summary?.items ?? const <InventorySummaryItem>[];
    final sorted = _sorted(items);
    final reviewing = _reviewing;
    final reviewPreviews = _reviewData(items);

    return AppScaffold(
      title: text.stockTab,
      headerWidget: TfGlobalTopBar(
        title: text.stockTab,
        onNavigateToOrders: widget.onNavigateToOrders,
        onNavigateToTarget: widget.onNavigateToTarget,
      ),
      pinHeader: true,
      fillBody: true,
      floatingActionButton: !reviewing && app.hasFeature('inventory')
          ? TourSpot(
              name: 'stock.scanFab',
              child: TfFab(
                icon: Icons.photo_camera_outlined,
                tooltip: text.scanStock,
                onPressed: widget.onRequestScan ?? () {},
              ),
            )
          : null,
      footer: reviewing
          ? TfStickyCTA(
              child: Row(
                children: [
                  Expanded(
                    child: TfButton(
                      label: text.cancel,
                      variant: TfButtonVariant.dark,
                      size: TfButtonSize.lg,
                      onPressed: _applying ? null : _cancelScan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TourSpot(
                      name: 'stock.scanConfirm',
                      child: TfButton(
                        label: text.scanReviewApply,
                        size: TfButtonSize.lg,
                        busy: _applying,
                        onPressed: _applying ? null : _confirmScan,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TourSpot(
                  name: 'stock.period',
                  child: TfPeriodWithCalendar(
                    compact: true,
                    options: [
                      ('today', text.rangeToday),
                      ('week', '7d'),
                      ('month', '30d'),
                    ],
                    value: _timeframe.name,
                    start: _rangeStart,
                    end: _rangeEnd,
                    onChanged: (value, start, end) {
                      if (value == TfPeriodWithCalendar.customValue) {
                        _onRangeChanged(start, end);
                      } else {
                        _updateTimeframe(TfTimeframe.values.byName(value));
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: PosSpacing.sp2),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TfButton(
                        label: text.countStock,
                        icon: Icons.fact_check_outlined,
                        variant: TfButtonVariant.paper,
                        size: TfButtonSize.sm,
                        onPressed: () => _openEndOfDayCount(context),
                      ),
                    ),
                    const SizedBox(width: PosSpacing.sp2),
                    Expanded(
                      child: TfButton(
                        label: text.stockIn,
                        icon: Icons.add_box_outlined,
                        variant: TfButtonVariant.paper,
                        size: TfButtonSize.sm,
                        onPressed: () => _openStockIn(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final app = AppScope.of(context);
                if (app.hasFeature('inventory')) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: PosSpacing.sp3),
                      Expanded(
                        child: Stack(
                          children: [
                            items.isEmpty
                                ? Center(
                                    child: TfEmptyState(
                                      icon: Icons.inventory_2_outlined,
                                      title: text.noStockItems,
                                      message:
                                          'Use Stock in to add your first item.',
                                      messageBn: text.addFirstStockItem,
                                      action: !reviewing &&
                                              app.canManageStock
                                          ? _AddItemButton(
                                              text: text,
                                              onPressed: () =>
                                                  _showAddItem(context),
                                            )
                                          : null,
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        TourSpot(
                                          name: 'stock.table',
                                          child: _StockTable(
                                            text: text,
                                            items: sorted,
                                            sort: _sort,
                                            dir: _dir,
                                            canEdit: app.canManageStock,
                                            onSort: _toggleSort,
                                            onRowTap: (item) =>
                                                _openRow(context, app, item),
                                            onLongPressRow: app.canManageStock
                                                ? (item) => _onLongPressRow(
                                                      context,
                                                      app,
                                                      item,
                                                    )
                                                : null,
                                            onQtyCommit: _onQtyCommit,
                                            onPriceCommit: _onPriceCommit,
                                            previews: reviewing
                                                ? reviewPreviews
                                                : const {},
                                            readOnly: reviewing,
                                          ),
                                        ),
                                        if (!reviewing) ...[
                                          const SizedBox(height: 12),
                                          TourSpot(
                                            name: 'stock.addItem',
                                            child: _AddItemButton(
                                              text: text,
                                              onPressed: () =>
                                                  _showAddItem(context),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        _AdvancedDrilldowns(text: text),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(PosSpacing.sp4),
                    child: const SubscriptionGateCard(feature: 'inventory'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers (spec formulas) ─────────────────────────────────────────────────

/// ratio = qty/par → ≥.6 ok · ≥.3 low · else out (no par ⇒ treated as ok).
String _stockKind(double onHand, double par) {
  if (par <= 0) return 'ok';
  final r = onHand / par;
  return r >= 0.6
      ? 'ok'
      : r >= 0.3
      ? 'low'
      : 'no';
}

double _ratio(InventorySummaryItem it) =>
    it.minThreshold > 0 ? it.onHand / it.minThreshold : 99;

InventoryItem? _resolveItem(PosAppController app, String id) {
  for (final i in app.inventoryItems) {
    if (i.id == id) return i;
  }
  return null;
}

// ── Stock table ────────────────────────────────────────────────────────────

class _StockTable extends StatelessWidget {
  const _StockTable({
    required this.text,
    required this.items,
    required this.sort,
    required this.dir,
    required this.canEdit,
    required this.onSort,
    required this.onRowTap,
    required this.onQtyCommit,
    required this.onPriceCommit,
    this.onLongPressRow,
    this.previews = const {},
    this.readOnly = false,
  });

  final AppStrings text;
  final List<InventorySummaryItem> items;
  final _StockSort sort;
  final int dir;
  final bool canEdit;
  final ValueChanged<_StockSort> onSort;
  final ValueChanged<InventorySummaryItem> onRowTap;
  final ValueChanged<InventorySummaryItem>? onLongPressRow;
  final Future<void> Function(InventorySummaryItem item, double qty)
  onQtyCommit;
  final Future<void> Function(InventorySummaryItem item, double price)
  onPriceCommit;
  final Map<String, _ScanCellPreview> previews;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    const heroW = 72.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 10),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 11, bottom: 9),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PosColors.lineStrong, width: 1.5),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                _HCell(
                  label: text.colItem,
                  active: sort == _StockSort.name,
                  dir: dir,
                  left: true,
                  onTap: () => onSort(_StockSort.name),
                ),
                const SizedBox(width: 12),
                _HCell(
                  label: readOnly ? text.colValue : text.colInOut,
                  width: 68,
                  active: sort == _StockSort.inOut,
                  dir: dir,
                  onTap: () => onSort(_StockSort.inOut),
                ),
                const SizedBox(width: 12),
                _HCell(
                  label: text.colUnitPrice,
                  width: 68,
                  active: sort == _StockSort.price,
                  dir: dir,
                  onTap: () => onSort(_StockSort.price),
                ),
                const SizedBox(width: 12),
                _HCell(
                  label: text.colQty,
                  width: heroW,
                  active: sort == _StockSort.qty,
                  dir: dir,
                  onTap: () => onSort(_StockSort.qty),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _StockRow(
              text: text,
              item: items[i],
              last: i == items.length - 1,
              heroW: heroW,
              canEdit: canEdit && !readOnly,
              reviewing: readOnly,
              onTap: () => onRowTap(items[i]),
              onLongPress: onLongPressRow == null
                  ? null
                  : () => onLongPressRow!(items[i]),
              onQtyCommit: onQtyCommit,
              onPriceCommit: onPriceCommit,
              preview: previews[items[i].id],
            ),
        ],
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  const _HCell({
    required this.label,
    required this.active,
    required this.dir,
    required this.onTap,
    this.width,
    this.left = false,
  });

  final String label;
  final bool active;
  final int dir;
  final VoidCallback onTap;
  final double? width;
  final bool left;

  @override
  Widget build(BuildContext context) {
    final cell = InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: left
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          Flexible(
            child: TfText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TfTextStyles.eyebrow.copyWith(
                color: active ? PosColors.accentStrong : PosColors.muted,
                letterSpacing: 0.55,
                fontSize: 10,
              ),
            ),
          ),
          if (active)
            Icon(
              dir < 0 ? Icons.arrow_drop_down : Icons.arrow_drop_up,
              size: 16,
              color: PosColors.accentStrong,
            ),
        ],
      ),
    );
    if (width != null) {
      return SizedBox(width: width, child: cell);
    }
    return Expanded(child: cell);
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.text,
    required this.item,
    required this.last,
    required this.heroW,
    required this.canEdit,
    required this.reviewing,
    required this.onTap,
    required this.onQtyCommit,
    required this.onPriceCommit,
    this.onLongPress,
    this.preview,
  });

  final AppStrings text;
  final InventorySummaryItem item;
  final bool last;
  final double heroW;
  final bool canEdit;
  final bool reviewing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Future<void> Function(InventorySummaryItem item, double qty)
  onQtyCommit;
  final Future<void> Function(InventorySummaryItem item, double price)
  onPriceCommit;
  final _ScanCellPreview? preview;

  @override
  Widget build(BuildContext context) {
    final kind = _stockKind(item.onHand, item.minThreshold);
    final p = preview;
    final name = InventoryItem.localizedNameParts(
      nameEn: item.nameEn,
      nameBn: item.nameBn,
      language: text.language,
    );
    final unit = InventoryUnits.displayLabel(item.unit, isBn: text.isBn);
    final qtyColor = kind == 'no'
        ? PosColors.danger
        : kind == 'low'
        ? PosColors.warning
        : PosColors.text;
    final baseValue = item.onHand * item.costPerUnit;
    final shownValue =
        (p?.qty.$2 ?? item.onHand) * (p?.price?.$2 ?? item.costPerUnit);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: last ? Colors.transparent : PosColors.line),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              onLongPress: canEdit ? onLongPress : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 10,
                      child: Center(
                        child: kind == 'ok'
                            ? const SizedBox.shrink()
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kind == 'low'
                                      ? PosColors.warning
                                      : PosColors.danger,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TfText(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TfTextStyles.rowMoney.copyWith(
                              color: PosColors.text,
                              fontSize: 12,
                            ),
                          ),
                          if (!reviewing) ...[
                            const SizedBox(height: 2),
                            TfText(
                              shownValue == 0
                                  ? '—'
                                  : tfFormatCurrency(context, shownValue),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TfTextStyles.label.copyWith(
                                color: PosColors.muted,
                                fontSize: 10,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 68,
                      child: reviewing
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children:
                                  (p != null &&
                                          (shownValue - baseValue).abs() >=
                                              0.01)
                                      ? [
                                          TfText(
                                            tfFormatCurrency(
                                                context, baseValue),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TfTextStyles.rowMoney
                                                .copyWith(
                                              fontSize: 10,
                                              color: PosColors.muted,
                                              decoration: TextDecoration
                                                  .lineThrough,
                                              decorationColor:
                                                  PosColors.muted,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          TfText(
                                            tfFormatCurrency(
                                                context, shownValue),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TfTextStyles.rowMoney
                                                .copyWith(
                                              fontSize: 12,
                                              color: shownValue > baseValue
                                                  ? PosColors.success
                                                  : PosColors.danger,
                                              fontWeight: FontWeight.w700,
                                              fontFeatures: const [
                                                FontFeature
                                                    .tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ]
                                      : [
                                          TfText(
                                            shownValue == 0
                                                ? '—'
                                                : tfFormatCurrency(context,
                                                    shownValue),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TfTextStyles.label
                                                .copyWith(
                                              color: PosColors.muted,
                                              fontSize: 10,
                                              fontFeatures: const [
                                                FontFeature
                                                    .tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (item.todayIn > 0)
                                  TfText(
                                    '+${tfFormatNumber(context, item.todayIn)}',
                                    style: TfTextStyles.label.copyWith(
                                      color: PosColors.success,
                                      fontSize: 10,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                if (item.todayOut > 0)
                                  TfText(
                                    '-${tfFormatNumber(context, item.todayOut)}',
                                    style: TfTextStyles.label.copyWith(
                                      color: PosColors.muted,
                                      fontSize: 10,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                if (item.todayIn == 0 && item.todayOut == 0)
                                  TfText(
                                    '—',
                                    style: TfTextStyles.bodyMuted.copyWith(
                                      color: PosColors.mutedSoft,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: _ScrubCell(
              key: ValueKey('price-${item.id}'),
              item: item,
              mode: _ScrubMode.price,
              canEdit: canEdit,
              width: 68,
              onCommit: onPriceCommit,
              preview: p == null || p.price == null
                  ? null
                  : _CellPreviewPair(p.price!),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: _ScrubCell(
              key: ValueKey('qty-${item.id}'),
              item: item,
              mode: _ScrubMode.qty,
              unit: unit,
              qtyColor: qtyColor,
              canEdit: canEdit,
              width: heroW,
              onCommit: onQtyCommit,
              preview: p == null
                  ? null
                  : _CellPreviewPair(
                      p.qty,
                      incrementStyle:
                          p.qtyStyle == _ScanQtyStyle.increment,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How a scan preview renders on the qty cell: stock-in shows the current
/// value with a green +N increment below (no slash); count shows the
/// struck-through old value with the new counted quantity in red below.
enum _ScanQtyStyle { increment, replace }

/// Review-mode preview pair (old, new) rendered by [_ScrubCell] in the exact
/// manual-edit style: muted struck-through old on top, green/red new below.
class _ScanCellPreview {
  const _ScanCellPreview({
    required this.qty,
    this.qtyStyle = _ScanQtyStyle.replace,
    this.price,
  });

  final (double, double) qty;
  final _ScanQtyStyle qtyStyle;
  final (double, double)? price;
}

/// (old, new) value pair plus rendering style, handed to a [_ScrubCell] during
/// scan review. With [incrementStyle] the cell keeps its current value and
/// shows the signed delta below instead of a struck-through replacement.
class _CellPreviewPair {
  const _CellPreviewPair(this.value, {this.incrementStyle = false});

  final (double, double) value;
  final bool incrementStyle;
}

enum _ScrubMode { qty, price }

/// Tap-to-edit cell with a delta scrubber: tapping the value opens an anchored
/// popover (slider + editor + "26 +8" label) over the cell; any outside tap
/// commits and closes. While the value differs from the original, the cell
/// shows the struck-through original (muted) with the new value in
/// green/red below; after commit the pair flashes ~1s, then the cell settles
/// on the new value. In scan-review mode a [preview] pair is rendered in the
/// exact same style (read-only, no scrubber).
class _ScrubCell extends StatefulWidget {
  const _ScrubCell({
    required this.item,
    required this.mode,
    required this.canEdit,
    required this.width,
    required this.onCommit,
    this.unit = '',
    this.qtyColor,
    this.preview,
    super.key,
  });

  final InventorySummaryItem item;
  final _ScrubMode mode;
  final bool canEdit;
  final double width;
  final String unit;
  final Color? qtyColor;
  final Future<void> Function(InventorySummaryItem item, double value) onCommit;

  /// (old, new) value pair rendered like an in-progress edit. When set the
  /// cell is read-only and previews its delta instead of the live value.
  final _CellPreviewPair? preview;

  @override
  State<_ScrubCell> createState() => _ScrubCellState();
}

class _ScrubCellState extends State<_ScrubCell> {
  static const double _panelWidth = 232;
  static const double _panelHeight = 128;

  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _flashTimer;
  bool _editing = false;
  bool _busy = false;
  bool _flash = false;
  double _openValue = 0;
  double _value = 0;
  double _flashOld = 0;
  double _flashValue = 0;

  bool get _isPrice => widget.mode == _ScrubMode.price;

  double get _current =>
      _isPrice ? widget.item.costPerUnit : widget.item.onHand;

  double get _maxDelta => math.max(_current.abs(), _isPrice ? 100 : 10);

  @override
  void dispose() {
    _flashTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _open() {
    if (!widget.canEdit || _busy || _editing || widget.preview != null) return;
    final anchor = _anchorKey.currentContext;
    if (anchor == null) return;
    final box = anchor.findRenderObject() as RenderBox?;
    if (box == null) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _editing = true;
      _openValue = _current;
      _value = _current;
    });
    _overlayEntry = OverlayEntry(
      builder: (_) => _ScrubPanel(
        mode: widget.mode,
        current: _openValue,
        value: _value,
        unit: widget.unit,
        maxDelta: _maxDelta,
        anchorRect: rect,
        onChanged: (value) => setState(() => _value = value),
        onSubmit: _commit,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _commit() async {
    if (!_editing || _busy) return;
    _closeOverlay();
    final value = _value;
    final delta = value - _openValue;
    setState(() => _editing = false);
    if (delta.abs() < 0.0001) return;
    _busy = true;
    var ok = false;
    try {
      await widget.onCommit(widget.item, value);
      ok = true;
    } catch (_) {
      // Screen-level callback shows the snackbar; keep the old value.
    } finally {
      _busy = false;
      if (mounted && ok) {
        setState(() {
          _flash = true;
          _flashOld = _openValue;
          _flashValue = value;
        });
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) setState(() => _flash = false);
        });
      }
    }
  }

  static String _formatQty(BuildContext context, double value) {
    if (value == value.roundToDouble()) return tfFormatNumber(context, value);
    return tfFormatNumber(context, value, decimalDigits: 1);
  }

  static String _formatPlain(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    var s = value.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  String _line(double value) =>
      _isPrice ? tfFormatCurrency(context, value) : _formatQty(context, value);

  @override
  Widget build(BuildContext context) {
    final current = _current;
    double base;
    double shown;
    if (_editing) {
      base = _openValue;
      shown = _value;
    } else if (_flash) {
      base = _flashOld;
      shown = _flashValue;
    } else if (widget.preview != null) {
      base = widget.preview!.value.$1;
      shown = widget.preview!.value.$2;
    } else {
      base = current;
      shown = current;
    }
    final delta = shown - base;
    final showPreview =
        (_editing || _flash || widget.preview != null) && delta.abs() >= 0.0001;
    final deltaColor = delta > 0 ? PosColors.success : PosColors.danger;
    // Stock-in scan qty previews keep the current value and show only the
    // signed increment below; count previews (and price) replace it.
    final incrementStyle = !_isPrice &&
        widget.preview != null &&
        widget.preview!.incrementStyle;
    // Count qty previews are corrections — always red, not delta-colored.
    final newColor = !_isPrice && widget.preview != null && !incrementStyle
        ? PosColors.danger
        : deltaColor;

    return KeyedSubtree(
      key: _anchorKey,
      child: SizedBox(
        width: widget.width,
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _open,
            behavior: HitTestBehavior.opaque,
            child: showPreview
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: incrementStyle
                        ? [
                            TfText(
                              _line(base),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TfTextStyles.rowMoney.copyWith(
                                fontSize: 12,
                                color: widget.qtyColor ?? PosColors.text,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 1),
                            TfText(
                              '${delta > 0 ? '+' : ''}${_line(delta)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TfTextStyles.rowMoney.copyWith(
                                fontSize: 12,
                                color: PosColors.success,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ]
                        : [
                            TfText(
                              _line(base),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TfTextStyles.rowMoney.copyWith(
                                fontSize: 10,
                                color: PosColors.muted,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: PosColors.muted,
                              ),
                            ),
                            const SizedBox(height: 1),
                            TfText(
                              _line(shown),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TfTextStyles.rowMoney.copyWith(
                                fontSize: 12,
                                color: newColor,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isPrice) ...[
                          TfText(
                            current > 0 ? _line(current) : '—',
                            style: TfTextStyles.rowMoney.copyWith(
                              color: current > 0
                                  ? PosColors.text
                                  : PosColors.mutedSoft,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          TfText(
                            _formatQty(context, current),
                            style: TfTextStyles.rowMoney.copyWith(
                              color: widget.qtyColor ?? PosColors.text,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 3),
                          TfText(
                            widget.unit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TfTextStyles.label.copyWith(
                              color: PosColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Popover panel for [_ScrubCell]: label ("26 +8"), center-zero delta
/// slider and a numeric editor synced both ways. Rendered in the app Overlay;
/// a full-screen barrier beneath it commits on any outside tap.
class _ScrubPanel extends StatefulWidget {
  const _ScrubPanel({
    required this.mode,
    required this.current,
    required this.value,
    required this.unit,
    required this.maxDelta,
    required this.anchorRect,
    required this.onChanged,
    required this.onSubmit,
  });

  final _ScrubMode mode;
  final double current;
  final double value;
  final String unit;
  final double maxDelta;
  final Rect anchorRect;
  final ValueChanged<double> onChanged;
  final VoidCallback onSubmit;

  @override
  State<_ScrubPanel> createState() => _ScrubPanelState();
}

class _ScrubPanelState extends State<_ScrubPanel> {
  late final TextEditingController _controller;
  late double _value;

  bool get _isPrice => widget.mode == _ScrubMode.price;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _controller = TextEditingController(
      text: _ScrubCellState._formatPlain(_value),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final w = _ScrubCellState._panelWidth;
    final h = _ScrubCellState._panelHeight;
    final rect = widget.anchorRect;
    final below = rect.bottom + 6 + h <= screen.height - 4;
    final top = below ? rect.bottom + 6 : math.max(4.0, rect.top - 6 - h);
    final left = (rect.center.dx - w / 2).clamp(8.0, screen.width - w - 8);

    final delta = _value - widget.current;
    final deltaColor = delta > 0
        ? PosColors.success
        : delta < 0
        ? PosColors.danger
        : PosColors.text;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSubmit,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: w,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.md),
                border: Border.all(color: PosColors.line),
                boxShadow: PosShadows.soft,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: TfText(
                          _isPrice
                              ? tfFormatCurrency(context, _value)
                              : _ScrubCellState._formatQty(context, _value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TfTextStyles.rowMoney.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (delta.abs() >= 0.0001)
                        TfText(
                          '${delta > 0 ? '+' : '-'}'
                          '${_ScrubCellState._formatQty(context, delta.abs())}',
                          maxLines: 1,
                          style: TfTextStyles.rowMoney.copyWith(
                            fontSize: 12,
                            color: deltaColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Slider(
                    value: delta.clamp(-widget.maxDelta, widget.maxDelta),
                    min: -widget.maxDelta,
                    max: widget.maxDelta,
                    onChanged: (d) {
                      final next = widget.current + d.roundToDouble();
                      setState(() {
                        _value = next;
                        _controller.text = _ScrubCellState._formatPlain(next);
                      });
                      widget.onChanged(next);
                    },
                  ),
                  Row(
                    children: [
                      if (_isPrice) ...[
                        TfText(
                          '৳',
                          style: TfTextStyles.rowMoney.copyWith(
                            color: PosColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                          ],
                          textAlign: TextAlign.right,
                          style: TfTextStyles.rowMoney.copyWith(
                            fontSize: 12,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          onChanged: (text) {
                            final parsed = double.tryParse(text);
                            if (parsed == null || parsed < 0) return;
                            setState(() => _value = parsed);
                            widget.onChanged(parsed);
                          },
                          onSubmitted: (_) => widget.onSubmit(),
                          onTapOutside: (details) {
                            final box =
                                context.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            final local = box.globalToLocal(details.position);
                            if (local.dx >= -8 &&
                                local.dy >= -8 &&
                                local.dx <= box.size.width + 8 &&
                                local.dy <= box.size.height + 8) {
                              return;
                            }
                            widget.onSubmit();
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      if (!_isPrice) ...[
                        const SizedBox(width: 4),
                        TfText(
                          widget.unit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TfTextStyles.label.copyWith(
                            color: PosColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Advanced drill-downs ─────────────────────────────────────────────────────

class _AdvancedDrilldowns extends StatelessWidget {
  const _AdvancedDrilldowns({required this.text});

  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final suppliers = AppScope.select(
      context,
      AppAspect.suppliers,
    ).inventorySuppliers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfText(
          text.advancedSection.toUpperCase(),
          style: TfTextStyles.eyebrow.copyWith(
            color: PosColors.muted,
            letterSpacing: 0.55,
          ),
        ),
        const SizedBox(height: 9),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TourSpot(
                  name: 'stock.variance',
                  child: _DrillCard(
                    icon: Icons.swap_vert_rounded,
                    label: text.dailyVariance,
                    hint: text.expectedVsCounted,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StockVarianceScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TourSpot(
                  name: 'stock.suppliers',
                  child: _DrillCard(
                    icon: Icons.local_shipping_outlined,
                    label: text.suppliers,
                    hint: text.suppliersCount(suppliers.length),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.bolt_rounded,
              size: 15,
              color: PosColors.accentStrong,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TfText(
                text.stockItemDetailHint,
                style: TfTextStyles.bodyMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DrillCard extends StatelessWidget {
  const _DrillCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PosRadii.card),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.card),
          border: Border.all(color: PosColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: PosColors.surfaceSunk,
                borderRadius: BorderRadius.circular(PosRadii.md),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: PosColors.text),
            ),
            const SizedBox(height: 9),
            TfText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TfTextStyles.rowTitle,
            ),
            const SizedBox(height: 1),
            TfText(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TfTextStyles.bodyMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add item + bottom bar ─────────────────────────────────────────────────────

class _AddItemButton extends StatelessWidget {
  const _AddItemButton({required this.text, required this.onPressed});

  final AppStrings text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(PosRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(color: PosColors.lineStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 18,
              color: PosColors.accentStrong,
            ),
            const SizedBox(width: 8),
            TfText(
              text.addInventoryItem,
              style: TfTextStyles.ctaLabel.copyWith(
                color: PosColors.accentStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add item ─────────────────────────────────────────────────────────────────

Future<void> _showAddItem(BuildContext context) async {
  final app = AppScope.read(context);
  final result = await Navigator.push<InventoryItem>(
    context,
    MaterialPageRoute(
      builder: (_) => _ItemFormSheet(text: app.strings, fullScreen: true),
    ),
  );
  if (result != null) {
    await app.saveInventoryItem(result);
    if (context.mounted) await app.refreshInventorySummary();
  }
}

// ── Sheet shell + add/edit item form (preserved) ─────────────────────────────

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: PosSpacing.sp2),
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
                    child: TfText(title, style: TfTextStyles.appBarTitle),
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

class _ItemFormSheet extends StatefulWidget {
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
          style: TfTextStyles.bodyMuted.copyWith(color: PosColors.slate),
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
            ...AppScope.select(
              context,
              AppAspect.suppliers,
            ).inventorySuppliers.map(
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
            style: TfTextStyles.appBarTitle,
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
