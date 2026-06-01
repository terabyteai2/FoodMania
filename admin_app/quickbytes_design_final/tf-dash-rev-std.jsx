// Terafoods · Manage Mode — REVIEW tab · STANDARD
// Business: "Cha Ghor" — small dine-in café (matches Dash_T2_Dinein).
//
// Re-architected per layout_change.txt — the Tier-2 operator is a small-cafe
// owner reading in plain Bangla terms. He has no mental model for hourly
// bar charts, peak-hour metrics, or 7-day averages — those are Tier-3 patterns.
// The whole frame here is cash-and-items thinking: how much, and what sold.
//
// Stack:
//   Hero (numericHero + plain-language "vs yesterday in taka" line — NO chart)
//   → 2 stat tiles (Orders · Covers — drop Peak Hour, that's jargon)
//   → Top items (PROMOTED: the screen's primary section — top 5 visible)
//   → Today's issues (conditional — only if late/comped orders exist)
//   → By source (collapsed by default — most P2 operators won't open it)
//
// Deleted from the previous build:
//   • Hourly bar chart
//   • Revenue by hour section
//   • Peak hour KPI
//   • 7-day average comparisons

// 2-column KPI variant — overrides KpiStrip's flex-fill behavior.
const KpiPair = ({ stats }) => (
  <div style={dashCardStyle({ padding: 0, display: 'flex', overflow: 'hidden' })}>
    {stats.map((s, i) => (
      <div key={i} style={{
        flex: 1, padding: '14px 16px', textAlign: 'left',
        borderLeft: i ? `1px solid ${RDASH.border}` : 'none',
      }}>
        <MicroLabel>{s.l}</MicroLabel>
        {s.bn && (
          <div style={{ fontSize: 10, color: RDASH.textTer, fontFamily: RDASH.bn, marginTop: 3 }}>
            {s.bn}
          </div>
        )}
        <div style={{
          fontSize: 24, fontWeight: 700, color: RDASH.text,
          letterSpacing: '-0.02em', lineHeight: 1, marginTop: 8, ...RDASH.num,
        }}>{s.v}</div>
      </div>
    ))}
  </div>
);

// Promoted top-item row — larger numerics, more vertical weight than
// the shared TopItemRow. This list IS the report at Tier 2.
const TopItemRowLg = ({ rank, name, bn, qty, rev, first }) => (
  <div style={{
    padding: '14px 16px',
    borderTop: first ? 'none' : `1px solid ${RDASH.divider}`,
    display: 'flex', alignItems: 'center', gap: 14,
  }}>
    <div style={{
      width: 26, height: 26, borderRadius: 7,
      background: rank === 1 ? RDASH.ink : RDASH.surfaceAlt,
      color: rank === 1 ? RDASH.accentOnInk : RDASH.textSec,
      display: 'grid', placeItems: 'center',
      fontSize: 12, fontWeight: 700, ...RDASH.num,
    }}>{rank}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 15, fontWeight: 600, color: RDASH.text, lineHeight: 1.2, letterSpacing: '-0.01em' }}>
        {name}
      </div>
      <div style={{ fontSize: 12, color: RDASH.textSec, marginTop: 3, display: 'flex', alignItems: 'center', gap: 8 }}>
        {bn && <span style={{ fontFamily: RDASH.bn }}>{bn}</span>}
        <span style={{ fontWeight: 600, ...RDASH.num }}>×{qty}</span>
      </div>
    </div>
    <div style={{
      fontSize: 16, fontWeight: 600, color: RDASH.text,
      letterSpacing: '-0.01em', ...RDASH.num,
    }}>{rev}</div>
  </div>
);

// Issue row — urgentSoft background paired with ink text per soft-surface rule.
const IssueRow = ({ tag, title, sub, first }) => (
  <div style={{
    padding: '12px 14px',
    borderTop: first ? 'none' : `1px solid ${RDASH.divider}`,
    background: RDASH.lateSoft,
    display: 'flex', alignItems: 'flex-start', gap: 10,
  }}>
    <div style={{
      padding: '3px 7px', background: RDASH.surface, color: RDASH.late,
      borderRadius: 5, fontSize: 10, fontFamily: RDASH.mono, fontWeight: 700,
      letterSpacing: 0.7, flexShrink: 0, marginTop: 1,
    }}>{tag}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: RDASH.ink, lineHeight: 1.3 }}>{title}</div>
      {sub && (
        <div style={{ fontSize: 11.5, color: RDASH.inkRaised, marginTop: 3, fontWeight: 400 }}>{sub}</div>
      )}
    </div>
  </div>
);

const Review_Standard = () => {
  const [sourceOpen, setSourceOpen] = React.useState(false);

  // Today's issues — show if any exist; collapse section entirely if empty.
  const issues = [
    { tag: 'LATE', title: 'Table 3 · Order #84 · 24 min late', sub: 'Kitchen backed up during 1:30 PM rush.' },
  ];

  return (
    <DashScreen navActive={2}>
      <DashHeader
        greet="Afternoon, Shuvo" emoji=""
        biz="Cha Ghor" bn="মোহাম্মদপুর" date="Sat · 3:08 PM"
        tier="Dine-in · 6 tables" tierBn="ডাইন-ইন" tierTone="paper" badge={1}
      />

      <ReviewTabs active="review" />

      {/* Hero — cash-and-items framing. Plain language line replaces the chart.
          He'll know if today was better than yesterday — the app just confirms it. */}
      <Section top={12}>
        <VsYesterdayHero
          today="৳14,820" todayLabel="Earned today"
          delta="+৳1,090" deltaUp
          vsBase="৳13,730" vsLabel="vs yest"
          periodNote={
            <span style={{ fontFamily: RDASH.bn }}>
              কালকের চেয়ে <span style={{ color: RDASH.ink, fontWeight: 600, fontFamily: RDASH.font, ...RDASH.num }}>৳1,090</span> বেশি · <span style={{ fontFamily: RDASH.font }}>Strong lunch period.</span>
            </span>
          }
        />
      </Section>

      {/* Two-tile KPI strip — Orders · Covers. Peak Hour dropped: a small-cafe
          owner doesn't optimize around a peak-hour metric; he already knows
          lunch and dinner are busy. */}
      <Section top={14}>
        <KpiPair stats={[
          { l: 'Orders', bn: 'অর্ডার', v: '42' },
          { l: 'Covers', bn: 'কভার',  v: '87' },
        ]} />
      </Section>

      {/* Top items — promoted. This is the screen's primary section: the
          operator's eyes should land here. Larger rows than the shared
          TopItemRow; top 5 visible without scrolling. */}
      <Section top={18}>
        <SecHead title="Top items today" bn="টপ আইটেম" action="See all" />
        <DashCard padded={false} style={{ overflow: 'hidden' }}>
          <TopItemRowLg first rank={1} name="Milk Tea (Cha)" bn="দুধ চা"      qty={64} rev="৳1,920" />
          <TopItemRowLg       rank={2} name="Singara"         bn="সিঙ্গাড়া"   qty={48} rev="৳960" />
          <TopItemRowLg       rank={3} name="Samosa"          bn="সমুচা"      qty={31} rev="৳930" />
          <TopItemRowLg       rank={4} name="Lemon Tea"       bn="লেবু চা"    qty={26} rev="৳520" />
          <TopItemRowLg       rank={5} name="Egg Toast"       bn="ডিম টোস্ট" qty={18} rev="৳450" />
        </DashCard>
      </Section>

      {/* Today's issues — only renders if there is something. Empty case
          collapses the section entirely; no empty-state placeholder. */}
      {issues.length > 0 && (
        <Section top={14}>
          <SecHead title="Today's issues" bn="সমস্যা" count={issues.length} accent={RDASH.late} />
          <DashCard padded={false} style={{ overflow: 'hidden' }}>
            {issues.map((it, i) => (
              <IssueRow key={i} first={i === 0} tag={it.tag} title={it.title} sub={it.sub} />
            ))}
          </DashCard>
        </Section>
      )}

      {/* By source — collapsed by default. ~80% cash operations at this tier;
          the breakdown is rarely interesting. One-line collapsible row. */}
      <Section top={14}>
        <button
          onClick={() => setSourceOpen(o => !o)}
          style={{
            width: '100%', display: 'flex', alignItems: 'center',
            justifyContent: 'space-between',
            padding: '10px 14px', margin: 0,
            background: RDASH.surface,
            border: `1px solid ${RDASH.border}`,
            borderRadius: sourceOpen ? '12px 12px 0 0' : 12,
            cursor: 'pointer', outline: 'none',
            fontFamily: RDASH.font,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 12.5, fontWeight: 600, color: RDASH.textSec }}>By source</span>
            <span style={{ fontSize: 11, fontFamily: RDASH.mono, color: RDASH.textTer, fontWeight: 600 }}>উৎস · 42 TX</span>
          </div>
          <span style={{
            fontSize: 13, color: RDASH.textTer,
            display: 'inline-block',
            transform: sourceOpen ? 'rotate(180deg)' : 'none',
            transition: 'transform 0.18s',
            lineHeight: 1,
          }}>▾</span>
        </button>
        {sourceOpen && (
          <div style={{
            border: `1px solid ${RDASH.border}`, borderTop: 'none',
            borderRadius: '0 0 12px 12px',
            background: RDASH.surface,
          }}>
            <SourceCard
              rows={[
                { l: 'Cash',   v: 11860, value: '৳11,860', color: RDASH.accent },
                { l: 'Card',   v: 2110,  value: '৳2,110',  color: RDASH.ink },
                { l: 'Online', v: 850,   value: '৳850',    color: RDASH.textTer },
              ]}
              subtitle="42 TX"
            />
          </div>
        )}
      </Section>

      <div style={{ height: 14 }} />
    </DashScreen>
  );
};

Object.assign(window, { Review_Standard });
