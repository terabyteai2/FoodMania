# QuickBytes Desktop POS (Windows)

A focused Flutter **Windows** register that clones the **Petpooja desktop** UX
(blue brand) while reusing the mobile app's proven backend logic. See
`DESIGN_DESKTOP.md` for the visual spec (measured from
`../admin_app/context_pictures/petpooja13–17.png`).

## Architecture — reuse, don't duplicate
`desktop_app` depends on `admin_app` as a local package
(`local_pos: { path: ../admin_app }`) and reuses its **entire domain + data +
controller layer** via `package:local_pos/src/...`:

- Models, `CloudApiService` (REST), `LocalDatabaseService` (SQLite + FFI),
  `CloudRealtimeService` (WS), `SyncService`, `AppStrings` (EN + বাংলা),
  `PosAppController` (all business logic), `AppScope`, and the `PosColors` tokens.

Only the **UI** and the **Windows runner native code** are new. All new code
lives under `lib/desktop/`:

| Area | Path |
|---|---|
| Entry + boot (FFI, controller, login gate) | `lib/main.dart`, `lib/desktop/app/` |
| Shell (top bar + rail + nav) | `lib/desktop/shell/` |
| Billing (3-pane register) | `lib/desktop/billing/` |
| Tables / FOH | `lib/desktop/tables/` |
| Orders | `lib/desktop/orders/` |
| Menu management | `lib/desktop/menu/` |
| Day-End / shift + Z-report | `lib/desktop/dayend/` |
| Inventory | `lib/desktop/inventory/` |
| Analytics | `lib/desktop/analytics/` |
| Settings / Staff / Audit / Messages | `lib/desktop/{settings,staff,audit,messaging}/` |
| Printing channels (USB + Bluetooth) | `lib/desktop/printing/`, `windows/runner/` |
| Theme tokens + metrics | `lib/desktop/theme/` |

## Features (Phases 0–9)
Register-shift based POS: open the register → build tickets (category rail +
item grid + search/short-code + modifiers) → **KOT / KOT & Print / Settle &
Save** (Dine-in / Delivery / Pick-up); Tables/FOH floor with online-order
accept/reject; Orders (Ongoing/Completed lifecycle); Menu CRUD + availability;
Day-End with cash denominations + Z-report; Inventory (stock-in / usage / low
stock); Analytics (sales / collection / service-wise / profit / popular);
Settings (printer setup, language, logout), Staff, Audit, Messenger inbox.

**Out of scope (by design):** KDS, camera/menu-scan, receipt-scan.

## Running (Windows)
```powershell
cd desktop_app
flutter run -d windows      # or: flutter build windows
```
Sign in with the outlet's **Server ID** + an admin **email/username + password**
(`POST /admin/login`). Configure the receipt printer under **Settings**.

## Printing
- **USB / any Windows-driver thermal printer** — works via the native
  spooler-RAW channel (`com.terabyteai.foodmania/windows_printer`) ported into
  `windows/runner/flutter_window.cpp` + the reused raster ESC/POS pipeline.
- **Bluetooth (SPP/RFCOMM)** — `windows/runner/bt_printer.cpp` (C++/WinRT).
  ⚠ **Needs on-Windows verification**: this native half was authored without an
  MSVC/Windows SDK and an actual printer. Confirm the printer is Bluetooth
  **Classic/SPP** (not BLE) and re-check STA threading (see the header comment
  in `bt_printer.cpp`). Dart side + Settings UI are complete and analyzer-clean.

## Verification status
- `flutter analyze` → **clean**; `flutter test` → passing.
- `flutter build linux --debug` compiles the **entire Dart graph** to kernel
  (my code + the reused `local_pos` package); it only fails at the final native
  **linker** because of a snap-Flutter glibc/gstreamer mismatch in this headless
  Linux env — irrelevant to the Windows target.
- **Not verifiable here (needs Windows):** first boot, live login, real printing,
  and the Phase-9 Bluetooth native channel.

## Notable scope decisions
- No standalone "Operations hub" launcher — the left rail already navigates and
  the hub's unique tiles (Cash Flow / Expense / Withdrawal) are unconfirmed
  backend / out of scope.
- Billing creates one order per terminal action; appending items to an existing
  running order and "Hold/resume" tickets are follow-ups (edit an occupied table
  via the Tables sheet to KOT/settle it).
