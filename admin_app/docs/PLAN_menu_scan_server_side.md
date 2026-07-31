# PLAN — Menu Scan: server-side import + per-image WS notifications

Status: **IMPLEMENTED + VERIFIED 2026-08-01** (backend tests pass on VPS; app
analyzer clean, test suite identical to baseline). Scope rule: ONLY `admin_app/` + `backend/`.

## Final decision (user, after plan approval): **pure fire-and-forget**
- The app ignores the HTTP response entirely — no completion notification, no
  final sync. Sync happens ONLY via per-image `menu_scan_progress` WS events.
- `scanMenuPages` → `Future<void>` (no `MenuScanImportSummary` — nothing to parse).
- Request-level failures still surface as a failure notification (a rejected
  upload would otherwise emit zero WS events).

## Goal
Menu scan moves from "server returns candidates, app imports locally" to "server
scans, inserts into DB, and pushes a per-image notification to the Flutter client".
The app never creates scanned items locally — it just shows the notification and
syncs (pull) to find the items already installed.

## Confirmed decisions
- Backend endpoint keeps **multi-image upload** (all images, ≤6, same validation).
- Images go through the existing OCR→LLM trip **sequentially** per image
  (`scan_single_image_with_dedup` = 2 independent OCR→LLM trips per image — unchanged).
- Items are inserted into `menu_items` **by the backend**, not the app.
- After each image's insert+commit, the backend **broadcasts over the outlet WS**
  (`manager.broadcast(outlet_id, ...)`, room = `/ws/{outlet_id}`):
  `{"type": "menu_scan_progress", "data": {pageIndex, totalPages, createdCount, skippedDuplicateCount}}`
- Flutter client on that event: shows a `PosNotification` (system → menu) and fires
  `_syncWithFreshTenantToken()` (pull) — all while the HTTP request still processes
  the remaining images.
- WS-down fallback: none beyond request-level failure notifications — per the
  pure fire-and-forget decision, the app never parses the scan response.
- Duplicate policy: **skip** candidates matching an existing item
  (key = `normalize(nameEn)|normalize(categoryEn or "General")`, normalize =
  strip+lower+collapse `\s+`→` `; mirrors the removed Dart `_menuScanDuplicateKey`).
- Per-image scan failure (`MenuScanError`): log + broadcast progress event with
  error detail, continue to next image; 422 for the whole request only if
  validation fails up front.
- Scan screen UX: **fire-and-forget** — screen pops immediately after launching the
  pipeline; per-image notifications arrive progressively in the background.

## File-by-file changes

### backend/routers/menu.py (`scan_menu_pages`)
- Keep multi-file contract + size/count/image validation as-is.
- Add `import re`; helpers `_scan_duplicate_key(name, category)` and
  `_scan_item_tags(item)` (tag parity with Dart `MenuItemExtras.toTags()`:
  `icon:<key>`, `inc:<text>`, `addon:<price>:<name>`, `option:<name>:<delta>`;
  int string when price/delta is whole else 2dp).
- Loop pages sequentially (original structure): scan → resolve placeholder URLs →
  dedupe vs `select(MenuItem).where(outlet_id)` seen-key set → insert `MenuItem`
  (id uuid, bilingual fields, category default "General", price, is_available,
  image_url, tags_json, short_code via `_next_short_code`, version 1,
  updated_at=now) → collect rows.
- Single commit; per row `manager.broadcast(outlet_id, {"type": "menu_updated", ...})`
  (realtime parity) — keep cheap; then per-image `menu_scan_progress` broadcast with
  pageIndex/totalPages/createdCount/skippedDuplicateCount.
- Return `ok({"createdCount": N, "skippedDuplicateCount": M, "totalPages": P})`.

### backend/tests/test_menu_scan.py
- `test_menu_scan_route_accepts_manager_access_variants`: assert 200 + response
  counts (`createdCount == 1`) + item row exists in DB.
- `test_menu_scan_route_hands_multiple_images_to_ocr`: real DB session (bootstrap
  tenant like the variant test) instead of `fake_db` yielding `object()`;
  assert both images hit OCR and 2 rows inserted + response counts + WS broadcast
  captured via monkeypatched `manager.broadcast`.
- `test_menu_scan_route_rejects_too_many_images` / `rejects_oversized_image`: unchanged.

### admin_app/lib/src/services/cloud_api_service.dart ✅
- `scanMenuPages(List<MenuScanPageUpload>) → Future<void>`: multi-file multipart
  POST (`/outlets/{o}/menu/scan`), timeout 180s → **15 min**, non-2xx →
  `CloudApiException`. Response body is never parsed.
- **Deleted**: `MenuScanSubItem`, `MenuScanAddOn`, `MenuScanSizeVariant`,
  `MenuScanCandidate` (+ `_text`/`_splitBilingual`), `MenuScanResult`.
  **Kept** `MenuScanPageUpload` (stock-scan flow uses it).

### admin_app/lib/src/services/sync_service.dart ✅
- `_handleCloudRealtimeEvent`: new `menu_scan_progress` case → forward to
  `_onRemoteEvent` + log (no DB apply).

### admin_app/lib/src/app_controller.dart ✅
- `_handleRemoteSyncEvent`: `menu_scan_progress` case → parse
  pageIndex/totalPages/createdCount/error → `addNotification(type: system,
  actionTarget: 'menu', ...)` (error variant when the page failed) +
  `unawaited(_syncWithFreshTenantToken())`.
- `scanAndImportMenu` → `Future<void>` fire-and-forget: guard `canSync` →
  configure cloud → `await scanMenuPages(pages)`; failure → failure notification.
  Success does nothing (WS events drive everything).
- **Deleted**: `MenuScanImportResult`, `_menuScanDuplicateKey`, local import loop.

### admin_app/lib/src/features/menu/menu_scan_screen.dart ✅
- Removed `onScan` param + `ScanningProgressOverlay` blocking path.
- `_scanAll`: pops immediately with `Navigator.pop(context, uploads)`.

### Call sites (push → pop with uploads → `unawaited(scanAndImportMenu(uploads))`) ✅
- `menu_management_screen.dart` `_scanMenu`: simplified; `_scanBusy` removed
  (incl. the inline `ScanningProgress` section + disabled-button ternary).
- `app.dart` `_navigateOnboardingMenuScan`: simplified; onboarding overlay
  usage removed (`_showScanOverlay` stays — other screens still use it).
- `tenant_setup_screen.dart` `_scanNow`: push → launch unawaited → `_finish()`;
  "Menu scanned!" snackbar removed.

### admin_app/lib/src/core/localization/app_strings.dart ✅
- Added `menuScanPageDone(page,total,count)` + `menuScanPageFailed(page,total)`
  (EN + বাংলা). **Deleted** now-unused `menuScanImported`, `menuScanning`,
  `menuScanningWait`, `menuScanningShort`.

### admin_app/lib/src/core/widgets/scanning_progress.dart ✅ DELETED
- `ScanningProgress`/`ScanningProgressOverlay` had zero remaining users.

### admin_app/test/menu_scan_ui_test.dart ✅
- Deleted the `MenuScanResult.fromJson` test + unused cloud_api_service import;
  other tests untouched.

## Verify — RESULTS
- Backend: `python3 -m py_compile backend/routers/menu.py` ✅. Ran
  `pytest tests/test_menu_scan.py` **on the VPS** (160.187.130.80, prod DB):
  **19 passed** ✅ (fixed 2 pre-existing test bugs along the way: hex-suffix
  phone pattern, stale `images[0].items` assertion). VPS files restored to the
  original after testing; `rastarant` service never restarted.
- App: `flutter analyze lib test` ✅ (only pre-existing baseline: 1 unused
  `goTarget` warning + broken `messages_screen_test.dart`).
  `flutter test` ✅ — 88 passed / 15 failed, **identical to the git-stashed
  baseline run** (15 pre-existing failures; zero regressions).
- Baseline note: the 15 failures (control_tower, inventory_design,
  inventory_workflow_screens, tenant-setup table-count test, etc.) all fail on
  clean `main` too.
