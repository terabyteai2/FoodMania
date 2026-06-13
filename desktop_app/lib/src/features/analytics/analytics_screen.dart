import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/pos_notification.dart';
import '../orders/orders_screen.dart';

// ===========================================================================
// Owner Analytics — intelligence (not live ops). Mirrors the bytes-analytics design
// prototype; data is mock for now, structured for a future API swap
// (`[API: analytics endpoints by range/channel/daypart]`).
// ===========================================================================

// ── Chart palette (maps the prototype's CSS vars) ──────────────────────────
const Color _cDineIn = PosColors.primary; // #99FF47
const Color _cDelivery = PosColors.info; // #3E6FE0
const Color _cPickup = PosColors.warning; // #B0760A
const Color _cCounter = PosColors.muted; // #878C79
const Color _cLine = PosColors.primaryMid; // #67C81E trend stroke

// ── Mock dataset (ANALYTICS) ───────────────────────────────────────────────
typedef _Slice = ({String label, double pct, Color color});

typedef _Product = ({String name, String cat, int qty, int rev, double margin});

typedef _Category = ({String name, double share, int value});

typedef _Daypart = ({
  String name,
  String time,
  double share,
  int orders,
  double margin,
});

// Donut colour palettes (backend returns label/value/pct; FE assigns colour).
const List<Color> _channelPalette = [
  _cDineIn,
  _cDelivery,
  _cPickup,
  _cCounter,
  PosColors.primaryMid,
];
const List<Color> _paymentPalette = [_cDineIn, _cCounter, _cDelivery, _cPickup];

// ── Live analytics dataset ─────────────────────────────────────────────────
// Populated from GET /outlets/{o}/analytics (range/channel/daypart-scoped).
// The screen sets the library-level `_data` from the fetch before building, so
// the existing card widgets (and the See-all sub-screens) read it directly —
// exactly where they used to read the old mock consts.
class _Data {
  const _Data({
    required this.revenue,
    required this.prevRevenue,
    required this.orders,
    required this.aov,
    required this.margin,
    required this.sales7,
    required this.prevSales7,
    required this.sales7Labels,
    required this.peakHours,
    required this.channelMix,
    required this.paymentMix,
    required this.topItems,
    required this.categoryRev,
    required this.catMeta,
    required this.grow,
    required this.dayparts,
    required this.forecast,
    required this.cohort,
    required this.discounts,
    required this.wastage,
  });

  final int revenue;
  final int prevRevenue;
  final int orders;
  final int aov;
  final double? margin; // gross margin 0..1; null when no cost data
  final List<double> sales7;
  final List<double> prevSales7;
  final List<String> sales7Labels;
  final List<double> peakHours;
  final List<_Slice> channelMix;
  final List<_Slice> paymentMix;
  final List<_Product> topItems;
  final List<_Category> categoryRev;
  final Map<String, (double, double)> catMeta; // name -> (marginFraction, wow%)
  final Map<String, int> grow; // product name -> wow growth %
  final List<_Daypart> dayparts;
  // Advanced blocks are nullable: null = no underlying data → card hidden.
  final ({int projected, int? target, double? pace})? forecast;
  final ({double repeat, int ltv, int newPct, int returnPct, double freq})?
  cohort;
  final ({int given, double orders, double marginHit})? discounts;
  final ({int cost, double pct, String topItem})? wastage;

  factory _Data.fromJson(Map<String, Object?> j) {
    List<double> dl(Object? v) => [
      for (final e in (v as List? ?? const []))
        if (e is num) e.toDouble(),
    ];
    List<_Slice> slices(Object? v, List<Color> pal) {
      final list = (v as List? ?? const []);
      final out = <_Slice>[];
      for (var i = 0; i < list.length; i++) {
        final m = list[i];
        if (m is! Map) continue;
        out.add((
          label: (m['label'] ?? '').toString(),
          pct: ((m['pct'] as num?) ?? 0).toDouble(),
          color: pal[out.length % pal.length],
        ));
      }
      return out;
    }

    final products = <_Product>[];
    final grow = <String, int>{};
    for (final raw in (j['products'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final name = (raw['name'] ?? '').toString();
      products.add((
        name: name,
        cat: (raw['category'] ?? '').toString(),
        qty: ((raw['qty'] as num?) ?? 0).toInt(),
        rev: ((raw['salesBdt'] as num?) ?? 0).round(),
        margin: (((raw['marginPct'] as num?) ?? 0).toDouble()) / 100.0,
      ));
      grow[name] = ((raw['growthPct'] as num?) ?? 0).round();
    }

    final categories = <_Category>[];
    final catMeta = <String, (double, double)>{};
    for (final raw in (j['categories'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final name = (raw['name'] ?? '').toString();
      categories.add((
        name: name,
        share: ((raw['share'] as num?) ?? 0).toDouble(),
        value: ((raw['valueBdt'] as num?) ?? 0).round(),
      ));
      catMeta[name] = (
        (((raw['marginPct'] as num?) ?? 0).toDouble()) / 100.0,
        ((raw['growthPct'] as num?) ?? 0).toDouble(),
      );
    }

    final dayparts = <_Daypart>[];
    for (final raw in (j['dayparts'] as List? ?? const [])) {
      if (raw is! Map) continue;
      dayparts.add((
        name: (raw['name'] ?? '').toString(),
        time: (raw['time'] ?? '').toString(),
        share: ((raw['share'] as num?) ?? 0).toDouble(),
        orders: ((raw['orders'] as num?) ?? 0).toInt(),
        margin: (((raw['marginPct'] as num?) ?? 0).toDouble()) / 100.0,
      ));
    }

    final adv = (j['advanced'] as Map?) ?? const {};
    ({int projected, int? target, double? pace})? forecast;
    if (adv['forecast'] is Map) {
      final f = adv['forecast'] as Map;
      forecast = (
        projected: ((f['projected'] as num?) ?? 0).round(),
        target: (f['target'] as num?)?.round(),
        pace: (f['pace'] as num?)?.toDouble(),
      );
    }
    ({double repeat, int ltv, int newPct, int returnPct, double freq})? cohort;
    if (adv['cohort'] is Map) {
      final c = adv['cohort'] as Map;
      cohort = (
        repeat: ((c['repeat'] as num?) ?? 0).toDouble(),
        ltv: ((c['ltv'] as num?) ?? 0).round(),
        newPct: ((c['newPct'] as num?) ?? 0).toInt(),
        returnPct: ((c['returnPct'] as num?) ?? 0).toInt(),
        freq: ((c['freq'] as num?) ?? 0).toDouble(),
      );
    }
    ({int given, double orders, double marginHit})? discounts;
    if (adv['discounts'] is Map) {
      final d = adv['discounts'] as Map;
      discounts = (
        given: ((d['given'] as num?) ?? 0).round(),
        orders: ((d['orders'] as num?) ?? 0).toDouble(),
        marginHit: ((d['marginHit'] as num?) ?? 0).toDouble(),
      );
    }
    ({int cost, double pct, String topItem})? wastage;
    if (adv['wastage'] is Map) {
      final w = adv['wastage'] as Map;
      wastage = (
        cost: ((w['cost'] as num?) ?? 0).round(),
        pct: ((w['pct'] as num?) ?? 0).toDouble(),
        topItem: (w['topItem'] ?? '—').toString(),
      );
    }

    return _Data(
      revenue: ((j['revenue'] as num?) ?? 0).round(),
      prevRevenue: ((j['prevRevenue'] as num?) ?? 0).round(),
      orders: ((j['orders'] as num?) ?? 0).toInt(),
      aov: ((j['aov'] as num?) ?? 0).round(),
      margin: (j['margin'] as num?)?.toDouble(),
      sales7: dl(j['salesTrend']),
      prevSales7: dl(j['prevSalesTrend']),
      sales7Labels: [
        for (final e in (j['trendLabels'] as List? ?? const [])) e.toString(),
      ],
      peakHours: dl(j['peakHours']),
      channelMix: slices(j['channels'], _channelPalette),
      paymentMix: slices(j['payments'], _paymentPalette),
      topItems: products,
      categoryRev: categories,
      catMeta: catMeta,
      grow: grow,
      dayparts: dayparts,
      forecast: forecast,
      cohort: cohort,
      discounts: discounts,
      wastage: wastage,
    );
  }
}

const _Data _emptyData = _Data(
  revenue: 0,
  prevRevenue: 0,
  orders: 0,
  aov: 0,
  margin: null,
  sales7: [],
  prevSales7: [],
  sales7Labels: [],
  peakHours: [],
  channelMix: [],
  paymentMix: [],
  topItems: [],
  categoryRev: [],
  catMeta: {},
  grow: {},
  dayparts: [],
  forecast: null,
  cohort: null,
  discounts: null,
  wastage: null,
);

// Set by _AnalyticsScreenState before building the card subtree.
_Data _data = _emptyData;

// ── Filter option lists ────────────────────────────────────────────────────
const String _allChannels = 'All channels';
const String _allDay = 'All day';
const List<String> _channelFilters = [
  _allChannels,
  'Website',
  'Messenger',
  'POS',
  'Counter',
];
const List<String> _daypartFilters = [_allDay, 'Lunch', 'Dinner', 'Late'];

// UI label -> backend query key.
String _channelQuery(String label) => switch (label) {
  'Website' => 'website',
  'Messenger' => 'messenger',
  'POS' => 'pos',
  'Counter' => 'counter',
  _ => 'all',
};
String _daypartQuery(String label) => switch (label) {
  'Lunch' => 'lunch',
  'Dinner' => 'dinner',
  'Late' => 'late',
  _ => 'all',
};

enum _Timeframe { today, week, month, custom }

enum _ProductSort { rev, units, orders, margin, aov, growth }

// ── Helpers ────────────────────────────────────────────────────────────────
String _money(BuildContext context, num value) =>
    tfFormatCurrency(context, value.round(), decimalDigits: 0);

// Custom presets have no date picker; derive real UTC bounds from the label.
// Shared by the analytics screen and the detailed sales table.
(String, String)? _customRangeBounds(String customRange) {
  final now = DateTime.now();
  DateTime start;
  DateTime end = now;
  switch (customRange) {
    case 'Last month':
      final firstThis = DateTime(now.year, now.month, 1);
      start = DateTime(now.year, now.month - 1, 1);
      end = firstThis;
    case 'This quarter':
      start = now.subtract(const Duration(days: 90));
    case 'YTD':
      start = DateTime(now.year, 1, 1);
    default: // '1–8 Jun' and any other => trailing week
      start = now.subtract(const Duration(days: 7));
  }
  return (start.toUtc().toIso8601String(), end.toUtc().toIso8601String());
}

// ===========================================================================
// AnalyticsScreen (owner/manager tab root)
// ===========================================================================
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({this.onNavigateToTarget, super.key});

  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Timeframe _tf = _Timeframe.week;
  bool _advanced = false;
  _ProductSort _sort = _ProductSort.rev;
  String _customRange = '1–8 Jun';
  String _channel = _allChannels;
  String _daypart = _allDay;
  final ScrollController _scrollController = ScrollController();
  String? _lastLayoutDiag;
  String? _lastScrollSnapshotDiag;
  double? _lastScrollUpdatePixels;
  Offset? _lastPointerMovePosition;

  static const List<String> _customRanges = [
    '1–8 Jun',
    'Last month',
    'This quarter',
    'YTD',
  ];

  Future<_Data>? _future;

  int get _activeFilters =>
      (_channel != _allChannels ? 1 : 0) + (_daypart != _allDay ? 1 : 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = _load());

  String get _rangeKey => switch (_tf) {
    _Timeframe.today => 'today',
    _Timeframe.week => 'week',
    _Timeframe.month => 'month',
    _Timeframe.custom => 'custom',
  };

  // Custom presets have no date picker; derive real bounds from the label.
  (String, String)? _customBounds() => _customRangeBounds(_customRange);

  Future<_Data> _load() async {
    final app = AppScope.read(context);
    String? start;
    String? end;
    if (_tf == _Timeframe.custom) {
      final b = _customBounds();
      if (b != null) {
        start = b.$1;
        end = b.$2;
      }
    }
    final json = await app.fetchAnalytics(
      range: _rangeKey,
      start: start,
      end: end,
      channel: _channelQuery(_channel),
      daypart: _daypartQuery(_daypart),
    );
    final data = _Data.fromJson(json);
    if (kDebugMode) {
      debugPrint(
        '[QB-ANALYTICS-SCROLL-DIAG] load complete ${_stateSummary()} '
        'orders=${data.orders} revenue=${data.revenue} '
        'trend=${data.sales7.length} categories=${data.categoryRev.length} '
        'products=${data.topItems.length} channels=${data.channelMix.length} '
        'dayparts=${data.dayparts.length} advancedBlocks='
        '${[data.forecast != null ? 'forecast' : null, data.cohort != null ? 'cohort' : null, data.discounts != null ? 'discounts' : null, data.wastage != null ? 'wastage' : null].whereType<String>().join('|')}',
      );
    }
    return data;
  }

  String _tfLabel(BuildContext context) => switch (_tf) {
    _Timeframe.today => tfPick(context, en: 'Today', bn: 'আজ'),
    _Timeframe.week => tfPick(context, en: 'This week', bn: 'এই সপ্তাহ'),
    _Timeframe.month => tfPick(context, en: 'This month', bn: 'এই মাস'),
    _Timeframe.custom => _customRange,
  };

  Future<void> _openFilters() async {
    _logTouch('filters sheet open requested');
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiltersSheet(channel: _channel, daypart: _daypart),
    );
    _logTouch('filters sheet closed result=$result');
    if (result != null && mounted) {
      setState(() {
        _channel = result.$1;
        _daypart = result.$2;
        _future = _load();
      });
    }
  }

  String _stateSummary() {
    return 'range=$_rangeKey custom="$_customRange" channel="$_channel" '
        'daypart="$_daypart" advanced=$_advanced';
  }

  void _logLayoutConstraints(BoxConstraints constraints) {
    if (!kDebugMode) return;
    final signature =
        '${constraints.minWidth.toStringAsFixed(1)}/'
        '${constraints.maxWidth.toStringAsFixed(1)}/'
        '${constraints.minHeight.toStringAsFixed(1)}/'
        '${constraints.maxHeight.toStringAsFixed(1)}';
    if (_lastLayoutDiag == signature) return;
    _lastLayoutDiag = signature;
    debugPrint(
      '[QB-ANALYTICS-SCROLL-DIAG] content constraints '
      'minW=${constraints.minWidth.toStringAsFixed(1)} '
      'maxW=${constraints.maxWidth.toStringAsFixed(1)} '
      'minH=${constraints.minHeight.toStringAsFixed(1)} '
      'maxH=${constraints.maxHeight.toStringAsFixed(1)} ${_stateSummary()}',
    );
  }

  void _scheduleScrollSnapshot({
    required String phase,
    required String dataState,
    required List<String> sections,
  }) {
    if (!kDebugMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasClients = _scrollController.hasClients;
      var hasDimensions = false;
      var pixels = 0.0;
      var min = 0.0;
      var max = 0.0;
      var viewport = 0.0;
      var physics = 'none';
      if (hasClients) {
        final position = _scrollController.position;
        hasDimensions = position.hasContentDimensions;
        pixels = position.pixels;
        min = position.minScrollExtent;
        max = position.maxScrollExtent;
        viewport = position.viewportDimension;
        physics = position.physics.runtimeType.toString();
      }
      final suspicious = sections.length > 3 && hasClients && max <= 0;
      final signature = [
        phase,
        dataState,
        sections.join('|'),
        hasClients,
        hasDimensions,
        pixels.toStringAsFixed(1),
        max.toStringAsFixed(1),
        viewport.toStringAsFixed(1),
        _stateSummary(),
      ].join(' ');
      if (_lastScrollSnapshotDiag == signature) return;
      _lastScrollSnapshotDiag = signature;
      debugPrint(
        '[QB-ANALYTICS-SCROLL-DIAG] snapshot phase=$phase '
        'data=$dataState sections=${sections.join('|')} '
        'sectionCount=${sections.length} hasClients=$hasClients '
        'hasDimensions=$hasDimensions pixels=${pixels.toStringAsFixed(1)} '
        'min=${min.toStringAsFixed(1)} max=${max.toStringAsFixed(1)} '
        'viewport=${viewport.toStringAsFixed(1)} physics=$physics '
        'suspiciousNoScrollExtent=$suspicious ${_stateSummary()}',
      );
    });
  }

  List<String> _renderedSections(_Data data, {required bool hasPeak}) {
    return [
      'hero',
      if (data.sales7.isNotEmpty) 'trend',
      if (data.categoryRev.isNotEmpty) 'categories',
      if (data.topItems.isNotEmpty) 'products',
      if (data.channelMix.isNotEmpty) 'mix',
      if (data.dayparts.isNotEmpty) 'dayparts',
      if (_advanced) 'advanced',
      if (hasPeak) 'peak',
      'footer',
    ];
  }

  bool _handleAnalyticsScrollNotification(ScrollNotification notification) {
    if (!kDebugMode) return false;
    final metrics = notification.metrics;
    var shouldLog =
        notification is ScrollStartNotification ||
        notification is ScrollEndNotification ||
        notification is OverscrollNotification;
    if (notification is ScrollUpdateNotification) {
      final previous = _lastScrollUpdatePixels;
      shouldLog = previous == null || (metrics.pixels - previous).abs() >= 48;
      if (shouldLog) _lastScrollUpdatePixels = metrics.pixels;
    }
    if (!shouldLog) return false;
    final kind = notification.runtimeType.toString();
    final drag = notification is ScrollStartNotification
        ? notification.dragDetails != null
        : notification is ScrollUpdateNotification
        ? notification.dragDetails != null
        : false;
    final overscroll = notification is OverscrollNotification
        ? notification.overscroll.toStringAsFixed(1)
        : '0.0';
    debugPrint(
      '[QB-ANALYTICS-SCROLL-DIAG] notification type=$kind '
      'pixels=${metrics.pixels.toStringAsFixed(1)} '
      'min=${metrics.minScrollExtent.toStringAsFixed(1)} '
      'max=${metrics.maxScrollExtent.toStringAsFixed(1)} '
      'viewport=${metrics.viewportDimension.toStringAsFixed(1)} '
      'axis=${metrics.axis.name} outOfRange=${metrics.outOfRange} '
      'drag=$drag overscroll=$overscroll ${_stateSummary()}',
    );
    return false;
  }

  void _logTouch(String message) {
    if (!kDebugMode) return;
    debugPrint('[QB-ANALYTICS-TOUCH-DIAG] $message ${_stateSummary()}');
  }

  void _handlePointerDown(PointerDownEvent event) {
    _lastPointerMovePosition = event.localPosition;
    _logTouch(
      'pointerDown pointer=${event.pointer} kind=${event.kind.name} '
      'local=${_fmtOffset(event.localPosition)} '
      'global=${_fmtOffset(event.position)} buttons=${event.buttons}',
    );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final previous = _lastPointerMovePosition;
    final current = event.localPosition;
    if (previous == null || (current - previous).distance >= 48) {
      _lastPointerMovePosition = current;
      _logTouch(
        'pointerMove pointer=${event.pointer} kind=${event.kind.name} '
        'local=${_fmtOffset(current)} delta=${_fmtOffset(event.localDelta)}',
      );
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _logTouch(
      'pointerUp pointer=${event.pointer} kind=${event.kind.name} '
      'local=${_fmtOffset(event.localPosition)}',
    );
    _lastPointerMovePosition = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _logTouch(
      'pointerCancel pointer=${event.pointer} kind=${event.kind.name} '
      'local=${_fmtOffset(event.localPosition)}',
    );
    _lastPointerMovePosition = null;
  }

  String _fmtOffset(Offset offset) {
    return '(${offset.dx.toStringAsFixed(1)},${offset.dy.toStringAsFixed(1)})';
  }

  @override
  Widget build(BuildContext context) {
    final compare = _advanced;
    final app = AppScope.of(context);
    final text = app.strings;

    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton: app.menuItems.any((i) => i.isAvailable)
          ? TfFab(
              tooltip: text.newOrder,
              onPressed: () => openNewOrderForm(context),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: AppScope.select(
                context,
                AppAspect.language,
              ).strings.analyticsTab,
              onNavigateToTarget: widget.onNavigateToTarget,
              showAdvanced: true,
              advancedValue: _advanced,
              onAdvancedChanged: (v) => setState(() {
                _logTouch('advanced toggle $_advanced->$v');
                _advanced = v;
              }),
            ),
            // Timeframe segmented
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _Segmented(
                selected: _tf,
                onChanged: (tf) => setState(() {
                  _logTouch('timeframe tap ${_tf.name}->${tf.name}');
                  _tf = tf;
                  _future = _load();
                }),
              ),
            ),
            if (_tf == _Timeframe.custom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TfCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: PosColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final r in _customRanges)
                              _MiniChip(
                                label: r,
                                active: _customRange == r,
                                onTap: () => setState(() {
                                  _logTouch(
                                    'custom range tap "$_customRange"->"$r"',
                                  );
                                  _customRange = r;
                                  _future = _load();
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  TfChip(
                    label: tfPick(context, en: 'Filters', bn: 'ফিল্টার'),
                    count: _activeFilters > 0 ? _activeFilters : null,
                    active: _activeFilters > 0,
                    tint: true,
                    small: true,
                    leading: const Icon(Icons.tune_rounded),
                    onTap: _openFilters,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _activeFilters == 0
                        ? TfText(
                            tfPick(
                              context,
                              en: 'All channels · all day',
                              bn: 'সব চ্যানেল · সারাদিন',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PosColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (_channel != _allChannels)
                                _RemovableChip(
                                  label: _channel,
                                  onRemove: () => setState(() {
                                    _logTouch(
                                      'remove channel filter "$_channel"',
                                    );
                                    _channel = _allChannels;
                                    _future = _load();
                                  }),
                                ),
                              if (_daypart != _allDay)
                                _RemovableChip(
                                  label: _daypart,
                                  onRemove: () => setState(() {
                                    _logTouch(
                                      'remove daypart filter "$_daypart"',
                                    );
                                    _daypart = _allDay;
                                    _future = _load();
                                  }),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _logLayoutConstraints(constraints);
                  return FutureBuilder<_Data>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        _scheduleScrollSnapshot(
                          phase: 'builder',
                          dataState: 'waiting',
                          sections: const [],
                        );
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        _scheduleScrollSnapshot(
                          phase: 'builder',
                          dataState: 'error',
                          sections: const [],
                        );
                        return _AnalyticsMessage(
                          text: tfPick(
                            context,
                            en: "Couldn't load analytics.",
                            bn: 'অ্যানালিটিক্স লোড করা যায়নি।',
                          ),
                          onRetry: _reload,
                        );
                      }
                      _data = snap.data ?? _emptyData;
                      if (_data.orders == 0) {
                        _scheduleScrollSnapshot(
                          phase: 'builder',
                          dataState: 'empty',
                          sections: const [],
                        );
                        return _AnalyticsMessage(
                          text: tfPick(
                            context,
                            en: 'No sales in this range yet.',
                            bn: 'এই রেঞ্জে এখনও কোনো বিক্রয় নেই।',
                          ),
                          onRetry: _reload,
                        );
                      }
                      final rev = _data.revenue;
                      final prevRev = _data.prevRevenue;
                      final orders = _data.orders;
                      final growth = prevRev == 0
                          ? 0
                          : ((rev - prevRev) / prevRev * 100).round();
                      final hasPeak = _data.peakHours.any((v) => v > 0);
                      final sections = _renderedSections(
                        _data,
                        hasPeak: hasPeak,
                      );
                      _scheduleScrollSnapshot(
                        phase: 'builder',
                        dataState: 'loaded',
                        sections: sections,
                      );
                      return NotificationListener<ScrollNotification>(
                        onNotification: _handleAnalyticsScrollNotification,
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: _handlePointerDown,
                          onPointerMove: _handlePointerMove,
                          onPointerUp: _handlePointerUp,
                          onPointerCancel: _handlePointerCancel,
                          child: ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                            children: [
                              _HeroCard(
                                label:
                                    '${_tfLabel(context)} · '
                                    '${tfPick(context, en: 'Net sales', bn: 'নিট বিক্রয়')}',
                                revenue: rev,
                                prevRevenue: prevRev,
                                growth: growth,
                                orders: orders,
                                showCompare: compare,
                              ),
                              if (_data.sales7.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _SalesTrendCard(compare: compare),
                              ],
                              if (_data.categoryRev.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _CategoryCard(
                                  advanced: _advanced,
                                  onSeeAll: () {
                                    _logTouch('see all category tap');
                                    _push(const _CategoryAllScreen());
                                  },
                                ),
                              ],
                              if (_data.topItems.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _ProductCard(
                                  advanced: _advanced,
                                  sort: _sort,
                                  onSort: (s) => setState(() {
                                    _logTouch(
                                      'product sort tap ${_sort.name}->${s.name}',
                                    );
                                    _sort = s;
                                  }),
                                  onSeeAll: () {
                                    _logTouch(
                                      'see all products tap sort=${_sort.name}',
                                    );
                                    _push(
                                      _ProductsAllScreen(initialSort: _sort),
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 12),
                              _SalesTableEntry(
                                onTap: () {
                                  _logTouch('detailed sales table tap');
                                  _push(
                                    _SalesTableScreen(
                                      initialTf: _tf,
                                      initialCustomRange: _customRange,
                                    ),
                                  );
                                },
                              ),
                              if (_data.channelMix.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const _MixRow(),
                              ],
                              if (_data.dayparts.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const _DaypartCard(),
                              ],
                              if (_advanced) ...[
                                const SizedBox(height: 12),
                                const _AdvancedSections(),
                              ],
                              if (hasPeak) ...[
                                const SizedBox(height: 12),
                                const _PeakHoursCard(),
                              ],
                              const SizedBox(height: 10),
                              Center(
                                child: TfText(
                                  tfPick(
                                    context,
                                    en: 'VAT-inclusive',
                                    bn: 'ভ্যাট-সহ',
                                  ),
                                  style: const TextStyle(
                                    color: PosColors.mutedSoft,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    _logTouch('push ${screen.runtimeType}');
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _AnalyticsMessage extends StatelessWidget {
  const _AnalyticsMessage({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TfText(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TfButton(
            label: tfPick(context, en: 'Retry', bn: 'আবার চেষ্টা'),
            variant: TfButtonVariant.paper,
            size: TfButtonSize.md,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Section: hero
// ===========================================================================
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.label,
    required this.revenue,
    required this.prevRevenue,
    required this.growth,
    required this.orders,
    required this.showCompare,
  });

  final String label;
  final int revenue;
  final int prevRevenue;
  final int growth;
  final int orders;
  final bool showCompare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosColors.primarySoft,
        borderRadius: BorderRadius.circular(PosRadii.lg),
        border: Border.all(color: PosColors.primaryWash),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfText(
                      label,
                      style: const TextStyle(
                        color: PosColors.accentStrong,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TfText(
                      _money(context, revenue),
                      style: const TextStyle(
                        color: PosColors.text,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.85,
                        height: 1.05,
                      ),
                    ),
                    if (showCompare) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TfText(
                            '${tfPick(context, en: 'vs', bn: 'তুলনায়')} '
                            '${_money(context, prevRevenue)} '
                            '${tfPick(context, en: 'prior', bn: 'পূর্বে')} · ',
                            style: const TextStyle(
                              color: PosColors.inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          _DeltaPill(value: growth),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PosColors.primary,
                  borderRadius: BorderRadius.circular(PosRadii.md),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  size: 22,
                  color: PosColors.accentInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: tfPick(context, en: 'Orders', bn: 'অর্ডার'),
                  value: tfFormatNumber(context, orders),
                  delta: null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: tfPick(context, en: 'Avg order', bn: 'গড় অর্ডার'),
                  value: _money(context, _data.aov),
                  delta: null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: tfPick(
                    context,
                    en: 'Gross margin',
                    bn: 'গ্রস মার্জিন',
                  ),
                  value: _data.margin == null
                      ? '—'
                      : '${(_data.margin! * 100).round()}%',
                  delta: null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value, this.delta});

  final String label;
  final String value;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          TfText(
            value,
            style: const TextStyle(
              color: PosColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 1),
            TfText(
              delta!,
              style: const TextStyle(
                color: PosColors.success,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Section: sales trend
// ===========================================================================
class _SalesTrendCard extends StatelessWidget {
  const _SalesTrendCard({required this.compare});

  final bool compare;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            tfPick(context, en: 'Sales trend', bn: 'বিক্রয় ট্রেন্ড'),
            note: compare
                ? tfPick(
                    context,
                    en: 'vs prior · ৳ thousands',
                    bn: 'পূর্বের তুলনায় · ৳ হাজার',
                  )
                : tfPick(context, en: '৳ thousands', bn: '৳ হাজার'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _AreaChartPainter(
                  values: _data.sales7,
                  compare: compare ? _data.prevSales7 : null,
                  labels: _data.sales7Labels,
                  isBn: tfIsBn(context),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Section: revenue by category
// ===========================================================================
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.advanced, required this.onSeeAll});

  final bool advanced;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final maxShare = _data.categoryRev
        .map((c) => c.share)
        .reduce((a, b) => a > b ? a : b);
    final rows = _data.categoryRev.take(advanced ? 6 : 4).toList();
    return TfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SeeAllHeader(
            title: tfPick(
              context,
              en: 'Revenue by category',
              bn: 'ক্যাটাগরি অনুযায়ী আয়',
            ),
            note: advanced
                ? tfPick(
                    context,
                    en: 'share · margin · growth',
                    bn: 'শেয়ার · মার্জিন · গ্রোথ',
                  )
                : tfPick(
                    context,
                    en: 'share of net sales',
                    bn: 'নিট বিক্রয়ের শেয়ার',
                  ),
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 13),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: advanced ? 13 : 11),
            _CategoryRow(
              row: rows[i],
              rank: i,
              maxShare: maxShare,
              advanced: advanced,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.row,
    required this.rank,
    required this.maxShare,
    required this.advanced,
  });

  final _Category row;
  final int rank;
  final double maxShare;
  final bool advanced;

  @override
  Widget build(BuildContext context) {
    final meta = _data.catMeta[row.name] ?? (0.6, 4.0);
    final barColor = rank == 0
        ? PosColors.primary
        : rank < 3
        ? PosColors.primaryWash
        : PosColors.surface3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TfText(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PosColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TfText(
              '${_money(context, row.value)} · '
              '${(row.share * 100).round()}%',
              style: const TextStyle(
                color: PosColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _Bar(fraction: row.share / maxShare, color: barColor),
        if (advanced) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              _metaSpan(
                context,
                tfPick(context, en: 'Margin', bn: 'মার্জিন'),
                '${(meta.$1 * 100).round()}%',
                PosColors.inkSoft,
              ),
              const SizedBox(width: 14),
              _metaSpan(
                context,
                'WoW',
                '${meta.$2 >= 0 ? '+' : ''}${meta.$2.round()}%',
                meta.$2 >= 0 ? PosColors.success : PosColors.danger,
              ),
              const Spacer(),
              TfText(
                tfPick(context, en: 'Drill in ›', bn: 'ড্রিল ইন ›'),
                style: const TextStyle(
                  color: PosColors.accentStrong,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _metaSpan(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TfText(
          '$label ',
          style: const TextStyle(
            color: PosColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        TfText(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Section: product performance (sortable)
// ===========================================================================
typedef _ScoredProduct = ({
  String name,
  String cat,
  int qty,
  int rev,
  double margin,
  int orders,
  int aov,
  int growth,
});

List<_ScoredProduct> _scoredProducts() {
  return _data.topItems.map((it) {
    final orders = (it.qty * 0.78).round().clamp(1, 1 << 30);
    return (
      name: it.name,
      cat: it.cat,
      qty: it.qty,
      rev: it.rev,
      margin: it.margin,
      orders: orders,
      aov: (it.rev / orders).round(),
      growth: _data.grow[it.name] ?? 0,
    );
  }).toList();
}

num _sortValue(_ScoredProduct it, _ProductSort sort) => switch (sort) {
  _ProductSort.rev => it.rev,
  _ProductSort.units => it.qty,
  _ProductSort.orders => it.orders,
  _ProductSort.margin => it.margin,
  _ProductSort.aov => it.aov,
  _ProductSort.growth => it.growth,
};

String _sortLabel(BuildContext context, _ProductSort sort) => switch (sort) {
  _ProductSort.rev => tfPick(context, en: 'Revenue', bn: 'আয়'),
  _ProductSort.units => tfPick(context, en: 'Units', bn: 'ইউনিট'),
  _ProductSort.orders => tfPick(context, en: 'Orders', bn: 'অর্ডার'),
  _ProductSort.margin => tfPick(context, en: 'Margin', bn: 'মার্জিন'),
  _ProductSort.aov => 'AOV',
  _ProductSort.growth => tfPick(context, en: 'Growth', bn: 'গ্রোথ'),
};

String _metricValue(
  BuildContext context,
  _ScoredProduct it,
  _ProductSort sort,
) => switch (sort) {
  _ProductSort.rev => _money(context, it.rev),
  _ProductSort.units =>
    '${tfFormatNumber(context, it.qty)} ${tfPick(context, en: 'sold', bn: 'বিক্রি')}',
  _ProductSort.orders => tfFormatNumber(context, it.orders),
  _ProductSort.margin => '${(it.margin * 100).round()}%',
  _ProductSort.aov => _money(context, it.aov),
  _ProductSort.growth => '${it.growth >= 0 ? '+' : ''}${it.growth}%',
};

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.advanced,
    required this.sort,
    required this.onSort,
    required this.onSeeAll,
  });

  final bool advanced;
  final _ProductSort sort;
  final ValueChanged<_ProductSort> onSort;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final sorts = [
      _ProductSort.rev,
      _ProductSort.units,
      _ProductSort.orders,
      _ProductSort.margin,
      if (advanced) ...[_ProductSort.aov, _ProductSort.growth],
    ];
    final products = _scoredProducts()
      ..sort((a, b) => _sortValue(b, sort).compareTo(_sortValue(a, sort)));
    final shown = products.take(advanced ? 7 : 5).toList();

    return TfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SeeAllHeader(
            title: tfPick(
              context,
              en: 'Product performance',
              bn: 'প্রোডাক্ট পারফরম্যান্স',
            ),
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sorts)
                TfChip(
                  label: _sortLabel(context, s),
                  active: sort == s,
                  tint: true,
                  small: true,
                  onTap: () => onSort(s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < shown.length; i++)
            advanced
                ? _ProductDenseRow(item: shown[i], rank: i, first: i == 0)
                : _ProductRowTile(
                    item: shown[i],
                    rank: i,
                    sort: sort,
                    first: i == 0,
                  ),
          if (advanced) ...[
            const SizedBox(height: 12),
            TfButton(
              label: tfPick(
                context,
                en: 'Full menu report · export CSV',
                bn: 'সম্পূর্ণ মেনু রিপোর্ট · CSV',
              ),
              variant: TfButtonVariant.paper,
              size: TfButtonSize.md,
              onPressed: () {},
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductRowTile extends StatelessWidget {
  const _ProductRowTile({
    required this.item,
    required this.rank,
    required this.sort,
    required this.first,
  });

  final _ScoredProduct item;
  final int rank;
  final _ProductSort sort;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          _RankNumber(rank: rank),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PosColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                TfText(
                  '${tfFormatNumber(context, item.qty)} '
                  '${tfPick(context, en: 'sold', bn: 'বিক্রি')} · '
                  '${(item.margin * 100).round()}% '
                  '${tfPick(context, en: 'margin', bn: 'মার্জিন')}',
                  style: const TextStyle(
                    color: PosColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TfText(
            _metricValue(context, item, sort),
            style: const TextStyle(
              color: PosColors.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDenseRow extends StatelessWidget {
  const _ProductDenseRow({
    required this.item,
    required this.rank,
    required this.first,
  });

  final _ScoredProduct item;
  final int rank;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          _RankNumber(rank: rank),
          const SizedBox(width: 11),
          Expanded(
            child: TfText(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PosColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _numCell(context, tfFormatNumber(context, item.qty), 50),
          _numCell(context, '${(item.margin * 100).round()}%', 46),
          _numCell(
            context,
            '${item.growth >= 0 ? '+' : ''}${item.growth}',
            40,
            color: item.growth >= 0 ? PosColors.success : PosColors.danger,
            bold: true,
          ),
          _numCell(context, _money(context, item.rev), 72, bold: true),
        ],
      ),
    );
  }

  Widget _numCell(
    BuildContext context,
    String value,
    double width, {
    Color color = PosColors.text,
    bool bold = false,
  }) {
    return SizedBox(
      width: width,
      child: TfText(
        value,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

// ===========================================================================
// Section: channels + payments donuts
// ===========================================================================
class _MixRow extends StatelessWidget {
  const _MixRow();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _DonutCard(
              title: tfPick(context, en: 'Channels', bn: 'চ্যানেল'),
              slices: _data.channelMix,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DonutCard(
              title: tfPick(context, en: 'Payments', bn: 'পেমেন্ট'),
              slices: _data.paymentMix,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.title, required this.slices});

  final String title;
  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            title,
            style: const TextStyle(
              color: PosColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (slices.isEmpty)
            const SizedBox(height: 104)
          else ...[
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 104,
                height: 104,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _DonutPainter(
                      slices: slices,
                      centerText: '${slices.first.pct.round()}%',
                      centerLabel: slices.first.label.toLowerCase(),
                      isBn: tfIsBn(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final s in slices.take(4)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TfText(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PosColors.inkSoft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TfText(
                      '${s.pct.round()}%',
                      style: const TextStyle(
                        color: PosColors.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Section: daypart
// ===========================================================================
class _DaypartCard extends StatelessWidget {
  const _DaypartCard();

  @override
  Widget build(BuildContext context) {
    return TfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            tfPick(
              context,
              en: 'Daypart performance',
              bn: 'ডেপার্ট পারফরম্যান্স',
            ),
            note: tfPick(
              context,
              en: 'revenue share · margin',
              bn: 'আয় শেয়ার · মার্জিন',
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _data.dayparts.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _DaypartTile(daypart: _data.dayparts[i], highlight: i == 1),
          ],
        ],
      ),
    );
  }
}

class _DaypartTile extends StatelessWidget {
  const _DaypartTile({required this.daypart, required this.highlight});

  final _Daypart daypart;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? PosColors.primarySoft : PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    TfText(
                      daypart.name,
                      style: const TextStyle(
                        color: PosColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    TfText(
                      daypart.time,
                      style: const TextStyle(
                        color: PosColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                TfText(
                  '${tfFormatNumber(context, daypart.orders)} '
                  '${tfPick(context, en: 'orders', bn: 'অর্ডার')} · '
                  '${(daypart.margin * 100).round()}% '
                  '${tfPick(context, en: 'margin', bn: 'মার্জিন')}',
                  style: const TextStyle(
                    color: PosColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TfText(
            '${(daypart.share * 100).round()}%',
            style: const TextStyle(
              color: PosColors.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Section: peak hours (demoted)
// ===========================================================================
class _PeakHoursCard extends StatelessWidget {
  const _PeakHoursCard();

  @override
  Widget build(BuildContext context) {
    final maxHr = _data.peakHours.reduce((a, b) => a > b ? a : b);
    return Opacity(
      opacity: 0.92,
      child: TfCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TfText(
                    tfPick(context, en: 'Peak hours', bn: 'পিক আওয়ার'),
                    style: const TextStyle(
                      color: PosColors.inkSoft,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TfText(
                  tfPick(context, en: 'Busiest 8–9 PM', bn: 'ব্যস্ততম ৮–৯ PM'),
                  style: const TextStyle(
                    color: PosColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final v in _data.peakHours)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: (v / maxHr).clamp(0.04, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: v / maxHr > 0.85
                                    ? PosColors.primaryWash
                                    : PosColors.surface3,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final l in ['11 AM', '4 PM', '8 PM', '12 AM'])
                  TfText(
                    l,
                    style: const TextStyle(
                      color: PosColors.mutedSoft,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Section: advanced (forecast, unit economics, cohort, discounts/wastage,
// basket)
// ===========================================================================
class _AdvancedSections extends StatelessWidget {
  const _AdvancedSections();

  @override
  Widget build(BuildContext context) {
    final forecast = _data.forecast;
    final cohort = _data.cohort;
    final discounts = _data.discounts;
    final wastage = _data.wastage;

    final cards = <Widget>[];

    // Forecast vs target (null-safe: target/pace may be null when no target set).
    if (forecast != null) {
      cards.add(
        TfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                tfPick(
                  context,
                  en: 'Forecast vs target',
                  bn: 'ফোরকাস্ট বনাম টার্গেট',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  TfText(
                    _money(context, forecast.projected),
                    style: const TextStyle(
                      color: PosColors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TfText(
                    tfPick(context, en: 'projected', bn: 'অনুমান'),
                    style: const TextStyle(
                      color: PosColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (forecast.target != null) ...[
                const SizedBox(height: 10),
                _Bar(
                  fraction: (forecast.pace ?? 0).clamp(0.0, 1.0),
                  color: PosColors.primary,
                  height: 10,
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: TfText(
                        '${((forecast.pace ?? 0) * 100).round()}% '
                        '${tfPick(context, en: 'of target', bn: 'টার্গেটের')}',
                        style: const TextStyle(
                          color: PosColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TfText(
                      '${tfPick(context, en: 'target', bn: 'টার্গেট')} '
                      '${_money(context, forecast.target!)}',
                      style: const TextStyle(
                        color: PosColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Customer cohort — ONLY from online channels (messenger/website). Hidden
    // when there's no online history (e.g. a counter-only outlet).
    if (cohort != null) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
      cards.add(
        TfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                tfPick(context, en: 'Customer cohort', bn: 'কাস্টমার কোহোর্ট'),
                note: tfPick(context, en: 'online only', bn: 'শুধু অনলাইন'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      value: '${(cohort.repeat * 100).round()}%',
                      label: tfPick(
                        context,
                        en: 'Repeat rate',
                        bn: 'রিপিট রেট',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      value: _money(context, cohort.ltv),
                      label: tfPick(
                        context,
                        en: 'Est. LTV',
                        bn: 'আনুমানিক LTV',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      value: '${cohort.freq}×',
                      label: tfPick(context, en: 'Visits', bn: 'ভিজিট'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LabeledBar(
                label: tfPick(context, en: 'Returning', bn: 'ফিরে আসা'),
                fraction: cohort.returnPct / 100,
                value: '${cohort.returnPct}%',
                color: PosColors.accentStrong,
              ),
              const SizedBox(height: 11),
              _LabeledBar(
                label: tfPick(context, en: 'New', bn: 'নতুন'),
                fraction: cohort.newPct / 100,
                value: '${cohort.newPct}%',
                color: PosColors.surface3,
              ),
            ],
          ),
        ),
      );
    }

    // Discounts + wastage — each hidden when there's nothing to show.
    if (discounts != null || wastage != null) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
      cards.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (discounts != null)
                Expanded(
                  child: TfCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TfText(
                          tfPick(context, en: 'Discounts', bn: 'ডিসকাউন্ট'),
                          style: const TextStyle(
                            color: PosColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TfText(
                          _money(context, discounts.given),
                          style: const TextStyle(
                            color: PosColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TfText(
                          '${(discounts.orders * 100).round()}% '
                          '${tfPick(context, en: 'of orders', bn: 'অর্ডারে')}',
                          style: const TextStyle(
                            color: PosColors.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TfText(
                          '−${(discounts.marginHit * 100).round()}pt '
                          '${tfPick(context, en: 'margin', bn: 'মার্জিন')}',
                          style: const TextStyle(
                            color: PosColors.danger,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (discounts != null && wastage != null)
                const SizedBox(width: 10),
              if (wastage != null)
                Expanded(
                  child: TfCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TfText(
                          tfPick(context, en: 'Wastage', bn: 'অপচয়'),
                          style: const TextStyle(
                            color: PosColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TfText(
                          _money(context, wastage.cost),
                          style: const TextStyle(
                            color: PosColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TfText(
                          '${(wastage.pct * 100).round()}% '
                          '${tfPick(context, en: 'of stock value', bn: 'স্টক মূল্যের')}',
                          style: const TextStyle(
                            color: PosColors.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TfText(
                          '${tfPick(context, en: 'Top:', bn: 'শীর্ষ:')} ${wastage.topItem}',
                          style: const TextStyle(
                            color: PosColors.warning,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cards,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            value,
            style: const TextStyle(
              color: PosColors.text,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          TfText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledBar extends StatelessWidget {
  const _LabeledBar({
    required this.label,
    required this.fraction,
    required this.value,
    required this.color,
  });

  final String label;
  final double fraction;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TfText(
                label,
                style: const TextStyle(
                  color: PosColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TfText(
              value,
              style: const TextStyle(
                color: PosColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _Bar(fraction: fraction, color: color, height: 7),
      ],
    );
  }
}

// ===========================================================================
// See-all: Revenue by category (full)
// ===========================================================================
enum _CatSort { rev, share, margin, growth, units }

class _CategoryAllScreen extends StatefulWidget {
  const _CategoryAllScreen();

  @override
  State<_CategoryAllScreen> createState() => _CategoryAllScreenState();
}

class _CategoryAllScreenState extends State<_CategoryAllScreen> {
  _CatSort _sort = _CatSort.rev;

  @override
  Widget build(BuildContext context) {
    final rows = _data.categoryRev.map((c) {
      final meta = _data.catMeta[c.name] ?? (0.6, 4.0);
      final items = _data.topItems.where((it) => it.cat == c.name);
      final units = items.fold<int>(0, (s, it) => s + it.qty);
      return (
        name: c.name,
        share: c.share,
        value: c.value,
        margin: meta.$1,
        growth: meta.$2,
        units: units,
      );
    }).toList();
    num key(
      ({
        String name,
        double share,
        int value,
        double margin,
        double growth,
        int units,
      })
      r,
    ) => switch (_sort) {
      _CatSort.rev => r.value,
      _CatSort.share => r.share,
      _CatSort.margin => r.margin,
      _CatSort.growth => r.growth,
      _CatSort.units => r.units,
    };
    rows.sort((a, b) => key(b).compareTo(key(a)));
    final maxV = rows.map((r) => r.value).reduce(math.max);
    final totalRev = rows.fold<int>(0, (s, r) => s + r.value);

    final sorts = <(_CatSort, String)>[
      (_CatSort.rev, tfPick(context, en: 'Revenue', bn: 'আয়')),
      (_CatSort.share, tfPick(context, en: 'Share', bn: 'শেয়ার')),
      (_CatSort.margin, tfPick(context, en: 'Margin', bn: 'মার্জিন')),
      (_CatSort.growth, tfPick(context, en: 'Growth', bn: 'গ্রোথ')),
      (_CatSort.units, tfPick(context, en: 'Units', bn: 'ইউনিট')),
    ];

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TfAppBar(
              title: tfPick(
                context,
                en: 'Revenue by category',
                bn: 'ক্যাটাগরি অনুযায়ী আয়',
              ),
              subtitle:
                  '${_money(context, totalRev)} '
                  '${tfPick(context, en: 'net · last 7 days', bn: 'নিট · গত ৭ দিন')}',
              leading: const _BackButton(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in sorts)
                    TfChip(
                      label: s.$2,
                      active: _sort == s.$1,
                      tint: true,
                      small: true,
                      onTap: () => setState(() => _sort = s.$1),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 11),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final barColor = i == 0
                      ? PosColors.primary
                      : i < 3
                      ? PosColors.primaryWash
                      : PosColors.surface3;
                  return TfCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _RankNumber(rank: i, small: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TfText(
                                r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: PosColors.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TfText(
                              _money(context, r.value),
                              style: const TextStyle(
                                color: PosColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Bar(fraction: r.value / maxV, color: barColor),
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            _miniStat(
                              context,
                              tfPick(context, en: 'Share', bn: 'শেয়ার'),
                              '${(r.share * 100).round()}%',
                              PosColors.inkSoft,
                            ),
                            _miniStat(
                              context,
                              tfPick(context, en: 'Margin', bn: 'মার্জিন'),
                              '${(r.margin * 100).round()}%',
                              PosColors.inkSoft,
                            ),
                            _miniStat(
                              context,
                              'WoW',
                              '${r.growth >= 0 ? '+' : ''}${r.growth.round()}%',
                              r.growth >= 0
                                  ? PosColors.success
                                  : PosColors.danger,
                            ),
                            _miniStat(
                              context,
                              tfPick(context, en: 'Units', bn: 'ইউনিট'),
                              tfFormatNumber(context, r.units),
                              PosColors.inkSoft,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _ExportBar(
              label: tfPick(
                context,
                en: 'Export category report',
                bn: 'ক্যাটাগরি রিপোর্ট এক্সপোর্ট',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfMicroLabel(label.toUpperCase()),
          const SizedBox(height: 2),
          TfText(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// See-all: Product performance (full, searchable + sortable)
// ===========================================================================
class _ProductsAllScreen extends StatefulWidget {
  const _ProductsAllScreen({required this.initialSort});

  final _ProductSort initialSort;

  @override
  State<_ProductsAllScreen> createState() => _ProductsAllScreenState();
}

class _ProductsAllScreenState extends State<_ProductsAllScreen> {
  late _ProductSort _sort = widget.initialSort;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = _scoredProducts();
    final filtered =
        products.where((p) {
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return p.name.toLowerCase().contains(q) ||
              p.cat.toLowerCase().contains(q);
        }).toList()..sort(
          (a, b) => _sortValue(b, _sort).compareTo(_sortValue(a, _sort)),
        );

    final sorts = [
      _ProductSort.rev,
      _ProductSort.units,
      _ProductSort.orders,
      _ProductSort.margin,
      _ProductSort.aov,
      _ProductSort.growth,
    ];

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TfAppBar(
              title: tfPick(
                context,
                en: 'Product performance',
                bn: 'প্রোডাক্ট পারফরম্যান্স',
              ),
              subtitle:
                  '${tfFormatNumber(context, products.length)} '
                  '${tfPick(context, en: 'menu items · last 7 days', bn: 'মেনু আইটেম · গত ৭ দিন')}',
              leading: const _BackButton(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TfSearchField(
                controller: _search,
                hintText: tfPick(
                  context,
                  en: 'Search items…',
                  bn: 'আইটেম খুঁজুন…',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in sorts)
                    TfChip(
                      label: _sortLabel(context, s),
                      active: _sort == s,
                      tint: true,
                      small: true,
                      onTap: () => setState(() => _sort = s),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  TfCard(
                    padding: const EdgeInsets.fromLTRB(15, 4, 15, 10),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 11, bottom: 9),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TfMicroLabel(
                                  tfPick(context, en: 'ITEM', bn: 'আইটেম'),
                                ),
                              ),
                              TfMicroLabel(
                                _sortLabel(context, _sort).toUpperCase(),
                                color: PosColors.accentStrong,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: PosColors.lineStrong),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: TfText(
                              tfPick(
                                context,
                                en: 'No items match "$_query".',
                                bn: '"$_query" এর সাথে কিছু মেলেনি।',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: PosColors.muted,
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          for (var i = 0; i < filtered.length; i++)
                            _FullProductRow(
                              item: filtered[i],
                              rank: i,
                              sort: _sort,
                              last: i == filtered.length - 1,
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _ExportBar(
              label: tfPick(
                context,
                en: 'Export full menu report',
                bn: 'সম্পূর্ণ মেনু রিপোর্ট এক্সপোর্ট',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullProductRow extends StatelessWidget {
  const _FullProductRow({
    required this.item,
    required this.rank,
    required this.sort,
    required this.last,
  });

  final _ScoredProduct item;
  final int rank;
  final _ProductSort sort;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: TfText(
              '${rank + 1}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: rank == 0 ? PosColors.accentStrong : PosColors.mutedSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PosColors.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                TfText(
                  '${item.cat} · ${(item.margin * 100).round()}% '
                  '${tfPick(context, en: 'margin', bn: 'মার্জিন')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PosColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 86,
            child: TfText(
              _metricValue(context, item, sort),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: sort == _ProductSort.growth
                    ? (item.growth >= 0 ? PosColors.success : PosColors.danger)
                    : PosColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Filters bottom sheet
// ===========================================================================
// ===========================================================================
// Detailed sales table (spec §4.8 "Detailed sales table") — a master,
// filterable, sortable ledger sliced by item × service × channel. Mirrors the
// bytes-salestable prototype; fits the phone surface (no horizontal scroll) by
// capping visible numeric metrics at 3. Channel + Service are backed by real
// data; Shift/Terminal/Staff are kept for parity but have no row dimension, so
// selecting a specific value yields an honest "no rows" state (never fabricated).
// ===========================================================================

// numeric metric registry — key, EN/BN header, column width, money?, default-on.
typedef _StMetric = ({
  String k,
  String enLabel,
  String bnLabel,
  double w,
  bool money,
  bool def,
});

const List<_StMetric> _stMetrics = [
  (
    k: 'units',
    enLabel: 'Units',
    bnLabel: 'ইউনিট',
    w: 46,
    money: false,
    def: true,
  ),
  (
    k: 'orders',
    enLabel: 'Orders',
    bnLabel: 'অর্ডার',
    w: 50,
    money: false,
    def: false,
  ),
  (k: 'rev', enLabel: 'Revenue', bnLabel: 'আয়', w: 74, money: true, def: true),
  (k: 'aov', enLabel: 'AOV', bnLabel: 'গড়', w: 60, money: true, def: false),
  (k: 'cost', enLabel: 'Cost', bnLabel: 'খরচ', w: 60, money: true, def: false),
  (
    k: 'profit',
    enLabel: 'Profit',
    bnLabel: 'লাভ',
    w: 64,
    money: true,
    def: false,
  ),
  (
    k: 'margin',
    enLabel: 'Margin',
    bnLabel: 'মার্জিন',
    w: 50,
    money: false,
    def: true,
  ),
];
const int _stMaxMetrics = 3;

const String _stAllServices = 'All';
const String _stAllChannels = 'All channels';
const String _stAllShifts = 'All shifts';
const String _stAllTerminals = 'All terminals';
const String _stAllStaff = 'All staff';

const List<String> _stServices = [
  _stAllServices,
  'Dine-in',
  'Takeaway',
  'Delivery',
];
const List<String> _stChannelFilters = [
  _stAllChannels,
  'POS',
  'Messenger',
  'Website',
];
// No real row carries shift/terminal/staff — these are parity-only filters.
const List<String> _stShiftFilters = [
  _stAllShifts,
  'Morning',
  'Evening',
  'Night',
];
const List<String> _stTerminalFilters = [
  _stAllTerminals,
  'Terminal 1',
  'Terminal 2',
];
const List<String> _stStaffFilters = [_stAllStaff, 'Cashier', 'Waiter'];

String _stServiceKey(String label) => switch (label) {
  'Dine-in' => 'dineIn',
  'Takeaway' => 'takeaway',
  'Delivery' => 'delivery',
  _ => 'all',
};

class _SalesRow {
  _SalesRow({
    required this.id,
    required this.name,
    required this.category,
    required this.service,
    required this.serviceKey,
    required this.channel,
    required this.channelKey,
    required this.units,
    required this.orders,
    required this.sales,
    required this.cost,
  });

  final String id;
  final String name;
  final String category;
  final String service;
  final String serviceKey;
  final String channel;
  final String channelKey;
  final int units;
  final int orders;
  final double sales;
  final double? cost; // null => menu item has no cost price

  double? get profit => cost == null ? null : sales - cost!;
  double get aov => orders > 0 ? sales / orders : 0;
  double? get margin =>
      (cost == null || sales <= 0) ? null : (sales - cost!) / sales;

  static _SalesRow fromJson(Map<String, Object?> j) {
    double? toD(Object? v) => v == null ? null : (v as num).toDouble();
    return _SalesRow(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      service: (j['service'] ?? '').toString(),
      serviceKey: (j['serviceKey'] ?? '').toString(),
      channel: (j['channel'] ?? '').toString(),
      channelKey: (j['channelKey'] ?? '').toString(),
      units: (j['units'] as num?)?.toInt() ?? 0,
      orders: (j['orders'] as num?)?.toInt() ?? 0,
      sales: toD(j['salesBdt']) ?? 0,
      cost: toD(j['costBdt']),
    );
  }
}

num? _stMetricNum(_SalesRow r, String k) => switch (k) {
  'units' => r.units,
  'orders' => r.orders,
  'rev' => r.sales,
  'aov' => r.aov,
  'cost' => r.cost,
  'profit' => r.profit,
  'margin' => r.margin,
  _ => null,
};

String _stMetricText(BuildContext c, _SalesRow r, _StMetric m) {
  final v = _stMetricNum(r, m.k);
  if (v == null) return '—';
  if (m.k == 'margin') return '${(v * 100).round()}%';
  if (m.money) return _money(c, v);
  return tfFormatNumber(c, v);
}

class _SalesTableEntry extends StatelessWidget {
  const _SalesTableEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TfCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PosColors.primarySoft,
                borderRadius: BorderRadius.circular(PosRadii.lg),
              ),
              child: const Icon(
                Icons.table_rows_rounded,
                size: 20,
                color: PosColors.accentStrong,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TfText(
                    tfPick(
                      context,
                      en: 'Detailed sales table',
                      bn: 'বিস্তারিত বিক্রয় তালিকা',
                    ),
                    style: const TextStyle(
                      color: PosColors.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  TfText(
                    tfPick(
                      context,
                      en: 'Filter, sort & export every line',
                      bn: 'প্রতিটি লাইন ফিল্টার, সাজান ও এক্সপোর্ট',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PosColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
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
    );
  }
}

class _SalesTableScreen extends StatefulWidget {
  const _SalesTableScreen({
    required this.initialTf,
    required this.initialCustomRange,
  });

  final _Timeframe initialTf;
  final String initialCustomRange;

  @override
  State<_SalesTableScreen> createState() => _SalesTableScreenState();
}

class _SalesTableScreenState extends State<_SalesTableScreen> {
  late _Timeframe _tf = widget.initialTf;
  late final String _customRange = widget.initialCustomRange;
  String _service = _stAllServices;
  String _channel = _stAllChannels;
  String _shift = _stAllShifts;
  String _terminal = _stAllTerminals;
  String _staff = _stAllStaff;
  String _sortKey = 'rev';
  bool _sortDesc = true;
  late final Map<String, bool> _vis = {for (final m in _stMetrics) m.k: m.def};
  Future<List<_SalesRow>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  void _reload() => setState(() => _future = _load());

  String get _rangeKey => switch (_tf) {
    _Timeframe.today => 'today',
    _Timeframe.week => 'week',
    _Timeframe.month => 'month',
    _Timeframe.custom => 'custom',
  };

  int get _activeFilters =>
      (_channel != _stAllChannels ? 1 : 0) +
      (_shift != _stAllShifts ? 1 : 0) +
      (_terminal != _stAllTerminals ? 1 : 0) +
      (_staff != _stAllStaff ? 1 : 0);

  List<_StMetric> get _visMetrics =>
      _stMetrics.where((m) => _vis[m.k] ?? false).toList();

  Future<List<_SalesRow>> _load() async {
    final app = AppScope.read(context);
    String? start;
    String? end;
    if (_tf == _Timeframe.custom) {
      final b = _customRangeBounds(_customRange);
      if (b != null) {
        start = b.$1;
        end = b.$2;
      }
    }
    // Fetch the full period once (channel = all); Service/Channel/Shift/etc.
    // are applied client-side so only the timeframe triggers a refetch.
    final json = await app.fetchSalesTable(
      range: _rangeKey,
      start: start,
      end: end,
    );
    final rawRows = json['rows'];
    if (rawRows is! List) return const [];
    return rawRows
        .whereType<Map>()
        .map((e) => _SalesRow.fromJson(Map<String, Object?>.from(e)))
        .toList();
  }

  // Apply on-screen filters + sort to the fetched base rows.
  List<_SalesRow> _apply(List<_SalesRow> base) {
    // Shift/Terminal/Staff have no real backing dimension — a specific pick
    // matches nothing, surfacing an honest empty state rather than fake data.
    if (_shift != _stAllShifts ||
        _terminal != _stAllTerminals ||
        _staff != _stAllStaff) {
      return const [];
    }
    final svcKey = _stServiceKey(_service);
    bool channelMatch(_SalesRow r) => switch (_channel) {
      'POS' => r.channelKey == 'pos' || r.channelKey == 'counter',
      'Messenger' => r.channelKey == 'messenger',
      'Website' => r.channelKey == 'website',
      _ => true,
    };
    final rows = base
        .where((r) => svcKey == 'all' || r.serviceKey == svcKey)
        .where(channelMatch)
        .toList();
    final dir = _sortDesc ? -1 : 1;
    rows.sort((a, b) {
      if (_sortKey == 'name') return a.name.compareTo(b.name) * dir;
      final av = _stMetricNum(a, _sortKey);
      final bv = _stMetricNum(b, _sortKey);
      if (av == null && bv == null) return 0;
      if (av == null) return 1; // nulls last regardless of direction
      if (bv == null) return -1;
      return av.compareTo(bv) * dir;
    });
    return rows;
  }

  void _setSort(String k) => setState(() {
    if (_sortKey == k) {
      _sortDesc = !_sortDesc;
    } else {
      _sortKey = k;
      _sortDesc = k != 'name'; // name defaults ascending, metrics descending
    }
  });

  Future<void> _openMetrics() async {
    final result = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StMetricsSheet(vis: Map<String, bool>.from(_vis)),
    );
    if (result != null && mounted) {
      setState(() {
        _vis
          ..clear()
          ..addAll(result);
        // If the active sort column was hidden, fall back to a visible one.
        if (_sortKey != 'name' && !(_vis[_sortKey] ?? false)) {
          final first = _visMetrics.isNotEmpty ? _visMetrics.first.k : 'name';
          _sortKey = first;
          _sortDesc = true;
        }
      });
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<(String, String, String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StFiltersSheet(
        channel: _channel,
        shift: _shift,
        terminal: _terminal,
        staff: _staff,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _channel = result.$1;
        _shift = result.$2;
        _terminal = result.$3;
        _staff = result.$4;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<_SalesRow>>(
          future: _future,
          builder: (context, snap) {
            final loading =
                snap.connectionState != ConnectionState.done && !snap.hasData;
            final base = snap.data ?? const <_SalesRow>[];
            final rows = _apply(base);
            final totalRev = rows.fold<double>(0, (s, r) => s + r.sales);
            final subtitle = loading
                ? tfPick(context, en: 'Loading…', bn: 'লোড হচ্ছে…')
                : '${rows.length} '
                      '${tfPick(context, en: 'rows', bn: 'সারি')} · '
                      '${_money(context, totalRev)} '
                      '${tfPick(context, en: 'net', bn: 'নিট')}';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TfAppBar(
                  title: tfPick(
                    context,
                    en: 'Sales table',
                    bn: 'বিক্রয় তালিকা',
                  ),
                  subtitle: subtitle,
                  leading: const _BackButton(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _Segmented(
                    selected: _tf,
                    onChanged: (tf) {
                      if (tf == _tf) return;
                      setState(() => _tf = tf);
                      _reload();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _StringSegmented(
                    options: [
                      for (final s in _stServices)
                        (
                          s,
                          s == _stAllServices
                              ? tfPick(context, en: 'All', bn: 'সব')
                              : s,
                        ),
                    ],
                    selected: _service,
                    onChanged: (s) => setState(() => _service = s),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      _StToolbarButton(
                        icon: Icons.view_column_rounded,
                        label:
                            '${tfPick(context, en: 'Metrics', bn: 'মেট্রিক')} · '
                            '${_visMetrics.length}',
                        active: false,
                        onTap: _openMetrics,
                      ),
                      const SizedBox(width: 8),
                      _StToolbarButton(
                        icon: Icons.filter_list_rounded,
                        label:
                            tfPick(context, en: 'Filters', bn: 'ফিল্টার') +
                            (_activeFilters > 0 ? ' · $_activeFilters' : ''),
                        active: _activeFilters > 0,
                        onTap: _openFilters,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: snap.hasError
                      ? _StMessage(
                          message: tfPick(
                            context,
                            en: 'Could not load the sales table.',
                            bn: 'বিক্রয় তালিকা লোড করা যায়নি।',
                          ),
                          onRetry: _reload,
                        )
                      : loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildTable(context, rows),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<_SalesRow> rows) {
    if (rows.isEmpty) {
      return _StMessage(
        message: tfPick(
          context,
          en: 'No rows match these filters.',
          bn: 'এই ফিল্টারে কোনো সারি নেই।',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        TfCard(
          padding: const EdgeInsets.fromLTRB(15, 4, 15, 8),
          child: Column(
            children: [
              _headerRow(context),
              for (var i = 0; i < rows.length; i++)
                _bodyRow(context, rows[i], i, rows.length),
              _totalsRow(context, rows),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TfText(
            tfPick(
              context,
              en: 'Tap a column to sort · choose metrics & filters above',
              bn: 'সাজাতে কলামে চাপুন · উপরে মেট্রিক ও ফিল্টার বাছুন',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: PosColors.mutedSoft, fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  Widget _caret(String k) => _sortKey == k
      ? Icon(
          _sortDesc
              ? Icons.keyboard_arrow_down_rounded
              : Icons.keyboard_arrow_up_rounded,
          size: 13,
          color: PosColors.accentStrong,
        )
      : const SizedBox.shrink();

  TextStyle _eyebrow(bool active) => TextStyle(
    color: active ? PosColors.accentStrong : PosColors.muted,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  Widget _headerRow(BuildContext context) {
    final metrics = _visMetrics;
    return Container(
      padding: const EdgeInsets.only(top: 7, bottom: 9),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PosColors.lineStrong, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const SizedBox(width: 9),
          Expanded(
            child: GestureDetector(
              onTap: () => _setSort('name'),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Flexible(
                    child: TfText(
                      tfPick(context, en: 'ITEM', bn: 'আইটেম'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _eyebrow(_sortKey == 'name'),
                    ),
                  ),
                  _caret('name'),
                ],
              ),
            ),
          ),
          for (final m in metrics) ...[
            const SizedBox(width: 9),
            SizedBox(
              width: m.w,
              child: GestureDetector(
                onTap: () => _setSort(m.k),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _caret(m.k),
                    Flexible(
                      child: TfText(
                        tfPick(
                          context,
                          en: m.enLabel,
                          bn: m.bnLabel,
                        ).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: _eyebrow(_sortKey == m.k),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bodyRow(BuildContext context, _SalesRow r, int i, int total) {
    final metrics = _visMetrics;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: i == total - 1 ? Colors.transparent : PosColors.line,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: TfText(
              '${i + 1}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: i == 0 ? PosColors.accentStrong : PosColors.mutedSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PosColors.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                TfText(
                  _service == _stAllServices
                      ? '${r.service} · ${r.category}'
                      : r.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PosColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          for (final m in metrics) ...[
            const SizedBox(width: 9),
            SizedBox(
              width: m.w,
              child: TfText(
                _stMetricText(context, r, m),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: m.k == 'profit'
                      ? PosColors.success
                      : (m.k == 'margin' ? PosColors.inkSoft : PosColors.text),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalsRow(BuildContext context, List<_SalesRow> rows) {
    final metrics = _visMetrics;
    final units = rows.fold<int>(0, (s, r) => s + r.units);
    final orders = rows.fold<int>(0, (s, r) => s + r.orders);
    final rev = rows.fold<double>(0, (s, r) => s + r.sales);
    var costKnown = 0.0;
    var revKnown = 0.0;
    var anyCost = false;
    for (final r in rows) {
      if (r.cost != null) {
        anyCost = true;
        costKnown += r.cost!;
        revKnown += r.sales;
      }
    }
    String fmt(_StMetric m) => switch (m.k) {
      'units' => tfFormatNumber(context, units),
      'orders' => tfFormatNumber(context, orders),
      'rev' => _money(context, rev),
      'aov' => orders > 0 ? _money(context, (rev / orders).round()) : '—',
      'cost' => anyCost ? _money(context, costKnown) : '—',
      'profit' => anyCost ? _money(context, revKnown - costKnown) : '—',
      'margin' =>
        revKnown > 0
            ? '${((revKnown - costKnown) / revKnown * 100).round()}%'
            : '—',
      _ => '—',
    };
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      margin: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: PosColors.lineStrong, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const SizedBox(width: 9),
          Expanded(
            child: TfText(
              '${tfPick(context, en: 'Total', bn: 'মোট')} · ${rows.length}',
              style: const TextStyle(
                color: PosColors.inkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final m in metrics) ...[
            const SizedBox(width: 9),
            SizedBox(
              width: m.w,
              child: TfText(
                fmt(m),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: PosColors.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Generic string segmented control (mirrors _Segmented, value-driven).
class _StringSegmented extends StatelessWidget {
  const _StringSegmented({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(String value, String label)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o.$1),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == o.$1
                        ? PosColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(PosRadii.sm),
                    boxShadow: selected == o.$1 ? PosShadows.soft : null,
                  ),
                  child: TfText(
                    o.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected == o.$1
                          ? PosColors.text
                          : PosColors.muted,
                      fontSize: 13,
                      fontWeight: selected == o.$1
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StToolbarButton extends StatelessWidget {
  const _StToolbarButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? PosColors.primarySoft : PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(
            color: active ? PosColors.primaryWash : PosColors.lineStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? PosColors.accentStrong : PosColors.inkSoft,
            ),
            const SizedBox(width: 7),
            TfText(
              label,
              style: TextStyle(
                color: active ? PosColors.accentStrong : PosColors.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StMessage extends StatelessWidget {
  const _StMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TfText(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: PosColors.muted, fontSize: 14),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            TfButton(
              label: tfPick(context, en: 'Retry', bn: 'আবার চেষ্টা'),
              variant: TfButtonVariant.ghost,
              size: TfButtonSize.sm,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

class _StMetricsSheet extends StatefulWidget {
  const _StMetricsSheet({required this.vis});

  final Map<String, bool> vis;

  @override
  State<_StMetricsSheet> createState() => _StMetricsSheetState();
}

class _StMetricsSheetState extends State<_StMetricsSheet> {
  late final Map<String, bool> _vis = Map<String, bool>.from(widget.vis);

  int get _count => _vis.values.where((v) => v).length;

  void _toggle(String k) {
    final on = _vis[k] ?? false;
    if (!on && _count >= _stMaxMetrics) return;
    setState(() => _vis[k] = !on);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: PosColors.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TfText(
                      tfPick(context, en: 'Metrics', bn: 'মেট্রিক'),
                      style: const TextStyle(
                        color: PosColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _vis
                        ..clear()
                        ..addEntries(
                          _stMetrics.map((m) => MapEntry(m.k, m.def)),
                        );
                    }),
                    child: TfText(
                      tfPick(context, en: 'Reset', bn: 'রিসেট'),
                      style: const TextStyle(
                        color: PosColors.accentStrong,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TfText(
                tfPick(
                  context,
                  en: 'Show up to $_stMaxMetrics columns — $_count/$_stMaxMetrics selected',
                  bn: 'সর্বোচ্চ $_stMaxMetrics কলাম — $_count/$_stMaxMetrics নির্বাচিত',
                ),
                style: const TextStyle(color: PosColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              for (final m in _stMetrics) _metricRow(context, m),
              const SizedBox(height: 16),
              TfButton(
                label: tfPick(
                  context,
                  en: 'Show $_count ${_count == 1 ? 'metric' : 'metrics'}',
                  bn: '$_count মেট্রিক দেখান',
                ),
                size: TfButtonSize.lg,
                onPressed: () => Navigator.of(context).pop(_vis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricRow(BuildContext context, _StMetric m) {
    final on = _vis[m.k] ?? false;
    final disabled = !on && _count >= _stMaxMetrics;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => _toggle(m.k),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PosColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    TfText(
                      tfPick(context, en: m.enLabel, bn: m.bnLabel),
                      style: const TextStyle(
                        color: PosColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (m.money) ...[
                      const SizedBox(width: 7),
                      const TfText(
                        '৳',
                        style: TextStyle(
                          color: PosColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TfToggle(
                value: on,
                enabled: !disabled,
                onChanged: (_) => _toggle(m.k),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StFiltersSheet extends StatefulWidget {
  const _StFiltersSheet({
    required this.channel,
    required this.shift,
    required this.terminal,
    required this.staff,
  });

  final String channel;
  final String shift;
  final String terminal;
  final String staff;

  @override
  State<_StFiltersSheet> createState() => _StFiltersSheetState();
}

class _StFiltersSheetState extends State<_StFiltersSheet> {
  late String _channel = widget.channel;
  late String _shift = widget.shift;
  late String _terminal = widget.terminal;
  late String _staff = widget.staff;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: PosColors.lineStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TfText(
                        tfPick(context, en: 'Filters', bn: 'ফিল্টার'),
                        style: const TextStyle(
                          color: PosColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _channel = _stAllChannels;
                        _shift = _stAllShifts;
                        _terminal = _stAllTerminals;
                        _staff = _stAllStaff;
                      }),
                      child: TfText(
                        tfPick(context, en: 'Reset', bn: 'রিসেট'),
                        style: const TextStyle(
                          color: PosColors.accentStrong,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _group(
                  context,
                  tfPick(context, en: 'CHANNEL', bn: 'চ্যানেল'),
                  _stChannelFilters,
                  _channel,
                  (v) => setState(() => _channel = v),
                ),
                _group(
                  context,
                  tfPick(context, en: 'SHIFT', bn: 'শিফট'),
                  _stShiftFilters,
                  _shift,
                  (v) => setState(() => _shift = v),
                ),
                _group(
                  context,
                  tfPick(context, en: 'TERMINAL', bn: 'টার্মিনাল'),
                  _stTerminalFilters,
                  _terminal,
                  (v) => setState(() => _terminal = v),
                ),
                _group(
                  context,
                  tfPick(context, en: 'STAFF / USER', bn: 'স্টাফ / ইউজার'),
                  _stStaffFilters,
                  _staff,
                  (v) => setState(() => _staff = v),
                ),
                const SizedBox(height: 4),
                TfButton(
                  label: tfPick(
                    context,
                    en: 'Apply filters',
                    bn: 'ফিল্টার প্রয়োগ',
                  ),
                  size: TfButtonSize.lg,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((_channel, _shift, _terminal, _staff)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(
    BuildContext context,
    String label,
    List<String> options,
    String value,
    ValueChanged<String> onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfMicroLabel(label),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              TfChip(
                label: o,
                active: value == o,
                tint: true,
                onTap: () => onSelect(o),
              ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.channel, required this.daypart});

  final String channel;
  final String daypart;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String _channel = widget.channel;
  late String _daypart = widget.daypart;

  void _logSheetTouch(String message) {
    if (!kDebugMode) return;
    debugPrint(
      '[QB-ANALYTICS-TOUCH-DIAG] filtersSheet $message '
      'channel="$_channel" daypart="$_daypart"',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: PosColors.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TfText(
                      tfPick(context, en: 'Filters', bn: 'ফিল্টার'),
                      style: const TextStyle(
                        color: PosColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _logSheetTouch('reset tap');
                      _channel = _allChannels;
                      _daypart = _allDay;
                    }),
                    child: TfText(
                      tfPick(context, en: 'Reset', bn: 'রিসেট'),
                      style: const TextStyle(
                        color: PosColors.accentStrong,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TfMicroLabel(tfPick(context, en: 'CHANNEL', bn: 'চ্যানেল')),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _channelFilters)
                    TfChip(
                      label: c,
                      active: _channel == c,
                      tint: true,
                      onTap: () => setState(() {
                        _logSheetTouch('channel chip tap "$_channel"->"$c"');
                        _channel = c;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              TfMicroLabel(tfPick(context, en: 'DAYPART', bn: 'ডেপার্ট')),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _daypartFilters)
                    TfChip(
                      label: d,
                      active: _daypart == d,
                      tint: true,
                      onTap: () => setState(() {
                        _logSheetTouch('daypart chip tap "$_daypart"->"$d"');
                        _daypart = d;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TfButton(
                label: tfPick(
                  context,
                  en: 'Apply filters',
                  bn: 'ফিল্টার প্রয়োগ',
                ),
                size: TfButtonSize.lg,
                onPressed: () {
                  _logSheetTouch('apply tap');
                  Navigator.of(context).pop((_channel, _daypart));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared small widgets
// ===========================================================================
class _Segmented extends StatelessWidget {
  const _Segmented({required this.selected, required this.onChanged});

  final _Timeframe selected;
  final ValueChanged<_Timeframe> onChanged;

  @override
  Widget build(BuildContext context) {
    final opts = <(_Timeframe, String)>[
      (_Timeframe.today, tfPick(context, en: 'Today', bn: 'আজ')),
      (_Timeframe.week, tfPick(context, en: '7 days', bn: '৭ দিন')),
      (_Timeframe.month, tfPick(context, en: '30 days', bn: '৩০ দিন')),
      (_Timeframe.custom, tfPick(context, en: 'Custom', bn: 'কাস্টম')),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Row(
        children: [
          for (final o in opts)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o.$1),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == o.$1
                        ? PosColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(PosRadii.sm),
                    boxShadow: selected == o.$1 ? PosShadows.soft : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (o.$1 == _Timeframe.custom) ...[
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: selected == o.$1
                              ? PosColors.text
                              : PosColors.muted,
                        ),
                        const SizedBox(width: 4),
                      ],
                      TfText(
                        o.$2,
                        style: TextStyle(
                          color: selected == o.$1
                              ? PosColors.text
                              : PosColors.muted,
                          fontSize: 13,
                          fontWeight: selected == o.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: TfText(
            title,
            style: const TextStyle(
              color: PosColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (note != null)
          TfText(
            note!,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _SeeAllHeader extends StatelessWidget {
  const _SeeAllHeader({required this.title, this.note, required this.onSeeAll});

  final String title;
  final String? note;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _SectionTitle(title, note: note)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSeeAll,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TfText(
                tfPick(context, en: 'See all', bn: 'সব দেখুন'),
                style: const TextStyle(
                  color: PosColors.accentStrong,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: PosColors.accentStrong,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color, this.height = 8});

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: height,
        color: PosColors.surfaceSunk,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankNumber extends StatelessWidget {
  const _RankNumber({required this.rank, this.small = false});

  final int rank;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      child: TfText(
        '${rank + 1}',
        style: TextStyle(
          color: rank == 0 ? PosColors.accentStrong : PosColors.mutedSoft,
          fontSize: small ? 12.5 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? PosColors.primarySoft : PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.sm),
          border: Border.all(
            color: active ? PosColors.primaryWash : PosColors.lineStrong,
          ),
        ),
        child: TfText(
          label,
          style: TextStyle(
            color: active ? PosColors.accentStrong : PosColors.inkSoft,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: PosColors.primarySoft,
          borderRadius: BorderRadius.circular(PosRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TfText(
              label,
              style: const TextStyle(
                color: PosColors.accentStrong,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.close_rounded,
              size: 14,
              color: PosColors.accentStrong,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    final color = up ? PosColors.success : PosColors.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 2),
        TfText(
          '${up ? '+' : ''}$value%',
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return TfIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: tfPick(context, en: 'Back', bn: 'ফিরে যান'),
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(top: BorderSide(color: PosColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: TfButton(
          label: label,
          icon: Icons.download_rounded,
          size: TfButtonSize.lg,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

// ===========================================================================
// Painters
// ===========================================================================
class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({
    required this.values,
    required this.labels,
    this.compare,
    required this.isBn,
  });

  final List<double> values;
  final List<double>? compare;
  final List<String> labels;
  final bool isBn;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 8.0;
    const labelBand = 18.0;
    final chartH = size.height - labelBand;
    final all = [...values, ...?compare];
    final max = all.reduce(math.max) * 1.12;
    final min = all.reduce(math.min) * 0.82;
    final range = (max - min) == 0 ? 1 : (max - min);

    double x(int i) => pad + i * (size.width - pad * 2) / (values.length - 1);
    double y(double v) => chartH - pad - (v - min) / range * (chartH - pad * 2);

    // Grid lines
    final grid = Paint()
      ..color = PosColors.line
      ..strokeWidth = 1;
    for (final g in [0.25, 0.5, 0.75]) {
      final gy = pad + g * (chartH - pad * 2);
      _dashedLine(canvas, Offset(pad, gy), Offset(size.width - pad, gy), grid);
    }

    // Area fill
    final areaPath = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      areaPath.lineTo(x(i), y(values[i]));
    }
    areaPath
      ..lineTo(x(values.length - 1), chartH - pad)
      ..lineTo(x(0), chartH - pad)
      ..close();
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x5799FF47), Color(0x0099FF47)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartH));
    canvas.drawPath(areaPath, fill);

    // Compare dashed line
    if (compare != null) {
      final cmpPaint = Paint()
        ..color = PosColors.mutedSoft
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      _dashedPolyline(canvas, [
        for (var i = 0; i < compare!.length; i++) Offset(x(i), y(compare![i])),
      ], cmpPaint);
    }

    // Main line
    final linePath = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      linePath.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = _cLine
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    final last = values.length - 1;
    for (var i = 0; i < values.length; i++) {
      final isLast = i == last;
      canvas.drawCircle(
        Offset(x(i), y(values[i])),
        isLast ? 4 : 2.3,
        Paint()..color = isLast ? _cLine : Colors.white,
      );
      if (!isLast) {
        canvas.drawCircle(
          Offset(x(i), y(values[i])),
          2.3,
          Paint()
            ..color = _cLine
            ..strokeWidth = 1.6
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // X labels
    for (var i = 0; i < labels.length; i++) {
      final isLast = i == last;
      final tp = TextPainter(
        text: TextSpan(
          text: isBn ? tfToBnNumbers(labels[i]) : labels[i],
          style: TextStyle(
            color: isLast ? PosColors.text : PosColors.muted,
            fontSize: 10,
            fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x(i) - tp.width / 2, chartH + (labelBand - tp.height) / 2),
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    _dashedPolyline(canvas, [a, b], paint, dash: 3, gap: 4);
  }

  void _dashedPolyline(
    Canvas canvas,
    List<Offset> points,
    Paint paint, {
    double dash = 4,
    double gap = 4,
  }) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final dist = (b - a).distance;
      final dir = (b - a) / dist;
      var d = 0.0;
      while (d < dist) {
        final start = a + dir * d;
        final end = a + dir * math.min(d + dash, dist);
        canvas.drawLine(start, end, paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) =>
      old.values != values || old.compare != compare || old.isBn != isBn;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.centerText,
    required this.centerLabel,
    required this.isBn,
  });

  final List<_Slice> slices;
  final String centerText;
  final String centerLabel;
  final bool isBn;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = PosColors.surfaceSunk
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke,
    );

    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.pct / 100 * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = s.color
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke,
      );
      start += sweep;
    }

    final valueTp = TextPainter(
      text: TextSpan(
        text: isBn ? tfToBnNumbers(centerText) : centerText,
        style: const TextStyle(
          color: PosColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    valueTp.paint(
      canvas,
      Offset(center.dx - valueTp.width / 2, center.dy - valueTp.height + 2),
    );

    final labelTp = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: const TextStyle(
          color: PosColors.muted,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 24);
    labelTp.paint(canvas, Offset(center.dx - labelTp.width / 2, center.dy + 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      !identical(old.slices, slices) ||
      old.centerText != centerText ||
      old.centerLabel != centerLabel ||
      old.isBn != isBn;
}
