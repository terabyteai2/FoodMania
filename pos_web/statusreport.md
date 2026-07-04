# QuickBytes POS Web — STATUS REPORT & BUILD CONTEXT

> Read this top-to-bottom before working on `pos_web/`. Update it at the end of EVERY phase.
> Last updated: 2026-07-04 (Phase 0 complete)

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
| petpooja13/14 | Billing (category rail, item grid, search + short-code, cart, service tabs, payment radios, Save/Save&Print/KOT/KOT&Print/Hold, Settle & Save, favorites) | Phase 1 — TODO |
| petpooja15 | Table View (zones, dashed vacant tiles, legend, +Add Table, online-order Accept/Reject + accept modal) | Phase 2 — TODO |
| petpooja16 | Operations hub icon grid (subset) | Phase 2/3 — TODO |
| petpooja17 | Day-end report cards | Phase 3 — TODO |
| petpooja10/18/19/20 | Analytics dashboards | Phase B (later) |
| petpooja11 | VAT report w/ print/download | Phase B |
| petpooja12 | Menu bulk management (no channel toggles) | Phase B |
| petpooja21/22/23 | Inventory (no PO approvals, no scan) | Phase B |

## Backend API map (all existing — zero backend API changes needed for v1)
Base = same origin in prod; dev uses `VITE_API_BASE`. Bearer = deviceToken. Envelope: `{data, error}`.

- Auth: `POST /admin/login {usernameOrEmail, password, serverId}` → AuthPayload; `POST /admin/phone/send-otp {phone}` / `verify-otp {phone, code}` → `{status:'login', login: AuthPayload}`; `POST /admin/demo/manager-login` (dev-gated); `GET /admin/access` (subscription).
- Menu: `GET /outlets/{o}/menu` — items with `_en/_bn`, tags (options `option:Name:delta`, addons `addon:price:Name`, sizes `size:Name:price`, icon, discount; short code lives in tags — verify exact key in Phase 1 against `admin_app/lib/src/models/menu_item.dart`).
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

### ⏭ Phase 1 — billing + printing (NEXT)
Billing screen per petpooja13/14 + full printing module. See task list. Open items to
resolve at start: exact short-code tag key in menu tags; item-tile left-edge color policy
(veg markers dropped → use neutral edge, blue when in cart).

### Phase 2 — table view + orders + realtime — TODO
### Phase 3 — shift + day-end — TODO
### Phase 4 — offline outbox hardening — TODO
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
