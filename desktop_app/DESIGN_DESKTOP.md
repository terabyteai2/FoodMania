# QuickBytes Desktop — Design Reference (Petpooja-desktop fidelity, blue)

> **Source of truth = `admin_app/context_pictures/petpooja13–17.png`** (the native
> desktop app). Web dashboards petpooja18–23 inform analytics/inventory *content*
> only. This doc names the values; when it and the pictures disagree, the pictures win.
> The phone `DESIGN.md` does **not** govern this app.

## 0. The one substitution
Everywhere Petpooja uses **red `~#E23744`** (New Order, active order-type tab, active
category, steppers, selected radios, primary CTAs) → **blue `PosColors.primary #2F4FE0`**.
Green stays green (KOT printed / paid), **yellow stays yellow** (occupied zone/table).
Red remains destructive-only (reject/void/delete). Reuse `PosColors`/`PosShadows`; desktop
sizing lives in `lib/desktop/theme/desk_theme.dart` (`DeskMetrics`).

## 1. Chrome (petpooja13/16)
**Top app bar** — `DeskMetrics.topBar` (56), white `surface`, 1px `line` bottom border:
`[wordmark]  [New Order ▸ filled primary]  [ Bill No 🔍 sunk field ]  …spacer…  [tool icons]
[🔔 notifications] [? help] [⏻ logout]`. Bare 20px icons in `ink2`. (Petpooja's "Call For
Support" block is dropped.)

**Left rail** — `DeskMetrics.railWidth` (212), white `surface`, 1px `line` right border:
outlet chip (🏪 restaurant name) on top; nav items (icon + 13.5/600 label); active item =
`primarySoft` fill + `primary` icon/label; account·role footer. On the **Billing** screen the
rail switches to the **category list** (petpooja13 left column).

## 2. Billing screen — the 3-pane register (petpooja13/14)
Row of three columns under the top bar:

**A. Category rail** (left, 212) — vertical list: an expandable group ("Beverages ▾"),
"Favorite Items", then categories. Active category = `primary` text on `primarySoft`; a thin
left accent bar. Scrollable.

**B. Item pane** (center, flex) — two fields on one row: `Search item` (flex) + `Short Code`
(fixed ~260). Below, a **4-column card grid** (`gridGap` 8): each card ~88 tall, `surface`,
1px `line`, radius `sm`, item name (`rowTitle` 14/600) + price; a category-hue left strip is
allowed (NOT veg/non-veg — out of scope). Favourites render first in a tinted "★ Favourites"
panel (blue-wash cards). Tapping a customizable item opens a modifier/qty popover; simple
items add directly (reuse `desktopMenuNeedsCustomization` / `DesktopMenuLineSelection`).

**C. Checkout panel** (right, `DeskMetrics.checkoutWidth` 428) — the cart/KOT:
1. **Order-type tabs**: `Dine In | Delivery | Pick Up`. Active = `primary` fill, white label.
2. **Identity row**: table/customer icons + table tag ("AC4") + zone chip (yellow
   `stateOccupied` when occupied). Delivery/Pick-up show customer instead.
3. **Column header**: `ITEMS · CHECK ITEMS · QTY · PRICE` (`eyebrow`, `muted`).
4. **Line rows** (≥ `DeskMetrics.rowMin` 44): `✕` remove · name (+ modifier in parens) ·
   stepper `− [qty] +` (circular `primary`-outlined) · price over line-total.
5. **Totals bar**: `Bogo/Offer` · `Split` · `Sales Return` · **Total** (right, bold tabular).
6. **Payment modes** (radios): `Cash · Card · Due · Other · Part` — selected = `primary` dot.
7. **Settle**: `Settlement Amount` field + **Settle & Save** (blue) when settling; `It's Paid`.
8. **Action row** (sticky footer, `bar` shadow): `Save · Save & Print · Save & eBill · KOT ·
   KOT & Print · Hold` (edit mode swaps in `Cancel`). Primary actions blue; `Hold`/ghost
   outlined; destructive red. Wire to `createDesktopOrder`/`sendDesktopKot`/`settleDesktopOrder`
   + `printOrderTicket`/`printCustomerInvoice`.

## 3. Table View / FOH (petpooja15)
Header `Table View` + `Contactless`, reconnect banner, legend (● Printed / ● Paid / ●
Running-KOT), `Delivery · Pick Up · + Add Table`. **Zone sections** ("AC", "Garden") each a
grid of **square** table tiles (`tileTableAspect` 1.0): vacant = dashed `line` border on
`surface`; occupied = `stateOccupied` fill + `stateOccupiedInk`; running-KOT adds a
`stateKitchen` dot; paid = green. Online-order cards (channel + Delivery badge) with
`Reject`/`Accept`; Accept opens a min-delivery/prep-time popover with `KOT`/`KOT & Print`.
Tap vacant → Billing (new); tap occupied → edit that order.

## 4. Operations hub (petpooja16) & Day-End (petpooja17)
Hub = responsive grid of feature tiles (icon + label) → only the tiles we support
(Orders, Online Orders, KOTs, Table, Inventory, Day End, Day-End History, Notifications,
Language, Settings). Day-End = stat cards (Success/Cancelled/Complimentary/Sales-Return
orders, Order Payment Details, Payment Information) + `Next`. Cards: `surface`, radius `card`,
1px `line`, `soft` shadow.

## 5. Analytics / Inventory content (petpooja18–23)
Content vocabulary (QuicklyServices, not Petpooja/GST): Gross/Net Sales, Collection, Discounts,
Prep Cost, Wastage, Gross Profit, Popular Dishes, Service-wise Sales; payment split; COGS;
stock value / low-stock / variance. Charts are desktop-wide multi-card dashboards. Currency
**৳ BDT**. Missing metrics are **hidden, never zero-filled** (NULL-safe invariant).

## 6. Discipline
Bilingual EN + বাংলা via reused `AppStrings` (Plus Jakarta Sans EN / Hind Siliguri · Noto Sans
Bengali). Money tabular. Touch/mouse targets ≥ 36. No veg/non-veg markers, no KDS, no
camera/scan surfaces. Every new visual value gets a `DeskMetrics`/`PosColors` token — no raw
literals in feature code.
