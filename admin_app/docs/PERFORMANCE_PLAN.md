# FoodMania admin_app — Performance Optimization Plan

**Date:** 2026-07-19  
**Project:** `/home/dev/Documents/GitHub/FoodMania/admin_app`  
**Mode:** Plan only — no edits yet

---

## Context

The app is a Flutter POS (Quickbytes) for the Bangladesh restaurant market. ~72k lines of Dart across ~120 files. Architecture: single `PosAppController` (ChangeNotifier) provided via `AppScope` (InheritedNotifier) + `AppModel` (InheritedModel for aspect-scoped rebuilds). Offline-first with SQLite + REST + WebSocket sync.

**What's already good:**
- `AppModel` aspect system exists (InheritedModel with 13 aspects)
- Orders paginated (200 initial, 100/page, 500 max)
- `_LazyIndexedStack` for tab isolation
- Identity-based memoization in `_CounterMode` and inventory sort
- Sync uses self-rescheduling timer with jitter (not Timer.periodic)
- Image cache capped at 48MB/120 images
- BoundedStringSet for alert tracking (cap 2000)
- Proper dispose() for timers, subscriptions, controllers
- Sync listener has manual change detection before notifying

**The problem:** Despite the aspect system existing, it's underutilized. 209 `AppScope.of` calls (full subscription) vs 9 `AppScope.select` calls (scoped). The root `ListenableBuilder` rebuilds the entire MaterialApp on every notification. 95 `notifyListeners()` calls on a monolithic controller.

---

## Phase 1: Root Rebuild Fix (HIGH IMPACT, LOW RISK)

### 1.1 — Remove root-level `ListenableBuilder` on full controller
**File:** `app.dart` ~line 91  
**Issue:** `ListenableBuilder(listenable: _controller, ...)` wraps the entire `MaterialApp`. Every `notifyListeners()` (95 call sites) rebuilds the whole tree.  
**Fix:** Remove the `ListenableBuilder`. The `AppScope` (InheritedNotifier) + `AppModel` (InheritedModel) already handle scoped rebuilds. The only things the root builder provides are: theme tone, locale, and `AppModel` wrapping. Move `PosColors.setTone()` to `didChangeDependencies` of the `LocalPosApp` root widget, and derive locale from a `ValueListenableBuilder` or the existing aspect system.  
**Risk:** Low — the `AppModel` already sits inside `AppScope` and handles aspect-scoped notification.

### 1.2 — Migrate `AppScope.of` → `AppScope.select`/`selectMany` in hot screens
**Files:** 209 call sites across `features/`  
**Issue:** Most screens use `AppScope.of(context)` which subscribes to ALL aspects.  
**Fix:** Systematically replace with `AppScope.selectMany` specifying only the needed aspects. Priority screens: `orders_screen.dart`, `tables_screen.dart`, `menu_management_screen.dart`, `inventory_screen.dart`, `analytics_screen.dart`, `settings_screen.dart`, `messages_screen.dart`, `more_screen.dart`.  
**Risk:** Low — mechanical replacement, well-defined aspect enum.

### 1.3 — Move `PosColors.setTone()` out of build
**File:** `app.dart` ~line 97  
**Issue:** Side effect in build method — mutates static state during build.  
**Fix:** Move to `didChangeDependencies` or a theme-change listener on the controller.

---

## Phase 2: Widget Rebuild Efficiency (HIGH IMPACT, MEDIUM RISK)

### 2.1 — 30s timer: scope rebuild to only occupied table cells
**Files:** `tables_screen.dart` ~line 54, `orders_screen.dart` ~line 221  
**Issue:** Both screens use `Timer.periodic(30s, (_) => setState(() {}))` which rebuilds the entire screen.  
**Fix:** Create a shared `ValueNotifier<int>` tick notifier (or `EntryageTicker`). Individual cells/widgets that display elapsed time listen via `ValueListenableBuilder`. The rest of the screen never rebuilds.  
**Pattern:**
```dart
class AgeTicker extends ValueNotifier<int> {
  AgeTicker() : super(0) {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => value++);
  }
  Timer? _timer;
  @override void dispose() { _timer?.cancel(); super.dispose(); }
}
```
Provide it via a small `InheritedNotifier` above the grids/lists.

### 2.2 — Tab swipe: don't rebuild on every animation frame
**File:** `orders_screen.dart` ~line 228  
**Issue:** `_onTabChanged` calls `setState()` on every animation frame during tab swipe.  
**Fix:** Only rebuild when `!_tabs.indexIsChanging`.

### 2.3 — Menu search: debounce + memoize
**File:** `menu_management_screen.dart` ~line 184 (and ~270)  
**Issue:** Every keystroke triggers `setState()` → full re-filter of all menu items + category chip count recomputation (O(n×categories) per keystroke).  
**Fix:**  
1. Debounce search input by 250ms before `setState`.  
2. Pre-compute `searchText` per item in a memo map (like `_CounterMode` already does).  
3. Pre-compute category counts once when `menuItems` identity changes, not per build.  
4. Use `ValueListenableBuilder` for the search field so only the list rebuilds, not the whole screen.

### 2.4 — Inventory table: replace eager Column with lazy ListView
**File:** `inventory_screen.dart` ~line 552  
**Issue:** `for (var i = 0; i < items.length; i++) _StockRow(...)` inside a `Column` — all rows always in widget tree. 200+ rows = 200+ widgets built per frame.  
**Fix:** Use `ListView.builder` (or `CustomScrollView` + `SliverList`) with the header as `SliverPersistentHeader`. Only visible rows build.

### 2.5 — Orders: reduce closure allocation in builder
**File:** `orders_screen.dart` ~line 910  
**Issue:** 4-5 new closures created per card per rebuild.  
**Fix:** Pass `orders[i]` and callbacks as direct references where possible, or use `ValueKey` on the card and let the card's `State` cache the closures in `didUpdateWidget`.

### 2.6 — `TfMenuPerfTable`: remove shrinkWrap
**File:** `tf_design_system.dart` ~line 3400  
**Issue:** `shrinkWrap: true` + `NeverScrollableScrollPhysics` defeats lazy building.  
**Fix:** Replace with `CustomScrollView` + `SliverList` or a plain `Column` with `.map()` (since the table is already inside a scrollable parent).

---

## Phase 3: Compute Caching (MEDIUM IMPACT, LOW RISK)

### 3.1 — Cache `metrics` getter
**File:** `app_controller.dart` ~line 845  
**Issue:** `metrics` iterates `orders` 4+ times and `menuItems` 2 times on every access. Called from build methods → runs on every rebuild.  
**Fix:** Cache `DashboardMetrics` and invalidate when `orders` or `menuItems` change:
```dart
DashboardMetrics? _cachedMetrics;
DashboardMetrics get metrics {
  if (_cachedMetrics == null) _cachedMetrics = _computeMetrics();
  return _cachedMetrics!;
}
void _invalidateMetrics() { _cachedMetrics = null; }
```
Call `_invalidateMetrics()` in `reloadData()` and any mutation that affects orders/menu.

### 3.2 — Cache `categories` / `inventoryCategories`
**File:** `app_controller.dart` ~line 880  
**Issue:** New `Set` + `toList()` + `sort()` on every getter access.  
**Fix:** Same pattern as metrics — cache and invalidate on `menuItems`/`inventoryItems` change.

### 3.3 — Cache `TfMoney` RegExp + default TextStyle
**File:** `tf_design_system.dart` ~line 560  
**Issue:** New `RegExp` allocated on every `TfMoney.build()`.  
**Fix:** Make `static final RegExp _groupRegex = RegExp(...)` and `static const TextStyle _defaultStyle = TextStyle(...)`.

### 3.4 — Optimize `tfToBnNumbers`
**File:** `tf_design_system.dart` ~line 110  
**Issue:** 10 sequential `replaceAll` calls = 10 intermediate strings.  
**Fix:** Single `replaceAllMapped` with a `Map`:
```dart
static final Map<String,String> _bn = {'0':'০', ...};
String tfToBnNumbers(String s) => s.replaceAllMapped(RegExp(r'[0-9]'), (m) => _bn[m[0]]!);
```

### 3.5 — Cache locale lookups in `TfText` family
**File:** `tf_design_system.dart` ~line 265+  
**Issue:** Each `TfText` does 4 `tfIsBn(context)` calls (each an InheritedWidget lookup). 100+ widgets per screen = 400+ lookups per frame.  
**Fix:** Create a single `LocaleInherited` widget that pre-computes `isBn`, `fontFamily`, `strutStyle`, and `textHeightBehavior` once per locale change. All `Tf*` widgets read from this single widget.  
**Impact:** Eliminates ~400 inherited lookups per screen per frame.

### 3.6 — Cache inventory fold/where computations
**File:** `inventory_screen.dart` ~line 240  
**Issue:** `fold<double>(0, ...)` and `.where(...).length` run on every build.  
**Fix:** Cache alongside the existing sort memoization, invalidating when items identity changes.

### 3.7 — Cache analytics chart data
**File:** `analytics_screen.dart` ~line 1050  
**Issue:** List comprehensions from `widget.trend` + date parsing on every build.  
**Fix:** Cache `values` and `labels` in `didUpdateWidget`, only recompute when `trend` or `_metric` changes.

---

## Phase 4: Data Loading & Sync (MEDIUM IMPACT, MEDIUM RISK)

### 4.1 — Parallelize `reloadData()`
**File:** `app_controller.dart` ~line 1190  
**Issue:** 7 sequential awaits for independent collections.  
**Fix:** Use `Future.wait` for parallel loading.

### 4.2 — Selective reload on DB changes
**File:** `app_controller.dart` ~line 1465, `local_database_service.dart`  
**Issue:** DB change stream carries no table info → `reloadData()` re-fetches all 7 collections every time.  
**Fix:** Add table name to the change stream event. `reloadData({String? onlyTable})` reloads only the affected collection.  
**Impact:** Single menu toggle no longer re-fetches all orders + inventory + notifications.

### 4.3 — Batch sync push
**File:** `sync_service.dart` ~line 280  
**Issue:** 120 pending events pushed sequentially (120 HTTP requests). At 300ms/RTT = 36s blocking.  
**Fix:** Parallelize small batches with `Future.wait` (e.g., 5 concurrent). Or add a backend batch endpoint.  
**Quick win:** `Future.wait` with concurrency pool of 5.

### 4.4 — Wrap cloud pull imports in single transaction
**File:** `sync_service.dart` ~line 300-340  
**Issue:** Each `applyRemote*` call opens a separate transaction. 500 orders = 500 transactions.  
**Fix:** Add batch methods like `database.applyRemoteOrdersBatch(List<OrderModel>)` that use one transaction.

### 4.5 — Skip redundant cloud pulls when realtime is connected
**File:** `sync_service.dart` ~line 300  
**Issue:** 5 HTTP GETs every 30s regardless of realtime WS state.  
**Fix:** If realtime channel is connected and active, increase pull interval to 5 min or skip entirely.

### 4.6 — Add `limit` to `getInventoryItems` and `getNotifications`
**File:** `local_database_service.dart`  
**Issue:** Both return full table with no limit.  
**Fix:** Add `limit` parameter (default 500 for inventory, 200 for notifications).

### 4.7 — Add missing DB indexes
**File:** `local_database_service.dart` ~line 1630  
**Issue:** Missing: `order_items.menuItemId`, `orders.createdAt` standalone, `menu_items.deletedAt` partial.  
**Fix:** Add to the `onCreate`/`onUpgrade` migration.

### 4.8 — Batch menu item lookups in `createOrder`/`updateOrderItems`
**File:** `local_database_service.dart` ~line 520, ~770  
**Issue:** N+1 lookup — one `SELECT` per requested item inside the transaction.  
**Fix:** Single `SELECT ... WHERE id IN (...)` before the loop, build a `Map<String, MenuItem>`.

---

## Phase 5: Memory & Resource (MEDIUM IMPACT, LOW RISK)

### 5.1 — Cap `notifications` list
**File:** `app_controller.dart` ~line 700  
**Issue:** Unbounded list growth.  
**Fix:** Limit `getNotifications(limit: 200)` and prune old read notifications.

### 5.2 — Add `_loadPopularity()` cache TTL
**File:** `app_controller.dart`  
**Issue:** Fires cloud API on every `reloadData()`.  
**Fix:** Cache for 5 minutes; only re-fetch if expired.

### 5.3 — Add `runZonedGuardedExceptions` in `main.dart`
**File:** `main.dart`  
**Issue:** Uncaught async errors silently swallowed in release.  
**Fix:** Wrap `runApp` in `runZonedGuardedExceptions`.

### 5.4 — Process sync payloads in smaller batches
**File:** `sync_service.dart` ~line 300  
**Issue:** All pulled payloads (500 orders + items + menu + inventory) held in memory simultaneously.  
**Fix:** Process in chunks of 100, releasing references after each batch is applied.

---

## Phase 6: infra / polish (LOW IMPACT, LOW RISK)

### 6.1 — Reduce double `notifyListeners()` in async loaders
**File:** `app_controller.dart` (`_runBusy`, `refreshDashboardSummary`, `refreshInventorySummary`, `loadMoreOrders`)  
**Issue:** Two notifications per async op (loading start + end).  
**Fix:** Optionally use `ValueNotifier<bool>` for loading state, or coalesce notifications.

### 6.2 — Add HTTP retry in `_sendJson`
**File:** `cloud_api_service.dart` ~line 2330  
**Issue:** No retry for transient 5xx/timeouts.  
**Fix:** 1-2 quick retries with exponential backoff.

### 6.3 — Fix `_OrderList` TabBarView children eager construction
**File:** `orders_screen.dart` ~line 860  
**Issue:** Both tab children widget descriptors created every rebuild.  
**Fix:** Use `TabBarView.builder` or cache the children.

### 6.4 — Use `ListView.builder` in `_PendingOrderDetailSheet`
**File:** `orders_screen.dart` ~line 2170  
**Issue:** All order item rows built eagerly inside DraggableScrollableSheet.  
**Fix:** `ListView.builder` with `itemCount: order.items.length`.

---

## Execution Order (Recommended)

| Step | Phase | Effort | Impact |
|------|-------|--------|--------|
| 1 | 1.1 — Remove root ListenableBuilder | 1h | 🔴 Critical |
| 2 | 1.2 — Migrate AppScope.of → select in hot screens | 3h | 🔴 Critical |
| 3 | 2.1 — Scope 30s timer rebuild | 2h | 🟠 High |
| 4 | 2.3 — Debounce + memoize menu search | 2h | 🟠 High |
| 5 | 2.4 — Inventory lazy ListView | 1h | 🟠 High |
| 6 | 3.1 — Cache metrics getter | 30min | 🟠 High |
| 7 | 3.5 — Locale lookup caching | 2h | 🟡 Medium |
| 8 | 4.1 — Parallelize reloadData | 30min | 🟡 Medium |
| 9 | 4.2 — Selective DB reload | 2h | 🟡 Medium |
| 10 | 4.3 — Batch sync push | 2h | 🟡 Medium |
| 11 | 4.4 — Single transaction batch import | 1h | 🟡 Medium |
| 12 | 3.3-3.4 — TfMoney RegExp + tfToBnNumbers | 30min | 🟡 Medium |
| 13 | 4.7 — Missing DB indexes | 30min | 🟡 Medium |
| 14 | 4.8 — Batch menu lookups in createOrder | 1h | 🟡 Medium |
| 15 | 5.1-5.4 — Memory caps + TTL | 1h | 🟡 Medium |
| 16 | 2.2 — Tab swipe fix | 15min | 🟢 Low |
| 17 | 6.1-6.4 — Polish items | 2h | 🟢 Low |

**Total estimated effort:** ~20h for all phases.  
**Phase 1 alone (steps 1-2) would address the biggest perf win** — eliminating full-app rebuilds on every controller notification.