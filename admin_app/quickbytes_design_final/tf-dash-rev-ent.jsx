// Terafoods · Manage Mode — REVIEW tab · ENTERPRISE
// Fleet view across 5 outlets (matches Dash_T4_Fleet). Owner-only.
//
// Re-architected per layout_change.txt — the urgent content for a fleet
// owner is operational health ("Mirpur had 14% late rate today" is the kind
// of thing that prompts a phone call). Operational health now leads inline
// on outlet rankings rather than living in a standalone section, which
// collapses two scrolls into one scannable list.
//
// Stack:
//   Hero (fleet revenue, delta vs 7-day avg, insight, small ghost chart)
//   → Outlet ranking with inline health chips (LATE / WASTE / VAR per row)
//   → Fleet KPI row, 4 cols (Covers · Avg Ticket · Fleet FC% · On Goal)
//   → Revenue by hour (fleet aggregate, 7-day comparison — chart fully earned here)
//   → Capacity right now (3 outlets, FULL/BUSY/STEADY labels + inline key footnote)
//   → Top movers fleet-wide
//
// Deleted from previous build:
//   • Standalone Operational health section (now inline on outlet rows)
//   • Cross-fleet staff scoreboard (fleet owners compare outlets, not individuals)

// Inline health chip — fits next to revenue on an outlet row. Each chip
// is a one-line operational alert: tag + value, rendered in the
// corresponding signal's soft surface paired with the signal's ink color.
const HealthChip = ({ tone, label, value }) => {
  const t = {
    late:     { bg: RDASH.lateSoft,   color: RDASH.late   },
    warn:     { bg: RDASH.warnSoft,   color: RDASH.warn   },
    danger:   { bg: RDASH.dangerSoft, color: RDASH.danger },
  }[tone];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '3px 7px', borderRadius: 5,
      background: t.bg, color: t.color,
      fontSize: 10, fontFamily: RDASH.mono, fontWeight: 700,
      letterSpacing: 0.6, whiteSpace: 'nowrap',
      ...RDASH.num,
    }}>
      <span style={{ letterSpacing: 0.6 }}>{label}</span>
      <span style={{ fontWeight: 700 }}>{value}</span>
    </span>
  );
};

// Outlet row with inline health chips. Replaces the previous standalone
// Operational health section — health signals now ride alongside the
// revenue ranking so "who won" and "who's broken" are answerable in one pass.
const OutletRankRowInline = ({ rank, name, area, rev, covers, deltaPct, deltaUp, foodCost, badge, chips, first }) => (
  <div style={{
    padding: '12px 14px',
    borderTop: first ? 'none' : `1px solid ${RDASH.divider}`,
    display: 'flex', alignItems: 'flex-start', gap: 12,
  }}>
    <div style={{
      width: 28, height: 28, borderRadius: 8, flexShrink: 0,
      background: rank === 1 ? RDASH.ink : (rank === 2 ? RDASH.accentSoft : RDASH.surfaceAlt),
      color: rank === 1 ? RDASH.accentOnInk : (rank === 2 ? RDASH.accentSoftInk : RDASH.textSec),
      display: 'grid', placeItems: 'center',
      fontSize: 11, fontFamily: RDASH.mono, fontWeight: 700, ...RDASH.num,
      marginTop: 2,
    }}>{rank}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 13.5, fontWeight: 600, color: RDASH.text, letterSpacing: '-0.01em' }}>{name}</span>
        {badge && (
          <span style={{
            fontSize: 9, fontFamily: RDASH.mono, fontWeight: 700,
            color: badge.color || RDASH.accentSoftInk,
            background: badge.bg || RDASH.accentSoft,
            padding: '2px 5px', borderRadius: 3, letterSpacing: 0.5,
          }}>{badge.t}</span>
        )}
      </div>
      <div style={{ fontSize: 11, color: RDASH.textTer, marginTop: 2, fontFamily: RDASH.mono, ...RDASH.num }}>
        {area} · {covers} covers · FC {foodCost}%
      </div>
      {chips && chips.length > 0 && (
        <div style={{ marginTop: 8, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {chips.map((c, i) => (
            <HealthChip key={i} tone={c.tone} label={c.label} value={c.value} />
          ))}
        </div>
      )}
    </div>
    <div style={{ textAlign: 'right', flexShrink: 0 }}>
      <div style={{ fontSize: 14, fontWeight: 600, color: RDASH.text, letterSpacing: -0.2, ...RDASH.num }}>{rev}</div>
      <div style={{
        fontSize: 10.5, fontWeight: 700,
        color: deltaUp ? RDASH.good : RDASH.late,
        marginTop: 3, fontFamily: RDASH.mono, ...RDASH.num,
      }}>
        {deltaUp ? '▲' : '▼'} {deltaPct}
      </div>
    </div>
  </div>
);

// Capacity row — outlet name + horizontal fill + status label.
const CapacityRow = ({ name, pct, status, first }) => {
  const tone = pct >= 85 ? RDASH.late : (pct >= 60 ? RDASH.accent : RDASH.good);
  return (
    <div style={{
      padding: '11px 14px',
      borderTop: first ? 'none' : `1px solid ${RDASH.divider}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 13, fontWeight: 600, color: RDASH.text }}>{name}</span>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
          <span style={{ fontSize: 13, fontWeight: 600, color: RDASH.text, ...RDASH.num }}>{pct}%</span>
          <span style={{
            fontSize: 10, fontFamily: RDASH.mono, color: RDASH.textSec,
            fontWeight: 600, letterSpacing: 0.4, textTransform: 'uppercase',
          }}>{status}</span>
        </div>
      </div>
      <div style={{ height: 4, background: RDASH.track, borderRadius: 2, overflow: 'hidden', marginTop: 8 }}>
        <div style={{ height: '100%', width: `${pct}%`, background: tone }} />
      </div>
    </div>
  );
};

const Review_Enterprise = () => (
  <DashScreen navActive={2}>
    <DashHeader
      greet="Evening, Tareq" emoji=""
      biz="Pirates Group" bn="ফ্লিট" date="Sat · 8:48 PM"
      tier="Fleet · 5 outlets" tierBn="ফ্লিট" tierTone="dark" badge={6}
    />

    <ReviewTabs active="review" period="Today · Fleet" />

    {/* Fleet hero — at this tier the audience has the literacy for a
        small ghost chart in the hero. */}
    <Section top={12}>
      <VsYesterdayHero
        today="৳1,84,200" todayLabel="Fleet revenue · today"
        delta="+14%" deltaUp
        vsBase="৳1,61,580" vsLabel="vs 7-day avg"
        todayBars={[420, 620, 880, 1240, 1820, 2240, 1980, 1480, 1180, 1340, 1820, 2480, 2940, 2440, 1640]}
        yesterdayBars={[380, 560, 780, 1080, 1620, 2020, 1780, 1320, 1080, 1180, 1620, 2180, 2580, 2140, 1440]}
        periodNote={<>4 of 5 outlets above target — <span style={{ color: RDASH.ink, fontWeight: 600 }}>Dhanmondi</span> leading by ৳3,860.</>}
      />
    </Section>

    {/* Outlet rankings — health signals INLINE. The fleet owner scans down
        the list and sees both who won and who's broken in one pass.
        Replaces the previous standalone "Operational health" section. */}
    <Section top={14}>
      <SecHead title="Outlets · today" bn="আউটলেট" action="Compare" />
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <OutletRankRowInline first rank={1} name="Dhanmondi" area="Spice Garden 27"
          rev="৳52,180" covers={218} deltaPct="+22%" deltaUp foodCost={29}
          badge={{ t: 'TOP', bg: RDASH.accentSoft, color: RDASH.accentSoftInk }}
        />
        <OutletRankRowInline rank={2} name="Gulshan" area="Spice Garden 2"
          rev="৳48,360" covers={196} deltaPct="+8%" deltaUp foodCost={32}
        />
        <OutletRankRowInline rank={3} name="Banani" area="Bistro 11"
          rev="৳39,720" covers={184} deltaPct="+3%" deltaUp foodCost={30}
        />
        <OutletRankRowInline rank={4} name="Uttara" area="Cha Ghor 18"
          rev="৳26,840" covers={184} deltaPct="−2%" foodCost={33}
          chips={[
            { tone: 'danger', label: 'VAR', value: '−৳620' },
          ]}
        />
        <OutletRankRowInline rank={5} name="Mirpur" area="Cha Ghor 12"
          rev="৳17,100" covers={160} deltaPct="−14%" foodCost={38}
          chips={[
            { tone: 'late',  label: 'LATE',  value: '14%'  },
            { tone: 'warn',  label: 'WASTE', value: '6.2%' },
          ]}
        />
      </DashCard>
    </Section>

    {/* Fleet KPI strip — 4 cols: Covers · Avg Ticket · Fleet FC% · On Goal */}
    <Section top={14}>
      <KpiStrip stats={[
        { l: 'Covers',     v: '942' },
        { l: 'Avg ticket', v: '৳710' },
        { l: 'Fleet FC',   v: '31%' },
        { l: 'On goal',    v: '4/5' },
      ]} />
    </Section>

    {/* Revenue by hour — fleet aggregate, with 7-day comparison. At this
        tier the chart is fully earned. */}
    <Section top={14}>
      <SecHead title="Revenue by hour · fleet" bn="ঘণ্টা" action="7-day" />
      <HourlyCard
        title="Today vs 7-day average · all outlets"
        today={[420, 620, 880, 1240, 1820, 2240, 1980, 1480, 1180, 1340, 1820, 2480, 2940, 2440, 1640]}
        yesterday={[380, 560, 780, 1080, 1620, 2020, 1780, 1320, 1080, 1180, 1620, 2180, 2580, 2140, 1440]}
        peakHour={12}
        peakLabel="8:00 PM · ৳2,940"
        hasGhost
      />
    </Section>

    {/* Capacity right now — 3 outlets only, with FULL/BUSY/STEADY labels.
        Key sits inline as a one-line footnote at the bottom of the card. */}
    <Section top={14}>
      <SecHead title="Capacity right now" bn="ক্যাপাসিটি" action="Tonight" />
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <CapacityRow first name="Dhanmondi" pct={92} status="Full" />
        <CapacityRow       name="Gulshan"   pct={78} status="Busy" />
        <CapacityRow       name="Banani"    pct={54} status="Steady" />
        <div style={{
          padding: '8px 14px 10px',
          borderTop: `1px solid ${RDASH.divider}`,
          fontSize: 10.5, fontFamily: RDASH.mono, fontWeight: 600,
          color: RDASH.textSec, letterSpacing: 0.4,
          display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: '4px 10px',
        }}>
          <span style={{ color: RDASH.late }}>FULL &gt;85%</span>
          <span style={{ opacity: 0.4 }}>·</span>
          <span style={{ color: RDASH.accent }}>BUSY 60–85%</span>
          <span style={{ opacity: 0.4 }}>·</span>
          <span style={{ color: RDASH.good }}>STEADY &lt;60%</span>
        </div>
      </DashCard>
    </Section>

    {/* Top movers fleet-wide — cross-outlet aggregate. */}
    <Section top={14}>
      <SecHead title="Top movers · fleet" bn="টপ আইটেম" action="Aggregate" />
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <TopItemRow first rank={1} name="Beef Tehari"   bn="বিফ তেহারি"  qty={184} rev="৳1,84,000" margin="৳1,18,260" foodCost={28} />
        <TopItemRow       rank={2} name="Chicken Tikka" bn="চিকেন টিক্কা" qty={156} rev="৳53,040"   margin="৳32,890"   foodCost={31} />
        <TopItemRow       rank={3} name="Mutton Roast"  bn="খাসির রোস্ট"  qty={92}  rev="৳36,800"   margin="৳18,420"   foodCost={42} warnLabel="margin kom" />
        <TopItemRow       rank={4} name="Milk Tea"      bn="দুধ চা"       qty={428} rev="৳12,840"   margin="৳9,420"    foodCost={20} />
        <TopItemRow       rank={5} name="Borhani"       bn="বোরহানি"      qty={284} rev="৳14,200"   margin="৳7,960"    foodCost={28} />
      </DashCard>
    </Section>

    <div style={{ height: 14 }} />
  </DashScreen>
);

Object.assign(window, { Review_Enterprise });
