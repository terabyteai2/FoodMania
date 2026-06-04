// Terafoods · Manage Mode — TIER 2 · CAFE (Cha Ghor)
//
// Cafe Mode adds floor management + shift attribution. Top app bar gets a
// Manager/Owner toggle now that two distinct people read this screen. Floor
// is the second pillar; ring-up still leads.
//
//   1. Top app bar      · outlet [CAFE] · time | Mgr|Owner | drawer
//   2. Open tickets bar · slim live strip
//   3. Ring-up          · search + tiles with glyphs
//   4. Floor            · 6 tables, neutral occupied state, color = exception
//   5. Needs you        · only real, actionable rows
//   6. Today (demoted)  · collapsible
//   7. Sticky tray      · the ONE plum CTA

const Dash_T2_Dinein = () => {
  const [role, setRole] = React.useState('manager');
  return (
    <DashScreen navActive={2}>
      <DashTopBar
        outlet="Cha Ghor · Dhanmondi 27"
        mode="Cafe"
        time="2:48 PM · Mon 3 Jun"
        role={role} onRoleChange={setRole}
        drawer="৳14,820"
      />

      <OpenTicketsBar count={5} total="৳1,420" />

      <Section top={10}>
        <RingupSearch
          placeholder="Search item or scan code"
          recent={['Milk Tea', 'Singara', 'Lemon Tea']}
        />
      </Section>

      <Section top={14}>
        <FOHCounter
          title="Top sellers · tap to add"
          cols={3}
          tiles={[
            { n: 'Milk Tea',    p: '৳30', cat: 'Tea',     glyph: 'cup',    tint: DASH.inkRaised,         qty: 2 },
            { n: 'Singara',     p: '৳20', cat: 'Snack',   glyph: 'cookie', tint: 'oklch(0.65 0.18 35)' },
            { n: 'Samosa',      p: '৳30', cat: 'Snack',   glyph: 'cookie', tint: 'oklch(0.65 0.18 35)', qty: 1 },
            { n: 'Lemon Tea',   p: '৳20', cat: 'Tea',     glyph: 'cup',    tint: DASH.inkRaised },
            { n: 'Egg Toast',   p: '৳45', cat: 'Snack',   glyph: 'cookie', tint: 'oklch(0.78 0.12 75)' },
            { n: 'Cold Drink',  p: '৳40', cat: 'Drink',   glyph: 'glass',  tint: DASH.good },
            { n: 'Coffee',      p: '৳50', cat: 'Coffee',  glyph: 'cup',    tint: DASH.inkRaised },
            { n: 'Paratha',     p: '৳25', cat: 'Bread',   glyph: 'bread',  tint: 'oklch(0.65 0.18 35)' },
            { n: 'Borhani',     p: '৳35', cat: 'Drink',   glyph: 'glass',  tint: DASH.good }
          ]}
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

      <Section top={18}>
        <CollapsedSummary cash="৳14,820" orders="42" top="Milk Tea · ×64" />
      </Section>

      <Section top={10}>
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
