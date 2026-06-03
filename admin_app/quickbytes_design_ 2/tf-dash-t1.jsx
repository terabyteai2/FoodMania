// Terafoods · Manage Mode — TIER 1 · Counter (Lebu Fresh juice bar)
// New structure per Dashboard_Inventory_Edits brief:
//   1. Unified top nav (title + bell + settings + Manager/Owner toggle)
//   2. Totals header  · Total Cash + Total Orders
//   3. FOH Counter    · 6 top sellers, 3 columns, Edit button
//      → tapped tiles roll into a sticky "Create order · ৳total" CTA
//   4. Review zone    · Hot Selling list + Close day card

const T1_NAV = [
  { kind: 'home', label: 'Dashboard' },
  { kind: 'menu', label: 'Orders' },
  { kind: 'inventory', label: 'Inventory' },
  { kind: 'chart', label: 'Reports' },
  { kind: 'settings', label: 'More' }
];

const Dash_T1_Counter = () =>
<DashScreen nav={T1_NAV} navActive={0}>
    <TopNav title="Dashboard" role="manager" badge={null} />

    {/* 1 · Totals header */}
    <Section top={4}>
      <TotalsHeader cash="৳6,240" orders="38" sub="38 orders today" />
    </Section>

    {/* 2 · FOH Counter — 6 top sellers, 3 cols */}
    <Section top={18}>
      <FOHCounter
        title="Counter · top sellers"
        cols={3}
        tiles={[
          { emoji: '🍋', n: 'Lemon Mint',   p: '৳60',  qty: 2 },
          { emoji: '🥭', n: 'Mango Lassi',  p: '৳120', tint: '#FEF3D1', qty: 1 },
          { emoji: '🍊', n: 'Orange Fresh', p: '৳80',  tint: '#FCEEDC' },
          { emoji: '🥤', n: 'Sugarcane',    p: '৳50',  tint: '#E8F4F0' },
          { emoji: '☕', n: 'Cold Coffee',   p: '৳140', tint: '#EEEAE2' },
          { emoji: '🍉', n: 'Watermelon',   p: '৳70',  tint: '#FBE4DB' }
        ]}
      />
    </Section>

    {/* 3 · Review zone */}
    <Section top={24}>
      <Divider label="Today so far" />
    </Section>

    <Section top={12}>
      <SecHead title="Hot Selling" action="See all" />
      <MoverRow rank={1} name="Lemon Mint"  qty={18} rev="৳1,080" pct={1} />
      <MoverRow rank={2} name="Mango Lassi" qty={9}  rev="৳1,080" pct={0.92} />
      <MoverRow rank={3} name="Cold Coffee" qty={5}  rev="৳700"   pct={0.6} />
    </Section>

    <Section top={14}>
      <div style={{ paddingBottom: 8 }}>
        <CloseCard amount="৳6,240" title="Close counter · ৳6,240" kicker="End of day" warn="3 items left in current order — clear before closing" />
      </div>
    </Section>

    {/* spacer so the sticky tray doesn't cover the last card */}
    <div style={{ height: 84 }} />

    <CreateOrderTray count={3} total="৳240" />
  </DashScreen>;


Object.assign(window, { Dash_T1_Counter });
