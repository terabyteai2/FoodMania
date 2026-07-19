# Flutter Performance Analysis Report

**Project:** FoodMania admin_app  
**Date:** 2026-07-19  
**Files analyzed:** 6 core files (~11,547 lines total)

---

## 1. `tf_design_system.dart` (4,654 lines)

### 1.1 Object Creation in Build Methods — `TfMoney`

**Severity: HIGH**

`TfMoney.build()` creates a `RegExp` and performs string manipulation on every rebuild:

```dart
// Lines ~560-585
@override
Widget build(BuildContext context) {
  final isBn = tfIsBn(context);
  final parts = amount.toStringAsFixed(2).split('.');
  final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String matchFunc(Match match) => '${match[1]},';
  final String formattedInteger = parts[0].replaceAllMapped(reg, matchFunc);
  // ...
  final baseStyle = style ?? TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700,
    color: PosColors.slate, fontFamily: tfFontFamily(context),
  );
```

**Issues:**
- `RegExp` object allocated on every build call — should be `static final`
- `TextStyle` fallback created on every build when `style` is null — should be a `const` default
- `toStringAsFixed(2).split('.')` runs unconditionally even when the value is unchanged between rebuilds

**Fix:**
```dart
static final RegExp _groupRegex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
static const TextStyle _defaultStyle = TextStyle(
  fontSize: 16, fontWeight: FontWeight.w700,
  color: PosColors.slate, fontFamily: tfEnglishFontFamily,
);
```

### 1.2 Repeated Locale Lookups in Every Widget

**Severity: MEDIUM**

Every `TfText`, `TfMicroLabel`, `TfDelta`, `TfMoney` widget calls `tfIsBn(context)` which calls `Localizations.localeOf(context)` — this is an `InheritedWidget` lookup (O(log n) element traversal) on every build. In a screen with 100+ `TfText` widgets (common in grids/lists), this is 100+ inherited lookups per frame.

```dart
// Line ~265 — TfText.build
@override
Widget build(BuildContext context) {
  final isBn = tfIsBn(context);          // InheritedWidget lookup
  final base = style ?? const TextStyle();
  final safeStyle = tfSafeTextStyle(context, base);  // another lookup
  return Text(
    isBn ? tfToBnNumbers(text) : text,
    style: safeStyle,
    strutStyle: tfSafeStrutStyle(context, safeStyle),  // another lookup
    textHeightBehavior: tfSafeTextHeightBehavior(context),  // another lookup
```

**Issues:**
- 4 separate `tfIsBn(context)` calls (each doing `Localizations.localeOf`) within a single `TfText.build()` via the helper functions
- `tfSafeTextStyle`, `tfSafeStrutStyle`, `tfSafeTextHeightBehavior` each independently call `tfIsBn(context)`

**Fix:** Cache `isBn` once per build and pass it down, or create a single `LocaleInfo` inherited widget that bundles all locale-derived data.

### 1.3 `tfToBnNumbers` — Repeated Character Replacement

**Severity: LOW**

```dart
// Lines ~110-118
String tfToBnNumbers(String input) {
  const english = ['0','1','2','3','4','5','6','7','8','9'];
  const bangla = ['০','১','২','৩','৪','৫','৬','৭','৮','৯'];
  String output = input;
  for (int i = 0; i < english.length; i++) {
    output = output.replaceAll(english[i], bangla[i]);
  }
  return output;
}
```

**Issue:** 10 sequential `replaceAll` calls create 10 intermediate strings. Called on every `TfText` widget in Bangla mode. For a screen with 50 text widgets showing numbers, that's 500 string allocations per frame.

**Fix:** Use a single `replaceAllMapped` with a character map:
```dart
static final Map<String, String> _digitMap = {
  '0': '০', '1': '১', /* ... */ '9': '৯',
};
String tfToBnNumbers(String input) =>
    input.replaceAllMapped(RegExp(r'[0-9]'), (m) => _digitMap[m[0]]!);
```

### 1.4 `TfSourceIcon` — CustomPaint Repaints

**Severity: LOW**

```dart
// Lines ~720-740
class _TfSourceIconPainter extends CustomPainter {
  @override
  bool shouldRepaint(_TfSourceIconPainter oldDelegate) =>
      oldDelegate.name != name ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
```

**Issue:** The painter is correctly implemented with `shouldRepaint`, but the parent `TfSourceIcon` widget creates a new `_TfSourceIconPainter` instance on every build even when props haven't changed. Flutter's `CustomPaint` will still call `shouldRepaint` (which returns false), but the painter object is allocated needlessly.

**Fix:** Make the painter a `static const` when the icon is static, or cache it:

### 1.5 `TfButton` — Non-const Default Variants

**Severity: MEDIUM**

The `TfButton` widget (around line ~1000+) doesn't use const constructors for its internal decorations. Each build creates new `BoxDecoration`, `BoxShadow` lists, and `TextStyle` objects. Since `TfButton` appears repeatedly in lists and toolbars, this adds up.

### 1.6 `_AreaChartPainter` and `_BarChartPainter` — Text Painting in Custom Painter

**Severity: MEDIUM**

```dart
// Around line ~3700+_AreaChartPainter.paint
void paint(Canvas canvas, Size size) {
  // ...
  _paintText(canvas, money ? _kfmt(maxVal * i / 4) : ..., ...);
  // ...
}
```

**Issue:** `_paintText` (a helper that creates a `TextPainter` and lays out text) is called inside `paint()`. `TextPainter` layout is expensive — called 5+ times per chart frame for grid labels and x-axis labels. No text layout caching.

**Fix:** Pre-compute label strings outside the painter and cache `TextPainter` instances, or use a separate overlay of `Text` widgets positioned over the `CustomPaint`.

### 1.7 `TfMenuPerfTable` — ListView Inside Column

**Severity: MEDIUM**

```dart
// Around line ~3400
ListView.separated(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: rows.length,
  // ...
)
```

**Issue:** `shrinkWrap: true` with `NeverScrollableScrollPhysics` forces the `ListView` to measure all children, defeating lazy building. For long menus (100+ items), this builds every row eagerly. Should use `CustomScrollView` with `SliverList` or a regular `Column` with `.map()`.

---

## 2. `tables_screen.dart` (477 lines)

### 2.1 Timer-Driven Full Screen Rebuild

**Severity: HIGH**

```dart
// Lines ~30-40
@override
void initState() {
  super.initState();
  _tick = Timer.periodic(const Duration(seconds: 30), (_) {
    if (mounted) setState(() {});
  });
}
```

**Issue:** Every 30 seconds, `setState()` is called on the entire `TablesScreen` state, rebuilding the full widget subtree including the grid, all table cells, and the tab bar — even if no table state has changed. The `AppScope.selectMany` call in `build()` also re-subscribes to `orders`, `settings`, and `language` aspects.

**Fix:** Only rebuild the cells that display elapsed time. Either:
- Use a `ValueNotifier<int>` tick that individual cells listen to via `ValueListenableBuilder`
- Or use `BlocBuilder` / `Selector` to scope rebuilds to cells showing occupied tables

### 2.2 Filter + List Creation in `_FullService.build()`

**Severity: MEDIUM**

```dart
// Lines ~72-76
final openOrders = app.ordersFor().where((o) => o.status.isOpen).toList();
```

Then further filtering at lines ~93-99:
```dart
orders: openOrders
    .where((o) => o.serviceType == OrderServiceType.takeaway)
    .toList(),
```

**Issue:** `app.ordersFor()` returns a full list which is then filtered 3 times (once for open, once for takeaway, once for delivery) on every build. No memoization.

**Fix:** Cache the filtered lists in the state and only recompute when `app.ordersFor()` identity changes.

### 2.3 `_DineInGrid.build()` — Map Construction Every Frame

**Severity: MEDIUM**

```dart
// Lines ~105-120
final byTable = <String, OrderModel>{};
final occupiedTableKeys = <String>{};
for (final o in openOrders) {
  final raw = (o.tableNo ?? '').trim();
  if (raw.isEmpty) continue;
  occupiedTableKeys.add(raw.startsWith('T') ? raw.substring(1) : raw);
  byTable[raw] = o;
  if (raw.startsWith('T')) {
    byTable[raw.substring(1)] = o;
  } else {
    byTable['T$raw'] = o;
  }
}
```

**Issue:** For every grid build, a `Map` and `Set` are allocated and populated by iterating all open orders. With the 30-second timer driving rebuilds, this runs twice per minute. Each `GridView.builder` item then does `byTable[label]` lookup.

**Fix:** Move the map computation to a memoized field keyed on `openOrders` identity.

### 2.4 `_CounterMode` — Good: Menu Memo Pattern

**Severity: GOOD PRACTICE (noted positively)**

```dart
// Lines ~280-310
List<MenuItem>? _menuMemoKey;
List<MenuItem> _partitionedMenu = const [];
Map<String, String> _searchBlobs = const {};

void _ensureMenuMemo(List<MenuItem> items) {
  if (identical(_menuMemoKey, items)) return;
  // recompute only when the list identity changes
}
```

**Note:** This is an excellent pattern — identity-based memoization prevents recomputation on every build. The only improvement would be to also debounce search filtering when typing quickly.

### 2.5 `_CounterMode` — `_cartQtyByItemId` Computed Every Build

**Severity: LOW-MEDIUM**

```dart
// Lines ~330-336
Map<String, int> get _cartQtyByItemId {
  final out = <String, int>{};
  for (final line in _cartLines) {
    out[line.item.id] = (out[line.item.id] ?? 0) + line.qty;
  }
  return out;
}
```

**Issue:** Allocates a new `Map` on every `build()` call. When the cart has many lines and the user is typing in search, this map is rebuilt on every keystroke.

---

## 3. `analytics_screen.dart` (1,347 lines)

### 3.1 `_RevenueChartCard` — List Comprehension on Every Build

**Severity: MEDIUM**

```dart
// Around line ~1050
@override
Widget build(BuildContext context) {
  final values = [
    for (final p in widget.trend)
      _metric == 0 ? p.revenue : p.orders.toDouble(),
  ];
  final labels = [for (final p in widget.trend) _shortDate(p.date)];
```

**Issue:** Two new lists are created on every build, even when `widget.trend` hasn't changed. The `_shortDate` function parses ISO date strings on every frame.

**Fix:** Cache `values` and `labels` in `didUpdateWidget` or use `useMemoized` pattern; only recompute when `trend` or `_metric` changes.

### 3.2 `ItemDrillDownScreen` — Reversed List Copy

**Severity: LOW**

```dart
// Around line ~1150
final reversed = d.daily.reversed.toList();
```

**Issue:** `.reversed.toList()` creates a new list copy on every build. This should be cached in state.

### 3.3 `_salesBreakdown` — Heavy Inline Widget List Construction

**Severity: MEDIUM**

```dart
// Lines ~175-230
List<Widget> _salesBreakdown(BuildContext context, AppStrings text, AnalyticsSummaryData d) {
  // ...
  return [
    ..._diagnosticWidgets(),
    if (d.trend.isNotEmpty) ...[
      _RevenueChartCard(trend: d.trend, text: text),
      const SizedBox(height: PosSpacing.sp3),
    ],
    _analyticsKpiGrid(context, text, d),
    // ... many more widgets including ReportSection with 8+ ReportRow items
  ];
}
```

**Issue:** The entire widget list (potentially 20+ widgets including charts, stat grids, report sections) is built as a `List<Widget>` on every `build()` call. Since the parent `ListView` already handles lazy building, constructing all widgets eagerly in a list defeats the purpose.

**Fix:** Return the widgets inline as children of the `ListView` (which is already the case in the parent), but avoid assembling them as a list that's then spread into the ListView. Instead, use a builder pattern or `CustomScrollView` with slivers.

### 3.4 `_StatTile` — Non-const BoxDecoration

**Severity: LOW**

```dart
// Around line ~630
@override
Widget build(BuildContext context) {
  return TfCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
```

**Issue:** `BoxDecoration` with a variable `tint` color can't be const, but the `shape: BoxShape.circle` and dimensions are constant. With 6 stat tiles per screen, this is 6 new `BoxDecoration` objects per frame.

### 3.5 FutureBuilder Rebuild Pattern

**Severity: MEDIUM**

```dart
// Lines ~100-110
FutureBuilder<AnalyticsSummaryData>(
  future: _future,
  builder: (context, snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const TfLoading();
    }
    // ...
  },
)
```

**Issue:** `_future` is set once via `??=` in `didChangeDependencies`. When `_setRange` is called, a new `_load()` future is assigned. However, the `FutureBuilder` rebuilds on every framework rebuild tick even when the future hasn't changed, because `FutureBuilder` doesn't compare future identity. This means the chart widgets inside the builder are rebuilt even during parent rebuilds that don't change the data.

**Fix:** Extract the `FutureBuilder` into a separate widget `const`-keyed by the future's identity, or use a `Stream`/`StatefulWidget` that only rebuilds when data actually arrives.

### 3.6 `_PopularDishes` — Iterative Container Creation

**Severity: LOW**

```dart
// Around line ~700
for (final dish in shown)
  Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: PosColors.line)),
    ),
```

**Issue:** Each dish row is created eagerly inside a `Column` (not a `ListView.builder`), meaning all rows are built at once. For 10+ popular dishes, this is 10+ `Container` + `Row` + `TfText` widget trees in a single frame.

---

## 4. `inventory_screen.dart` (1,333 lines)

### 4.1 Good: Sort Memoization

**Severity: GOOD PRACTICE (noted positively)**

```dart
// Lines ~155-180
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
```

**Note:** Excellent memoization — sort only recomputes when source list identity or sort key changes.

### 4.2 `build()` — Fold Operations on Every Rebuild

**Severity: MEDIUM**

```dart
// Lines ~240-250
final items = summary?.items ?? const <InventorySummaryItem>[];
final stockValue = items.fold<double>(0, (s, i) => s + _itemValue(i));
final lowCount = items.where((i) => _stockKind(i.onHand, i.minThreshold) != 'ok').length;
final sorted = _sorted(items);
```

**Issue:** Two O(n) passes (`fold` + `where().length`) over the full inventory on every build. These should be memoized alongside the sort cache, since they only change when the items list changes.

**Fix:**
```dart
double? _stockValueCache;
int? _lowCountCache;
// invalidate alongside _sortedCache
```

### 4.3 `_StockTable` — All Rows Built Eagerly

**Severity: HIGH**

```dart
// Lines ~510-520
Container(
  // ...
  child: Column(
    children: [
      Container(/* header */),
      for (var i = 0; i < items.length; i++)
        _StockRow(
          text: text,
          item: items[i],
          // ...
        ),
    ],
  ),
)
```

**Issue:** The entire stock table is built as a `Column` with a `for` loop — no lazy building. If there are 200+ inventory items, every single `_StockRow` widget is created and laid out on every frame, even ones off-screen. Combined with the `SingleChildScrollView` parent, this means the entire table is always in the widget tree.

**Fix:** Replace `Column` + `for` with `ListView.builder` (or `CustomScrollView` + `SliverList`) for lazy row building. Keep the header as a `SliverPersistentHeader`.

### 4.4 `_ItemFormSheet` — Uuid Instance Created Per Widget

**Severity: LOW**

```dart
// Lines ~1070
final _uuid = const Uuid();
```

**Issue:** `const Uuid()` is fine (shared), but the widget creates form field `TextEditingController`s in `initState` that are properly disposed. No issue here — noted as good practice.

### 4.5 `_StockRow` — Multiple `TfText` Widgets per Row (~6-8 each)

**Severity: MEDIUM**

Each `_StockRow` builds approximately 6-8 `TfText` widgets, each doing 4 `tfIsBn(context)` lookups (see §1.2). For 200 rows, that's ~6,400 inherited widget lookups per frame.

**Fix:** Resolve locale once at the parent `_StockTable` level and pass `isBn` down, or use a locale-inherited widget that caches the result.

---

## 5. `menu_management_screen.dart` (2,877 lines)

### 5.1 Search Filtering on Every Keystroke — Full Rebuild

**Severity: HIGH**

```dart
// Lines ~55-70
@override
Widget build(BuildContext context) {
  final app = AppScope.selectMany(context, const [
    AppAspect.menu, AppAspect.account, AppAspect.language,
  ]);
  // ...
  final query = _searchController.text.trim().toLowerCase();
  final items = app.menuItems
      .where((item) {
        final matchesCategory = _selectedCategory == text.allCategories ||
            item.localizedCategory(language) == _selectedCategory;
        final matchesSearch = query.isEmpty
            ? true
            : item.searchText(language).contains(query);
        return matchesCategory && matchesSearch;
      })
      .toList(growable: false);
```

**Issue:** Every keystroke in the search field triggers `setState()` (via `onChanged: (_) => setState(() {})`), which rebuilds the entire screen and re-filters ALL menu items. `item.searchText(language)` likely builds a search string for each item on every filter pass. For 500+ menu items, this is 500+ string operations per keystroke.

**Fix:**
- Debounce search input (e.g., 300ms delay)
- Pre-compute and cache `searchText` per item (like `_CounterMode` in `tables_screen.dart` does with `_searchBlobs`)
- Use `ValueListenableBuilder` for the search field to avoid rebuilding the entire screen

### 5.2 `onChanged: (_) => setState(() {})` — Bare SetState

**Severity: HIGH**

```dart
// Line ~98
TfSearchField(
  controller: _searchController,
  onChanged: (_) => setState(() {}),
```

**Issue:** `setState(() {})` with an empty body is technically a no-op rebuild trigger, but combined with the full `build()` method that does all the filtering, it causes the maximum possible work per keystroke. The shadow `_CounterMode` widget in `tables_screen.dart` has this same pattern but with proper memoization.

### 5.3 Filter Chip Counts Recomputed Every Build

**Severity: MEDIUM**

```dart
// Lines ~100-115
TfFilterChipRow(
  chips: categories
      .map((cat) => TfFilterChipData(
        label: cat,
        count: cat == text.allCategories
            ? app.menuItems.length
            : app.menuItems.where((i) => i.localizedCategory(language) == cat).length,
        active: cat == _selectedCategory,
      ))
      .toList(),
```

**Issue:** For each category chip, `app.menuItems.where(...).length` iterates the entire menu items list. With 20 categories and 500 items, that's 10,000 comparisons per build. Should be pre-computed once.

### 5.4 `_selectedItemIds.removeWhere` in `build()`

**Severity: LOW**

```dart
// Lines ~75-77
_selectedItemIds.removeWhere(
  (id) => !app.menuItems.any((item) => item.id == id),
);
```

**Issue:** O(n*m) lookup — for each selected ID, scans all menu items. With 50 selected items and 500 menu items, that's 25,000 comparisons per build. Should use a `Set` of valid IDs.

### 5.5 Image Handling — `_DesktopMenuCard` Builds Image Widgets Eagerly

**Severity: MEDIUM**

```dart
// Around line ~1030
GridView.builder(
  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 265,
    mainAxisExtent: 190,
  ),
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return _DesktopMenuCard(
      item: item,
      // ...
```

**Good**: Uses `GridView.builder` for lazy building. However, each `_DesktopMenuCard` constructs a `MenuImageView` widget which likely loads images. No explicit image caching is visible at this level. The image caching depends on `MenuImageView`'s implementation.

### 5.6 `_desktopCategories` — `countOf` Computed Per Item in ListView

**Severity: LOW**

```dart
// Around line ~430
int countOf(String category) => category == text.allCategories
    ? allItems.length
    : allItems.where((i) => i.localizedCategory(language) == category).length;
```

**Issue:** Called for each category in the horizontal `ListView`. With 20 categories, each doing a full scan — 20 × 500 = 10,000 comparisons. Minor since it's a short horizontal list, but wasteful.

---

## 6. `app.dart` (1,739 lines)

### 6.1 `ListenableBuilder` on `PosAppController` — Root-Level Rebuilds

**Severity: HIGH**

```dart
// Lines ~50-60
@override
Widget build(BuildContext context) {
  return AppScope(
    controller: _controller,
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final text = _controller.strings;
        final tone = _resolveTone(_controller.themePreference);
        PosColors.setTone(tone);
        return AppModel(
          controller: _controller,
          child: MaterialApp(
```

**Issue:** `ListenableBuilder` listens to the entire `PosAppController` (which is a `ChangeNotifier` or similar). Every `notifyListeners()` call on the controller rebuilds the **entire `MaterialApp`** — including theme, locale, and the entire widget tree. This is the single most expensive rebuild in the app.

**Fix:** Use targeted `AppScope.select` / `AppScope.selectMany` at this level to only rebuild when the specific aspects that affect the `MaterialApp` shell change (language, theme). The child screens already use `selectMany`, but the root `ListenableBuilder` fires on every notification regardless.

### 6.2 `PosColors.setTone(tone)` Called in Build

**Severity: MEDIUM**

```dart
// Line ~58
PosColors.setTone(tone);
```

**Issue:** Mutating static color tokens during `build()` is a side effect in a build method — this violates Flutter's build purity principle. If `setTone` changes static state, it should be done in `didChangeDependencies` or in response to a theme change, not on every build pass.

### 6.3 `_LazyIndexedStack` — Good Pattern for Tab Isolation

**Severity: GOOD PRACTICE (noted positively)**

```dart
// Around line ~520
final body = _LazyIndexedStack(
  index: _selected.index,
  builders: pageBuilders,
);
```

**Note:** BaldLazy indexed stack is the correct pattern — only mounts the active tab's page and lazily builds others on first visit. This prevents all tabs from being in the widget tree simultaneously.

### 6.4 `MainShell.build()` — LayoutBuilder Rebuilds on Every Constraint Change

**Severity: MEDIUM**

```dart
// Around line ~540
return LayoutBuilder(
  builder: (context, constraints) {
    final useRail = constraints.maxWidth >= 760;
    // ...
    return Scaffold(
      key: _scaffoldKey,
      // ...
```

**Issue:** `LayoutBuilder` triggers a rebuild on every constraint change (window resize, keyboard appearance, orientation change). The entire body (including `_LazyIndexedStack` and `NavigationRail`/`Drawer` setup) is reconstructed. The `destinations` list and `pageBuilders` list are rebuilt every time.

**Fix:** Extract the `LayoutBuilder` decision to a higher level (e.g., a `MediaQuery` BasedBuilder) and widget-cache the two outcomes so they don't change structure on minor constraint changes.

### 6.5 Notification Toast — Timer-Based Debounce

**Severity: LOW**

```dart
// Lines ~680-690
_notificationToastDebounce?.cancel();
_notificationToastDebounce = Timer(const Duration(milliseconds: 600), () {
  if (!mounted) return;
  _showPendingNotificationToast();
});
```

**Issue:** The debounce timer is correctly implemented, but `_showPendingNotificationToast` reads from `AppScope.read(context)` (which does a full inherited widget lookup) and creates `showTopNotificationToast` — a new overlay entry. This is fine for occasional notifications but could stack if multiple notifications arrive in quick succession (the debounce key logic prevents duplicates but not chain-ups).

### 6.6 `_AppNavDrawer` — Full Rebuild on Every Selection

**Severity: LOW**

```dart
// The drawer reads AppAspect.language/account/settings
final app = AppScope.selectMany(context, const [
  AppAspect.language, AppAspect.account, AppAspect.settings,
]);
```

**Issue:** The drawer rebuilds on any change to language, account, or settings — but the actual destination list is static per role. Could use `const` widgets for unchanging portions.

---

## Summary — Top 10 Priority Fixes

| # | File | Issue | Severity | Impact |
|---|------|-------|----------|--------|
| 1 | `app.dart` | `ListenableBuilder` on full controller → rebuilds MaterialApp | HIGH | Every controller notification rebuilds entire app |
| 2 | `menu_management_screen.dart` | Search filtering + chip counts recomputed per keystroke | HIGH | UI jank with 500+ menu items |
| 3 | `tables_screen.dart` | 30s timer triggers full screen `setState` | HIGH | Unnecessary grid rebuilds every 30s |
| 4 | `inventory_screen.dart` | All stock rows built eagerly in `Column` | HIGH | 200+ rows always in widget tree |
| 5 | `tf_design_system.dart` | 4× `tfIsBn(context)` per `TfText` widget | MEDIUM | 400+ inherited lookups per screen |
| 6 | `tf_design_system.dart` | `TfMoney` allocates RegExp per build | MEDIUM | String/regex allocation in hot path |
| 7 | `analytics_screen.dart` | Chart data lists rebuilt on every frame | MEDIUM | List allocation + date parsing per frame |
| 8 | `inventory_screen.dart` | `fold` + `where().length` O(n) passes per build | MEDIUM | Full inventory scan every rebuild |
| 9 | `app.dart` | `PosColors.setTone()` side effect in build | MEDIUM | Violates build purity |
| 10 | `tf_design_system.dart` | `TfMenuPerfTable` shrinkWrap defeats lazy building | MEDIUM | All rows built eagerly |

---

## Architectural Recommendations

### A. Locale Resolution Caching
Create a single `InheritedLocale` widget that pre-computes `isBn`, `fontFamily`, `strutStyle` defaults once per locale change. All `Tf*` widgets read from this instead of calling `Localizations.localeOf(context)` independently.

### B. Search Debounce Pattern
Standardize the `_CounterMode` memoization pattern across all search-driven screens (menu, tables counter mode, inventory). Consider a `useDebouncedSearch` hook-style helper.

### C. Controller Granularity
Split `PosAppController` into multiple `Listenable` sub-controllers (or use `ValueNotifier<T>` per aspect) so that `ListenableBuilder` at the root only rebuilds when truly app-wide state changes.

### D. Table/Grid Lazy Building
Replace any `Column(children: [for(...) ...])` pattern with `ListView.builder` or `SliverList.builder` to minimize off-screen widget count.

### E. Const Widget Promotion
Audit all `BoxDecoration`, `TextStyle`, `EdgeInsets`, and `Border` objects for `const` promotion — especially in frequently-built widgets (`_StockRow`, `_StatTile`, `TfButton`).