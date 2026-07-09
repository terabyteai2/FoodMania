# QuickBytes Desktop — Design Reset Reference (authoritative)

> ✅ **This is the authoritative desktop design truth.** It **supersedes**
> `DESIGN_DESKTOP.md` (now historical — to be re-derived from this file).
> When this doc and `DESIGN_DESKTOP.md` disagree, **this doc wins.**
>
> **Scope:** the design-reset baseline for `desktop_app` (`quickbytes_desktop`, the
> Flutter Windows POS that reuses `admin_app` via the `local_pos` path dep). UI lives
> under `desktop_app/lib/desktop/`; tokens in `lib/desktop/theme/desk_theme.dart`.
>
> **This is a capture/reference doc, not an implementation.** No `lib/desktop/` code
> changes are implied by this file existing — the actual reset is a later effort.

## 0. Provenance of the reference screens
The user supplied ~14 reference screens (2026-07-09) as **inline visual context**, split
into two kinds:
- **Raw PetPooja captures** — the real product; they define *functional & layout* truth.
- **Polished redesign mockups** — cleaned-up "consumeristic" target frames; they define
  the *visual endpoint* the reset moves toward (rounded cards, softer tiles, channel toggles).

The raw PNG bytes were **not** available as files, so this doc stores a detailed **written
catalog** instead. To archive the literal images, drop them into
`admin_app/context_pictures/` at the next free slots (**`petpooja24…petpooja37`**, the
convention both surfaces already use) and the per-screen `PNG:` lines below become live
references. Until then those slots are **placeholders**.

## 1. Invariants carried forward (unchanged by the reset)
These hold regardless of the new visual direction:
- **The one substitution** — Petpooja **red `~#E23744`** (primary CTAs, active tabs, active
  category, steppers, selected radios) → **blue `PosColors.primary #2F4FE0`**.
- **Semantic colors** — green = KOT-printed / paid; **yellow** = occupied zone/table; red is
  **destructive-only** (reject / void / delete).
- **Currency ৳ BDT.** PetPooja's ₹ / GST / Home-Tax / Zomato·Swiggy specifics are Indian; adapt
  per the existing localization discipline (local tax vocabulary, local/native channel names)
  rather than copying them literally.
- **Bilingual EN + বাংলা** via reused `AppStrings` (Plus Jakarta Sans EN / Hind Siliguri ·
  Noto Sans Bengali). Money is tabular.
- **Tokens only** — every visual value is a `DeskMetrics` / `PosColors` / `PosShadows` token;
  no raw literals in feature code.
- **No veg/non-veg markers, no KDS, no camera/scan** surfaces.
- **NULL-safe** — missing metrics are **hidden, never zero-filled**.

## 1a. Data-model binding (source of truth for entities & enums)
The reset borrows PetPooja's *visual language* only — never its Indian data vocabulary.
The **canonical data model** is `admin_app/context/data_model.txt` +
`admin_app/context/current_status_report.txt` (**ignore** `admin_app/context/DESIGN.md`).
`desktop_app` already reuses these exact models via the `local_pos` path dep, so every
screen must bind to the real entities/enums and their own localized labels — no hardcoded
PetPooja strings. Canonical enums (EN + বাংলা via each enum's `localized(isBn)`):
- **OrderServiceType** — `dineIn`='Dine-in', `takeaway`=**'Parcel'** ('পার্সেল'), `delivery`='Delivery'.
  There is **no "Pick Up"**.
- **OrderPaymentMethod** — `cash · card · bkash · nagad · payLater`. **Not** Zomato/Swiggy/
  Wallet/Due/Other/Part.
- **OrderStatus** — lifecycle `pending → accepted → completed`; `rejected` voids. Legacy
  `preparing/ready → accepted`, `served → completed`, `cancelled → rejected` (read-time only).
- **OrderSource** — `localLan · cloud · facebookMessenger · desktopPos · manual`. "Online sales"
  = website storefront + Facebook Messenger (the only channels that carry customer identity) —
  **not** Zomato/Swiggy.
- **AdjustmentType** — `restock · usage · waste · correction`; `InventoryItem.isLowStock/isOutOfStock`.
- **InventoryUnits** — `kg · g · L · mL · pcs`.
- **Money** — ৳ **BDT**, integer-ish (via `theme/desk_format.dart money()`). Tax = **VAT**
  (`pos_vat_rate_percent`) + **service charge** (`pos_service_charge_percent`); not GST/Home Tax.
- **NULL-safe** — advanced metrics with no data return null and the card is **hidden**, never
  zero-filled; no forced customer form in FOH (dine-in/parcel/counter).

## 1b. Chrome — collapsible sidebar nav (reset rule)
The main navigation is a **collapsible left sidebar**, not a fixed rail. **Expanded**
= icon + label (width ≈ `DeskMetrics.railWidth`); **collapsed** = icons-only (narrow),
with a toggle to switch. Active item keeps the `primarySoft` fill + `primary` icon/label
treatment; outlet chip on top, account·role footer at the bottom. This **supersedes** the
"fixed left rail" wording in `DESIGN_DESKTOP.md §1`. On the **Billing** screen the sidebar
still yields to the category list as before. (Applies to `shell/desk_shell.dart`.)

## 2. Screen catalog

### 2A. Raw PetPooja captures (functional / layout truth)

**R1 — Billing web dashboard (overview)**  ·  PNG: `petpooja24` (placeholder)
- *Layout:* header (wordmark · outlet picker · Marketplace CTA · alerts/settings), sync-status
  line ("Order synced … POS synced …"), a date-scoped control (date pill + refresh). Main:
  a **row of 4 KPI cards** — Total Sales / Dine In / Take Away / Delivery, each = amount +
  order count + trend icon + overflow menu. Below: a **sales bar chart**. Right column:
  Price Discovery, Order Free Samples, Supplier Hub promo cards.
- *Data:* per-service sales & order counts; daily sales bars.
- *Drives:* `analytics/analytics_screen.dart` (KPI row + service split) — top of the desktop
  Analytics dashboard. Sync line → `shell` status affordance.

**R2 — Billing dashboard (orders + marketplace band)**  ·  PNG: `petpooja25` (placeholder)
- *Layout:* summary tiles (No. of Orders · Total Sales · Zomato · Swiggy · Other), a
  **combined line+bar sales chart** with a hover tooltip (per-channel Amt & Count), a
  **Marketplace** panel (Easy Operations / Customer Acquisition / Restaurant Marketing /
  Loan — each a "N Services" row), and date-scoped **Discount / Total Sales / Taxes** cards.
- *Data:* order count, channel-split sales, tax totals (GST / Home Tax chips).
- *Drives:* `analytics/analytics_screen.dart` (channel-split chart + tax summary). The
  Marketplace band is **out of scope** (Petpooja upsell) — drop per existing discipline.

**R3 — Billing dashboard (payment split + revenue leakage)**  ·  PNG: `petpooja26` (placeholder)
- *Layout:* sales chart, a **Discount bar chart** (Total Discount headline), a **Total Sales
  breakdown** list (Cash / Card / Wallet / Due Payment / Other / Online Paid / Online COD —
  each a labelled progress bar + amount), **Taxes / GST / Home Tax** card, and a **Revenue
  Leakage** card.
- *Data:* payment-mode split, discount-over-time, tax lines, leakage.
- *Drives:* `analytics/analytics_screen.dart` (payment-mode split + discount trend). Map tax/
  leakage to ৳ BDT vocabulary.

**R4 — Outlets Statistics**  ·  PNG: `petpooja27` (placeholder)
- *Layout:* "All Outlets" scope; a **row of stat tiles** (Cash Collection / Online Sales /
  Taxes / Discounts — each amount + a "% of total" context line), an Offers rail, then two
  tables: **Zone-Wise Statistics** and **Outlet-Wise Statistics** with columns *Orders · Sales ·
  Net Sales · Tax · Discount · Modified · Re-Printed · Waived Off · Round Off · Charges* and a
  **Total** row; per-row overflow menu; sortable headers.
- *Data:* per-zone / per-outlet order + money aggregates.
- *Drives:* `analytics/analytics_screen.dart` (multi-outlet stats tables + tiles). Single-outlet
  installs collapse the zone/outlet grouping.

**R5 — Inventory dashboard**  ·  PNG: `petpooja28` (placeholder)
- *Layout:* **Key Statistics** card (Purchase / Wastage + a period filter), **COGS** card
  ("Worth of Stock Consumed" headline + a per-item bar), a **New Purchase** empty-state card,
  an auto-consumption toggle row, **Pending Purchases** (count of POs) + **Pending PO Approvals**
  cards, and a **Stock Level** section. Right rail of quick actions (Purchase Order / Stock
  Purchase / Sales / Wastage / Stock).
- *Data:* purchase/wastage totals, COGS, pending POs, stock levels.
- *Drives:* `inventory/inventory_screen.dart` (stat cards + stock/COGS content). Use
  Prep-Cost / Wastage / COGS / stock-value / low-stock vocabulary; hide absent metrics.

**R6 — Raw Materials Management list**  ·  PNG: `petpooja29` (placeholder)
- *Layout:* breadcrumb + action row (**Add New Raw Material** primary · Action ▾ · Import ▾ ·
  Export ▾), a filter row (Name field + Category dropdown + Search / Show All / Save / Copy),
  then a **data table**: *Name · Category · Favorite · Available · Created · Created By · Action*
  with inline row controls (favorite checkbox, available checkbox, delete/edit/copy icons) and a
  "Showing X of Y records" footer.
- *Data:* raw-material master list.
- *Drives:* `inventory/inventory_screen.dart` + `inventory/inventory_item_form.dart` (list +
  add/edit). Row action icons map to edit / delete / duplicate flows.

**R7 — Day-End / order-summary cards (native desktop)**  ·  PNG: `petpooja30` (placeholder)
- *Layout:* a **grid of summary cards** — Success Orders · Cancelled · Complimentary · Sales
  Return · Success Advance · Memo Advance · Order Payment Details · Payment Information · Cash
  Payment Modes — each = amount + "No. of orders" + drill arrow. Bottom-right **Next** CTA.
- *Data:* end-of-day order + payment tallies.
- *Drives:* `dayend/day_end_screen.dart` (summary card grid → `Next` into Z-report /
  denominations via `dayend/denomination_grid.dart`).

**R8 — Operations hub grid**  ·  PNG: `petpooja31` (placeholder)
- *Layout:* header (Operations / Main Server / Master Billing Station + support contacts), then
  a **responsive grid of ~26 feature tiles** (icon + label): Orders · Extra Information History ·
  Online Orders · KOTs · Customers · Cash Flow · Expense · Withdrawal · Cash Top-Up · Inventory ·
  Notification · Table · Virtual Wallet · Manual Sync · Help · Live View · Due Payment · Language
  Profiles · Billing User Profile · Currency Conversion · Day End · Day End History · Waiter
  Devices · Feedback · Delivery Boys · LED Display. Active/hover tile = `primary` outline.
- *Drives:* the desktop **Operations hub** (`shell/desk_shell.dart` + `shell/desk_nav.dart`).
  Render **only supported tiles** (Orders, Online Orders, KOTs, Table, Inventory, Day End,
  Day-End History, Notifications, Language, Settings, Staff, Audit) — drop the rest.

**R9 — Delivery-accept dialog over Table View**  ·  PNG: `petpooja32` (placeholder)
- *Layout:* a **modal** for an incoming online order (channel header + order id + item list)
  with **Minimum Delivery Time** and **Preparation Time** stepper fields, action row
  *Save · Save & Print · Save & EBill · KOT · KOT & Print*. Behind it: **Table View** — zone
  sections of **square** table tiles (AC1…AC20, Garden…), header controls *Delivery · Pick Up ·
  + Add Table* + legend (Printed / Paid / Running-KOT).
- *Drives:* `tables/tables_screen.dart` (floor + zones + legend) and the accept modal →
  `tables/table_order_sheet.dart`. Tap vacant → new order; tap occupied → edit.

**R10 — Order-build / billing (favorites + settle)**  ·  PNG: `petpooja33` (placeholder)
- *Layout:* the **3-pane register** — left **category rail** (expandable "Beverages ▾",
  "Favorite Items", Indian / Mocktails / Cocktails / Soft Drinks); center **item pane**
  (Search + Short Code fields, a **blue-wash "Favourite Items" panel** with heart-marked cards,
  then a card grid); right **checkout** (item rows with `− qty +` steppers + line price,
  **Total**, `Bogo Offer` · `Split`, payment radios *Cash · Card · Due · Other · Part*,
  **Settlement Amount** field + **Settle & Save**, `It's Paid`, footer *Save · Save & Print ·
  Save & eBill · Cancel*).
- *Drives:* `billing/billing_screen.dart` (+ `cart_line.dart`, `item_customizer.dart`,
  `settle_dialog.dart` / `settle_flow.dart`). Favourites panel = blue-wash per invariant.

**R11 — Order-build / billing (full-screen, KOT + loyalty)**  ·  PNG: `petpooja34` (placeholder)
- *Layout:* same register maximized; top **order-type tabs** *Dine In | Delivery | Pick Up*
  (active = `primary`), identity tag ("AC4") + zone chip, cart rows, **Total**, payment radios,
  toggles *It's Paid · Loyalty · Virtual Wallet*, footer *Save · Save & Print · Save & eBill ·
  KOT · KOT & Print · Hold*.
- *Drives:* `billing/billing_screen.dart` full-screen state; `open_shift_dialog.dart` gating;
  KOT actions → `sendDesktopKot` / print flows.

### 2B. Polished redesign mockups (the "consumeristic" visual target)

**M1 — Push all menu items + Update prices in channels**  ·  PNG: `petpooja35` (placeholder)
- *Layout:* two **rounded cards** on a warm/cream field — left **"Push all menu items"**
  (restaurant checkboxes All / West / North / South, Cancel + **Save Changes** primary CTA);
  right **"Update prices in channels"** (per-channel **toggles**: Zomato · Swiggy · Dine-in ·
  Delivery). Below, an outlet-scoped **menu table**: *Item Name · Short Code · Category · Price*
  where **Price shows the new value with the old value struck through** (e.g. `125 ~~110~~`),
  row checkboxes + category dropdowns.
- *Target styling:* large radius cards, soft fills, pill toggles, clear price-diff affordance.
- *Drives:* `menu/menu_screen.dart` + `menu/menu_item_form.dart` (bulk push + per-channel
  availability/pricing). Adapt channel set to local/native channels; ৳ pricing.
- **⚠ Deferred (needs data model):** `MenuItem` today has no per-channel availability,
  no multi-restaurant push, and no previous/compare price — so the channel toggles, the
  "push to restaurants" card, and the struck-through old→new price are **not built yet**
  (NULL-safe: don't fabricate). The reset so far applies only the soft-card table framing;
  the distinctive M1 controls require backend/model work first.

**M2 — Consolidated Tax Report**  ·  PNG: `petpooja36` (placeholder)
- *Layout:* a header card (doc icon + **"Consolidated Tax Report (period)"** + **Print** /
  **Download** primary CTA), then a **Tax Report** table per outlet: *Months · Sales · Taxable
  Amt · Per(%) · Total Tax*, with a **Non Taxable Amount** callout and a bold **Grand Total**.
- *Target styling:* light-tinted panel, generous row spacing, bold totals row.
- *Drives:* `analytics/analytics_screen.dart` (or a Day-End report tab). Adapt GST → local tax
  vocabulary; ৳ BDT; hide months with no data.

**M3 — Online-sales + virtual-outlet analytics**  ·  PNG: `petpooja37` (placeholder)
- *Layout:* a **4-card analytics cluster** on a tinted field — **Track of Online sales** (donut:
  Home Website / Zomato / Swiggy), **Virtual outlet sales & order count** (line chart across
  outlets + Order-Count / Total-Sales legend), **YOY sales on festivals** (year bars + count/
  sales callout), **Virtual outlet Average ticket size** (horizontal bars per outlet).
- *Target styling:* soft rounded cards, muted category palette, chart-first hierarchy.
- *Drives:* `analytics/analytics_screen.dart` (online-sales + per-outlet analytics section).
  Follow the **dataviz** conventions; NULL-safe series (hide empty, never zero-fill). Adapt
  channel names.

## 3. Reset direction (summary)
The **raw captures (R1–R11)** fix *what data and controls each screen carries* and the
proven 3-pane register / floor / hub / day-end structure. The **polished mockups (M1–M3)**
fix *how it should look* after the reset — larger-radius cards, softer tiles, pill toggles,
explicit price-diff affordances, chart-first analytics. The reset moves the current
`lib/desktop/` screens toward that visual language **while preserving every invariant in §1**
(blue substitution, semantic colors, ৳ BDT, bilingual, tokens-only, no veg/KDS, NULL-safe).
Implementation is a separate future effort; this file is the reference it should build from.
