// Terafoods · Inventory · SCREEN 1 — Inventory Home
// Stack: app bar → KPI trio → category filter → top movers → list → bottom actions.

const Inv1_Home = () => (
  <InvScreen
    bottomBar={(
      <InvBottomBar>
        <InvAction variant="accent" icon="plus">Stock in</InvAction>
        <InvAction variant="ink" icon="clipboardCheck">Start count</InvAction>
      </InvBottomBar>
    )}
  >
    <TopNav title="Inventory" badge={1} />

    {/* KPI header — three cells, no accent. Variance is dim when zero. */}
    <Section top={4}>
      <div style={{
        background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 14,
        display: 'grid', gridTemplateColumns: '1.1fr 1fr 0.95fr', overflow: 'hidden',
      }}>
        {/* Stock value */}
        <div style={{ padding: '14px 14px' }}>
          <Eyebrow>Stock value</Eyebrow>
          <div style={{ fontSize: 22, fontWeight: 600, color: DASH.text, letterSpacing: -0.5, lineHeight: 1, ...DASH.num }}>
            ৳12,096
          </div>
          <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 6, ...DASH.num }}>across 8 SKUs</div>
        </div>
        {/* Used today */}
        <div style={{ padding: '14px 12px', borderLeft: `1px solid ${DASH.border}` }}>
          <Eyebrow>Used today</Eyebrow>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <div style={{ fontSize: 22, fontWeight: 600, color: DASH.text, letterSpacing: -0.5, lineHeight: 1, ...DASH.num }}>
              ৳652
            </div>
          </div>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4, marginTop: 6,
            padding: '2px 7px', borderRadius: 999,
            background: DASH.goodSoft, color: DASH.good,
            fontSize: 10.5, fontWeight: 700, fontFamily: DASH.mono, letterSpacing: 0.3,
            ...DASH.num,
          }}>
            <span>▲</span>+35%
          </div>
        </div>
        {/* Variance */}
        <div style={{ padding: '14px 12px', borderLeft: `1px solid ${DASH.border}` }}>
          <Eyebrow>Variance</Eyebrow>
          <div style={{ fontSize: 22, fontWeight: 600, color: DASH.textTer, letterSpacing: -0.5, lineHeight: 1, ...DASH.num }}>
            ৳0
          </div>
          <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 6 }}>no loss today</div>
        </div>
      </div>
    </Section>

    {/* Category filter — horizontal scroll, "All" active using accentSoft */}
    <Section top={14}>
      <div style={{
        display: 'flex', gap: 8, overflowX: 'auto', paddingLeft: 0, paddingRight: 0,
        scrollbarWidth: 'none',
      }}>
        {[
          { l: 'All',    n: 12, on: true },
          { l: 'Meat',   n: 3 },
          { l: 'Veg',    n: 4 },
          { l: 'Dairy',  n: 2 },
          { l: 'Grains', n: 2 },
          { l: 'Oil',    n: 1 },
        ].map((c, i) => (
          <div key={i} style={{
            padding: '8px 12px', borderRadius: 6,
            background: c.on ? DASH.accentSoft : DASH.surface,
            color: c.on ? DASH.accentInk : DASH.text,
            border: `1px solid ${c.on ? DASH.accent + '55' : DASH.border}`,
            fontSize: 12.5, fontWeight: 600, whiteSpace: 'nowrap',
            display: 'inline-flex', alignItems: 'center', gap: 6,
          }}>
            {c.l}
            <span style={{
              fontSize: 10.5, fontFamily: DASH.mono, fontWeight: 700,
              color: c.on ? DASH.accentInk : DASH.textTer, opacity: 0.85, ...DASH.num,
            }}>{c.n}</span>
          </div>
        ))}
      </div>
    </Section>

    {/* Top movers */}
    <Section top={20}>
      <Eyebrow>Top movers · today</Eyebrow>
      <DashCard padded={false} style={{ padding: '4px 0', overflow: 'hidden' }}>
        {[
          { rank: 1, n: 'Mutton',  qty: '1.8 kg', rev: '৳1,980', pct: 1.00 },
          { rank: 2, n: 'Chicken', qty: '2.5 kg', rev: '৳700',   pct: 0.36 },
          { rank: 3, n: 'Rice',    qty: '4.2 kg', rev: '৳252',   pct: 0.13 },
        ].map((m, i, arr) => (
          <div key={i} style={{
            padding: '12px 14px',
            borderTop: i ? `1px solid ${DASH.divider}` : 'none',
            display: 'flex', alignItems: 'center', gap: 12,
          }}>
            <div style={{ width: 18, fontSize: 11, fontFamily: DASH.mono, fontWeight: 700, color: DASH.textTer, ...DASH.num }}>
              {String(m.rank).padStart(2, '0')}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8 }}>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text }}>{m.n}</div>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text, ...DASH.num }}>{m.rev}</div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 7 }}>
                <div style={{ flex: 1 }}><FillBar pct={m.pct} /></div>
                <div style={{ fontSize: 10.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 600, whiteSpace: 'nowrap', ...DASH.num }}>{m.qty}</div>
              </div>
            </div>
          </div>
        ))}
      </DashCard>
    </Section>

    {/* Inventory list */}
    <Section top={22}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8, padding: '0 2px' }}>
        <Eyebrow>All items</Eyebrow>
        <div style={{ flex: 1 }} />
        <Eyebrow color={DASH.textTer}>On hand · today</Eyebrow>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        {/* Column header — 0.5px hairline rule, mono labels */}
        <div style={{
          display: 'grid', gridTemplateColumns: '1.7fr 0.95fr 0.95fr 0.7fr',
          alignItems: 'center', padding: '8px 14px',
          borderBottom: `1px solid ${DASH.divider}`,
          background: DASH.surfaceAlt,
        }}>
          <div style={{ fontSize: 9.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 700, letterSpacing: 0.7, textTransform: 'uppercase' }}>Item</div>
          <div style={{ fontSize: 9.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 700, letterSpacing: 0.7, textTransform: 'uppercase', textAlign: 'right' }}>On hand</div>
          <div style={{ fontSize: 9.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 700, letterSpacing: 0.7, textTransform: 'uppercase', textAlign: 'right' }}>Today</div>
          <div style={{ fontSize: 9.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 700, letterSpacing: 0.7, textTransform: 'uppercase', textAlign: 'right' }}>Status</div>
        </div>

        {[
          { l: 'R', n: 'Rice',     bn: '',     onHand: '12',  unit: 'kg', today: '—',     todayTone: 'mute',   status: 'good' },
          { l: 'M', n: 'Mutton',   bn: '',   onHand: '0.8', unit: 'kg', today: '−1.8',  todayTone: 'danger', status: 'warn' },
          { l: 'C', n: 'Chicken',  bn: '', onHand: '4.2', unit: 'kg', today: '−2.5',  todayTone: 'down',   status: 'good' },
          { l: 'O', n: 'Onion',    bn: '', onHand: '6.0', unit: 'kg', today: '−0.7',  todayTone: 'down',   status: 'good' },
          { l: 'S', n: 'Soy oil',  bn: '',     onHand: '8.5', unit: 'ltr',today: '−0.4', todayTone: 'down',   status: 'good' },
          { l: 'P', n: 'Potato',   bn: '',     onHand: '4.5', unit: 'kg', today: '—',     todayTone: 'mute',   status: 'good' },
        ].map((it, i, arr) => {
          const todayCol = it.todayTone === 'danger' ? DASH.danger
                          : it.todayTone === 'down' ? DASH.text
                          : DASH.textTer;
          return (
            <div key={i} style={{
              display: 'grid', gridTemplateColumns: '1.7fr 0.95fr 0.95fr 0.7fr',
              alignItems: 'center', padding: '0 14px',
              height: INV.rowH,
              borderBottom: i < arr.length - 1 ? `1px solid ${DASH.divider}` : 'none',
            }}>
              {/* Item */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0 }}>
                <InvAvatar letter={it.l} size={36} />
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text, lineHeight: 1.15, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{it.n}</div>
                </div>
              </div>
              {/* On hand */}
              <div style={{ textAlign: 'right' }}>
                <span style={{ fontSize: 14, fontWeight: 600, color: DASH.text, ...DASH.num }}>{it.onHand}</span>
                <span style={{ fontSize: 11, color: DASH.textTer, marginLeft: 3, fontFamily: DASH.mono, fontWeight: 600 }}>{it.unit}</span>
              </div>
              {/* Today */}
              <div style={{ textAlign: 'right', fontSize: 13, fontWeight: 600, color: todayCol, ...DASH.num }}>
                {it.today}{it.todayTone !== 'mute' && <span style={{ fontFamily: DASH.mono, fontWeight: 600, marginLeft: 2, color: DASH.textTer, fontSize: 10 }}>{it.unit}</span>}
              </div>
              {/* Status */}
              <div style={{ textAlign: 'right' }}>
                {it.status === 'warn'
                  ? <InvPill tone="warn">Low</InvPill>
                  : <span style={{ width: 6, height: 6, borderRadius: 4, background: DASH.textTer, display: 'inline-block', marginRight: 4 }} />}
              </div>
            </div>
          );
        })}
      </DashCard>
    </Section>
  </InvScreen>
);

Object.assign(window, { Inv1_Home });
