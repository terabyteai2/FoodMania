/* ============================================================
   Bytes POS — Control Tower (manager live ops) + More hub
   ============================================================ */

function ControlTower({ tabMode }) {
  const b = useBytes();
  const [adv, setAdv] = useState(false);
  const Metric = ({ label, value, delta, up, sub }) => (
    <div className="card" style={{ padding: '13px 14px', flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }} className="ell">{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 3, letterSpacing: '-.02em' }} className="tab ell">{value}</div>
      {(delta != null || sub) && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 4 }}>
          {delta != null && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontSize: 12, fontWeight: 700, color: up ? 'var(--success)' : 'var(--danger)' }}><Icon name={up ? 'trendup' : 'trenddn'} size={13} sw={2.2} />{delta}</span>}
          {sub && <span style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 500 }}>{sub}</span>}
        </div>
      )}
    </div>
  );
  const orders = b.orders;
  const pending = orders.filter((o) => o.state === 'pending');
  const slowest = [...pending].sort((a, c) => c.mins - a.mins)[0];
  const lowStock = b.inventory.filter((i) => stockKind(i) !== 'ok');
  const liveRev = orders.reduce((s, o) => s + orderTotal(o.lines, 0, orderCharge(o)), 0);
  const target = 240000;
  const pace = Math.round(liveRev / target * 100);

  const channelLoad = Object.entries(CHANNELS).map(([id, [ic, label, color, soft]]) => [id, label, ic, color, soft, orders.filter((o) => o.channel === id).length]).filter((x) => x[5] > 0);
  const maxCh = Math.max(...channelLoad.map((c) => c[5]), 1);
  const waiters = b.staff.filter((s) => s.role === 'waiter');

  return (
    <React.Fragment>
      <Header title={b.t('title.tower')} sub="Live operations" big={tabMode} onBack={tabMode ? undefined : b.pop} right={tabMode ? <TopActions /> : <span className="badge success" style={{ height: 26 }}><span className="bd" style={{ background: 'var(--success)' }} />Live</span>} />
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span className="eyebrow">Right now · 7:42 PM</span>
        <AdvToggle on={adv} onChange={setAdv} label={b.t('word.advanced')} />
      </div>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        {/* alerts */}
        {(slowest || lowStock.length > 0) && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 14 }}>
            {slowest && slowest.mins >= 3 && (
              <div onClick={() => b.push({ screen: 'orderDetail', orderId: slowest.id })} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '12px 13px', borderRadius: 'var(--r-lg)', background: 'var(--danger-soft)', border: '1px solid #F2C9C8', cursor: 'pointer' }}>
                <div style={{ width: 34, height: 34, borderRadius: 8, background: 'var(--danger)', display: 'grid', placeItems: 'center', color: '#fff', flex: '0 0 34px' }}><Icon name="clock" size={19} /></div>
                <div style={{ flex: 1 }}><div style={{ fontSize: 14, fontWeight: 700, color: 'var(--danger)' }}>Order #{slowest.serial} waiting {slowest.mins}m</div><div style={{ fontSize: 12.5, color: 'var(--ink-2)' }}>{typeLabel(slowest)} · needs accepting</div></div>
                <Icon name="chev" size={18} color="var(--danger)" />
              </div>
            )}
            {lowStock.length > 0 && (
              <div onClick={() => b.setTab('inventory')} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '12px 13px', borderRadius: 'var(--r-lg)', background: 'var(--warning-soft)', border: '1px solid #F0DDA8', cursor: 'pointer' }}>
                <div style={{ width: 34, height: 34, borderRadius: 8, background: 'var(--warning)', display: 'grid', placeItems: 'center', color: '#fff', flex: '0 0 34px' }}><Icon name="warn" size={19} /></div>
                <div style={{ flex: 1 }}><div style={{ fontSize: 14, fontWeight: 700, color: 'var(--warning)' }}>{lowStock.length} items below par</div><div style={{ fontSize: 12.5, color: 'var(--ink-2)' }} className="ell">{lowStock.slice(0, 3).map((i) => i.name).join(', ')}</div></div>
                <Icon name="chev" size={18} color="var(--warning)" />
              </div>
            )}
          </div>
        )}

        {/* quick stats — always visible */}
        <div style={{ display: 'flex', gap: 10, marginBottom: 12 }}>
          <Metric label="Open orders" value={'' + orders.length} sub={pending.length + ' pending'} />
          <Metric label="Tables seated" value={orders.filter((o) => o.table).length + '/' + TABLES.length} sub="42% turn" />
          <Metric label="Avg accept" value="2.4m" delta="0.6m" up sub="" />
        </div>

        {/* channel load — always visible */}
        <div className="card" style={{ padding: 16, marginBottom: 12 }}>
          <span style={{ fontSize: 15, fontWeight: 700 }}>Order channels · now</span>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 11, marginTop: 13 }}>
            {channelLoad.map(([id, label, ic, color, soft, n]) => (
              <div key={id} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 30, height: 30, borderRadius: 7, background: soft, color, display: 'grid', placeItems: 'center', flex: '0 0 30px' }}><Icon name={ic} size={16} /></div>
                <span style={{ fontSize: 13.5, fontWeight: 600, width: 80, flex: '0 0 80px' }}>{label}</span>
                <div style={{ flex: 1, height: 8, borderRadius: 4, background: 'var(--surface-2)', overflow: 'hidden' }}><div style={{ width: (n / maxCh * 100) + '%', height: '100%', background: color, borderRadius: 4 }} /></div>
                <span style={{ fontSize: 13, fontWeight: 700, width: 18, textAlign: 'right' }} className="tab">{n}</span>
              </div>
            ))}
          </div>
        </div>

        {/* ADVANCED: pace to target */}
        {adv && (
          <div className="card" style={{ padding: 16, marginBottom: 12 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 10 }}>
              <span style={{ fontSize: 15, fontWeight: 700 }}>Pace to target</span>
              <span style={{ fontSize: 12.5, color: 'var(--muted)', fontWeight: 600 }}>target {money(target)}</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 10 }}>
              <span style={{ fontSize: 28, fontWeight: 800, letterSpacing: '-.02em' }} className="tab">{money(liveRev)}</span>
              <span style={{ fontSize: 14, fontWeight: 700, color: 'var(--success)' }}>{pace}%</span>
            </div>
            <div style={{ height: 10, borderRadius: 5, background: 'var(--surface-2)', overflow: 'hidden', position: 'relative' }}>
              <div style={{ width: Math.min(100, pace) + '%', height: '100%', background: 'var(--accent)', borderRadius: 5 }} />
              <div style={{ position: 'absolute', left: '72%', top: -2, bottom: -2, width: 2, background: 'var(--ink-2)' }} />
            </div>
            <div style={{ fontSize: 11.5, color: 'var(--muted)', marginTop: 7 }}>On track vs. expected pace for 7:42 PM (marker)</div>
          </div>
        )}

        {/* ADVANCED: staff metrics */}
        {adv && (
          <div className="card" style={{ padding: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
              <span style={{ fontSize: 15, fontWeight: 700 }}>Staff on shift</span>
              <span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>{waiters.filter((w) => w.active).length} active</span>
            </div>
            {waiters.map((w, i) => (
              <div key={w.id} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '11px 0', borderTop: i === 0 ? 'none' : '1px solid var(--line)', opacity: w.active ? 1 : .5 }}>
                <div style={{ width: 36, height: 36, borderRadius: 10, background: w.active ? 'var(--accent-tint)' : 'var(--surface-2)', color: w.active ? 'var(--accent-strong)' : 'var(--muted)', display: 'grid', placeItems: 'center', fontSize: 13.5, fontWeight: 700, flex: '0 0 36px' }}>{w.init}</div>
                <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 600 }}>{w.name}</div><div style={{ fontSize: 12, color: 'var(--muted)' }}>{w.active ? w.tables + ' tables' : 'Off shift'}</div></div>
                <span style={{ fontSize: 14, fontWeight: 700 }} className="tab">{w.active ? money(w.sales) : '—'}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </React.Fragment>
  );
}

/* ---------- More hub ---------- */
function MoreScreen() {
  const b = useBytes();
  const needsHelp = (b.chats || []).filter((c) => c.status === 'needs').length;
  const owner = b.role === 'owner';
  const canManage = b.role === 'owner' || b.role === 'manager';
  const me = b.staff.find((s) => s.role === b.role) || b.staff[0];
  const HubCard = ({ icon, title, sub, onClick, dark }) => (
    <button onClick={onClick} style={{ flex: 1, minWidth: 0, textAlign: 'left', cursor: 'pointer', border: '1px solid ' + (dark ? 'var(--ink)' : 'var(--line)'), borderRadius: 'var(--r-lg)', padding: 15, background: dark ? 'var(--ink)' : 'var(--surface)', display: 'flex', flexDirection: 'column', gap: 10, fontFamily: 'var(--font)' }}>
      <div style={{ width: 40, height: 40, borderRadius: 10, background: dark ? 'var(--accent)' : 'var(--accent-tint)', color: dark ? 'var(--accent-ink)' : 'var(--accent-strong)', display: 'grid', placeItems: 'center' }}><Icon name={icon} size={22} /></div>
      <div>
        <div style={{ fontSize: 15.5, fontWeight: 700, color: dark ? '#fff' : 'var(--ink)' }}>{title}</div>
        <div style={{ fontSize: 12.5, color: dark ? 'rgba(255,255,255,.6)' : 'var(--muted)', marginTop: 2, lineHeight: 1.4 }}>{sub}</div>
      </div>
    </button>
  );
  const Row = ({ icon, label, hint, right, onClick, danger, first }) => (
    <button onClick={onClick} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 13, minHeight: 54, padding: '10px 14px', cursor: 'pointer', border: 'none', background: 'transparent', font: 'inherit', textAlign: 'left', borderTop: first ? 'none' : '1px solid var(--line)' }}>
      <div style={{ width: 34, height: 34, borderRadius: 8, background: danger ? 'var(--danger-soft)' : 'var(--surface-2)', color: danger ? 'var(--danger)' : 'var(--ink-2)', display: 'grid', placeItems: 'center', flex: '0 0 34px' }}><Icon name={icon} size={18} /></div>
      <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 14.5, fontWeight: 600, color: danger ? 'var(--danger)' : 'var(--ink)' }}>{label}</div>{hint && <div style={{ fontSize: 12.5, color: 'var(--muted)' }} className="ell">{hint}</div>}</div>
      {right || <Icon name="chev" size={18} color="var(--muted)" />}
    </button>
  );

  return (
    <React.Fragment>
      <Header title={b.t('title.more')} big right={<TopActions />} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 18px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        {/* profile + role switcher (demo) */}
        <div className="card" style={{ padding: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 13 }}>
            <div style={{ width: 48, height: 48, borderRadius: 13, background: 'var(--ink)', color: 'var(--accent)', display: 'grid', placeItems: 'center', fontSize: 18, fontWeight: 800 }}>SG</div>
            <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 16, fontWeight: 700 }}>Spice Garden</div><div style={{ fontSize: 13, color: 'var(--muted)' }}>{me.name} · {b.t('role.' + b.role)}</div></div>
            <span className="badge accent" style={{ height: 24 }}>Pro</span>
          </div>
          <div style={{ marginTop: 13 }}>
            <div className="eyebrow" style={{ marginBottom: 7 }}>{b.t('role.viewingAs')} · demo</div>
            <div className="seg lime">
              {['owner', 'manager', 'waiter'].map((r) => <button key={r} className={b.role === r ? 'active' : ''} onClick={() => b.switchRole(r)}>{b.t('role.' + r)}</button>)}
            </div>
          </div>
        </div>

        {/* customers */}
        <div onClick={() => b.go({ screen: 'messages' })} className="card" style={{ display: 'flex', alignItems: 'center', gap: 13, padding: 14, cursor: 'pointer' }}>
          <div style={{ width: 44, height: 44, borderRadius: 12, background: 'var(--accent-tint)', color: 'var(--accent-strong)', display: 'grid', placeItems: 'center', flex: '0 0 44px' }}><Icon name="chat" size={22} /></div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 700 }}>{b.t('title.messages')}</div>
            <div style={{ fontSize: 13, color: 'var(--muted)' }}>Take over chats the bot can’t answer</div>
          </div>
          {needsHelp > 0 && <span className="tab" style={{ minWidth: 22, height: 22, padding: '0 7px', borderRadius: 11, background: 'var(--warning)', color: '#fff', fontSize: 12, fontWeight: 700, display: 'grid', placeItems: 'center' }}>{needsHelp}</span>}
          <Icon name="chev" size={18} color="var(--placeholder)" />
        </div>

        {/* management */}
        <div>
          <div className="eyebrow" style={{ margin: '0 2px 9px' }}>Manage</div>
          <div className="card" style={{ overflow: 'hidden' }}>
            <Row icon="grid" label={b.t('title.menu')} hint={MENU.length + ' items'} onClick={() => b.push({ screen: 'menu' })} first />
            {canManage && <Row icon="users" label={b.t('title.staff')} hint={b.staff.filter((s) => s.active).length + ' active members'} onClick={() => b.push({ screen: 'staff' })} />}
            {canManage && <Row icon="shield" label={b.t('title.audit')} hint="Voids · refunds · comps" onClick={() => b.push({ screen: 'audit' })} />}
            {owner && <Row icon="settings" label={b.t('title.settings')} hint="Storefront, areas, VAT, theme" onClick={() => b.push({ screen: 'settings' })} />}
          </div>
        </div>

        {/* service mode (manager+) */}
        {canManage && (
          <div>
            <div className="eyebrow" style={{ margin: '0 2px 9px' }}>Service mode</div>
            <div className="card" style={{ padding: 14 }}>
              <div className="seg lime" style={{ marginBottom: 11 }}>
                <button className={b.mode === 'full' ? 'active' : ''} onClick={() => b.setMode('full')}><Icon name="table" size={16} />Full-service</button>
                <button className={b.mode === 'counter' ? 'active' : ''} onClick={() => b.setMode('counter')}><Icon name="store" size={16} />Counter</button>
              </div>
              <div style={{ fontSize: 13, color: 'var(--muted)', lineHeight: 1.5 }}>
                {b.mode === 'full' ? 'Tables, dine-in, delivery & parcel. The Tables tab manages the floor.' : 'Quick ordering with no tables — for food carts using a Bluetooth receipt printer. The Tables tab becomes a fast counter.'}
              </div>
            </div>
          </div>
        )}

        {/* language quick-toggle */}
        <div className="card" style={{ padding: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 11, marginBottom: 11 }}>
            <div style={{ width: 34, height: 34, borderRadius: 8, background: 'var(--surface-2)', color: 'var(--ink-2)', display: 'grid', placeItems: 'center', flex: '0 0 34px' }}><Icon name="language" size={19} /></div>
            <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 600 }}>Language · ভাষা</div></div>
          </div>
          <div className="seg">
            <button className={b.lang === 'en' ? 'active' : ''} onClick={() => b.setLang('en')}>English</button>
            <button className={b.lang === 'bn' ? 'active' : ''} onClick={() => b.setLang('bn')}>বাংলা</button>
          </div>
        </div>

        <div className="card" style={{ overflow: 'hidden' }}>
          <Row icon="settings" label="Device · Sunmi V2s" hint="Battery 78% · synced" onClick={() => {}} first />
          <Row icon="back" label="Sign out" danger onClick={() => {}} />
        </div>

        <div style={{ textAlign: 'center', color: 'var(--placeholder)', fontSize: 11.5 }}>Quick Bytes POS · v1.0 · Made for Bangladesh</div>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { ControlTower, MoreScreen });
