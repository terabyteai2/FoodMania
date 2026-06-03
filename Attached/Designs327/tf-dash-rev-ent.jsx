// Terafoods · Dashboard · OWNER — ENTERPRISE (chain, 5 outlets)
//
// Fleet-wide period analytics. Same plum discipline as Standard/Advanced —
// active period pill, selected sort chip, the revenue line. Operational
// alerts (FULL/STUCK/capacity right now) are NOT on this screen — those live
// on the fleet Manager view. Owner sees the rate as a metric, not the ticket.
//
//   1. Top app bar       · group [FLEET] · time | Mgr|Owner | fleet drawer
//   2. Period            · primary control
//   3. Fleet hero        · revenue + plain-language delta vs 7-day avg
//   4. Fleet KPI strip   · covers · avg ticket · fleet FC · on goal
//   5. Outlet ranking    · inline health chips on rows that need them
//   6. Revenue by hour   · LINE chart (fleet aggregate)
//   7. Menu perf (Excel) · cross-outlet aggregate with margin column
//   8. By source         · monochrome bars

// Inline health chip — fits next to revenue on an outlet row.
const HealthChip = ({ tone, label, value }) => {
  const t = {
    late:   { bg: DASH.lateSoft,   color: DASH.late   },
    warn:   { bg: DASH.warnSoft,   color: DASH.warn   },
    danger: { bg: DASH.dangerSoft, color: DASH.danger }
  }[tone];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '3px 7px', borderRadius: 5,
      background: t.bg, color: t.color,
      fontSize: 10, fontFamily: DASH.mono, fontWeight: 700,
      letterSpacing: 0.6, whiteSpace: 'nowrap',
      ...DASH.num
    }}>
      <span style={{ letterSpacing: 0.6 }}>{label}</span>
      <span style={{ fontWeight: 700 }}>{value}</span>
    </span>
  );
};

const OutletRankRowInline = ({ rank, name, area, rev, covers, deltaPct, deltaUp, foodCost, badge, chips, first }) => (
  <div style={{
    padding: '12px 14px',
    borderTop: first ? 'none' : `1px solid ${DASH.divider}`,
    display: 'flex', alignItems: 'flex-start', gap: 12
  }}>
    <div style={{
      width: 26, height: 26, borderRadius: 7, flexShrink: 0,
      background: DASH.surface,
      color: DASH.textSec,
      border: `1px solid ${DASH.border}`,
      display: 'grid', placeItems: 'center',
      fontSize: 11, fontFamily: DASH.mono, fontWeight: 700, ...DASH.num,
      marginTop: 2
    }}>{rank}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text, letterSpacing: '-0.01em' }}>{name}</span>
        {badge && (
          <span style={{
            fontSize: 9, fontFamily: DASH.mono, fontWeight: 700,
            color: badge.color || DASH.text,
            background: badge.bg || DASH.surfaceAlt,
            border: `1px solid ${DASH.border}`,
            padding: '2px 5px', borderRadius: 3, letterSpacing: 0.5
          }}>{badge.t}</span>
        )}
      </div>
      <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 2, fontFamily: DASH.mono, ...DASH.num }}>
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
      <div style={{ fontSize: 14, fontWeight: 600, color: DASH.text, letterSpacing: -0.2, ...DASH.num }}>{rev}</div>
      <div style={{
        fontSize: 10.5, fontWeight: 700,
        color: deltaUp ? DASH.good : DASH.late,
        marginTop: 3, fontFamily: DASH.mono, ...DASH.num,
        display: 'inline-flex', alignItems: 'center', gap: 3, justifyContent: 'flex-end'
      }}>
        <span style={{ fontSize: 9 }}>{deltaUp ? '↑' : '↓'}</span>
        {deltaPct}
      </div>
    </div>
  </div>
);

const Review_Enterprise = () => {
  const [period, setPeriod] = React.useState('Today');
  const [sort, setSort] = React.useState('rev');
  const [role, setRole] = React.useState('owner');

  const menuRows = [
    { name: 'Beef Tehari',   qty: 184, rev: '৳1,84,000', margin: '৳1,18,260 (64%)', vsPrev: '+18%' },
    { name: 'Chicken Tikka', qty: 156, rev: '৳53,040',   margin: '৳32,890 (62%)',   vsPrev: '+9%' },
    { name: 'Mutton Roast',  qty: 92,  rev: '৳36,800',   margin: '৳18,420 (50%)',   vsPrev: '+2%', warn: 'low margin' },
    { name: 'Milk Tea',      qty: 428, rev: '৳12,840',   margin: '৳9,420 (73%)',    vsPrev: '+24%' },
    { name: 'Borhani',       qty: 284, rev: '৳14,200',   margin: '৳7,960 (56%)',    vsPrev: '−4%' }
  ];

  return (
    <DashScreen navActive={2}>
      <DashTopBar
        outlet="Spice Garden Group"
        mode="Fleet · 5 outlets"
        time="11 PM · Mon 3 Jun"
        role={role} onRoleChange={setRole}
        drawer="৳1,84,200" drawerLabel="Fleet drawer"
      />

      {/* 2 · Period */}
      <Section top={4}>
        <PeriodSelector value={period} onChange={setPeriod} />
        <PeriodSubtitle range="Mon · 3 Jun · all outlets" compare="7-day avg" />
      </Section>

      {/* 3 · Fleet hero with plain-language delta */}
      <Section top={14}>
        <div style={{
          background: DASH.surface, border: `0.5px solid ${DASH.border}`,
          borderRadius: 14, padding: '16px 16px 14px',
          boxShadow: DASH.shadowSoft
        }}>
          <MicroLabel>Fleet revenue · this Monday</MicroLabel>
          <div style={{
            fontSize: 44, fontWeight: 700, color: DASH.ink, marginTop: 10,
            letterSpacing: '-0.03em', lineHeight: 1.0, ...DASH.num
          }}>৳1,84,200</div>
          <div style={{ marginTop: 10, lineHeight: 1.5 }}>
            <Delta value="৳22,620" baselineLabel="7-day avg" pct="+14%" size="md" />
          </div>
          <div style={{
            fontSize: 12.5, color: DASH.textSec, marginTop: 8, lineHeight: 1.5
          }}>
            4 of 5 outlets above target — <strong style={{ color: DASH.text, fontWeight: 600 }}>Dhanmondi</strong> leading by ৳3,860.
          </div>
        </div>
      </Section>

      {/* 4 · Fleet KPI strip */}
      <Section top={14}>
        <KpiStrip stats={[
          { l: 'Covers',     v: '942' },
          { l: 'Avg ticket', v: '৳710' },
          { l: 'Fleet FC',   v: '31%' },
          { l: 'On goal',    v: '4/5' }
        ]} />
      </Section>

      {/* 5 · Outlet ranking with inline health chips */}
      <Section top={18}>
        <SecHead title="Outlets · today" action="Compare" />
        <DashCard padded={false} style={{ overflow: 'hidden' }}>
          <OutletRankRowInline first rank={1} name="Dhanmondi" area="Spice Garden 27"
            rev="৳52,180" covers={218} deltaPct="+22%" deltaUp foodCost={29}
            badge={{ t: 'TOP' }}
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
              { tone: 'danger', label: 'VAR', value: '−৳620' }
            ]}
          />
          <OutletRankRowInline rank={5} name="Mirpur" area="Cha Ghor 12"
            rev="৳17,100" covers={160} deltaPct="−14%" foodCost={38}
            chips={[
              { tone: 'late',  label: 'LATE',  value: '14%'  },
              { tone: 'warn',  label: 'WASTE', value: '6.2%' }
            ]}
          />
        </DashCard>
      </Section>

      {/* 6 · Fleet revenue by hour — line chart */}
      <Section top={20}>
        <SecHead title="Revenue by hour · fleet" action="7-day avg" />
        <LineChartCard
          title="Today vs 7-day average · all outlets"
          today={[420, 620, 880, 1240, 1820, 2240, 1980, 1480, 1180, 1340, 1820, 2480, 2940, 2440, 1640]}
          yesterday={[380, 560, 780, 1080, 1620, 2020, 1780, 1320, 1080, 1180, 1620, 2180, 2580, 2140, 1440]}
          todayLabel="Today"
          priorLabel="7-day avg"
          peakNote="Peak 8 PM · ৳2,940"
        />
      </Section>

      {/* 7 · Menu performance — fleet aggregate with margin column */}
      <Section top={20}>
        <SecHead title="Top movers · fleet" action="Aggregate" />
        <MenuPerfHeader sort={sort} onChange={setSort} />
        <MenuPerfTable rows={menuRows} showMargin />
      </Section>

      {/* 8 · By source — fleet-wide monochrome bars */}
      <Section top={20}>
        <SecHead title="By source" />
        <ChannelSplit rows={[
          { l: 'Dine-in',  v: '৳1,18,000', pct: 64 },
          { l: 'Takeaway', v: '৳40,600',   pct: 22 },
          { l: 'Delivery', v: '৳25,600',   pct: 14 }
        ]} />
      </Section>

      <div style={{ height: 18 }} />
    </DashScreen>
  );
};

Object.assign(window, { Review_Enterprise });
