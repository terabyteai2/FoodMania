/* ============================================================
   Bytes POS — shared primitives, icons, logo, phone frame
   ============================================================ */
const { useState, useRef, useEffect, useMemo, createContext, useContext } = React;

const TK = '\u09F3'; // ৳ Bangladeshi Taka
const money = (n) => TK + Math.round(n).toLocaleString('en-US');
const money1 = (n) => TK + (Math.round(n * 10) / 10).toLocaleString('en-US');
const kfmt = (n) => n >= 1000 ? (Math.round(n / 100) / 10).toLocaleString() + 'k' : ('' + Math.round(n));

/* ---------- icons (1.8 stroke line) ---------- */
const PATHS = {
  search:'M11 11l4 4 M7.5 13a5.5 5.5 0 100-11 5.5 5.5 0 000 11z',
  plus:'M10 4v12 M4 10h12', minus:'M4 10h12',
  back:'M12 4l-6 6 6 6', fwd:'M8 4l6 6-6 6', chev:'M7 4l6 6-6 6', chevd:'M5 8l5 5 5-5', chevu:'M5 12l5-5 5 5',
  check:'M4 10.5l4 4 8-9', x:'M5 5l10 10 M15 5L5 15',
  receipt:'M5 2.5h10v15l-2.2-1.4L10.5 17 8 16.1 5.5 17 5 2.5z M8 6.5h4 M8 9.5h4',
  bag:'M6 6V5a4 4 0 018 0v1 M4 6h12l-.8 11H4.8L4 6z',
  grid:'M3 3h6v6H3z M11 3h6v6h-6z M3 11h6v6H3z M11 11h6v6h-6z',
  table:'M3 7h14 M5 7v3a2 2 0 002 2h6a2 2 0 002-2V7 M7 12v4 M13 12v4',
  box:'M10 2.5l7 3.8v7.4l-7 3.8-7-3.8V6.3l7-3.8z M3.2 6.3L10 10l6.8-3.7 M10 10v7.5',
  boxin:'M10 2v7 M7 6.5l3 3 3-3 M3.5 11.5v4a1 1 0 001 1h11a1 1 0 001-1v-4',
  chart:'M3 17h14 M6 17V9 M10 17V4 M14 17v-6',
  tower:'M10 9.5a2 2 0 100-4 2 2 0 000 4z M5.5 3a6.4 6.4 0 000 9 M14.5 3a6.4 6.4 0 010 9 M3 1.2a9 9 0 000 12.6 M17 1.2a9 9 0 010 12.6 M10 9.5l-2 8 M10 9.5l2 8 M8 15h4',
  settings:'M10 7.2a2.8 2.8 0 100 5.6 2.8 2.8 0 000-5.6z M10 1.8l1.2 2 2.3-.4.6 2.3 2 1.2-1 2.1 1 2.1-2 1.2-.6 2.3-2.3-.4L10 18.2l-1.2-2-2.3.4-.6-2.3-2-1.2 1-2.1-1-2.1 2-1.2.6-2.3 2.3.4L10 1.8z',
  bolt:'M11 2L4 11h5l-1 7 7-9h-5l1-7z',
  clock:'M10 5.5v4.5l3 2 M10 2.5a7.5 7.5 0 100 15 7.5 7.5 0 000-15z',
  user:'M10 10a3 3 0 100-6 3 3 0 000 6z M4.5 17a5.5 5.5 0 0111 0',
  users:'M7.5 9a2.6 2.6 0 100-5.2 2.6 2.6 0 000 5.2z M2.8 16a4.7 4.7 0 019.4 0 M13 4a2.6 2.6 0 010 5 M14.2 16a4.7 4.7 0 00-2.2-3.9',
  trash:'M4 6h12 M8 6V4.5h4V6 M5.5 6l.7 10h7.6l.7-10 M8.5 9v4 M11.5 9v4',
  edit:'M12.5 3.5l4 4-9 9H3.5v-4l9-9z M11 5l4 4',
  printer:'M6 8V3h8v5 M6 14H4.5A1.5 1.5 0 013 12.5V9.5A1.5 1.5 0 014.5 8h11A1.5 1.5 0 0117 9.5v3a1.5 1.5 0 01-1.5 1.5H14 M6 12h8v5H6v-5z',
  camera:'M3 6.5h2.5L7 4.5h6l1.5 2H17a1 1 0 011 1v8a1 1 0 01-1 1H3a1 1 0 01-1-1v-8a1 1 0 011-1z M10 13.5a3 3 0 100-6 3 3 0 000 6z',
  sparkle:'M10 2.5l1.6 4.3L16 8.4l-4.4 1.6L10 14.3 8.4 10 4 8.4l4.4-1.6L10 2.5z M15.5 13l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7.7-1.8z',
  scan:'M3 7V5a2 2 0 012-2h2 M13 3h2a2 2 0 012 2v2 M17 13v2a2 2 0 01-2 2h-2 M7 17H5a2 2 0 01-2-2v-2 M3 10h14',
  qr:'M3 3h5v5H3z M12 3h5v5h-5z M3 12h5v5H3z M5 5h1v1H5z M14 5h1v1h-1z M5 14h1v1H5z M12 12h2v2h-2z M16 12v5 M12 16h2',
  globe:'M10 2.5a7.5 7.5 0 100 15 7.5 7.5 0 000-15z M2.5 10h15 M10 2.5c2.2 2 3.3 4.8 3.3 7.5S12.2 15.5 10 17.5 6.7 12.7 6.7 10 7.8 4.5 10 2.5z',
  chat:'M3 5.5A1.5 1.5 0 014.5 4h11A1.5 1.5 0 0117 5.5v6a1.5 1.5 0 01-1.5 1.5H8l-4 3v-3H4.5A1.5 1.5 0 013 11.5v-6z',
  store:'M3.5 8.5V16h13V8.5 M2.5 8.5L4 4h12l1.5 4.5a2 2 0 01-3.75 1 2 2 0 01-3.75 0 2 2 0 01-3.75 0 2 2 0 01-3.75-1z',
  bell:'M10 3a4.5 4.5 0 014.5 4.5c0 4 1.5 5 1.5 5H4s1.5-1 1.5-5A4.5 4.5 0 0110 3z M8.5 16a1.5 1.5 0 003 0',
  truck:'M2.5 5h9v8h-9z M11.5 8h3l2.5 2.5V13h-5.5 M5.5 16a1.6 1.6 0 100-3.2 1.6 1.6 0 000 3.2z M14 16a1.6 1.6 0 100-3.2 1.6 1.6 0 000 3.2z',
  card:'M3 6h14v8H3z M3 9h14', cash:'M2.5 5h15v9h-15z M10 12a2.5 2.5 0 100-5 2.5 2.5 0 000 5z',
  tag:'M3.2 3.2h6l7.6 7.6-6 6L3.2 9.2v-6z M6.5 6.5h.01',
  note:'M4 3h9l3 3v11H4V3z M7 8h6 M7 11h6 M7 14h3',
  dots:'M5 10h.01 M10 10h.01 M15 10h.01', dotsv:'M10 5h.01 M10 10h.01 M10 15h.01',
  wifi:'M2 6.5a11 11 0 0116 0 M5 9.5a7 7 0 0110 0 M8 12.5a3 3 0 014 0 M10 15.3h.01',
  arrowr:'M4 10h12 M11 5l5 5-5 5', arrowu:'M10 16V4 M5 9l5-5 5 5', arrowd:'M10 4v12 M5 11l5 5 5-5',
  trendup:'M3 14l4.5-5 3 3L17 6 M13 6h4v4', trenddn:'M3 6l4.5 5 3-3L17 14 M13 14h4v-4',
  filter:'M3 5h14 M5.5 10h9 M8 15h4', sort:'M5 7l3-3 3 3 M8 4v12 M15 13l-3 3-3-3 M12 16V4',
  list:'M6 5h11 M6 10h11 M6 15h11 M3 5h.01 M3 10h.01 M3 15h.01',
  count:'M4 5l1.5 1.5L8 4 M4 10l1.5 1.5L8 9 M4 15l1.5 1.5L8 14 M11 5h6 M11 10h6 M11 15h6',
  check2:'M5 10l3.5 3.5L16 6', warn:'M10 3l8 14H2L10 3z M10 8v4 M10 15h.01',
  pin:'M10 2.5c3.3 0 5.5 2.4 5.5 5.4 0 3.7-5.5 9.6-5.5 9.6S4.5 11.6 4.5 7.9C4.5 4.9 6.7 2.5 10 2.5z M10 10a2 2 0 100-4 2 2 0 000 4z',
  phone:'M5 3h3l1.5 4-2 1.5a9 9 0 004 4l1.5-2 4 1.5v3a1.5 1.5 0 01-1.6 1.5C8 19.5 1 12.5.5 5.1A1.5 1.5 0 012 3.5',
  star:'M10 2.5l2.2 4.6 5 .7-3.6 3.5.9 5L10 13.9 5.5 16.3l.9-5L2.8 7.8l5-.7L10 2.5z',
  flame:'M10 17c3.3 0 5.5-2.4 5.5-5.4 0-2-1-3.6-2.2-5C12 5 11.4 3.4 11.4 2c-1.6 1-2.4 2.6-2.4 4.2 0 .8.2 1.5.5 2.2-1.6-.4-2.4-1.8-2.4-1.8-.7 1-1.6 2.6-1.6 4.6C5.5 14.4 6.7 17 10 17z',
  burger:'M4 12h12 M4 9.5h12 M5 7c0-1.8 2.2-3 5-3s5 1.2 5 3 M4.5 12c0 2 1.5 3.5 3 3.5h5c1.5 0 3-1.5 3-3.5',
  pizza:'M10 3.5L3 16l7-1.5L17 16 10 3.5z M9 9.5h.01 M11.5 11.5h.01',
  fries:'M6 8l-.5-3.5 1.8-.3L8 8 M9.2 8l.3-4 1.9.1-.3 3.9 M12.5 8l1-3.3 1.8.5-1 2.8 M5 8h10l-1 8H6l-1-8z',
  drink:'M6 5h8l-1 12H7L6 5z M5.5 8h9 M10 2.5V5', rice:'M3.5 11h13c0 3.3-2.9 5.5-6.5 5.5S3.5 14.3 3.5 11z M6 11c0-2 1.8-3.5 4-3.5s4 1.5 4 3.5 M8 5.5c0-1 .9-1.8 2-1.8s2 .8 2 1.8',
  kebab:'M10 2.5v15 M7 6a3 3 0 016 0 6 6 0 01-6 0z M7 11a3 3 0 016 0 6 6 0 01-6 0z',
  salad:'M4 9h12c0 3.5-2.7 6.5-6 6.5S4 12.5 4 9z M8 6.5c0-1 1-2 2-2s2 1 2 2 M6.5 8.5c-.5-1 0-2.5 1-3',
  dessert:'M5 8a5 5 0 0110 0z M5 8h10 M6.5 8l1 8h5l1-8 M10 4.5V2.5',
  history:'M10.5 5.5v4.5l3 1.8 M3.5 10a6.5 6.5 0 112.2 4.9 M3.5 10H6 M3.5 10V7.5',
  download:'M10 3v9 M6 8.5l4 4 4-4 M4 16h12', coins:'M7 8.5a4 2.2 0 108 0 4 2.2 0 10-8 0z M7 8.5v3.5a4 2.2 0 008 0V8.5 M5 5.5a4 2 0 108 0',
  refresh:'M16 5v4h-4 M15.5 9a6 6 0 10-1.5 5.5', open:'M5 5h6 M5 5v6 M5 5l9 9 M14 9v5h-5',
  taka:'M5 7.5h4 M9 5v8c0 1.5 1 2.5 2.5 2.5 M5 11h7',
  bot:'M6 7.5h8a1.5 1.5 0 011.5 1.5v4a1.5 1.5 0 01-1.5 1.5H6a1.5 1.5 0 01-1.5-1.5V9A1.5 1.5 0 016 7.5z M10 4.5v3 M10 3.6a.9.9 0 100-.01 M8 10.5h.01 M12 10.5h.01 M2.5 10v2.5 M17.5 10v2.5 M8.5 13.5h3',
  send:'M3.5 10L17 3.5 11 17l-2.2-5.3L3.5 10z',
  image:'M3.5 4h13v12h-13z M3.5 13l4-4 3 3 3-3.5 3 3.5 M7 8a1 1 0 100-2 1 1 0 000 2z',
  reply:'M8 5L3 10l5 5 M3 10h8a5 5 0 015 5v1',
  taka2:'M5 7.5h4 M9 5v8c0 1.5 1 2.5 2.5 2.5 M5 11h7',
  shield:'M10 2.5l6 2.2v4.6c0 4-2.7 6.6-6 8.2-3.3-1.6-6-4.2-6-8.2V4.7l6-2.2z M7.5 10l1.8 1.8L13 8',
  userplus:'M8.5 10a3 3 0 100-6 3 3 0 000 6z M3 17a5.5 5.5 0 0110-3.1 M15 11v5 M12.5 13.5h5',
  percent:'M6 6a1 1 0 100-.01 M14 14a1 1 0 100-.01 M5 15L15 5',
  palette:'M10 2.5a7.5 7.5 0 000 15c1.2 0 1.7-1 1.2-1.9-.6-1.1.2-2.3 1.5-2.3H15a3 3 0 003-3c0-4.3-3.6-7.8-8-7.8z M6.5 9a1 1 0 100-.01 M9 6.2a1 1 0 100-.01 M13 6.8a1 1 0 100-.01',
  link:'M8 12l4-4 M7.5 10.5l-1.6 1.6a2.6 2.6 0 003.7 3.7l1.6-1.6 M12.5 9.5l1.6-1.6a2.6 2.6 0 00-3.7-3.7L8.8 5.8',
  swap:'M5 7h10l-3-3 M15 13H5l3 3',
  variance:'M3 16h14 M5 16V8 M5 8l4 4 4-6 4 5',
  void:'M10 3.5a6.5 6.5 0 100 13 6.5 6.5 0 000-13z M5.6 5.6l8.8 8.8',
  language:'M3 5h7 M6.5 3.5V5 M5 5c0 3-1.2 5.5-3 6.5 M4.5 8.5c1 1.6 2.6 2.5 4 3 M11 16.5l3-7 3 7 M12 14h4',
};
function Icon({ name, size = 19, color = 'currentColor', sw = 1.8, fill = false, style }) {
  const d = PATHS[name] || '';
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none" style={{ display: 'block', flex: '0 0 auto', ...style }}>
      <path d={d} stroke={fill ? 'none' : color} fill={fill ? color : 'none'} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/* ---------- Bytes logo: lime rounded-square + ink bolt ---------- */
function Mark({ size = 30, radius }) {
  const r = radius != null ? radius : size * 0.26;
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" style={{ display: 'block' }}>
      <rect x="4" y="4" width="92" height="92" rx={r / size * 100} fill="#99FF47" />
      <path d="M56 21 L31 56 H46 L42 79 L69 42 H53 L58 21 Z" fill="#14180E" />
    </svg>
  );
}
function Wordmark({ size = 19, sub }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
      <Mark size={size * 1.75} />
      <div style={{ minWidth: 0 }}>
        <div style={{ fontSize: size, fontWeight: 800, letterSpacing: '-.03em', lineHeight: 1, color: 'var(--ink)', display: 'flex', alignItems: 'baseline', gap: 4 }}><span style={{ fontWeight: 600 }}>Quick</span><span>Bytes</span></div>
        {sub && <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 3, fontWeight: 500 }} className="ell">{sub}</div>}
      </div>
    </div>
  );
}

/* ---------- category visual ---------- */
const CAT_TINT = {
  Burgers:['#FBEFCD','#B0760A','burger'], Pizza:['#FBE3E2','#D43A3F','pizza'],
  'Rice & Curry':['#E4FBC9','#498F18','rice'], Kebab:['#FBE3E2','#B0760A','kebab'],
  Sides:['#E3EAFC','#3E6FE0','fries'], Salads:['#E4FBC9','#498F18','salad'],
  Beverages:['#E3EAFC','#3E6FE0','drink'], Desserts:['#FBEFCD','#B0760A','dessert'],
};
function Thumb({ cat, size = 52, ic }) {
  const [bg, fg, dic] = CAT_TINT[cat] || ['#ECEFE4', '#7C8270', 'bag'];
  return (
    <div className="thumb" style={{ width: size, height: size, flexBasis: size, background: bg }}>
      <Icon name={ic || dic} size={size * 0.5} color={fg} sw={1.6} />
    </div>
  );
}

/* ---------- channel meta ---------- */
const CHANNELS = {
  storefront:['globe', 'Website', '#3E6FE0', '#E3EAFC'],
  chatbot:['chat', 'Messenger', '#3E6FE0', '#E3EAFC'],
  waiter:['users', 'Waiter', '#7C8270', '#ECEFE4'],
  qr:['qr', 'Table QR', '#B0760A', '#FBEFCD'],
  counter:['store', 'Counter', '#498F18', '#E4FBC9'],
  manager:['user', 'Manager', '#14180E', '#ECEFE4'],
};

function Toggle({ on, onChange }) { return <div className={'toggle' + (on ? ' on' : '')} onClick={() => onChange(!on)}><div className="knob" /></div>; }
/* minimal Advanced switch — no description, just a label + toggle */
function AdvToggle({ on, onChange, label = 'Advanced' }) {
  return (
    <div onClick={() => onChange(!on)} style={{ display: 'inline-flex', alignItems: 'center', gap: 9, height: 34, padding: '0 6px 0 12px', borderRadius: 'var(--r-md)', border: '1px solid ' + (on ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: on ? 'var(--accent-tint)' : 'var(--surface)', cursor: 'pointer' }}>
      <span style={{ fontSize: 12.5, fontWeight: 700, color: on ? 'var(--accent-strong)' : 'var(--ink-2)' }}>{label}</span>
      <div className={'toggle' + (on ? ' on' : '')} style={{ width: 38, height: 22, flex: '0 0 38px' }}><div className="knob" style={{ width: 16, height: 16, top: 3, left: on ? 19 : 3 }} /></div>
    </div>
  );
}
function Qty({ value, onChange, min = 1 }) {
  return (
    <div className="qty">
      <button onClick={() => onChange(Math.max(min, value - 1))}><Icon name="minus" size={16} /></button>
      <span className="v tab">{value}</span>
      <button onClick={() => onChange(value + 1)}><Icon name="plus" size={16} /></button>
    </div>
  );
}
function Status({ kind, children }) { return <span className={'status ' + kind}><span className="dot" />{children}</span>; }

/* ---------- status bar ---------- */
function StatusBar() {
  return (
    <div style={{ height: 34, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 18px', position: 'relative', flex: '0 0 34px', background: 'var(--bg)' }}>
      <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink)' }} className="tab">7:42</span>
      <div style={{ position: 'absolute', left: '50%', top: 9, transform: 'translateX(-50%)', width: 9, height: 9, borderRadius: 9, background: '#0c0f09' }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--ink)' }}>
        <Icon name="wifi" size={15} sw={1.6} />
        <svg width="22" height="12" viewBox="0 0 22 12"><rect x="0.5" y="1.5" width="18" height="9" rx="2" stroke="currentColor" strokeWidth="1.2" fill="none" /><rect x="2" y="3" width="13" height="6" rx="1" fill="currentColor" /><rect x="20" y="4" width="1.5" height="4" rx="1" fill="currentColor" /></svg>
      </div>
    </div>
  );
}

/* ---------- phone frame ---------- */
function Phone({ children }) {
  return (
    <div style={{ position: 'fixed', inset: 0, background: '#E4E7DF', display: 'grid', placeItems: 'center', padding: '22px 0',
      backgroundImage: 'radial-gradient(120% 80% at 50% 0%, #EEF0EA 0%, #DADDD2 80%)' }}>
      <div style={{ position: 'relative', height: 'min(872px, calc(100vh - 36px))', width: 'calc(min(872px, calc(100vh - 36px)) * 410 / 872)', minWidth: 0, flex: '0 0 auto', background: '#11140d',
        borderRadius: 44, padding: 6, boxShadow: '0 30px 70px rgba(40,46,30,.28), 0 0 0 1px rgba(0,0,0,.04)' }}>
        <div className="bytes-root" style={{ position: 'relative', width: '100%', height: '100%', borderRadius: 37, overflow: 'hidden', background: 'var(--bg)', display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <StatusBar />
          <div style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>{children}</div>
          <div style={{ flex: '0 0 auto', height: 22, display: 'grid', placeItems: 'center', background: 'var(--surface)' }}>
            <div style={{ width: 120, height: 5, borderRadius: 3, background: 'var(--ink)', opacity: .26 }} />
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- top bar (shared, conditional) ----------
   One bar for every screen: brand variant on the Orders home,
   title (+ optional back) everywhere else. Right slot is a row
   of square 42px actions for visual coherence. */
function BarBtn({ icon, onClick, badge, accent, dot }) {
  return (
    <button onClick={onClick} style={{ position: 'relative', width: 42, height: 42, borderRadius: 10, border: '1px solid var(--line-2)', background: accent ? 'var(--accent)' : 'var(--surface)', display: 'grid', placeItems: 'center', cursor: 'pointer', color: accent ? 'var(--accent-ink)' : 'var(--ink)', flex: '0 0 42px' }}>
      <Icon name={icon} size={20} />
      {badge > 0 && <span className="tab" style={{ position: 'absolute', top: -5, right: -5, minWidth: 18, height: 18, padding: '0 5px', borderRadius: 9, background: 'var(--danger)', color: '#fff', fontSize: 10.5, fontWeight: 800, display: 'grid', placeItems: 'center', border: '2px solid var(--bg)' }}>{badge}</span>}
      {dot && !badge && <span style={{ position: 'absolute', top: 9, right: 10, width: 7, height: 7, borderRadius: '50%', background: 'var(--danger)', border: '1.5px solid var(--surface)' }} />}
    </button>
  );
}
function Header({ title, sub, onBack, right, big, brand }) {
  return (
    <div style={{ flex: '0 0 auto', padding: onBack ? '4px 14px 12px' : '6px 16px 12px', background: 'var(--bg)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 44 }}>
        {onBack && (
          <button onClick={onBack} style={{ width: 40, height: 40, marginLeft: -8, border: 'none', background: 'transparent', cursor: 'pointer', display: 'grid', placeItems: 'center', color: 'var(--ink)' }}><Icon name="back" size={22} sw={2} /></button>
        )}
        {brand ? (
          <div style={{ flex: 1, minWidth: 0 }}><Wordmark size={20} sub={sub} /></div>
        ) : (
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="ell" style={{ fontSize: big ? 26 : 22, fontWeight: 700, letterSpacing: '-.02em', color: 'var(--ink)' }}>{title}</div>
            {sub && <div className="ell" style={{ fontSize: 13, color: 'var(--muted)', marginTop: 1, fontWeight: 500 }}>{sub}</div>}
          </div>
        )}
        {right && <div style={{ display: 'flex', alignItems: 'center', gap: 8, flex: '0 0 auto' }}>{right}</div>}
      </div>
    </div>
  );
}

/* ---------- shared top-bar actions: messages + notifications ----------
   One component used across every home screen. Bell opens an in-app
   notification center (dropdown); messenger jumps to the inbox. */
const NOTIF_META = {
  pending: ['receipt', 'var(--accent-strong)', 'var(--accent-tint)'],
  escalation: ['chat', 'var(--warning)', 'var(--warning-soft)'],
  stock: ['box', 'var(--danger)', 'var(--danger-soft)'],
  table: ['table', 'var(--info)', 'var(--info-soft)'],
  shift: ['clock', 'var(--ink-2)', 'var(--surface-2)'],
};
function TopActions() {
  const b = useBytes();
  const [open, setOpen] = useState(false);
  const t = b.t;
  const escal = (b.chats || []).filter((c) => c.status === 'needs').length;
  const notifs = b.notifs || [];
  const unread = notifs.filter((n) => !n.read).length;
  return (
    <React.Fragment>
      <BarBtn icon="chat" badge={escal} onClick={() => b.go({ screen: 'messages' })} />
      <BarBtn icon="bell" badge={unread} onClick={() => setOpen((v) => !v)} />
      {open && (
        <React.Fragment>
          <div onClick={() => setOpen(false)} style={{ position: 'absolute', inset: 0, zIndex: 60, background: 'rgba(20,24,14,.18)' }} />
          <div style={{ position: 'absolute', top: 52, right: 12, left: 12, zIndex: 61, background: 'var(--surface)', borderRadius: 'var(--r-lg)', border: '1px solid var(--line-2)', boxShadow: 'var(--e3)', overflow: 'hidden' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '13px 15px 11px', borderBottom: '1px solid var(--line)' }}>
              <span style={{ fontSize: 15, fontWeight: 700 }}>{t('word.notifications')}</span>
              {unread > 0 && <button onClick={() => b.markNotifsRead()} style={{ border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 12.5, fontWeight: 600, color: 'var(--accent-strong)' }}>{t('word.markRead')}</button>}
            </div>
            <div className="scrollY noscroll" style={{ maxHeight: 360 }}>
              {notifs.length === 0 && <div style={{ padding: '32px 16px', textAlign: 'center', color: 'var(--muted)', fontSize: 13.5 }}>{t('word.noNotifs')}</div>}
              {notifs.map((n) => {
                const [ic, fg, bg] = NOTIF_META[n.type] || NOTIF_META.shift;
                return (
                  <div key={n.id} onClick={() => { b.markNotifRead(n.id); setOpen(false); if (n.route.screen) b.go(n.route); else if (n.route.tab) b.setTab(n.route.tab); }} style={{ display: 'flex', gap: 11, padding: '12px 15px', cursor: 'pointer', borderBottom: '1px solid var(--line)', background: n.read ? 'var(--surface)' : 'var(--bg)' }}>
                    <div style={{ width: 34, height: 34, borderRadius: 9, background: bg, color: fg, display: 'grid', placeItems: 'center', flex: '0 0 34px' }}><Icon name={ic} size={18} /></div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                        <span style={{ fontSize: 13.5, fontWeight: 700, flex: 1, minWidth: 0 }} className="ell">{n.title}</span>
                        <span style={{ fontSize: 11, color: 'var(--placeholder)', flex: '0 0 auto' }}>{n.mins < 60 ? n.mins + 'm' : Math.round(n.mins / 60) + 'h'}</span>
                      </div>
                      <div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 1 }} className="ell">{n.body}</div>
                    </div>
                    {!n.read && <span style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--accent-strong)', flex: '0 0 7px', marginTop: 6 }} />}
                  </div>
                );
              })}
            </div>
          </div>
        </React.Fragment>
      )}
    </React.Fragment>
  );
}
const NAV_BY_ROLE = {
  owner: [['analytics', 'nav.analytics', 'chart'], ['tables', 'nav.tables', 'table'], ['orders', 'nav.orders', 'receipt'], ['inventory', 'nav.stock', 'box'], ['more', 'nav.more', 'dots']],
  manager: [['tower', 'nav.tower', 'tower'], ['tables', 'nav.tables', 'table'], ['orders', 'nav.orders', 'receipt'], ['inventory', 'nav.stock', 'box'], ['more', 'nav.more', 'dots']],
  waiter: [['tables', 'nav.tables', 'table'], ['orders', 'nav.orders', 'receipt'], ['more', 'nav.more', 'dots']],
};
function TabBar({ tab, setTab, badge, role = 'manager', t = (k) => k }) {
  const tabs = NAV_BY_ROLE[role] || NAV_BY_ROLE.manager;
  return (
    <div style={{ flex: '0 0 auto', display: 'flex', borderTop: '1px solid var(--line)', background: 'var(--surface)' }}>
      {tabs.map(([id, key, ic]) => {
        const on = tab === id;
        return (
          <button key={id} onClick={() => setTab(id)} style={{ flex: 1, border: 'none', background: 'transparent', cursor: 'pointer', padding: '9px 0 8px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, color: on ? 'var(--ink)' : 'var(--muted)' }}>
            <div style={{ position: 'relative' }}>
              <div style={{ width: 46, height: 28, borderRadius: 8, background: on ? 'var(--accent)' : 'transparent', display: 'grid', placeItems: 'center', transition: 'background .12s' }}>
                <Icon name={ic} size={21} sw={on ? 2 : 1.7} color={on ? 'var(--accent-ink)' : 'currentColor'} />
              </div>
              {id === 'orders' && badge > 0 && (
                <span className="tab" style={{ position: 'absolute', top: -4, right: 2, minWidth: 16, height: 16, padding: '0 4px', borderRadius: 8, background: 'var(--danger)', color: '#fff', fontSize: 10, fontWeight: 700, display: 'grid', placeItems: 'center', border: '1.5px solid var(--surface)' }}>{badge}</span>
              )}
            </div>
            <span style={{ fontSize: 11, fontWeight: on ? 700 : 500 }}>{t(key)}</span>
          </button>
        );
      })}
    </div>
  );
}

function Sheet({ open, onClose, children }) {
  if (!open) return null;
  return (<React.Fragment><div className="scrim" onClick={onClose} /><div className="sheet"><div className="grab" />{children}</div></React.Fragment>);
}

Object.assign(window, {
  TK, money, money1, kfmt, Icon, Mark, Wordmark, Thumb, Toggle, AdvToggle, Qty, Status, StatusBar, Phone, Header, BarBtn, TopActions, TabBar, Sheet,
  CAT_TINT, CHANNELS, useState, useRef, useEffect, useMemo, createContext, useContext,
});
