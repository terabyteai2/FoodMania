// Terafoods · Dashboard · REVIEW (Owner) — STANDARD (Cha Ghor)
// New structure per Dashboard_Inventory_Edits brief:
//   1. Unified top nav with Manager/Owner toggle (set to Owner here)
//   2. Totals header — Total Cash + Total Orders
//   3. Hot Selling — promoted, this is the screen's hero list
//   4. Today's issues (conditional)
//   5. By source — collapsed by default
//   Accent wash strips added to spice the page up.

// 2-column KPI variant — overrides KpiStrip's flex-fill behavior.
const KpiPair = ({ stats }) => (
  <div style={dashCardStyle({ padding: 0, display: 'flex', overflow: 'hidden' })}>
    {stats.map((s, i) => (
      <div key={i} style={{
        flex: 1, padding: '14px 16px', textAlign: 'left',
        borderLeft: i ? `1px solid ${RDASH.border}` : 'none',
      }}>
        <MicroLabel>{s.l}</MicroLabel>
        <div style={{
          fontSize: 24, fontWeight: 700, color: RDASH.text,
          letterSpacing: '-0.02em', lineHeight: 1, marginTop: 8, ...RDASH.num,
        }}>{s.v}</div>
      </div>
    ))}
  </div>
);

// Promoted top-item row — the hero list of this screen.
// Active row #1 gets accentWash backing so the page doesn't read flat.
const TopItemRowLg = ({ rank, name, qty, rev, first }) => (
  <div style={{
    padding: '14px 16px',
    borderTop: first ? 'none' : `1px solid ${RDASH.divider}`,
    background: rank === 1 ? RDASH.accentWash : 'transparent',
    display: 'flex', alignItems: 'center', gap: 14,
  }}>
    <div style={{
      width: 26, height: 26, borderRadius: 7,
      background: rank === 1 ? RDASH.accent : RDASH.surfaceAlt,
      color: rank === 1 ? RDASH.accentInk : RDASH.textSec,
      display: 'grid', placeItems: 'center',
      fontSize: 12, fontWeight: 700, ...RDASH.num,
    }}>{rank}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 15, fontWeight: 600, color: RDASH.text, lineHeight: 1.2, letterSpacing: '-0.01em' }}>
        {name}
      </div>
      <div style={{ fontSize: 12, color: RDASH.textSec, marginTop: 3, display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ fontWeight: 600, ...RDASH.num }}>×{qty}</span>
      </div>
    </div>
    <div style={{
      fontSize: 16, fontWeight: 600, color: RDASH.text,
      letterSpacing: '-0.01em', ...RDASH.num,
    }}>{rev}</div>
  </div>
);

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

  const issues = [
    { tag: 'LATE', title: 'Table 3 · Order #84 · 24 min late', sub: 'Kitchen backed up during 1:30 PM rush.' },
  ];

  return (
    <DashScreen navActive={2}>
      <TopNav title="Dashboard" role="owner" badge={1} />

      {/* 1 · Totals header */}
      <Section top={4}>
        <TotalsHeader cash="৳14,820" orders="42" sub="Cash · Card · Mobile pay" />
      </Section>

      {/* 2 · KPI — Orders · Covers */}
      <Section top={14}>
        <KpiPair stats={[
          { l: 'Covers', v: '87' },
          { l: 'Avg ticket', v: '৳353' },
        ]} />
      </Section>

      {/* 3 · Hot Selling — promoted */}
      <Section top={18}>
        <SecHead title="Hot Selling" action="See all" />
        <DashCard padded={false} style={{ overflow: 'hidden' }}>
          <TopItemRowLg first rank={1} name="Milk Tea"  qty={64} rev="৳1,920" />
          <TopItemRowLg       rank={2} name="Singara"   qty={48} rev="৳960" />
          <TopItemRowLg       rank={3} name="Samosa"    qty={31} rev="৳930" />
          <TopItemRowLg       rank={4} name="Lemon Tea" qty={26} rev="৳520" />
          <TopItemRowLg       rank={5} name="Egg Toast" qty={18} rev="৳450" />
        </DashCard>
      </Section>

      {/* 4 · Today's issues */}
      {issues.length > 0 && (
        <Section top={14}>
          <SecHead title="Today's issues" count={issues.length} accent={RDASH.late} />
          <DashCard padded={false} style={{ overflow: 'hidden' }}>
            {issues.map((it, i) => (
              <IssueRow key={i} first={i === 0} tag={it.tag} title={it.title} sub={it.sub} />
            ))}
          </DashCard>
        </Section>
      )}

      {/* 5 · By source — collapsible */}
      <Section top={14}>
        <button
          onClick={() => setSourceOpen(o => !o)}
          style={{
            width: '100%', display: 'flex', alignItems: 'center',
            justifyContent: 'space-between',
            padding: '10px 14px', margin: 0,
            background: RDASH.accentWash,
            border: `1px solid ${RDASH.accent}33`,
            borderRadius: sourceOpen ? '12px 12px 0 0' : 12,
            cursor: 'pointer', outline: 'none',
            fontFamily: RDASH.font,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 12.5, fontWeight: 600, color: RDASH.accentInk }}>By source</span>
            <span style={{ fontSize: 11, fontFamily: RDASH.mono, color: RDASH.textSec, fontWeight: 600 }}>42 TX</span>
          </div>
          <span style={{
            fontSize: 13, color: RDASH.accentInk,
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
