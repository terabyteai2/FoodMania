// Terafoods · Manage Mode — TIER 4 · CHAIN RESTAURANT (Spice Garden Group, 5 outlets)
//
// Chain Mode = multi-location fleet. The audience is an area ops manager — they
// do NOT ring up orders at the fleet level, so the ring-up hero is absent.
// The fleet console is otherwise built like Manager:
//
//   1. Top app bar      · group [FLEET] · time | Mgr|Owner | fleet drawer
//   2. Open tickets bar · cross-outlet live strip
//   3. Period           · pinned selector
//   4. Fleet hero       · GoalCard (ink progress)
//   5. Delta line       · "more than prev Mon (+13%)" plain language
//   6. Snapshot         · covers · avg ticket · fleet late
//   7. Needs you        · cross-outlet alerts
//   8. Leaderboard      · neutral TOP, good/late deltas
//   9. Staffing         · suggestion
//  10. Close fleet day  · roll-up

const T4_NAV = [
  { kind: 'home',  label: 'Fleet' },
  { kind: 'shop',  label: 'Outlets' },
  { kind: 'orders',label: 'Orders' },
  { kind: 'people',label: 'Staff' },
  { kind: 'settings', label: 'More' }
];

const Dash_T4_Fleet = () => {
  const [period, setPeriod] = React.useState('Today');

  return (
    <DashScreen nav={T4_NAV} navActive={0}>
      <UnifiedTopNav
        title="Dashboard"
        sub="Spice Garden Group · 5 outlets"
        mode="enterprise"
        badge={4}
      />

      <OpenTicketsBar count={42} total="৳58,640" late={3} />

      {/* 3 · Period */}
      <Section top={10}>
        <PeriodSelector value={period} onChange={setPeriod} />
        <PeriodSubtitle range="Mon · 3 Jun · 9 AM – 8:14 PM" compare="prev Mon" />
      </Section>

      {/* 4 · Fleet hero */}
      <Section top={14}>
        <GoalCard
          amount="৳1,86,400" goal="৳2,10,000" pct={89}
          label="Fleet revenue · today"
          sub="৳23,600 to goal · pace +12%"
        />
      </Section>

      {/* 5 · Canonical delta — plain language */}
      <Section top={10}>
        <div style={{
          background: DASH.surface, border: `1px solid ${DASH.border}`,
          borderRadius: 12, padding: '12px 14px',
          display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12
        }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <Delta value="৳22,180" baselineLabel="prev Mon" pct="+14%" />
            <div style={{ fontSize: 12, color: DASH.textSec, marginTop: 6 }}>
              4 of 5 outlets ahead of pace
            </div>
          </div>
        </div>
      </Section>

      {/* 6 · Snapshot */}
      <Section top={14}>
        <KpiStrip stats={[
          { v: '312',   l: 'Covers' },
          { v: '৳512',  l: 'Avg ticket' },
          { v: '5.6%',  l: 'Fleet late', color: DASH.late }
        ]} />
      </Section>

      {/* 7 · Needs you — fleet alerts */}
      <Section top={18}>
        <SecHead title="Needs you" count={3} />
        <AlertRow tag="FULL"  tone="late"
          title="Gulshan at 94% capacity"
          sub="3 parties waiting · est. wait ~18 min" cta="View" />
        <AlertRow tag="STUCK" tone="stuck"
          title="Uttara kitchen stuck · 3 orders"
          sub="No tickets cleared in 12 min — over threshold" cta="Call" />
        <AlertRow tag="LOW"   tone="low"
          title="Mirpur · 2 items below reorder"
          sub="Mutton, Polao rice — auto-reorder suggested" cta="Reorder" />
      </Section>

      {/* 8 · Outlet leaderboard */}
      <Section top={14}>
        <SecHead title="Outlets · today" action="Ranked" />
        <OutletCard
          name="Gulshan" area="Road 11 · 14 tables" rev="৳61,800"
          deltaVsAvg="32%" deltaUp occ="94%" occTone="warn" late="7%" lateTone="warn"
          badge={{ t: 'Top' }}
          spark={[0.4, 0.5, 0.6, 0.7, 0.8, 0.92, 0.96, 1]}
        />
        <OutletCard
          name="Banani" area="Kemal Ataturk · 12 tables" rev="৳52,100"
          deltaVsAvg="12%" deltaUp occ="78%" late="4%"
          spark={[0.5, 0.45, 0.6, 0.65, 0.7, 0.8, 0.85, 0.9]}
        />
        <OutletCard
          name="Dhanmondi" area="Road 27 · 10 tables" rev="৳38,400"
          deltaVsAvg="3%" deltaUp={false} occ="62%" late="2%"
          spark={[0.6, 0.55, 0.5, 0.58, 0.52, 0.6, 0.55, 0.6]}
        />
        <OutletCard
          name="Uttara" area="Sector 7 · 12 tables" rev="৳21,300"
          deltaVsAvg="42%" deltaUp={false} occ="48%" late="9%" lateTone="bad"
          spark={[0.5, 0.4, 0.45, 0.35, 0.4, 0.3, 0.35, 0.3]}
        />
        <OutletCard
          name="Mirpur" area="Sector 10 · 8 tables" rev="৳12,800"
          deltaVsAvg="61%" deltaUp={false} occ="40%" late="—"
          badge={{ t: 'New', bg: DASH.goodSoft, color: DASH.good }}
          spark={[0.2, 0.25, 0.3, 0.28, 0.35, 0.4, 0.42, 0.45]}
        />
      </Section>

      {/* 9 · Staffing */}
      <Section top={18}>
        <SecHead title="Staffing" action="Schedule" />
        <DashCard style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 10,
            background: DASH.surfaceAlt, color: DASH.ink,
            border: `1px solid ${DASH.border}`,
            display: 'grid', placeItems: 'center', flexShrink: 0
          }}>
            <NavIcon kind="people" />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text }}>
              Peak 7–9 PM · add 2 at Gulshan
            </div>
            <div style={{ fontSize: 11, color: DASH.textSec, marginTop: 3, lineHeight: 1.45 }}>
              Revenue-by-hour suggests understaffing the dinner rush
            </div>
          </div>
          <div style={{
            padding: '7px 12px', height: 30, background: DASH.surface, color: DASH.text,
            border: `1px solid ${DASH.borderStrong}`, borderRadius: 7,
            fontSize: 12, fontWeight: 600, display: 'inline-flex', alignItems: 'center', flexShrink: 0
          }}>Adjust</div>
        </DashCard>
      </Section>

      {/* 10 · Fleet day-end */}
      <Section top={14}>
        <div style={{ paddingBottom: 14 }}>
          <CloseCard
            amount="৳1,86,400"
            title="Fleet day-end · 5 outlets"
            kicker="Roll up the group"
            warn="2 outlets still open — Gulshan, Banani"
          />
        </div>
      </Section>
    </DashScreen>
  );
};

Object.assign(window, { Dash_T4_Fleet });
