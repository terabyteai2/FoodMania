// Terafoods · Manage Mode — TIER 3 · RESTAURANT (Spice Garden)
//
// Full-service. Counter-first hierarchy, with a live ops trio (pending /
// booked / late) sitting between the sales card and the peak-hours chart.
//
//   1. Top app bar      · outlet [REST.] · time | Mgr|Owner | drawer
//   2. Open tickets bar · slim live strip with LATE count
//   3. Quick sell       · 4×3 ring-up grid, single-line names, Edit shortcut  ← hero
//   4. Sales card       · total sales + total orders
//   5. Ops trio         · pending orders · booked tables · late orders
//   6. Peak hours       · single-line volume chart, accent-wash fill
//   7. Floor            · 12 tables, color = exception only
//   8. Needs you        · real, actionable rows
//   9. Quick actions    · KOT / Print / Settle / Reports — neutral
//  10. Close            · shift handover
//  11. Sticky tray      · the ONE plum CTA

const Dash_T3_Full = () => {
  return (
    <DashScreen navActive={2}>
      <UnifiedTopNav
        title="Dashboard"
        sub="Spice Garden · Gulshan 2"
        mode="restaurant"
        badge={3}
      />

      <OpenTicketsBar count={9} total="৳12,640" late={1} />

      {/* 3 · Quick sell — 4×3 ring-up grid. Hero of the screen. */}
      <Section top={12}>
        <FOHCounter
          title="Quick sell · tap to ring up"
          cols={4}
          clamp={1}
          tiles={[
            { n: 'Beef Tehari',    p: '৳450', glyph: 'bowl',      qty: 2 },
            { n: 'Chicken Tikka',  p: '৳340', glyph: 'drumstick' },
            { n: 'Mutton Roast',   p: '৳400', glyph: 'bowl' },
            { n: 'Borhani',        p: '৳50',  glyph: 'glass' },
            { n: 'Plain Rice',     p: '৳45',  glyph: 'bowl' },
            { n: 'Naan',           p: '৳25',  glyph: 'bread',     qty: 1 },
            { n: 'Kacchi Biryani', p: '৳520', glyph: 'bowl' },
            { n: 'Chicken Curry',  p: '৳280', glyph: 'drumstick' },
            { n: 'Salad',          p: '৳60',  glyph: 'leaf' },
            { n: 'Beef Bhuna',     p: '৳380', glyph: 'bowl' },
            { n: 'Dal',            p: '৳90',  glyph: 'bowl' },
            { n: 'Borhani Jug',    p: '৳180', glyph: 'glass' }
          ]}
        />
      </Section>

      {/* 4 · Sales card — total sales + total orders */}
      <Section top={22}>
        <TotalsHeader cash="৳42,180" orders="88" sub="Chicken Biryani · top seller ×22" />
      </Section>

      {/* 5 · Ops trio — pending / booked / late, before the chart */}
      <Section top={14}>
        <TowerRow tiles={[
          { value: '9', sub: 'Pending orders', tone: 'amber' },
          { value: '4', sub: 'Booked tables',  tone: 'paper' },
          { value: '1', sub: 'Late orders',    tone: 'coral' }
        ]} />
      </Section>

      {/* 6 · Peak hours — single-line volume, accent-wash fill */}
      <Section top={14}>
        <PeakHoursCard
          peakNote="Busiest 8–9 PM"
          data={[10, 18, 34, 42, 20]}
          xLabels={['3P', '5P', '7P', '9P', '11P']}
        />
      </Section>

      <Section top={22}>
        <SecHead title="Floor" action="9 of 12 busy" />
        <FloorMap
          cols={4}
          dur
          tables={[
            { n: 'T1',  state: 'seated',  cover: 2, dur: '24m' },
            { n: 'T2',  state: 'kitchen', cover: 4, dur: '12m' },
            { n: 'T3',  state: 'bill',    cover: 3, dur: '48m' },
            { n: 'T4',  state: 'idle' },
            { n: 'T5',  state: 'seated',  cover: 5, dur: '8m'  },
            { n: 'T6',  state: 'late',    cover: 4, dur: '48m' },
            { n: 'T7',  state: 'kitchen', cover: 2, dur: '14m' },
            { n: 'T8',  state: 'idle' },
            { n: 'T9',  state: 'served',  cover: 6, dur: '62m' },
            { n: 'T10', state: 'seated',  cover: 3, dur: '4m'  },
            { n: 'T11', state: 'kitchen', cover: 2, dur: '18m' },
            { n: 'T12', state: 'idle' }
          ]}
          legend={['idle', 'seated', 'kitchen', 'bill', 'late']}
        />
      </Section>

      <Section top={18}>
        <SecHead title="Needs you" count={2} />
        <AlertRow
          tag="LATE" tone="late"
          title="T6 · #137 · 48 min"
          sub="Beef Tehari ×2 — kitchen confirmed delay"
          cta="Check"
        />
        <AlertRow
          tag="LOW"  tone="low"
          title="Mutton stock · 0.8 kg left"
          sub="~3 more orders at today's pace — auto-reorder ready"
          cta="Reorder"
        />
      </Section>

      <Section top={14}>
        <QuickActions actions={[
          { icon: 'printer', t: 'Print KOT' },
          { icon: 'printer', t: 'Print bill' },
          { icon: 'bell',    t: 'Call waiter' },
          { icon: 'chart',   t: 'Reports' }
        ]} />
      </Section>

      <Section top={18}>
        <CloseCard
          amount="৳42,180"
          title="Hand over to night shift"
          kicker="Shift handover"
          warn="9 open orders will carry over"
        />
      </Section>

      <div style={{ height: 96 }} />

      <CreateOrderTray count={3} total="৳925" />
    </DashScreen>
  );
};

Object.assign(window, { Dash_T3_Full });
