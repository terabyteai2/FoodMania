// Terafoods · Computer OS — desktop shell (Windows laptop POS)
// ============================================================================
// Phase 1 FOH foundation + Phase 2 essential analytics.
// Frame: 1366×820 (Windows 10/11, 1366×768 minimum + window chrome).
// Layout adapter: left nav rail 72px (icons only) — labels appear on hover.
// Tokens borrowed from DASH (mobile shared) so brand stays consistent.

const PC = {
  W: 1366,
  H: 820,
  RAIL: 72,
  TOPBAR: 56,
  CHROME: 36,
  C: DASH, // alias
};

// ────────────────────────────────────────────────────────────────
// Window chrome — Windows-11-style titlebar + the live app inside.
// Single neutral wrapper around every desktop screen so the
// design canvas reads as a real laptop app, not a web page.
// ────────────────────────────────────────────────────────────────
const PcWindow = ({ children, title, sub }) => (
  <div style={{
    width: PC.W, height: PC.H, background: '#E7E4ED', borderRadius: 8,
    boxShadow: '0 24px 60px rgba(22,16,30,0.18), 0 0 0 1px rgba(22,16,30,0.08)',
    fontFamily: PC.C.font, color: PC.C.text, overflow: 'hidden',
    display: 'flex', flexDirection: 'column',
  }}>
    {/* titlebar */}
    <div style={{
      height: PC.CHROME, background: '#F4F2F8', borderBottom: `1px solid ${PC.C.border}`,
      display: 'flex', alignItems: 'center', padding: '0 12px', gap: 10, flexShrink: 0,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <PcBrandDot />
        <span style={{ fontSize: 12, fontWeight: 600, color: PC.C.text, letterSpacing: -0.1 }}>
          Terafoods POS
        </span>
        {title && <>
          <span style={{ fontSize: 11, color: PC.C.textTer }}>·</span>
          <span style={{ fontSize: 12, color: PC.C.textSec }}>{title}</span>
        </>}
        {sub && <span style={{ fontSize: 11, color: PC.C.textTer, marginLeft: 4 }}>{sub}</span>}
      </div>
      <div style={{ flex: 1 }} />
      <span style={{ fontSize: 10.5, fontFamily: PC.C.mono, color: PC.C.textTer, fontWeight: 600, letterSpacing: 0.5 }}>
        Cha Ghor · Counter 1
      </span>
      <div style={{ width: 14 }} />
      {[
        <path key="m" d="M2 6h8" stroke="currentColor" strokeWidth="1" />,
        <path key="x" d="M2 2h8v8H2z" fill="none" stroke="currentColor" strokeWidth="1" />,
        <path key="c" d="M2 2l8 8M10 2L2 10" stroke="currentColor" strokeWidth="1" />,
      ].map((p, i) => (
        <div key={i} style={{
          width: 32, height: PC.CHROME, display: 'grid', placeItems: 'center',
          color: i === 2 ? PC.C.text : PC.C.textSec, cursor: 'pointer',
        }}>
          <svg width="12" height="12" viewBox="0 0 12 12">{p}</svg>
        </div>
      ))}
    </div>
    {/* app body */}
    <div style={{ flex: 1, minHeight: 0, display: 'flex', background: PC.C.bg }}>
      {children}
    </div>
  </div>
);

const PcBrandDot = () => (
  <div style={{
    width: 16, height: 16, borderRadius: 4, background: PC.C.accent,
    display: 'grid', placeItems: 'center', color: PC.C.accentInk,
  }}>
    <svg width="10" height="10" viewBox="0 0 16 16" fill="none">
      <path d="M5 2v5a2 2 0 0 0 2 2v5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
      <path d="M7 2v5a2 2 0 0 1-2 2" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
      <circle cx="11" cy="8" r="4" stroke="currentColor" strokeWidth="1.6" />
      <circle cx="11" cy="8" r="1.5" fill="currentColor" />
    </svg>
  </div>
);

// ────────────────────────────────────────────────────────────────
// Left navigation rail — 72px collapsed (icons-only, the default).
// Top section: section nav. Bottom: settings + cashier avatar.
// ────────────────────────────────────────────────────────────────
const PC_NAV = [
  { id: 'counter', kind: 'shop', label: 'Counter', sk: 'F1' },
  { id: 'floor', kind: 'people', label: 'Dine-in', sk: 'F2' },
  { id: 'orders', kind: 'orders', label: 'Orders', sk: 'F3' },
  { id: 'menu', kind: 'menu', label: 'Menu', sk: 'F4' },
  { id: 'stock', kind: 'inventory', label: 'Stock', sk: 'F5' },
  { id: 'reports', kind: 'chart', label: 'Reports', sk: 'F6' },
];

const PcRail = ({ active = 'counter' }) => (
  <div style={{
    width: PC.RAIL, flexShrink: 0, background: PC.C.surface,
    borderRight: `1px solid ${PC.C.border}`,
    display: 'flex', flexDirection: 'column', padding: '12px 0',
  }}>
    <div style={{ padding: '4px 0 14px', display: 'grid', placeItems: 'center' }}>
      <PcBrandDot />
    </div>
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2, padding: '0 10px' }}>
      {PC_NAV.map(n => (
        <PcRailItem key={n.id} kind={n.kind} label={n.label} sk={n.sk} active={n.id === active} />
      ))}
    </div>
    <div style={{ padding: '0 10px', display: 'flex', flexDirection: 'column', gap: 2, marginTop: 8 }}>
      <PcRailItem kind="bell" label="Alerts" badge="3" />
      <PcRailItem kind="settings" label="Settings" />
      <div style={{ height: 1, background: PC.C.border, margin: '8px 4px' }} />
      <div style={{
        width: 40, height: 40, borderRadius: 10, background: PC.C.accent, color: PC.C.accentInk,
        display: 'grid', placeItems: 'center', fontSize: 13, fontWeight: 700,
        margin: '0 auto',
      }}>RH</div>
    </div>
  </div>
);

const PcRailItem = ({ kind, label, sk, active, badge }) => (
  <div style={{
    height: 52, borderRadius: 10, position: 'relative',
    background: active ? PC.C.accentSoft : 'transparent',
    color: active ? PC.C.accent : PC.C.textSec,
    display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2,
  }}>
    {active && (
      <span style={{ position: 'absolute', left: -10, top: 14, bottom: 14, width: 3, borderRadius: 2, background: PC.C.accent }} />
    )}
    <div style={{ position: 'relative' }}>
      <NavIcon kind={kind} />
      {badge && (
        <span style={{
          position: 'absolute', top: -4, right: -8, minWidth: 16, height: 16, padding: '0 4px',
          borderRadius: 8, background: PC.C.late, color: '#FFF', fontSize: 9.5, fontWeight: 700,
          display: 'grid', placeItems: 'center', border: `1.5px solid ${PC.C.surface}`,
        }}>{badge}</span>
      )}
    </div>
    <span style={{ fontSize: 9.5, fontWeight: active ? 700 : 500, letterSpacing: 0.1 }}>{label}</span>
    {sk && <span style={{
      position: 'absolute', top: 6, right: 6,
      fontSize: 8.5, fontFamily: PC.C.mono, fontWeight: 600,
      color: active ? PC.C.accent : PC.C.textTer, letterSpacing: 0.4, opacity: 0.7,
    }}>{sk}</span>}
  </div>
);

// ────────────────────────────────────────────────────────────────
// Top bar — section title (left), search (center), status pills (right).
// "Status pills" carry the desktop-critical context:
//   · offline indicator (the app works offline; surface it always)
//   · EN/BN toggle (required by spec)
//   · printer status (cheap thermals are flaky; surface always)
//   · drawer status (open / closed) + active shift clock
// ────────────────────────────────────────────────────────────────
const PcTopBar = ({ title, sub, search = 'Scan barcode or search items   F8', actions, tools = ['offline','bn','printer','drawer','shift'] }) => (
  <div style={{
    height: PC.TOPBAR, flexShrink: 0, background: PC.C.surface,
    borderBottom: `1px solid ${PC.C.border}`,
    display: 'flex', alignItems: 'center', padding: '0 18px', gap: 18,
  }}>
    <div style={{ minWidth: 0 }}>
      <div style={{ fontSize: 17, fontWeight: 700, color: PC.C.text, letterSpacing: -0.3, lineHeight: 1 }}>{title}</div>
      {sub && <div style={{ fontSize: 11.5, color: PC.C.textSec, marginTop: 3 }}>{sub}</div>}
    </div>
    <div style={{ flex: 1, maxWidth: 460, marginLeft: 'auto' }}>
      <div style={{
        height: 36, borderRadius: 8, background: PC.C.surfaceAlt,
        border: `1px solid ${PC.C.border}`,
        display: 'flex', alignItems: 'center', gap: 10, padding: '0 12px',
      }}>
        <span style={{ color: PC.C.textTer }}><NavIcon kind="search" /></span>
        <span style={{ flex: 1, fontSize: 13, color: PC.C.textTer }}>{search}</span>
        <span style={{
          padding: '2px 6px', borderRadius: 4, background: PC.C.surface,
          border: `1px solid ${PC.C.border}`, fontSize: 10,
          fontFamily: PC.C.mono, fontWeight: 600, color: PC.C.textSec, letterSpacing: 0.4,
        }}>Ctrl+K</span>
      </div>
    </div>
    {actions && <div style={{ display: 'flex', gap: 8 }}>{actions}</div>}
    <PcStatusPills only={tools} />
  </div>
);

const PcStatusPills = ({ only }) => {
  const all = {
    offline: <PcPill key="o" tone="warn" dot icon="wifi">Offline · synced 12m ago</PcPill>,
    bn:      <PcLangToggle key="l" />,
    printer: <PcPill key="p" tone="good" dot icon="printer">RP-80 ready</PcPill>,
    drawer:  <PcPill key="d" tone="muted" dot icon="shop">Drawer open</PcPill>,
    shift:   <PcPill key="s" tone="muted" icon="clock">Shift · 03:42:18</PcPill>,
  };
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      {only.map(k => all[k])}
    </div>
  );
};

const PcPill = ({ children, tone = 'muted', dot, icon }) => {
  const t = {
    good:  { bg: PC.C.goodSoft, color: PC.C.good, dot: PC.C.good },
    warn:  { bg: PC.C.warnSoft, color: PC.C.warn, dot: PC.C.warn },
    bad:   { bg: PC.C.dangerSoft, color: PC.C.danger, dot: PC.C.danger },
    muted: { bg: PC.C.surfaceAlt, color: PC.C.text, dot: PC.C.textTer },
    accent:{ bg: PC.C.accentSoft, color: PC.C.accent, dot: PC.C.accent },
  }[tone];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '5px 10px', borderRadius: 999, background: t.bg, color: t.color,
      fontSize: 11.5, fontWeight: 600, fontFamily: PC.C.mono, letterSpacing: 0.1,
      ...PC.C.num,
    }}>
      {dot && <span style={{ width: 6, height: 6, borderRadius: 3, background: t.dot }} />}
      {icon && <NavIcon kind={icon} />}
      {children}
    </span>
  );
};

const PcLangToggle = () => (
  <div style={{
    display: 'inline-flex', background: PC.C.surfaceAlt, borderRadius: 7, padding: 2,
    border: `1px solid ${PC.C.border}`,
  }}>
    {[['EN', true], ['বাং', false]].map(([t, on], i) => (
      <span key={i} style={{
        padding: '4px 10px', borderRadius: 5,
        background: on ? PC.C.surface : 'transparent',
        color: on ? PC.C.text : PC.C.textSec,
        border: on ? `1px solid ${PC.C.borderStrong}` : '1px solid transparent',
        fontSize: 11.5, fontWeight: 600,
        fontFamily: on && t !== 'EN' ? PC.C.bn : PC.C.font,
      }}>{t}</span>
    ))}
  </div>
);

// ────────────────────────────────────────────────────────────────
// Button — desktop sizing (32 / 40 / 48). Always shows keyboard
// shortcut hint on the right when given. Tight 8px radius.
// ────────────────────────────────────────────────────────────────
const PcBtn = ({ children, variant = 'primary', size = 'md', icon, sk, full, style }) => {
  const s = { sm: { h: 28, fs: 12, px: 10, r: 6 }, md: { h: 36, fs: 13, px: 14, r: 7 }, lg: { h: 44, fs: 14.5, px: 18, r: 8 }, xl: { h: 56, fs: 16, px: 22, r: 10 } }[size];
  const v = {
    primary: { bg: PC.C.accent, color: PC.C.accentInk, border: PC.C.accent },
    dark:    { bg: PC.C.ink, color: PC.C.onInk, border: PC.C.ink },
    ghost:   { bg: 'transparent', color: PC.C.text, border: PC.C.borderStrong },
    surface: { bg: PC.C.surface, color: PC.C.text, border: PC.C.border },
    good:    { bg: PC.C.good, color: '#fff', border: PC.C.good },
    danger:  { bg: PC.C.danger, color: '#fff', border: PC.C.danger },
  }[variant];
  return (
    <div style={{
      height: s.h, padding: `0 ${s.px}px`, background: v.bg, color: v.color,
      border: `1px solid ${v.border}`, borderRadius: s.r,
      fontSize: s.fs, fontWeight: 600, letterSpacing: -0.1,
      display: 'inline-flex', alignItems: 'center', gap: 8, whiteSpace: 'nowrap',
      width: full ? '100%' : undefined, justifyContent: 'center', boxSizing: 'border-box',
      ...style,
    }}>
      {icon && <NavIcon kind={icon} />}
      <span>{children}</span>
      {sk && (
        <span style={{
          marginLeft: 6, padding: '1px 6px', borderRadius: 4,
          background: variant === 'primary' || variant === 'dark' || variant === 'good' || variant === 'danger' ? 'rgba(255,255,255,0.18)' : PC.C.surfaceAlt,
          fontSize: 10, fontFamily: PC.C.mono, fontWeight: 700, letterSpacing: 0.4,
          color: variant === 'primary' || variant === 'dark' || variant === 'good' || variant === 'danger' ? 'rgba(255,255,255,0.95)' : PC.C.textSec,
        }}>{sk}</span>
      )}
    </div>
  );
};

// ────────────────────────────────────────────────────────────────
// Card + section header — desktop sizing.
// ────────────────────────────────────────────────────────────────
const PcCard = ({ children, style, pad = 16 }) => (
  <div style={{
    background: PC.C.surface, border: `1px solid ${PC.C.border}`,
    borderRadius: 12, padding: pad, boxSizing: 'border-box',
    boxShadow: PC.C.shadowSoft, ...style,
  }}>{children}</div>
);

const PcEyebrow = ({ children, color }) => (
  <div style={{
    fontSize: 10.5, fontFamily: PC.C.mono, fontWeight: 700,
    color: color || PC.C.textSec, letterSpacing: 0.7, textTransform: 'uppercase',
  }}>{children}</div>
);

const PcSectionHead = ({ title, sub, right }) => (
  <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12, marginBottom: 12 }}>
    <div>
      <div style={{ fontSize: 14.5, fontWeight: 700, color: PC.C.text, letterSpacing: -0.2 }}>{title}</div>
      {sub && <div style={{ fontSize: 11.5, color: PC.C.textSec, marginTop: 2 }}>{sub}</div>}
    </div>
    {right}
  </div>
);

const PcKpi = ({ label, value, sub, delta, deltaUp, tone, spark, sparkPts }) => (
  <PcCard pad={14} style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
      <PcEyebrow>{label}</PcEyebrow>
      {delta && (
        <span style={{
          display: 'inline-flex', alignItems: 'center', gap: 3,
          fontSize: 11, fontWeight: 700, padding: '2px 7px', borderRadius: 4,
          background: deltaUp ? PC.C.goodSoft : PC.C.dangerSoft,
          color: deltaUp ? PC.C.good : PC.C.danger, ...PC.C.num,
        }}>{deltaUp ? '↑' : '↓'} {delta}</span>
      )}
    </div>
    <div style={{
      fontSize: 30, fontWeight: 700, color: tone === 'late' ? PC.C.late : PC.C.ink,
      marginTop: 10, letterSpacing: '-0.025em', lineHeight: 1, ...PC.C.num,
    }}>{value}</div>
    {sub && <div style={{ fontSize: 11.5, color: PC.C.textSec, marginTop: 8, ...PC.C.num }}>{sub}</div>}
    {spark && <div style={{ marginTop: 12 }}><PcSpark height={36} points={sparkPts} /></div>}
  </PcCard>
);

// Tiny desktop sparkline
const PcSpark = ({ points, height = 40, accent, fill }) => {
  const pts = points || [0.2, 0.32, 0.28, 0.45, 0.4, 0.62, 0.58, 0.7, 0.68, 0.84, 0.9, 1.0];
  const w = 240, padX = 2, padY = 4;
  const innerW = w - padX * 2, innerH = height - padY * 2;
  const dx = innerW / (pts.length - 1);
  const xs = pts.map((_, i) => padX + i * dx);
  const ys = pts.map(p => padY + innerH - p * innerH);
  const d = pts.map((_, i) => {
    if (i === 0) return `M${xs[i]},${ys[i]}`;
    const cx = xs[i - 1] + (xs[i] - xs[i - 1]) / 2;
    return `C${cx},${ys[i - 1]} ${cx},${ys[i]} ${xs[i]},${ys[i]}`;
  }).join(' ');
  const col = accent || PC.C.accent;
  return (
    <svg width="100%" height={height} viewBox={`0 0 ${w} ${height}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {fill && <path d={`${d} L${xs[xs.length - 1]},${height} L${xs[0]},${height} Z`} fill={col} opacity="0.10" />}
      <path d={d} fill="none" stroke={col} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={xs[xs.length - 1]} cy={ys[ys.length - 1]} r="3" fill={PC.C.surface} stroke={col} strokeWidth="1.6" />
    </svg>
  );
};

// ────────────────────────────────────────────────────────────────
// Footer bar — keyboard hints across the bottom (28px).
// Reinforces that this is a keyboard-driven desktop app.
// ────────────────────────────────────────────────────────────────
const PcFooter = ({ hints }) => (
  <div style={{
    height: 28, flexShrink: 0, background: PC.C.surface,
    borderTop: `1px solid ${PC.C.border}`,
    display: 'flex', alignItems: 'center', padding: '0 18px', gap: 18,
    fontSize: 11, color: PC.C.textSec, fontFamily: PC.C.mono, fontWeight: 600,
  }}>
    {hints.map((h, i) => (
      <span key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
        <span style={{
          padding: '1px 5px', borderRadius: 3, background: PC.C.surfaceAlt,
          border: `1px solid ${PC.C.border}`, color: PC.C.text,
          fontSize: 10, letterSpacing: 0.4,
        }}>{h.k}</span>
        <span>{h.l}</span>
      </span>
    ))}
    <div style={{ flex: 1 }} />
    <span>v2.4.1 · Rashed Hossain · Mon 2 Jun</span>
  </div>
);

// ────────────────────────────────────────────────────────────────
// Generic shell wrapper: rail + (topbar + content + footer).
// Most screens just wrap their main pane in this and pass children.
// ────────────────────────────────────────────────────────────────
const PcShell = ({ activeNav, title, sub, topActions, statusTools, footerHints, children, chromeTitle, chromeSub }) => (
  <PcWindow title={chromeTitle} sub={chromeSub}>
    <PcRail active={activeNav} />
    <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
      <PcTopBar title={title} sub={sub} actions={topActions} tools={statusTools || ['offline','bn','printer','drawer','shift']} />
      <div style={{ flex: 1, minHeight: 0, display: 'flex', background: PC.C.bg }}>
        {children}
      </div>
      <PcFooter hints={footerHints || [
        { k: 'F1', l: 'Counter' }, { k: 'F2', l: 'Tables' }, { k: 'F8', l: 'Search' },
        { k: 'Ctrl+P', l: 'Print' }, { k: 'Ctrl+S', l: 'Save' }, { k: 'Esc', l: 'Cancel' },
      ]} />
    </div>
  </PcWindow>
);

// expose
Object.assign(window, {
  PC, PcWindow, PcRail, PcTopBar, PcPill, PcLangToggle, PcBtn, PcCard,
  PcEyebrow, PcSectionHead, PcKpi, PcSpark, PcFooter, PcShell, PcStatusPills,
});
