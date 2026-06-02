// Terafoods · Dashboard · REVIEW (Owner) — ADVANCED (Spice Garden)
// New structure per Dashboard_Inventory_Edits brief:
//   1. Unified top nav with Manager/Owner toggle (Owner)
//   2. Totals header — Total Cash + Total Orders
//   3. Staff today
//   4. KPI strip — Covers / Avg ticket / Food cost
//   5. Revenue by hour
//   6. Hot Selling (renamed from "What sold")
//   7. By source — 3-chip row

const MarginCallout = ({ text }) => (
  <div style={{
    marginTop: 8,
    padding: '11px 14px',
    background: RDASH.warnSoft,
    borderRadius: 10,
    border: `1px solid ${RDASH.warn}28`,
    display: 'flex', alignItems: 'flex-start', gap: 10,
  }}>
    <div style={{
      width: 6, height: 6, borderRadius: 3,
      background: RDASH.warn, marginTop: 5, flexShrink: 0,
    }} />
    <span style={{
      fontSize: 12.5, color: RDASH.ink,
      lineHeight: 1.5, fontWeight: 600,
    }}>{text}</span>
  </div>
);

const SourceChips = ({ rows }) => (
  <div style={{ display: 'flex', gap: 8 }}>
    {rows.map((r, i) => (
      <div key={i} style={{
        flex: 1, padding: '11px 12px',
        background: RDASH.surface,
        border: `1px solid ${RDASH.border}`,
        borderRadius: 12,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginBottom: 6 }}>
          <span style={{ width: 6, height: 6, borderRadius: 3, background: r.color, flexShrink: 0 }} />
          <span style={{ fontSize: 11, color: RDASH.textSec, fontWeight: 600 }}>{r.l}</span>
        </div>
        <div style={{ fontSize: 14, fontWeight: 600, color: RDASH.text, ...RDASH.num }}>{r.value}</div>
        <div style={{
          fontSize: 10.5, color: RDASH.textTer, marginTop: 3,
          fontFamily: RDASH.mono, fontWeight: 600, ...RDASH.num,
        }}>{r.pct}</div>
      </div>
    ))}
  </div>
);

const Review_Advanced = () => (
  <DashScreen navActive={2}>
    <TopNav title="Dashboard" role="owner" badge={2} />

    {/* 1 · Totals header */}
    <Section top={4}>
      <TotalsHeader cash="৳42,380" orders="88" sub="Cash · Card · Mobile pay" />
    </Section>

    {/* 2 · Staff today — accent wash card framing the day-end pulse */}
    <Section top={18}>
      <SecHead title="Staff today" action="6 on shift" />
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <StaffScoreRow first rank={1} name="Anwar"  role="Waiter" covers={64} ticket="৳780" time="6h 14m" mistakes={0} />
        <StaffScoreRow       rank={2} name="Salim"  role="Waiter" covers={52} ticket="৳712" time="6h 04m" mistakes={1} />
        <StaffScoreRow       rank={3} name="Rashed" role="Waiter" covers={48} ticket="৳694" time="6h 14m" mistakes={0} />
        <StaffScoreRow       rank={4} name="Jasim"  role="Waiter" covers={36} ticket="৳684" time="5h 22m" mistakes={2} />
      </DashCard>
    </Section>

    {/* 3 · KPI strip */}
    <Section top={14}>
      <KpiStrip stats={[
        { l: 'Covers',     v: '218' },
        { l: 'Avg ticket', v: '৳724' },
        { l: 'Food cost',  v: '32%' },
      ]} />
    </Section>

    {/* 4 · Revenue by hour */}
    <Section top={14}>
      <SecHead title="Revenue by hour" action="7-day" />
      <HourlyCard
        title="Today vs 7-day average"
        today={[80, 140, 280, 520, 840, 1280, 1180, 740, 520, 640, 1080, 1820, 2240, 1860, 1240]}
        yesterday={[60, 120, 240, 460, 760, 1180, 1080, 680, 480, 580, 980, 1640, 1980, 1640, 1080]}
        peakHour={12}
        peakLabel="8:00 PM · ৳2,240"
        hasGhost
      />
    </Section>

    {/* 5 · Hot Selling — renamed from "What sold" */}
    <Section top={14}>
      <SecHead title="Hot Selling" />
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <TopItemRow first rank={1} name="Beef Tehari"    qty={42} rev="৳18,900" margin="৳12,180" foodCost={26} />
        <TopItemRow       rank={2} name="Chicken Tikka"  qty={36} rev="৳12,240" margin="৳7,580"  foodCost={31} />
        <TopItemRow       rank={3} name="Mutton Roast"   qty={28} rev="৳11,200" margin="৳5,620"  foodCost={42} warnLabel="low margin" />
        <TopItemRow       rank={4} name="Plain Rice"     qty={92} rev="৳4,140"  margin="৳2,940"  foodCost={22} />
        <TopItemRow       rank={5} name="Borhani"        qty={68} rev="৳3,400"  margin="৳1,920"  foodCost={28} />
      </DashCard>
      <MarginCallout text="Mutton Roast sells big but margin is thin (FC 42%). Worth a look." />
    </Section>

    {/* 6 · By source */}
    <Section top={14}>
      <SecHead title="By source" />
      <SourceChips rows={[
        { l: 'Cash',   value: '৳18,420', pct: '43%', color: RDASH.accent },
        { l: 'Card',   value: '৳14,860', pct: '35%', color: RDASH.ink },
        { l: 'Online', value: '৳9,100',  pct: '22%', color: RDASH.textTer },
      ]} />
    </Section>

    <div style={{ height: 14 }} />
  </DashScreen>
);

Object.assign(window, { Review_Advanced });
