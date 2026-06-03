// Terafoods · Manage Mode — TIER 1 · FOOD CART (Lebu Fresh juice bar)
//
// Manager (Counter / Home) — reclaim the top real estate. The whole reason
// this screen exists is to ring up chits. Top app bar is compact; the slim
// "open" strip is the live operational number; everything below the strip
// is ring-up, then takeaway, then a demoted today summary.
//
//   1. Top app bar      · outlet [MODE] · time | (no role toggle on T1) | drawer
//   2. Open tickets bar · slim one-line strip — manager's live number
//   3. Ring-up          · search + 9 text-first tiles with category glyphs
//   4. Open takeaway    · in-flight list (no floor map in Food Cart mode)
//   5. Today (demoted)  · collapsible
//   6. Sticky tray      · "Create order · ৳total" — the ONE plum CTA

const T1_NAV = [
  { kind: 'home',  label: 'Counter' },
  { kind: 'orders',label: 'Orders' },
  { kind: 'inventory', label: 'Stock' },
  { kind: 'chart', label: 'Reports' },
  { kind: 'settings', label: 'More' }
];

const Dash_T1_Counter = () => (
  <DashScreen nav={T1_NAV} navActive={0}>
    {/* 1 · Top app bar — no role toggle (single-operator mode) */}
    <DashTopBar
      outlet="Lebu Fresh · Dhanmondi"
      mode="Food cart"
      time="4:12 PM · Mon 3 Jun"
      drawer="৳6,240"
    />

    {/* 2 · Open tickets — slim live strip */}
    <OpenTicketsBar count={3} total="৳240" />

    {/* 3 · Ring-up — search + top sellers. Hero of the screen. */}
    <Section top={10}>
      <RingupSearch
        placeholder="Search item or scan code"
        recent={['Lemon Mint', 'Mango Lassi', 'Sugarcane']}
      />
    </Section>

    <Section top={14}>
      <FOHCounter
        title="Top sellers · tap to add"
        cols={3}
        tiles={[
          { n: 'Lemon Mint',    p: '৳60',  cat: 'Juice',   glyph: 'glass', tint: DASH.good,                                qty: 2 },
          { n: 'Mango Lassi',   p: '৳120', cat: 'Lassi',   glyph: 'glass', tint: 'oklch(0.78 0.12 75)',                    qty: 1 },
          { n: 'Orange Fresh',  p: '৳80',  cat: 'Juice',   glyph: 'glass', tint: DASH.good },
          { n: 'Sugarcane',     p: '৳50',  cat: 'Juice',   glyph: 'glass', tint: DASH.good },
          { n: 'Cold Coffee',   p: '৳140', cat: 'Coffee',  glyph: 'cup',   tint: DASH.inkRaised },
          { n: 'Watermelon',    p: '৳70',  cat: 'Juice',   glyph: 'glass', tint: 'oklch(0.65 0.18 25)' },
          { n: 'Pineapple',     p: '৳90',  cat: 'Juice',   glyph: 'glass', tint: 'oklch(0.78 0.12 75)' },
          { n: 'Faluda',        p: '৳160', cat: 'Dessert', glyph: 'cake',  tint: 'oklch(0.68 0.15 350)' },
          { n: 'Borhani',       p: '৳50',  cat: 'Drink',   glyph: 'glass', tint: DASH.textSec }
        ]}
      />
    </Section>

    {/* 4 · Open takeaway — list, not floor map */}
    <Section top={22}>
      <SecHead title="Open takeaway" count={3} accent={DASH.inkRaised} />
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <OpenTicketRow first tag="#42" who="Cash · counter"  items={2} total="৳180" age="2 min" />
        <OpenTicketRow       tag="#41" who="bKash · 8712"    items={1} total="৳60"  age="6 min" />
        <OpenTicketRow       tag="#40" who="Cash · counter"  items={3} total="৳230" age="11 min" />
      </DashCard>
    </Section>

    {/* 5 · Today summary — demoted, collapsible */}
    <Section top={14}>
      <CollapsedSummary cash="৳6,240" orders="38" top="Lemon Mint · ×18" />
    </Section>

    <Section top={10}>
      <CloseCard
        amount="৳6,240"
        title="Close counter"
        kicker="End of day"
        warn="1 ticket still open — settle before close"
      />
    </Section>

    <div style={{ height: 96 }} />

    {/* 6 · The ONE plum CTA in this viewport. */}
    <CreateOrderTray count={3} total="৳240" />
  </DashScreen>
);

Object.assign(window, { Dash_T1_Counter });
