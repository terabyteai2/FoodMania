// Terafoods · Inventory · SCREEN 5 — Daily report
// Performance synthesis: variance hero → revenue split → top products →
// flow ledger (in/out) → restock alert panel.

// Linear distribution width track for revenue split (no chart engine).
const RevSplitBar = ({ rows }) => {
  const total = rows.reduce((s, r) => s + r.v, 0);
  return (
    <DashCard style={{ padding: '12px 14px' }}>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8 }}>
        <Eyebrow>Revenue · today</Eyebrow>
        <span style={{ fontSize: 10.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 600, letterSpacing: 0.4, ...DASH.num }}>
          POS · 47 tx
        </span>
      </div>
      <div style={{ fontSize: 30, fontWeight: 600, color: DASH.text, letterSpacing: -0.9, lineHeight: 1, marginTop: 6, ...DASH.num }}>
        ৳6,419
      </div>
      {/* Stacked track */}
      <div style={{
        marginTop: 14, height: 8, display: 'flex',
        background: DASH.track, borderRadius: 4, overflow: 'hidden',
      }}>
        {rows.map((r, i) => (
          <div key={i} style={{
            width: `${(r.v / total) * 100}%`,
            background: r.color,
            borderRight: i < rows.length - 1 ? `1px solid ${DASH.surface}` : 'none',
          }} />
        ))}
      </div>
      {/* Legend */}
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 12, gap: 8 }}>
        {rows.map((r, i) => (
          <div key={i} style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, background: r.color }} />
              <span style={{ fontSize: 11, color: DASH.textSec, fontWeight: 600 }}>{r.l}</span>
            </div>
            <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, marginTop: 4, ...DASH.num }}>
              {r.value}
            </div>
            <div style={{ fontSize: 10, color: DASH.textTer, marginTop: 2, fontFamily: DASH.mono, ...DASH.num }}>
              {Math.round((r.v / total) * 100)}%
            </div>
          </div>
        ))}
      </div>
    </DashCard>
  );
};

// Product performance matrix — explicit ranking list.
const ProductRow = ({ rank, name, bn, qty, rev, top }) => (
  <div style={{
    padding: '11px 14px',
    borderTop: rank > 1 ? `1px solid ${DASH.divider}` : 'none',
    display: 'flex', alignItems: 'center', gap: 12,
  }}>
    <div style={{
      width: 22, height: 22, borderRadius: 6,
      background: top ? DASH.ink : DASH.surfaceAlt,
      color: top ? DASH.accentOnInk : DASH.textTer,
      display: 'grid', placeItems: 'center',
      fontSize: 10, fontFamily: DASH.mono, fontWeight: 700, ...DASH.num,
    }}>{rank}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, lineHeight: 1.15 }}>{name}</div>
    </div>
    <div style={{ textAlign: 'right', fontSize: 11, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 600, ...DASH.num, width: 38 }}>
      ×{qty}
    </div>
    <div style={{ textAlign: 'right', fontSize: 13, fontWeight: 600, color: DASH.text, ...DASH.num, minWidth: 64 }}>
      {rev}
    </div>
  </div>
);

// Inbound / outbound ledger cell.
const FlowCell = ({ tone, label, count, unit, sub }) => {
  const t = tone === 'in'
    ? { bg: DASH.goodSoft, color: DASH.good, icon: 'trendingUp' }
    : { bg: DASH.lateSoft, color: DASH.late, icon: 'trendingDown' };
  return (
    <DashCard style={{ padding: '13px 14px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Eyebrow>{label}</Eyebrow>
        <div style={{
          width: 24, height: 24, borderRadius: 6,
          background: t.bg, color: t.color,
          display: 'grid', placeItems: 'center',
        }}>
          <InvIcon kind={t.icon} s={13} />
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 5, marginTop: 8 }}>
        <span style={{ fontSize: 24, fontWeight: 600, color: t.color, letterSpacing: -0.6, lineHeight: 1, ...DASH.num }}>{count}</span>
        <span style={{ fontSize: 12, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 600 }}>{unit}</span>
      </div>
      <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 6, ...DASH.num }}>{sub}</div>
    </DashCard>
  );
};

const Inv5_Report = () => (
  <InvScreen padBottom={70 + 8}>
    <InvAppBar
      leading={(
        <div style={{
          width: 36, height: 36, borderRadius: 10, background: DASH.surface,
          border: `1px solid ${DASH.border}`, display: 'grid', placeItems: 'center',
        }}>
          <InvIcon kind="back" s={18} />
        </div>
      )}
      title="Daily report"
      sub="May 24 · auto-generated"
      trailing={(
        <InvIconBtn><InvIcon kind="share" s={17} /></InvIconBtn>
      )}
    />

    {/* Hero loss insight — successSoft when zero variance */}
    <Section top={4}>
      <div style={{
        background: DASH.goodSoft,
        border: `1px solid ${DASH.good}33`,
        borderRadius: 14, padding: '14px 16px',
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Eyebrow color={DASH.good}>Unexplained variance · today</Eyebrow>
          <span style={{
            padding: '3px 8px', borderRadius: 6, background: DASH.good, color: '#FFF',
            fontSize: 9.5, fontWeight: 700, fontFamily: DASH.mono, letterSpacing: 0.7,
          }}>VERIFIED</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 8 }}>
          <div style={{ fontSize: 36, fontWeight: 600, color: DASH.good, letterSpacing: -1.1, lineHeight: 1, ...DASH.num }}>
            ৳0
          </div>
          <div style={{ fontSize: 12, color: DASH.good, opacity: 0.8, ...DASH.num }}>
            counted = expected
          </div>
        </div>
        <div style={{ fontSize: 11.5, color: DASH.good, opacity: 0.8, marginTop: 8, lineHeight: 1.4 }}>
          All 8 SKUs reconciled at 6:42 PM — clean book for the day.
        </div>
      </div>
    </Section>

    {/* Revenue Analytics Map */}
    <Section top={14}>
      <RevSplitBar rows={[
        { l: 'Cash',   v: 3850, value: '৳3,850', color: DASH.accent },
        { l: 'Card',   v: 1620, value: '৳1,620', color: DASH.ink },
        { l: 'Online', v: 949,  value: '৳949',   color: DASH.textTer },
      ]} />
    </Section>

    {/* Product Performance Matrix */}
    <Section top={14}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 10, padding: '0 2px' }}>
        <Eyebrow>Top sellers</Eyebrow>
        <div style={{ flex: 1 }} />
        <Eyebrow color={DASH.textTer}>Qty · Revenue</Eyebrow>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <ProductRow top rank={1} name="Beef Tehari"   qty={42} rev="৳2,520" />
        <ProductRow rank={2} name="Chicken Burger" qty={28} rev="৳1,680" />
        <ProductRow rank={3} name="Plain Rice"     qty={31} rev="৳930"   />
        <ProductRow rank={4} name="Borhani"        qty={36} rev="৳720"   />
        <ProductRow rank={5} name="Singara"        qty={28} rev="৳569"   />
      </DashCard>
    </Section>

    {/* Supply logistics tracker */}
    <Section top={14}>
      <Eyebrow>Stock flow · today</Eyebrow>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <FlowCell tone="in"  label="Inbound"  count="+25" unit="kg" sub="1 delivery · Rice" />
        <FlowCell tone="out" label="Outbound" count="−13.4" unit="kg" sub="across 6 SKUs" />
      </div>
    </Section>

    {/* Restock alert panel */}
    <Section top={14}>
      <Eyebrow>Action needed · tomorrow</Eyebrow>
      <div style={{
        background: DASH.warnSoft,
        border: `1px solid ${DASH.warn}33`,
        borderRadius: 14, overflow: 'hidden',
      }}>
        <div style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            width: 28, height: 28, borderRadius: 8,
            background: DASH.warn, color: '#FFF',
            display: 'grid', placeItems: 'center',
          }}>
            <InvIcon kind="alertTriangle" s={15} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: DASH.warn, lineHeight: 1.2 }}>
              2 items below threshold
            </div>
            <div style={{ fontSize: 11, color: DASH.warn, opacity: 0.78, marginTop: 3, ...DASH.num }}>
              Order before tomorrow's lunch service
            </div>
          </div>
        </div>

        {[
          { l: 'M', n: 'Mutton',  bn: '', onHand: '0.8', unit: 'kg', threshold: '1.0', supplier: 'Karim Goshto' },
          { l: 'G', n: 'Ginger',  bn: '',   onHand: '1.4', unit: 'kg', threshold: '2.0', supplier: 'Karwan Bazar' },
        ].map((it, i) => (
          <div key={i} style={{
            padding: '12px 14px',
            background: DASH.surface,
            borderTop: `1px solid ${DASH.warn}22`,
            display: 'flex', alignItems: 'center', gap: 12,
          }}>
            <InvAvatar letter={it.l} size={36} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, lineHeight: 1.2 }}>
                {it.n}
              </div>
              <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3, fontFamily: DASH.mono, fontWeight: 600, ...DASH.num }}>
                <span style={{ color: DASH.warn }}>{it.onHand} {it.unit}</span> / threshold {it.threshold} {it.unit} · {it.supplier}
              </div>
            </div>
            <div style={{
              height: 32, padding: '0 12px', borderRadius: 8,
              border: `1px solid ${DASH.borderStrong}`, background: DASH.surface,
              color: DASH.text, fontSize: 12, fontWeight: 600,
              display: 'inline-flex', alignItems: 'center', gap: 5,
            }}>
              Reorder
              <InvIcon kind="chevronRight" s={13} color={DASH.textSec} />
            </div>
          </div>
        ))}
      </div>
    </Section>

    <div style={{ height: 16 }} />
  </InvScreen>
);

Object.assign(window, { Inv5_Report });
