// Terafoods · Dashboard · OWNER — STANDARD (food cart + cafe)
//
// Period-driven analytics. Brief calls for controlled plum here:
//   • active period pill (plum fill)
//   • selected sort chip (accentSoft fill, ink text)
//   • single revenue trend line (plum)
// Nowhere else: no plum on data, deltas, tiles, or rank badges.
//
//   1. Top app bar      · outlet [CAFE] · time | Mgr|Owner | drawer
//   2. Period           · Today / Week / Month / Custom (plum active)
//   3. Revenue hero     · big number + plain-language delta
//   4. KPI strip        · orders · avg ticket · covers · late rate
//   5. Revenue by hour  · LINE chart (plum line, dashed grey prior)
//   6. Menu perf table  · Excel-like, sortable header above
//   7. By source        · monochrome proportion bars

const Review_Standard = () => {
  const [period, setPeriod] = React.useState('Today');
  const [sort, setSort] = React.useState('rev');
  const [role, setRole] = React.useState('owner');

  const menuRows = [
    { name: 'Milk Tea',  qty: 64, rev: '৳1,920', share: '13%', vsPrev: '+12%' },
    { name: 'Singara',   qty: 48, rev: '৳960',   share: '6%',  vsPrev: '+4%' },
    { name: 'Samosa',    qty: 31, rev: '৳930',   share: '6%',  vsPrev: '−2%' },
    { name: 'Lemon Tea', qty: 26, rev: '৳520',   share: '4%',  vsPrev: '+8%' },
    { name: 'Egg Toast', qty: 18, rev: '৳450',   share: '3%',  vsPrev: '−5%' }
  ];

  return (
    <DashScreen navActive={2}>
      <DashTopBar
        outlet="Cha Ghor · Dhanmondi 27"
        mode="Cafe"
        time="11 PM · Mon 3 Jun"
        role={role} onRoleChange={setRole}
        drawer="৳14,820"
      />

      {/* 2 · Period — primary control. Active = plum fill */}
      <Section top={4}>
        <PeriodSelector value={period} onChange={setPeriod} />
        <PeriodSubtitle range="Mon · 3 Jun · 9 AM – 11 PM" compare="prev Mon" />
      </Section>

      {/* 3 · Revenue hero with plain-language delta */}
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
          }}>৳14,820</div>
          <div style={{ marginTop: 10, lineHeight: 1.5 }}>
            <Delta value="৳1,860" baselineLabel="last Monday" pct="+14%" size="md" />
          </div>
          <div style={{
            fontSize: 12.5, color: DASH.textSec, marginTop: 8, lineHeight: 1.5
          }}>
            Net after discounts <strong style={{ color: DASH.text, fontWeight: 600, ...DASH.num }}>৳14,540</strong>
          </div>
        </div>
      </Section>

      {/* 4 · KPI strip — metric, not pill */}
      <Section top={14}>
        <KpiStrip stats={[
          { l: 'Orders',     v: '42' },
          { l: 'Avg ticket', v: '৳353' },
          { l: 'Covers',     v: '87' },
          { l: 'Late rate',  v: '2.4%' }
        ]} />
      </Section>

      {/* 5 · Line chart — plum line + dashed grey prior */}
      <Section top={20}>
        <SecHead title="Revenue by hour" action="vs prev Mon" />
        <LineChartCard
          title="This Mon vs prev Mon"
          today={[80, 140, 280, 520, 840, 1180, 1080, 740, 520, 640, 980, 1480, 1620, 1240, 720]}
          yesterday={[60, 120, 240, 460, 760, 1080, 980, 680, 480, 580, 880, 1280, 1420, 1080, 640]}
          todayLabel="This Mon"
          priorLabel="Prev Mon"
          peakNote="Peak 8 PM · ৳1,620"
        />
      </Section>

      {/* 6 · Menu performance — Excel-like aligned table */}
      <Section top={20}>
        <SecHead title="Menu performance" action="See all" />
        <MenuPerfHeader sort={sort} onChange={setSort} />
        <MenuPerfTable rows={menuRows} />

        {/* Bottom-movers footnote */}
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
              Cold Coffee, Borhani, Faluda
            </div>
          </div>
          <span style={{
            fontSize: 11, fontWeight: 600, color: DASH.textSec,
            display: 'inline-flex', alignItems: 'center', gap: 4
          }}>3 items · 0 sold <span style={{ color: DASH.textTer }}>›</span></span>
        </div>
      </Section>

      {/* 7 · By source — monochrome proportion bars */}
      <Section top={20}>
        <SecHead title="By source" />
        <ChannelSplit rows={[
          { l: 'Cash',   v: '৳11,860', pct: 80 },
          { l: 'Card',   v: '৳2,110',  pct: 14 },
          { l: 'Online', v: '৳850',    pct: 6 }
        ]} />
      </Section>

      <div style={{ height: 18 }} />
    </DashScreen>
  );
};

Object.assign(window, { Review_Standard });
