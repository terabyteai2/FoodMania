// Terafoods · Inventory · complexity-dial tiers
// P1 SIMPLE (juice bar / tea stall) — stock value · used today · top movers · stock-in/count
// P3 ADVANCED (full-service)        — value · health · food-cost % · reorder · reconciliation · menu costing
// P2 STANDARD uses the existing Inv1_Home (already matches: 3 KPI cards + filtered item list + actions).

// ============================================================================
// Inv_Simple — P1: counter-only (Lebu Fresh juice bar)
// Brief: home is just the "All items" list. Sorted automatically by top moving.
// ============================================================================

const SimpleItemRow = ({ letter, n, onHand, unit, status, first }) => (
  <div style={{
    display: 'grid', gridTemplateColumns: '1.7fr 1fr 0.8fr',
    alignItems: 'center', padding: '0 14px', height: 64,
    borderTop: first ? 'none' : `1px solid ${DASH.divider}`,
  }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0 }}>
      <InvAvatar letter={letter} size={36} />
      <div style={{ minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: DASH.text, lineHeight: 1.15, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{n}</div>
      </div>
    </div>
    <div style={{ textAlign: 'right' }}>
      <span style={{ fontSize: 14, fontWeight: 600, color: DASH.text, ...DASH.num }}>{onHand}</span>
      <span style={{ fontSize: 11, color: DASH.textTer, marginLeft: 3, fontFamily: DASH.mono, fontWeight: 600 }}>{unit}</span>
    </div>
    <div style={{ textAlign: 'right' }}>
      {status === 'warn' ? <InvPill tone="warn">Low</InvPill>
       : status === 'out' ? <InvPill tone="danger">Out</InvPill>
       : <span style={{ width: 7, height: 7, borderRadius: 4, background: DASH.good, display: 'inline-block', marginRight: 4 }} />}
    </div>
  </div>
);

const Inv_Simple = () => (
  <InvScreen
    bottomBar={(
      <InvBottomBar>
        <InvAction variant="accent" icon="plus">Stock in</InvAction>
        <InvAction variant="ink" icon="clipboardCheck">Start count</InvAction>
      </InvBottomBar>
    )}
  >
    <TopNav title="Inventory" />

    {/* All items — auto-sorted by top moving (top sellers float to the top) */}
    <Section top={4}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8, padding: '0 2px' }}>
        <Eyebrow>All items · top moving first</Eyebrow>
        <div style={{ flex: 1 }} />
        <Eyebrow color={DASH.textTer}>5 SKUs</Eyebrow>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <SimpleItemRow first letter="L" n="Lemon"  onHand="40"  unit="pcs" status="good" />
        <SimpleItemRow       letter="G" n="Ginger" onHand="1.2" unit="kg"  status="good" />
        <SimpleItemRow       letter="S" n="Sugar"  onHand="0.9" unit="kg"  status="warn" />
        <SimpleItemRow       letter="M" n="Mint"   onHand="0.2" unit="kg"  status="warn" />
        <SimpleItemRow       letter="W" n="Water"  onHand="48"  unit="btl" status="good" />
      </DashCard>
    </Section>
  </InvScreen>
);

// ============================================================================
// Inv_Standard — P2: small dine-in (Cha Ghor)
// Brief: home is just the "All items" list. Sorted automatically by top moving.
// ============================================================================

const Inv_Standard = () => (
  <InvScreen
    bottomBar={(
      <InvBottomBar>
        <InvAction variant="accent" icon="plus">Stock in</InvAction>
        <InvAction variant="ink" icon="clipboardCheck">Start count</InvAction>
      </InvBottomBar>
    )}
  >
    <TopNav title="Inventory" badge={1} />

    <Section top={4}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8, padding: '0 2px' }}>
        <Eyebrow>All items · top moving first</Eyebrow>
        <div style={{ flex: 1 }} />
        <Eyebrow color={DASH.textTer}>12 SKUs</Eyebrow>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <SimpleItemRow first letter="T" n="Tea leaves"  onHand="2.4" unit="kg"  status="good" />
        <SimpleItemRow       letter="M" n="Milk"        onHand="4.6" unit="ltr" status="good" />
        <SimpleItemRow       letter="S" n="Sugar"       onHand="3.2" unit="kg"  status="good" />
        <SimpleItemRow       letter="O" n="Oil"         onHand="8.5" unit="ltr" status="good" />
        <SimpleItemRow       letter="F" n="Flour"       onHand="6.0" unit="kg"  status="good" />
        <SimpleItemRow       letter="P" n="Potato"      onHand="4.5" unit="kg"  status="good" />
        <SimpleItemRow       letter="N" n="Onion"       onHand="0.8" unit="kg"  status="warn" />
        <SimpleItemRow       letter="E" n="Eggs"        onHand="0"   unit="pcs" status="out" />
      </DashCard>
    </Section>
  </InvScreen>
);


const Inv_Advanced = () => (
  <InvScreen
    bottomBar={(
      <InvBottomBar>
        <InvAction variant="accent" icon="plus">Stock in</InvAction>
        <InvAction variant="ink" icon="clipboardCheck">Start count</InvAction>
      </InvBottomBar>
    )}
  >
    <TopNav title="Inventory" badge={3} />

    {/* KPI trio — Value · Health · Food cost % */}
    <Section top={4}>
      <div style={{
        background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 14,
        display: 'grid', gridTemplateColumns: '1.1fr 0.95fr 1fr', overflow: 'hidden',
      }}>
        <div style={{ padding: '14px 14px' }}>
          <Eyebrow>Stock value</Eyebrow>
          <div style={{ fontSize: 22, fontWeight: 600, color: DASH.text, letterSpacing: -0.5, lineHeight: 1, ...DASH.num }}>৳84,260</div>
          <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 6, ...DASH.num }}>42 SKUs · 6 vendors</div>
        </div>
        <div style={{ padding: '14px 12px', borderLeft: `1px solid ${DASH.border}` }}>
          <Eyebrow>Health</Eyebrow>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
            <div style={{ fontSize: 22, fontWeight: 600, color: DASH.text, letterSpacing: -0.5, lineHeight: 1, ...DASH.num }}>38</div>
            <span style={{ fontSize: 12, color: DASH.textTer, fontWeight: 600, ...DASH.num }}>/42</span>
          </div>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4, marginTop: 6,
            padding: '2px 7px', borderRadius: 999,
            background: DASH.warnSoft, color: DASH.warn,
            fontSize: 10, fontWeight: 700, fontFamily: DASH.mono, letterSpacing: 0.4,
          }}>3 LOW · 1 OUT</div>
        </div>
        <div style={{ padding: '14px 12px', borderLeft: `1px solid ${DASH.border}` }}>
          <Eyebrow>Food cost</Eyebrow>
          <div style={{ fontSize: 22, fontWeight: 600, color: DASH.text, letterSpacing: -0.5, lineHeight: 1, ...DASH.num }}>32%</div>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4, marginTop: 6,
            padding: '2px 7px', borderRadius: 999,
            background: DASH.goodSoft, color: DASH.good,
            fontSize: 10.5, fontWeight: 700, fontFamily: DASH.mono, ...DASH.num,
          }}>
            <span>▼</span>−2.1pt
          </div>
        </div>
      </div>
    </Section>

    {/* Reorder suggestions · 7-day usage */}
    <Section top={20}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8, padding: '0 2px' }}>
        <Eyebrow>Reorder · 7-day usage</Eyebrow>
        <div style={{ flex: 1 }} />
        <Eyebrow color={DASH.textTer}>3 items</Eyebrow>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        {[
          { l: 'M', n: 'Mutton',  onHand: '0.8 kg', rate: '2.1 kg/day', days: '< 1d', qty: '8 kg',  tone: 'danger' },
          { l: 'C', n: 'Chicken', onHand: '4.2 kg', rate: '2.5 kg/day', days: '1.7d', qty: '12 kg', tone: 'warn' },
          { l: 'T', n: 'Tomato',  onHand: '1.2 kg', rate: '1.8 kg/day', days: '< 1d', qty: '10 kg', tone: 'danger' },
        ].map((r, i) => {
          const t = r.tone === 'danger'
            ? { bg: DASH.dangerSoft, c: DASH.danger }
            : { bg: DASH.warnSoft, c: DASH.warn };
          return (
            <div key={i} style={{
              padding: '12px 14px',
              borderTop: i ? `1px solid ${DASH.divider}` : 'none',
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <InvAvatar letter={r.l} size={36} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text }}>{r.n}</span>
                  <span style={{
                    padding: '1px 6px', borderRadius: 4, background: t.bg, color: t.c,
                    fontSize: 9.5, fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.5,
                  }}>{r.days}</span>
                </div>
                <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3, fontFamily: DASH.mono, ...DASH.num }}>
                  on hand {r.onHand} · uses {r.rate}
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text, ...DASH.num }}>Order {r.qty}</div>
                <div style={{
                  fontSize: 10, color: DASH.accent, marginTop: 4,
                  fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.6,
                }}>TAP TO ORDER</div>
              </div>
            </div>
          );
        })}
      </DashCard>
    </Section>

    {/* Yesterday's reconciliation · variance tracking */}
    <Section top={20}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8, padding: '0 2px' }}>
        <Eyebrow>Yesterday's count · variance</Eyebrow>
        <div style={{ flex: 1 }} />
        <Eyebrow color={DASH.danger}>−৳620 net</Eyebrow>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <div style={{
          display: 'grid', gridTemplateColumns: '1.3fr 1fr 1fr 0.9fr',
          padding: '8px 14px', background: DASH.surfaceAlt,
          borderBottom: `1px solid ${DASH.divider}`,
        }}>
          {['Item', 'Counted', 'Δ qty', 'Δ ৳'].map((h, i) => (
            <div key={i} style={{
              fontSize: 9.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 700,
              letterSpacing: 0.7, textTransform: 'uppercase',
              textAlign: i ? 'right' : 'left',
            }}>{h}</div>
          ))}
        </div>
        {[
          { n: 'Beef', counted: '13.2 kg', dQty: '−0.8 kg', dVal: '−৳480', tone: 'danger' },
          { n: 'Oil',  counted: '21.6 L',  dQty: '−0.4 L',  dVal: '−৳140', tone: 'warn' },
          { n: 'Rice', counted: '60.0 kg', dQty: 'OK',      dVal: '—',      tone: 'good' },
        ].map((r, i) => {
          const c = r.tone === 'danger' ? DASH.danger : r.tone === 'warn' ? DASH.warn : DASH.good;
          return (
            <div key={i} style={{
              padding: '11px 14px',
              borderTop: i ? `1px solid ${DASH.divider}` : 'none',
              display: 'grid', gridTemplateColumns: '1.3fr 1fr 1fr 0.9fr',
              alignItems: 'center', gap: 8,
            }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text }}>{r.n}</div>
              <div style={{ fontSize: 12, color: DASH.textSec, textAlign: 'right', fontFamily: DASH.mono, ...DASH.num }}>{r.counted}</div>
              <div style={{ fontSize: 12.5, fontWeight: 600, color: c, textAlign: 'right', fontFamily: DASH.mono, ...DASH.num }}>{r.dQty}</div>
              <div style={{ fontSize: 12, fontWeight: 700, color: c, textAlign: 'right', fontFamily: DASH.mono, ...DASH.num }}>{r.dVal}</div>
            </div>
          );
        })}
      </DashCard>
    </Section>

    {/* Menu costing · top items */}
    <Section top={20}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8, padding: '0 2px' }}>
        <Eyebrow>Menu costing · top items</Eyebrow>
        <div style={{ flex: 1 }} />
        <Eyebrow color={DASH.textTer}>By revenue</Eyebrow>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        {[
          { n: 'Beef Tehari',   price: '৳450', cost: '৳118', fc: 26, tone: 'good' },
          { n: 'Chicken Tikka', price: '৳340', cost: '৳105', fc: 31, tone: 'good' },
          { n: 'Mutton Roast',  price: '৳400', cost: '৳168', fc: 42, tone: 'warn' },
          { n: 'Naan',          price: '৳25',  cost: '৳7',   fc: 28, tone: 'good' },
        ].map((m, i) => {
          const c = m.tone === 'warn' ? DASH.warn : DASH.good;
          const bg = m.tone === 'warn' ? DASH.warnSoft : DASH.goodSoft;
          return (
            <div key={i} style={{
              padding: '11px 14px',
              borderTop: i ? `1px solid ${DASH.divider}` : 'none',
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text }}>{m.n}</div>
                <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3, fontFamily: DASH.mono, ...DASH.num }}>
                  price {m.price} · cost {m.cost}
                </div>
              </div>
              <div style={{
                fontSize: 13, fontWeight: 700, color: c, fontFamily: DASH.mono, ...DASH.num,
                padding: '4px 10px', borderRadius: 6, background: bg,
              }}>FC {m.fc}%</div>
            </div>
          );
        })}
      </DashCard>
    </Section>
  </InvScreen>
);

// Standard tier is the existing Inv1_Home — alias for the complexity-dial section.

Object.assign(window, { Inv_Simple, Inv_Standard, Inv_Advanced, SimpleItemRow });
