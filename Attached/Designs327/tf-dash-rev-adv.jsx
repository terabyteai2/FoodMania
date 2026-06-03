// Terafoods · Dashboard · OWNER — ADVANCED (restaurant)
//
// Adds food cost % + margin column to the menu performance table. Same
// Excel-familiar treatment as STANDARD; chart is the same plum line +
// dashed grey prior. Plum appears in exactly three places:
//   • active period pill, • selected sort chip, • revenue trend line.
//
//   1. Top app bar       · outlet [REST.] · time | Mgr|Owner | drawer
//   2. Period            · primary control
//   3. Revenue hero      · big number + plain-language delta + net line
//   4. KPI strip         · orders · covers · avg ticket · food cost
//   5. Revenue by hour   · LINE chart
//   6. Menu perf (Excel) · 5-col table WITH margin column
//   7. Staff today       · 4 waiters scoreboard
//   8. By source         · monochrome bars

const MarginCallout = ({ text }) => (
  <div style={{
    marginTop: 8,
    padding: '11px 14px',
    background: DASH.warnSoft,
    borderRadius: 10,
    border: `1px solid ${DASH.warn}28`,
    display: 'flex', alignItems: 'flex-start', gap: 10,
  }}>
    <div style={{
      width: 6, height: 6, borderRadius: 3,
      background: DASH.warn, marginTop: 5, flexShrink: 0,
    }} />
    <span style={{
      fontSize: 12.5, color: DASH.ink,
      lineHeight: 1.5, fontWeight: 600,
    }}>{text}</span>
  </div>
);

const Review_Advanced = () => {
  const [period, setPeriod] = React.useState('Today');
  const [sort, setSort] = React.useState('rev');
  const [role, setRole] = React.useState('owner');

  const menuRows = [
    { name: 'Beef Tehari',   qty: 42, rev: '৳18,900', margin: '৳12,180 (64%)', vsPrev: '+22%' },
    { name: 'Chicken Tikka', qty: 36, rev: '৳12,240', margin: '৳7,580 (62%)',  vsPrev: '+8%' },
    { name: 'Mutton Roast',  qty: 28, rev: '৳11,200', margin: '৳5,620 (50%)',  vsPrev: '+4%',  warn: 'low margin' },
    { name: 'Plain Rice',    qty: 92, rev: '৳4,140',  margin: '৳2,940 (71%)',  vsPrev: '+18%' },
    { name: 'Borhani',       qty: 68, rev: '৳3,400',  margin: '৳1,920 (56%)',  vsPrev: '−3%' }
  ];

  return (
    <DashScreen navActive={2}>
      <DashTopBar
        outlet="Spice Garden · Gulshan 2"
        mode="Restaurant"
        time="11 PM · Mon 3 Jun"
        role={role} onRoleChange={setRole}
        drawer="৳42,380"
      />

      {/* 2 · Period */}
      <Section top={4}>
        <PeriodSelector value={period} onChange={setPeriod} />
        <PeriodSubtitle range="Mon · 3 Jun · 11 AM – 11 PM" compare="prev Mon" />
      </Section>

      {/* 3 · Revenue hero */}
      <Section top={14}>
        <div style={{
          background: DASH.surface, border: `0.5px solid ${DASH.border}`,
          borderRadius: 14, padding: '16px 16px 14px',
          boxShadow: DASH.shadowSoft
        }}>
          <MicroLabel>Revenue · this Monday</MicroLabel>
          <div style={{
            fontSize: 44, fontWeight: 700, color: DASH.ink, marginTop: 10,
            letterSpacing: '-0.03em', lineHeight: 1.0, ...DASH.num
          }}>৳42,380</div>
          <div style={{ marginTop: 10, lineHeight: 1.5 }}>
            <Delta value="৳5,260" baselineLabel="last Monday" pct="+14%" size="md" />
          </div>
          <div style={{
            fontSize: 12.5, color: DASH.textSec, marginTop: 8, lineHeight: 1.5
          }}>
            Net after discounts <strong style={{ color: DASH.text, fontWeight: 600, ...DASH.num }}>৳41,640</strong>
          </div>
        </div>
      </Section>

      {/* 4 · KPI strip — food cost shown (costing is set up) */}
      <Section top={14}>
        <KpiStrip stats={[
          { l: 'Orders',     v: '88' },
          { l: 'Covers',     v: '218' },
          { l: 'Avg ticket', v: '৳724' },
          { l: 'Food cost',  v: '32%' }
        ]} />
      </Section>

      {/* 5 · Line chart */}
      <Section top={20}>
        <SecHead title="Revenue by hour" action="vs prev Mon" />
        <LineChartCard
          title="This Mon vs prev Mon"
          today={[80, 140, 280, 520, 840, 1280, 1180, 740, 520, 640, 1080, 1820, 2240, 1860, 1240]}
          yesterday={[60, 120, 240, 460, 760, 1180, 1080, 680, 480, 580, 980, 1640, 1980, 1640, 1080]}
          todayLabel="This Mon"
          priorLabel="Prev Mon"
          peakNote="Peak 8 PM · ৳2,240"
        />
      </Section>

      {/* 6 · Menu performance — Excel-like with margin column */}
      <Section top={20}>
        <SecHead title="Menu performance" action="See all" />
        <MenuPerfHeader sort={sort} onChange={setSort} />
        <MenuPerfTable rows={menuRows} showMargin />
        <MarginCallout text="Mutton Roast sells big but margin is thin (FC 42%). Worth a look." />

        {/* Bottom movers */}
        <div style={{
          marginTop: 12, padding: '11px 14px', display: 'flex',
          alignItems: 'center', justifyContent: 'space-between',
          background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 12
        }}>
          <div>
            <div style={{
              fontSize: 10, fontFamily: DASH.mono, fontWeight: 600, color: DASH.textTer,
              letterSpacing: 0.6, textTransform: 'uppercase'
            }}>Bottom movers · this Mon</div>
            <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, marginTop: 4 }}>
              Khichuri, Reshmi Kebab, Brain Masala
            </div>
          </div>
          <span style={{
            fontSize: 11, fontWeight: 600, color: DASH.textSec,
            display: 'inline-flex', alignItems: 'center', gap: 4
          }}>3 items · &lt;5 each <span style={{ color: DASH.textTer }}>›</span></span>
        </div>
      </Section>

      {/* 7 · Staff today */}
      <Section top={20}>
        <SecHead title="Staff today" action="6 on shift" />
        <DashCard padded={false} style={{ overflow: 'hidden' }}>
          <StaffScoreRow first rank={1} name="Anwar"  role="Waiter" covers={64} ticket="৳780" time="6h 14m" mistakes={0} />
          <StaffScoreRow       rank={2} name="Salim"  role="Waiter" covers={52} ticket="৳712" time="6h 04m" mistakes={1} />
          <StaffScoreRow       rank={3} name="Rashed" role="Waiter" covers={48} ticket="৳694" time="6h 14m" mistakes={0} />
          <StaffScoreRow       rank={4} name="Jasim"  role="Waiter" covers={36} ticket="৳684" time="5h 22m" mistakes={2} />
        </DashCard>
      </Section>

      {/* 8 · By source */}
      <Section top={20}>
        <SecHead title="By source" />
        <ChannelSplit rows={[
          { l: 'Dine-in',  v: '৳27,000', pct: 64 },
          { l: 'Takeaway', v: '৳9,300',  pct: 22 },
          { l: 'Delivery', v: '৳5,900',  pct: 14 }
        ]} />
      </Section>

      <div style={{ height: 18 }} />
    </DashScreen>
  );
};

Object.assign(window, { Review_Advanced });
