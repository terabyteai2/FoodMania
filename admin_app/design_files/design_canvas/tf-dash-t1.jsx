// Terafoods · Manage Mode — TIER 1 · FOOD CART (Lebu Fresh juice bar)
//
// Counter-first home. Hierarchy per the brief:
//   1. Top app bar      · outlet [MODE] · time | drawer
//   2. Open tickets bar · slim live operational number
//   3. Quick sell       · 4×3 ring-up grid, single-line names, Edit shortcut  ← hero
//   4. Sales card       · total sales + total orders
//   5. Peak hours       · single-line volume chart, accent-wash fill
//   6. Open takeaway    · in-flight list
//   7. Close            · end of day
//   8. Sticky tray      · "Create order · ৳total" — the ONE plum CTA

const T1_NAV = [
  { kind: 'home',  label: 'Counter' },
  { kind: 'orders',label: 'Orders' },
  { kind: 'inventory', label: 'Stock' },
  { kind: 'chart', label: 'Reports' },
  { kind: 'settings', label: 'More' }
];

const Dash_T1_Counter = () => (
  <DashScreen nav={T1_NAV} navActive={0}>
    {/* 1 · Uniform top nav — heading + sub on left, mode dial + bell on right */}
    <UnifiedTopNav
      title="Dashboard"
      sub="Lebu Fresh · Dhanmondi"
      mode="foodcart"
      badge={1}
    />

    {/* 2 · Open tickets — slim live strip */}
    <OpenTicketsBar count={3} total="৳240" />

    {/* 3 · Quick sell — 4×3 ring-up grid. Hero of the screen. */}
    <Section top={12}>
      <FOHCounter
        title="Quick sell · tap to ring up"
        cols={4}
        clamp={1}
        tiles={[
          { n: 'Lemon Mint',   p: '৳60',  glyph: 'glass',     qty: 2 },
          { n: 'Mango Lassi',  p: '৳120', glyph: 'glass',     qty: 1 },
          { n: 'Orange Fresh', p: '৳80',  glyph: 'glass' },
          { n: 'Sugarcane',    p: '৳50',  glyph: 'glass' },
          { n: 'Cold Coffee',  p: '৳140', glyph: 'cup' },
          { n: 'Watermelon',   p: '৳70',  glyph: 'glass' },
          { n: 'Pineapple',    p: '৳90',  glyph: 'glass' },
          { n: 'Faluda',       p: '৳160', glyph: 'cake' },
          { n: 'Borhani',      p: '৳50',  glyph: 'glass' },
          { n: 'Lemon Soda',   p: '৳40',  glyph: 'glass' },
          { n: 'Green Mango',  p: '৳70',  glyph: 'glass' },
          { n: 'Singara',      p: '৳15',  glyph: 'cookie' }
        ]}
      />
    </Section>

    {/* 4 · Sales card — total sales + total orders */}
    <Section top={22}>
      <TotalsHeader cash="৳6,240" orders="38" sub="Lemon Mint · top seller ×18" />
    </Section>

    {/* 5 · Peak hours — single-line volume, accent-wash fill */}
    <Section top={14}>
      <PeakHoursCard
        peakNote="Busiest 5–7 PM"
        data={[4, 7, 9, 14, 18, 11]}
        xLabels={['11A', '1P', '3P', '5P', '7P', '9P']}
      />
    </Section>

    {/* 6 · Open takeaway — list, not floor map */}
    <Section top={22}>
      <SecHead title="Open takeaway" count={3} accent={DASH.inkRaised} />
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <OpenTicketRow first tag="#42" who="Cash · counter"  items={2} total="৳180" age="2 min" />
        <OpenTicketRow       tag="#41" who="bKash · 8712"    items={1} total="৳60"  age="6 min" />
        <OpenTicketRow       tag="#40" who="Cash · counter"  items={3} total="৳230" age="11 min" />
      </DashCard>
    </Section>

    {/* 7 · Close */}
    <Section top={14}>
      <CloseCard
        amount="৳6,240"
        title="Close counter"
        kicker="End of day"
        warn="1 ticket still open — settle before close"
      />
    </Section>

    <div style={{ height: 96 }} />

    {/* 8 · The ONE plum CTA in this viewport. */}
    <CreateOrderTray count={3} total="৳240" />
  </DashScreen>
);

Object.assign(window, { Dash_T1_Counter });
