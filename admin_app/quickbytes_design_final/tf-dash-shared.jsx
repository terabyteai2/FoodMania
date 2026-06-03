// Terafoods · Manage-Mode dashboard — PosColors design system
// ============================================================================
// 1 · Tokens
// ============================================================================

const DASH = {
  // Scaffolding — Neutral-cool violet base
  bg:           '#F8F8FA',   // paper — scaffold
  surface:      '#FFFFFF',   // surface — cards/sheets
  surfaceAlt:   '#F1F1F5',   // surfaceSunk — wells, search fills
  track:        '#F1F1F5',   // track fill
  trackInk:     'rgba(255,255,255,0.14)',

  // Ink — Violet-black
  ink:          '#16101E',   // ink — primary text
  inkRaised:    '#2D2438',   // inkSoft — secondary emphasis
  text:         '#16101E',
  textSec:      '#635B6E',   // muted
  textTer:      '#A097AB',   // mutedSoft
  onInk:        '#FFFFFF',
  onInkSec:     'rgba(255,255,255,0.72)',
  onInkTer:     'rgba(255,255,255,0.48)',

  // Borders
  border:       '#E2DDE8',   // line
  borderStrong: '#CAC3D4',   // lineStrong
  divider:      '#E2DDE8',

  // Accent — Deep Plum. ≤ 5% of viewport.
  accent:       '#4C1D5E',   // primary CTAs, FAB, focused states
  accentDeep:   '#351244',   // pressed
  accentMid:    '#6B3080',   // secondary CTAs (never with full accent in same viewport)
  accentSoft:   '#E8D8F0',   // selected backgrounds — pair with ink only
  accentWash:   '#F4EDF8',   // hover tints, non-interactive only
  accentInk:    '#FFFFFF',   // text/icons on full-strength accent
  accentSoftInk:'#16101E',   // text on accentSoft (= ink)
  accentOnInk:  '#E8D8F0',   // accentSoft used as accent-on-dark surfaces

  // Signals — functional only
  good:         '#15803D',   // success
  goodSoft:     '#DCFCE7',
  warn:         '#B45309',   // warning — low stock
  warnSoft:     '#FEF3C7',
  late:         '#9A3412',   // urgent — late/expedite
  lateSoft:     '#FFEDD5',
  danger:       '#7F1D1D',
  dangerSoft:   '#FEE2E2',

  // Type
  font:         'Inter, system-ui, sans-serif',
  mono:         'Inter, system-ui, sans-serif',   // tabular numerics use Inter w600 + tnum
  bn:           '"Hind Siliguri", Inter, sans-serif',
  num:          { fontFeatureSettings: '"tnum" 1, "cv01" 1', fontVariantNumeric: 'tabular-nums' },

  // Shadows — cast in violet-black (rgb 22,16,30)
  shadowSoft:   '0 1px 2px rgba(22,16,30,0.05)',
  shadowGlow:   '0 4px 12px rgba(22,16,30,0.07)',
  shadowRaised: '0 8px 24px rgba(22,16,30,0.09)',
};

const dashCardStyle = (extra) => ({
  background: DASH.surface, border: `1px solid ${DASH.border}`,
  borderRadius: 14, padding: '14px 14px', ...extra,
});
const DashCard = ({ children, style, padded = true }) => (
  <div style={dashCardStyle({ padding: padded ? '14px 14px' : 0, ...style })}>{children}</div>
);

// Tiny mono micro-label "TODAY · 10:42AM"
const MicroLabel = ({ children, color, style }) => (
  <span style={{
    fontSize: 10, fontFamily: DASH.mono, color: color || DASH.textTer,
    letterSpacing: 0.6, textTransform: 'uppercase', fontWeight: 600, ...style,
  }}>{children}</span>
);

const Bn = ({ children, dim }) => (
  <span style={{ fontFamily: DASH.bn, color: dim || DASH.textTer, fontWeight: 400 }}>{children}</span>
);

// ============================================================================
// 2 · Shell — cool-gray phone body + bottom nav
// ============================================================================

const DASH_NAV_DEFAULT = [
  { kind: 'orders', label: 'Orders' },
  { kind: 'menu', label: 'Menu' },
  { kind: 'home', label: 'Home' },
  { kind: 'inventory', label: 'Stock' },
  { kind: 'settings', label: 'More' },
];

const DashBottomNav = ({ items, active = 2 }) => {
  const list = items || DASH_NAV_DEFAULT;
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, height: 70,
      background: DASH.surface, borderTop: `1px solid ${DASH.border}`,
      display: 'flex', alignItems: 'flex-start', justifyContent: 'space-around',
      padding: '10px 0 0',
    }}>
      {list.map((it, i) => {
        const on = i === active;
        return (
          <div key={i} style={{
            flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
            color: on ? DASH.text : DASH.textTer,
          }}>
            <div style={{
              width: 36, height: 22, borderRadius: 6, display: 'grid', placeItems: 'center',
              background: on ? DASH.ink : 'transparent', color: on ? DASH.onInk : DASH.textTer,
            }}>
              <NavIcon kind={it.kind} />
            </div>
            <div style={{ fontSize: 10.5, fontWeight: on ? 600 : 500, lineHeight: 1, color: on ? DASH.text : DASH.textTer }}>
              {it.label}
            </div>
          </div>
        );
      })}
    </div>
  );
};

const DashScreen = ({ children, nav, navActive = 2, bg }) => (
  <div style={{
    position: 'relative', height: '100%', background: bg || DASH.bg, overflow: 'hidden',
    fontFamily: DASH.font, color: DASH.text,
  }}>
    <div style={{
      position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'hidden',
      paddingBottom: 80, WebkitOverflowScrolling: 'touch',
    }}>
      {children}
    </div>
    <DashBottomNav items={nav} active={navActive} />
  </div>
);

// ============================================================================
// 3 · Header — compact identity bar
// ============================================================================

const TierBadge = ({ label, bn, tone = 'paper' }) => {
  const tones = {
    paper: { bg: DASH.surface, color: DASH.text, border: DASH.borderStrong, dot: DASH.accent },
    amber: { bg: DASH.accentSoft, color: DASH.accentInk, border: DASH.accent, dot: DASH.accent },
    dark:  { bg: DASH.ink, color: DASH.onInk, border: DASH.ink, dot: DASH.accentOnInk },
  }[tone];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '5px 10px', borderRadius: 6,
      fontSize: 10.5, fontFamily: DASH.mono, fontWeight: 600,
      letterSpacing: 0.6, textTransform: 'uppercase',
      background: tones.bg, color: tones.color, border: `1px solid ${tones.border}`,
    }}>
      <span style={{ width: 6, height: 6, borderRadius: 3, background: tones.dot }} />
      {label}
      {bn && <Bn dim={tone === 'dark' ? DASH.onInkSec : DASH.textTer}>{bn}</Bn>}
    </span>
  );
};

const HeaderIconBtn = ({ children, badge }) => (
  <div style={{
    width: 40, height: 40, borderRadius: 10, background: DASH.surface,
    border: `1px solid ${DASH.border}`, display: 'grid', placeItems: 'center',
    color: DASH.text, position: 'relative',
  }}>
    {children}
    {badge != null && (
      <div style={{
        position: 'absolute', top: -4, right: -4, minWidth: 18, height: 18, padding: '0 5px',
        borderRadius: 9, background: DASH.late, color: '#FFF', fontSize: 10, fontWeight: 600,
        display: 'grid', placeItems: 'center', border: `2px solid ${DASH.bg}`, ...DASH.num,
      }}>{badge}</div>
    )}
  </div>
);

const DashHeader = ({ greet, emoji, biz, bn, date, tier, tierBn, tierTone, badge }) => (
  <div style={{ padding: '14px 16px 12px' }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <MicroLabel>{date}</MicroLabel>
        <div style={{ fontSize: 17, fontWeight: 600, color: DASH.text, marginTop: 4, letterSpacing: -0.3, lineHeight: 1.15 }}>
          {biz} {emoji}
        </div>
        <div style={{ fontSize: 12, color: DASH.textSec, marginTop: 3 }}>
          {greet}{bn && <> · <Bn dim={DASH.textTer}>{bn}</Bn></>}
        </div>
      </div>
      <HeaderIconBtn>
        <span style={{ fontSize: 11, fontFamily: DASH.mono, fontWeight: 600, letterSpacing: 0.4 }}>EN</span>
      </HeaderIconBtn>
      <HeaderIconBtn badge={badge}><NavIcon kind="bell" /></HeaderIconBtn>
    </div>
    <div style={{ marginTop: 12 }}>
      <TierBadge label={tier} bn={tierBn} tone={tierTone} />
    </div>
  </div>
);

// ============================================================================
// 4 · Section / divider — priority rails
// ============================================================================

const Section = ({ children, top = 14 }) => (
  <div style={{ padding: `${top}px 16px 0` }}>{children}</div>
);

const SecHead = ({ title, bn, action, count, accent }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10, padding: '0 2px' }}>
    <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, letterSpacing: -0.1 }}>{title}</div>
    {bn && <Bn>{bn}</Bn>}
    <div style={{ flex: 1 }} />
    {count != null && (
      <span style={{
        background: accent || DASH.late, color: '#FFF', fontSize: 11, fontWeight: 600,
        minWidth: 20, height: 20, padding: '0 7px', borderRadius: 999,
        display: 'inline-grid', placeItems: 'center', ...DASH.num,
      }}>{count}</span>
    )}
    {action && (
      <span style={{ fontSize: 12, color: DASH.textSec, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 3 }}>
        {action}
        <span style={{ opacity: 0.5 }}><NavIcon kind="chevron" /></span>
      </span>
    )}
  </div>
);

// Zone divider — full-bleed band with a tag chip in the middle.
const Divider = ({ label, bn }) => (
  <div style={{
    margin: '6px 0 4px', display: 'flex', alignItems: 'center', gap: 0,
    background: 'transparent',
  }}>
    <div style={{ flex: 1, height: 1, background: DASH.borderStrong }} />
    <div style={{
      padding: '5px 12px', borderRadius: 999, background: DASH.surface,
      border: `1px solid ${DASH.borderStrong}`,
      fontSize: 10, fontFamily: DASH.mono, fontWeight: 600, color: DASH.textSec,
      letterSpacing: 0.8, textTransform: 'uppercase', whiteSpace: 'nowrap',
      display: 'inline-flex', alignItems: 'center', gap: 6,
    }}>
      <span style={{ width: 5, height: 5, borderRadius: 3, background: DASH.textTer }} />
      {label}{bn && <Bn>{bn}</Bn>}
    </div>
    <div style={{ flex: 1, height: 1, background: DASH.borderStrong }} />
  </div>
);

// ============================================================================
// 5 · Sparkline + mini spark
// ============================================================================

const Sparkline = ({ height = 56, points, accent, onInk = false }) => {
  const pts = points || [0.18, 0.30, 0.22, 0.42, 0.36, 0.55, 0.62, 0.58, 0.78, 0.72, 0.92, 1.00];
  const col = accent || (onInk ? DASH.accentOnInk : DASH.accent);
  const width = 296, padX = 4, padTop = 10, padBot = 6;
  const innerW = width - padX * 2, innerH = height - padTop - padBot;
  const dx = innerW / (pts.length - 1);
  const xs = pts.map((_, i) => padX + i * dx);
  const ys = pts.map(p => padTop + innerH - p * innerH);
  const smooth = pts.map((_, i) => {
    if (i === 0) return `M${xs[i]},${ys[i]}`;
    const x0 = xs[i - 1], y0 = ys[i - 1], x1 = xs[i], y1 = ys[i];
    const cx = x0 + (x1 - x0) / 2;
    return `C${cx},${y0} ${cx},${y1} ${x1},${y1}`;
  }).join(' ');
  // Baseline tick + segmented horizontal grid (4 cols)
  return (
    <svg width="100%" height={height} viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {/* segment ticks */}
      {[0.25, 0.5, 0.75].map((t, i) => (
        <line key={i} x1={padX + t * innerW} y1={padTop} x2={padX + t * innerW} y2={height - padBot}
          stroke={onInk ? 'rgba(255,255,255,0.08)' : DASH.divider} strokeWidth="1" />
      ))}
      <path d={smooth} fill="none" stroke={col} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round" />
      <circle cx={xs[xs.length - 1]} cy={ys[ys.length - 1]} r="3.5"
        fill={onInk ? DASH.ink : DASH.surface} stroke={col} strokeWidth="1.8" />
    </svg>
  );
};

const MiniSpark = ({ points, accent, w = 56, h = 22, up = true, onInk = false }) => {
  const pts = points || [0.4, 0.5, 0.35, 0.6, 0.55, 0.8, 0.72, 1.0];
  const col = accent || (up ? DASH.accent : DASH.late);
  const dx = w / (pts.length - 1);
  const xs = pts.map((_, i) => i * dx);
  const ys = pts.map(p => h - 2 - p * (h - 4));
  const d = xs.map((x, i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${ys[i].toFixed(1)}`).join(' ');
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block' }}>
      <path d={d} fill="none" stroke={col} strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
};

// ============================================================================
// 6 · EarnedCard — inverted-ink hero (the ONE primary metric per screen)
// ============================================================================

const EarnedCard = ({ amount, bn = 'আজকের আয়', delta, deltaUp = true, note, spark, sparkPts, label = 'Earned today' }) => (
  <div style={{
    background: DASH.surface, color: DASH.ink, borderRadius: 14, padding: '16px 16px 14px',
    border: `0.5px solid ${DASH.border}`, boxShadow: DASH.shadowSoft,
    position: 'relative', overflow: 'hidden',
  }}>
    <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
      <div style={{ minWidth: 0 }}>
        <MicroLabel>{label}</MicroLabel>
        <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 4, fontFamily: DASH.bn }}>{bn}</div>
      </div>
      {delta && (
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 5,
          background: deltaUp ? DASH.goodSoft : DASH.dangerSoft,
          color: deltaUp ? DASH.good : DASH.danger,
          fontSize: 12, fontWeight: 600, padding: '4px 10px', borderRadius: 6,
          whiteSpace: 'nowrap', ...DASH.num,
        }}>
          <span>{deltaUp ? '↑' : '↓'}</span>{delta}
        </div>
      )}
    </div>
    <div style={{
      fontSize: 48, fontWeight: 700, color: DASH.ink, marginTop: 12,
      letterSpacing: '-0.03em', lineHeight: 1.0, ...DASH.num,
    }}>{amount}</div>
    {note && <div style={{ fontSize: 13, color: DASH.textSec, marginTop: 10, lineHeight: 1.5, fontWeight: 400 }}>{note}</div>}
    {spark && <div style={{ marginTop: 14 }}><Sparkline height={48} points={sparkPts} accent={DASH.ink} /></div>}
  </div>
);

// ============================================================================
// 7 · Payment split — cash / card / online
// ============================================================================

const PaySplit = ({ rows }) => (
  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
    {rows.map(([l, v, bn, pct, accent], i) => (
      <div key={i} style={dashCardStyle({ padding: '11px 12px' })}>
        <MicroLabel>{l}</MicroLabel>
        {bn && <div style={{ fontSize: 10, color: DASH.textTer, fontFamily: DASH.bn, marginTop: 2 }}>{bn}</div>}
        <div style={{ fontSize: 18, fontWeight: 600, color: DASH.text, marginTop: 6, letterSpacing: -0.3, ...DASH.num }}>{v}</div>
        <div style={{ height: 3, background: DASH.track, borderRadius: 2, overflow: 'hidden', marginTop: 8 }}>
          <div style={{ height: '100%', width: `${pct * 100}%`, background: accent || DASH.accent }} />
        </div>
      </div>
    ))}
  </div>
);

// ============================================================================
// 8 · Live snapshot tiles (T3)
// ============================================================================

const TowerTile = ({ value, sub, vsub, bn, tone }) => {
  const t = {
    amber: { bg: DASH.accentSoft, border: DASH.accent, color: DASH.accentInk, sub: DASH.accentInk, rail: DASH.accent },
    paper: { bg: DASH.surface, border: DASH.border, color: DASH.text, sub: DASH.textSec, rail: DASH.textTer },
    coral: { bg: DASH.lateSoft, border: DASH.late, color: DASH.late, sub: DASH.late, rail: DASH.late },
  }[tone || 'paper'];
  return (
    <div style={{
      background: t.bg, borderRadius: 12, padding: '12px 12px', border: `1px solid ${t.border}40`,
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 2, background: t.rail }} />
      <div style={{ fontSize: 28, fontWeight: 600, color: t.color, letterSpacing: -0.6, lineHeight: 1, marginTop: 4, ...DASH.num }}>
        {value}{vsub && <span style={{ fontSize: 14, color: t.sub, fontWeight: 600, marginLeft: 2, opacity: 0.6 }}>{vsub}</span>}
      </div>
      <div style={{ fontSize: 10.5, fontFamily: DASH.mono, fontWeight: 600, color: t.sub, marginTop: 10, letterSpacing: 0.5, textTransform: 'uppercase', lineHeight: 1.2 }}>
        {sub}
      </div>
      {bn && <div style={{ fontSize: 10, color: t.sub, marginTop: 3, fontFamily: DASH.bn, opacity: 0.72 }}>{bn}</div>}
    </div>
  );
};

const TowerRow = ({ tiles }) => (
  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
    {tiles.map((t, i) => <TowerTile key={i} {...t} />)}
  </div>
);

// ============================================================================
// 9 · KPI strip — compact aggregate row
// ============================================================================

const KpiStrip = ({ stats }) => (
  <div style={dashCardStyle({ padding: 0, display: 'flex', overflow: 'hidden' })}>
    {stats.map((s, i) => (
      <div key={i} style={{
        flex: 1, padding: '12px 8px', textAlign: 'left', position: 'relative',
        borderLeft: i ? `1px solid ${DASH.border}` : 'none',
      }}>
        <MicroLabel>{s.l}</MicroLabel>
        <div style={{
          fontSize: 19, fontWeight: 600, color: s.color || DASH.text,
          letterSpacing: -0.4, lineHeight: 1, marginTop: 8, ...DASH.num,
        }}>{s.v}</div>
      </div>
    ))}
  </div>
);

// ============================================================================
// 10 · Floor map
// ============================================================================

const TABLE_STATES = {
  idle:    { bg: DASH.surface,    border: DASH.border,     dot: DASH.textTer,  fg: DASH.textSec,      label: 'Idle',         bn: 'খালি' },
  // 'seated' = a "selected" workflow state. Per system rules accentSoft is the
  // selected-state surface; no full-accent border/dot is allowed on top of it
  // or we burn the viewport's saturation budget.
  seated:  { bg: DASH.accentSoft, border: DASH.accentSoft, dot: DASH.accentSoftInk, fg: DASH.accentSoftInk, label: 'Seated',       bn: 'বসেছে' },
  kitchen: { bg: DASH.goodSoft,   border: DASH.good,       dot: DASH.good,     fg: DASH.good,         label: 'In kitchen',   bn: 'কিচেনে' },
  served:  { bg: DASH.surfaceAlt, border: DASH.border,     dot: DASH.textSec,  fg: DASH.textSec,      label: 'Served',       bn: 'পরিবেশিত' },
  // 'bill' is a workflow milestone, NOT a capacity/caution warning. Use a
  // neutral inkSoft treatment so it reads as "needs attention" without
  // borrowing the low-stock warning signal.
  bill:    { bg: DASH.surfaceAlt, border: DASH.borderStrong, dot: DASH.inkRaised, fg: DASH.inkRaised,  label: 'Bill pending', bn: 'বিল বাকি' },
  late:    { bg: DASH.lateSoft,   border: DASH.late,       dot: DASH.late,     fg: DASH.late,         label: 'Late',         bn: 'দেরি' },
};

const FloorMap = ({ tables, cols = 4, legend, dur }) => (
  <div>
    <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, 1fr)`, gap: 8 }}>
      {tables.map((t, i) => {
        const s = TABLE_STATES[t.state] || TABLE_STATES.idle;
        const filled = t.state !== 'idle';
        return (
          <div key={i} style={{
            background: s.bg, border: `1px solid ${filled ? s.border + '55' : s.border}`,
            borderRadius: 10, padding: '10px 10px', minHeight: 60, position: 'relative',
            display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 14, fontWeight: 600, color: s.fg, ...DASH.num }}>{t.n}</span>
              <span style={{ width: 7, height: 7, borderRadius: 4, background: s.dot }} />
            </div>
            <div style={{ fontSize: 10, color: s.fg, opacity: 0.75, lineHeight: 1.2, fontFamily: DASH.mono, fontWeight: 600 }}>
              {t.cover != null ? `${t.cover}P` : '—'}{dur && t.dur ? ` · ${t.dur}` : ''}
            </div>
          </div>
        );
      })}
    </div>
    {legend && (
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px 14px', marginTop: 12, padding: '0 2px' }}>
        {legend.map((k) => {
          const s = TABLE_STATES[k];
          return (
            <span key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, color: DASH.textSec }}>
              <span style={{ width: 7, height: 7, borderRadius: 4, background: s.dot }} />{s.label}
            </span>
          );
        })}
      </div>
    )}
  </div>
);

// ============================================================================
// 11 · Alerts — "Needs you" rows
// ============================================================================

const ALERT_TONES = {
  late:  { bg: DASH.lateSoft,   color: DASH.late,   rail: DASH.late,   label: 'LATE' },
  low:   { bg: DASH.warnSoft,   color: DASH.warn,   rail: DASH.warn,   label: 'LOW' },
  out:   { bg: DASH.dangerSoft, color: DASH.danger, rail: DASH.danger, label: 'OUT' },
  off:   { bg: DASH.surfaceAlt, color: DASH.textSec,rail: DASH.border, label: 'INFO' },
  stuck: { bg: DASH.dangerSoft, color: DASH.danger, rail: DASH.danger, label: 'STUCK' },
};

const AlertRow = ({ tag, tone, title, sub, cta }) => {
  const t = ALERT_TONES[tone] || ALERT_TONES.off;
  // No colored left rail — the tag pill is the semantic signal. Stacking
  // rail + tag + section-count badge put three urgent-tinted elements on
  // one card, which broke the saturation budget.
  return (
    <div style={dashCardStyle({ padding: 0, marginBottom: 8, overflow: 'hidden' })}>
      <div style={{ display: 'flex', alignItems: 'stretch' }}>
        <div style={{ flex: 1, padding: '12px 14px', display: 'flex', alignItems: 'flex-start', gap: 12 }}>
          <div style={{
            padding: '3px 7px', background: t.bg, color: t.color, borderRadius: 5,
            fontSize: 10, fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.7,
            marginTop: 1, whiteSpace: 'nowrap',
          }}>{tag}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, lineHeight: 1.3 }}>{title}</div>
            {sub && <div style={{ fontSize: 11.5, color: DASH.textSec, marginTop: 3, lineHeight: 1.45 }}>{sub}</div>}
          </div>
          {cta && (
            <div style={{
              padding: '7px 12px', height: 30, background: DASH.ink, color: DASH.onInk,
              borderRadius: 7, fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap',
              display: 'inline-flex', alignItems: 'center', flexShrink: 0,
            }}>{cta}</div>
          )}
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// 12 · Quick actions
// ============================================================================

const QuickActions = ({ actions }) => (
  <div style={{ display: 'grid', gridTemplateColumns: `repeat(${actions.length}, 1fr)`, gap: 8 }}>
    {actions.map((q, i) => {
      const primary = !!q.accent;
      return (
        <div key={i} style={{
          background: primary ? DASH.accent : DASH.surface,
          border: `0.5px solid ${primary ? DASH.accent : DASH.border}`,
          borderRadius: 12, padding: '12px 6px',
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
          color: primary ? DASH.accentInk : DASH.text,
          boxShadow: primary ? DASH.shadowGlow : 'none',
        }}>
          <div style={{
            width: 32, height: 32, borderRadius: 8,
            background: primary ? 'rgba(255,255,255,0.16)' : DASH.surfaceAlt,
            color: primary ? DASH.accentInk : DASH.text,
            display: 'grid', placeItems: 'center',
          }}>
            <NavIcon kind={q.icon} />
          </div>
          <div style={{ fontSize: 12, fontWeight: 600, textAlign: 'center', lineHeight: 1.2 }}>{q.t}</div>
        </div>
      );
    })}
  </div>
);

// ============================================================================
// 13 · Top movers
// ============================================================================

const MoverRow = ({ rank, name, qty, rev, pct, share }) => (
  <div style={dashCardStyle({ marginBottom: 6, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 })}>
    <div style={{
      fontSize: 11, fontFamily: DASH.mono, fontWeight: 700, color: DASH.textTer,
      width: 22, letterSpacing: 0.4, ...DASH.num,
    }}>{String(rank).padStart(2, '0')}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8 }}>
        <div style={{ fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', color: DASH.text }}>{name}</div>
        <div style={{ fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap', color: DASH.text, ...DASH.num }}>{rev}</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 6 }}>
        <div style={{ height: 4, flex: 1, background: DASH.track, borderRadius: 2, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${pct * 100}%`, background: DASH.inkRaised }} />
        </div>
        <div style={{ fontSize: 10.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 600, whiteSpace: 'nowrap', ...DASH.num }}>
          ×{qty}{share ? ` · ${share}` : ''}
        </div>
      </div>
    </div>
  </div>
);

// ============================================================================
// 14 · Channel split bars
// ============================================================================

const ChannelSplit = ({ rows }) => (
  <DashCard>
    {rows.map((r, i) => (
      <div key={i} style={{ marginTop: i ? 14 : 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 6 }}>
          <span style={{ fontSize: 12.5, color: DASH.text, fontWeight: 600 }}>
            {r.l}
            {r.bn && <span style={{ fontFamily: DASH.bn, color: DASH.textTer, fontWeight: 400, marginLeft: 6, fontSize: 11 }}>{r.bn}</span>}
          </span>
          <span style={{ fontSize: 12, color: DASH.textSec, ...DASH.num }}>
            <strong style={{ color: DASH.text, fontWeight: 600 }}>{r.v}</strong> · {r.pct}%
          </span>
        </div>
        <div style={{ height: 6, background: DASH.track, borderRadius: 3, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${r.pct}%`, background: r.accent || DASH.accent, borderRadius: 3 }} />
        </div>
      </div>
    ))}
  </DashCard>
);

// ============================================================================
// 15 · Ops trio (T3) — small metrics
// ============================================================================

const OpsTrio = ({ items }) => (
  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
    {items.map((m, i) => (
      <div key={i} style={dashCardStyle({ padding: '11px 12px' })}>
        <div style={{ color: DASH.textTer }}><NavIcon kind={m.icon} /></div>
        <div style={{ fontSize: 18, fontWeight: 600, color: m.color || DASH.text, marginTop: 8, letterSpacing: -0.3, lineHeight: 1, ...DASH.num }}>{m.v}</div>
        <div style={{ fontSize: 10, fontFamily: DASH.mono, color: DASH.textSec, fontWeight: 600, marginTop: 6, letterSpacing: 0.5, textTransform: 'uppercase', lineHeight: 1.2 }}>{m.l}</div>
      </div>
    ))}
  </div>
);

// ============================================================================
// 16 · Staff row
// ============================================================================

const StaffRow = ({ rank, name, orders, rev, extra, top }) => (
  <div style={dashCardStyle({ marginBottom: 6, padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 12 })}>
    <div style={{
      width: 32, height: 32, borderRadius: 16, flexShrink: 0,
      background: top ? DASH.accent : DASH.surfaceAlt,
      color: top ? DASH.accentInk : DASH.text,
      border: `0.5px solid ${top ? DASH.accent : DASH.border}`,
      display: 'grid', placeItems: 'center', fontSize: 12, fontWeight: 600,
    }}>{name.slice(0, 1)}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text }}>{name}</div>
      <div style={{ fontSize: 11, color: DASH.textSec, marginTop: 2, ...DASH.num }}>{orders} orders{extra ? ` · ${extra}` : ''}</div>
    </div>
    <div style={{ fontSize: 14, fontWeight: 600, color: DASH.text, ...DASH.num }}>{rev}</div>
  </div>
);

// ============================================================================
// 17 · Goal card (T4 hero) — inverted ink with progress
// ============================================================================

const GoalCard = ({ amount, goal, pct, label = 'Fleet revenue · today', bn = 'লক্ষ্য', sub }) => (
  <div style={{
    background: DASH.surface, color: DASH.ink, borderRadius: 14, padding: '16px 16px 14px',
    border: `0.5px solid ${DASH.border}`, boxShadow: DASH.shadowSoft,
    position: 'relative', overflow: 'hidden',
  }}>
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
      <MicroLabel>{label}</MicroLabel>
      <span style={{
        display: 'inline-flex', alignItems: 'center', gap: 5,
        background: DASH.accentSoft, color: DASH.accentSoftInk,
        fontSize: 12, fontWeight: 600, padding: '4px 10px', borderRadius: 6, ...DASH.num,
      }}>
        <span style={{ width: 5, height: 5, borderRadius: 3, background: DASH.accent }} />
        {pct}% of goal
      </span>
    </div>
    <div style={{
      fontSize: 48, fontWeight: 700, color: DASH.ink, marginTop: 12,
      letterSpacing: '-0.03em', lineHeight: 1.0, ...DASH.num,
    }}>{amount}</div>
    <div style={{ height: 6, background: DASH.surfaceAlt, borderRadius: 3, overflow: 'hidden', marginTop: 16 }}>
      <div style={{ height: '100%', width: `${pct}%`, background: DASH.accent, borderRadius: 3 }} />
    </div>
    <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 12 }}>
      <span style={{ color: DASH.textSec, fontWeight: 400, ...DASH.num }}>{sub}</span>
      <span style={{ color: DASH.textTer, fontWeight: 400, ...DASH.num }}>
        Goal {goal} <Bn dim={DASH.textTer}>{bn}</Bn>
      </span>
    </div>
  </div>
);

// ============================================================================
// 18 · Outlet card (T4)
// ============================================================================

const Metric = ({ label, value, tone }) => {
  const col = tone === 'warn' ? DASH.late : (tone === 'bad' ? DASH.danger : DASH.text);
  return (
    <div>
      <div style={{ fontSize: 14, fontWeight: 600, color: col, lineHeight: 1, ...DASH.num }}>{value}</div>
      <div style={{ fontSize: 9.5, fontFamily: DASH.mono, color: DASH.textTer, marginTop: 4, letterSpacing: 0.5, textTransform: 'uppercase', fontWeight: 600 }}>{label}</div>
    </div>
  );
};

const OutletCard = ({ name, area, rev, deltaVsAvg, deltaUp, occ, occTone, late, lateTone, spark, badge }) => (
  <div style={dashCardStyle({ marginBottom: 8, padding: '13px 14px' })}>
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 14, fontWeight: 600, color: DASH.text, letterSpacing: -0.1 }}>{name}</span>
          {badge && (
            <span style={{
              fontSize: 9.5, fontFamily: DASH.mono, fontWeight: 700, color: badge.color || DASH.accent,
              background: badge.bg || DASH.accentSoft, padding: '2px 6px', borderRadius: 4,
              letterSpacing: 0.6, textTransform: 'uppercase',
            }}>{badge.t}</span>
          )}
        </div>
        <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3 }}>{area}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div style={{ fontSize: 18, fontWeight: 600, color: DASH.text, letterSpacing: -0.4, lineHeight: 1, ...DASH.num }}>{rev}</div>
        <div style={{ fontSize: 11, fontWeight: 600, color: deltaUp ? DASH.accent : DASH.late, marginTop: 4, ...DASH.num }}>
          {deltaUp ? '▲' : '▼'} {deltaVsAvg} <span style={{ color: DASH.textTer, fontWeight: 600 }}>vs avg</span>
        </div>
      </div>
    </div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 18, marginTop: 12, paddingTop: 12, borderTop: `1px solid ${DASH.divider}` }}>
      <Metric label="Occupancy" value={occ} tone={occTone} />
      <div style={{ width: 1, height: 24, background: DASH.divider }} />
      <Metric label="Late" value={late} tone={lateTone} />
      <div style={{ flex: 1 }} />
      <MiniSpark points={spark} up={deltaUp} />
    </div>
  </div>
);

// ============================================================================
// 19 · Close-day / shift card
// ============================================================================

// CloseCard — end-of-day review card. The icon box stays neutral (ink) so it
// doesn't compete with the screen's primary CTA (sticky tray / QuickActions
// accent button) for the saturation budget. CloseCard is a review affordance,
// not a primary action.
const CloseCard = ({ amount, kicker = 'Ready when you are', title, warn }) => (
  <div style={{
    background: DASH.surface, color: DASH.ink, border: `0.5px solid ${DASH.border}`,
    borderRadius: 14, padding: '14px 16px', boxShadow: DASH.shadowSoft,
    display: 'flex', alignItems: 'center', gap: 12,
  }}>
    <div style={{ flex: 1 }}>
      <MicroLabel>{kicker}</MicroLabel>
      <div style={{ fontSize: 15, fontWeight: 600, marginTop: 6, color: DASH.ink, letterSpacing: '-0.01em', ...DASH.num }}>{title || `Close today · ${amount}`}</div>
      {warn && (
        <div style={{ fontSize: 12, color: DASH.textSec, marginTop: 6, fontWeight: 400, display: 'flex', alignItems: 'center', gap: 5 }}>
          <span style={{ width: 5, height: 5, borderRadius: 3, background: DASH.textTer }} />{warn}
        </div>
      )}
    </div>
    <div style={{
      width: 40, height: 40, borderRadius: 10,
      background: DASH.surfaceAlt, color: DASH.text,
      border: `1px solid ${DASH.border}`,
      display: 'grid', placeItems: 'center', flexShrink: 0,
    }}><NavIcon kind="arrow" /></div>
  </div>
);

// ============================================================================
// 20 · Quick-sale tiles (T2 unused but exported)
// ============================================================================

const QuickSale = ({ items }) => (
  <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0,1fr) minmax(0,1fr)', gap: 8 }}>
    {items.map((q, i) => (
      <div key={i} style={dashCardStyle({ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 56 })}>
        <div style={{ width: 34, height: 34, borderRadius: 9, background: q.tint || DASH.accentSoft, display: 'grid', placeItems: 'center', flexShrink: 0 }}>
          <span style={{ fontSize: 17 }}>{q.emoji}</span>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{q.n}</div>
          <div style={{ fontSize: 12, color: DASH.textSec, marginTop: 2, ...DASH.num }}>{q.p}</div>
        </div>
        <div style={{ width: 26, height: 26, borderRadius: 8, background: DASH.ink, color: DASH.onInk, display: 'grid', placeItems: 'center', flexShrink: 0 }}>
          <NavIcon kind="plus" />
        </div>
      </div>
    ))}
  </div>
);

// ============================================================================
// Exports
// ============================================================================

Object.assign(window, {
  DASH, DashCard, MicroLabel, Bn,
  DashScreen, DashBottomNav, TierBadge, DashHeader, HeaderIconBtn,
  Section, SecHead, Divider,
  Sparkline, MiniSpark,
  EarnedCard, PaySplit, TowerTile, TowerRow, KpiStrip,
  FloorMap, TABLE_STATES,
  AlertRow, QuickActions, MoverRow, ChannelSplit, OpsTrio, StaffRow,
  GoalCard, OutletCard, Metric, CloseCard, QuickSale,
});
