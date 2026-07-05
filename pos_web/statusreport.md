# QuickBytes POS Web — STATUS REPORT & BUILD CONTEXT

> Read this top-to-bottom before working on `pos_web/`. Update it at the end of EVERY phase.
> Last updated: 2026-07-05 (Phase C COMPLETE — root-domain launch, /landing marketing site, self-service signup)

## What this product is

A browser-based desktop POS for QuickBytes restaurants (Bangladesh), replacing the abandoned
Flutter `desktop_app/` (deleted in commit `191e382`). React 18 + Vite 5 + TypeScript, served by
nginx directly at the **root domain** `https://quickbytes.buzz/` — same static-`root`+
`try_files` pattern as `platform_admin` (`/admin/`) and the marketing site (`/landing/`, see
`QuickBytes_Landing_Page/`). Unauthenticated visitors to `/` are redirected client-side to
`/landing/`; `/login` and `/signup` are in-app screens `pos_web` serves itself (not gated behind
a session), linked to from the marketing site's nav/CTAs.

**Design source of truth = the pictures** in `admin_app/context_pictures/petpooja13..23.png`
(Petpooja Windows POS screenshots). NOT any DESIGN.md. Exactly ONE substitution:
**Petpooja red (#E23744 family) → QuickBytes blue `#2F4FE0`** (`--primary` in
`src/tokens.css`). Navy `#1E2A44` secondary, green success, yellow occupied/running — all
copied from the pictures unchanged.

**Functionality = what the QuickBytes system supports** (mobile `admin_app` behavior +
existing backend API), NOT everything visible in the Petpooja pictures.

### OMIT — these Petpooja features are out of scope (product decisions)
KDS · Zomato/Swiggy channels · customers DB · loyalty / virtual wallet · expenses ·
delivery boys · LED display · cash top-up · waiter devices · BOGO offers · sales returns
(use audit refund instead) · advance/memo orders · veg/non-veg markers · any camera/scanning
feature (menu OCR, receipt OCR).

### Locked decisions
| Topic | Decision |
|---|---|
| Stack | React 18, Vite 5, TypeScript, zustand, idb. No UI framework — hand-rolled CSS from the pictures. |
| Hosting | Built into `backend/pos_dist/` (`bash backend/build_pos.sh`, Vite `base: '/'`); nginx serves that dir directly at the root domain (`deploy/nginx/quickbytes.conf`) — FastAPI has no pos_web serving code, it's already synced by `deploy/redeploy.sh`'s whole-repo rsync. |
| Printing | **WebUSB + Web Bluetooth ESC/POS direct from the browser** (no local helper). Tickets rendered on canvas → 1-bit raster → `GS v 0` — same bitmap philosophy as the Flutter apps (Bengali-safe). `window.print()` HTML ticket = universal fallback. Templates: `printer.txt` at repo root. |
| Offline | IndexedDB caches (menu/settings/orders) + mutation outbox with replay. Idempotency keys: order `id` (client UUID), KOT `batchId`, settle `eventId` — all natively supported by the backend. localStorage: session, lang, printer prefs, favorites. |
| Auth | All roles (owner/manager/waiter). Username/password (`POST /admin/login` — requires `serverId`!) or phone OTP. NO Google Sign-In. Session = `AuthPayload` JSON in localStorage `qbpos.session`; deviceToken is a 365-day outlet JWT used as Bearer on every call. |
| Currency/lang | ৳ BDT; EN + বাংলা toggle (localStorage `qbpos.lang`; `src/i18n/strings.ts`). Payment methods: cash, card, bkash, nagad, pay_later. |
| Order lifecycle | pending → accepted → completed; rejected removes. Legacy statuses (`served`→completed etc.) normalize at read time. |

## Picture → screen map
| Picture | Screen | Status |
|---|---|---|
| petpooja13/14 | Billing (category rail, item grid, search + short-code, cart, service tabs, payment radios, Save/Save&Print/KOT/KOT&Print/Hold, Settle & Save, favorites) | ✅ Phase 1 |
| petpooja15 | Table View (zones, dashed vacant tiles, legend, +Add Table, online-order Accept/Reject + accept modal) | ✅ Phase 2 |
| petpooja16 | Operations hub icon grid (subset: Printers, Day End, Shift) | ✅ Phase 1/3 |
| petpooja17 | Day-end report cards | ✅ Phase 3 |
| petpooja18/19/20 | Dashboard — live "money-first + right now" tower | ✅ Phase B1 |
| petpooja10/18 | Analytics report — Sales Breakdown + Item-wise (+ charts) | ✅ Phase B1 |
| petpooja11 | Tax Summary — range-scoped (net sales · VAT rate · tax collected), print/CSV | ✅ Phase B1 |
| (hub) | Reports — order buckets (success/cancelled/comp) + item performance | ✅ Phase B1 |
| petpooja12 | Menu bulk management (no channel toggles) | ✅ Phase B2 |
| petpooja21/22/23 | Inventory — stock hub (CRUD, stock-in/usage/waste/count) + daily report (no PO approvals, no scan) — **owner-only** | ✅ Phase B3 |

## Backend API map (all existing — zero backend API changes needed for v1)
Base = same origin in prod; dev uses `VITE_API_BASE`. Bearer = deviceToken. Envelope: `{data, error}`.

- Auth: `POST /admin/login {usernameOrEmail, password, serverId}` → AuthPayload; `POST /admin/phone/send-otp {phone}` / `verify-otp {phone, code}` → `{status:'login', login: AuthPayload}`; `POST /admin/demo/manager-login` (dev-gated); `GET /admin/access` (subscription).
- Menu: `GET /outlets/{o}/menu` — items with `_en/_bn`, tags (options `option:Name:delta`, addons `addon:price:Name`, sizes `size:Name:price`, icon, discount). Short code is a top-level int field `shortCode` (confirmed Phase 1), NOT a tag.
- Orders: `GET /outlets/{o}/orders?since=`; `POST /outlets/{o}/orders` (client-generated `id`); `PATCH .../orders/{id}/status|/items|/` .
- POS: `GET/PATCH /outlets/{o}/pos/settings` (floorLayout/vat/serviceCharge/discountPresets/dailySalesTarget); `GET .../pos/shifts/current`; `POST .../pos/shifts/open`, `.../shifts/{id}/close`; `POST .../pos/orders/{id}/kot` (batchId); `POST .../pos/orders/{id}/settle` (split lines, eventId idempotent, server re-validates totals — 422 on mismatch, 409 if shift closed); `POST .../pos/orders/{id}/audit` (void/refund/comp, manager+); `GET .../pos/reports?days=`.
- Realtime: `WS /ws/{outlet_id}?token=` — JSON events + `{type:'ping'}` keepalive. Reconnect w/ capped backoff (see `admin_app/lib/src/services/cloud_realtime_service.dart` for the reference impl).
- Phase B: `GET /outlets/{o}/analytics`, `/dashboard/summary`, `/analytics/sales-table`, `/reports/performance`, `/reports/order-buckets`, `/menu/popularity`, inventory summary/daily-report.

## Printing notes (Phase 1)
- Render KOT/receipt/day-end per `printer.txt` templates on an offscreen canvas at 384 dots
  (58mm) or 576 dots (80mm) wide — mirror `admin_app/lib/src/services/ticket_bitmap.dart`.
- ESC/POS envelope: `ESC @` init → raster `GS v 0` chunks → feed → `GS V` cut → optional
  `ESC p` drawer kick. Reference encoder: admin_app printer_service uses esc_pos_utils_plus
  the same way (raster-only, no text commands — keeps Bengali correct).
- **WebUSB caveat (accepted risk):** Windows binds `usbprint.sys` to many USB thermal
  printers, which blocks WebUSB claiming. Field fix: one-time WinUSB driver swap via Zadig.
  Web Bluetooth works only with BLE-capable printers (not classic-SPP-only). HTTPS or
  localhost required for both APIs; Chrome/Edge only.
- Printer prefs (chosen devices, paper width, KOT vs bill role) in localStorage.

## Phase log

### ✅ Phase 0 — scaffold + auth shell (2026-07-04)
- Committed legacy Flutter desktop_app deletion (`191e382`).
- Created `pos_web/`: Vite+React+TS scaffold, `src/tokens.css` (design tokens + shared
  primitives — the red→blue substitution lives here), self-hosted fonts (Plus Jakarta Sans,
  Hind Siliguri, NotoSansBengali TTFs copied from admin_app), `src/i18n/strings.ts` (EN/BN),
  `src/api/types.ts` + `src/api/client.ts` (typed endpoints incl. all v1 mutations),
  `src/state/session.ts` (zustand + localStorage), Login screen (password + OTP + dev demo),
  Shell with petpooja13-style top bar skeleton + nav (billing/tables/orders/ops placeholders),
  subscription-blocked gate, offline banner (navigator.onLine).
- Backend: `POS_DIST` mounts + `/pos/*` SPA catch-all in `backend/main.py`;
  `backend/build_pos.sh`; pos_web step in `deploy/redeploy.sh`.
- Verified: `npm run build` (tsc + vite) green; `python3 -m py_compile backend/main.py` green.

### ✅ Phase 1 — billing + printing (2026-07-05)
Billing screen per petpooja13/14 + the full browser printing stack.
- **Core money/menu logic** (`src/core/money.ts`, `core/tags.ts`, `state/menu.ts`,
  `state/cart.ts`, `state/pos.ts`): totals = subtotal + VAT + service charge + delivery −
  discount (percent/flat/fixed, clamped ≥ 0), `formatTk` (৳, lakh grouping), tag decoding
  (options/addons/sizes/includes/icon/discount), favorites (localStorage), held drafts,
  order create (client UUID, source `desktop_pos`, status `accepted`) / KOT (batchId) /
  settle (eventId) via the existing API.
  - **Short code** confirmed = top-level `MenuItem.shortCode` (int), NOT a tag. Extracted
    `matchShortCode(items, input)` (digits-only, available-only) — unit tested.
- **Billing screen** (`screens/Billing.tsx` + `billing.css`): 3-column grid (category rail w/
  Favorite Items · item grid w/ search + short-code Enter · cart pane), service tabs
  (Dine In → table modal, Delivery → address/phone sheet, Pick Up), qty steppers,
  CustomizeModal (size/option/addon), discount modal (presets from pos settings),
  dark payment strip (cash/card/bkash/nagad/pay_later + Split), actions Save / Save & Print /
  KOT / KOT & Print / Hold / Settle & Save, held-orders modal, shift-open gate modal.
- **Printing** (`src/print/*`): `escpos.ts` raster encoder (canvas → 1-bit threshold →
  `GS v 0` bands + init/feed/cut/drawer-kick), `ticketRenderer.ts` (canvas KOT / receipt /
  test-ticket painters, 384/576 dots, Bengali via canvas fonts), `webusb.ts` (bulk-out,
  16KB chunks), `webbluetooth.ts` (BLE GATT, 180B chunks), `printManager.ts` (per-role
  bill/KOT prefs in localStorage + `window.print()` fallback), `PrinterSettings.tsx` in Ops.
- **Ops hub** (`screens/Ops.tsx`): petpooja16-style tile grid — Printers pane live; shift
  status tile; Day End / Sync tiles stubbed for later phases.
- **Tests** (vitest, 24 passing): money math, ESC/POS encoder bytes, short-code matcher.
- Verified: `tsc --noEmit` clean, `vitest run` 24/24 green, `npm run build` green
  (198 KB JS / 63 KB gzip), fonts copied into `pos_dist/fonts/`.
- Carry-over: tables/orders nav still placeholder (Phase 2); item-tile edge is neutral,
  blue when in cart (veg markers dropped, per plan).

### ✅ Phase 2 — table view + orders + realtime (2026-07-05)
petpooja15 Table View + Orders list + the realtime socket.
- **Nav store** (`state/nav.ts`): section routing lifted out of Shell so Tables/Orders can
  route into Billing after prepping the cart (tap vacant → dine-in + table prefilled; tap
  occupied → `cart.loadOrder`; Delivery / Pick Up quick-starts; top-bar New Order clears cart).
- **Realtime** (`api/ws.ts`): reconnecting WebSocket (exponential backoff, jitter, ping/pong
  keepalive). Any order/kot/settle event → `orders.refresh` (server wins, no trust in body).
  Top-bar shows a live/reconnecting dot.
- **Orders store** (`state/orders.ts`): recent-orders cache + pure derivations
  (`pendingOnline`, `ongoingOrders`, `completedOrders`, `occupiedTables`, `tableStateOf`),
  online accept/reject, and **void** = manager audit event + status→rejected (mirrors the
  mobile `app_controller` flow — audit endpoint alone does NOT change status). New online
  orders bump an unseen badge + play a WebAudio chime.
- **Table View** (`screens/Tables.tsx`): zone sections from `pos.settings.floorLayout`, live
  tiles (vacant dashed / running blue / running-KOT amber / paid green) with running amount +
  elapsed, online-order rail (Accept modal w/ prep-time stepper + optional KOT print / Reject),
  legend, and a **floor-layout editor** behind + Add Table (add/rename/remove zones & tables →
  PATCH pos settings → reload).
- **Orders** (`screens/Orders.tsx`): Ongoing / Completed tabs, Open-to-edit, receipt Reprint,
  manager-only Void with reason modal.
- **Shell**: boots menu + pos + orders and opens the socket on session; badge clears on Tables.
- **Tests** (vitest, 29 passing total; +5 for order derivations). tsc clean, build green
  (214 KB JS / 67 KB gzip).
- Notes: `updateOrderDetails({prepMinutes})` on accept is best-effort (advisory, non-blocking).
  "Paid" tile state is rare in our lifecycle (settle completes the order → table frees).

### ✅ Phase 3 — shift + day-end (2026-07-05)
petpooja17 Day-End + full shift open/close with cash counting.
- **DenominationCounter** (`components/DenominationCounter.tsx`): BDT note/coin grid
  (1000…1) with live total; shared by open and close.
- **ShiftModal** (`components/ShiftModal.tsx`): open (opening float) / close (counted
  drawer). Billing's inline shift-open modal was replaced by this shared component, so
  opening a shift now captures denominations everywhere. Close sends counted cash; the
  backend computes expected/variance and returns the closed shift.
- **Day-End** (`screens/DayEnd.tsx`): card grid from `/pos/reports?days=1` — Success
  Orders (sales + count), Covers, Voided, Complimentary, Sales Returns (from
  `auditCounts` void/comp/refund), Expected Drawer. Panels: payment split
  (`paymentSplit`, lowercase method keys), cash drawer (opening float + cash taken →
  expected; counted + variance after close), top items. Printable via **renderDayEnd**
  (new ESC/POS template).
- **Ops hub**: Printers / Day End / Shift tiles now route (Day End + Shift → Day-End pane).
- Verified against backend: `close_shift` sets expected/counted/variance; report
  `paymentSplit` keyed by lowercase payment_method; `auditCounts` keyed by action.
- 29 tests still green; tsc clean; build green (221 KB JS / 69 KB gzip).

### ✅ Phase 4 — offline outbox hardening (2026-07-05)
IndexedDB cache + mutation outbox so the core FOH loop survives a network blip.
- **`offline/db.ts`**: `idb`-backed store — a `kv` cache (menu / settings / shift /
  orders snapshots, keyed by `type:outletId`) and an autoincrement `outbox` store.
  All helpers are best-effort (swallow + no-op if IDB is unavailable).
- **`offline/outbox.ts`** (pure, unit-tested): op union (createOrder / updateOrderItems /
  updateOrderStatus / sendKot / settleOrder / auditOrder), `enqueue` (idempotent per key),
  `dispatch`, `classifyError` (offline/5xx/408/429 = transient; 4xx = permanent), and
  `replayOutbox` — FIFO, **stops at the first transient failure to preserve ordering**,
  **dead-letters permanent failures** so the rest drains. Decoupled via `OutboxStore` /
  `OutboxApi` interfaces (tested with in-memory fakes).
- **`state/sync.ts`**: owns the IDB outbox + real api, exposes `queued` / `dead` /
  `replaying`, `enqueue`, `flush(outletId)` (replay → refetch orders to reconcile),
  `discardDead`.
- **Boot hydration**: menu/pos/orders `load()` are now network-first with an IDB fallback
  and write-through, so an offline boot still paints the menu, floor and open orders.
- **Optimistic writes**: `cart.saveOrder / sendKot / settle` catch offline/5xx, enqueue the
  op (reusing the existing idempotency keys: order UUID, KOT batchId, settle by order id),
  and apply the result locally so billing/KOT/settle keep working offline. (accept/reject/
  void stay online-only — they act on orders that only arrive over the network anyway, and
  it avoids an orders↔sync import cycle.)
- **Triggers**: flush on `online` event, on WS (re)connect, and on boot (drains a prior
  offline session). Top bar shows a "⇅ N" queued chip + a "⚠ N" failed chip (→ Operations);
  Ops has a Sync tile + dead-letter list with Retry / Discard.
- **Tests** (vitest, 36 passing total; +7 outbox engine). tsc clean; build green
  (230 KB JS / 72 KB gzip incl. idb).
- Manual test still owed: kill the network in DevTools mid-KOT/settle, confirm queue +
  replay-on-reconnect (needs the deployed API / a browser).

### ✅ Phase B1 — dashboard + analytics/reports + tax (2026-07-05)
Owner/manager back-office, wired as **Ops-hub sub-panes** (gated `role==='owner'||'manager'`).
- **Charts** are hand-rolled inline SVG (no chart lib — honors the "no UI framework" rule):
  `components/charts/{AreaTrend,BarChart,Donut,Sparkline}.tsx` over a pure, unit-tested
  `charts/geometry.ts` (`buildLine`/`seriesMax`/`donutSegments`/`ringArc`), sized via
  `useElementWidth`. `components/PeriodPicker.tsx` (Today/7d/30d/custom → `range`).
- **`screens/Dashboard.tsx`** ← `GET /dashboard/summary` (`moneyFirst`+`rightNow`): KPI cards
  (earned today +Δ%, orders, avg ticket, profit %), 7-day sparkline, service-mix donut,
  top movers, right-now (tables/kitchen/late) + needs-attention.
- **`screens/Analytics.tsx`** ← `GET /analytics/summary` + PeriodPicker. Sales Breakdown tab
  (KPI strip, revenue↔orders AreaTrend, service-wise bars, collection donut, profit estimation,
  popular dishes) + Item-wise tab (category cards). **Tax Summary** panel (net sales · VAT rate
  from pos settings · `taxAndDuty`) with **Print** (`renderTaxSummary` painter) + CSV. Item CSV.
- **`screens/Reports.tsx`** ← `GET /reports/order-buckets` (success/cancelled/comp + payments)
  + `GET /reports/performance` (7/30/90-day item ranking, CSV).
- Note: `/analytics/summary` is the report admin_app actually ships; `/analytics` and
  `/analytics/sales-table` are unused there and were intentionally NOT used. No VAT/tax endpoint
  exists → Tax Summary is derived from real fields (not a fictional monthly report).
- `core/csv.ts` (pure), shared `screens/backoffice.css` + `components/StatCard.tsx`.

### ✅ Phase B2 — menu bulk management (2026-07-05)
petpooja12 in-scope part (no channel toggles, no multi-restaurant push).
- **`screens/MenuManage.tsx`**: category sidebar w/ counts, name/short-code search,
  inline-editable rows (name · short code · category · price · availability toggle), bulk
  select → Mark available/unavailable + Bulk discount, delete. **`components/MenuItemModal.tsx`**
  add/edit form (core fields + Advanced: description/includes/options/add-ons → `tags`).
- Writes: `state/menu.ts` gains `saveItem`/`saveMany`/`deleteItem` → `api.pushMenuItem`
  (POST upsert) / `api.deleteMenuItem`. **Full-replacement payloads** built by pure
  `core/menuPayload.ts` (`mergeMenuPayload` preserves shortCode/tags/isFavorite, bumps version)
  + `core/tags.ts` `buildTags` (inverse of `parseExtras`). Online-only for v1.
- **i18n:** Phase B panes are English-only, matching the sibling operational screens
  (DayEnd/Ops/PrinterSettings). Not routed through `t()` (follow-up if BN is wanted).
- **Tests** (vitest, 57 passing total; +21: chart geometry, CSV, menu payload-merge, tag
  round-trip). tsc clean; build green (265 KB JS / 81 KB gzip, 35 KB CSS — no new deps).
- Manual smoke still owed: exercise the panes against the deployed API in a browser
  (manager login) — period switching, tax print/CSV, menu edit round-trip.

### Phase B3 — inventory (raw materials / stock / purchase / wastage / daily report) — ✅ DONE
**Owner-only** (backend `routers/inventory.py` is `owner_only=True` on every endpoint → the
Ops tile + pane gate on `session.role === 'owner'`, not `isManager`). Built the in-scope subset
(OMIT PO approvals, receipt OCR scan, marketplace/supplier-hub, Pending-PO cards):
- `screens/Inventory.tsx` — tabbed **Stock** / **Daily report** pane.
  - **Stock** (petpooja21/22): stat strip (stock value · alerts · variance today · materials),
    `PeriodPicker` flow window, category chips (from summary), item table (status dot · today
    in/out/net · on-hand vs min · spend) with per-row **Stock-in / Count / Edit / Delete**.
  - **Daily report** (petpooja22/23): business-date picker; unexplained-variance/stock-flow
    KPIs; revenue-split `Donut`; top sellers; reorder-before-noon; variance breakdown table.
- Data: `fetchInventorySummary` (hub) + `pullInventory` (raw items for edit + suppliers) run in
  parallel in `state/inventory.ts` (network-first, IDB-cached summary/items). `fetchInventoryDailyReport`.
- Writes (online-only): `pushInventoryItem` (full-replacement upsert via `mergeInventoryPayload`,
  quantity preserved on edit — stock changes go through adjustments), `deleteInventoryItem`,
  `postInventoryAdjustment` (restock/usage/waste; signed `delta` via `adjustmentDelta`),
  `postDailyStockCount` (absolute qty on BDT business date via `todayBdtDate`).
- Modals: `InventoryItemModal` (CRUD), `StockAdjustModal` (segmented restock/usage/waste/count).
- `core/inventory.ts` pure helpers + `core/inventory.test.ts` (10 tests): delta signing, BDT
  date, net movement, summary flow-window mapping, payload merge.
- **Tests**: 67 passing total (+10). tsc clean; build green (287 KB JS / 86 KB gzip — no new deps).
- OWED (same as B1/B2): manual browser smoke against deployed API with an **owner** login —
  add/edit/delete a material, stock-in with cost (confirm cost/unit recompute), usage & waste,
  an end-of-day count (confirm variance surfaces), and the daily-report date switch. Suppliers:
  list + add wired (`saveInventorySupplier`); no supplier management screen (out of scope).

---

### ✅ Phase C — root-domain launch + self-service signup (2026-07-05)
Flipped the public routing: `pos_web` now owns the root domain as the actual product;
`QuickBytes_Landing_Page` (marketing) moved to `/landing/`. This **supersedes** the Phase 0
note above about FastAPI serving `/pos/*` — that mount never actually worked in prod (nginx's
old `/pos/` alias pointed at an empty `pos_admin/` dir and shadowed it) and has been removed.
- **`vite.config.ts`**: `base: '/pos/'` → `base: '/'`; `src/tokens.css` self-hosted font URLs
  `/pos/fonts/...` → `/fonts/...` to match (a build-time-only bug the font-warning at build
  would have masked — vite build now warning-free).
- **nginx** (`deploy/nginx/quickbytes.conf`): new `/landing/` alias block (same filesystem path
  as before, `landing/dist/templates/landing-page/`, so `redeploy.sh`'s landing rsync step is
  unchanged); root `location /` now serves `backend/pos_dist` directly (already rsynced by the
  whole-repo sync — no new deploy step needed); old `/pos/` alias → `301 /`; `/get` → `/landing/`.
- **`backend/main.py`**: removed the dead `POS_DIST` mounts/catch-all (nginx serves it directly
  now, same as `platform_admin`/landing which never had FastAPI serving code either).
- **Auth**: added self-service restaurant signup — `screens/Signup.tsx` chains
  `POST /tenants/bootstrap` (client generates a short human-copyable Server ID via
  `crypto.getRandomValues`, not a raw UUID) → `POST /admin/create` (role `owner`) →
  `POST /admin/login`, then shows the Server ID once (copy button) before entering the
  dashboard — it's the same value required for every future sign-in, no other way to recover
  it. `App.tsx` now does simple `window.location.pathname` branching (no router): unauthed `/`
  → redirect to `/landing/`; `/login` and `/signup` render outside the session gate either way.
  `Login.tsx`/`Signup.tsx` cross-link to each other.
- Landing page nav/hero/pricing/CTA-band CTAs now point at `/login` and `/signup` instead of
  `#download` (the native-app download cards further down the page are untouched/still valid).
- Tests unchanged at 67/67 green; `tsc --noEmit` + `npm run build` clean.

**Core POS (Phases 0–4) + back-office B1/B2/B3 + Phase C (root launch/signup) complete.**

## Dev workflow
```bash
cd pos_web
npm install
VITE_API_BASE=https://quickbytes.buzz npm run dev   # dev against prod API (use demo login only in local dev backend)
npm run typecheck && npm test && npm run build       # build outputs to ../backend/pos_dist
python3 -m py_compile backend/main.py                # after backend edits
```
No local Postgres in this dev env — backend can't run here; smoke-test against the deployed
API. Real printer tests require the user's Windows counter PC (Chrome, USB thermal).
