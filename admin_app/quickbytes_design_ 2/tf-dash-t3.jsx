// Terafoods · Manage Mode — TIER 3 · Full-service (Spice Garden)
// New structure per Dashboard_Inventory_Edits brief:
//   1. Top nav with Manager/Owner toggle
//   2. Totals header (Total Cash · Total Orders)
//   3. Right now (live snapshot — T3 only)
//   4. FOH Counter · 6 top sellers, 3 cols, with Edit
//   5. Needs you · Quick actions
//   6. Review zone — channel split + Hot Selling + Close shift

const Dash_T3_Full = () => (
  <DashScreen navActive={2}>
    <TopNav title="Dashboard" role="manager" badge={3} />

    {/* 1 · Totals header */}
    <Section top={4}>
      <TotalsHeader cash="৳42,180" orders="88" sub="Cash · Card · Mobile pay" />
    </Section>

    {/* 2 · Right now — live snapshot */}
    <Section top={18}>
      <SecHead title="Right now" />
      <TowerRow tiles={[
        { value: '7',  vsub: '/12', sub: 'Tables seated', tone: 'amber' },
        { value: '4',              sub: 'In kitchen',    tone: 'paper' },
        { value: '2',              sub: 'Late > 20m',    tone: 'coral' }
      ]} />
    </Section>

    {/* 3 · FOH Counter — 6 top sellers, 3 cols */}
    <Section top={18}>
      <FOHCounter
        title="Counter · top sellers"
        cols={3}
        tiles={[
          { emoji: '🍛', n: 'Beef Tehari',   p: '৳450', tint: '#FBE4DB', qty: 2 },
          { emoji: '🍗', n: 'Chicken Tikka', p: '৳340', tint: '#FEF3D1' },
          { emoji: '🍖', n: 'Mutton Roast',  p: '৳400', tint: '#FBE4DB' },
          { emoji: '🥗', n: 'Borhani',       p: '৳50',  tint: '#E8F4F0' },
          { emoji: '🍚', n: 'Plain Rice',    p: '৳45',  tint: '#FEF1C5' },
          { emoji: '🫓', n: 'Naan',          p: '৳25',  tint: '#EEEAE2', qty: 1 }
        ]}
      />
    </Section>

    {/* 4 · Needs you */}
    <Section>
      <SecHead title="Needs you" count={2} />
      <AlertRow tag="LATE" tone="late" title="Table 6 · #137" sub="48 min waiting · Beef Tehari ×2" cta="Check" />
      <AlertRow tag="LOW"  tone="low"  title="Mutton stock · 0.8 kg left" sub="~3 more orders at today's pace" cta="Reorder" />
    </Section>

    {/* 5 · Quick actions */}
    <Section>
      <QuickActions actions={[
        { icon: 'printer', t: 'Print bill' },
        { icon: 'bell',    t: 'Call waiter' },
        { icon: 'chart',   t: 'Reports' }
      ]} />
    </Section>

    {/* ─── Review zone ─── */}
    <Section top={22}>
      <Divider label="Review" />
    </Section>

    <Section top={14}>
      <SecHead title="Where it came from" />
      <ChannelSplit rows={[
        { l: 'Dine-in',  v: '৳27.0k', pct: 64, accent: DASH.accent },
        { l: 'Takeaway', v: '৳9.3k',  pct: 22, accent: DASH.ink },
        { l: 'Delivery', v: '৳5.9k',  pct: 14, accent: DASH.late }
      ]} />
    </Section>

    <Section>
      <SecHead title="Hot Selling" action="See all" />
      <MoverRow rank={1} name="Chicken Biriyani" qty={22} rev="৳5,280" pct={1}    share="13%" />
      <MoverRow rank={2} name="Beef Tehari"      qty={12} rev="৳3,360" pct={0.64} share="8%" />
    </Section>

    <Section top={14}>
      <div style={{ paddingBottom: 8 }}>
        <CloseCard amount="৳42,180" title="Close shift · hand over to night" kicker="Shift handover · ৳42,180" warn="9 open orders carry to next shift" />
      </div>
    </Section>

    <div style={{ height: 84 }} />

    <CreateOrderTray count={3} total="৳925" />
  </DashScreen>
);

Object.assign(window, { Dash_T3_Full });
