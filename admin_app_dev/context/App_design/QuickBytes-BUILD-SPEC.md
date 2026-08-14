# QuickBytes POS — Build Specification

> A complete spec to rebuild the **QuickBytes** restaurant-POS mobile app from scratch. Pair this with your backend API/routes (integration points are flagged **`[API]`** throughout). Built as a React 18 single-page app on one portrait phone surface (**410×872**). Currency **৳ Taka (BDT)**. Demo brand **"Spice Garden", Dhanmondi**.

---

## 0. Product in one paragraph

QuickBytes is a mobile-first POS for small/medium Bangladeshi restaurants. A single phone surface serves three **roles** (Owner / Manager / Waiter) with role-aware navigation and access. It ingests orders from **six channels** (website storefront, Messenger chatbot, table-QR, waiter, counter, manager) into one queue with a strict **pending → accepted → completed** lifecycle. It runs the floor (tables, dine-in/parcel/delivery), manages menu + inventory (with stock-in, counts, variance, suppliers), surfaces owner **analytics** and manager **live ops**, lets a manager **take over Messenger chats** the bot can't handle, and exposes **staff, audit, and settings**. Bilingual **English / বাংলা** throughout.

### Audience — two literacy tiers (design for both)
- **Owners** — BBA grads from English-medium private universities (e.g. NSU). Comfortable with analytics jargon (COGS, prime cost, contribution margin, cohort, LTV, attach rate). **Don't dumb analytics down.**
- **Managers / waiters** — high-school or in-university, **not necessarily English-proficient**, but fluent with social apps & other BD POS apps. Lean on **icons + the Bangla toggle + familiar patterns + short labels**.

---

## 1. Roles & access control `[API: auth returns role]`

| Capability | Owner | Manager | Waiter |
|---|---|---|---|
| Insight tab | **Analytics** | **Control Tower ("Live")** | — |
| Tables · Orders | ✓ | ✓ | ✓ |
| Stock | ✓ | ✓ | — |
| Menu management | ✓ | ✓ | view only |
| Messages (chat takeover) | ✓ | ✓ | — |
| Staff invite | ✓ (incl. Manager) | ✓ (Waiter only) | — |
| Audit trail | ✓ | ✓ | — |
| Settings | ✓ | — | — |

**Role-aware bottom nav** (≤5 tabs, Orders centered where present):
- Owner: `Analytics · Live · Orders · Stock · More`
- Manager: `Live  · Orders · Stock · More`
- Waiter: `Counter · More`

A **demo role switcher** lives in More → profile card. Switching role rewrites the nav and resets to a permitted tab. In production this comes from the authenticated session.

---

## 2. Data models

> Field names mirror the working prototype. Adapt to your DB; the **shape** is what matters. All money is integer Taka.

### Menu item
```
MenuItem { id, cat, name, desc, price, cost, stock: 'ok'|'low'|'no',
           sold, delivery: bool, mods: [modGroupId] }
Category = string   // 'Burgers','Rice & Curry','Kebab','Sides','Beverages','Desserts'
ModGroup { id, label, type:'single'|'multi', req: bool,
           opts: [[optId, label, priceDelta]] }   // priceDelta in ৳
```
`[API]` `GET /menu` → items + categories + mod groups. `POST/PATCH/DELETE /menu/items/:id`. `PATCH /menu/items/:id/availability`. One **universal delivery** toggle: `PATCH /menu/delivery-enabled`.

### Order
```
Order {
  id, serial,            // serial = short daily number, the card HERO (e.g. 24)
  token,                 // customer pickup token (success-screen hero, e.g. 2061)
  channel: 'storefront'|'chatbot'|'qr'|'waiter'|'counter'|'manager',
  type: 'dinein'|'parcel'|'delivery',
  state: 'pending'|'accepted'|'completed',   // rejected => deleted
  mins,                  // minutes since placed (for "waiting Nm" / late alerts)
  customer, phone, addr, area, charge,       // charge = delivery fee (per area); 0 for dinein/parcel
  table,                 // 'T5' for dine-in, else null
  server,                // waiter name, optional
  discount,              // ৳ applied
  lines: [OrderLine]
}
OrderLine { lid, id, name, cat, base, qty, mods:{groupId:optId|[optId]}, note }
```
**Totals:** `lineUnit = base + Σ selected mod priceDeltas`; `lineTotal = lineUnit × qty`; `orderTotal = (Σ lineTotal − discount) × (1+VAT) + charge`.
`[API]` `GET /orders?state=&channel=&from=&to=&q=`, `POST /orders`, `PATCH /orders/:id/state` (`accepted`/`completed`/`rejected`), `PATCH /orders/:id` (lines/discount/delivery info). **Print dedup:** track printed KOT/bill so re-accept doesn't double-print.

### Inventory
```
StockItem { id, name, cat, unit:'kg'|'L'|'pcs'|'pkt'|'btl', qty, par, cost, used7, moves }
// stockKind: ratio = qty/par → ≥.6 ok · ≥.3 low · else out
// coverDays = round(qty / used7 * 7)
Supplier { id, name, items, phone, last }
```
`[API]` `GET /inventory`, `POST /inventory/stock-in` (lines: name/qty/unit/cost), `POST /inventory/count` (counts → variance), `GET /inventory/:id/history`, `GET /inventory/variance`, `GET /suppliers`.

### Messaging (Messenger handoff) `[API: Messenger webhook + bot]`
```
Chat { id, name, handle, init, mins, unread,
       status:'needs'|'replied'|'bot',         // 'needs' = bot escalated to manager
       reason: 'Photo requested'|'Delivery quote'|'Catering ask'|'Bot handling',
       messages: [{ from:'customer'|'bot'|'manager'|'system', text, time, kind?:'image' }] }
```
The FB chatbot auto-answers; on an unresolved ask (photo, far-area delivery quote, catering/custom) it sets `status:'needs'` and posts a `system` escalation message. Manager replies (`from:'manager'`) **in our UI**; replies post back to Messenger via your bridge. `[API]` `GET /chats`, `POST /chats/:id/reply`, `POST /chats/:id/handback` (return to bot).

### Other
```
Notification { id, type:'pending'|'escalation'|'stock'|'table'|'shift', title, body, mins, read, route }
Staff { id, name, role, phone, init, active, tables, sales }
AuditEntry { id, action:'void'|'refund'|'comp'|'discount', label, who, role, reason, amount, mins }
Settings { areas:[{name,charge}], discounts:[{label,kind:'pct'|'flat',val}], vat, slug, theme, autoprint }
```
`[API]` `GET/POST /notifications`, `GET/POST /staff` + OTP invite, `GET /audit`, `GET/PATCH /settings`. Storefront URL = `<slug>.quickbytes.buzz`.

---

## 3. Global UI system (condensed)

- **Mostly white, lime sparingly.** Accent `#99FF47`; ink-on-lime `#14180E` (never white); lime text on white `--accent-strong #3E7E14`; **accent-wash** `--accent-tint #F0FADF` for emphasis (Accept, owner cards, bot bubbles).
- Neutrals `bg #F7F8F4 · surface #fff · ink #1A1E14 · muted #878C79 · line #EDEEE8`. Signals `success #498F18 · warning #B0760A · danger #D43A3F · info #3E6FE0`. **Occupied-table wash (NOT lime):** slate `#EDF1F7 / #D5DEEC / #4C679C`.
- Typeface **Inter**; **tabular numerals** for all money/qty. Corners ≤12px (only toggles round). **Borders over shadows.** Targets ≥44px.
- **Shared `Header`:** brand variant (lime mark + "QuickBytes" + location) on Orders home; title (+ back) elsewhere. Right slot = **`TopActions`** (Messages icon w/ escalation badge + notification **bell** opening an in-app dropdown). **No page-navigation buttons in the top bar** — primary actions live in the bottom bar.
- **Phone frame is hard-width-constrained**; give flex inputs `min-width:0`.
- **i18n:** every nav label / title / high-traffic action has an EN + বাংলা string via `t('key')`; toggle in Settings + More.

---

## 4. Screens, wireframes & flows

> ASCII frames are 410-wide phone. `[≡]`=back, `[◎]`=brand mark, `[✉•][🔔•]`=TopActions.

### 4.1 Orders (home) — the default for Owner/Manager
```
┌───────────────────────────────────────┐
│ [◎] QuickBytes            [✉ 2][🔔 3]  │  brand header + TopActions
│     Spice Garden · Dhanmondi           │
│ ┌──────────────┐ ┌───────────────────┐ │
│ │ On the floor │ │  3  to accept     │ │  calm summary row
│ │  ৳9,683      │ │  7 ongoing        │ │
│ └──────────────┘ └───────────────────┘ │
│ [🔍 Search orders…            ] [⛃]    │  search + Filters sheet
│ [ Ongoing 7 ][ Completed 3 ]           │  state seg
│ ┌───────────────────────────────────┐  │
│ │ 🌐  #24  Delivery          ৳1,551 │  │  card: SERIAL is hero,
│ │     Website · 1m ago              │  │  TYPE replaces customer name
│ │     5 items · 2× Kacchi, 2× Borh… │  │
│ │                      [✕] [ Accept ]│  │  pending: reject + Accept
│ └───────────────────────────────────┘  │  (Accept = accent-WASH, not solid lime)
│ … accepted card → [Print KOT][Print Bill]
│                                    (＋) │  lone solid-lime FAB → new order
│ [ Analytics ][Tables][Orders][Stock][More]
└───────────────────────────────────────┘
```
- **No pending badge/tag** on cards (pending is conveyed by the Accept action + card border).
- **Filters sheet:** date range (today / yesterday / 7d / 30d / 3mo / 12mo) + source (channel). `[API: query params]`
- Tapping a card → **Order detail** (title = `#serial`; editable lines, customer/channel card, summary; Accept → print). Print Bill → marks **completed**.
- **Lifecycle:** pending → **Accept** → accepted/ongoing → **Print Bill** → completed. Reject removes.

### 4.2 Tables (FOH)
```
[≡] Tables (big)                 [✉][🔔]
[ Dine-in · Parcel · Delivery ]          ← order-type seg
●occupied 4   ○free 8
┌────┐┌────┐┌────┐   occupied = slate wash (NOT lime)
│ T1 ││ T2●││ T3 │   vacant = plain white
│vac ││12m ││vac │   tile shows mins + running total when seated
└────┘└────┘└────┘
            [ + New dine-in order ]   ← bottom-bar primary
```
- **Dine-in & Parcel share logic** (Parcel = takeaway): pick → **Order build** → **Review** → **Success**.
- **Delivery is different — form FIRST:** tapping "Delivery" → **Delivery form** (Step 1) BEFORE the menu.
- **Counter mode** (set in More; for food carts): Tables tab becomes a tap-to-ring **quick-sell grid**.

### 4.3 Delivery form (delivery only, comes first)
```
[≡] Delivery details · Step 1     (Delivery)
Recipient name [👤 ............]
Phone number   [📞 01XXX-XXXXXX ]
Address        [ House, road, area, landmark… ]
Area · sets delivery charge
 [Dhanmondi ৳60][Mohammadpur ৳80][Banani ৳100]
 [Mirpur ৳110][Uttara ৳150][Other ৳130]
        [ → Continue to menu   ৳60 delivery ]
```
Area selection sets `order.charge` (from Settings → delivery areas). Valid (name+phone+address) gates Continue → Order build.

### 4.4 Order build (add items)
```
[🔍 Search…]              [≣ list][⊞ grid ▾]   grid ▾ = 2/3/4-column dropdown
[ All ][Burgers][Rice & Curry]…               category chips
▸ BURGERS                                      LIST groups under category headers
  [img] Beef Smash Burger      ৳380  [ + ]
        selected → [ − 2 + ] stepper, row tinted
▸ RICE & CURRY …
(GRID: tap-to-add; selected tile shows count badge + a − to remove)
        [ Review · 5 items     ৳1,840 ]
```
Items with mod groups open a **modifier sheet** (single/multi, required flags, price deltas).

### 4.5 Review → Success
```
Review                                Success
[ + Add more items ]                  ┌──────────────────────┐
lines (qty steppers / remove)         │        ✓ (lime)       │
Discount [None][10%][15%][৳50]…       │   Order confirmed     │
 (presets from Settings)              │  ╔══════════════════╗ │
Summary: subtotal / VAT / charge      │  ║ CUSTOMER TOKEN   ║ │
[ Confirm & print     ৳1,932 ]        │  ║      2061        ║ │  TOKEN is the hero
                                       │  ╚══════════════════╝ │  NO receipt previews
                                       │ [ KOT ][ Token ][Bill]│  print row across bottom
                                       │ [New order] [  Done  ]│
                                       └──────────────────────┘
```
Confirm prints KOT · Token · Bill `[API: print jobs, dedup]`. Success screen never shows receipt bodies.

### 4.6 Messages (Messenger takeover)
```
[≡] Messages · Bot live              Inbox            Thread
[ Needs you 2 ][ All chats ]                          [≡] Rumana · via Messenger   [🤖]
┌─────────────────────────────────┐                  ───────────────────────────────
│ (RA) Rumana Akter         2m  ●2 │                  cust: Can you show the Kacchi?  (left, neutral)
│  Photo requested  [amber tag]    │ → tap →          ⚠ Chatbot needs your help (amber, centered)
│  Reply ›                          │                  YOU/BYTES BOT bubbles (right):
└─────────────────────────────────┘                   bot = accent-tint + "BYTES BOT" label
                                                       manager = solid ink
                                                       [Send Kacchi photo][Quote price]  quick replies
                                                       [🖼][ Write a reply…        ][➤]
```
Bot auto-answers; escalates (status `needs`) on photo / far-area quote / catering. Manager replies in **our** UI. `[🤖]` hands back to bot. Quick replies are context-aware by `reason`. Image button sends an item-photo bubble.

### 4.7 Stock
```
[≡] Stock (big)                      [✉][🔔]
┌ Stock value ৳53,399 ┐┌ Below par 4 items ┐
INVENTORY                        [ Advanced ⊙]   minimal toggle
┌─────────────────────────────────────────┐
│   ITEM            VALUE   QTY             │  header (sortable)
│ 1 Mutton Curry  ৳14,700   14 kg          │  QTY rightmost, LEFT-justified
│ 2 Basmati Rice   ৳8,680   62 kg          │  so 14/62/9/96 align across units
│●3 Beef (bonele…) ৳6,120    9 kg          │  single fixed-width dot col = aligned
│ 6 Coke Cans      ৳4,032   96 pcs         │
└─────────────────────────────────────────┘
[ ≣ Count ]            [ ⤓ Stock in ]          labeled bottom-bar actions
```
- **Single, fixed-width status-dot column** (amber=low, red=out, blank=ok) keeps every row aligned. Rows comfortably spaced (not dense).
- **Advanced toggle** reveals a **Cover (days)** column + drill-down cards (Variance, Suppliers) and makes rows open **Item detail** (cover, 7-day usage sparkline, adjustment history: stock-in / usage / wastage / count / staff-meal).
- **Stock-in:** multi-line editor; bottom bar **`Scan bill` + `Add to inventory`** (both always visible — high-frequency). Scan-bill = OCR a supplier invoice → prefilled lines `[API: OCR]`.
- **Count:** progress bar + per-item count fields with live variance; bottom bar **`Scan` + `Finish count`**.
- **Variance** screen: system vs counted, loss value. **Suppliers:** contact + last order.

### 4.8 Analytics (Owner tab)
```
[≡] Analytics (big)                  [✉][🔔]
                          [ Advanced analytics ⊙]   minimal toggle (Compare folds in here)
[ Today ][7d][30d][Custom]   [⛃ Filters]            channel + daypart filters
Net sales hero (accent-wash) + Δ deltas
Sales trend (line + area)
Revenue by category            [ See all › ]        → full page
  Rice & Curry  ৳612k · 42%  ▇▇▇▇▇▇
Product performance            [ See all › ]        → full page
  [Revenue][Units][Orders][Margin]  (chips)
  1 Chicken Biryani  512 sold · 63%   ৳163,840
Channels donut · Payments donut · Dayparts · (peak hours, demoted)
```
- **"See all" → Revenue by category (full):** sort chips Revenue/Share/Margin/Growth/Units; per-card bar + Share/Margin/WoW/Units; Export.
- **"See all" → Product performance (full):** search + 6 sort dimensions (Revenue/Units/Orders/Margin/AOV/Growth); dynamic metric column; full item table; Export.
- **Advanced on** unlocks category/product drill-downs + forecast, unit economics, cohort, discounts/wastage, basket. `[API: analytics endpoints by range/channel/daypart]`

### 4.9 Control Tower (Manager tab)
Live ops + a minimal **Advanced** toggle. Always: attention alerts (late order, low stock — tap routes to source), quick stats (open orders, tables seated, avg accept), channel load bars. **Advanced** adds pace-to-target (vs expected-pace marker) and per-waiter staff metrics.

### 4.10 More + secondary screens
- **More:** profile + **role switcher (demo)**; Messages; role-gated **Manage** (Menu, Staff, Audit, Settings); service-mode (Full/Counter, manager+); quick language toggle.
- **Menu management** (pushed, has back): icon action row Delivery·Scan·Discounts·Settings; item rows with inline Available toggle; **Add item = bottom-bar primary**; item editor (photo, name, price, category, Available, set-discount).
- **Settings** (owner): Storefront (URL `<slug>.quickbytes.buzz`, hero media, logo, **menu theme** swatches), Ordering (**delivery areas** editor area→charge, **discount presets** editor %/flat → feed Review, **VAT** stepper, auto-print), App (**Language EN/বাংলা**, about/privacy).
- **Staff** (owner/manager): member list (role badge, active toggle, waiter perf). **Invite = bottom-bar** → role pick (Manager gated to owner & only if none active) → name/phone → **OTP** accept → added. `[API: POST /staff/invite → OTP]`
- **Audit trail** (owner/manager): every **void / refund / comp / discount override** with who, role, time, amount, **reason**; type-filter chips. `[API: GET /audit]`

### 4.11 Notification center (bell dropdown)
In-app dropdown (not a screen): "Mark all read"; rows = color-coded icon + title + body + relative time + unread dot; tap routes to source. Surfaces **pending orders, low-stock/stockout, chatbot escalations, long-seated/bill-pending tables, shift & day-end reminders**. `[API: GET /notifications, realtime push]`

---

## 5. Key flows (state transitions)

1. **Incoming order:** channel → `pending` (notification + Orders badge) → manager **Accept** → `accepted` (KOT prints) → **Print Bill** → `completed`. Reject → removed.
2. **Dine-in/Parcel:** Tables → type → Order build → Review (discount) → Confirm → Success (token) → prints.
3. **Delivery:** Tables → Delivery → **form (name/phone/address/area→charge)** → Order build → Review → Success.
4. **Chat escalation:** customer ↔ bot → bot stuck → `needs` (escalation notification) → manager opens thread → replies/sends photo/quote → `replied` (or hand back → `bot`).
5. **Stock-in:** Stock → Stock in → (optionally Scan bill → OCR lines) → edit → Add to inventory → qty/value updated.
6. **Count:** Stock → Count → enter counts (live variance) → Finish count → variance logged.
7. **Role change (demo):** More → role switcher → nav + access recompute.

---

## 6. Build conventions (prototype, for reference)

React 18 + Babel standalone, pinned script tags. Split across `bytes-*.jsx`, each ending `Object.assign(window, {…})`; design tokens in `bytes-tokens.css`; strings in `bytes-i18n.jsx` (`makeT(lang)`); entry HTML loads **shared → i18n → data → cart → aiscan → screens → app**. Per-file uniquely-named style objects (never a bare `const styles`). Flex inputs set `min-width:0`. Components holding text inputs are hoisted to module scope (avoid remount-on-keystroke focus loss). Everything stays on the single 410×872 phone surface.

---

## 7. Backend integration checklist `[API]`

- [ ] Auth + role (Owner/Manager/Waiter), session → nav/access
- [ ] Menu CRUD + availability + universal delivery toggle
- [ ] Orders: list (filters: state/channel/date/search), create, state transitions, edit lines/discount/delivery info, **print dedup**
- [ ] Print jobs: KOT / token / bill (kitchen + Bluetooth receipt printers)
- [ ] Inventory: list, stock-in, count→variance, item history, suppliers; **bill OCR**
- [ ] Messenger bridge: chats, escalation webhook, manager reply→Messenger, hand-back
- [ ] Notifications: feed + realtime push for the 5 trigger types
- [ ] Staff: list, OTP invite, activate/deactivate; Audit log writes on void/refund/comp/discount
- [ ] Settings: delivery areas, discount presets, VAT, storefront slug/theme/media, auto-print, language
- [ ] Analytics: net sales, trend, revenue-by-category, product performance, channels/payments, dayparts, peak hours; advanced (forecast/unit-economics/cohort/basket) — all by range/channel/daypart
- [ ] Storefront publish to `<slug>.quickbytes.buzz`
