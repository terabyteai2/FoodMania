# QuickBytes POS — Mobile Design System (as-built)

> Spec for **QuickBytes** — a restaurant POS **mobile** app (Android-first, one portrait phone surface, 410×872). Built on **Volt** design DNA — crisp square-leaning corners, hairline borders, one neutral typeface (Inter), one electric-lime accent — re-balanced for a **calm, mostly-white operational UI**. Light-theme only; tablet/terminal variants derive from this same token set later.
>
> **Audience (two literacy tiers — design for both):**
> - **Owners** — BBA graduates from English-medium private universities (NSU etc.). Comfortable with analytics terminology (COGS, prime cost, contribution margin, cohort, LTV, attach rate). Don't dumb analytics down.
> - **Managers / waiters** — high-school or in-university, **not necessarily English-proficient**, but fluent with social apps and other BD POS apps. Lean on **icons + a Bangla toggle**, familiar social-app patterns (chat bubbles, bottom nav, toggles), and short labels. Currency **৳ Taka**. Demo brand **"Spice Garden", Dhanmondi**.

---

## 1. Core rules (read first)

1. **Mostly white, lime sparingly.** White dominates. `#99FF47` lime = *go / primary / positive / active*, in small doses — one primary action, the active tab/seg, a key positive number, an accent-wash highlight. Never flood a screen with lime.
2. **Ink on lime, always** (`#14180E`), never white. Lime *text* on white = `--accent-strong #3E7E14`.
3. **Accent-wash for emphasis** (`--accent-tint #F0FADF`): owner/analytics hero cards, highlighted rows, the **Accept** action, bot chat bubbles, AI callouts. The soft way to use the brand without a saturated fill.
4. **Signals are functional, not decorative.** Amber/red only for real states (low stock, late order, reject). No badge spam, no decorative progress bars.
5. **Touch targets ≥ 44×44.** Buttons h44–52, add/icon-actions 42–44, chips h36, list rows ≥ 54, toggles round only.
6. **Borders, not shadows.** `1px solid --line`. Shadows reserved for sheets (`e3`), the sticky action bar (`e-up`), the notification dropdown, and the single FAB.
7. **Crisp corners** (≤12px); only toggles are round. **Tabular money** everywhere.
8. **One device aspect ratio** (410×872) for the whole app — every screen, including analytics/control-tower, stays on the phone surface so it screenshots consistently. The phone frame is **hard-width-constrained** (not aspect-ratio-from-content) so a wide child can never stretch it — give flex inputs `min-width:0`.

---

## 2. Color tokens (light)

### Brand — lime ramp
`50 #F3FDE7 · 100 #E4FBC9 · 200 #CDF79B · 300 #B4F46E · 400 #99FF47 (accent) · 500 #84F02C (press) · 600 #67C81E · 700 #3E7E14 (accent-strong) · 800 #2F5E14 · 900 #1E3D0F`
Derived: `accent-ink #14180E` · `accent-tint #F0FADF` · `accent-tint-2 #D8F3AD`.

### Neutrals
`bg #F7F8F4 · surface #FFFFFF · surface-2 #F2F3EE · surface-3 #E9EBE3 · ink #1A1E14 · ink-2 #565B4C · muted #878C79 · placeholder #AEB2A2 · line #EDEEE8 · line-2 #E0E2D8`

### Signals (lime = positive; never invent a 2nd green)
`success #498F18 / soft #E4FBC9` · `warning #B0760A / #FBEFCD` · `danger #D43A3F / #FBE3E2` · `info #3E6FE0 / #E3EAFC`.

### Occupied-table wash (FOH) — deliberately NOT lime
`--seat-tint #EDF1F7 · --seat-line #D5DEEC · --seat-ink #4C679C`. A calm slate so "occupied" never reads as a tappable/positive state.

### Channel hues
dine-in lime · website/delivery `#3E6FE0` · messenger `#3E6FE0` · table-QR `#B0760A` · counter `#498F18` · manager ink.

---

## 3. Typography — Inter

| Role | Size / Weight | Notes |
|---|---|---|
| Screen title (big) | 26 / 700 | tab roots |
| Screen title | 22 / 700 | pushed screens |
| Money / token hero | 33–76 / 800 | success token, analytics net sales — tabular `-0.02em` |
| Section (H2) | 15 / 700 | card titles |
| Order serial (hero) | 19 / 800 | the `#24` on order cards |
| Title (row/tile) | 14–15 / 600 | item / order / staff name |
| Price / money | 14–17 / 700 | tabular |
| Body | 14 / 400 · Body-S 13 muted | |
| Label / status | 11–13 / 500–700 | |
| Eyebrow | 11–12 / 700 · `0.05–0.08em` UPPER | section kicker |

**Bangla:** every nav label, screen title, and high-traffic action has an EN + বাংলা string (`makeT(lang)` → `t('key')`). Bangla renders in the same Inter stack (system Bengali fallback); sizes/weights unchanged — Bangla glyphs read slightly larger, which suits the lower-literacy tier.

---

## 4. Shape · spacing · elevation

**Radius** `xs 3 · sm 5 · md 7 · lg 9 · xl 12 · pill 999 (toggles)`.
**Spacing** base-4. Screen padding 16; card padding 13–16; list gap 10–11; section gap 12–18.
**Elevation** flat+border default. `e3` sheets + notification dropdown. `e-up` sticky bars. FAB shadow `0 8px 22px -6px rgba(126,200,40,.6)`.

---

## 5. Roles & access (Owner / Manager / Waiter)

The app is **role-aware**. A demo **role switcher** lives in More → profile card (segmented Owner/Manager/Waiter). Switching role rewrites the bottom nav and gates screens.

| | Owner | Manager | Waiter |
|---|---|---|---|
| Home/insight tab | **Analytics** | **Control Tower (Live)** | — |
| Tables · Orders | ✓ | ✓ | ✓ |
| Stock | ✓ | ✓ | — |
| Menu mgmt | ✓ | ✓ | view |
| Messages | ✓ | ✓ | — |
| Staff invite | ✓ (incl. Manager) | ✓ (Waiter only) | — |
| Audit trail | ✓ | ✓ | — |
| Settings (storefront/areas/VAT/theme) | ✓ | — | — |

**Bottom nav by role** (always 5 or fewer, Orders centered where present):
- **Owner:** `Analytics · Tables · Orders · Stock · More`
- **Manager:** `Live · Tables · Orders · Stock · More`
- **Waiter:** `Tables · Orders · More`

Analytics (owner) and Control Tower (manager) are **real tabs**, rendered on the phone surface — never a separate tablet view.

---

## 6. Navigation & shared chrome

- **Shared top bar (`Header`).** One component, conditional: **brand variant** (lime mark + "QuickBytes" + location) on the Orders home; **title (+ optional back) variant** elsewhere; tab-root titles use `big`. Right slot on every home screen = **`TopActions`** (shared): a **Messages** BarBtn (escalation badge) + a **notifications bell** BarBtn (unread badge). **No page-navigation buttons in the top bar** — primary actions live in the bottom bar (Add item, Stock-in, Count, etc.).
- **`BarBtn`** — square 42px, hairline border, optional count badge or dot.
- **Notification center** — the bell opens an in-app **dropdown** (not a screen): "Mark all read", rows = color-coded icon + title + body + relative time + unread dot; tapping routes to the source (order, Messages, Stock, Tables, Control Tower). Surfaces: **new pending orders, low-stock/stockout, chatbot escalations, long-seated/bill-pending tables, shift & day-end reminders.**
- **Bottom tab bar** — active tab = lime pill behind icon + bold label; pending-order badge on Orders. Localized labels.

---

## 7. Screens

- **Orders (home).** Multi-channel feed (website, messenger, table-QR, waiter, counter, manager — quiet channel glyph per card, *not* a filter). Calm summary row (floor revenue + to-accept count). **Search** + a **Filters** sheet (date range: today→12 months; source). Seg **Ongoing / Completed**. Lone lime **FAB** = new order. **Card anatomy:** short serial **`#24` is the hero**; **order *type* (Delivery / Table 5 / Parcel) replaces the customer name**; channel + age subline; emphasized `N items · preview`. **No pending badge/tag** (removed — pending is conveyed by the Accept action + card border). States: *pending* → **Accept** (accent-wash, the FAB stays the only bright element) + small reject ✕; *accepted* → **Print KOT** + **Print Bill** (Bill marks **Completed**).
- **Order detail.** Title = serial. Editable lines, customer/channel card, summary, Accept → prints.
- **Messages (Messenger hand-off).** The FB chatbot auto-answers; when stuck (photo request, far-area delivery quote, catering/custom) it **escalates to the manager**, who replies **in our UI — never Facebook's**. Inbox: bot-info banner, **Needs you / All chats** seg, rows w/ avatar + last msg + amber reason tag. Thread: customer bubbles neutral-left; **bot/manager bubbles right** — **bot = accent-tint with a "BYTES BOT" label**, manager = solid ink; **amber centered escalation banners**; composer with **context-aware quick replies**, an image-send, and **hand-back-to-bot**. Entry: top-bar Messages BarBtn (badge) + More → Messages.
- **Tables (FOH).** Order-type seg **Dine-in · Parcel · Delivery** (no pickup). Dine-in grid, no cover counts; **occupied = calm slate wash**, vacant = plain white. **Parcel = Dine-in logic** (takeaway) → menu → review → success. **Delivery is different: the delivery form comes FIRST** (Step 1: recipient name, phone, address, area→charge) → *then* menu → review → success. Counter mode (More) turns Tables into a tap-to-ring quick-sell grid.
- **Order build.** Search + category chips + **list/grid toggle**. **List groups items under category headers**; **grid has a 2/3/4-column dropdown**. Tap-to-add; **selected items get accent-tint highlight** — list rows show a qty stepper, grid tiles a count badge + **minus to remove**. Modifier sheet for option items.
- **Review.** Add-more shortcut, editable lines, **discount presets pulled from Settings**, summary; confirm prints KOT · Token · Bill.
- **Success.** No receipt previews — the **customer token is the hero** (huge accent-tint card) under a success check; **KOT · Token · Bill print buttons in a row across the bottom** (tap = sent → reprint); New order / Done footer.
- **Menu management** *(pushed from More)*. Compact icon **action row**: Delivery toggle · Scan · Discounts · Settings. Item rows w/ inline Available toggle. One **universal delivery** switch. **Add item** is a **bottom-bar** primary (not a top-bar button). Item editor: photo, name, price, category, Available + Set-discount.
- **Stock.** **Ranked white table** (Product-performance style): rank `#` · Item · **Cover (adv)** · Value · **Qty (rightmost)**. A **single, fixed-width status dot** column keeps every row perfectly aligned (low = amber, out = red; ok = blank). Sortable headers; summary tiles (stock value, below-par). **Minimal "Advanced" toggle** reveals the **Cover** column + drill-down cards (Variance, Suppliers) and makes rows open **Item detail** (usage sparkline + adjustment history). **Bottom bar: labeled `Count` + `Stock in`** (no cryptic top-bar icon).
  - **Stock-in:** multi-line editor; **bottom bar = `Scan bill` + `Add to inventory`** (both always visible — used constantly). Supplier-bill scan lives here.
  - **Count:** progress bar + per-item count fields w/ live variance; **bottom bar = `Scan` + `Finish count`**.
  - **Advanced drill-downs:** Item detail (cover, 7-day usage, adjustment log), Daily variance (system vs counted, loss value), Suppliers (contact + last order).
- **Analytics (owner tab).** Accent-wash hero (net sales + deltas). **Minimal "Advanced analytics" toggle** (bare label + switch, top-right — no description). **Compare folded into Advanced** (no separate chip; prior-period deltas appear with Advanced on). Timeframe seg + **Filters** sheet (channel, daypart). Sections: sales trend, revenue-by-category, product performance, channel/payment donuts, daypart, demoted peak-hours. **Advanced** unlocks deeper category/product drill-downs + forecast, unit economics, cohort, discounts/wastage, basket.
- **Control Tower (manager tab).** Live ops + **minimal "Advanced" toggle**. Always: attention alerts (late order, low stock), quick stats, channel load. **Advanced** adds pace-to-target and per-waiter staff metrics.
- **Settings (owner)** *(pushed)*. **Storefront:** public URL `<slug>.quickbytes.buzz`, hero media, logo, **menu theme** (6 swatches). **Ordering:** **Delivery areas** editor (area→charge), **Discount presets** editor (%/flat), **VAT** stepper, auto-print toggle. **App:** **Language EN/বাংলা**, about/privacy.
- **Staff (owner/manager)** *(pushed)*. Member list w/ role badge, active toggle, waiter performance. **Invite** = bottom-bar primary → role pick (Manager gated to owner & only if none active) → name/phone → **OTP** simulate-accept → added.
- **Audit trail (owner/manager)** *(pushed)*. Every **void · refund · comp · discount override** with who, role, time, amount, and a **reason** line. Type-filter chips.
- **More.** Profile + **role switcher (demo)**; Messages; role-gated **Manage** group (Menu, Staff, Audit, Settings); service-mode (manager+); quick **language** toggle.

---

## 8. Components

**Primary button** h44 (lg 52), radius `md`, 600, lime+ink — ideally one per screen; pair with `ghost`. **Accept** uses accent-wash, not a solid lime fill.
**FAB** 56×56 rounded-square lime, icon-only, anchored to the content area (clears the tab bar). The Orders screen's lone solid-lime element.
**BarBtn** 42px square top-bar action (badge/dot optional). **TopActions** = Messages + bell, shared across home screens.
**Notification dropdown** absolute under the bar, `e3`, color-coded rows, unread dots, routes on tap.
**AdvToggle** minimal inline "label + small switch" — Stock, Analytics, Control Tower. No description text.
**Row** `surface`+`line`, radius `lg`, 52px tinted thumb. **Tile** (grid) tap-to-add w/ count badge + minus.
**Chip** h36, radius `sm`; active = lime+ink; `tint` active = accent-tint + accent-strong. **Seg** `surface-2` wrapper, active = white (or `lime` variant).
**Field** h44, focus = accent ring; **flex inputs MUST set `min-width:0`** (default input intrinsic width otherwise stretches the phone frame). **Qty stepper** `surface-2` pill, 32px buttons. **Toggle** round, on = lime (only round control).
**Bottom sheet** radius xl top, grab handle, `e3`. **Bottom action bar** sticky, `e-up`; multi-action bars pair a fixed-width `ghost` with a `flex:1` `primary`.
**Chat bubble** — neutral-left customer; right bot (accent-tint + label) / manager (ink). **Print doc** thermal-receipt look (only inside detail/reprint, never on success).
**Donut / AreaChart / bars** — analytics primitives; lime lead series, neutral/channel hues for the rest.

---

## 9. Do / Don't

✅ Mostly white · lime in small doses · accent-wash for emphasis & Accept · slate (not lime) for occupied tables · functional signals only · ≥44px targets · tabular money · borders over shadows · ink on lime · one aspect ratio · icons + Bangla for the manager tier · primary actions in the bottom bar · `min-width:0` on flex inputs.
❌ Lime flooding a screen · white text on lime · a pending **badge** on order cards (use the Accept action) · page-nav buttons in the top bar · prose where a table column works (Stock) · multiple/misaligned status dots · a second "success" green · rounding past 12px · dumbing-down analytics terms for owners · English-only labels on high-traffic actions.
