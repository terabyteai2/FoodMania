// Terafoods · Manage Mode — REVIEW tab · ADVANCED
// Business: "Spice Garden" — full-service restaurant (matches Dash_T3_Full).
//
// Re-architected per layout_change.txt — Tier 3 is the literacy boundary:
// the owner is delegating to a manager and 5–8 staff; he now genuinely
// needs the app to tell him things he doesn't already know. This is where
// the bar chart, the 7-day average, peak hour, and food-cost % first earn
// their place.
//
// Stack (Staff moves up — it's the most actionable end-of-service section):
//   Hero (delta vs 7-day avg, plain-language insight, NO chart in hero)
//   → Staff today (promoted: 2nd after hero, end-of-service pulse)
//   → KPI row, 4 cols (Orders · Covers · Avg Ticket · Food Cost %)
//   → Revenue by hour (dedicated chart — first place a bar chart appears)
//   → What sold (top items + margin %, warningSoft chip on low-margin items)
//   → By source (defaulted-OPEN with 3 value chips, no chart)
//
// Deleted from previous build:
//   • Hourly chart embedded in hero
//   • Turns/Table KPI (derivable from Covers÷Tables)
//   • Profitability quadrant matrix (MBA jargon) — replaced by the
//     warningSoft chip + one-line plain-language callout

// One-line margin callout — plain language instead of quadrant labels.
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

// 3-chip row — Cash · Card · Online value pills (no chart at P3)
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
    <DashHeader
      greet="Evening, Rezaul" emoji=""
      biz="Spice Garden" bn="ধানমন্ডি" date="Sat · 8:14 PM"
      tier="Full-service · 24 tables" tierBn="ফুল সার্ভিস" tierTone="paper" badge={2}
    />

    <ReviewTabs active="review" period="Today" />

    {/* Hero — clean. Delta vs 7-day avg + plain-language insight. No chart;
        the chart gets its own section below so the hero stays anchored
        on the single hero number. */}
    <Section top={12}>
      <VsYesterdayHero
        today="৳42,380" todayLabel="Earned today"
        delta="+10%" deltaUp
        vsBase="৳38,420" vsLabel="vs 7-day avg"
        periodNote={<>Strongest dinner this week — <span style={{ color: RDASH.ink, fontWeight: 600 }}>87% capacity</span> at 8 PM peak.</>}
      />
    </Section>

    {/* Staff today — moved up from former bottom position. End-of-service
        pulse: at this tier the owner isn't watching every table, so the
        most actionable thing right now is "who carried the floor tonight?" */}
    <Section top={14}>
      <SecHead title="Staff today" bn="স্টাফ" action="6 on shift" />
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <StaffScoreRow first rank={1} name="Anwar"  role="Waiter" covers={64} ticket="৳780" time="6h 14m" mistakes={0} />
        <StaffScoreRow       rank={2} name="Salim"  role="Waiter" covers={52} ticket="৳712" time="6h 04m" mistakes={1} />
        <StaffScoreRow       rank={3} name="Rashed" role="Waiter" covers={48} ticket="৳694" time="6h 14m" mistakes={0} />
        <StaffScoreRow       rank={4} name="Jasim"  role="Waiter" covers={36} ticket="৳684" time="5h 22m" mistakes={2} />
      </DashCard>
    </Section>

    {/* 4-pill KPI strip — Orders · Covers · Avg Ticket · Food Cost %.
        Turns/Table dropped: derivable mentally from Covers ÷ Tables.
        Food Cost % surfaced to the top row — it's the number that
        matters most for profitability at this tier. */}
    <Section top={14}>
      <KpiStrip stats={[
        { l: 'Orders',     v: '88' },
        { l: 'Covers',     v: '218' },
        { l: 'Avg ticket', v: '৳724' },
        { l: 'Food cost',  v: '32%' },
      ]} />
    </Section>

    {/* Revenue by hour — dedicated section, full-width chart with today
        as solid bars and 7-day average as ghost. Peak hour annotated
        directly on the chart header. This is the first place a bar
        chart appears in the product. */}
    <Section top={14}>
      <SecHead title="Revenue by hour" bn="ঘণ্টা" action="7-day" />
      <HourlyCard
        title="Today vs 7-day average"
        today={[80, 140, 280, 520, 840, 1280, 1180, 740, 520, 640, 1080, 1820, 2240, 1860, 1240]}
        yesterday={[60, 120, 240, 460, 760, 1180, 1080, 680, 480, 580, 980, 1640, 1980, 1640, 1080]}
        peakHour={12}
        peakLabel="8:00 PM · ৳2,240"
        hasGhost
      />
    </Section>

    {/* What sold — top items + margin %. warningSoft chip flags any item
        below margin threshold ("margin kom"). Plain-language flag does
        the job the quadrant matrix's "Puzzle/Review" labels were doing,
        without the MBA jargon a Dhaka restaurant owner has no hook for. */}
    <Section top={14}>
      <SecHead title="What sold" bn="বিক্রি" />
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <TopItemRow first rank={1} name="Beef Tehari"   bn="বিফ তেহারি"  qty={42} rev="৳18,900" margin="৳12,180" foodCost={26} />
        <TopItemRow       rank={2} name="Chicken Tikka" bn="চিকেন টিক্কা" qty={36} rev="৳12,240" margin="৳7,580"  foodCost={31} />
        <TopItemRow       rank={3} name="Mutton Roast"  bn="খাসির রোস্ট"  qty={28} rev="৳11,200" margin="৳5,620"  foodCost={42} warnLabel="margin kom" />
        <TopItemRow       rank={4} name="Plain Rice"    bn="সাদা ভাত"     qty={92} rev="৳4,140"  margin="৳2,940"  foodCost={22} />
        <TopItemRow       rank={5} name="Borhani"       bn="বোরহানি"      qty={68} rev="৳3,400"  margin="৳1,920"  foodCost={28} />
      </DashCard>
      <MarginCallout text="Mutton Roast — beshi bikri kintu margin kom (FC 42%). Check korben." />
    </Section>

    {/* By source — defaulted-open. At Tier 3, card and online start
        mattering more; show the three numbers, but no chart. */}
    <Section top={14}>
      <SecHead title="By source" bn="উৎস" />
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
