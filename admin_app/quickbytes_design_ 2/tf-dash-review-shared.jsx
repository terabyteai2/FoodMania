// Terafoods · Manage Mode — REVIEW tab (owner role)
// Shared primitives for the Review tab across the complexity dial.
// Reuses DASH tokens + the Manage tab's shell so the two tabs feel like one app.

// ============================================================================
// Review-tab palette override — new design_rules.pdf color system
// Only the dashboard Review tab uses RDASH; all other tabs keep DASH.
// ============================================================================
// RDASH = DASH (PosColors now applied globally — no Review-tab overrides needed)
const RDASH = { ...DASH };



// ============================================================================
// Tab switcher — sits under DashHeader. Sticky-feeling segmented control.
// ============================================================================

// ReviewTabs — superseded by TopNav's Manager/Owner toggle per the latest
// brief. Kept as a no-op so any older call sites stay parsing.
const ReviewTabs = () => null;

// ============================================================================
// Vs-yesterday hero — money + delta + (optional) ghost line / mini bars
// ============================================================================

// Compact bar set used inside the hero as a yesterday-comparison strip.
const HeroSpark = ({ today, yesterday, label = 'vs yest' }) => {
  const max = Math.max(...today, ...yesterday) || 1;
  const w = 296, h = 36, gap = 2;
  const bw = (w / today.length) - gap;
  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {yesterday.map((v, i) => {
        const bh = (v / max) * (h - 6);
        return <rect key={`y${i}`} x={i * (bw + gap)} y={h - bh - 2} width={bw} height={bh}
          fill={RDASH.surfaceAlt} stroke={RDASH.borderStrong} strokeWidth="0.5" rx="1" />;
      })}
      {today.map((v, i) => {
        const bh = (v / max) * (h - 6);
        return <rect key={`t${i}`} x={i * (bw + gap)} y={h - bh - 2} width={bw} height={bh}
          fill={RDASH.ink} rx="1" />;
      })}
    </svg>
  );
};

const VsYesterdayHero = ({ today, todayLabel, delta, deltaUp = true, vsBase, vsLabel, todayBars, yesterdayBars, periodNote }) => (
  <div style={{
    background: RDASH.surface, color: RDASH.ink, borderRadius: 14, padding: '16px 16px 14px',
    border: `0.5px solid ${RDASH.border}`, boxShadow: RDASH.shadowSoft,
    position: 'relative', overflow: 'hidden',
  }}>
    <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
      <div style={{ minWidth: 0 }}>
        <MicroLabel>{todayLabel}</MicroLabel>
        <div style={{ fontSize: 11, color: RDASH.textTer, marginTop: 4, fontFamily: RDASH.bn }}></div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
        <span style={{
          display: 'inline-flex', alignItems: 'center', gap: 5,
          background: deltaUp ? RDASH.goodSoft : RDASH.dangerSoft,
          color: deltaUp ? RDASH.good : RDASH.danger,
          fontSize: 12, fontWeight: 600, padding: '4px 10px', borderRadius: 6,
          whiteSpace: 'nowrap', ...RDASH.num,
        }}>
          <span>{deltaUp ? '↑' : '↓'}</span>{delta}
        </span>
        {vsLabel && (
          <span style={{ fontSize: 11, color: RDASH.textTer, fontWeight: 400, ...RDASH.num }}>
            {vsLabel} {vsBase}
          </span>
        )}
      </div>
    </div>
    <div style={{
      fontSize: 48, fontWeight: 700, color: RDASH.ink, marginTop: 12,
      letterSpacing: '-0.03em', lineHeight: 1.0, ...RDASH.num,
    }}>{today}</div>
    {periodNote && (
      <div style={{ fontSize: 13, color: RDASH.textSec, marginTop: 10, lineHeight: 1.5, fontWeight: 400 }}>{periodNote}</div>
    )}
    {todayBars && (
      <div style={{ marginTop: 16, paddingTop: 14, borderTop: `0.5px solid ${RDASH.border}` }}>
        <HeroSpark today={todayBars} yesterday={yesterdayBars} />
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6 }}>
          {['9 AM', '1 PM', '5 PM', '9 PM', '11 PM'].map((l, i) => (
            <span key={i} style={{ fontSize: 11, color: RDASH.textTer, fontWeight: 400, letterSpacing: 0.07 + 'em' }}>{l}</span>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 14, marginTop: 10 }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11, color: RDASH.textSec, fontWeight: 400 }}>
            <span style={{ width: 8, height: 8, background: RDASH.ink, borderRadius: 1 }} />Today
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11, color: RDASH.textTer, fontWeight: 400 }}>
            <span style={{ width: 8, height: 8, background: RDASH.surfaceAlt, border: `0.5px solid ${RDASH.borderStrong}`, borderRadius: 1 }} />Yesterday
          </span>
        </div>
      </div>
    )}
  </div>
);

// ============================================================================
// Hourly bar chart card — bar set with today vs yesterday (ghost)
// ============================================================================

const HourlyBars = ({ today, yesterday, peakHour, height = 96 }) => {
  const max = Math.max(...today, ...(yesterday || [0])) || 1;
  const w = 316, padL = 4, padR = 4, padTop = 6, padBot = 16;
  const innerW = w - padL - padR;
  const bw = innerW / today.length;
  const gap = bw * 0.28;
  return (
    <svg width="100%" height={height} viewBox={`0 0 ${w} ${height}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {/* baseline */}
      <line x1="0" y1={height - padBot} x2={w} y2={height - padBot} stroke={RDASH.border} strokeWidth="0.5" />
      {today.map((v, i) => {
        const yv = yesterday ? yesterday[i] : 0;
        const x = padL + i * bw + gap / 2;
        const bWidth = bw - gap;
        const innerH = height - padTop - padBot;
        const tH = (v / max) * innerH;
        const yH = (yv / max) * innerH;
        return (
          <g key={i}>
            {yesterday && (
              <rect x={x} y={height - padBot - yH} width={bWidth} height={yH}
                fill={RDASH.surfaceAlt} stroke={RDASH.borderStrong} strokeWidth="0.5" rx="1" />
            )}
            <rect x={x + 0.5} y={height - padBot - tH} width={bWidth - 1} height={tH}
              fill={i === peakHour ? RDASH.accent : RDASH.ink} rx="1" />
          </g>
        );
      })}
      {/* hour ticks */}
      {[0, 6, 12, 18, today.length - 1].map((i) => {
        if (i >= today.length) return null;
        const labels = ['9 AM', '12 PM', '3 PM', '6 PM', '11 PM'];
        const map = { 0: 0, 6: 1, 12: 2, 18: 3, [today.length - 1]: 4 };
        return (
          <text key={i}
            x={padL + i * bw + (bw - gap) / 2 + gap / 2}
            y={height - 3}
            textAnchor="middle"
            fontFamily='"JetBrains Mono", monospace'
            fontSize="8" fontWeight="600" fill={RDASH.textTer}
            letterSpacing="0.4">{labels[map[i]]}</text>
        );
      })}
    </svg>
  );
};

const HourlyCard = ({ title = 'Revenue by hour', today, yesterday, peakHour, peakLabel, hasGhost = false }) => (
  <DashCard style={{ padding: '12px 12px 4px' }}>
    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 8, padding: '0 2px' }}>
      <Eyebrow>{title}</Eyebrow>
      {peakLabel && (
        <span style={{ fontSize: 10.5, fontFamily: RDASH.mono, color: RDASH.accent, fontWeight: 700, letterSpacing: 0.3, ...RDASH.num }}>
          PEAK · {peakLabel}
        </span>
      )}
    </div>
    <HourlyBars today={today} yesterday={yesterday} peakHour={peakHour} />
    {hasGhost && (
      <div style={{ display: 'flex', gap: 14, padding: '6px 6px 4px' }}>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11, color: RDASH.textSec }}>
          <span style={{ width: 8, height: 8, background: RDASH.ink, borderRadius: 1 }} />Today
        </span>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11, color: RDASH.textSec }}>
          <span style={{ width: 8, height: 8, background: RDASH.surfaceAlt, border: `0.5px solid ${RDASH.borderStrong}`, borderRadius: 1 }} />7-day avg
        </span>
      </div>
    )}
  </DashCard>
);

// ============================================================================
// Source breakdown — stacked track with legend cells
// ============================================================================

const SourceCard = ({ total, rows, title = 'By source', subtitle }) => {
  const sum = rows.reduce((s, r) => s + r.v, 0) || 1;
  return (
    <DashCard style={{ padding: '12px 14px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <Eyebrow>{title}</Eyebrow>
        {subtitle && <span style={{ fontSize: 10.5, fontFamily: RDASH.mono, color: RDASH.textTer, fontWeight: 600, letterSpacing: 0.3, ...RDASH.num }}>{subtitle}</span>}
      </div>
      {total && (
        <div style={{ fontSize: 22, fontWeight: 600, color: RDASH.text, marginTop: 6, letterSpacing: -0.5, lineHeight: 1, ...RDASH.num }}>
          {total}
        </div>
      )}
      <div style={{ marginTop: 12, height: 8, display: 'flex', background: RDASH.track, borderRadius: 4, overflow: 'hidden' }}>
        {rows.map((r, i) => (
          <div key={i} style={{
            width: `${(r.v / sum) * 100}%`,
            background: r.color,
            borderRight: i < rows.length - 1 ? `1px solid ${RDASH.surface}` : 'none',
          }} />
        ))}
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 12, gap: 8 }}>
        {rows.map((r, i) => (
          <div key={i} style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, background: r.color }} />
              <span style={{ fontSize: 11, color: RDASH.textSec, fontWeight: 600 }}>{r.l}</span>
            </div>
            <div style={{ fontSize: 13, fontWeight: 600, color: RDASH.text, marginTop: 4, ...RDASH.num }}>{r.value}</div>
            <div style={{ fontSize: 10, color: RDASH.textTer, marginTop: 2, fontFamily: RDASH.mono, ...RDASH.num }}>
              {Math.round((r.v / sum) * 100)}%
            </div>
          </div>
        ))}
      </div>
    </DashCard>
  );
};

// ============================================================================
// Top items list — variant for review (qty, revenue, margin)
// ============================================================================

const TopItemRow = ({ rank, name, bn, qty, rev, margin, foodCost, warnLabel, first }) => (
  <div style={{
    padding: '11px 14px',
    borderTop: first ? 'none' : `1px solid ${RDASH.divider}`,
    display: 'flex', alignItems: 'center', gap: 12,
  }}>
    <div style={{
      width: 22, height: 22, borderRadius: 6,
      background: rank === 1 ? RDASH.ink : RDASH.surfaceAlt,
      color: rank === 1 ? RDASH.accentOnInk : RDASH.textTer,
      display: 'grid', placeItems: 'center',
      fontSize: 10, fontFamily: RDASH.mono, fontWeight: 700, ...RDASH.num,
    }}>{rank}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: RDASH.text, lineHeight: 1.15 }}>{name}</div>
      <div style={{ fontSize: 11, color: RDASH.textTer, marginTop: 2, display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
        {bn && <span style={{ fontFamily: RDASH.bn }}>{bn}</span>}
        <span style={{ fontFamily: RDASH.mono, fontWeight: 600, ...RDASH.num }}>×{qty}</span>
        {foodCost != null && (
          <span style={{ fontFamily: RDASH.mono, fontWeight: 600, color: foodCost > 38 ? RDASH.late : RDASH.textTer, ...RDASH.num }}>
            FC {foodCost}%
          </span>
        )}
        {warnLabel && (
          <span style={{
            fontSize: 9.5, fontFamily: RDASH.mono, fontWeight: 700,
            color: RDASH.warn, background: RDASH.warnSoft,
            padding: '2px 6px', borderRadius: 4, letterSpacing: 0.3,
            textTransform: 'uppercase',
          }}>{warnLabel}</span>
        )}
      </div>
    </div>
    <div style={{ textAlign: 'right' }}>
      <div style={{ fontSize: 13.5, fontWeight: 600, color: RDASH.text, ...RDASH.num }}>{rev}</div>
      {margin && (
        <div style={{ fontSize: 10.5, color: RDASH.good, marginTop: 3, fontFamily: RDASH.mono, fontWeight: 700, ...RDASH.num }}>
          +{margin} margin
        </div>
      )}
    </div>
  </div>
);

// ============================================================================
// Profitability matrix — 2×2 quadrant (Stars/Steady/Puzzle/Review)
// ============================================================================

const PROFIT_QUADS = {
  star:   { l: 'Stars',  sub: 'high margin · popular', color: RDASH.good,    bg: RDASH.goodSoft },
  steady: { l: 'Steady', sub: 'low margin · popular',  color: RDASH.textSec, bg: RDASH.surfaceAlt },
  puzzle: { l: 'Puzzle', sub: 'high margin · slow',    color: RDASH.warn,    bg: RDASH.warnSoft },
  review: { l: 'Review', sub: 'low margin · slow',     color: RDASH.danger,  bg: RDASH.dangerSoft },
};

const ProfitMatrix = ({ items }) => {
  // items: { quad, name, n }
  const grouped = { star: [], steady: [], puzzle: [], review: [] };
  items.forEach((it) => { if (grouped[it.quad]) grouped[it.quad].push(it); });
  const order = ['star', 'puzzle', 'steady', 'review'];
  return (
    <DashCard style={{ padding: '0' }}>
      <div style={{ padding: '12px 14px', borderBottom: `1px solid ${RDASH.divider}` }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <Eyebrow>Menu profitability · 30-day</Eyebrow>
          <span style={{ fontSize: 10.5, fontFamily: RDASH.mono, color: RDASH.textTer, fontWeight: 600, letterSpacing: 0.4 }}>VOLUME × MARGIN</span>
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr' }}>
        {order.map((k, i) => {
          const q = PROFIT_QUADS[k];
          const its = grouped[k];
          return (
            <div key={k} style={{
              padding: '12px 14px',
              borderRight: i % 2 === 0 ? `1px solid ${RDASH.divider}` : 'none',
              borderTop: i >= 2 ? `1px solid ${RDASH.divider}` : 'none',
              minHeight: 110,
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ width: 6, height: 6, borderRadius: 3, background: q.color }} />
                <span style={{ fontSize: 12, fontWeight: 700, color: q.color, letterSpacing: -0.1 }}>{q.l}</span>
                <span style={{ fontSize: 10, color: RDASH.textTer, fontFamily: RDASH.mono, fontWeight: 600, ...RDASH.num }}>×{its.length}</span>
              </div>
              <div style={{ fontSize: 10, color: RDASH.textTer, marginTop: 3 }}>{q.sub}</div>
              <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 4 }}>
                {its.slice(0, 3).map((it, j) => (
                  <div key={j} style={{
                    fontSize: 11.5, color: RDASH.text, fontWeight: 600,
                    background: q.bg, padding: '4px 8px', borderRadius: 5,
                    display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
                  }}>
                    <span style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{it.name}</span>
                    <span style={{ fontSize: 10, fontFamily: RDASH.mono, color: q.color, fontWeight: 700, marginLeft: 6, ...RDASH.num }}>×{it.n}</span>
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </DashCard>
  );
};

// ============================================================================
// Staff scoreboard row — covers, ticket, service time
// ============================================================================

const StaffScoreRow = ({ rank, name, role, covers, ticket, time, mistakes, first }) => {
  const top = rank === 1;
  return (
    <div style={{
      padding: '11px 14px',
      borderTop: first ? 'none' : `1px solid ${RDASH.divider}`,
      display: 'flex', alignItems: 'center', gap: 12,
    }}>
      <div style={{
        width: 30, height: 30, borderRadius: 15, flexShrink: 0,
        background: top ? RDASH.ink : RDASH.surfaceAlt,
        color: top ? RDASH.accentOnInk : RDASH.text,
        border: top ? `1px solid ${RDASH.ink}` : `1px solid ${RDASH.border}`,
        display: 'grid', placeItems: 'center',
        fontSize: 11, fontWeight: 700,
      }}>{name.slice(0, 1)}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
          <span style={{ fontSize: 13, fontWeight: 600, color: RDASH.text }}>{name}</span>
          {top && (
            <span style={{
              fontSize: 9, fontFamily: RDASH.mono, fontWeight: 700, color: RDASH.accentInk,
              background: RDASH.accentSoft, padding: '2px 5px', borderRadius: 3, letterSpacing: 0.5,
            }}>TOP</span>
          )}
        </div>
        <div style={{ fontSize: 11, color: RDASH.textTer, marginTop: 2, fontFamily: RDASH.mono, fontWeight: 600, ...RDASH.num }}>
          {role} · {covers} covers · avg {ticket}
        </div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: RDASH.text, ...RDASH.num }}>{time}</div>
        <div style={{ fontSize: 10.5, color: mistakes > 0 ? RDASH.late : RDASH.textTer, marginTop: 3, fontFamily: RDASH.mono, fontWeight: 600, ...RDASH.num }}>
          {mistakes > 0 ? `${mistakes} comp` : 'clean'}
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// Outlet rank row (Enterprise)
// ============================================================================

const OutletRankRow = ({ rank, name, area, rev, covers, deltaPct, deltaUp, foodCost, badge, first }) => (
  <div style={{
    padding: '12px 14px',
    borderTop: first ? 'none' : `1px solid ${RDASH.divider}`,
    display: 'flex', alignItems: 'center', gap: 12,
  }}>
    <div style={{
      width: 28, height: 28, borderRadius: 8,
      background: rank === 1 ? RDASH.ink : (rank === 2 ? RDASH.accentSoft : RDASH.surfaceAlt),
      color: rank === 1 ? RDASH.accentOnInk : (rank === 2 ? RDASH.accentInk : RDASH.textSec),
      display: 'grid', placeItems: 'center',
      fontSize: 11, fontFamily: RDASH.mono, fontWeight: 700, ...RDASH.num,
    }}>{rank}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 13, fontWeight: 600, color: RDASH.text }}>{name}</span>
        {badge && (
          <span style={{
            fontSize: 9, fontFamily: RDASH.mono, fontWeight: 700, color: badge.color || RDASH.accent,
            background: badge.bg || RDASH.accentSoft, padding: '2px 5px', borderRadius: 3, letterSpacing: 0.5,
          }}>{badge.t}</span>
        )}
      </div>
      <div style={{ fontSize: 11, color: RDASH.textTer, marginTop: 2, fontFamily: RDASH.mono, ...RDASH.num }}>
        {area} · {covers} covers · FC {foodCost}%
      </div>
    </div>
    <div style={{ textAlign: 'right' }}>
      <div style={{ fontSize: 14, fontWeight: 600, color: RDASH.text, letterSpacing: -0.2, ...RDASH.num }}>{rev}</div>
      <div style={{ fontSize: 10.5, fontWeight: 700, color: deltaUp ? RDASH.good : RDASH.late, marginTop: 3, fontFamily: RDASH.mono, ...RDASH.num }}>
        {deltaUp ? '▲' : '▼'} {deltaPct}
      </div>
    </div>
  </div>
);

Object.assign(window, {
  RDASH,
  ReviewTabs, VsYesterdayHero, HeroSpark,
  HourlyBars, HourlyCard, SourceCard,
  TopItemRow, ProfitMatrix, PROFIT_QUADS,
  StaffScoreRow, OutletRankRow,
});
