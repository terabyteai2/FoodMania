// Terafoods · Manage Mode — TIER 4 · Multi-unit / High-volume
// Business: "Spice Garden Group" — 5 outlets. Area ops manager (Karim).
// Priority scroll for a fleet manager:
//   NOW       → 1. Fleet goal hero        2. Cross-outlet KPI strip
//   NEEDS YOU → 3. Fleet alerts           4. Outlet leaderboard
//   REVIEW    → 5. Benchmarks             6. Staffing
//   CLOSE     → 7. Fleet day-end

const T4_NAV = [
  { kind: 'home',  label: 'Fleet' },
  { kind: 'shop',  label: 'Outlets' },
  { kind: 'orders',label: 'Orders' },
  { kind: 'people',label: 'Staff' },
  { kind: 'settings', label: 'More' },
];

const Dash_T4_Fleet = () => (
  <DashScreen nav={T4_NAV} navActive={0}>
    <DashHeader
      greet="Evening, Karim" emoji=""
      biz="Spice Garden Group" bn="" date="Fri · 7:42 PM"
      tier="Area ops · 5 outlets" tierBn="ফ্লিট" tierTone="dark" badge={6}
    />

    {/* 1 · NOW — fleet goal */}
    <Section top={4}>
      <GoalCard
        amount="৳1,86,400" goal="৳2,10,000" pct={89}
        label="Fleet revenue · today" bn="লক্ষ্য"
        sub="৳23,600 to goal · pace +12%"
      />
    </Section>

    {/* 2 · NOW — fleet aggregate */}
    <Section top={10}>
      <KpiStrip stats={[
        { v: '5',     l: 'Outlets' },
        { v: '312',   l: 'Covers' },
        { v: '৳512',  l: 'Avg ticket' },
        { v: '5.6%',  l: 'Fleet late', color: DASH.late },
      ]} />
    </Section>

    {/* 3 · NEEDS YOU — fleet alerts */}
    <Section>
      <SecHead title="Needs you" bn="ফ্লিট অ্যালার্ট" count={3} />
      <AlertRow tag="FULL"  tone="late"  title="Gulshan at 94% capacity"          sub="Near full · 3 parties waiting — wait ~18 min" cta="View" />
      <AlertRow tag="STUCK" tone="stuck" title="Uttara kitchen stuck · 3 orders" sub="No tickets cleared in 12 min — over threshold" cta="Call" />
      <AlertRow tag="LOW"   tone="low"   title="Mirpur · 2 items below reorder"  sub="Mutton, Polao rice — auto-reorder suggested"     cta="Reorder" />
    </Section>

    {/* 4 · Outlet leaderboard */}
    <Section>
      <SecHead title="Outlets today" bn="আউটলেট" action="Ranked" />
      <OutletCard
        name="Gulshan" area="Road 11 · 14 tables" rev="৳61.8k"
        deltaVsAvg="32%" deltaUp occ="94%" occTone="warn" late="7%" lateTone="warn"
        badge={{ t: 'Top', bg: DASH.accentSoft, color: DASH.accentInk }}
        spark={[0.4, 0.5, 0.6, 0.7, 0.8, 0.92, 0.96, 1]}
      />
      <OutletCard
        name="Banani" area="Kemal Ataturk · 12 tables" rev="৳52.1k"
        deltaVsAvg="12%" deltaUp occ="78%" late="4%"
        spark={[0.5, 0.45, 0.6, 0.65, 0.7, 0.8, 0.85, 0.9]}
      />
      <OutletCard
        name="Dhanmondi" area="Road 27 · 10 tables" rev="৳38.4k"
        deltaVsAvg="3%" deltaUp={false} occ="62%" late="2%"
        spark={[0.6, 0.55, 0.5, 0.58, 0.52, 0.6, 0.55, 0.6]}
      />
      <OutletCard
        name="Uttara" area="Sector 7 · 12 tables" rev="৳21.3k"
        deltaVsAvg="42%" deltaUp={false} occ="48%" late="9%" lateTone="bad"
        spark={[0.5, 0.4, 0.45, 0.35, 0.4, 0.3, 0.35, 0.3]}
      />
      <OutletCard
        name="Mirpur" area="Sec 10 · 8 tables" rev="৳12.8k"
        deltaVsAvg="61%" deltaUp={false} occ="40%" late="—"
        badge={{ t: 'New', bg: DASH.goodSoft, color: DASH.good }}
        spark={[0.2, 0.25, 0.3, 0.28, 0.35, 0.4, 0.42, 0.45]}
      />
    </Section>

    {/* ─── REVIEW ─── */}
    <Section top={22}>
      <Divider label="Review" bn="পর্যালোচনা" />
    </Section>

    {/* 5 · Benchmarks */}
    <Section top={14}>
      <SecHead title="Benchmarks" bn="বেঞ্চমার্ক" />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        <DashCard>
          <MicroLabel>Best avg ticket</MicroLabel>
          <div style={{ fontSize: 22, fontWeight: 600, color: DASH.text, marginTop: 8, letterSpacing: -0.4, ...DASH.num }}>৳540</div>
          <div style={{ fontSize: 11, color: DASH.accent, marginTop: 4, fontWeight: 600, ...DASH.num }}>Gulshan · ▲ ৳28 vs fleet</div>
        </DashCard>
        <DashCard>
          <MicroLabel>Worst late %</MicroLabel>
          <div style={{ fontSize: 22, fontWeight: 600, color: DASH.late, marginTop: 8, letterSpacing: -0.4, ...DASH.num }}>9%</div>
          <div style={{ fontSize: 11, color: DASH.late, marginTop: 4, fontWeight: 600, ...DASH.num }}>Uttara · ▲ 3.4pt vs fleet</div>
        </DashCard>
      </div>
    </Section>

    {/* 6 · Staffing suggestion */}
    <Section>
      <SecHead title="Staffing" bn="স্টাফিং" action="Schedule" />
      <DashCard style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ width: 38, height: 38, borderRadius: 10, background: DASH.ink, color: DASH.accentOnInk, display: 'grid', placeItems: 'center', flexShrink: 0 }}>
          <NavIcon kind="people" />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text }}>Peak 7–9pm · add 2 at Gulshan</div>
          <div style={{ fontSize: 11, color: DASH.textSec, marginTop: 3, lineHeight: 1.45 }}>Revenue-by-hour suggests understaffing the dinner rush</div>
        </div>
        <div style={{
          padding: '7px 12px', height: 30, background: DASH.surface, color: DASH.text,
          border: `1px solid ${DASH.borderStrong}`, borderRadius: 7,
          fontSize: 12, fontWeight: 600, display: 'inline-flex', alignItems: 'center', flexShrink: 0,
        }}>Adjust</div>
      </DashCard>
    </Section>

    {/* 7 · Fleet day-end */}
    <Section top={14}>
      <div style={{ paddingBottom: 14 }}>
        <CloseCard amount="৳1,86,400" title="Fleet day-end · 5 outlets" kicker="Roll up the group" warn="2 outlets still open — Gulshan, Banani" />
      </div>
    </Section>
  </DashScreen>
);

Object.assign(window, { Dash_T4_Fleet });
