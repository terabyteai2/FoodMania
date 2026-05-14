// Rastarant — design tokens + shared primitives
// Dark-first premium POS palette. Single source of truth.
// Exposed on window so other Babel script tags can use them.

const tokens = {
  // surfaces
  bg0: '#0F0E0C',         // app bg
  bg1: '#1A1815',         // cards
  bg2: '#25221E',         // raised / hover
  bg3: '#33302A',         // input
  hairline: '#2E2A24',
  hairlineHi: '#3A352D',
  // ink
  inkHi: '#F5F1E8',       // titles
  inkMid: '#A8A096',      // body
  inkLow: '#6B6359',      // caption
  inkInvert: '#0F0E0C',   // on-brand
  // brand
  brand: '#F2C744',       // refined yellow (down from #FFD928)
  brandDim: 'rgba(242,199,68,0.14)',
  brandRim: 'rgba(242,199,68,0.32)',
  // states
  success: '#6DAA6E',
  successDim: 'rgba(109,170,110,0.14)',
  danger: '#D8694F',
  dangerDim: 'rgba(216,105,79,0.14)',
  info: '#74A6D8',
};

const fontUI = "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
const fontBn = "'Hind Siliguri', Inter, sans-serif";
const fontMono = "'JetBrains Mono', ui-monospace, SFMono-Regular, monospace";

// ---------- Inline SVG icons (24px viewbox, stroke-based) ----------
const Icon = ({ name, size = 20, color = 'currentColor', strokeWidth = 1.75 }) => {
  const paths = {
    receipt: 'M5 3v18l2-1.5L9 21l2-1.5L13 21l2-1.5L17 21l2-1.5V3l-2 1.5L15 3l-2 1.5L11 3 9 4.5 7 3 5 4.5V3z M8 8h8 M8 12h8 M8 16h5',
    home: 'M3 11l9-8 9 8v10a1 1 0 0 1-1 1h-5v-7H10v7H4a1 1 0 0 1-1-1V11z',
    chart: 'M3 3v18h18 M7 15l3-5 4 3 5-8',
    menu: 'M4 6h16 M4 12h16 M4 18h10',
    book: 'M4 4h6a3 3 0 0 1 3 3v13a2 2 0 0 0-2-2H4V4z M20 4h-6a3 3 0 0 0-3 3v13a2 2 0 0 1 2-2h7V4z',
    settings: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9c.36.15.66.4.87.71',
    plus: 'M12 5v14 M5 12h14',
    search: 'M11 4a7 7 0 1 1-7 7 7 7 0 0 1 7-7z M21 21l-4.5-4.5',
    bell: 'M6 8a6 6 0 1 1 12 0c0 7 3 9 3 9H3s3-2 3-9z M10 21a2 2 0 0 0 4 0',
    check: 'M4 12l5 5L20 6',
    x: 'M6 6l12 12 M18 6L6 18',
    chevR: 'M9 6l6 6-6 6',
    chevD: 'M6 9l6 6 6-6',
    clock: 'M12 7v5l3 2 M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z',
    printer: 'M6 9V3h12v6 M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2 M6 14h12v7H6z',
    sync: 'M21 12a9 9 0 0 1-15.5 6.3L3 16 M3 12a9 9 0 0 1 15.5-6.3L21 8 M21 3v5h-5 M3 21v-5h5',
    user: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2 M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
    table: 'M3 9h18 M3 5h18v14H3z M9 9v10 M15 9v10',
    moon: 'M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z',
    flame: 'M12 2c1 4 5 5 5 10a5 5 0 0 1-10 0c0-3 2-4 2-7 2 1 3 2 3 4 1-1 1-4 0-7z',
    coin: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M12 7v10 M9 10c0-1.5 1.3-2 3-2s3 .8 3 2-1 2-3 2-3 .9-3 2 1.4 2 3 2 3-.5 3-2',
    bag: 'M6 7h12l-1 13H7L6 7z M9 7V5a3 3 0 0 1 6 0v2',
    truck: 'M1 7h13v10H1z M14 11h5l3 3v3h-8 M5 21a2 2 0 1 0 0-4 2 2 0 0 0 0 4z M17 21a2 2 0 1 0 0-4 2 2 0 0 0 0 4z',
    fork: 'M6 3v8a2 2 0 0 0 2 2v8 M10 3v8a2 2 0 0 1-2 2 M8 3v6 M16 3c-2 0-3 2-3 5s1 5 3 5v8',
    boxes: 'M3 7l9 4 9-4-9-4-9 4z M3 7v10l9 4 M21 7v10l-9 4 M12 11v10',
    filter: 'M3 5h18l-7 8v6l-4-2v-4L3 5z',
  };
  const d = paths[name];
  if (!d) return null;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke={color} strokeWidth={strokeWidth}
      strokeLinecap="round" strokeLinejoin="round">
      <path d={d} />
    </svg>
  );
};

// ---------- Atoms ----------

const Badge = ({ children, kind = 'neutral', size = 'sm' }) => {
  const map = {
    brand: { bg: tokens.brandDim, color: tokens.brand, border: tokens.brandRim },
    success: { bg: tokens.successDim, color: tokens.success, border: 'rgba(109,170,110,0.32)' },
    danger: { bg: tokens.dangerDim, color: tokens.danger, border: 'rgba(216,105,79,0.32)' },
    neutral: { bg: tokens.bg2, color: tokens.inkMid, border: tokens.hairline },
  };
  const k = map[kind];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      fontFamily: fontUI, fontSize: size === 'sm' ? 10 : 11, fontWeight: 600,
      letterSpacing: 0.6, textTransform: 'uppercase',
      padding: size === 'sm' ? '3px 7px' : '4px 9px',
      borderRadius: 999, background: k.bg, color: k.color,
      border: `1px solid ${k.border}`, whiteSpace: 'nowrap',
    }}>{children}</span>
  );
};

const Toggle = ({ on, onChange }) => (
  <button
    onClick={onChange}
    style={{
      width: 40, height: 24, borderRadius: 12,
      background: on ? tokens.brand : tokens.bg3,
      border: 'none', padding: 0, position: 'relative', cursor: 'pointer',
      transition: 'background .15s', flex: '0 0 auto',
    }}>
    <span style={{
      position: 'absolute', top: 2, left: on ? 18 : 2,
      width: 20, height: 20, borderRadius: 10,
      background: on ? tokens.inkInvert : tokens.inkHi,
      transition: 'left .15s, background .15s',
    }} />
  </button>
);

const IconBtn = ({ name, onClick, ariaLabel }) => (
  <button onClick={onClick} aria-label={ariaLabel}
    style={{
      width: 40, height: 40, borderRadius: 12,
      background: tokens.bg1, border: `1px solid ${tokens.hairline}`,
      color: tokens.inkHi, display: 'grid', placeItems: 'center',
      cursor: 'pointer', flex: '0 0 auto',
    }}>
    <Icon name={name} size={18} />
  </button>
);

// ---------- Phone shell ----------

const PHONE_W = 390;
const PHONE_H = 844;

const StatusBar = () => (
  <div style={{
    height: 44, padding: '0 22px',
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    color: tokens.inkHi, fontFamily: fontUI, fontSize: 15, fontWeight: 600,
    background: tokens.bg0,
  }}>
    <span>9:41</span>
    <div style={{
      width: 100, height: 24, borderRadius: 12, background: '#000',
    }} />
    <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
      {/* signal */}
      <svg width="17" height="11" viewBox="0 0 17 11" fill={tokens.inkHi}>
        <rect x="0" y="7" width="3" height="4" rx="1" />
        <rect x="4.5" y="5" width="3" height="6" rx="1" />
        <rect x="9" y="2" width="3" height="9" rx="1" />
        <rect x="13.5" y="0" width="3" height="11" rx="1" />
      </svg>
      {/* battery */}
      <svg width="26" height="12" viewBox="0 0 26 12">
        <rect x="0.5" y="0.5" width="22" height="11" rx="2.5" fill="none" stroke={tokens.inkHi} opacity="0.5" />
        <rect x="2" y="2" width="19" height="8" rx="1.5" fill={tokens.inkHi} />
        <rect x="23.5" y="4" width="1.5" height="4" rx="0.75" fill={tokens.inkHi} opacity="0.5" />
      </svg>
    </div>
  </div>
);

const HomeIndicator = () => (
  <div style={{
    height: 34, display: 'grid', placeItems: 'center', background: tokens.bg0,
  }}>
    <div style={{ width: 134, height: 5, borderRadius: 3, background: tokens.inkHi }} />
  </div>
);

const NAV = [
  { id: 'orders', label: 'Orders', bn: 'অর্ডার', icon: 'receipt' },
  { id: 'dashboard', label: 'Insights', bn: 'বিশ্লেষণ', icon: 'chart' },
  { id: 'menu', label: 'Menu', bn: 'মেনু', icon: 'book' },
  { id: 'settings', label: 'Settings', bn: 'সেটিংস', icon: 'settings' },
];

const BottomNav = ({ active, onChange }) => (
  <div style={{
    position: 'absolute', left: 0, right: 0, bottom: 34,
    background: tokens.bg0, borderTop: `1px solid ${tokens.hairline}`,
    padding: '10px 12px 14px',
    display: 'flex', justifyContent: 'space-around', alignItems: 'center',
  }}>
    {NAV.map((it) => {
      const isOn = it.id === active;
      return (
        <button key={it.id} onClick={() => onChange(it.id)} style={{
          background: isOn ? tokens.brand : 'transparent',
          color: isOn ? tokens.inkInvert : tokens.inkMid,
          border: 'none', padding: isOn ? '10px 18px' : '10px 14px',
          borderRadius: 999, cursor: 'pointer',
          display: 'flex', alignItems: 'center', gap: 8,
          minHeight: 48, transition: 'all .18s',
          fontFamily: fontUI, fontSize: 13, fontWeight: 600,
        }}>
          <Icon name={it.icon} size={20} />
          {isOn && <span>{it.label}</span>}
        </button>
      );
    })}
  </div>
);

const Phone = ({ children }) => (
  <div style={{
    width: PHONE_W + 16, height: PHONE_H + 16,
    background: '#0a0908', borderRadius: 52, padding: 8,
    boxShadow: '0 40px 100px rgba(0,0,0,0.5), 0 0 0 1px #1f1c18',
  }}>
    <div style={{
      width: PHONE_W, height: PHONE_H, borderRadius: 44, overflow: 'hidden',
      background: tokens.bg0, position: 'relative',
      fontFamily: fontUI, color: tokens.inkHi,
    }}>
      <StatusBar />
      {children}
      <HomeIndicator />
    </div>
  </div>
);

// Section header (small caps label)
const SectionLabel = ({ children, right }) => (
  <div style={{
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '0 20px', marginBottom: 10,
  }}>
    <div style={{
      fontFamily: fontUI, fontSize: 11, fontWeight: 600, letterSpacing: 1.2,
      textTransform: 'uppercase', color: tokens.inkLow,
    }}>{children}</div>
    {right}
  </div>
);

// Screen content scroll region
const ScreenScroll = ({ children, pb = 130 }) => (
  <div style={{
    position: 'absolute', top: 44, left: 0, right: 0, bottom: 34,
    overflowY: 'auto', paddingBottom: pb,
  }}>
    {children}
  </div>
);

// Page header (large title + optional right action)
const PageHeader = ({ title, sub, right }) => (
  <div style={{ padding: '14px 20px 18px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
    <div>
      <div style={{
        fontFamily: fontUI, fontSize: 30, fontWeight: 600, lineHeight: 1.05,
        color: tokens.inkHi, letterSpacing: -0.6,
      }}>{title}</div>
      {sub && <div style={{
        fontFamily: fontBn, fontSize: 13, color: tokens.inkMid, marginTop: 4,
      }}>{sub}</div>}
    </div>
    {right}
  </div>
);

Object.assign(window, {
  tokens, fontUI, fontBn, fontMono,
  Icon, Badge, Toggle, IconBtn,
  Phone, StatusBar, HomeIndicator, BottomNav, NAV,
  SectionLabel, ScreenScroll, PageHeader,
  PHONE_W, PHONE_H,
});
