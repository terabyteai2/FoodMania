// Terafoods · Manage Mode — TIER 2 · CAFE (Cha Ghor)
//
// Cafe Mode adds floor management + shift attribution. Counter-first hierarchy
// matches T1; floor + alerts sit below the analytics block.
//
//   1. Top app bar      · outlet [CAFE] · time | Mgr|Owner | drawer
//   2. Open tickets bar · slim live strip
//   3. Quick sell       · 4×3 ring-up grid, single-line names, Edit shortcut  ← hero
//   4. Sales card       · total sales + total orders
//   5. Peak hours       · single-line volume chart, accent-wash fill
//   6. Floor            · 6 tables, neutral occupied state, color = exception
//   7. Needs you        · only real, actionable rows
//   8. Close            · end of day
//   9. Sticky tray      · the ONE plum CTA

const Dash_T2_Dinein = () => {
  return (
    <DashScreen navActive={2}>
      <UnifiedTopNav
        title="Dashboard"
        sub="Cha Ghor · Dhanmondi 27"
        mode="cafe"
        badge={2}
      />

      <OpenTicketsBar count={5} total="৳1,420" />

      {/* 3 · Quick sell — 4×3 ring-up grid. Hero of the screen. */}
      <Section top={12}>
        <FOHCounter
          title="Quick sell · tap to ring up"
          cols={4}
          clamp={1}
          tiles={[
            { n: 'Milk Tea',   p: '৳30', glyph: 'cup',    qty: 2 },
            { n: 'Singara',    p: '৳20', glyph: 'cookie' },
            { n: 'Samosa',     p: '৳30', glyph: 'cookie', qty: 1 },
            { n: 'Lemon Tea',  p: '৳20', glyph: 'cup' },
            { n: 'Egg Toast',  p: '৳45', glyph: 'cookie' },
            { n: 'Cold Drink', p: '৳40', glyph: 'glass' },
            { n: 'Coffee',     p: '৳50', glyph: 'cup' },
            { n: 'Paratha',    p: '৳25', glyph: 'bread' },
            { n: 'Borhani',    p: '৳35', glyph: 'glass' },
            { n: 'Special Cha',p: '৳25', glyph: 'cup' },
            { n: 'Naan',       p: '৳20', glyph: 'bread' },
            { n: 'Cake Slice', p: '৳60', glyph: 'cake' }
          ]}
        />
      </Section>

      {/* 4 · Sales card — total sales + total orders */}
      <Section top={22}>
        <TotalsHeader cash="৳14,820" orders="42" sub="Milk Tea · top seller ×64" />
      </Section>

      {/* 5 · Peak hours — single-line volume, accent-wash fill */}
      <Section top={14}>
        <PeakHoursCard
          peakNote="Busiest 4–6 PM"
          data={[8, 12, 9, 15, 22, 14]}
          xLabels={['9A', '11A', '1P', '3P', '5P', '7P']}
        />
      </Section>

      <Section top={22}>
        <SecHead title="Floor" action="3 of 6 busy" />
        <FloorMap
          cols={3}
          dur
          tables={[
            { n: 'T1', state: 'seated',  cover: 2, dur: '18m' },
            { n: 'T2', state: 'idle' },
            { n: 'T3', state: 'bill',    cover: 4, dur: '42m' },
            { n: 'T4', state: 'seated',  cover: 3, dur: '8m'  },
            { n: 'T5', state: 'idle' },
            { n: 'T6', state: 'idle' }
          ]}
          legend={['idle', 'seated', 'bill']}
        />
      </Section>

      <Section top={18}>
        <SecHead title="Needs you" count={1} />
        <AlertRow
          tag="LATE" tone="late"
          title="T3 · #84 · 24 min"
          sub="Cha + Singara — past the 20-min mark"
          cta="Check"
        />
      </Section>

      <Section top={14}>
        <CloseCard
          amount="৳14,820"
          title="Close day"
          kicker="End of day"
          warn="3 orders still open — settle before closing"
        />
      </Section>

      <div style={{ height: 96 }} />

      <CreateOrderTray count={3} total="৳80" />
    </DashScreen>
  );
};

Object.assign(window, { Dash_T2_Dinein });
