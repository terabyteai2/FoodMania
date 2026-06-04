// Terafoods · shared theme + primitives
// Hi-fi, follows the master design prompt: 3 colors, 400/500 only, 12px min, 44px tap targets.

const TF = {
  W: 360,
  H: 780,
  FRAME_PAD: 8,
  C: {
    // Accent — Deep Plum. ≤ 5% of viewport.
    primary:     '#4C1D5E',  // accent — primary CTAs, FAB
    primarySoft: '#E8D8F0',  // accentSoft — selected backgrounds
    primaryWash: '#F4EDF8',  // accentWash — hover tints
    primaryDeep: '#351244',  // accentDeep — pressed
    primaryMid:  '#6B3080',  // accentMid — secondary CTAs
    accentInk:   '#FFFFFF',  // text on full-strength accent

    // Ink — Violet-black
    dark:        '#16101E',  // ink — primary text
    inkSoft:     '#2D2438',  // inkSoft — secondary emphasis

    // Scaffold — Neutral-cool violet
    bg:          '#F8F8FA',  // paper — scaffold
    paper:       '#FFFFFF',  // surface — cards/sheets
    surfaceSunk: '#F1F1F5',  // surfaceSunk — search wells

    // Borders + secondary text
    border:      '#E2DDE8',  // line — 0.5px borders
    borderStrong:'#CAC3D4',  // lineStrong — active states
    text:        '#16101E',
    textSec:     '#635B6E',  // muted
    textTer:     '#A097AB',  // mutedSoft

    // Signals — functional only
    greenText:   '#15803D',  // success
    greenBg:     '#DCFCE7',
    redText:     '#7F1D1D',  // danger
    redBg:       '#FEE2E2',
    coral:       '#9A3412',  // urgent — expedite signals
    coralBg:     '#FFEDD5',
    coralWash:   '#FFEDD5',
    warnText:    '#B45309',  // warning — low stock
    warnBg:      '#FEF3C7',
  },
};

const TFC = TF.C;

// --- Phone frame --------------------------------------------------------

const StatusBar = ({ dark }) => (
  <div style={{
    height: 32, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '0 18px', fontFamily: 'Inter, sans-serif', fontSize: 13, fontWeight: 600,
    color: dark ? '#FFF' : TFC.text, background: dark ? TFC.dark : 'transparent',
  }}>
    <span>9:41</span>
    <span style={{ display: 'flex', gap: 5, alignItems: 'center', fontSize: 11 }}>
      <span>●●●</span><span>◐</span><span>▮</span>
    </span>
  </div>
);

const Phone = ({ children, bg }) => (
  <div style={{
    width: TF.W + TF.FRAME_PAD * 2, height: TF.H + TF.FRAME_PAD * 2,
    background: TFC.dark, borderRadius: 38, padding: TF.FRAME_PAD,
    boxShadow: '0 1px 0 rgba(255,255,255,0.06) inset, 0 0 0 1px #0d0c0a',
    fontFamily: 'Inter, sans-serif',
  }}>
    <div style={{
      width: TF.W, height: TF.H, background: bg || TFC.bg, borderRadius: 30,
      position: 'relative', overflow: 'hidden',
    }}>
      <StatusBar />
      <div style={{ position: 'absolute', inset: '32px 0 0 0' }}>{children}</div>
    </div>
  </div>
);

// --- Brand mark ---------------------------------------------------------

const Logo = ({ size = 28, color = TFC.dark }) => (
  <svg width={size} height={size} viewBox="0 0 32 32" fill="none">
    <path d="M9 4v9a3 3 0 0 0 3 3v12" stroke={color} strokeWidth="2.2" strokeLinecap="round" />
    <path d="M12 4v9a3 3 0 0 1-3 3" stroke={color} strokeWidth="2.2" strokeLinecap="round" />
    <circle cx="22" cy="16" r="9" stroke={color} strokeWidth="2.2" />
    <circle cx="22" cy="16" r="3.5" fill={color} />
  </svg>
);

// --- Buttons & inputs ---------------------------------------------------

const Btn = ({ children, variant = 'primary', icon, iconRight, style, fullWidth = true, size = 'lg', disabled }) => {
  const sizes = {
    lg: { padding: '14px 18px', fontSize: 15, radius: 12, height: 50 },
    md: { padding: '10px 14px', fontSize: 14, radius: 10, height: 42 },
    sm: { padding: '7px 12px', fontSize: 13, radius: 8, height: 32 },
  }[size];
  const styles = {
    primary: { bg: disabled ? TFC.surfaceSunk : TFC.primary, color: disabled ? TFC.textTer : TFC.accentInk, border: 'none' },
    dark: { bg: TFC.dark, color: '#FFF', border: 'none' },
    ghost: { bg: 'transparent', color: TFC.text, border: `0.5px solid ${TFC.borderStrong}` },
    paper: { bg: TFC.paper, color: TFC.text, border: `0.5px solid ${TFC.border}` },
  }[variant];
  return (
    <div style={{
      width: fullWidth ? '100%' : 'auto',
      padding: sizes.padding, height: sizes.height, boxSizing: 'border-box',
      background: styles.bg, color: styles.color, border: styles.border,
      borderRadius: sizes.radius, fontSize: sizes.fontSize, fontWeight: 600,
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      opacity: disabled ? 0.6 : 1, ...style,
    }}>
      {icon && <span style={{ display: 'inline-flex', alignItems: 'center' }}>{icon}</span>}
      <span>{children}</span>
      {iconRight && <span style={{ display: 'inline-flex', alignItems: 'center' }}>{iconRight}</span>}
    </div>
  );
};

const Field = ({ label, value, placeholder, focused, prefix, suffix, hint, bn, ...rest }) => (
  <div style={{ marginBottom: 14 }} {...rest}>
    {label && (
      <div style={{ marginBottom: 6, marginLeft: 2, display: 'flex', alignItems: 'baseline', gap: 6 }}>
        <span style={{ fontSize: 13, color: TFC.text, fontWeight: 600 }}>{label}</span>
        {bn && <span style={{ fontSize: 11, color: TFC.textSec, fontFamily: '"Hind Siliguri", sans-serif' }}>{bn}</span>}
      </div>
    )}
    <div style={{
      padding: '13px 14px', minHeight: 48, boxSizing: 'border-box',
      background: TFC.paper, borderRadius: 12,
      border: `${focused ? 1 : 0.5}px solid ${focused ? TFC.dark : TFC.border}`,
      display: 'flex', alignItems: 'center', gap: 10,
    }}>
      {prefix && <span style={{ fontSize: 14, color: TFC.textSec, fontWeight: 600 }}>{prefix}</span>}
      <div style={{ flex: 1, fontSize: 15, color: value ? TFC.text : TFC.textSec, fontWeight: 400 }}>
        {value || placeholder}
        {focused && <span style={{ marginLeft: 1, color: TFC.text }}>|</span>}
      </div>
      {suffix && <span style={{ fontSize: 13, color: TFC.textSec }}>{suffix}</span>}
    </div>
    {hint && <div style={{ fontSize: 12, color: TFC.textSec, marginTop: 6, marginLeft: 2 }}>{hint}</div>}
  </div>
);

const Chip = ({ children, active, size = 'md', icon }) => {
  const px = size === 'sm' ? '6px 11px' : '8px 14px';
  const fs = size === 'sm' ? 12 : 13;
  return (
    <div style={{
      padding: px, fontSize: fs, fontWeight: active ? 500 : 400,
      background: active ? TFC.dark : TFC.paper,
      color: active ? '#FFF' : TFC.text,
      border: `0.5px solid ${active ? TFC.dark : TFC.border}`,
      borderRadius: 999, display: 'inline-flex', alignItems: 'center', gap: 6,
      whiteSpace: 'nowrap',
    }}>
      {icon && <span>{icon}</span>}
      {children}
    </div>
  );
};

const Card = ({ children, style, padded = true }) => (
  <div style={{
    background: TFC.paper, borderRadius: 12, border: `0.5px solid ${TFC.border}`,
    padding: padded ? '12px 14px' : 0, ...style,
  }}>{children}</div>
);

const StatCard = ({ label, value, sub, bn, style }) => (
  <div style={{ background: TFC.bg, borderRadius: 8, padding: '10px 12px', ...style }}>
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
      <span style={{ fontSize: 11, color: TFC.textSec, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</span>
      {bn && <span style={{ fontSize: 10, color: TFC.textSec, fontFamily: '"Hind Siliguri", sans-serif' }}>{bn}</span>}
    </div>
    <div style={{ fontSize: 22, color: TFC.text, fontWeight: 600, marginTop: 4, letterSpacing: -0.3 }}>{value}</div>
    {sub && <div style={{ fontSize: 11, color: TFC.textSec, marginTop: 2 }}>{sub}</div>}
  </div>
);

// --- Pill / status badge ------------------------------------------------

const Status = ({ kind, children }) => {
  const k = {
    pending: { bg: TFC.primarySoft, color: TFC.dark },
    accepted: { bg: TFC.greenBg, color: TFC.greenText },
    late: { bg: TFC.redBg, color: TFC.redText },
    served: { bg: TFC.greenBg, color: TFC.greenText },
    info: { bg: TFC.bg, color: TFC.textSec },
  }[kind] || { bg: TFC.bg, color: TFC.textSec };
  return (
    <span style={{
      padding: '3px 8px', borderRadius: 999, fontSize: 11, fontWeight: 600,
      background: k.bg, color: k.color, letterSpacing: 0.2, textTransform: 'uppercase',
      display: 'inline-flex', alignItems: 'center', gap: 4,
    }}>{children}</span>
  );
};

// --- Bottom nav ---------------------------------------------------------

const NavIcon = ({ kind }) => {
  const s = 22;
  const stroke = 1.6;
  const p = { width: s, height: s, viewBox: '0 0 24 24', fill: 'none' };
  const cmn = { stroke: 'currentColor', strokeWidth: stroke, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (kind) {
    case 'orders':
      return <svg {...p}><rect x="5" y="3.5" width="14" height="17" rx="2" {...cmn} /><path d="M8.5 8h7M8.5 12h7M8.5 16h4" {...cmn} /></svg>;
    case 'menu':
      return <svg {...p}><path d="M9 3v9a3 3 0 0 0 3 3v6" {...cmn} /><path d="M12 3v9a3 3 0 0 1-3 3" {...cmn} /><circle cx="17" cy="9" r="5.5" {...cmn} /><path d="M17 14.5V21" {...cmn} /></svg>;
    case 'home':
      return <svg {...p}><path d="M4 11.5 12 4l8 7.5V20a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1v-8.5Z" {...cmn} /></svg>;
    case 'inventory':
      return <svg {...p}><rect x="3.5" y="6.5" width="17" height="13" rx="1.5" {...cmn} /><path d="M3.5 10.5h17M9 6.5V4.5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" {...cmn} /></svg>;
    case 'settings':
      return <svg {...p}><circle cx="12" cy="12" r="3" {...cmn} /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.9 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.9-2.9l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.9-2.9l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.9 2.9l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z" {...cmn} /></svg>;
    case 'bell':
      return <svg {...p}><path d="M6 8a6 6 0 1 1 12 0c0 6 2 7 2 7H4s2-1 2-7Z" {...cmn} /><path d="M10.5 20a1.7 1.7 0 0 0 3 0" {...cmn} /></svg>;
    case 'plus':
      return <svg {...p}><path d="M12 5v14M5 12h14" {...cmn} /></svg>;
    case 'arrow':
      return <svg {...p}><path d="M5 12h14M14 6l6 6-6 6" {...cmn} /></svg>;
    case 'back':
      return <svg {...p}><path d="M19 12H5M10 6l-6 6 6 6" {...cmn} /></svg>;
    case 'check':
      return <svg {...p}><path d="M5 12.5 10 17l9-10" {...cmn} /></svg>;
    case 'search':
      return <svg {...p}><circle cx="11" cy="11" r="6" {...cmn} /><path d="m20 20-4.3-4.3" {...cmn} /></svg>;
    case 'camera':
      return <svg {...p}><rect x="3" y="7" width="18" height="13" rx="2" {...cmn} /><circle cx="12" cy="13.5" r="3.5" {...cmn} /><path d="M9 7l1.5-2.5h3L15 7" {...cmn} /></svg>;
    case 'printer':
      return <svg {...p}><path d="M7 9V4h10v5" {...cmn} /><rect x="4" y="9" width="16" height="8" rx="1.5" {...cmn} /><rect x="7" y="14" width="10" height="6" rx="1" {...cmn} /><circle cx="17" cy="12" r="0.7" fill="currentColor" /></svg>;
    case 'bluetooth':
      return <svg {...p}><path d="M7 7l10 10-5 4V3l5 4-10 10" {...cmn} /></svg>;
    case 'wifi':
      return <svg {...p}><path d="M2 9.5a15 15 0 0 1 20 0M5 13a10 10 0 0 1 14 0M8.5 16.5a5 5 0 0 1 7 0" {...cmn} /><circle cx="12" cy="20" r="0.8" fill="currentColor" /></svg>;
    case 'close':
      return <svg {...p}><path d="m6 6 12 12M18 6 6 18" {...cmn} /></svg>;
    case 'minus':
      return <svg {...p}><path d="M5 12h14" {...cmn} /></svg>;
    case 'dot':
      return <svg {...p}><circle cx="12" cy="12" r="3" fill="currentColor" /></svg>;
    case 'chevron':
      return <svg {...p}><path d="m9 6 6 6-6 6" {...cmn} /></svg>;
    case 'sparkle':
      return <svg {...p}><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6" {...cmn} /></svg>;
    case 'shop':
      return <svg {...p}><path d="M4 9.5 5.2 5a1 1 0 0 1 1-.8h11.6a1 1 0 0 1 1 .8L20 9.5" {...cmn} /><path d="M4 9.5h16v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 18.5v-9Z" {...cmn} /><path d="M4 9.5a2.4 2.4 0 0 0 4 0 2.4 2.4 0 0 0 4 0 2.4 2.4 0 0 0 4 0 2.4 2.4 0 0 0 4 0M9.5 20v-4.5h5V20" {...cmn} /></svg>;
    case 'people':
      return <svg {...p}><circle cx="9" cy="8" r="3" {...cmn} /><path d="M3.5 19a5.5 5.5 0 0 1 11 0M16 5.5a3 3 0 0 1 0 6M16.5 14.2A5.5 5.5 0 0 1 20.5 19" {...cmn} /></svg>;
    case 'chart':
      return <svg {...p}><path d="M4 20V4M4 20h16" {...cmn} /><path d="M8 16v-3M12 16V8M16 16v-5" {...cmn} /></svg>;
    case 'clock':
      return <svg {...p}><circle cx="12" cy="12" r="8" {...cmn} /><path d="M12 8v4.5l3 2" {...cmn} /></svg>;
    case 'trend':
      return <svg {...p}><path d="M4 15l5-5 3.5 3.5L20 6" {...cmn} /><path d="M15 6h5v5" {...cmn} /></svg>;
    case 'leaf':
      return <svg {...p}><path d="M5 19c0-8 5-13 14-14 1 9-4 14-14 14Z" {...cmn} /><path d="M9 15c2.5-3 5-4.5 8-5" {...cmn} /></svg>;
    case 'flame':
      return <svg {...p}><path d="M12 3s4 4 4 8a4 4 0 0 1-8 0c0-1.5.8-2.5 1.5-3.5C10 11 12 12 12 14" {...cmn} /><path d="M5 14a7 7 0 1 0 14 0c0-4-3-7-3-7" {...cmn} /></svg>;
    default:
      return <svg {...p}><circle cx="12" cy="12" r="8" {...cmn} /></svg>;
  }
};

const NAV_DEFAULT = [
  { kind: 'orders', label: 'Orders', bn: '' },
  { kind: 'menu', label: 'Menu', bn: '' },
  { kind: 'home', label: 'Home', bn: '' },
  { kind: 'inventory', label: 'Stock', bn: '' },
  { kind: 'settings', label: 'More', bn: '' },
];

const BottomNav = ({ active = 2, items }) => {
  const list = items || NAV_DEFAULT;
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, height: 70,
      background: TFC.paper, borderTop: `0.5px solid ${TFC.border}`,
      display: 'flex', alignItems: 'flex-start', justifyContent: 'space-around',
      padding: '8px 0 0', paddingBottom: 'env(safe-area-inset-bottom)',
    }}>
      {list.map((it, i) => (
        <div key={i} style={{
          flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
          color: i === active ? TFC.text : TFC.textSec,
        }}>
          <NavIcon kind={it.kind} />
          <div style={{ fontSize: 11, fontWeight: i === active ? 500 : 400, lineHeight: 1, marginTop: 4 }}>{it.label}</div>
          <div style={{
            width: 18, height: 3, borderRadius: 2, marginTop: 4,
            background: i === active ? TFC.primary : 'transparent',
          }} />
        </div>
      ))}
    </div>
  );
};

// --- Top app bar --------------------------------------------------------

const AppBar = ({ title, bn, leading, trailing, sub }) => (
  <div style={{ padding: '14px 16px 8px', display: 'flex', alignItems: 'flex-start', gap: 12 }}>
    {leading}
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span style={{ fontSize: 22, color: TFC.text, fontWeight: 600, letterSpacing: -0.3, lineHeight: 1.1 }}>{title}</span>
        {bn && <span style={{ fontSize: 13, color: TFC.textSec, fontFamily: '"Hind Siliguri", sans-serif' }}>{bn}</span>}
      </div>
      {sub && <div style={{ fontSize: 12, color: TFC.textSec, marginTop: 4 }}>{sub}</div>}
    </div>
    {trailing && <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>{trailing}</div>}
  </div>
);

const IconBtn = ({ children, badge, dark }) => (
  <div style={{
    width: 38, height: 38, borderRadius: 10,
    background: dark ? TFC.dark : TFC.paper,
    color: dark ? '#FFF' : TFC.text,
    border: `0.5px solid ${dark ? TFC.dark : TFC.border}`,
    display: 'grid', placeItems: 'center', position: 'relative',
  }}>
    {children}
    {badge != null && (
      <div style={{
        position: 'absolute', top: -4, right: -4, minWidth: 18, height: 18, padding: '0 4px',
        borderRadius: 9, background: TFC.redText, color: '#FFF',
        fontSize: 10, fontWeight: 600, display: 'grid', placeItems: 'center',
        border: `1.5px solid ${TFC.paper}`,
      }}>{badge}</div>
    )}
  </div>
);

// --- Tweaks plumbing ----------------------------------------------------
// Cross-file shared tweak state so any screen can read the current layout / palette.
// Components subscribe via useTweakState(); App writes via window.__setTfTweaks.

const TfTweaksContext = React.createContext({
  menu_layout: 'list',
  brand: 'amber',
  mood: 'warm',
});
const useTfTweaks = () => React.useContext(TfTweaksContext);

// expose
Object.assign(window, {
  TF, TFC, Phone, StatusBar, Logo, Btn, Field, Chip, Card, StatCard, Status,
  NavIcon, BottomNav, AppBar, IconBtn, TfTweaksContext, useTfTweaks,
});
