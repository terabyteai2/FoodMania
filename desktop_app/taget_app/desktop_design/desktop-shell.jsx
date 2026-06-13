/* ============================================================
   QuickBytes Desktop — shell: scaling stage, nav rail, rail
   popovers (notifications · account/role · language), header.
   Reuses Icon/Mark/money from bytes-shared and the desk store
   (useDesk) defined in desktop-app.jsx.
   ============================================================ */
const { useState: dShellState, useEffect: dShellEffect, useRef: dShellRef } = React;

/* ---- desktop nav per role (operational tabs; back-office stays on phone) ---- */
const DESK_NAV = {
  owner:   [['register', 'Register', 'bag'], ['tables', 'Tables', 'table'], ['orders', 'Orders', 'receipt'], ['inventory', 'Stock', 'box'], ['analytics', 'Analytics', 'chart']],
  manager: [['register', 'Register', 'bag'], ['tables', 'Tables', 'table'], ['orders', 'Orders', 'receipt'], ['inventory', 'Stock', 'box'], ['tower', 'Live', 'tower']],
  waiter:  [['register', 'Register', 'bag'], ['tables', 'Tables', 'table'], ['orders', 'Orders', 'receipt']],
};
const DESK_NAV_BN = { register: 'রেজিস্টার', tables: 'টেবিল', orders: 'অর্ডার', inventory: 'স্টক', analytics: 'বিশ্লেষণ', tower: 'লাইভ' };

/* ---------- scaling stage ---------- */
function Frame({ children }) {
  const [scale, setScale] = dShellState(1);
  dShellEffect(() => {
    const fit = () => setScale(Math.min(window.innerWidth / 1280, window.innerHeight / 800));
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, []);
  return (
    <div className="dk-viewport">
      <div className="dk-stage bytes-root" style={{ transform: `scale(${scale})` }}>
        <div className="dk-root">{children}</div>
      </div>
    </div>
  );
}

/* ---------- nav rail ---------- */
function NavRail() {
  const d = useDesk();
  const nav = DESK_NAV[d.role] || DESK_NAV.manager;
  const escal = d.chats.filter((c) => c.status === 'needs').length;
  const unread = d.notifs.filter((n) => !n.read).length;
  const me = d.staff.find((s) => s.role === d.role) || d.staff[0];
  return (
    <div className="dk-rail">
      <div className="brand"><Mark size={40} /></div>
      <div className="dk-navlist">
        {nav.map(([id, label, ic]) => (
          <button key={id} className={'dk-navbtn' + (d.tab === id ? ' on' : '')} onClick={() => d.setTab(id)}>
            <span className="ic"><Icon name={ic} size={22} color="currentColor" /></span>
            <span className="lb">{d.lang === 'bn' ? (DESK_NAV_BN[id] || label) : label}</span>
            {id === 'orders' && d.pendingCount > 0 && <span className="nbadge tab">{d.pendingCount}</span>}
          </button>
        ))}
      </div>
      <div className="dk-railfoot">
        <button className="dk-railbtn" title="Messages" onClick={() => d.setMsgOpen(true)}>
          <Icon name="chat" size={21} />
          {escal > 0 && <span className="nbadge tab">{escal}</span>}
        </button>
        <button className="dk-railbtn" title="Notifications" onClick={() => d.setPop(d.pop === 'notif' ? null : 'notif')}>
          <Icon name="bell" size={21} />
          {unread > 0 && <span className="nbadge tab">{unread}</span>}
        </button>
        <div style={{ width: 28, height: 1, background: 'var(--line)', margin: '2px 0' }} />
        <button className="dk-langbtn" title="Language" onClick={() => d.setLang(d.lang === 'en' ? 'bn' : 'en')}>{d.lang === 'en' ? 'EN' : 'বাং'}</button>
        <button className="dk-avatar" title="Account" onClick={() => d.setPop(d.pop === 'acct' ? null : 'acct')}>{me ? me.init : '··'}</button>
      </div>
      {d.pop === 'notif' && <NotifPop />}
      {d.pop === 'acct' && <AccountPop />}
    </div>
  );
}

/* ---------- notifications popover ---------- */
const DK_NOTIF_META = {
  pending: ['receipt', 'var(--accent-strong)', 'var(--accent-tint)'],
  escalation: ['chat', 'var(--warning)', 'var(--warning-soft)'],
  stock: ['box', 'var(--danger)', 'var(--danger-soft)'],
  table: ['table', 'var(--info)', 'var(--info-soft)'],
  shift: ['clock', 'var(--ink-2)', 'var(--surface-2)'],
};
function NotifPop() {
  const d = useDesk();
  const unread = d.notifs.filter((n) => !n.read).length;
  return (
    <React.Fragment>
      <div onClick={() => d.setPop(null)} style={{ position: 'fixed', inset: 0, zIndex: 55 }} />
      <div className="dk-pop dk-fadein" style={{ left: 80, bottom: 64, width: 348 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '13px 16px', borderBottom: '1px solid var(--line)' }}>
          <span style={{ fontSize: 15, fontWeight: 700 }}>{d.lang === 'bn' ? 'নোটিফিকেশন' : 'Notifications'}</span>
          {unread > 0 && <button onClick={d.markAllRead} style={{ border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 12.5, fontWeight: 600, color: 'var(--accent-strong)' }}>{d.lang === 'bn' ? 'সব পঠিত' : 'Mark all read'}</button>}
        </div>
        <div className="scrollY" style={{ maxHeight: 420 }}>
          {d.notifs.map((n) => {
            const [ic, fg, bg] = DK_NOTIF_META[n.type] || DK_NOTIF_META.shift;
            return (
              <div key={n.id} onClick={() => d.openNotif(n)} style={{ display: 'flex', gap: 11, padding: '12px 16px', cursor: 'pointer', borderBottom: '1px solid var(--line)', background: n.read ? 'var(--surface)' : 'var(--bg)' }}>
                <div style={{ width: 34, height: 34, borderRadius: 9, background: bg, color: fg, display: 'grid', placeItems: 'center', flex: '0 0 34px' }}><Icon name={ic} size={18} /></div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                    <span style={{ fontSize: 13.5, fontWeight: 700, flex: 1, minWidth: 0 }} className="ell">{n.title}</span>
                    <span style={{ fontSize: 11, color: 'var(--placeholder)' }}>{n.mins < 60 ? n.mins + 'm' : Math.round(n.mins / 60) + 'h'}</span>
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
  );
}

/* ---------- account / role popover ---------- */
const DK_ROLES = [['owner', 'Owner', 'মালিক'], ['manager', 'Manager', 'ম্যানেজার'], ['waiter', 'Waiter', 'ওয়েটার']];
function AccountPop() {
  const d = useDesk();
  const me = d.staff.find((s) => s.role === d.role) || d.staff[0];
  return (
    <React.Fragment>
      <div onClick={() => d.setPop(null)} style={{ position: 'fixed', inset: 0, zIndex: 55 }} />
      <div className="dk-pop dk-fadein" style={{ left: 80, bottom: 14, width: 268 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '15px 16px', borderBottom: '1px solid var(--line)' }}>
          <div className="dk-avatar" style={{ pointerEvents: 'none' }}>{me ? me.init : '··'}</div>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 14.5, fontWeight: 700 }} className="ell">{me ? me.name : 'Staff'}</div>
            <div style={{ fontSize: 12, color: 'var(--muted)' }}>Spice Garden · Dhanmondi</div>
          </div>
        </div>
        <div style={{ padding: '10px 12px' }}>
          <div className="eyebrow" style={{ padding: '4px 4px 8px' }}>{d.lang === 'bn' ? 'ভূমিকা (ডেমো)' : 'Switch role (demo)'}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            {DK_ROLES.map(([id, en, bn]) => (
              <button key={id} onClick={() => d.setRole(id)} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 42, padding: '0 12px', borderRadius: 'var(--r-md)', border: '1px solid ' + (d.role === id ? 'var(--accent)' : 'var(--line-2)'), background: d.role === id ? 'var(--accent-tint)' : 'var(--surface)', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 14, fontWeight: 600, color: d.role === id ? 'var(--accent-strong)' : 'var(--ink)' }}>
                <span>{d.lang === 'bn' ? bn : en}</span>
                {d.role === id && <Icon name="check" size={18} color="var(--accent-strong)" />}
              </button>
            ))}
          </div>
        </div>
      </div>
    </React.Fragment>
  );
}

/* ---------- desktop screen header ---------- */
function DeskHead({ title, sub, right }) {
  return (
    <div className="dk-topbar">
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="ttl ell">{title}</div>
        {sub && <div className="sub ell">{sub}</div>}
      </div>
      {right}
    </div>
  );
}

/* ---------- small shared: desktop search field ---------- */
function DeskField({ icon = 'search', value, onChange, placeholder, width }) {
  const [foc, setFoc] = dShellState(false);
  return (
    <div className={'field' + (foc ? ' focus' : '')} style={{ width: width || 'auto', flex: width ? '0 0 auto' : 1, maxWidth: width ? undefined : 360 }}>
      <Icon name={icon} size={18} />
      <input value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} onFocus={() => setFoc(true)} onBlur={() => setFoc(false)} />
      {value && <button onClick={() => onChange('')} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--muted)', display: 'grid', placeItems: 'center' }}><Icon name="x" size={15} /></button>}
    </div>
  );
}

Object.assign(window, { DESK_NAV, Frame, NavRail, DeskHead, DeskField });
