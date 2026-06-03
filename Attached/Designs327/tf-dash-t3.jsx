// Terafoods · Manage Mode — TIER 3 · RESTAURANT (Spice Garden)
//
// Full-service: 12-table floor, real alerts, quick utility actions. Owner +
// Manager roles diverge here; the top app bar carries the toggle.
//
//   1. Top app bar      · outlet [REST.] · time | Mgr|Owner | drawer
//   2. Open tickets bar · slim live strip with LATE count
//   3. Ring-up          · search + 9 tiles with category glyphs
//   4. Floor            · 12 tables, color = exception only
//   5. Needs you        · real, actionable rows
//   6. Quick actions    · KOT / Print / Settle / Call waiter — neutral
//   7. Today (demoted)  · collapsible
//   8. Sticky tray      · the ONE plum CTA

const Dash_T3_Full = () => {
  const [role, setRole] = React.useState('manager');
  return (
    <DashScreen navActive={2}>
      <DashTopBar
        outlet="Spice Garden · Gulshan 2"
        mode="Restaurant"
        time="8:14 PM · Mon 3 Jun"
        role={role} onRoleChange={setRole}
        drawer="৳42,180"
      />

      <OpenTicketsBar count={9} total="৳12,640" late={1} />

      <Section top={10}>
        <RingupSearch
          placeholder="Search item or scan code"
          recent={['Beef Tehari', 'Chicken Tikka', 'Naan']}
        />
      </Section>

      <Section top={14}>
        <FOHCounter
          title="Top sellers · tap to add"
          cols={3}
          tiles={[
            { n: 'Beef Tehari',    p: '৳450', cat: 'Rice',  glyph: 'bowl',      tint: 'oklch(0.55 0.18 30)',  qty: 2 },
            { n: 'Chicken Tikka',  p: '৳340', cat: 'Grill', glyph: 'drumstick', tint: 'oklch(0.65 0.18 35)' },
            { n: 'Mutton Roast',   p: '৳400', cat: 'Curry', glyph: 'bowl',      tint: 'oklch(0.55 0.18 30)' },
            { n: 'Borhani',        p: '৳50',  cat: 'Drink', glyph: 'glass',     tint: DASH.good },
            { n: 'Plain Rice',     p: '৳45',  cat: 'Rice',  glyph: 'bowl',      tint: DASH.inkRaised },
            { n: 'Naan',           p: '৳25',  cat: 'Bread', glyph: 'bread',     tint: 'oklch(0.78 0.12 75)',  qty: 1 },
            { n: 'Kacchi Biryani', p: '৳520', cat: 'Rice',  glyph: 'bowl',      tint: 'oklch(0.55 0.18 30)' },
            { n: 'Chicken Curry',  p: '৳280', cat: 'Curry', glyph: 'drumstick', tint: 'oklch(0.55 0.18 30)' },
            { n: 'Salad',          p: '৳60',  cat: 'Side',  glyph: 'leaf',      tint: DASH.good }
          ]}
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
        <CollapsedSummary cash="৳42,180" orders="88" top="Chicken Biryani · ×22" />
      </Section>

      <Section top={10}>
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
