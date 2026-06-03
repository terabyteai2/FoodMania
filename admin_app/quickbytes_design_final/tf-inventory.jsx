// Terafoods · Inventory module — 5 screens
// Uses DASH design tokens established by the dashboard. Accent ≤ 5% of viewport,
// tabular numerals on every metric, 44px tap targets, Lucide-style 1.6-stroke icons.

// ============================================================================
// Shared inventory primitives
// ============================================================================

const INV = {
  rowH: 64,                          // mandated row height
  fab: 56,
  bottomBarH: 80,                    // fixed action row above bottom nav
  page: 16,                          // standard horizontal margin
};

// Inv icons — Lucide vocabulary, 1.6 stroke. Sizes via the `s` prop.
const InvIcon = ({ kind, s = 20, color }) => {
  const p = { width: s, height: s, viewBox: '0 0 24 24', fill: 'none' };
  const c = { stroke: color || 'currentColor', strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (kind) {
    case 'package':
      return <svg {...p}><path d="M3.5 7.5 12 3l8.5 4.5v9L12 21l-8.5-4.5v-9Z" {...c} /><path d="M3.5 7.5 12 12l8.5-4.5M12 12v9" {...c} /></svg>;
    case 'plus':
      return <svg {...p}><path d="M12 5v14M5 12h14" {...c} /></svg>;
    case 'camera':
      return <svg {...p}><rect x="3" y="7" width="18" height="13" rx="2" {...c} /><circle cx="12" cy="13.5" r="3.5" {...c} /><path d="M9 7l1.5-2.5h3L15 7" {...c} /></svg>;
    case 'clipboardCheck':
      return <svg {...p}><rect x="6" y="4.5" width="12" height="16" rx="2" {...c} /><path d="M9 4.5h6v3H9zM9 13.5l2 2 4-4.5" {...c} /></svg>;
    case 'alertTriangle':
      return <svg {...p}><path d="M12 4 3 19h18L12 4Z" {...c} /><path d="M12 10v4M12 17v.5" {...c} /></svg>;
    case 'alertOctagon':
      return <svg {...p}><path d="m8 3 8 0 5 5v8l-5 5h-8l-5-5v-8l5-5Z" {...c} /><path d="M12 8v4M12 16v.5" {...c} /></svg>;
    case 'trendingUp':
      return <svg {...p}><path d="M4 15l5-5 3.5 3.5L20 6" {...c} /><path d="M15 6h5v5" {...c} /></svg>;
    case 'trendingDown':
      return <svg {...p}><path d="M4 9l5 5 3.5-3.5L20 18" {...c} /><path d="M15 18h5v-5" {...c} /></svg>;
    case 'search':
      return <svg {...p}><circle cx="11" cy="11" r="6.5" {...c} /><path d="m20 20-3.8-3.8" {...c} /></svg>;
    case 'moreVertical':
      return <svg {...p}><circle cx="12" cy="5.5" r="1" fill={color || 'currentColor'} /><circle cx="12" cy="12" r="1" fill={color || 'currentColor'} /><circle cx="12" cy="18.5" r="1" fill={color || 'currentColor'} /></svg>;
    case 'chevronRight':
      return <svg {...p}><path d="m9 6 6 6-6 6" {...c} /></svg>;
    case 'chevronDown':
      return <svg {...p}><path d="m6 9 6 6 6-6" {...c} /></svg>;
    case 'sparkles':
      return <svg {...p}><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6" {...c} /></svg>;
    case 'back':
      return <svg {...p}><path d="M19 12H5M10 6l-6 6 6 6" {...c} /></svg>;
    case 'bell':
      return <svg {...p}><path d="M6 8a6 6 0 1 1 12 0c0 6 2 7 2 7H4s2-1 2-7Z" {...c} /><path d="M10.5 20a1.7 1.7 0 0 0 3 0" {...c} /></svg>;
    case 'share':
      return <svg {...p}><circle cx="6" cy="12" r="2.5" {...c} /><circle cx="18" cy="6" r="2.5" {...c} /><circle cx="18" cy="18" r="2.5" {...c} /><path d="M8.2 10.8 15.8 7.2M8.2 13.2 15.8 16.8" {...c} /></svg>;
    case 'edit':
      return <svg {...p}><path d="M4 20h4l10-10-4-4L4 16v4Z" {...c} /><path d="m14 6 4 4" {...c} /></svg>;
    case 'check':
      return <svg {...p}><path d="m5 12.5 5 4.5 9-10" {...c} /></svg>;
    case 'minus':
      return <svg {...p}><path d="M5 12h14" {...c} /></svg>;
    case 'phone':
      return <svg {...p}><path d="M5 4h3l2 5-2.5 1.5a11 11 0 0 0 5.5 5.5L15 13.5l5 2v3a2 2 0 0 1-2 2A14 14 0 0 1 4 6a2 2 0 0 1 1-2Z" {...c} /></svg>;
    case 'user':
      return <svg {...p}><circle cx="12" cy="8" r="3.5" {...c} /><path d="M5 20a7 7 0 0 1 14 0" {...c} /></svg>;
    case 'truck':
      return <svg {...p}><path d="M3 7h11v9H3zM14 10h4l3 3v3h-7" {...c} /><circle cx="7" cy="18" r="2" {...c} /><circle cx="17.5" cy="18" r="2" {...c} /></svg>;
    case 'box':
      return <svg {...p}><rect x="4" y="6" width="16" height="14" rx="2" {...c} /><path d="M4 10h16M9 6V4h6v2" {...c} /></svg>;
    default:
      return null;
  }
};

// Inventory app-bar — distinct from the dashboard's DashHeader (no greeting,
// no biz name; this is a section header). Elevation 0, lives on `paper`.
const InvAppBar = ({ title, sub, leading, trailing }) => (
  <div style={{
    padding: '14px 16px 12px',
    display: 'flex', alignItems: 'center', gap: 10,
    background: DASH.bg,
  }}>
    {leading}
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 20, fontWeight: 600, color: DASH.text, letterSpacing: -0.3, lineHeight: 1.1 }}>{title}</div>
      {sub && <div style={{ fontSize: 11.5, color: DASH.textSec, marginTop: 4, ...DASH.num }}>{sub}</div>}
    </div>
    {trailing && <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexShrink: 0 }}>{trailing}</div>}
  </div>
);

// Compact icon button used in the inventory app bar (smaller than the header
// one so 3 fit comfortably next to the title).
const InvIconBtn = ({ children, badge, pip }) => (
  <div style={{
    width: 36, height: 36, borderRadius: 10, background: DASH.surface,
    border: `1px solid ${DASH.border}`, display: 'grid', placeItems: 'center',
    color: DASH.text, position: 'relative',
  }}>
    {children}
    {pip && (
      <div style={{
        position: 'absolute', bottom: -2, right: -2,
        width: 10, height: 10, borderRadius: 5,
        background: DASH.good, border: `2px solid ${DASH.bg}`,
      }} />
    )}
    {badge != null && (
      <div style={{
        position: 'absolute', top: -4, right: -4, minWidth: 16, height: 16, padding: '0 4px',
        borderRadius: 8, background: DASH.late, color: '#FFF', fontSize: 9.5, fontWeight: 700,
        display: 'grid', placeItems: 'center', border: `2px solid ${DASH.bg}`, ...DASH.num,
      }}>{badge}</div>
    )}
  </div>
);

// EN/BN locale toggle chip — paper surface, hard 10px radius (Inputs/Small Buttons).
const LocaleToggle = ({ value = 'EN' }) => (
  <div style={{
    height: 36, borderRadius: 10, background: DASH.surface,
    border: `1px solid ${DASH.border}`, display: 'flex', alignItems: 'center',
    overflow: 'hidden',
  }}>
    {['EN', 'BN'].map((l) => {
      const on = l === value;
      return (
        <div key={l} style={{
          padding: '0 10px', height: '100%', display: 'grid', placeItems: 'center',
          fontSize: 11, fontWeight: 700, fontFamily: DASH.mono, letterSpacing: 0.4,
          background: on ? DASH.ink : 'transparent',
          color: on ? DASH.onInk : DASH.textTer,
        }}>{l}</div>
      );
    })}
  </div>
);

// Sunk numeric/text input cell — F4F4F1 well, ink text, tabular numerals.
const InvInput = ({ value, placeholder, prefix, suffix, focused, numeric = false, align = 'left' }) => (
  <div style={{
    height: 48, padding: '0 14px',
    background: DASH.surfaceAlt,
    border: `1px solid ${focused ? DASH.ink : 'transparent'}`,
    borderRadius: 10,
    display: 'flex', alignItems: 'center', gap: 8,
  }}>
    {prefix && <span style={{ fontSize: 14, color: DASH.textSec, fontWeight: 600, ...(numeric ? DASH.num : null) }}>{prefix}</span>}
    <div style={{
      flex: 1, fontSize: 15, color: value ? DASH.text : DASH.textTer,
      fontWeight: 600, textAlign: align, ...(numeric ? DASH.num : null),
    }}>
      {value || placeholder}
      {focused && <span style={{ marginLeft: 1, color: DASH.text }}>|</span>}
    </div>
    {suffix && <span style={{ fontSize: 13, color: DASH.textSec, fontWeight: 600 }}>{suffix}</span>}
  </div>
);

// Eyebrow ("TOP MOVERS · TODAY") — small wide mono label.
const Eyebrow = ({ children, color }) => (
  <div style={{
    fontSize: 10.5, fontFamily: DASH.mono, color: color || DASH.textSec,
    letterSpacing: 0.8, textTransform: 'uppercase', fontWeight: 700, marginBottom: 10,
  }}>{children}</div>
);

// Signal pill (HEALTHY / LOW / OUT). Uses signal soft + signal ink.
const InvPill = ({ tone = 'good', children }) => {
  const t = {
    good:   { bg: DASH.goodSoft,   color: DASH.good },
    warn:   { bg: DASH.warnSoft,   color: DASH.warn },
    danger: { bg: DASH.dangerSoft, color: DASH.danger },
    urgent: { bg: DASH.lateSoft,   color: DASH.late },
    neutral:{ bg: DASH.surfaceAlt, color: DASH.textSec },
  }[tone];
  return (
    <span style={{
      padding: '3px 8px', borderRadius: 6,
      background: t.bg, color: t.color,
      fontSize: 10, fontWeight: 700, fontFamily: DASH.mono,
      letterSpacing: 0.7, textTransform: 'uppercase',
      display: 'inline-flex', alignItems: 'center', gap: 5,
    }}>{children}</span>
  );
};

// Letter avatar — accentWash fill, ink letter. (Lightest accent use.)
const InvAvatar = ({ letter, size = 40 }) => (
  <div style={{
    width: size, height: size, borderRadius: 10,
    background: DASH.accentWash, color: DASH.accentInk,
    display: 'grid', placeItems: 'center',
    fontSize: size > 36 ? 15 : 13, fontWeight: 600, letterSpacing: -0.2,
    flexShrink: 0,
  }}>{letter}</div>
);

// Fixed bottom action layer — sits above bottom nav (70). 16px padding,
// surface bg with a 1px top hairline. Used by every inventory screen.
const InvBottomBar = ({ children, padding = 12 }) => (
  <div style={{
    position: 'absolute', left: 0, right: 0, bottom: 70,
    background: DASH.surface, borderTop: `1px solid ${DASH.border}`,
    padding: `${padding}px ${INV.page}px`,
    display: 'flex', alignItems: 'center', gap: 10,
  }}>{children}</div>
);

// Bottom-bar action button — used inside InvBottomBar.
const InvAction = ({ children, variant = 'accent', icon, flex = 1, height = 48 }) => {
  const v = {
    accent: { bg: DASH.accent,  color: '#FFF',       border: DASH.accent },
    ink:    { bg: DASH.ink,     color: DASH.onInk,   border: DASH.ink },
    ghost:  { bg: DASH.surface, color: DASH.text,    border: DASH.borderStrong },
  }[variant];
  return (
    <div style={{
      flex, height, borderRadius: 10,
      background: v.bg, color: v.color, border: `1px solid ${v.border}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      fontSize: 14, fontWeight: 600, letterSpacing: -0.1,
    }}>
      {icon && <InvIcon kind={icon} s={18} />}
      {children}
    </div>
  );
};

// Inv screen shell — DashScreen with inventory tab active + bottom inset
// for the fixed action bar. `bottomBar` renders the action layer.
const InvScreen = ({ children, bottomBar, padBottom = INV.bottomBarH + 70 }) => (
  <div style={{
    position: 'relative', height: '100%', background: DASH.bg, overflow: 'hidden',
    fontFamily: DASH.font, color: DASH.text,
  }}>
    <div style={{
      position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'hidden',
      paddingBottom: padBottom, WebkitOverflowScrolling: 'touch',
    }}>
      {children}
    </div>
    {bottomBar}
    <DashBottomNav active={3} />
  </div>
);

// Tiny linear progress bar — track + accent fill. Used in Top Movers.
const FillBar = ({ pct, color }) => (
  <div style={{ height: 4, background: DASH.track, borderRadius: 2, overflow: 'hidden' }}>
    <div style={{ height: '100%', width: `${Math.max(2, pct * 100)}%`, background: color || DASH.accent, borderRadius: 2 }} />
  </div>
);

Object.assign(window, {
  INV, InvIcon, InvAppBar, InvIconBtn, LocaleToggle,
  InvInput, Eyebrow, InvPill, InvAvatar,
  InvBottomBar, InvAction, InvScreen, FillBar,
});
