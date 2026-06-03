// Terafoods · Manage Mode — TIER 2 · Small dine-in (Cha Ghor)
// New structure per Dashboard_Inventory_Edits brief:
//   1. Unified top nav with Manager/Owner toggle
//   2. Totals header (Total Cash · Total Orders) — pay-method note (cash/card/mobile)
//   3. FOH Counter · 6 top sellers, 3 columns, with Edit
//   4. Floor · 3 cols
//   5. Needs you
//   6. Review zone — Hot Selling + Close day

const Dash_T2_Dinein = () => (
  <DashScreen navActive={2}>
    <TopNav title="Dashboard" role="manager" badge={1} />

    {/* 1 · Totals header */}
    <Section top={4}>
      <TotalsHeader cash="৳14,820" orders="42" sub="Cash · Card · Mobile pay" />
    </Section>

    {/* 2 · FOH Counter — 6 top sellers, 3 cols */}
    <Section top={18}>
      <FOHCounter
        title="Counter · top sellers"
        cols={3}
        tiles={[
          { emoji: '🍵', n: 'Milk Tea',  p: '৳30',  tint: '#EEEAE2', qty: 2 },
          { emoji: '🥟', n: 'Singara',    p: '৳20',  tint: '#FEF3D1' },
          { emoji: '🌶️', n: 'Samosa',    p: '৳30',  tint: '#FBE4DB', qty: 1 },
          { emoji: '🍋', n: 'Lemon Tea', p: '৳20',  tint: '#EAF4EE' },
          { emoji: '🍳', n: 'Egg Toast', p: '৳45',  tint: '#FEF1C5' },
          { emoji: '🧋', n: 'Cold Drink',p: '৳40',  tint: '#E8F4F0' }
        ]}
      />
    </Section>

    {/* 3 · Floor — 3 columns */}
    <Section top={22}>
      <SecHead title="Floor" action="3 of 6 busy" />
      <FloorMap
        cols={3}
        tables={[
          { n: 'T1', state: 'seated', cover: 2 },
          { n: 'T2', state: 'idle' },
          { n: 'T3', state: 'bill', cover: 4 },
          { n: 'T4', state: 'seated', cover: 3 },
          { n: 'T5', state: 'idle' },
          { n: 'T6', state: 'idle' }
        ]}
        legend={['idle', 'seated', 'bill']}
      />
    </Section>

    {/* 4 · Needs you */}
    <Section>
      <SecHead title="Needs you" count={1} />
      <AlertRow tag="LATE" tone="late" title="Table 3 · #84 · 24 min" sub="Cha + Singara · over the 20-min mark" cta="Check" />
    </Section>

    {/* ─── Review zone ─── */}
    <Section top={22}>
      <Divider label="Review" />
    </Section>

    <Section top={14}>
      <SecHead title="Hot Selling" action="See all" />
      <MoverRow rank={1} name="Milk Tea" qty={64} rev="৳1,920" pct={1} />
      <MoverRow rank={2} name="Singara"   qty={48} rev="৳960"   pct={0.5} />
      <MoverRow rank={3} name="Samosa"    qty={31} rev="৳930"   pct={0.48} />
    </Section>

    <Section top={14}>
      <div style={{ paddingBottom: 8 }}>
        <CloseCard amount="৳14,820" title="Close day · ৳14,820" kicker="End of day" warn="3 orders still open — settle before closing" />
      </div>
    </Section>

    <div style={{ height: 84 }} />

    <CreateOrderTray count={3} total="৳80" />
  </DashScreen>
);

Object.assign(window, { Dash_T2_Dinein });
