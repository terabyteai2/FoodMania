# Terafoods — Owner App (Phase 1)
# Build prompt for Claude Code

## What you're building

The owner-side of **Terafoods**, a restaurant POS for tier 2/3 restaurants in Bangladesh. The owner is older, not tech-fluent, and worried about two things above all: **money that didn't come in** and **stock that walked out the back door** (wastage + theft). Every screen must answer "did money come in?" or "is anything wrong?" in under one second.

Phase 1 = two surfaces:
1. **Dashboard** (home tab) — combines the "Money first" hero + the "Live control tower" attention list
2. **Inventory** (Stock tab) — list with inline +IN / −OUT chips, quick-edit drawer with draggable qty meter, multi-item Used-stock entry, item detail with movement timeline, daily report with variance as the hero.

Everything else (Orders, Menu, Settings, Onboarding) is out of scope for this pass — render a "coming soon" placeholder if navigated to.

## Stack

- **Next.js 14** (App Router) + **TypeScript**
- **Tailwind CSS** (configure theme tokens below)
- **shadcn/ui** for sheet/dialog/segmented-control primitives
- **Framer Motion** for the drawer + scrubber gestures
- **Zustand** for app state (no Redux)
- Mock all data — JSON files in `/data/*.json`, no real backend
- Mobile-first PWA, target viewport 320–420 px wide

## Design tokens

Add these to `tailwind.config.ts`:

| Token | Value | Use |
|---|---|---|
| `paper` | #FFFFFF | app background |
| `paper-2` | #FAF7EF | card background (warm) |
| `paper-3` | #F2EDDD | chip / raised surface |
| `hairline` | #E5DDC8 | 1px borders |
| `ink` | #171513 | titles, primary text, primary buttons |
| `ink-2` | #5B5650 | body text |
| `ink-3` | #9A9388 | captions, placeholder |
| `brand` | #F4C534 | accent (yellow) |
| `late` | #E88060 | variance / theft / late state |
| `late-tint` | #FBE4DC | late background tint |
| `ok` | #7BB47C | served / matched state |
| `ok-tint` | #E6F1E1 | ok background tint |

Fonts (Google Fonts):
- **Kalam** — display / headings (warmth, "hospitality" voice)
- **Inter** — numbers, UI, body
- **Hind Siliguri** — Bangla text (always paired with English)
- **JetBrains Mono** — timestamps, IDs, prices in tables

Currency: **৳** (Bangladeshi Taka). No decimals on totals. Decimals OK for kg / quantities.

## Pages

### `/` — Dashboard (owner home)

A single scrollable screen combining two psychological levers:

1. **Greeting** — "Good evening, Karim bhai 👋" + owner avatar top-right
2. **Hero earnings card** — today's revenue as the dominant number ("৳42,180"), brand-yellow delta chip ("▲ 12% vs yesterday"), sparkline of the last 12 hours, cash/card/online breakdown with horizontal value bars
3. **4-up mini-KPIs** — orders / open / avg / profit % (small cards in a row, no chartjunk)
4. **Live "Needs your eye" section** — surfaces what's broken right now:
   - **Late** order (Table N, time elapsed) → `[Check]` CTA
   - **Low stock** item (qty left + days of cover) → `[Reorder]` CTA
   - **Waiter offline** (last seen Xm ago) → `[Call]` CTA
   - Use the `late` color on the LATE chip; keep other chips neutral.
5. **Top movers** — 3 items with horizontal % bars
6. **Sticky close-day CTA at the bottom** (dark, full-bleed) — "Close today · ৳42,180"

The hero is the emotional spike. Don't let the live alerts steal its visual weight — alerts are a list, not a panel of red.

### `/inventory` — Inventory home (Stock tab)

1. **Header** — title + search + sort icons
2. **Stock-value strip** — left: "STOCK VALUE NOW · ৳68,400" — right: "VARIANCE TODAY · −৳340 [2 items]". Variance number in the late color. **Variance is the headline of inventory, not stock value.**
3. **Filter tabs** — All / Raw / Dry / Packaged, pill-style segmented
4. **Item rows** — each row is two stacked parts:
   - Top: thumbnail · name (EN) · name (BN) · on-hand qty · variance chip (OK / −0.3 / LOW)
   - Bottom (the new bit): two inline chips — `+IN +15` (green-tinted) and `−USED −2.6` (neutral) — both tappable. Tap opens the **Quick-edit drawer** in the corresponding mode.
   - Whole row also tappable → item detail.
5. **Dual FAB stack** (bottom-right, above the nav):
   - Smaller secondary: `− Used stock` (paper bg, ink border) → opens `/inventory/out`
   - Larger primary: `+ Stock in` (brand-yellow) → opens `/inventory/in`

### Quick-edit drawer (bottom sheet)

Triggered from any +IN or −USED chip on the inventory home. Rendered as a Sheet from `shadcn/ui`, snapping to ~70% height.

- **Item header**: thumbnail + name + "on hand 12.4 kg · ৳420/kg" + close ✕
- **Segmented control**: `+ Stock IN` | `− USED` (defaults to whichever chip was tapped)
- **QtyMeter** (the draggable scrubber — see component spec below)
- **Contextual field**:
  - IN mode → "FROM SUPPLIER" dropdown + auto-calculated COST
  - USED mode → reason chips (Kitchen / Staff meal / Spoiled / Sample / Other), required
- **Sticky bottom CTA** — dark bar showing "NEW ON-HAND · 16.4 kg" on the left, brand-yellow `Save` button on the right

### `/inventory/in` — Stock In (full screen)

For when the owner is receiving a delivery (more deliberate than the drawer). Supplier + date header. Big "Scan supplier bill" CTA (stub the AI — just open a fake camera state for now). Multi-item rows with qty/price/total cards. Total at bottom. Save.

### `/inventory/out` — Used stock (full screen, multi-item)

The new bit. Used for logging multiple items used by the kitchen / staff at end of day, or mid-shift wastage.

- **Reason selector** at top — chips: Kitchen (default selected) / Staff meal / Spoiled / Sample / Other. Selecting one applies to all items in this entry (but each item can override).
- **Item rows** — each row has:
  - Item header (thumb · name · on-hand) and the current qty displayed large on the right (e.g. `− 2.5 kg`)
  - A **compact horizontal scrubber** inline (no presets, just the track + handle in the `late` color)
- **+ Add another item** dashed-border row at the end
- **Sticky total** at bottom — "TOTAL USED · VALUE · ৳1,562 · 7.7 kg" + dark Save CTA
- Saving creates a Movement per item with kind=OUT, reason=<the selected reason>, by=<current user>.

### `/inventory/[id]` — Item detail

- Hero card: on-hand qty (big), par level + days of cover, unit price + value
- 7-day in/out mini bar chart (green bars in, paper bars out)
- "MOVEMENTS · TODAY" timeline — each entry: timestamp · color-coded rail · what happened · who did it (Karim, Rahim, "auto" for orders) · qty/cost delta. Tap to expand.
- "MOVEMENTS · FULL HISTORY ›" link
- Bottom action row: `Adjust count` (paper) + `Mark as waste` (ink)

### `/inventory/report/today` — Daily report

- **Hero: variance** — late-tint card with "UNEXPLAINED VARIANCE · TODAY · −৳340 across 2 items" + recurring-pattern callout ("Onion is short 4 days this week. Flag Rahim's shifts?")
- 4-up totals row — Opening / Stock in / Used / Closing
- **Variance breakdown** — per-item card with expected vs counted vs diff vs cost; chips for items with recurring patterns (e.g. "4× this week")
- **Reorder hint** — brand-yellow pill at the bottom for any items below par
- Share button in the header — exports a clean PNG of the report to WhatsApp (use `html-to-image`)

## QtyMeter component

The draggable horizontal scrubber. This is the most important UI primitive in inventory — every quantity input uses it.

```ts
type QtyMeterProps = {
  value: number;
  onChange: (v: number) => void;
  unit: string;                       // 'kg' | 'pcs' | 'L' | 'g' | ...
  min?: number;                       // default 0
  max?: number;                       // default = max(value * 2, 25)
  step?: number;                      // default 0.1
  mode: 'in' | 'out';                 // controls accent color
  presets?: (string | number)[];      // default ['+1', '+5', '+10', '+25']
  size?: 'full' | 'compact';          // 'compact' = no value display, no presets
};
```

**Behavior**:
- Drag handle horizontally with touch/pointer events. Track scrolls so the caret stays centered on the live value.
- Snap to `step`. Show major ticks at integer values with number labels under them; minor ticks at every `step`.
- Tap the big number above to swap into a numeric keypad mode (use the iOS-style keypad component from shadcn or build one — see `/inventory/[id]` count flow).
- Preset chips below: tap = add that delta to the current value. "Half" and "Empty" are absolute (set to onHand/2 or 0).
- Keyboard: ← → adjusts by step, Shift+← → by 10× step.
- ARIA: role="slider", aria-valuemin/max/now, aria-label.
- Sausage-finger friendly: handle is 26 px circle, track 56 px tall (full), tap targets ≥ 44 px.

## Data models

```ts
type Item = {
  id: string;
  name_en: string;
  name_bn: string;
  unit: 'kg' | 'g' | 'L' | 'mL' | 'pcs';
  on_hand: number;
  par_level: number;
  unit_price: number;     // ৳ per unit, last paid
  category: 'raw' | 'dry' | 'packaged';
  photo_hue: number;      // 0–360, for the striped thumbnail placeholder
};

type Movement = {
  id: string;
  item_id: string;
  kind: 'IN' | 'OUT' | 'COUNT' | 'WASTE';
  qty: number;            // always positive; sign comes from kind
  unit_price?: number;    // for IN
  reason?: 'Kitchen' | 'Staff meal' | 'Spoiled' | 'Sample' | 'Other';  // for OUT
  supplier?: string;      // for IN
  bill_ref?: string;
  by: string;             // 'Karim (owner)' | 'Rahim (waiter)' | 'auto'
  notes?: string;
  ts: string;             // ISO
};

// For dashboard
type Order = {
  id: string;              // '#143'
  source: 'Table N' | 'Take-away' | 'Delivery';
  status: 'pending' | 'accepted' | 'late' | 'served';
  amount: number;
  items_count: number;
  age_seconds: number;
};

type Alert = {
  kind: 'late' | 'low' | 'offline';
  primary: string;
  secondary: string;
  cta: 'Check' | 'Reorder' | 'Call';
};
```

Compute on-hand on the fly from movements (don't store it as denormalized state) so the variance math is the difference between (opening + sum of IN − sum of OUT (kind=OUT/WASTE)) and the latest COUNT.

## Mock data

Seed `/data/items.json` with ~14 items reflecting a typical Bangladeshi restaurant: Chicken, Beef, Mutton, Onion, Rice (basmati), Potato, Tomato, Coriander, Cooking oil, Garam masala, Borhani mix, Yogurt, Sugar, Salt. Use realistic on-hand and par values.

Seed `/data/movements.json` with 30+ movements over the last 3 days, including:
- Stock-IN entries from "Razzak vai" and "Hossain meats"
- OUT entries by kitchen with reasons
- Two COUNT entries with negative variance on Onion (recurring on Rahim's shifts) and Potato

Seed `/data/orders.json` with 38 orders across the day, 4 currently in progress, 2 marked late.

Use names: **Karim (owner)**, **Rahim (waiter)**, **Babul (kitchen)**, **Razzak vai (supplier)**.

## Interactions to nail

1. **Quick-edit drawer must open in <100 ms** from a chip tap. Pre-warm the sheet component.
2. **Stock-out screen must accept 3–5 items in under 30 seconds.** Test this yourself.
3. **Every number on every screen is tappable to edit.** No "edit mode."
4. **The variance hero on the daily report should make the owner pause.** It must feel weighty — pull the eye there before anything else.
5. **Bilingual everywhere** — Bangla as supporting text, English shouts. Section labels show both, separated by · (middle dot).

## What NOT to build yet

- Real auth (mock current user as Karim, owner role)
- Supabase / Postgres / any backend — JSON files only
- AI receipt scanning (stub the button; show a fake camera-with-bill state then jump to extracted-items)
- Online order integrations (Foodpanda, Pathao)
- Push notifications
- Reports beyond Daily — Weekly/Monthly come later

## Aesthetic

- Light/paper feel. **Never** ship dark mode for this phase — the warmth is the brand.
- Yellow is for **accents only** — primary buttons, the active nav pill, the IN scrubber caret, badges on the hero card. Don't paint surfaces yellow.
- 1 px hairline borders at 14 px radius. **No shadows** in the main layout (drawers and FABs may use one).
- Numbers in Inter, headings and section heads in Kalam, Bangla in Hind Siliguri.
- One headline per screen — never two competing dominant numbers.

## Definition of done for Phase 1

- [ ] Dashboard renders with mock data and live "now" timestamps
- [ ] Inventory list scrolls with 14 items, inline chips work
- [ ] Quick-edit drawer opens from chips, QtyMeter is drag-functional, save updates the on-hand
- [ ] Used-stock multi-item screen saves 3 items in one round-trip
- [ ] Item detail timeline shows correct movements
- [ ] Daily report computes variance correctly from movements
- [ ] Mobile-first; no horizontal scroll on 320 px wide viewport
- [ ] Lighthouse mobile a11y score ≥ 95
