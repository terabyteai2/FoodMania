# QuickBytes POS — Design System v4.2 "Petpooja-fidelity (pictures-first)"

> **Supersedes v3 (density-first) wholesale. 2026-07-03.**
>
> **The source of truth is `admin_app/context_pictures/petpooja_target/*.png` — not this
> document's prose.** `context_pictures/current/` holds the phone screenshots we are judged
> against. When this doc and the pictures disagree, the pictures win and this doc gets fixed.
> Rationale: v1–v3 were written spec-first and repeatedly failed to land the actual Petpooja
> look; v4 is measured *from* the screenshots and exists only to name those values as tokens.

## 0. The substitutions (user-confirmed; everything else copies the pictures)

1. **Blue, not crimson.** Everywhere Petpooja uses red `~#E23744` (primary CTAs, active tabs,
   FAB, steppers, selected radio-cards) we use the QuickBytes blue ramp,
   `PosColors.primary #2F4FE0`. Petpooja's dark-navy secondary button maps to
   `PosColors.secondary #1E2A44`. Green stays green (success), yellow stays yellow
   (occupied tables). Red remains destructive-only.
2. **Plus Jakarta Sans, not Quicksand/Poppins.** The `tfFontFamily` machinery
   (Jakarta EN / Hind Siliguri BN + fallbacks) is untouched.

**Carried-over product rules (still binding):**
- Bangladesh market: currency **৳ Taka**; two literacy tiers (EN owners, বাংলা-leaning staff
  → icons + short labels + BN toggle).
- Analytics/report **content** vocabulary follows QuicklyServices, not Petpooja: Gross Sales,
  Discounts, Net Sales, Collection, Prep Cost, Wastage, Gross Profit, Popular Dishes,
  Service-wise Sales. No aggregators, no GST, no AOV/LTV jargon.
- **Veg/non-veg markers are out of scope** (product decision): clone Petpooja screens
  *without* that element.

## 1. Non-negotiable principles

1.1 **Pictures over prose.** A restyle PR must cite the target image(s) it implements.
1.2 **Token discipline.** Every visual value lives in `app_theme.dart` (colors, spacing,
    density, radii, shadows) or `TfTextStyles` (type ramp). A raw `fontSize:`, chrome
    `EdgeInsets` literal, radius number, or `Color(0x…)` in feature code is a defect.
    `copyWith(color:, fontWeight:, height:)` on a token is legal; `copyWith(fontSize:)` is not.
1.3 **Utility over showcase.** Petpooja is a dense working tool: slim chrome, small type,
    thin borders, minimal shadow. If a screen reads like a marketing page, it is wrong.
1.4 Touch targets ≥ 44px even where the visual is smaller (padding / hit-test slop).
1.5 Anti-air rules (hard ❌): no `Spacer()` to stretch tile/card content apart; no wizard
    chrome ("Step 2 of 3") in the order flow — it is continuous search → tap → cart → confirm;
    no screen whose top half is one card and bottom half is background.

## 2. Color tokens (`PosColors`)

Blue ramp, navy secondary, neutrals, signals: unchanged (they already encode §0.1).

**Neutral wash (v4.1, user-confirmed):** decorative container washes are GREY, never
blue — blue is reserved for primary CTAs, active tabs/segments, and selection
highlights (in-cart tile, selected table, active sort/filter, multi-select rows).

| Token | Value | Role |
|---|---|---|
| `neutralSoft` | `= surfaceSunk #F1F3F6` | washed container (icon boxes, info cards, badges) |
| `neutralWash` | `= surface3 #E7EAEF` | border on washed containers |
| `neutralInk` | `= ink2 #5A6475` | text/icon on neutral wash |

Channel icon boxes on order cards use `channelNeutralSoft`; only the glyph keeps its
channel hue. `TfButtonVariant.accent` (Accept/Bill) and `infoSoft` where genuinely
semantic-info stay blue.

**New/changed in v4:**

| Token | Value | From picture |
|---|---|---|
| `stateOccupied` | `#F7C948` | target10 — saturated yellow fill of running tables |
| `stateOccupiedInk` | `#5C4A00` | target10 — timer/amount/number ink on yellow |
| `stateOccupiedLine` | `#DFAF2B` | tile border on yellow |
| `stateKitchen` | `#A9E3BF` | mint "KOT in kitchen" marker on occupied tiles |
| `stateKitchenInk` | `#1E7A47` | ink for the kitchen marker |
| `seatTint / seatLine / seatInk` | → `stateOccupied` family | occupied wash everywhere (FOH grid, order-build table picker) |

The pale pastels `stateRunning/statePrinted/stateKot` remain for badges/non-tile uses, but
**table tiles use the saturated family** — target10 shows full-strength yellow, not a wash.

## 3. Type ramp (`TfTextStyles`) — measured from targets 3, 4, 9, 10

| Token | Size/weight | Role (picture) |
|---|---|---|
| `appBarTitle` | **18/700** | "Tables", "Order for table : 3" (target9/3); same at tab roots and pushed |
| `screenTitle`, `pushedTitle` | = `appBarTitle` (compat aliases) | legacy references |
| `tileNumber` | **28/700** tabular | centered table number (target9/10) |
| `sectionHeader` | **14/700** | area headers "Party Hall", "AC" (target9/10) |
| `sectionStrip` | **12/600** | gray category strips "South Indian" (target3) |
| `rowTitle` | 14/600 | item/cart row names (target4) |
| `body` | 13/400 | supporting copy |
| `bodyMuted` | 13/400 muted | metadata |
| `label` | **11/600** | tile meta: "⏱ 32 min", tile amounts, "customizable*" (target3/10) |
| `tabLabel` | 14/600 | underline tabs (target9) |
| `price` | 15/700 tabular | money on rows/cards |
| `rowMoney` | **13/600** tabular | per-line money + qty gutter on order/receipt rows (v4.2) |
| `ctaLabel` | **15/700** | full-width CTA text "Confirm Order" (target4) |
| `orderSerial` | 19/800 tabular | #24 on order cards (kept — no Petpooja equivalent) |
| `statNumber` | **20/700** tabular | stat-card numbers (was 24/800 — too showcase) |
| `heroMoney` | **30/800** tabular | payment-success amount ONLY (target5; was 34) |
| `eyebrow` | 11/700 +0.55 | column headers in list tables (target6/7) |

Nothing above 28 except `heroMoney` on payment-success.

## 4. Geometry & density

**`PosRadii` (v4):** `xs 4 · sm 8 · md 10 · lg 10 · xl 16 · pill 999`.
Aliases: `card/input/tile = 10`, `tag = sm`, `chip/toggle = pill`.
Petpooja cards, buttons, and inputs are all ~8–10 radius (target1/3/4/11); the 12–16
rounded-SaaS corners are gone. `xl 16` is reserved for modal sheets (target11).

**`PosDensity` (v4):**

| Token | v4 | Picture evidence |
|---|---|---|
| `cardPad` | **10** | tile/cart-card internal padding (target3/4) |
| `gridGap` | **8** | table + item grid gutters (target9/10/3) |
| `sectionGap` | **10** | between cards/sections |
| `rowMin` | **48** | list rows (target7/8) |
| `tileMenu` | 104 | unchanged — already ≥8 tiles/screen |
| `tileTableAspect` | 1.0 | unchanged — square tiles (target9) |

Screen horizontal padding stays 16 (`PosSpacing.sp4`); everything inside packs.
**Shadows:** `soft` on cards; `bar` under sticky footers; `fab` glow on the circular FAB.
No other elevation.

## 5. Chrome anatomy (per picture)

### 5.1 App bar — target9, target3
One slim row: `[bare ☰ / ← icon] [title appBarTitle] …spacer… [bare action icons]`.
- **No outlet subtitle in the bar.** Outlet identity lives in the drawer header (target12).
- Bare 24px icons with ≥44px hit areas — not boxed/bordered icon buttons.
- Vertical padding `sp2` (8); total bar ≈ 52px. Same anatomy pushed and at tab roots.

### 5.2 Tabs — target9, target1
Underlined text tabs: `tabLabel`; active = `primary` label + 2.5px `primary` underline;
inactive = `muted`; hairline `line` under the whole strip; horizontally scrollable.
No pill/segment backgrounds for primary navigation tabs.

### 5.3 Table tile — target9 (vacant), target10 (occupied)
Square (aspect 1.0), radius `tile`, 3-column grid, `gridGap` gutters.
- **Vacant:** `surface` fill, `line` border, number centered `tileNumber` in `text`.
- **Occupied:** `stateOccupied` fill, `stateOccupiedLine` border, ink `stateOccupiedInk`:
  `⏱ N min` top (`label`), number centered (`tileNumber`), running amount bottom-left
  (`label`, tabular), `⋮` kebab bottom-right. Elapsed ticks live (30s cadence).
- **KOT sent:** occupied anatomy + a small `stateKitchen` dot.
- **No legend row** — Petpooja has none; tiles are self-explanatory.
- Areas ("Party Hall", "AC") are plain `sectionHeader` rows above their grids.

### 5.4 Cards & list rows — target4, target7, target8
White `surface`, radius `card`, 1px `line` border, `soft` shadow, `cardPad` padding,
rows ≥ `rowMin`. Column-header rows use `eyebrow` in `muted`.

### 5.5 Buttons & CTAs — target1, target4, target5, target11
- Primary CTA: full-width, h48 (h52 in sticky footers), radius `md`, `primary` fill,
  white `ctaLabel`. Never pill.
- Paired sticky footer: navy `secondary` left + `primary` right, both `Expanded`, gap 12,
  in a `surface` bar with `bar` shadow — **`TfStickyCTA` is the only footer chrome.**
- Ghost/outline: `surface` fill, `lineStrong` border, `text` ink.
- FAB: circular, `primary` fill, white icon, `fab` glow (target3/9).
- Steppers: circular `primary`-outlined − / + with the qty between (target1/4).

### 5.6 Selection radio-cards — target11
Payment modes etc.: 2-column grid of outlined cards h~44, radius `md`; selected =
`primary` border + `primary` radio dot; unselected = `lineStrong` border.

### 5.7 Category strips — target3
Full-width `surfaceSunk` strips, `sectionStrip` label in `ink2`, as in-list section
separators on order-build / long lists.

**Filter chips (`TfChip`, v4.1):** squared segment geometry — radius `md` (10), NOT
pill — matching `TfPeriodSelector`. Active = solid `primary` + white; inactive =
`surface` + `lineStrong` border. Every time-range filter is `TfPeriodWithCalendar`:
preset segments plus an auto-appended calendar-icon segment (the custom-range label
IS the calendar icon) revealing the inline `TfCalendarRangePicker`.

### 5.8 Drawer — target12
Brand header (`TfBrandHeader` — the ONLY place outlet name + wordmark live), then plain
icon + 15/600 label rows, help/contact block pinned at the bottom.

### 5.9 Payment success — target5
Green check hero, `heroMoney` amount in `success`, outlined "View invoice" (primary
substitutes Petpooja red), full-width `success` "Back to home". The one money-hero screen.

### 5.10 Order cards (Orders list) — v4.2, user-confirmed
Two card anatomies, both NEUTRAL white (`surface`/`line`; `pendingBorder` when
pending). No service-type color strip/rail — user rejected saturated color for
long-use fatigue on small POS screens. Only semantic color is allowed: age
escalation, KOT-printed green, the LATE badge.

**Ongoing (truncated operational ticket):** one header row = serial
(`orderSerial`) + inline 14px `ink2` channel glyph (no boxed wash) + type label
(`rowTitle`/ink2) + LATE badge (pending > 20 min) + total (`price`). Below: live
age in `label` (screen-level 30s tick; accepted-unbilled ink escalates
`late` ≥ 45 min → `danger` ≥ 120 min, w700 when escalated) with the quiet
KOT-sent check. Then the one-line item summary (count + first 2 names). Footer:
right-aligned **sm (36px)** buttons — KOT ghost (+11px `success` printed dot) and
Bill accent; pending gets compact Reject (40×36 outline) + Accept accent sm.
Never full-width md button pairs.

**Completed (owner record, QuicklyServices reference):** serial + green
`served`-kind "Completed" pill + `h:mm a` time (`label`/muted, from createdAt so
it agrees with the date group headers). Full item list (≤ 8 rows + expander;
grid tiles cap at 3 with a static "+N more") — 30px qty gutter in `rowMoney`,
name in `body` w500, per-line amount in `rowMoney`. Hairline, then Discount row
ONLY when > 0 (never ৳0), then `totalLabel` + total in `price`. Muted `label`
meta wrap line: payment · Table N/Parcel/Delivery · "by role" (each segment
hidden when its data is absent). No dimming, no shift/terminal chips, no
"Closed by".

**Chrome:** search collapses to a bare bar icon (`TfGlobalTopBar.extraActions`);
the inline field row mounts only while open or while a query is active. Active
search/filter icons render as dark boxed squares.

### 5.11 Guided tour (first-run coach marks)

One-time-per-account spotlight overlay (replayable from More hub → Help & Guide).
Implemented in `core/widgets/guided_tour.dart`; screens expose targets via the
zero-visual `TourSpot(name:)` wrapper (registered in `TourSpotRegistry`, resolved
to a global rect at show time; unmounted spots are skipped silently).

- **Scrim:** `tourScrim` (navy ~80%) over the whole shell; cutout = target
  rounded-rect (radius `md`) or circle (FABs), inflated 8px, 2px `primary` border.
- **Tooltip card:** `surface`, radius `card`, `line` border, `soft` shadow,
  `cardPad`-ish padding; title `rowTitle`, body `body`/`ink2`, `label`-muted
  "n/total" counter, `sm` ghost **Skip** + `sm` primary **Next/Done**, progress
  dots (`primary` active / `surface3` idle). Positioned below the target when
  its top half is clear, above otherwise; overview steps bottom-anchor the card.
- **Interaction:** scrim taps are absorbed (advance only via Next — no
  accidental dismissals); Skip and Done both persist the per-account completion
  flag (`guided_tour_v1_done_accounts` in SharedPreferences).
- **Step sets:** role-keyed on the landing tab — owner (Analytics overview +
  stats grid), manager (Orders overview + `+` FAB), waiter (Tables grid); shared
  header spots (`header.menu` / `header.bell` / `header.avatar`) in
  `TfGlobalTopBar`. Never navigates tabs mid-tour; role switch dismisses it.
- **Spot vocabulary (v2):** the assistant's highlight vocabulary
  (`backend_dev/data/support_guide_deeplinks.json`) covers every main screen —
  Analytics, Orders (search/tabs/filters/card actions), Tables (mode tabs,
  counter mode), Stock (period/table/add-item/variance/suppliers), Menu
  (search/categories/new-item), More hub rows, and the pushed Staff, Audit,
  stock-count, Reports, and Control Tower screens. Entries may carry
  `title`/`body` (default copy), `shape: circle` (FABs) and `role` metadata;
  the client still resolves every spot to a live element via
  `TourSpotRegistry` — nothing is position-stored.

## 6. Screen acceptance (phone ≈ 410×880)

| Surface | Target | Too airy if |
|---|---|---|
| FOH table grid | **≥ 9 tiles visible** with tabs + area header (target9) | tiles taller than wide, empty middles |
| Menu/order-build grid | **≥ 8 item tiles visible** (2-col × ≥4 rows) | tiles > ~104 tall or gaps > 8 |
| Dense lists (menu manage, stock) | **≥ 10 rows visible** (target7) | rows > ~52, double-height metadata |
| Orders (compact cards w/ KOT+Bill) | **≥ 5 ongoing cards visible** (v4.2) | full-width md button pairs, boxed channel washes |
| Report/analytics | ≥ 2 section cards + stat row visible | one hero + whitespace |

Every screen: slim bar (§5.1), no dead hero bands, sticky footers only via `TfStickyCTA`.

## 7. Token discipline — verification greps

Run over `lib/src/features/**`; every hit is a defect to fix or explicitly justify:

```bash
grep -rn "fontSize:" lib/src/features/
grep -rn "Color(0x" lib/src/features/
grep -rEn "BorderRadius\.circular\([0-9]" lib/src/features/
grep -rn "BoxShadow(" lib/src/features/
```

Legacy debt is tracked by the separate full-token-migration effort; **new/touched code
must be clean regardless.**

## 8. Change protocol

1. Look at the target picture first; measure, don't remember.
2. If a needed value has no token, add the token (named for its role) — never inline it.
3. Petpooja-red elements land blue (§0.1); yellow/green stay.
4. Update this doc in the same PR whenever a token value or anatomy rule changes.
