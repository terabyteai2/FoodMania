# QuickBytes POS — Design System v2

> A restaurant POS for the **Bangladesh** market. Two clearly separated influences:
>
> 1. **Visual UI/UX language → cloned from Petpooja** (the leading Indian POS): soft rounded white cards, pastel state fills, underline tabs, circular FAB, and — importantly — **Petpooja's information density** (packed panels, dense tables, tile grids) on the terminal/FOH and desktop back-office. **One deliberate change: the brand/primary color is a calm royal-indigo BLUE instead of Petpooja's crimson red.**
> 2. **Analytics & reporting CONTENT → modeled on QuicklyServices** (the leading BD POS), *not* Petpooja. No food-aggregator dependencies (Zomato/Swiggy), no GST/tax-report screens, no AOV/cohort/LTV jargon. The metrics are the simple, locally-understood vocabulary BD restaurateurs already read: Gross Sales, Discounts, Net Sales, Collection, Prep Cost, Wastage, Gross Profit, Popular Dishes, Service-wise Sales.
>
> **Two surfaces, one token set:**
> - **Mobile** — Android-first portrait phone (≈ 410×880). The primary floor surface for waiters/managers.
> - **PC / Desktop** — two desktop contexts, both detailed in Part C: a **fast billing/POS workstation** (cashier/counter) and a **web back-office** (owner dashboards, reports, menu/inventory/staff/settings). **Both mimic Petpooja's information density** — packed panels, dense tables, tile grids, every function visible — recolored to blue. We adopt Petpooja's function, layout grouping, *and* density; we don't thin it out.
>
> Currency **৳ Taka**. Demo brand **"Spice Garden", Dhanmondi**. Two literacy tiers (English-comfortable owners; Bangla-leaning managers/waiters → icons + বাংলা toggle + short labels).

---

## PART A — VISUAL UI/UX (Petpooja clone, blue-primary)

### 1. Core visual rules (read first)

1. **Blue is primary.** `--primary #2F4FE0` (royal-indigo) = brand + main call-to-action: Confirm Order, KOT & print, FAB, active tab underline, selected radios, primary links, chart lead series. One primary action per screen.
2. **Navy is the secondary action.** `--ink-btn #1E2A44` — calm dark counterpart. Paired footers run **navy (secondary) + blue (primary)**, e.g. *Save & print* / *KOT & print*.
3. **Green only for success.** `--success #1E9E5A` — payment success, available status, healthy stock, positive money figures. Never a primary action, never decorative.
4. **Pastel fills carry states**, never hard saturated blocks. Soft tint + darker ink label.
5. **Soft rounded cards.** Radius 12–16 on cards/tiles/buttons; pill only on chips/toggles. Friendly Petpooja feel.
6b. **Match Petpooja's density, don't fight it.** Pack panels, stat cards, charts, and tiles the way Petpooja does — multiple cards per row, charts side-by-side, dense sortable tables, every function visible. Whitespace is *not* a goal here; throughput and "everything one click away" are. (Mobile back-office instead follows QuicklyServices' density — stat-card grids + accordions + lists.)
6. **White surfaces, hairline dividers, light shadows.** Cards sit on `--bg` with a soft low shadow + 1px light border.
7. **Underline tabs, not pill segments.** Active = blue label + 2–3px blue underline; inactive = muted gray.
8. **Tabular money everywhere**, `৳` prefix, two decimals on bills, thousands separators (৳1,18,674.00 style acceptable; comma-grouping fine).
9. **Touch targets ≥ 44×44** mobile. Buttons h48–52, FAB 56, list rows ≥ 56.
10. **Throughput over minimalism.** Surfaces should expose function and data the way the references do — Petpooja-dense on terminal + desktop back-office, QS-style stat grids on mobile back-office. Don't strip elements for the sake of "clean"; the operator wants everything reachable fast.

### 2. Color tokens

**Primary — blue ramp (royal-indigo)**
`50 #EEF1FE · 100 #DCE3FD · 200 #B9C7FB · 300 #8FA3F5 · 400 #5E74EC · 500 #2F4FE0 (primary) · 600 #2440C2 · 700 #1D339B · 800 #182A7D · 900 #131F5A`
Derived: `--primary #2F4FE0 · --primary-press #2440C2 · --primary-ink #FFFFFF · --primary-tint #EEF1FE (wash/selected/highlight) · --primary-strong #1D339B (blue text on white)`.

**Secondary — navy** `--ink-btn #1E2A44 · --ink-btn-press #15203A` (white text).

**Neutrals** `bg #F6F7F9 · surface #FFFFFF · surface-2 #F1F3F6 · surface-3 #E7EAEF · ink #1B2330 · ink-2 #5A6475 · muted #8A93A3 · placeholder #AAB2C0 · line #ECEEF2 · line-2 #DEE2E9`

**Signals** `success #1E9E5A / soft #E3F6EC · warning #C98208 / soft #FCF0D8 · danger #D8434A / soft #FBE5E6 · info = primary blue`.

> **Destructive = red, and red ONLY.** delete/void/reject use `--danger #D8434A`. Unlike Petpooja (red = everything), red here means "careful" exclusively, because blue owns primary. Minus/remove steppers use a neutral outline, not red.

**Table / order state fills (Petpooja pastels)**
`--state-running #DCEBFB / ink #2B5C9E (sky — running/seated)`
`--state-printed #E3F6EC / ink #1E7A47 (mint — bill printed)`
`--state-kot #FCF3CF / ink #9A7400 (amber — running KOT)`
`--state-available #FFFFFF / line --line-2 / ink --ink (vacant)`

**Analytics tile-icon tints** (soft circles behind stat icons, QS-style)
`tint-purple #EFEAFB / icon #7C5CD6 · tint-blue #E4EFFA / icon #2F6FB0 · tint-green #E6F6EC / icon #2E9E63 · tint-amber #FCF3CF / icon #9A7400 · tint-red #FBE5E6 / icon #C0454B`. Used purely to differentiate stat cards at a glance — never as status meaning.

**Channel hues (order feed)** counter `--ink-btn` navy · website/storefront `#2F4FE0` blue · messenger `#2F4FE0` · table-QR `#C98208` amber · waiter `#1E9E5A` green.

### 3. Typography — Inter

| Role | Size / Weight | Notes |
|---|---|---|
| Screen title (tab root) | 24 / 700 | mobile home titles |
| Screen title (pushed) | 20–22 / 700 | optional back arrow |
| Page title (desktop) | 26–28 / 700 | back-office headers |
| Money / token hero | 32–48 / 800 | payment total, net sales — tabular `-0.02em` |
| Stat-card number | 22–28 / 800 | dashboard tiles, tabular |
| Section (H2) | 15–16 / 700 | card titles, report section headers, area headers |
| Order serial (hero) | 18–20 / 800 | the `#016744` on order cards |
| Title (row/tile) | 14–15 / 600 | item / table / staff name |
| Price / money (row) | 14–17 / 700 | tabular, `৳` prefix |
| Body | 14 / 400 · Body-S 13 muted | report row labels |
| Label / status | 11–13 / 600 | pastel state labels, chips, badges |
| Tab label | 14–15 / 600 | active blue, inactive muted |
| Eyebrow | 11–12 / 700 · `0.05em` UPPER | "BYTES BOT", section kicker |

**Bangla:** every nav label, screen title, report section header, and high-traffic action ships EN + বাংলা (`makeT(lang)` → `t('key')`). Same Inter stack + system Bengali fallback; sizes/weights unchanged.

### 4. Shape · spacing · elevation

**Radius** `sm 8 · md 12 · lg 14 · xl 16 · pill 999 (chips, toggles, radio, FAB)`.
**Spacing** base-4. Mobile screen padding 16; desktop tighter (12–20). Card padding 12–16; tile gap 8–12; section gap 12–18. Pack content like the references — don't pad screens just to add whitespace.
**Elevation**
- `card`: `0 1px 2px rgba(20,25,40,.04), 0 2px 8px rgba(20,25,40,.05)` + 1px `--line`.
- `e3`: bottom sheets, dropdowns, detail popovers.
- `e-up`: sticky footer action bar `0 -2px 12px rgba(20,25,40,.06)`.
- `fab`: `0 8px 22px -6px rgba(47,79,224,.55)` (blue glow).

### 5. Components

- **Primary button** h48 (lg 52), radius `md`, 600, `--primary` fill + white. One per screen. Full-width on mobile footers.
- **Secondary (navy) button** same metrics, `--ink-btn` fill + white. Left half of a paired footer.
- **Paired footer** sticky, `e-up`, navy + blue side-by-side (Save & print / KOT & print). Mobile both `flex:1`; desktop fixed-width right-aligned.
- **Ghost / outline** white + 1px `--line-2` + ink text (Import, + Waiter, Cancel). Blue-outline + blue-text variant for View Invoice.
- **FAB** 56×56 circle, `--primary`, white icon, bottom-right, `fab` shadow, clears bottom nav. Lone bright element on list screens.
- **Tabs (underline)** active = `--primary-strong` text + 2–3px `--primary` underline; inactive `--muted`. Horizontal-scroll on mobile overflow.
- **Two-tab toggle (analytics)** rounded segmented control on `--surface-2`, active segment = white card + blue text (e.g. Sales Breakdown / Item Wise Sales). Used in reporting, not for nav.
- **Chip** h36, pill, 1px `--line-2`; active = `--primary` fill + white, or `--primary-tint` + `--primary-strong` for soft active. Shift/Terminal info chips = `--primary-tint` (non-interactive).
- **Card** `--surface`, radius `lg`, `card` elevation.
- **Stat card** (dashboard tile): soft tint circle + icon top-left, big tabular number, small muted label below, optional `›` drill-down chevron top-right. Mobile 2-col or 3-col grid; desktop 4-col.
- **Mini-stat row** 2–3 numbers side by side with vertical hairline dividers, label under each (COGS: Prep Cost | Wastage | Payment Fee).
- **Table tile (FOH)** square, radius `lg`, big centered number, fill by state (white / running / printed / kot). Grid: 3-col mobile, 5+ desktop, grouped under area headers.
- **Report section** white card, bold section header (Sales Summary / Collection Summary / Profit Estimation), then label-left value-right rows separated by hairlines. **Deductions in parentheses** `(৳1,156.00)`. Sub-items indented. Optional collapse chevron on the header (accordion).
- **Accordion section** header with `⌄`/`›` chevron; collapsed shows header only, expanded reveals rows. Used on mobile analytics to keep screens short.
- **Ranked list** (Popular Dishes / item-wise): plain rows, name-left amount-right, hairline dividers; category-subtotal header rows get `--surface-2` background. Sortable column headers with up/down arrows on desktop.
- **Zebra table** alternating `--surface` / `--surface-2` rows for dense date→amount lists.
- **Chart-metric toggle** radio pair under a chart (●Revenue ○ No of Orders), selected = blue radio.
- **List row** ≥ 56px, `--surface` + bottom `--line`, optional thumb/icon, trailing value or stepper.
- **Qty stepper** `[−] n [+]` — minus neutral outline, plus `--primary` (filled on cart), number tabular.
- **Radio / checkbox** circular radio (Cash/Card/Other), square checkbox (Print KOT in Kitchen); selected = `--primary`.
- **Toggle** pill, on = `--primary` (availability, online-delivery, EN/বাংলা).
- **Field / search** h48, radius `md`, white/`surface-2` + 1px `--line-2`, leading icon, focus = `--primary` ring. Flex inputs `min-width:0`.
- **Status pill** small tint+ink pill (Available green, Occupied muted, Completed green, Running blue).
- **Bottom sheet** radius `xl` top, grab handle, `e3` (modifiers, filters).
- **Notification dropdown** absolute under top bar, `e3`, color-coded icon rows + unread dots, routes on tap.
- **Chat bubble** customer neutral-left; bot/manager right — bot = `--primary-tint` + "BYTES BOT" label, manager = navy. Amber centered escalation banners.
- **Charts** blue lead series; area charts = blue stroke + `--primary-tint` fill; bars = blue gradient; donut = channel hues. Light gridlines, muted axis labels, hover tooltips (Petpooja-style multi-line tooltip listing channel amounts/counts). Pack several per dashboard.

**Desktop-specific components** (from the real Petpooja desktop product, restyled clean + blue):
- **Icon rail (desktop nav)** — narrow ~64px fixed left column, icon-only (no labels), `--surface`, 1px right `--line`. Active item = `--primary` icon + a 3px `--primary` left bar (or soft `--primary-tint` square behind the icon). Tooltip label on hover. Top = brand mark. This is the primary desktop navigation. (Petpooja uses a red rail; ours is blue.)
- **Desktop top bar** — brand mark (in rail or here) + **outlet/location dropdown** (e.g. "Spice Garden — Dhanmondi" / "All Outlets") on the left; right cluster = bell (badge) + Messages + share/link + settings gear + profile. Optional context pill (we do NOT use Petpooja's red "Marketplace" promo pill).
- **Stat card row (desktop)** — rows of 3–4+ cards (Total Sales / Dine-in / Takeaway / Delivery, then more), each: label top-left, small trend glyph top-right, big tabular number, sub-count ("6 Orders"), optional `⋮` overflow. White card, `card` elevation. **Pack multiple rows** of these like Petpooja's dashboard — density is expected.
- **Panel** — the desktop unit of content: white card, `lg` radius, bold panel title left, **its own date-range dropdown + refresh icon** in the panel header (each panel independently scoped), `ⓘ` info affordance where a number needs a plain-language caption. Charts, breakdowns, and tables each live in their own panel. **Lay panels side-by-side and stacked densely** (chart next to payment-breakdown next to taxes panel), Petpooja-dashboard-style.
- **Info caption** — small muted line under a stat with an `ⓘ`, explaining the figure in plain words ("72.77% of total sales collected via cash, excluding online orders"). Borrowed from Petpooja's Outlets-Statistics cards; great for the lower-literacy tier.
- **Payment-mode breakdown** — label-left, thin horizontal **progress bar** (filled = `--primary`, track = `--surface-3`), amount-right; one row per mode (Cash / Card / Wallet / Due / Other / Online). Calm, no gridlines.
- **Data table (desktop)** — multi-column table (e.g. Zone-wise / Outlet-wise: Orders, Sales, Net Sales, Tax, Discount, Modified, Re-Printed, Waived Off, Round Off, Charges). Sortable headers with up/down arrows, hairline row dividers, a bold **Total** row, `⋮` row overflow, sticky header on scroll. **Dense rows are fine** — pack columns Petpooja-style. (Note: column *content* still follows QS metrics; Petpooja-only columns like Round Off / Waived Off / Re-Printed are optional, not required.)
- **Operations tile grid** — the desktop "everything" launcher (Orders, KOTs, Customers, Cash Flow, Expense, Inventory, Table, Day End, Waiter Devices, etc.): line-icon + label tiles, white, `lg` radius, hover = `--primary-tint` wash + `--primary` icon. **Pack the grid Petpooja-style** (many tiles, tight gaps). Curate to functions QuickBytes actually has (drop Petpooja-only items like Currency Conversion, LED Display, Marketplace).
- **Report-launcher cards** — pale-`--primary-tint` header cards (Success Orders, Cancelled, Complimentary, Sales Return, Payment Information, …) each = title + big amount + "No of orders: N" + a `→` link to the detail. Restyled from Petpooja's blue report tiles.
- **Desktop billing layout (POS workstation)** — 3-column: **left** = category list (selected = `--primary-tint` row + left blue bar); **center** = item-tile grid (each tile has a **veg/non-veg colored left border** + heart-favorite toggle, tap-to-add); **right** = running-order panel with columns ITEMS / CHECK ITEMS / QTY / PRICE, ✕ remove, qty steppers, running **Total**, payment radios (Cash/Card/Due/Other/Part), Settlement Amount field, and an action cluster (Save · Save & Print · Save & eBill · KOT · KOT & Print · Hold). Order-type tabs **Dine In / Delivery / Pick Up** top-right. **Mimic Petpooja's terminal density** — tight rows, every action visible, fast — just in our blue instead of red.
- **Accept-order modal** — incoming-order dialog: channel header + serial, item list, Reject (ghost/red-text) / Accept (blue), and on accept a small modal with Min Delivery Time / Prep Time steppers + Save / Save & Print / KOT / KOT & Print.

**Mobile**
- **Top bar** — left: hamburger/back + screen title (brand mark + location on home). Right: notifications bell (unread badge) + Messages action (escalation badge) + overflow ⋮. No page-nav buttons up here.
- **Bottom tab bar** — ≤ 5 tabs, active = `--primary` icon+label with soft `--primary-tint` pill behind icon, pending badge on Orders. Localized labels.
- **Side drawer (hamburger)** — profile + logout at top, then grouped nav with leading icons and `›` for groups (pattern borrowed from QS drawer; styled in our blue).
- **FAB** for the main create action.

**Desktop / PC**

QuickBytes has **two desktop contexts** (full detail in Part C):

*Billing/POS workstation (counter/cashier — speed-first):*
- **Top app bar** — hamburger, red→**blue New Order**, **Bill No search**, a compact row of monochrome icon buttons (reports, store/outlet, wallet, apps-grid launcher, KDS, reservation, timer), bell (count), help, power, profile. (Petpooja's "Call For Support" block is dropped.)
- **Apps-grid launcher** opens the **Operations tile grid** (curated).
- Main work area = the **desktop billing layout** (3-column) or the **Operations tile grid**.

*Web back-office (owner — Petpooja-dense):*
- **Icon rail** (left, icon-only, ~64px, blue active) = primary nav.
- **Desktop top bar** — outlet/location dropdown left; bell + Messages + share + settings + profile right.
- **Content** = stacked **panels** (each self-scoped with its own date-range + refresh), stat-card rows, clean data tables, floating detail popovers (`e3`). Multi-column on wide viewports, but generous gaps — not wall-to-wall.

**Role-aware nav**
- Owner: Analytics · Tables · Orders · Stock · More (desktop: icon rail → Analytics, Orders, Tables, Stock, Menu, Reports, Staff, Settings).
- Manager: Live (Control Tower) · Tables · Orders · Stock · More.
- Waiter: Tables · Orders · More.

### 7. Operational screens (Petpooja flow, blue)

- **Orders (home).** One queue, 5 channels (website · messenger · table-QR · waiter · counter) with a quiet channel glyph per card. Calm summary row + to-accept count. Search + Filters sheet. Underline seg Ongoing / Completed. Blue FAB = new order. Card: serial hero · order *type* (Delivery / Table 5 / Parcel) replacing customer name · channel + age subline · `N items · preview`. Strict **pending → accepted → completed**: pending → Accept (blue) + small reject ✕ (red); accepted → Print KOT + Print Bill (Bill = Completed).
- **Order build.** `← Order for table : 3` + search. Category sections with item tiles (veg/non-veg dot, "customizable*", price). Tap-to-add → `--primary-tint` highlight + count badge + minus. Blue FAB opens cart. List/grid toggle; grid 2/3/4-col.
- **Cart / Review.** "Final Order", + Waiter chip, + Add more (blue). Line rows: trash, name, modifiers, Edit ⌄, stepper. Footer: ☑ Print KOT in Kitchen + full-width blue Confirm Order.
- **Bill / Payment.** Underline tabs Dine-in · Delivery · Take away. Bill-for / Table no., line items + steppers + totals, Total Payable bold. Radios Cash/Card/Other (blue). Footer pair: navy Save & print + blue KOT & print.
- **Success.** Green check, Payment Successful, total in green, View Invoice (blue outline) + "Bill printed" info banner, full-width blue Back to Home.
- **Tables (FOH).** Underline tabs by area, area headers, square number tiles, state fills + legend. Blue FAB. Order-type seg Dine-in · Parcel · Delivery; Delivery puts recipient/area→charge form first. Counter mode = tap-to-ring grid. Tap table → detail popover.
- **Menu management.** Action row: Delivery toggle · Scan (AI menu-card scan) · Discounts · Settings. Item rows + inline Available toggle. Bulk: "Push all menu items" (multi-select outlets) + "Update availability in channels" toggles. Add item = bottom-bar blue primary.
- **Stock.** Ranked white table (rank · Item · Cover(adv) · Value · Qty), single status-dot column (amber low, red out). Sortable headers, summary tiles. Advanced toggle reveals Cover + drill-downs. Bottom bar: Count + Stock in. AI scan for handwritten supplier bills + EOD counts.
- **Messages.** Bot auto-answers, escalates to manager who replies in-app. Needs you / All chats underline seg, amber reason tags. Thread: bot = blue-tint + BYTES BOT, manager = navy.
- **Settings / Staff / Audit / More** — as standard back-office (blue primary, ghost secondary, role-gated).

---

## PART B — ANALYTICS & REPORTING CONTENT (modeled on QuicklyServices, rendered in the blue Petpooja skin)

> This is a **content reset.** The metrics below replace the old AOV/cohort/LTV/attach-rate/forecast/basket set. These are the figures QS surfaces and BD restaurateurs actually read. Render them in the Part-A components, at the **density of the surface**: dense/packed on desktop back-office (Petpooja-style panels & tables), QS-style stat-grid + accordions on mobile. "Uncluttered" here refers to **metric scope** (few, plain metrics — not jargon), not to visual whitespace.

### 8. Analytics information architecture

Two top-level tabs (two-tab toggle component):
1. **Sales Breakdown** — the money story.
2. **Item-wise Sales** — what sold.

Plus a **date-range stepper** at the very top (`‹ 1 Jun 2026 — 13 Jun 2026 ›`, or quick "Today"). Optional filters (Outlet, Service, Shift, Terminal) live in a Filters control, not cluttering the page.

### 9. Dashboard / home (owner Analytics tab)

**Hero chart** — full-width blue area chart, **Revenue** by default, with a metric toggle (●Revenue ○ No of Orders). X-axis = days across the selected range. Clean gridlines, muted axis.

**Stat-tile grid** (the headline numbers, each a stat card with tint-circle icon + big number + label; `›` where a drill-down exists):
- Orders (Completed)
- Gross Sales
- Discount & Commission › *(parenthesised, it's a deduction)*
- Net Sales
- Other Income › *(sum of Service Charge + Customer Fee + Delivery Charge)*
- Tax and Duty ›
- Due & Receivable ›
- Due Paid
- Total Collection ›

Mobile = 2 or 3 per row; desktop = 4 per row. Footnote in muted text where a tile aggregates (e.g. "*Other Income = Service Charge + Customer Fee + Delivery Charge*").

### 10. Sales Breakdown — report sections (accordions)

Render as stacked report-section cards; on mobile they collapse.

**A. Sales Summary**
- Orders Completed
- Gross Sales
  - Offer (deduction)
  - Membership (deduction)
  - Voucher (deduction)
  - Discount By Staff (deduction)
  - Commission (Delivery Service) (deduction)
- **Net Sales** (bold total)
- Advance Received
  - Due (deduction)
- Due Paid
  - Receivable (Delivery Service) (deduction)
- **Total** (bold)

**B. Collection Summary** — by payment mode (e.g. Cash – Cash · bKash · Card). Each mode → amount. Sub-link **Collection Breakdown ›** opens a per-outlet / per-mode detail.

**C. Service-wise Sales** — your channels (NOT aggregators):
- Dine-in
- Takeaway
- Restaurant Delivery (own riders)
- Delivery Service (3rd-party rider handoff)
Rendered as a small blue bar chart + a label-value list.

**D. Profit Estimation**
- Net Sales
- Service Charge
- Delivery Charge
- Preparation Cost (deduction)
- Wastage (deduction)
- Payment Fee (deduction)
- Taxes incl. (deduction)
- **Gross Profit** (bold; green when positive)
Plus a compact **Cost of Goods Sold** mini-stat row: Preparation Cost | Wastage | Payment Fee, and a Profit mini-row: Net Sales | COGS | Gross Profit.

### 11. Item-wise Sales

**Filters** (collapsed by default): Outlet · Service · Shift · Terminal · date range → Search · Download (PDF/Excel).

**Results table** — grouped by category with a category-subtotal header row (`Appetizer — 6567.00 (47)`), then item rows:
| Item Name | Avg. Unit Price (৳) | Total Price (৳) |
Sortable headers, in-table search box. Item name shows units sold in parens, e.g. `Chicken Pop (11)`.

**Popular Dishes** — a simple ranked list (name-left, total-sales-right, top ~5–10). No scores, no percentages — just the ranking. Lives on the dashboard too.

**Item drill-down** — tap an item → its own screen: blue area chart of that item's daily sales over the range + a "Sales for last N days" zebra list (date → amount). This is the deepest the local-tier user needs to go.

### 12. Performance Report (compare items)

A filter form (Outlet · Category · Daily/Weekly/Monthly performance · period e.g. 30 Days · start date) + **Apply**, with **Download PDF / Download Excel** links. Output = item-wise performance list. Plain-language helper text under the form ("Get item-wise report based on previous 30 days sales…").

### 13. What we deliberately DO NOT show (content guardrails)

To match the local literacy tier, the analytics **omit these metrics entirely**: Average Order Value (AOV), basket/attach-rate analysis, customer cohorts, LTV, demand forecasting, daypart heatmaps, contribution-margin/prime-cost dashboards. (Owners who want that depth get the Download Excel export instead.) This is a *content* guardrail, not a density one — the surfaces themselves still pack their panels Petpooja-style. Money figures stay concrete (৳ totals, counts, simple deductions). Every section answers a plain question: *How much did we sell? How did we collect it? What did it cost? What's left? What sold best?*

### 14. Chart style (analytics primitives)

- **Area / line** (revenue, item sales): blue stroke `--primary`, fill `--primary-tint`, smooth curve, light gridlines, muted axis, no data-point labels unless tapped.
- **Bars** (service-wise sales): blue gradient bars, value axis left, category labels below.
- **Donut** (collection by mode / service mix): channel hues, center hollow, legend right (mobile: below).
- **Metric toggle**: blue radio pair under the chart.
- Multiple panels/charts per dashboard view is expected; no more than ~2 series per chart for legibility.

---

## PART C — DESKTOP & SURFACE BEHAVIOR

> **Density model (locked):** mimic **Petpooja's density** on the **terminal/FOH** and the **desktop back-office** — packed panels, multi-card rows, dense sortable tables, tile grids, every function visible. **Mobile back-office** mimics **QuicklyServices' density** instead (stat-card grids + accordions + lists). **Analytics CONTENT everywhere stays QuicklyServices** (plain BD metrics; no AOV/cohort/tax-report jargon). Color is blue-primary throughout.

### 15. Desktop back-office (owner web — Petpooja-dense, blue)

- **Shell:** icon-only **left rail** (blue active) + **desktop top bar** (outlet/location dropdown left; bell + Messages + share + settings + profile right).
- **Dashboard:** opens with a **packed multi-panel layout**, Petpooja-style:
  - Top **stat-card row(s)** — Total Sales · Dine-in · Takeaway · Delivery (each: number, order count, trend glyph, `⋮`), plus a summary strip (No. of Orders · Total Sales · channel splits).
  - A large **chart panel** (sales over time — blue area/bars + hover tooltip) with its own date-range + refresh.
  - Alongside/below: **Discount** chart panel, **Total Sales → payment-mode breakdown** panel (Cash/Card/Wallet/Due/Other/Online progress bars + amounts), and small KPI panels — each independently date-scoped.
  - A right-hand column may stack secondary panels (e.g. quick links, alerts). We drop Petpooja's Marketplace/Order-Free-Samples/Supplier-Hub promos.
- **Outlets / Zone statistics:** stat cards with **`ⓘ` plain-language captions** (e.g. "72.77% of sales collected via cash, excl. online"), then **dense data tables** — Zone-wise and Outlet-wise (Orders · Sales · Net Sales · Tax · Discount · Modified · Re-Printed · Waived Off · Round Off · Charges) with sortable headers + a bold Total row. *(Columns we keep map to QS metrics; Petpooja-only columns are optional.)*
- **Reports landing:** grid of **report-launcher cards** (Success Orders, Cancelled, Complimentary, Sales Return, Order Payment Details, Payment Information, Cash Payment Modes…), each = title + amount + "No of orders" + `→`.
- **Analytics content** (the QS set from Part B) renders here **densely**: stat cards + Sales Summary / Collection / Service-wise / Profit Estimation panels laid side-by-side (not the mobile one-at-a-time accordion), Popular Dishes and Item-wise tables in their own panels.
- **Menu / Inventory / Staff / Settings:** Petpooja-style **management tables** — toolbar (red→**blue** primary like *Add New Raw Material* / *Add Item*, plus Action ▾ · Import ▾ · Export ▾), filter row (Name · Category · Search · Show All), then a dense table (Name · Category · Favorite · Available toggle · Created · Created By · row Action icons: delete/edit/duplicate). Inventory dashboard mirrors Petpooja's: Key Statistics (Purchase/Wastage), COGS panel, New Purchase, Stock Level, Pending Purchases/PO Approvals — content mapped to our stock model (AI scan, par levels).

### 16. Desktop terminal / FOH (Petpooja-dense, blue)

- **Top app bar:** hamburger · blue **New Order** · **Bill No** search · compact monochrome icon-button row (reports · outlet · wallet · apps-grid launcher · KDS · reservation · timer) · bell (count) · help · power · profile. (Drop "Call For Support" block.)
- **Apps-grid launcher → Operations tile grid** (curated, packed): Orders · Order History · Online Orders · KOTs · Customers · Cash Flow · Expense · Withdrawal · Cash Top-Up · Inventory · Notification · Table · Manual Sync · Live View · Due Payment · Language Profiles · Billing User Profile · Day End · Day End History · Waiter Devices · Feedback · Delivery Boys.
- **Billing screen:** the dense **3-column desktop billing layout** component (category list · item-tile grid with veg/non-veg borders + favorites · running-order panel with steppers, payment radios, Settlement, action cluster). Dine In / Delivery / Pick Up tabs top-right. Fast and tight — Petpooja density, blue not red.
- **Table view:** area-grouped square table tiles (AC / Garden / Bar …) with state legend (Running · Printed · Paid · Running KOT). Delivery / Pick Up / + Add Table actions on the bar.
- **Accept-order flow:** incoming-order card (channel + serial + items + Reject/Accept) → **accept modal** (Min Delivery Time / Prep Time steppers + Save / Save & Print / KOT / KOT & Print).
- **Day End / KOTs / Cash Flow / Expense:** standard Petpooja operational screens, dense tables + simple forms, blue primary actions.

### 17. Mobile back-office (QuicklyServices-dense, blue)

As specified in Part B: date-range stepper → 2-tab toggle (Sales Breakdown / Item-wise) → 2–3 **stat cards per row** → stacked **accordion** report sections → **lists/zebra tables** for item-wise and date→amount. This is QS's own density model — compact but scrollable, not Petpooja's wall-of-panels.

### 18. Mobile vs Desktop at a glance

| Aspect | Mobile | Desktop terminal/FOH | Desktop back-office |
|---|---|---|---|
| Density model | QS (back-office) / Petpooja (FOH) | **Petpooja-dense** | **Petpooja-dense** |
| Nav | Bottom tabs + top bar + drawer | Top app bar + apps-grid launcher | Icon rail + top bar |
| Create action | Blue FAB | Blue **New Order** | Blue primary in toolbar |
| Dashboard/analytics | Stat-card grid + accordions + lists (QS) | — | Packed multi-panel: stat rows + side-by-side charts + dense tables |
| Data tables | Card list / zebra + filter sheet | Dense operational tables | Dense sortable tables + Total row + `⋮` |
| Tables (FOH) | 3-col tile grid | Area-grouped tile grid | — |
| Billing | Order build → cart → bill sheet | 3-column billing workstation | — |
| Padding | 16 | tight (12–16) | tight (12–20) |
| Color | blue-primary | blue-primary | blue-primary |

---

## PART D — DO / DON'T

✅ Blue for primary & active · navy for the secondary action · green only for success/profit · red only for destructive · pastel tints for table/order states & stat-card icons · soft rounded cards (12–16) · **match the reference density** (Petpooja on terminal + desktop back-office, QS on mobile back-office) · icon rail on desktop · per-panel date+refresh · `ⓘ` plain-language captions on key numbers · underline tabs · circular blue FAB on mobile · plain-language QS metrics (Gross Sales, Net Sales, Collection, Prep Cost, Wastage, Gross Profit, Popular Dishes) · deductions in parentheses · tabular ৳ money · icons + Bangla on high-traffic actions · Download Excel/PDF for depth.

❌ Red as a primary action (red = destructive only) · green/navy as a call-to-action · blue flooding a screen · pill segments where underline tabs belong · multiple competing primary buttons in one zone · on-screen AOV / cohort / LTV / attach-rate / forecast / basket jargon · food-aggregator-specific screens (Zomato/Swiggy) we don't support · dedicated GST/tax-report screens · Petpooja promo modules (Marketplace, Order Free Samples, Supplier Hub) · English-only labels on high-traffic actions · artificially thinning out a screen for "minimalism" when the reference packs it.

---

### Provenance note
- **Part A (visual tokens/components)** = Petpooja's Captain App (mobile) + the **real Petpooja desktop product** (Windows billing app + billing.petpooja.com / inventory.petpooja.com back-office), recolored red→blue. High-confidence on color/shape/component/flow.
- **Density model** = Petpooja for terminal/FOH and desktop back-office (packed panels, dense tables, tile grids); QuicklyServices for mobile back-office (stat grids + accordions + lists).
- **Part B (analytics content)** = QuicklyServices (RestroGreen demo) reporting, examined directly. Metric names, IA, report sections, and chart types come from there; rendered in the blue Petpooja shell (dense on desktop, QS-style on mobile).
- QuickBytes-specific features (5-channel queue, AI menu/bill/count scan, role nav, Bangla, ৳) are mapped onto these patterns and are not native to either reference. Petpooja-only modules (Marketplace, Currency Conversion, LED Display, aggregator screens, tax-report screens) are deliberately excluded.
