// Terafoods · Inventory · SCREEN 2 — Item Detail (Rice)
// Stack: app bar → hero qty + health pill → 3-fact row → 30-day chart →
// ledger list (with inline threshold row) → bottom actions.

// Daily movement vectors for Rice over 30 days. Positive = restock, negative = use.
// Realistic shape: small daily consumption, three replenishment spikes.
const RICE_30D = (() => {
  const days = [];
  const restockDays = new Set([3, 12, 22]);
  for (let i = 0; i < 30; i++) {
    if (restockDays.has(i)) {
      days.push(25 + (i === 12 ? 5 : 0)); // restock 25–30 kg
    } else {
      // daily use 0.6–1.8 kg
      const seed = (i * 7 + 3) % 13;
      days.push(-(0.6 + (seed / 13) * 1.2));
    }
  }
  return days;
})();

// Custom bar chart — no graphs library, no gridlines.
const MovementChart = ({ data, height = 120, width = 328 }) => {
  const padTop = 14, padBot = 18, midPad = 0;
  const innerH = height - padTop - padBot;
  const max = Math.max(...data.map((v) => Math.abs(v)));
  const barW = (width - 6) / data.length;
  const gap = barW * 0.28;
  const w = barW - gap;
  return (
    <svg width="100%" height={height} viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {/* baseline */}
      <line x1="0" y1={padTop + innerH / 2} x2={width} y2={padTop + innerH / 2}
        stroke={DASH.border} strokeWidth="0.5" />
      {data.map((v, i) => {
        const up = v >= 0;
        const h = (Math.abs(v) / max) * (innerH / 2 - midPad);
        const x = 3 + i * barW + gap / 2;
        const y = up ? padTop + innerH / 2 - h : padTop + innerH / 2;
        return (
          <rect key={i} x={x} y={y} width={w} height={Math.max(1.2, h)}
            fill={up ? DASH.accent : DASH.textTer}
            rx={0.8} />
        );
      })}
      {/* day axis ticks (1, 10, 20, 30) */}
      {[0, 9, 19, 29].map((i) => (
        <text key={i}
          x={3 + i * barW + (barW - gap) / 2 + gap / 2}
          y={height - 4}
          textAnchor="middle"
          fontFamily='"JetBrains Mono", monospace'
          fontSize="8" fontWeight="600" fill={DASH.textTer}
          letterSpacing="0.4">{i + 1}</text>
      ))}
    </svg>
  );
};

// Ledger row — recent movements (last 5).
const LedgerRow = ({ date, time, label, delta, deltaUp, after }) => (
  <div style={{
    padding: '12px 14px',
    display: 'flex', alignItems: 'center', gap: 12,
    borderTop: `1px solid ${DASH.divider}`,
  }}>
    <div style={{
      width: 28, height: 28, borderRadius: 8, flexShrink: 0,
      background: deltaUp ? DASH.goodSoft : DASH.surfaceAlt,
      color: deltaUp ? DASH.good : DASH.textSec,
      display: 'grid', placeItems: 'center',
    }}>
      <InvIcon kind={deltaUp ? 'trendingUp' : 'trendingDown'} s={14} />
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, lineHeight: 1.2 }}>{label}</div>
      <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3, fontFamily: DASH.mono, ...DASH.num }}>
        {date} · {time}
      </div>
    </div>
    <div style={{ textAlign: 'right' }}>
      <div style={{ fontSize: 14, fontWeight: 600, color: deltaUp ? DASH.good : DASH.text, ...DASH.num }}>
        {deltaUp ? '+' : '−'}{delta}<span style={{ fontSize: 10, fontFamily: DASH.mono, color: DASH.textTer, marginLeft: 2, fontWeight: 600 }}>kg</span>
      </div>
      <div style={{ fontSize: 10.5, color: DASH.textTer, marginTop: 3, fontFamily: DASH.mono, ...DASH.num }}>→ {after} kg</div>
    </div>
  </div>
);

const Inv2_Detail = () => (
  <InvScreen
    bottomBar={(
      <InvBottomBar>
        <InvAction variant="accent" icon="plus">Stock in</InvAction>
        <InvAction variant="ghost" icon="edit">Edit item</InvAction>
      </InvBottomBar>
    )}
  >
    <InvAppBar
      leading={(
        <div style={{
          width: 36, height: 36, borderRadius: 10, background: DASH.surface,
          border: `1px solid ${DASH.border}`, display: 'grid', placeItems: 'center',
        }}>
          <InvIcon kind="back" s={18} />
        </div>
      )}
      title="Rice"
      sub="Grains · ৳60/kg"
      trailing={(
        <InvIconBtn><InvIcon kind="moreVertical" s={18} /></InvIconBtn>
      )}
    />

    {/* Hero — On hand 44px numericHero + HEALTHY pill */}
    <Section top={4}>
      <DashCard style={{ padding: '16px 16px 18px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Eyebrow>On hand</Eyebrow>
          <InvPill tone="good">
            <span style={{ width: 5, height: 5, borderRadius: 3, background: DASH.good }} />
            Healthy
          </InvPill>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 8 }}>
          <div style={{ fontSize: 44, fontWeight: 600, color: DASH.text, letterSpacing: -1.4, lineHeight: 1, ...DASH.num }}>
            12
          </div>
          <div style={{ fontSize: 18, fontWeight: 600, color: DASH.textSec, fontFamily: DASH.mono }}>kg</div>
          <div style={{ flex: 1 }} />
          <div style={{ fontSize: 12, color: DASH.textTer, fontFamily: DASH.mono, ...DASH.num }}>
            = ৳720
          </div>
        </div>
      </DashCard>
    </Section>

    {/* 3-Fact row */}
    <Section top={10}>
      <div style={{
        background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 14,
        display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', overflow: 'hidden',
      }}>
        {[
          { l: 'Avg daily', v: '1.2', u: 'kg/day' },
          { l: 'Remaining', v: '10',  u: 'days' },
          { l: 'Restocked', v: '5',   u: 'days ago' },
        ].map((f, i) => (
          <div key={i} style={{
            padding: '12px 12px',
            borderLeft: i ? `1px solid ${DASH.border}` : 'none',
          }}>
            <Eyebrow>{f.l}</Eyebrow>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
              <div style={{ fontSize: 20, fontWeight: 600, color: DASH.text, letterSpacing: -0.4, lineHeight: 1, ...DASH.num }}>{f.v}</div>
              <div style={{ fontSize: 11, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 600 }}>{f.u}</div>
            </div>
          </div>
        ))}
      </div>
    </Section>

    {/* 30-day movement chart */}
    <Section top={14}>
      <div style={{ display: 'flex', alignItems: 'baseline', marginBottom: 10, padding: '0 2px' }}>
        <Eyebrow>30-day movement</Eyebrow>
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: 11, color: DASH.textTer, fontFamily: DASH.mono, ...DASH.num }}>
          Apr 24 — May 24
        </div>
      </div>
      <DashCard style={{ padding: '8px 8px 4px' }}>
        <MovementChart data={RICE_30D} />
        <div style={{ display: 'flex', gap: 16, padding: '4px 8px 6px' }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, color: DASH.textSec }}>
            <span style={{ width: 8, height: 8, background: DASH.accent, borderRadius: 1 }} />
            Restock
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, color: DASH.textSec }}>
            <span style={{ width: 8, height: 8, background: DASH.textTer, borderRadius: 1 }} />
            Used
          </span>
        </div>
      </DashCard>
    </Section>

    {/* Ledger — recent movements */}
    <Section top={14}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8, padding: '0 2px' }}>
        <Eyebrow>Recent movements</Eyebrow>
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: 11, color: DASH.textTer, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 3 }}>
          See all <InvIcon kind="chevronRight" s={12} color={DASH.textTer} />
        </div>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        {[
          { date: 'May 24', time: '6:30 PM', label: 'End-of-day count', delta: '1.2', deltaUp: false, after: '12.0' },
          { date: 'May 24', time: '1:14 PM', label: 'Lunch service · Tehari',  delta: '2.4', deltaUp: false, after: '13.2' },
          { date: 'May 24', time: '11:02 AM',label: 'Prep · Beef Tehari batch', delta: '1.8', deltaUp: false, after: '15.6' },
          { date: 'May 19', time: '9:45 AM', label: 'Restock · Karwan Bazar', delta: '25.0', deltaUp: true,  after: '17.4' },
          { date: 'May 18', time: '7:48 PM', label: 'Dinner service',          delta: '1.4', deltaUp: false, after: '−7.6' },
        ].map((r, i) => (
          <LedgerRow key={i} {...r} />
        ))}

        {/* Inline threshold config row */}
        <div style={{
          padding: '12px 14px',
          background: DASH.surfaceAlt,
          borderTop: `1px solid ${DASH.divider}`,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{
            width: 28, height: 28, borderRadius: 8, flexShrink: 0,
            background: DASH.warnSoft, color: DASH.warn,
            display: 'grid', placeItems: 'center',
          }}>
            <InvIcon kind="alertTriangle" s={14} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 12.5, fontWeight: 600, color: DASH.text }}>Low-stock alert at</div>
            <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 2 }}>Warns you when on-hand drops below</div>
          </div>
          <div style={{
            padding: '6px 10px', borderRadius: 6, border: `1px solid ${DASH.borderStrong}`,
            background: DASH.surface, display: 'flex', alignItems: 'center', gap: 6,
          }}>
            <span style={{ fontSize: 14, fontWeight: 600, color: DASH.text, ...DASH.num }}>5</span>
            <span style={{ fontSize: 11, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 600 }}>kg</span>
            <span style={{ width: 1, height: 14, background: DASH.border, marginLeft: 2 }} />
            <InvIcon kind="edit" s={13} color={DASH.textSec} />
          </div>
        </div>
      </DashCard>
    </Section>
  </InvScreen>
);

Object.assign(window, { Inv2_Detail });
