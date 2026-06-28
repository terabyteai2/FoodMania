import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_timeframe_selector.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_summary.dart';
import '../../models/inventory_unit.dart';
import '../../models/pos_notification.dart';
import '../../models/receipt_scan.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';
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
    super.key,
  });

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

enum _StockSort { name, inOut, net, value, qty, status }

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  bool _advanced = false;
  _StockSort _sort = _StockSort.value;
  int _dir = -1; // -1 desc, 1 asc
  bool _firstLoadKicked = false;
  bool _scanning = false;
  final MenuImageService _imageService = MenuImageService();

  TfTimeframe _timeframe = TfTimeframe.today;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _showCalendar = false;
  bool _calendarClosing = false;

  late final AnimationController _tfController;
  late final Animation<double> _tfAnimation;

  @override
  void initState() {
    super.initState();
    _tfController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _tfAnimation = CurvedAnimation(
      parent: _tfController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _tfController.dispose();
    super.dispose();
  }

  void _onToggleAdvanced(bool v) {
    setState(() => _advanced = v);
    if (v) {
      _tfController.forward();
    } else {
      _tfController.reverse();
      // Reset to today when turning off advanced
      if (_timeframe != TfTimeframe.today) {
        _updateTimeframe(TfTimeframe.today);
      }
    }
  }

  void _updateTimeframe(TfTimeframe tf) {
    if (tf == TfTimeframe.custom) {
      setState(() => _showCalendar = true);
      return;
    }

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
      if (s != null && e != null) {
        _calendarClosing = true;
        _timeframe = TfTimeframe.custom;
      }
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

  void _surfaceBelowPar() {
    // Tapping the "Below par" card sorts worst-first (ascending qty/par ratio).
    setState(() {
      _sort = _StockSort.status;
      _dir = 1;
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
        case _StockSort.net:
          r = (a.todayIn - a.todayOut) - (b.todayIn - b.todayOut);
          break;
        case _StockSort.qty:
          r = a.onHand - b.onHand;
          break;
        case _StockSort.status:
          r = _ratio(a) - _ratio(b);
          break;
        case _StockSort.value:
        case _StockSort.name:
          r = _itemValue(a) - _itemValue(b);
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

  Future<void> _openStockIn(BuildContext context, {String? itemId}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => StockInScreen(preseedItemId: itemId)),
    );
    if (context.mounted) await AppScope.read(context).refreshInventorySummary();
  }

  Future<void> _openCount(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const EndOfDayCountScreen()),
    );
    if (context.mounted) await AppScope.read(context).refreshInventorySummary();
  }

  /// The hero action: snap a supplier bill OR a count sheet, let the backend
  /// classify it, then route into the pre-filled Stock-in or End-of-day screen.
  Future<void> _scanAndRoute(BuildContext context) async {
    if (_scanning) return;
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _scanning = true);
    StockScanResult? result;
    try {
      final page = await _imageService.captureMenuScanPage(pageNumber: 1);
      if (page == null) {
        if (mounted) setState(() => _scanning = false);
        return;
      }
      result = await app.scanInventoryStock([
        MenuScanPageUpload(
          bytes: page.bytes,
          fileName: page.fileName,
          mimeType: page.mimeType,
        ),
      ]);
    } on CloudApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on MenuImageException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    if (result == null || !context.mounted) return;

    final route = switch (result.category) {
      StockScanCategory.count => MaterialPageRoute<void>(
        builder: (_) => EndOfDayCountScreen(initialScan: result),
      ),
      StockScanCategory.stockIn => MaterialPageRoute<void>(
        builder: (_) => StockInScreen(initialScan: result),
      ),
    };
    await Navigator.push<void>(context, route);
    if (context.mounted) await AppScope.read(context).refreshInventorySummary();
  }

  Future<void> _openRow(
    BuildContext context,
    PosAppController app,
    InventorySummaryItem item,
  ) async {
    if (_advanced) {
      final full = _resolveItem(app, item.id);
      if (full != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (detailCtx) => InventoryItemDetailScreen(
              item: full,
              onEdit: app.isOwner
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
    }
    await _openStockIn(context, itemId: item.id);
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
    final stockValue = items.fold<double>(0, (s, i) => s + _itemValue(i));
    final lowCount = items
        .where((i) => _stockKind(i.onHand, i.minThreshold) != 'ok')
        .length;
    final sorted = _sorted(items);

    return AppScaffold(
      title: text.stockTab,
      headerWidget: AppPageHeader(
        title: text.stockTab,
        onNavigateToOrders: widget.onNavigateToOrders,
        onNavigateToTarget: widget.onNavigateToTarget,
      ),
      showDatePill: false,
      pinHeader: true,
      fillBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryStrip(
            text: text,
            stockValue: stockValue,
            lowCount: lowCount,
            lowActive: _sort == _StockSort.status,
            onTapLow: _surfaceBelowPar,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const TfMicroLabel('INVENTORY'),
              const Spacer(),
              AdvToggle(
                value: _advanced,
                onChanged: _onToggleAdvanced,
                label: text.advanced,
              ),
            ],
          ),
          SizeTransition(
            sizeFactor: _tfAnimation,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TfTimeframeSelector(
                selected: _timeframe,
                onChanged: _updateTimeframe,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              children: [
                items.isEmpty
                    ? Center(
                        child: TfEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: text.noStockItems,
                          message: 'Use Stock in to add your first item.',
                          messageBn: text.addFirstStockItem,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StockTable(
                              text: text,
                              items: sorted,
                              advanced: _advanced,
                              sort: _sort,
                              dir: _dir,
                              onSort: _toggleSort,
                              onRowTap: (item) => _openRow(context, app, item),
                            ),
                            const SizedBox(height: 12),
                            _AddItemButton(
                              text: text,
                              onPressed: () => _showAddItem(context),
                            ),
                            if (_advanced) ...[
                              const SizedBox(height: 14),
                              _AdvancedDrilldowns(text: text),
                            ],
                          ],
                        ),
                      ),
                if (_showCalendar)
                  AnimatedOpacity(
                    opacity: _calendarClosing ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    onEnd: _calendarClosing
                        ? () => setState(() {
                            _showCalendar = false;
                            _calendarClosing = false;
                          })
                        : null,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => setState(() => _showCalendar = false),
                            child: Container(color: Colors.black26),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: TfCalendarRangePicker(
                            start: _rangeStart,
                            end: _rangeEnd,
                            onRangeChanged: _onRangeChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _StockBottomBar(
            text: text,
            scanning: _scanning,
            onScan: () => _scanAndRoute(context),
            onCount: () => _openCount(context),
            onStockIn: () => _openStockIn(context),
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

double _itemValue(InventorySummaryItem it) => it.onHand * it.costPerUnit;

InventoryItem? _resolveItem(PosAppController app, String id) {
  for (final i in app.inventoryItems) {
    if (i.id == id) return i;
  }
  return null;
}

// ── Summary strip ───────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.text,
    required this.stockValue,
    required this.lowCount,
    required this.lowActive,
    required this.onTapLow,
  });

  final AppStrings text;
  final double stockValue;
  final int lowCount;
  final bool lowActive;
  final VoidCallback onTapLow;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryCard(
              label: text.stockValue,
              child: TfText(
                tfFormatCurrency(context, stockValue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: PosColors.text,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: text.belowPar,
              active: lowActive,
              onTap: onTapLow,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  TfText(
                    tfFormatNumber(context, lowCount),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: lowCount > 0 ? PosColors.warning : PosColors.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: TfText(
                      text.isBn ? 'টি আইটেম' : 'items',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PosColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.child,
    this.active = false,
    this.onTap,
  });

  final String label;
  final Widget child;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: active ? PosColors.accentSoft : PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(
          color: active ? PosColors.primaryWash : PosColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
          child,
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PosRadii.card),
      child: card,
    );
  }
}

// ── Stock table ────────────────────────────────────────────────────────────

class _StockTable extends StatelessWidget {
  const _StockTable({
    required this.text,
    required this.items,
    required this.advanced,
    required this.sort,
    required this.dir,
    required this.onSort,
    required this.onRowTap,
  });

  final AppStrings text;
  final List<InventorySummaryItem> items;
  final bool advanced;
  final _StockSort sort;
  final int dir;
  final ValueChanged<_StockSort> onSort;
  final ValueChanged<InventorySummaryItem> onRowTap;

  @override
  Widget build(BuildContext context) {
    final heroW = advanced ? 64.0 : 88.0;
    final valueW = advanced ? 0.0 : 70.0;
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
                if (advanced) ...[
                  const SizedBox(width: 12),
                  _HCell(
                    label: text.colInOut,
                    width: 68,
                    active: sort == _StockSort.inOut,
                    dir: dir,
                    onTap: () => onSort(_StockSort.inOut),
                  ),
                  const SizedBox(width: 12),
                  _HCell(
                    label: text.colNet,
                    width: 54,
                    active: sort == _StockSort.net,
                    dir: dir,
                    onTap: () => onSort(_StockSort.net),
                  ),
                ] else ...[
                  const SizedBox(width: 10),
                  _HCell(
                    label: text.colValue,
                    width: valueW,
                    active: sort == _StockSort.value,
                    dir: dir,
                    onTap: () => onSort(_StockSort.value),
                  ),
                ],
                const SizedBox(width: 12),
                _HCell(
                  label: advanced ? text.colCover : 'QTY',
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
              advanced: advanced,
              heroW: heroW,
              valueW: valueW,
              onTap: () => onRowTap(items[i]),
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
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: active ? PosColors.accentStrong : PosColors.muted,
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
    required this.advanced,
    required this.heroW,
    required this.valueW,
    required this.onTap,
  });

  final AppStrings text;
  final InventorySummaryItem item;
  final bool last;
  final bool advanced;
  final double heroW;
  final double valueW;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = _stockKind(item.onHand, item.minThreshold);
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

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: last ? Colors.transparent : PosColors.line,
            ),
          ),
        ),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TfText(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: PosColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TfText(
                    tfFormatCurrency(context, _itemValue(item)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: PosColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (advanced) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.todayIn > 0)
                      TfText(
                        '+${tfFormatNumber(context, item.todayIn)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PosColors.success,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (item.todayOut > 0)
                      TfText(
                        '-${tfFormatNumber(context, item.todayOut)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PosColors.muted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (item.todayIn == 0 && item.todayOut == 0)
                      const TfText(
                        '—',
                        style: TextStyle(
                          fontSize: 13,
                          color: PosColors.mutedSoft,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 54,
                child: Builder(
                  builder: (context) {
                    final net = item.todayIn - item.todayOut;
                    if (net == 0) {
                      return const TfText(
                        '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          color: PosColors.mutedSoft,
                        ),
                      );
                    }
                    return TfText(
                      '${net > 0 ? '+' : ''}${tfFormatNumber(context, net)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: net > 0 ? PosColors.success : PosColors.danger,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const SizedBox(width: 10),
              SizedBox(
                width: valueW,
                child: TfText(
                  tfFormatCurrency(context, _itemValue(item)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
            SizedBox(
              width: heroW,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: advanced
                      ? TfText(
                          _formatCover(context, item),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: qtyColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TfText(
                              _formatQty(context, item.onHand),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: qtyColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 3),
                            TfText(
                              unit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: PosColors.muted,
                              ),
                            ),
                          ],
                        ),
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

  static String _formatCover(BuildContext context, InventorySummaryItem item) {
    final ratio = _ratio(item);
    if (ratio >= 99) return 'OK';
    return '${tfFormatNumber(context, ratio, decimalDigits: 1)}x';
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: PosColors.muted,
          ),
        ),
        const SizedBox(height: 9),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
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
              const SizedBox(width: 10),
              Expanded(
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
                style: const TextStyle(fontSize: 12, color: PosColors.muted),
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
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: PosColors.text),
            ),
            const SizedBox(height: 9),
            TfText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PosColors.text,
              ),
            ),
            const SizedBox(height: 1),
            TfText(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: PosColors.muted),
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PosColors.accentStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom actions, by hierarchy: **Scan** is the lime primary hero (the fast
/// path — photograph a bill or a count sheet and let the backend route it);
/// **Count** and **Stock in** are the secondary manual-entry ghosts beneath it.
class _StockBottomBar extends StatelessWidget {
  const _StockBottomBar({
    required this.text,
    required this.scanning,
    required this.onScan,
    required this.onCount,
    required this.onStockIn,
  });

  final AppStrings text;
  final bool scanning;
  final VoidCallback onScan;
  final VoidCallback onCount;
  final VoidCallback onStockIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TfButton(
            label: scanning ? text.scanningStock : text.scanStock,
            icon: Icons.document_scanner_outlined,
            variant: TfButtonVariant.primary,
            size: TfButtonSize.lg,
            busy: scanning,
            onPressed: scanning ? null : onScan,
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: TfButton(
                  label: text.countAction,
                  icon: Icons.fact_check_outlined,
                  variant: TfButtonVariant.ghost,
                  size: TfButtonSize.md,
                  onPressed: scanning ? null : onCount,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TfButton(
                  label: text.stockIn,
                  icon: Icons.add_box_outlined,
                  variant: TfButtonVariant.ghost,
                  size: TfButtonSize.md,
                  onPressed: scanning ? null : onStockIn,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
          style: const TextStyle(
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
