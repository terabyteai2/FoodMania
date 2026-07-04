# QuickBytes POS Web — STATUS REPORT & BUILD CONTEXT

> Read this top-to-bottom before working on `pos_web/`. Update it at the end of EVERY phase.
> Last updated: 2026-07-05 (Phase 4 complete — core POS done)

## What this product is

A browser-based desktop POS for QuickBytes restaurants (Bangladesh), replacing the abandoned
Flutter `desktop_app/` (deleted in commit `191e382`). React 18 + Vite 5 + TypeScript, served
by the existing FastAPI backend at `https://quickbytes.buzz/pos/` — same pattern as the
customer menu SPA (`customer_menu/frontend` → `backend/frontend_dist` → `/menu/*`).

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
| Hosting | Built into `backend/pos_dist/` (`bash backend/build_pos.sh`); FastAPI serves `/pos/*` (see `backend/main.py` POS_DIST block). Deploys via `deploy/redeploy.sh` (pos_web step added). |
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
| petpooja10/18/19/20 | Analytics dashboards | Phase B (later) |
| petpooja11 | VAT report w/ print/download | Phase B |
| petpooja12 | Menu bulk management (no channel toggles) | Phase B |
| petpooja21/22/23 | Inventory (no PO approvals, no scan) | Phase B |

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

---

**Core POS (Phases 0–4) is complete.** Remaining work is Phase B (back-office).

### Phase B — back-office (menu/inventory/analytics/reports) — LATER

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
