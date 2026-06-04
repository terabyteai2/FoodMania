// Terafoods · Manage-Mode dashboard — PosColors design system
// ============================================================================
// 1 · Tokens
// ============================================================================

const DASH = {
  // Scaffolding — Neutral-cool violet base
  bg: '#F8F8FA', // paper — scaffold
  surface: '#FFFFFF', // surface — cards/sheets
  surfaceAlt: '#F1F1F5', // surfaceSunk — wells, search fills
  track: '#F1F1F5', // track fill
  trackInk: 'rgba(255,255,255,0.14)',

  // Ink — Violet-black
  ink: '#16101E', // ink — primary text
  inkRaised: '#2D2438', // inkSoft — secondary emphasis
  text: '#16101E',
  textSec: '#635B6E', // muted
  textTer: '#A097AB', // mutedSoft
  onInk: '#FFFFFF',
  onInkSec: 'rgba(255,255,255,0.72)',
  onInkTer: 'rgba(255,255,255,0.48)',

  // Borders
  border: '#E2DDE8', // line
  borderStrong: '#CAC3D4', // lineStrong
  divider: '#E2DDE8',

  // Accent — Deep Plum. ≤ 5% of viewport.
  accent: '#4C1D5E', // primary CTAs, FAB, focused states
  accentDeep: '#351244', // pressed
  accentMid: '#6B3080', // secondary CTAs (never with full accent in same viewport)
  accentSoft: '#E8D8F0', // selected backgrounds — pair with ink only
  accentWash: '#F4EDF8', // hover tints, non-interactive only
  accentInk: '#FFFFFF', // text/icons on full-strength accent
  accentSoftInk: '#16101E', // text on accentSoft (= ink)
  accentOnInk: '#E8D8F0', // accentSoft used as accent-on-dark surfaces

  // Signals — functional only
  good: '#15803D', // success
  goodSoft: '#DCFCE7',
  warn: '#B45309', // warning — low stock
  warnSoft: '#FEF3C7',
  late: '#9A3412', // urgent — late/expedite
  lateSoft: '#FFEDD5',
  danger: '#7F1D1D',
  dangerSoft: '#FEE2E2',

  // Type
  font: 'Inter, system-ui, sans-serif',
  mono: 'Inter, system-ui, sans-serif', // tabular numerics use Inter w600 + tnum
  bn: '"Hind Siliguri", Inter, sans-serif',
  num: { fontFeatureSettings: '"tnum" 1, "cv01" 1', fontVariantNumeric: 'tabular-nums' },

  // Shadows — cast in violet-black (rgb 22,16,30)
  shadowSoft: '0 1px 2px rgba(22,16,30,0.05)',
  shadowGlow: '0 4px 12px rgba(22,16,30,0.07)',
  shadowRaised: '0 8px 24px rgba(22,16,30,0.09)'
};

const dashCardStyle = (extra) => ({
  background: DASH.surface, border: `1px solid ${DASH.border}`,
  borderRadius: 14, padding: '14px 14px', ...extra
});
const DashCard = ({ children, style, padded = true }) =>
<div style={dashCardStyle({ padding: padded ? '14px 14px' : 0, ...style })}>{children}</div>;


// Tiny mono micro-label "TODAY · 10:42AM"
const MicroLabel = ({ children, color, style }) =>
<span style={{
  fontSize: 10, fontFamily: DASH.mono, color: color || DASH.textTer,
  letterSpacing: 0.6, textTransform: 'uppercase', fontWeight: 600, ...style
}}>{children}</span>;


// Bn — Bangla labels are removed app-wide per the latest brief.
// Kept as a no-op so existing call-sites keep type-checking; renders nothing.
const Bn = () => null;


// ============================================================================
// 2 · Shell — cool-gray phone body + bottom nav
// ============================================================================

const DASH_NAV_DEFAULT = [
{ kind: 'orders', label: 'Orders' },
{ kind: 'menu', label: 'Menu' },
{ kind: 'home', label: 'Home' },
{ kind: 'inventory', label: 'Stock' },
{ kind: 'settings', label: 'More' }];


// Bottom nav — neutral active state (ink + 2px pip).
// Dominance rule: the screen's single full-saturation accent is the sticky
// CTA / FAB. Bottom-nav active is a 'you are here' marker, not a CTA, so it
// rides on ink not plum — keeps the saturation budget for the one tap.
const DashBottomNav = ({ items, active = 2 }) => {
  const list = items || DASH_NAV_DEFAULT;
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, height: 70,
      background: DASH.surface, borderTop: `1px solid ${DASH.border}`,
      display: 'flex', alignItems: 'flex-start', justifyContent: 'space-around',
      padding: '10px 0 0'
    }}>
      {list.map((it, i) => {
        const on = i === active;
        return (
          <div key={i} style={{
            flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            color: on ? DASH.ink : DASH.textTer
          }}>
            <div style={{
              width: 26, height: 26, display: 'grid', placeItems: 'center',
              color: on ? DASH.ink : DASH.textTer
            }}>
              <NavIcon kind={it.kind} />
            </div>
            <div style={{ fontSize: 10.5, fontWeight: on ? 700 : 500, lineHeight: 1, color: on ? DASH.ink : DASH.textTer }}>
              {it.label}
            </div>
            <div style={{
              width: 18, height: 2, borderRadius: 1, marginTop: 4,
              background: on ? DASH.ink : 'transparent'
            }} />
          </div>);

      })}
    </div>);

};

const DashScreen = ({ children, nav, navActive = 2, bg }) =>
<div style={{
  position: 'relative', height: '100%', background: bg || DASH.bg, overflow: 'hidden',
  fontFamily: DASH.font, color: DASH.text
}}>
    <div style={{
    position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'hidden',
    paddingBottom: 80, WebkitOverflowScrolling: 'touch'
  }}>
      {children}
    </div>
    <DashBottomNav items={nav} active={navActive} />
  </div>;


// ============================================================================
// 3 · Top nav — unified across the app
// ============================================================================

const HeaderIconBtn = ({ children, badge }) =>
<div style={{
  width: 40, height: 40, borderRadius: 10, background: DASH.surface,
  border: `1px solid ${DASH.border}`, display: 'grid', placeItems: 'center',
  color: DASH.text, position: 'relative'
}}>
    {children}
    {badge != null &&
  <div style={{
    position: 'absolute', top: -4, right: -4, minWidth: 18, height: 18, padding: '0 5px',
    borderRadius: 9, background: DASH.late, color: '#FFF', fontSize: 10, fontWeight: 600,
    display: 'grid', placeItems: 'center', border: `2px solid ${DASH.bg}`, ...DASH.num
  }}>{badge}</div>
  }
  </div>;


// 3b · 
// Per the brief: page heading + notifications + settings. Identical across
// every section. On the Dashboard only, an extra Manager / Owner toggle sits
// directly under the title — that's where the old Manage/Review tabs went.
// ============================================================================

const RoleToggle = ({ role = 'manager', onChange }) => (
  <div style={{
    display: 'inline-flex', background: DASH.surfaceAlt, borderRadius: 10, padding: 3,
    border: `1px solid ${DASH.border}`
  }}>
    {[
      { id: 'manager', label: 'Manager' },
      { id: 'owner', label: 'Owner' }
    ].map((t) => {
      const on = role === t.id;
      return (
        <div key={t.id} onClick={() => onChange && onChange(t.id)} style={{
          padding: '7px 16px', borderRadius: 7,
          background: on ? DASH.surface : 'transparent',
          color: on ? DASH.text : DASH.textSec,
          border: on ? `1px solid ${DASH.borderStrong}` : '1px solid transparent',
          fontSize: 12.5, fontWeight: 600, letterSpacing: -0.1,
          cursor: 'pointer'
        }}>
          {t.label}
        </div>);

    })}
  </div>);


const TopNav = ({ title, role, onRoleChange, badge }) =>
<div style={{ padding: '14px 16px 12px' }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 20, fontWeight: 700, color: DASH.text, letterSpacing: -0.4, lineHeight: 1.1 }}>
          {title}
        </div>
      </div>
      <HeaderIconBtn badge={badge}><NavIcon kind="bell" /></HeaderIconBtn>
      <HeaderIconBtn><NavIcon kind="settings" /></HeaderIconBtn>
    </div>
    {role &&
  <div style={{ marginTop: 12 }}>
        <RoleToggle role={role} onChange={onRoleChange} />
      </div>
  }
  </div>;


// Legacy DashHeader — kept as an alias so older calls still mount the new
// TopNav. All bn / tier / greeting props are ignored (the brief stripped them).
const DashHeader = ({ pageTitle, biz, role, onRoleChange, badge }) =>
<TopNav title={pageTitle || biz || 'Dashboard'} role={role} onRoleChange={onRoleChange} badge={badge} />;


// Legacy TierBadge — no-op, the brief removed the inline tier chips.
const TierBadge = () => null;


// ============================================================================
// 4 · Section / divider — priority rails
// ============================================================================

const Section = ({ children, top = 14 }) =>
<div style={{ padding: `${top}px 16px 0` }}>{children}</div>;


const SecHead = ({ title, bn, action, count, accent }) =>
<div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10, padding: '0 2px' }}>
    <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, letterSpacing: -0.1 }}>{title}</div>
    {bn && <Bn>{bn}</Bn>}
    <div style={{ flex: 1 }} />
    {count != null &&
  <span style={{
    background: accent || DASH.late, color: '#FFF', fontSize: 11, fontWeight: 600,
    minWidth: 20, height: 20, padding: '0 7px', borderRadius: 999,
    display: 'inline-grid', placeItems: 'center', ...DASH.num
  }}>{count}</span>
  }
    {action &&
  <span style={{ fontSize: 12, color: DASH.textSec, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 3 }}>
        {action}
        <span style={{ opacity: 0.5 }}><NavIcon kind="chevron" /></span>
      </span>
  }
  </div>;


// Zone divider — full-bleed band with a tag chip in the middle.
const Divider = ({ label, bn }) =>
<div style={{
  margin: '6px 0 4px', display: 'flex', alignItems: 'center', gap: 0,
  background: 'transparent'
}}>
    <div style={{ flex: 1, height: 1, background: DASH.borderStrong }} />
    <div style={{
    padding: '5px 12px', borderRadius: 999, background: DASH.surface,
    border: `1px solid ${DASH.borderStrong}`,
    fontSize: 10, fontFamily: DASH.mono, fontWeight: 600, color: DASH.textSec,
    letterSpacing: 0.8, textTransform: 'uppercase', whiteSpace: 'nowrap',
    display: 'inline-flex', alignItems: 'center', gap: 6
  }}>
      <span style={{ width: 5, height: 5, borderRadius: 3, background: DASH.textTer }} />
      {label}{bn && <Bn>{bn}</Bn>}
    </div>
    <div style={{ flex: 1, height: 1, background: DASH.borderStrong }} />
  </div>;


// ============================================================================
// 5 · Sparkline + mini spark
// ============================================================================

const Sparkline = ({ height = 56, points, accent, onInk = false }) => {
  const pts = points || [0.18, 0.30, 0.22, 0.42, 0.36, 0.55, 0.62, 0.58, 0.78, 0.72, 0.92, 1.00];
  const col = accent || (onInk ? DASH.accentOnInk : DASH.accent);
  const width = 296,padX = 4,padTop = 10,padBot = 6;
  const innerW = width - padX * 2,innerH = height - padTop - padBot;
  const dx = innerW / (pts.length - 1);
  const xs = pts.map((_, i) => padX + i * dx);
  const ys = pts.map((p) => padTop + innerH - p * innerH);
  const smooth = pts.map((_, i) => {
    if (i === 0) return `M${xs[i]},${ys[i]}`;
    const x0 = xs[i - 1],y0 = ys[i - 1],x1 = xs[i],y1 = ys[i];
    const cx = x0 + (x1 - x0) / 2;
    return `C${cx},${y0} ${cx},${y1} ${x1},${y1}`;
  }).join(' ');
  // Baseline tick + segmented horizontal grid (4 cols)
  return (
    <svg width="100%" height={height} viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {/* segment ticks */}
      {[0.25, 0.5, 0.75].map((t, i) =>
      <line key={i} x1={padX + t * innerW} y1={padTop} x2={padX + t * innerW} y2={height - padBot}
      stroke={onInk ? 'rgba(255,255,255,0.08)' : DASH.divider} strokeWidth="1" />
      )}
      <path d={smooth} fill="none" stroke={col} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round" />
      <circle cx={xs[xs.length - 1]} cy={ys[ys.length - 1]} r="3.5"
      fill={onInk ? DASH.ink : DASH.surface} stroke={col} strokeWidth="1.8" />
    </svg>);

};

const MiniSpark = ({ points, accent, w = 56, h = 22, up = true, onInk = false }) => {
  const pts = points || [0.4, 0.5, 0.35, 0.6, 0.55, 0.8, 0.72, 1.0];
  const col = accent || (up ? DASH.accent : DASH.late);
  const dx = w / (pts.length - 1);
  const xs = pts.map((_, i) => i * dx);
  const ys = pts.map((p) => h - 2 - p * (h - 4));
  const d = xs.map((x, i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${ys[i].toFixed(1)}`).join(' ');
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block' }}>
      <path d={d} fill="none" stroke={col} strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" />
    </svg>);

};

// ============================================================================
// 6b · TotalsHeader — Total Cash + Total Orders KPI band
// Stretches across the top of every Manage / Review screen (T1/T2/T3 + standard
// & advanced review). 2 cells, surface card, the screen's hero anchor.
// ============================================================================

const TotalsHeader = ({ cash, orders, sub }) =>
<div style={{
  background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 14,
  display: 'grid', gridTemplateColumns: '1.15fr 1fr', overflow: 'hidden',
  boxShadow: DASH.shadowSoft
}}>
    <div style={{ padding: '16px 16px' }}>
      <MicroLabel>Total cash</MicroLabel>
      <div style={{
      fontSize: 32, fontWeight: 700, color: DASH.ink, marginTop: 8,
      letterSpacing: '-0.03em', lineHeight: 1.0, ...DASH.num
    }}>{cash}</div>
      {sub && <div style={{ fontSize: 11, color: DASH.textSec, marginTop: 6, ...DASH.num }}>{sub}</div>}
    </div>
    <div style={{ padding: '16px 16px', borderLeft: `1px solid ${DASH.border}` }}>
      <MicroLabel>Total orders</MicroLabel>
      <div style={{
      fontSize: 32, fontWeight: 700, color: DASH.ink, marginTop: 8,
      letterSpacing: '-0.03em', lineHeight: 1.0, ...DASH.num
    }}>{orders}</div>
    </div>
  </div>;


// ============================================================================
// 6c · FOHCounter — embedded 3-column quick-sell tile grid for Manage tabs
// 6 products, top-selling-by-default, with an Edit button beside the title.
// Tapped tiles roll up into a sticky "Create order [total]" CTA — that lives
// in the screen, not in this primitive.
// ============================================================================

// 6c · FOH — text-first ring-up tiles
// Operators ring up by name + position, not by picture. Tiles drop the
// emoji clipart slot entirely. Structure:
//   • thin LEFT RAIL (category color, muted) — 'tint' prop, optional
//   • small monochrome Lucide-style glyph + tiny mono category label
//   • item name (titleMedium / bodyMedium w600)
//   • price (numericMedium w600)
//   • qty badge (ink) when in cart — selection indicator, not accent fill
// 'emoji' prop is accepted-but-ignored so older call sites keep parsing.
const FOHTile = ({ n, p, cat, glyph, tint, qty, clamp = 2, onClick /* emoji ignored */ }) => {
  const active = !!qty;
  const oneLine = clamp === 1;
  return (
    <div onClick={onClick} style={{
      position: 'relative',
      background: DASH.surface,
      border: `1px solid ${active ? DASH.ink : DASH.border}`,
      borderRadius: 12,
      padding: tint ? '12px 12px 12px 14px' : '11px 11px',
      minHeight: oneLine ? 78 : 96,
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      color: DASH.ink, cursor: 'pointer', overflow: 'hidden'
    }}>
      {/* category left rail — 1.5px, muted; absent if no tint passed */}
      {tint && <div style={{
        position: 'absolute', left: 0, top: 10, bottom: 10, width: 2.5,
        background: tint, borderRadius: 2
      }} />}
      {active &&
      <div style={{
        position: 'absolute', top: -8, right: -6, minWidth: 22, height: 22, padding: '0 6px',
        borderRadius: 11, background: DASH.ink, color: DASH.onInk, fontSize: 11, fontWeight: 700,
        display: 'grid', placeItems: 'center', border: `2px solid ${DASH.bg}`, ...DASH.num
      }}>{qty}</div>
      }
      <div>
        {(glyph || cat) && (
          <div style={{
            display: 'flex', alignItems: 'center', gap: 5, marginBottom: 5,
            color: DASH.textSec
          }}>
            {glyph && <CategoryGlyph kind={glyph} size={13} color={DASH.textSec} />}
            {cat && <span style={{
              fontSize: 9.5, fontFamily: DASH.mono, fontWeight: 600, color: DASH.textSec,
              letterSpacing: 0.6, textTransform: 'uppercase'
            }}>{cat}</span>}
          </div>
        )}
        <div style={{
          fontSize: 13.5, fontWeight: 600, lineHeight: 1.25, color: DASH.ink,
          letterSpacing: '-0.01em',
          ...(oneLine
            ? { whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }
            : { display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' })
        }}>{n}</div>
      </div>
      <div style={{
        fontSize: 14, fontWeight: 600, color: DASH.text, marginTop: 6,
        letterSpacing: '-0.01em', ...DASH.num
      }}>{p}</div>
    </div>);

};

// Sticky "Create order · ৳total" tray — sits above the bottom nav.
// Replaces "Take cash" per the brief and works for all tiers.
const CreateOrderTray = ({ count, total, label = 'Create order' }) =>
<div style={{ position: 'absolute', left: 0, right: 0, bottom: 70, padding: '0 12px 10px' }}>
    <div style={{
    background: DASH.surface, borderRadius: 14, padding: '11px 11px 11px 14px',
    display: 'flex', alignItems: 'center', gap: 10,
    boxShadow: DASH.shadowRaised,
    border: `1px solid ${DASH.border}`
  }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <MicroLabel>{count} items in order</MicroLabel>
      </div>
      <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      background: DASH.accent, color: DASH.accentInk,
      padding: '11px 16px', borderRadius: 11, flexShrink: 0,
      boxShadow: DASH.shadowGlow
    }}>
        <span style={{ fontSize: 13.5, fontWeight: 600 }}>{label}</span>
        <span style={{ fontSize: 15, fontWeight: 700, letterSpacing: -0.3, ...DASH.num }}>{total}</span>
      </div>
    </div>
  </div>;


const FOHCounter = ({ title = 'Counter · top sellers', tiles, cols = 3, action, clamp }) =>
<div>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10, padding: '0 2px' }}>
      <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text, letterSpacing: -0.1 }}>{title}</div>
      <span style={{
      padding: '5px 10px', borderRadius: 7,
      background: DASH.surface, color: DASH.textSec,
      border: `1px solid ${DASH.border}`,
      fontSize: 11, fontWeight: 600, fontFamily: DASH.mono, letterSpacing: 0.5,
      display: 'inline-flex', alignItems: 'center', gap: 6
    }}>
        <NavIcon kind="settings" />{action || 'Edit'}
      </span>
    </div>
    <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0,1fr))`, gap: 8 }}>
      {tiles.map((t, i) => <FOHTile key={i} clamp={clamp} {...t} />)}
    </div>
  </div>;


// ============================================================================
// 6 · EarnedCard — inverted-ink hero (the ONE primary metric per screen)
// ============================================================================

const EarnedCard = ({ amount, bn = '', delta, deltaUp = true, note, spark, sparkPts, label = 'Earned today' }) =>
<div style={{
  background: DASH.surface, color: DASH.ink, borderRadius: 14, padding: '16px 16px 14px',
  border: `0.5px solid ${DASH.border}`, boxShadow: DASH.shadowSoft,
  position: 'relative', overflow: 'hidden'
}}>
    <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
      <div style={{ minWidth: 0 }}>
        <MicroLabel>{label}</MicroLabel>
      </div>
      {delta &&
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      background: deltaUp ? DASH.goodSoft : DASH.dangerSoft,
      color: deltaUp ? DASH.good : DASH.danger,
      fontSize: 12, fontWeight: 600, padding: '4px 10px', borderRadius: 6,
      whiteSpace: 'nowrap', ...DASH.num
    }}>
          <span>{deltaUp ? '↑' : '↓'}</span>{delta}
        </div>
    }
    </div>
    <div style={{
    fontSize: 48, fontWeight: 700, color: DASH.ink, marginTop: 12,
    letterSpacing: '-0.03em', lineHeight: 1.0, ...DASH.num
  }}>{amount}</div>
    {note && <div style={{ fontSize: 13, color: DASH.textSec, marginTop: 10, lineHeight: 1.5, fontWeight: 400 }}>{note}</div>}
    {spark && <div style={{ marginTop: 14 }}><Sparkline height={48} points={sparkPts} accent={DASH.ink} /></div>}
  </div>;


// ============================================================================
// 7 · Payment split — cash / card / online
// ============================================================================

// PaySplit — monochrome ink ladder. Accent never used on a metric tile.
const PaySplit = ({ rows }) =>
<div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
    {rows.map(([l, v, bn, pct, accent], i) =>
  <div key={i} style={dashCardStyle({ padding: '11px 12px' })}>
        <MicroLabel>{l}</MicroLabel>
        <div style={{ fontSize: 18, fontWeight: 600, color: DASH.text, marginTop: 6, letterSpacing: -0.3, ...DASH.num }}>{v}</div>
        <div style={{ height: 3, background: DASH.track, borderRadius: 2, overflow: 'hidden', marginTop: 8 }}>
          <div style={{ height: '100%', width: `${pct * 100}%`,
            background: accent || [DASH.ink, DASH.inkRaised, DASH.textSec][i] || DASH.textTer
          }} />
        </div>
      </div>
  )}
  </div>;


// ============================================================================
// 8 · Live snapshot tiles (T3)
// ============================================================================

const TowerTile = ({ value, sub, vsub, bn, tone }) => {
  // Tones — 'amber' is the workflow 'now' tone (was accentSoft wash); converted
  // to neutral surface + ink rail so we don't burn the accent budget on a
  // metric tile. 'coral' stays as an exception signal (late / over-threshold).
  const t = {
    amber: { bg: DASH.surface,  border: DASH.border, color: DASH.ink,  sub: DASH.textSec, rail: DASH.ink  },
    paper: { bg: DASH.surface,  border: DASH.border, color: DASH.text, sub: DASH.textSec, rail: DASH.textTer },
    coral: { bg: DASH.lateSoft, border: DASH.late,   color: DASH.late, sub: DASH.late,    rail: DASH.late }
  }[tone || 'paper'];
  return (
    <div style={{
      background: t.bg, borderRadius: 12, padding: '12px 12px', border: `1px solid ${t.border}40`,
      position: 'relative', overflow: 'hidden'
    }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 2, background: t.rail }} />
      <div style={{ fontSize: 28, fontWeight: 600, color: t.color, letterSpacing: -0.6, lineHeight: 1, marginTop: 4, ...DASH.num }}>
        {value}{vsub && <span style={{ fontSize: 14, color: t.sub, fontWeight: 600, marginLeft: 2, opacity: 0.6 }}>{vsub}</span>}
      </div>
      <div style={{ fontSize: 10.5, fontFamily: DASH.mono, fontWeight: 600, color: t.sub, marginTop: 10, letterSpacing: 0.5, textTransform: 'uppercase', lineHeight: 1.2 }}>
        {sub}
      </div>
    </div>);

};

const TowerRow = ({ tiles }) =>
<div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
    {tiles.map((t, i) => <TowerTile key={i} {...t} />)}
  </div>;


// ============================================================================
// 9 · KPI strip — compact aggregate row
// ============================================================================

const KpiStrip = ({ stats }) =>
<div style={dashCardStyle({ padding: 0, display: 'flex', overflow: 'hidden' })}>
    {stats.map((s, i) =>
  <div key={i} style={{
    flex: 1, padding: '12px 8px', textAlign: 'left', position: 'relative',
    borderLeft: i ? `1px solid ${DASH.border}` : 'none'
  }}>
        <MicroLabel>{s.l}</MicroLabel>
        <div style={{
      fontSize: 19, fontWeight: 600, color: s.color || DASH.text,
      letterSpacing: -0.4, lineHeight: 1, marginTop: 8, ...DASH.num
    }}>{s.v}</div>
      </div>
  )}
  </div>;


// ============================================================================
// 10 · Floor map
// ============================================================================

const TABLE_STATES = {
  idle:    { bg: DASH.surface,    border: DASH.border,       dot: DASH.textTer,  fg: DASH.textSec,  label: 'Idle',         bn: '' },
  // Occupied states are NEUTRAL surface + ink — a small filled dot is the
  // only signal. Colour is reserved for exceptions (late = warning).
  seated:  { bg: DASH.surface,    border: DASH.borderStrong, dot: DASH.ink,      fg: DASH.ink,      label: 'Seated',       bn: '' },
  kitchen: { bg: DASH.surface,    border: DASH.border,       dot: DASH.good,     fg: DASH.ink,      label: 'In kitchen',   bn: '' },
  served:  { bg: DASH.surfaceAlt, border: DASH.border,       dot: DASH.textSec,  fg: DASH.textSec,  label: 'Served',       bn: '' },
  bill:    { bg: DASH.surface,    border: DASH.borderStrong, dot: DASH.inkRaised,fg: DASH.inkRaised,label: 'Bill pending', bn: '' },
  late:    { bg: DASH.lateSoft,   border: DASH.late,         dot: DASH.late,     fg: DASH.late,     label: 'Late',         bn: '' }
};

const FloorMap = ({ tables, cols = 4, legend, dur }) =>
<div>
    <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, 1fr)`, gap: 8 }}>
      {tables.map((t, i) => {
      const s = TABLE_STATES[t.state] || TABLE_STATES.idle;
      const filled = t.state !== 'idle';
      return (
        <div key={i} style={{
          background: s.bg, border: `1px solid ${filled ? s.border + '55' : s.border}`,
          borderRadius: 10, padding: '10px 10px', minHeight: 60, position: 'relative',
          display: 'flex', flexDirection: 'column', justifyContent: 'space-between'
        }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 14, fontWeight: 600, color: s.fg, ...DASH.num }}>{t.n}</span>
              <span style={{ width: 7, height: 7, borderRadius: 4, background: s.dot }} />
            </div>
            <div style={{ fontSize: 10, color: s.fg, opacity: 0.75, lineHeight: 1.2, fontFamily: DASH.mono, fontWeight: 600 }}>
              {t.cover != null ? `${t.cover}P` : '—'}{dur && t.dur ? ` · ${t.dur}` : ''}
            </div>
          </div>);

    })}
    </div>
    {legend &&
  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px 14px', marginTop: 12, padding: '0 2px' }}>
        {legend.map((k) => {
      const s = TABLE_STATES[k];
      return (
        <span key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, color: DASH.textSec }}>
              <span style={{ width: 7, height: 7, borderRadius: 4, background: s.dot }} />{s.label}
            </span>);

    })}
      </div>
  }
  </div>;


// ============================================================================
// 11 · Alerts — "Needs you" rows
// ============================================================================

const ALERT_TONES = {
  late: { bg: DASH.lateSoft, color: DASH.late, rail: DASH.late, label: 'LATE' },
  low: { bg: DASH.warnSoft, color: DASH.warn, rail: DASH.warn, label: 'LOW' },
  out: { bg: DASH.dangerSoft, color: DASH.danger, rail: DASH.danger, label: 'OUT' },
  off: { bg: DASH.surfaceAlt, color: DASH.textSec, rail: DASH.border, label: 'INFO' },
  stuck: { bg: DASH.dangerSoft, color: DASH.danger, rail: DASH.danger, label: 'STUCK' }
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
            marginTop: 1, whiteSpace: 'nowrap'
          }}>{tag}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, lineHeight: 1.3 }}>{title}</div>
            {sub && <div style={{ fontSize: 11.5, color: DASH.textSec, marginTop: 3, lineHeight: 1.45 }}>{sub}</div>}
          </div>
          {cta &&
          <div style={{
            padding: '7px 12px', height: 30, background: DASH.ink, color: DASH.onInk,
            borderRadius: 7, fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap',
            display: 'inline-flex', alignItems: 'center', flexShrink: 0
          }}>{cta}</div>
          }
        </div>
      </div>
    </div>);

};

// ============================================================================
// 12 · Quick actions
// ============================================================================

// QuickActions — utility row, all neutral. Per dominance rule, the screen's
// one full-saturation accent is the sticky 'Create order' tray; quick actions
// are utilities, not primary CTAs. 'accent' prop is honored for back-compat
// only when no sticky tray is present (rare).
const QuickActions = ({ actions }) =>
<div style={{ display: 'grid', gridTemplateColumns: `repeat(${actions.length}, 1fr)`, gap: 8 }}>
    {actions.map((q, i) => {
    return (
      <div key={i} style={{
        background: DASH.surface,
        border: `1px solid ${DASH.border}`,
        borderRadius: 12, padding: '12px 6px',
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
        color: DASH.text
      }}>
          <div style={{
          width: 32, height: 32, borderRadius: 8,
          background: DASH.surfaceAlt,
          color: DASH.text,
          display: 'grid', placeItems: 'center'
        }}>
            <NavIcon kind={q.icon} />
          </div>
          <div style={{ fontSize: 12, fontWeight: 600, textAlign: 'center', lineHeight: 1.2 }}>{q.t}</div>
        </div>);

  })}
  </div>;


// ============================================================================
// 13 · Top movers
// ============================================================================

const MoverRow = ({ rank, name, qty, rev, pct, share }) =>
<div style={dashCardStyle({ marginBottom: 6, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 })}>
    <div style={{
    fontSize: 11, fontFamily: DASH.mono, fontWeight: 700, color: DASH.textTer,
    width: 22, letterSpacing: 0.4, ...DASH.num
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
  </div>;


// ============================================================================
// 14 · Channel split bars
// ============================================================================

// ChannelSplit — monochrome by default (ink ladder). Caller-supplied 'accent'
// is honored only for exception rows (e.g. late = warning).
const ChannelSplit = ({ rows }) =>
<DashCard>
    {rows.map((r, i) =>
  <div key={i} style={{ marginTop: i ? 14 : 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 6 }}>
          <span style={{ fontSize: 12.5, color: DASH.text, fontWeight: 600 }}>
            {r.l}
          </span>
          <span style={{ fontSize: 12, color: DASH.textSec, ...DASH.num }}>
            <strong style={{ color: DASH.text, fontWeight: 600 }}>{r.v}</strong> · {r.pct}%
          </span>
        </div>
        <div style={{ height: 6, background: DASH.track, borderRadius: 3, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${r.pct}%`,
            background: r.accent || [DASH.ink, DASH.inkRaised, DASH.textSec][i] || DASH.textTer,
            borderRadius: 3
          }} />
        </div>
      </div>
  )}
  </DashCard>;


// ============================================================================
// 15 · Ops trio (T3) — small metrics
// ============================================================================

const OpsTrio = ({ items }) =>
<div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
    {items.map((m, i) =>
  <div key={i} style={dashCardStyle({ padding: '11px 12px' })}>
        <div style={{ color: DASH.textTer }}><NavIcon kind={m.icon} /></div>
        <div style={{ fontSize: 18, fontWeight: 600, color: m.color || DASH.text, marginTop: 8, letterSpacing: -0.3, lineHeight: 1, ...DASH.num }}>{m.v}</div>
        <div style={{ fontSize: 10, fontFamily: DASH.mono, color: DASH.textSec, fontWeight: 600, marginTop: 6, letterSpacing: 0.5, textTransform: 'uppercase', lineHeight: 1.2 }}>{m.l}</div>
      </div>
  )}
  </div>;


// ============================================================================
// 16 · Staff row
// ============================================================================

const StaffRow = ({ rank, name, orders, rev, extra, top }) =>
<div style={dashCardStyle({ marginBottom: 6, padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 12 })}>
    <div style={{
    width: 32, height: 32, borderRadius: 16, flexShrink: 0,
    background: top ? DASH.ink : DASH.surfaceAlt,
    color: top ? DASH.onInk : DASH.text,
    border: `0.5px solid ${top ? DASH.ink : DASH.border}`,
    display: 'grid', placeItems: 'center', fontSize: 12, fontWeight: 600
  }}>{name.slice(0, 1)}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text }}>{name}</div>
      <div style={{ fontSize: 11, color: DASH.textSec, marginTop: 2, ...DASH.num }}>{orders} orders{extra ? ` · ${extra}` : ''}</div>
    </div>
    <div style={{ fontSize: 14, fontWeight: 600, color: DASH.text, ...DASH.num }}>{rev}</div>
  </div>;


// ============================================================================
// 17 · Goal card (T4 hero) — inverted ink with progress
// ============================================================================

const GoalCard = ({ amount, goal, pct, label = 'Fleet revenue · today', bn = '', sub }) =>
<div style={{
  background: DASH.surface, color: DASH.ink, borderRadius: 14, padding: '16px 16px 14px',
  border: `0.5px solid ${DASH.border}`, boxShadow: DASH.shadowSoft,
  position: 'relative', overflow: 'hidden'
}}>
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
      <MicroLabel>{label}</MicroLabel>
      {/* % of goal pill — neutral (was accentSoft). Pace is a metric, not a CTA. */}
      <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      background: DASH.surfaceAlt, color: DASH.inkRaised,
      border: `1px solid ${DASH.border}`,
      fontSize: 11.5, fontWeight: 600, padding: '3px 9px', borderRadius: 6, ...DASH.num
    }}>
        {pct}% of goal
      </span>
    </div>
    <div style={{
    fontSize: 48, fontWeight: 700, color: DASH.ink, marginTop: 12,
    letterSpacing: '-0.03em', lineHeight: 1.0, ...DASH.num
  }}>{amount}</div>
    {/* Progress bar — ink, not accent (system rule: progress never plum). */}
    <div style={{ height: 6, background: DASH.surfaceAlt, borderRadius: 3, overflow: 'hidden', marginTop: 16 }}>
      <div style={{ height: '100%', width: `${pct}%`, background: DASH.ink, borderRadius: 3 }} />
    </div>
    <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 12 }}>
      <span style={{ color: DASH.textSec, fontWeight: 400, ...DASH.num }}>{sub}</span>
      <span style={{ color: DASH.textTer, fontWeight: 400, ...DASH.num }}>
        Goal {goal}
      </span>
    </div>
  </div>;


// ============================================================================
// 18 · Outlet card (T4)
// ============================================================================

const Metric = ({ label, value, tone }) => {
  const col = tone === 'warn' ? DASH.late : tone === 'bad' ? DASH.danger : DASH.text;
  return (
    <div>
      <div style={{ fontSize: 14, fontWeight: 600, color: col, lineHeight: 1, ...DASH.num }}>{value}</div>
      <div style={{ fontSize: 9.5, fontFamily: DASH.mono, color: DASH.textTer, marginTop: 4, letterSpacing: 0.5, textTransform: 'uppercase', fontWeight: 600 }}>{label}</div>
    </div>);

};

const OutletCard = ({ name, area, rev, deltaVsAvg, deltaUp, occ, occTone, late, lateTone, spark, badge }) =>
<div style={dashCardStyle({ marginBottom: 8, padding: '13px 14px' })}>
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 14, fontWeight: 600, color: DASH.text, letterSpacing: -0.1 }}>{name}</span>
          {badge &&
        <span style={{
          fontSize: 9.5, fontFamily: DASH.mono, fontWeight: 700,
          color: badge.color || DASH.inkRaised,
          background: badge.bg || DASH.surfaceAlt,
          border: `1px solid ${DASH.border}`,
          padding: '2px 6px', borderRadius: 4,
          letterSpacing: 0.6, textTransform: 'uppercase'
        }}>{badge.t}</span>
        }
        </div>
        <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3 }}>{area}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div style={{ fontSize: 18, fontWeight: 600, color: DASH.text, letterSpacing: -0.4, lineHeight: 1, ...DASH.num }}>{rev}</div>
        <div style={{ fontSize: 11, fontWeight: 600, color: deltaUp ? DASH.good : DASH.late, marginTop: 4, ...DASH.num,
          display: 'inline-flex', alignItems: 'center', gap: 4, justifyContent: 'flex-end' }}>
          <span style={{ fontSize: 10, fontWeight: 700 }}>{deltaUp ? '↑' : '↓'}</span>
          {deltaVsAvg} <span style={{ color: DASH.textTer, fontWeight: 500 }}>vs avg</span>
        </div>
      </div>
    </div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 18, marginTop: 12, paddingTop: 12, borderTop: `1px solid ${DASH.divider}` }}>
      <Metric label="Occupancy" value={occ} tone={occTone} />
      <div style={{ width: 1, height: 24, background: DASH.divider }} />
      <Metric label="Late" value={late} tone={lateTone} />
      <div style={{ flex: 1 }} />
      <MiniSpark points={spark} up={deltaUp} accent={deltaUp ? DASH.good : DASH.late} />
    </div>
  </div>;


// ============================================================================
// 19 · Close-day / shift card
// ============================================================================

// CloseCard — end-of-day review card. The icon box stays neutral (ink) so it
// doesn't compete with the screen's primary CTA (sticky tray / QuickActions
// accent button) for the saturation budget. CloseCard is a review affordance,
// not a primary action.
const CloseCard = ({ amount, kicker = 'Ready when you are', title, warn }) =>
<div style={{
  background: DASH.surface, color: DASH.ink, border: `0.5px solid ${DASH.border}`,
  borderRadius: 14, padding: '14px 16px', boxShadow: DASH.shadowSoft,
  display: 'flex', alignItems: 'center', gap: 12
}}>
    <div style={{ flex: 1 }}>
      <MicroLabel>{kicker}</MicroLabel>
      <div style={{ fontSize: 15, fontWeight: 600, marginTop: 6, color: DASH.ink, letterSpacing: '-0.01em', ...DASH.num }}>{title || `Close today · ${amount}`}</div>
      {warn &&
    <div style={{ fontSize: 12, color: DASH.textSec, marginTop: 6, fontWeight: 400, display: 'flex', alignItems: 'center', gap: 5 }}>
          <span style={{ width: 5, height: 5, borderRadius: 3, background: DASH.textTer }} />{warn}
        </div>
    }
    </div>
    <div style={{
    width: 40, height: 40, borderRadius: 10,
    background: DASH.surfaceAlt, color: DASH.text,
    border: `1px solid ${DASH.border}`,
    display: 'grid', placeItems: 'center', flexShrink: 0
  }}><NavIcon kind="arrow" /></div>
  </div>;


// ============================================================================
// 20 · Quick-sale tiles (T2 unused but exported)
// ============================================================================

const QuickSale = ({ items }) =>
<div style={{ display: 'grid', gridTemplateColumns: 'minmax(0,1fr) minmax(0,1fr)', gap: 8 }}>
    {items.map((q, i) =>
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
  )}
  </div>;


// ============================================================================
// 21 · Delta — inline plain-language comparison
// ============================================================================
// Rules: absolute value FIRST, baseline spelled out, percent in parens.
// Quiet up/down arrow + success/danger TEXT colour. No filled pills (those
// read as stock-ticker; this is restaurant analytics).
//
//   <Delta value="৳1,860" baselineLabel="last Monday" pct="+14%" />
//   <Delta value="৳1,860" baselineLabel="last Monday" pct="−14%" down />
//
// Legacy callers passing `baseline="vs yesterday"` still parse — the
// component strips the leading "vs " and uses whatever's left as the
// baseline label.

const Delta = ({ value, pct, down = false, baseline, baselineLabel, prefix, size = 'md' }) => {
  const up = !down;
  const col = up ? DASH.good : DASH.danger;
  const fs = size === 'sm' ? 12 : size === 'lg' ? 14 : 13;
  const vw = size === 'sm' ? 600 : 700;
  const label = baselineLabel || (baseline ? baseline.replace(/^vs\s+/i, '') : null);
  const verb = prefix || (up ? 'more than' : 'less than');
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'baseline', gap: 5,
      fontSize: fs, color: col, fontWeight: 500, lineHeight: 1.3,
      ...DASH.num
    }}>
      <span style={{ fontWeight: 700, fontSize: fs - 1 }}>{up ? '↑' : '↓'}</span>
      <span>
        <strong style={{ fontWeight: vw, color: col }}>{value}</strong>
        {label && <>
          <span style={{ color: DASH.text, fontWeight: 500 }}> {verb} </span>
          <span style={{ color: DASH.text, fontWeight: 500 }}>{label}</span>
        </>}
        {pct && <span style={{ color: DASH.textSec, fontWeight: 500 }}> ({pct})</span>}
      </span>
    </span>
  );
};

// ============================================================================
// 22 · PeriodSelector — primary control on the Owner screen
// ============================================================================
// Active segment uses PLUM fill + white text — this is one of the three
// places where plum is allowed to live on the Owner screen (selected-state
// surface, brief allowance). Inactive segments are surface + textSec.

const PERIODS = ['Today', 'Week', 'Month', 'Custom'];

const PeriodSelector = ({ value = 'Today', onChange }) => (
  <div style={{
    background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 12,
    padding: 4, display: 'flex', alignItems: 'center', gap: 4,
    boxShadow: DASH.shadowSoft
  }}>
    {PERIODS.map((p) => {
      const on = p === value;
      return (
        <div key={p} onClick={() => onChange && onChange(p)} style={{
          flex: 1, padding: '8px 10px', borderRadius: 8,
          background: on ? DASH.accent : 'transparent',
          color: on ? DASH.accentInk : DASH.textSec,
          fontSize: 12.5, fontWeight: on ? 700 : 600, letterSpacing: -0.1,
          textAlign: 'center', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4
        }}>
          {p}
          {p === 'Custom' && (
            <span style={{ opacity: 0.6, fontSize: 10 }}>▾</span>
          )}
        </div>
      );
    })}
  </div>
);

// Period subtitle — the "Mon 3 Jun · vs prev Mon" line that lives directly
// under the selector and labels the baseline. Not optional — every Owner
// screen states the baseline.
const PeriodSubtitle = ({ range, compare }) => (
  <div style={{
    marginTop: 8, display: 'flex', alignItems: 'baseline',
    justifyContent: 'space-between', gap: 8, padding: '0 2px'
  }}>
    <span style={{
      fontSize: 11.5, color: DASH.textSec, fontWeight: 600, ...DASH.num
    }}>{range}</span>
    <span style={{
      fontSize: 10.5, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 600,
      letterSpacing: 0.4
    }}>vs {compare}</span>
  </div>
);

// ============================================================================
// 23 · DashTopBar — compact app bar for Manager dashboards
// ============================================================================
// Left → right: outlet name (titleMedium) + small muted mode pill ("CAFE") +
// time (bodySmall muted) · right side · role toggle (Manager/Owner, compact)
// + drawer total (small labelled value). NO bell/settings here — those live
// in the bottom nav's "More" tab.

const DashTopBar = ({ outlet, mode, time, role, onRoleChange, drawer, drawerLabel = 'Drawer' }) => (
  <div style={{
    padding: '14px 16px 10px',
    display: 'flex', alignItems: 'center', gap: 12
  }}>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
        <span style={{
          fontSize: 18, fontWeight: 700, color: DASH.ink, letterSpacing: -0.4, lineHeight: 1.1,
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: 180
        }}>{outlet}</span>
        {mode && (
          <span style={{
            fontSize: 9.5, fontFamily: DASH.mono, fontWeight: 700, color: DASH.textSec,
            background: DASH.surfaceAlt, border: `1px solid ${DASH.border}`,
            padding: '2px 6px', borderRadius: 4, letterSpacing: 0.7, textTransform: 'uppercase'
          }}>{mode}</span>
        )}
      </div>
      {time && (
        <div style={{
          fontSize: 11.5, color: DASH.textSec, fontWeight: 500, marginTop: 3, ...DASH.num
        }}>{time}</div>
      )}
    </div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 }}>
      {role && (
        <CompactRoleToggle role={role} onChange={onRoleChange} />
      )}
      {drawer && (
        <div style={{ textAlign: 'right' }}>
          <div style={{
            fontSize: 9, fontFamily: DASH.mono, fontWeight: 600, color: DASH.textTer,
            letterSpacing: 0.7, textTransform: 'uppercase'
          }}>{drawerLabel}</div>
          <div style={{
            fontSize: 14, fontWeight: 700, color: DASH.text, letterSpacing: -0.2, ...DASH.num,
            marginTop: 2
          }}>{drawer}</div>
        </div>
      )}
    </div>
  </div>
);

// Compact segmented toggle for the app bar — smaller than the full RoleToggle.
const CompactRoleToggle = ({ role = 'manager', onChange }) => (
  <div style={{
    display: 'inline-flex', background: DASH.surfaceAlt, borderRadius: 8, padding: 2,
    border: `1px solid ${DASH.border}`
  }}>
    {[
      { id: 'manager', label: 'Mgr' },
      { id: 'owner', label: 'Owner' }
    ].map((t) => {
      const on = role === t.id;
      return (
        <div key={t.id} onClick={() => onChange && onChange(t.id)} style={{
          padding: '5px 9px', borderRadius: 6,
          background: on ? DASH.surface : 'transparent',
          color: on ? DASH.text : DASH.textSec,
          border: on ? `1px solid ${DASH.borderStrong}` : '1px solid transparent',
          fontSize: 11, fontWeight: 700, letterSpacing: -0.1,
          cursor: 'pointer'
        }}>
          {t.label}
        </div>
      );
    })}
  </div>
);

// ============================================================================
// 23c · ModeDial + UnifiedTopNav — uniform header for every by-tier screen
// ============================================================================
// Page heading + subheading on the left; a self-explanatory mode dial (icon +
// 4-bar signal meter showing complexity level) + a notification bell on the
// right. Nothing else lives in this nav. Used identically across Dashboard,
// Inventory, and FOH order-entry by-tier sections.

const TIER_MODES = [
  { id: 'foodcart',   label: 'Food cart',  sub: 'Counter only',         level: 1 },
  { id: 'cafe',       label: 'Cafe',       sub: 'Tables + ring-up',     level: 2 },
  { id: 'restaurant', label: 'Restaurant', sub: 'Floor + modifiers',    level: 3 },
  { id: 'enterprise', label: 'Enterprise', sub: 'Multi-outlet fleet',   level: 4 }
];

const ModeIcon = ({ kind, size = 16, color }) => {
  const p = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', style: { display: 'block', flexShrink: 0 } };
  const c = { stroke: color || 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (kind) {
    case 'foodcart':
      return <svg {...p}><path d="M4 11h16M12 4v7M5 4l-1.5 3h17L19 4" {...c} /><path d="M6 11v8a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1v-8" {...c} /><circle cx="9" cy="20.5" r="1" {...c} /><circle cx="15" cy="20.5" r="1" {...c} /></svg>;
    case 'cafe':
      return <svg {...p}><path d="M5 9h12v6a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4V9Z" {...c} /><path d="M17 11h2a2 2 0 0 1 0 4h-2" {...c} /></svg>;
    case 'restaurant':
      return <svg {...p}><path d="M7 3v8a2 2 0 0 0 4 0V3M9 11v10" {...c} /><path d="M15 3c-1 2-1 4 0 6h2v12" {...c} /></svg>;
    case 'enterprise':
      return <svg {...p}><path d="M3 21V10l4-3 4 3v11M11 21V13l4-2 4 2v8M3 21h18" {...c} /><path d="M7 21v-4M15 21v-4" {...c} /></svg>;
    default:
      return <svg {...p}><circle cx="12" cy="12" r="7" {...c} /></svg>;
  }
};

const ModeMeter = ({ level = 1, color, dim }) => {
  const heights = [5, 8, 11, 14];
  return (
    <span style={{ display: 'inline-flex', alignItems: 'flex-end', gap: 2, height: 14 }}>
      {heights.map((h, i) => (
        <span key={i} style={{
          width: 3, height: h, borderRadius: 1,
          background: i < level ? (color || DASH.ink) : (dim || DASH.border)
        }} />
      ))}
    </span>
  );
};

const ModeDial = ({ mode = 'cafe', onChange }) => {
  const [open, setOpen] = React.useState(false);
  const current = TIER_MODES.find(m => m.id === mode) || TIER_MODES[1];
  return (
    <div style={{ position: 'relative', flexShrink: 0 }}>
      <div onClick={() => setOpen(o => !o)} style={{
        display: 'inline-flex', alignItems: 'center', gap: 8,
        height: 40, padding: '0 10px', borderRadius: 10,
        background: DASH.surface, border: `1px solid ${DASH.border}`,
        color: DASH.text, cursor: 'pointer', userSelect: 'none'
      }}>
        <ModeIcon kind={current.id} size={16} color={DASH.text} />
        <ModeMeter level={current.level} />
        <span style={{
          fontSize: 9, color: DASH.textSec, marginTop: 1,
          transform: open ? 'rotate(180deg)' : 'none', transition: 'transform 0.15s'
        }}>▼</span>
      </div>
      {open && (
        <>
          <div onClick={() => setOpen(false)} style={{
            position: 'fixed', inset: 0, zIndex: 9, background: 'transparent'
          }} />
          <div style={{
            position: 'absolute', top: 46, right: 0, width: 224, zIndex: 10,
            background: DASH.surface, border: `1px solid ${DASH.border}`,
            borderRadius: 12, boxShadow: DASH.shadowRaised, overflow: 'hidden'
          }}>
            <div style={{
              padding: '10px 12px 4px', fontSize: 10,
              fontFamily: DASH.mono, fontWeight: 700, color: DASH.textTer,
              letterSpacing: 0.7, textTransform: 'uppercase'
            }}>Mode</div>
            {TIER_MODES.map((m, i) => {
              const on = m.id === current.id;
              return (
                <div key={m.id} onClick={() => { onChange && onChange(m.id); setOpen(false); }} style={{
                  padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10,
                  cursor: 'pointer',
                  background: on ? DASH.accentWash : 'transparent',
                  borderTop: `1px solid ${DASH.divider}`
                }}>
                  <ModeIcon kind={m.id} size={16} color={on ? DASH.accent : DASH.text} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 600, color: on ? DASH.accent : DASH.text, letterSpacing: -0.1 }}>{m.label}</div>
                    <div style={{ fontSize: 10.5, color: DASH.textSec, marginTop: 1 }}>{m.sub}</div>
                  </div>
                  <ModeMeter level={m.level} color={on ? DASH.accent : DASH.ink} />
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
};

const UnifiedTopNav = ({ title, sub, mode, onMode, badge }) => {
  const [m, setM] = React.useState(mode || 'cafe');
  const cur = onMode ? mode : m;
  const set = onMode || setM;
  return (
    <div style={{ padding: '14px 16px 10px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontSize: 19, fontWeight: 700, color: DASH.ink, letterSpacing: -0.4,
            lineHeight: 1.15,
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis'
          }}>{title}</div>
          {sub && (
            <div style={{
              fontSize: 11.5, color: DASH.textSec, fontWeight: 500, marginTop: 3,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', ...DASH.num
            }}>{sub}</div>
          )}
        </div>
        <ModeDial mode={cur} onChange={set} />
        <HeaderIconBtn badge={badge}><NavIcon kind="bell" /></HeaderIconBtn>
      </div>
    </div>
  );
};

// Slim one-line "open tickets" strip — directly under the app bar.
// Manager's live number. numericMedium for the values, no card chrome.
const OpenTicketsBar = ({ count, total, late }) => (
  <div style={{
    padding: '8px 16px 2px',
    display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap'
  }}>
    <span style={{
      display: 'inline-flex', alignItems: 'baseline', gap: 6,
      fontSize: 13.5, color: DASH.text, fontWeight: 600, letterSpacing: -0.1, ...DASH.num
    }}>
      <span style={{ width: 6, height: 6, borderRadius: 4, background: DASH.ink, alignSelf: 'center' }} />
      <strong style={{ fontWeight: 700 }}>{count} open</strong>
      <span style={{ color: DASH.textSec, fontWeight: 500 }}>· {total} in flight</span>
    </span>
    {late > 0 && (
      <span style={{
        fontSize: 10, fontFamily: DASH.mono, fontWeight: 700, color: DASH.late,
        background: DASH.lateSoft, padding: '2px 6px', borderRadius: 4, letterSpacing: 0.5
      }}>{late} LATE</span>
    )}
  </div>
);

// Legacy ContextStrip — superseded by DashTopBar + OpenTicketsBar. Kept as a
// no-op shim that renders both pieces from the old prop shape so any older
// call site still gets a sensible header.
const ContextStrip = ({ outlet, mode, time, openTickets, openTotal, drawer }) => (
  <>
    <DashTopBar outlet={outlet} mode={mode} time={time} drawer={drawer} />
    {openTickets != null && (
      <OpenTicketsBar count={openTickets} total={openTotal} />
    )}
  </>
);

// ============================================================================
// 24 · CategoryGlyph — small monochrome Lucide-style icon
// ============================================================================
// 2px stroke, no fill, currentColor. Used on FOH tiles as a category cue
// next to the eyebrow text. One glyph per category, not per item.

const CategoryGlyph = ({ kind, size = 14, color }) => {
  const p = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', style: { display: 'inline-block', flexShrink: 0 } };
  const c = { stroke: color || 'currentColor', strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (kind) {
    case 'cup': // tea / coffee
      return <svg {...p}><path d="M4 9h13v6a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4V9Z" {...c} /><path d="M17 11h2a2 2 0 0 1 0 4h-2" {...c} /><path d="M8 5c0-2 2-2 2-4M12 5c0-2 2-2 2-4" {...c} /></svg>;
    case 'glass': // juice / cold drink / lassi
      return <svg {...p}><path d="M7 4h10l-1.2 16a1 1 0 0 1-1 .9H9.2a1 1 0 0 1-1-.9L7 4Z" {...c} /><path d="M7.6 9h8.8" {...c} /></svg>;
    case 'bowl': // rice / curry / soup
      return <svg {...p}><path d="M3 11h18a9 9 0 0 1-18 0Z" {...c} /><path d="M6 7c0-1 .5-2 1.5-2M11 6c0-1 .5-2 1.5-2M16 6c0-1 .5-2 1.5-2" {...c} /></svg>;
    case 'flame': // grill / spicy
      return <svg {...p}><path d="M12 3s4 4 4 8a4 4 0 1 1-8 0c0-1.5.8-2.5 1.5-3.5" {...c} /></svg>;
    case 'bread': // bread / naan / paratha
      return <svg {...p}><path d="M4 11a4 4 0 0 1 4-4h8a4 4 0 0 1 4 4v3a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3v-3Z" {...c} /><path d="M9 11v6M13 11v6M17 11v6" {...c} /></svg>;
    case 'leaf': // side / salad / herb
      return <svg {...p}><path d="M5 19c0-8 5-13 14-14 1 9-4 14-14 14Z" {...c} /><path d="M9 15c2.5-3 5-4.5 8-5" {...c} /></svg>;
    case 'cake': // dessert
      return <svg {...p}><path d="M4 12h16v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8Z" {...c} /><path d="M4 15h16" {...c} /><path d="M9 12V8a1 1 0 1 1 2 0v4M13 12V8a1 1 0 1 1 2 0v4" {...c} /></svg>;
    case 'cookie': // snack
      return <svg {...p}><circle cx="12" cy="12" r="9" {...c} /><circle cx="9" cy="10" r="0.5" fill="currentColor" stroke="none" /><circle cx="14" cy="9" r="0.5" fill="currentColor" stroke="none" /><circle cx="13" cy="14" r="0.5" fill="currentColor" stroke="none" /><circle cx="9" cy="15" r="0.5" fill="currentColor" stroke="none" /></svg>;
    case 'drumstick': // chicken / meat
      return <svg {...p}><path d="M14 4a4 4 0 0 1 4 4c0 1.5-.5 3-2 4l-1 1-5 5-3-3 5-5 1-1c1-1.5 1.5-3 1-5Z" {...c} /><path d="M7 14l-2 2a2 2 0 0 0 2 3l1-1M5 16l-2 2" {...c} /></svg>;
    default:
      return <svg {...p}><circle cx="12" cy="12" r="7" {...c} /></svg>;
  }
};

// ============================================================================
// 25 · LineChart — Excel-familiar revenue line
// ============================================================================
// Single revenue line (plum #4C1D5E — the one accent on this card). Optional
// dashed muted-grey prior-period line. End labels on both lines. Minimal
// gridlines, plain feel.

const LineChart = ({
  today, yesterday, height = 140,
  todayLabel = 'Today', priorLabel = 'Prior',
  xLabels = ['9 AM', '12 PM', '3 PM', '6 PM', '11 PM'],
  fill = false, fillColor,
  yFormat = (v) => `৳${v >= 1000 ? Math.round(v / 1000) + 'k' : v}`
}) => {
  const w = 320, padL = 8, padR = 56, padTop = 18, padBot = 26;
  const max = Math.max(...today, ...(yesterday || [0])) * 1.08 || 1;
  const innerW = w - padL - padR, innerH = height - padTop - padBot;
  const xs = today.map((_, i) => padL + (i / (today.length - 1)) * innerW);
  const ys = (vs) => vs.map((v) => padTop + innerH - (v / max) * innerH);
  const todayYs = ys(today);
  const priorYs = yesterday ? ys(yesterday) : null;
  const dPath = (xs, ys) => xs.map((x, i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${ys[i].toFixed(1)}`).join(' ');

  const lastX = xs[xs.length - 1];
  const lastTodayY = todayYs[todayYs.length - 1];
  const lastPriorY = priorYs ? priorYs[priorYs.length - 1] : null;
  const lastTodayVal = today[today.length - 1];
  const lastPriorVal = yesterday ? yesterday[yesterday.length - 1] : null;

  // y-axis ticks — 3 light gridlines
  const ticks = [0.25, 0.5, 0.75, 1].map((t) => ({
    v: max * t,
    y: padTop + innerH - t * innerH
  }));

  return (
    <svg width="100%" height={height} viewBox={`0 0 ${w} ${height}`} style={{ display: 'block' }}>
      {/* gridlines */}
      {ticks.map((t, i) => (
        <line key={i} x1={padL} y1={t.y} x2={padL + innerW} y2={t.y}
          stroke={DASH.divider} strokeWidth="0.5"
          strokeDasharray={i === ticks.length - 1 ? '0' : '0'} />
      ))}
      <line x1={padL} y1={padTop + innerH} x2={padL + innerW} y2={padTop + innerH}
        stroke={DASH.borderStrong} strokeWidth="0.5" />
      {/* prior line — dashed muted */}
      {priorYs && (
        <path d={dPath(xs, priorYs)} fill="none"
          stroke={DASH.textTer} strokeWidth="1.4"
          strokeDasharray="3 3"
          strokeLinecap="round" strokeLinejoin="round" />
      )}
      {/* accent-wash area fill under today line */}
      {fill && (
        <path
          d={`${dPath(xs, todayYs)} L${xs[xs.length - 1].toFixed(1)},${(padTop + innerH).toFixed(1)} L${xs[0].toFixed(1)},${(padTop + innerH).toFixed(1)} Z`}
          fill={fillColor || DASH.accentWash} stroke="none" />
      )}
      {/* today line — plum, the one accent on this card */}
      <path d={dPath(xs, todayYs)} fill="none"
        stroke={DASH.accent} strokeWidth="2"
        strokeLinecap="round" strokeLinejoin="round" />
      {/* today endpoint dot */}
      <circle cx={lastX} cy={lastTodayY} r="3"
        fill={DASH.surface} stroke={DASH.accent} strokeWidth="2" />
      {/* prior endpoint dot */}
      {priorYs && (
        <circle cx={lastX} cy={lastPriorY} r="2"
          fill={DASH.surface} stroke={DASH.textTer} strokeWidth="1.2" />
      )}
      {/* x labels */}
      {xLabels.map((l, i) => {
        const f = i / (xLabels.length - 1);
        return (
          <text key={i}
            x={padL + f * innerW}
            y={height - 8}
            textAnchor={i === 0 ? 'start' : i === xLabels.length - 1 ? 'end' : 'middle'}
            fontFamily={DASH.mono} fontSize="9" fontWeight="600"
            fill={DASH.textTer} letterSpacing="0.4">{l}</text>
        );
      })}
      {/* line-end labels */}
      <g>
        <text x={lastX + 6} y={lastTodayY + 4}
          fontFamily={DASH.mono} fontSize="10.5" fontWeight="700"
          fill={DASH.accent} style={{ letterSpacing: 0.2 }}>{yFormat(lastTodayVal)}</text>
        <text x={lastX + 6} y={lastTodayY - 7}
          fontFamily={DASH.mono} fontSize="8.5" fontWeight="600"
          fill={DASH.textSec} style={{ letterSpacing: 0.4, textTransform: 'uppercase' }}>{todayLabel}</text>
        {priorYs && (
          <>
            <text x={lastX + 6} y={lastPriorY + 4}
              fontFamily={DASH.mono} fontSize="10.5" fontWeight="600"
              fill={DASH.textSec} style={{ letterSpacing: 0.2 }}>{yFormat(lastPriorVal)}</text>
            <text x={lastX + 6} y={lastPriorY - 7}
              fontFamily={DASH.mono} fontSize="8.5" fontWeight="600"
              fill={DASH.textTer} style={{ letterSpacing: 0.4, textTransform: 'uppercase' }}>{priorLabel}</text>
          </>
        )}
      </g>
    </svg>
  );
};

const LineChartCard = ({ title, today, yesterday, todayLabel, priorLabel, xLabels, peakNote }) => (
  <div style={{
    background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 12,
    padding: '12px 12px 6px'
  }}>
    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '0 4px 4px' }}>
      <span style={{
        fontSize: 10.5, fontFamily: DASH.mono, color: DASH.textSec, fontWeight: 600,
        letterSpacing: 0.5, textTransform: 'uppercase'
      }}>{title}</span>
      {peakNote && (
        <span style={{
          fontSize: 10, fontFamily: DASH.mono, color: DASH.textSec, fontWeight: 600,
          letterSpacing: 0.4
        }}>{peakNote}</span>
      )}
    </div>
    <LineChart today={today} yesterday={yesterday} todayLabel={todayLabel} priorLabel={priorLabel} xLabels={xLabels} />
    <div style={{ display: 'flex', gap: 14, padding: '2px 4px 6px' }}>
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11, color: DASH.textSec }}>
        <span style={{ width: 16, height: 2, background: DASH.accent, borderRadius: 1 }} />
        {todayLabel || 'Today'}
      </span>
      {yesterday && (
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11, color: DASH.textSec }}>
          <svg width="16" height="2"><line x1="0" y1="1" x2="16" y2="1" stroke={DASH.textTer} strokeWidth="1.4" strokeDasharray="3 3" /></svg>
          {priorLabel || 'Prior'}
        </span>
      )}
    </div>
  </div>
);

// ============================================================================
// 25b · PeakHoursCard — single-series hourly volume with accent-wash fill
// ============================================================================
// A plain, Excel-familiar line of order volume across the day. One plum line,
// accentWash area fill underneath (non-interactive tint, per system). No prior
// line, no legend — the peak note on the right names the busiest window.

const PeakHoursCard = ({ title = 'Peak hours', data, xLabels, peakNote, unit = 'orders' }) => (
  <div style={{
    background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 12,
    padding: '12px 12px 8px'
  }}>
    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '0 4px 6px' }}>
      <span style={{
        fontSize: 10.5, fontFamily: DASH.mono, color: DASH.textSec, fontWeight: 600,
        letterSpacing: 0.5, textTransform: 'uppercase'
      }}>{title}</span>
      {peakNote && (
        <span style={{
          fontSize: 10, fontFamily: DASH.mono, color: DASH.textSec, fontWeight: 700,
          letterSpacing: 0.4, textTransform: 'uppercase'
        }}>{peakNote}</span>
      )}
    </div>
    <LineChart
      today={data}
      fill
      height={130}
      todayLabel=""
      xLabels={xLabels}
      yFormat={(v) => `${v}`}
    />
    <div style={{ padding: '4px 4px 2px' }}>
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 10.5, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 600, letterSpacing: 0.4, textTransform: 'uppercase' }}>
        <span style={{ width: 16, height: 2, background: DASH.accent, borderRadius: 1 }} />
        {unit} / hour
      </span>
    </div>
  </div>
);

// ============================================================================
// 26 · MenuPerfTable — Excel-like table for Owner menu performance
// ============================================================================
// Columns: Item | Qty | Revenue | Share % | vs prev. Right-aligned numerics
// in tabular figures. Thin row dividers (#E2DDE8). No rank chip, no shadow,
// no plum data colours.

const MenuPerfTable = ({ rows, showMargin = false }) => {
  const cols = showMargin
    ? '1.5fr 0.6fr 1.1fr 0.7fr 1fr'
    : '1.6fr 0.6fr 1.1fr 0.7fr 1fr';
  const headers = showMargin
    ? ['Item', 'Qty', 'Revenue', 'Margin', 'vs prev']
    : ['Item', 'Qty', 'Revenue', 'Share', 'vs prev'];
  return (
    <div style={{
      background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 12,
      overflow: 'hidden'
    }}>
      {/* header row */}
      <div style={{
        display: 'grid', gridTemplateColumns: cols, padding: '9px 14px',
        background: DASH.surfaceAlt, borderBottom: `1px solid ${DASH.border}`,
        columnGap: 8
      }}>
        {headers.map((h, i) => (
          <div key={i} style={{
            fontSize: 9.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 700,
            letterSpacing: 0.6, textTransform: 'uppercase',
            textAlign: i === 0 ? 'left' : 'right'
          }}>{h}</div>
        ))}
      </div>
      {/* body rows */}
      {rows.map((r, i) => {
        const deltaUp = !(r.vsPrev || '').startsWith('-') && !(r.vsPrev || '').startsWith('−');
        const deltaCol = r.vsPrev == null || r.vsPrev === '—'
          ? DASH.textTer
          : deltaUp ? DASH.good : DASH.danger;
        return (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: cols, padding: '10px 14px',
            borderTop: i ? `1px solid ${DASH.divider}` : 'none',
            columnGap: 8, alignItems: 'center'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
              <span style={{
                fontSize: 9.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 700,
                ...DASH.num, width: 14, flexShrink: 0
              }}>{String(i + 1).padStart(2, '0')}</span>
              <span style={{
                fontSize: 13, fontWeight: 600, color: DASH.text,
                whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                letterSpacing: -0.1
              }}>{r.name}</span>
              {r.warn && (
                <span style={{
                  fontSize: 8.5, fontFamily: DASH.mono, fontWeight: 700, color: DASH.warn,
                  background: DASH.warnSoft, padding: '1px 4px', borderRadius: 3,
                  letterSpacing: 0.4, textTransform: 'uppercase', flexShrink: 0
                }}>{r.warn}</span>
              )}
            </div>
            <div style={{ fontSize: 12.5, color: DASH.text, fontWeight: 500, textAlign: 'right', ...DASH.num }}>
              {r.qty}
            </div>
            <div style={{ fontSize: 13, color: DASH.text, fontWeight: 600, textAlign: 'right', letterSpacing: -0.1, ...DASH.num }}>
              {r.rev}
            </div>
            <div style={{ fontSize: 12, color: DASH.textSec, fontWeight: 500, textAlign: 'right', ...DASH.num }}>
              {showMargin ? r.margin : r.share}
            </div>
            <div style={{
              fontSize: 11.5, color: deltaCol, fontWeight: 600,
              textAlign: 'right', ...DASH.num,
              display: 'inline-flex', alignItems: 'center', justifyContent: 'flex-end', gap: 3
            }}>
              {r.vsPrev && r.vsPrev !== '—' && (
                <span style={{ fontSize: 10 }}>{deltaUp ? '↑' : '↓'}</span>
              )}
              <span>{r.vsPrev || '—'}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
};

// ============================================================================
// 24 · RingupSearch — type-to-search / quick-add atop the ring-up grid
// ============================================================================
// The brief: "add a type-to-search / quick-add so the Manager can key an item
// by name or code without scrolling." This is the muscle-memory loop —
// chits arrive pre-written, the Manager keys them.

const RingupSearch = ({ placeholder = 'Search items or scan code', recent }) => (
  <div>
    <div style={{
      background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 10,
      padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10
    }}>
      <span style={{ color: DASH.textTer, display: 'inline-flex' }}>
        <NavIcon kind="search" />
      </span>
      <span style={{ flex: 1, fontSize: 13.5, color: DASH.textTer, fontWeight: 500 }}>
        {placeholder}
      </span>
      <span style={{
        fontSize: 10, fontFamily: DASH.mono, fontWeight: 700, color: DASH.textSec,
        letterSpacing: 0.5, padding: '3px 7px',
        background: DASH.surfaceAlt, border: `1px solid ${DASH.border}`, borderRadius: 5
      }}>⌘K</span>
    </div>
    {recent && recent.length > 0 && (
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8, padding: '0 2px' }}>
        <span style={{
          fontSize: 10, fontFamily: DASH.mono, fontWeight: 600, color: DASH.textTer,
          letterSpacing: 0.6, textTransform: 'uppercase', alignSelf: 'center', marginRight: 2
        }}>Recent</span>
        {recent.map((r, i) => (
          <span key={i} style={{
            fontSize: 12, fontWeight: 600, color: DASH.text,
            background: DASH.surface, border: `1px solid ${DASH.border}`,
            padding: '5px 9px', borderRadius: 6,
            display: 'inline-flex', alignItems: 'center', gap: 4
          }}>
            {r}
          </span>
        ))}
      </div>
    )}
  </div>
);

// ============================================================================
// 25 · OpenTicketRow — list row for in-flight orders (Manager)
// ============================================================================
// Use this instead of a full floor map when the mode doesn't have tables
// (T1 Food Cart = takeaway only).

const OpenTicketRow = ({ tag, who, items, total, age, late, first }) => (
  <div style={{
    padding: '12px 14px',
    borderTop: first ? 'none' : `1px solid ${DASH.divider}`,
    display: 'flex', alignItems: 'center', gap: 12
  }}>
    <div style={{
      padding: '3px 7px', borderRadius: 5,
      background: late ? DASH.lateSoft : DASH.surfaceAlt,
      color: late ? DASH.late : DASH.textSec,
      fontSize: 10, fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.5,
      flexShrink: 0
    }}>{tag}</div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, letterSpacing: -0.1, ...DASH.num }}>
        {who}
      </div>
      <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 2, fontFamily: DASH.mono, fontWeight: 500, ...DASH.num }}>
        {items} items · {age}
      </div>
    </div>
    <div style={{ fontSize: 14, fontWeight: 600, color: DASH.text, ...DASH.num }}>{total}</div>
  </div>
);

// ============================================================================
// 26 · CollapsedSummary — demoted today-summary for Manager screens
// ============================================================================
// Per brief: "Today summary, demoted and collapsible — drawer total, order
// count, top item. A glance, not the focus."

const CollapsedSummary = ({ cash, orders, top }) => {
  const [open, setOpen] = React.useState(false);
  return (
    <div style={{
      background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 12,
      overflow: 'hidden'
    }}>
      <div onClick={() => setOpen(o => !o)} style={{
        padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
        cursor: 'pointer'
      }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontSize: 10.5, fontFamily: DASH.mono, fontWeight: 600, color: DASH.textTer,
            letterSpacing: 0.6, textTransform: 'uppercase'
          }}>Today so far</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginTop: 4 }}>
            <span style={{ fontSize: 16, fontWeight: 700, color: DASH.text, letterSpacing: -0.3, ...DASH.num }}>{cash}</span>
            <span style={{ fontSize: 12, color: DASH.textSec, fontWeight: 500, ...DASH.num }}>{orders} orders</span>
          </div>
        </div>
        <span style={{
          fontSize: 12, color: DASH.textSec,
          transform: open ? 'rotate(180deg)' : 'none',
          transition: 'transform 0.18s'
        }}>▾</span>
      </div>
      {open && (
        <div style={{
          borderTop: `1px solid ${DASH.divider}`, padding: '10px 14px 12px',
          fontSize: 12, color: DASH.textSec
        }}>
          {top && (
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 11.5, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 600 }}>TOP ITEM</span>
              <span style={{ fontSize: 13, fontWeight: 600, color: DASH.text, ...DASH.num }}>{top}</span>
            </div>
          )}
          <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 8, fontStyle: 'italic' }}>
            Open the Reports tab for hour-by-hour and menu trends.
          </div>
        </div>
      )}
    </div>
  );
};

// ============================================================================
// 27 · MenuPerfHeader — sortable column headers for menu performance lists
// ============================================================================
// Per brief, on Owner screens menu performance is the SECOND pillar; surfaces
// must be sortable by revenue / quantity / margin. We render a real header
// row above the MoverRow / TopItemRow stacks.

// MenuPerfHeader — sortable column chips. Selected chip uses accentSoft
// fill + ink text + pill radius (brief: selected-state, not full accent).
const MENU_SORTS = [
  { id: 'rev', l: 'Revenue' },
  { id: 'qty', l: 'Qty' },
  { id: 'margin', l: 'Margin' }
];

const MenuPerfHeader = ({ sort = 'rev', onChange }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 6, padding: '0 2px', marginBottom: 8
  }}>
    <span style={{
      fontSize: 10, fontFamily: DASH.mono, fontWeight: 600, color: DASH.textTer,
      letterSpacing: 0.6, textTransform: 'uppercase', marginRight: 4
    }}>Sort</span>
    {MENU_SORTS.map((s) => {
      const on = s.id === sort;
      return (
        <span key={s.id} onClick={() => onChange && onChange(s.id)} style={{
          padding: '5px 11px', borderRadius: 999,
          background: on ? DASH.accentSoft : DASH.surface,
          color: on ? DASH.accentSoftInk : DASH.textSec,
          border: `1px solid ${on ? 'transparent' : DASH.border}`,
          fontSize: 11.5, fontWeight: on ? 700 : 600, cursor: 'pointer',
          display: 'inline-flex', alignItems: 'center', gap: 4
        }}>
          {s.l}{on && <span style={{ fontSize: 9, opacity: 0.7 }}>▼</span>}
        </span>
      );
    })}
  </div>
);

// ============================================================================
// Exports
// ============================================================================

Object.assign(window, {
  DASH, DashCard, MicroLabel, Bn,
  DashScreen, DashBottomNav, TierBadge, DashHeader, HeaderIconBtn,
  TopNav, RoleToggle, TotalsHeader, FOHCounter, FOHTile, CreateOrderTray,
  Section, SecHead, Divider,
  Sparkline, MiniSpark,
  EarnedCard, PaySplit, TowerTile, TowerRow, KpiStrip,
  FloorMap, TABLE_STATES,
  AlertRow, QuickActions, MoverRow, ChannelSplit, OpsTrio, StaffRow,
  GoalCard, OutletCard, Metric, CloseCard, QuickSale,
  Delta, PeriodSelector, PeriodSubtitle, ContextStrip,
  RingupSearch, OpenTicketRow, CollapsedSummary, MenuPerfHeader,
  DashTopBar, CompactRoleToggle, OpenTicketsBar,
  ModeIcon, ModeMeter, ModeDial, UnifiedTopNav, TIER_MODES,
  CategoryGlyph, LineChart, LineChartCard, PeakHoursCard, MenuPerfTable
});