/* ============================================================
   Quick Bytes POS — Staff (list + OTP invite) + Audit trail
   ============================================================ */

const ROLE_META = {
  owner: ['Owner', 'var(--accent-strong)', 'var(--accent-tint)'],
  manager: ['Manager', 'var(--info)', 'var(--info-soft)'],
  waiter: ['Waiter', 'var(--ink-2)', 'var(--surface-2)'],
};

function StaffScreen() {
  const b = useBytes();
  const [invite, setInvite] = useState(false);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [inviteRole, setInviteRole] = useState('waiter');
  const [stage, setStage] = useState('form'); // form → otp → done
  const canInviteManager = b.role === 'owner' && !b.staff.some((s) => s.role === 'manager' && s.active);

  const submit = () => { if (!name.trim() || phone.trim().length < 6) return; setStage('otp'); };
  const confirm = () => { b.addStaff({ name: name.trim(), phone: phone.trim(), role: inviteRole, init: name.trim().split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase() }); setStage('done'); };
  const close = () => { setInvite(false); setStage('form'); setName(''); setPhone(''); setInviteRole('waiter'); };

  return (
    <React.Fragment>
      <Header title={b.t('title.staff')} sub={b.staff.filter((s) => s.active).length + ' active'} onBack={b.pop} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {b.staff.map((s) => {
          const [rl, fg, bg] = ROLE_META[s.role];
          return (
            <div key={s.id} className="card" style={{ padding: 13, display: 'flex', alignItems: 'center', gap: 12, opacity: s.active ? 1 : .55 }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: bg, color: fg, display: 'grid', placeItems: 'center', fontSize: 15, fontWeight: 700, flex: '0 0 44px' }}>{s.init}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                  <span style={{ fontSize: 15, fontWeight: 700 }} className="ell">{s.name}</span>
                  <span style={{ fontSize: 11, fontWeight: 700, color: fg, background: bg, borderRadius: 5, padding: '2px 7px', flex: '0 0 auto' }}>{rl}</span>
                </div>
                <div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 2 }} className="tab">{s.phone}{s.role === 'waiter' && s.active ? ' · ' + s.tables + ' tables · ' + money(s.sales) : ''}</div>
              </div>
              {s.role !== 'owner' && <Toggle on={s.active} onChange={() => b.toggleStaff(s.id)} />}
            </div>
          );
        })}
      </div>
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg" onClick={() => setInvite(true)}><Icon name="userplus" size={20} color="var(--accent-ink)" sw={2} />{b.t('act.invite')}</button>
      </div>

      <Sheet open={invite} onClose={close}>
        <div style={{ padding: '6px 18px 22px' }}>
          {stage === 'form' && (
            <React.Fragment>
              <div style={{ fontSize: 19, fontWeight: 700, marginBottom: 4 }}>Invite staff</div>
              <div style={{ fontSize: 13, color: 'var(--muted)', marginBottom: 16 }}>They’ll get an OTP to accept on their phone.</div>
              <div className="eyebrow" style={{ marginBottom: 8 }}>Role</div>
              <div className="seg" style={{ marginBottom: 14 }}>
                {canInviteManager && <button className={inviteRole === 'manager' ? 'active' : ''} onClick={() => setInviteRole('manager')}>Manager</button>}
                <button className={inviteRole === 'waiter' ? 'active' : ''} onClick={() => setInviteRole('waiter')}>Waiter</button>
              </div>
              <div className="field" style={{ marginBottom: 10 }}><Icon name="user" size={18} /><input value={name} onChange={(e) => setName(e.target.value)} placeholder="Full name" /></div>
              <div className="field" style={{ marginBottom: 16 }}><Icon name="phone" size={17} /><input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="01XXX-XXXXXX" inputMode="tel" /></div>
              <button className="btn btn-primary btn-block btn-lg" disabled={!name.trim() || phone.trim().length < 6} onClick={submit}>Send OTP invite</button>
            </React.Fragment>
          )}
          {stage === 'otp' && (
            <div style={{ textAlign: 'center' }}>
              <div style={{ width: 56, height: 56, borderRadius: 15, background: 'var(--accent-tint)', color: 'var(--accent-strong)', display: 'grid', placeItems: 'center', margin: '4px auto 14px' }}><Icon name="phone" size={26} /></div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>OTP sent to {phone}</div>
              <div style={{ fontSize: 13, color: 'var(--muted)', margin: '6px 0 18px' }}>Waiting for {name.trim()} to accept the invite…</div>
              <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginBottom: 18 }}>
                {['4', '8', '1', '6'].map((d, i) => <div key={i} style={{ width: 44, height: 52, borderRadius: 'var(--r-md)', border: '1px solid var(--line-2)', background: 'var(--surface-2)', display: 'grid', placeItems: 'center', fontSize: 22, fontWeight: 700 }} className="tab">{d}</div>)}
              </div>
              <button className="btn btn-primary btn-block btn-lg" onClick={confirm}>Simulate accept</button>
            </div>
          )}
          {stage === 'done' && (
            <div style={{ textAlign: 'center', padding: '8px 0' }}>
              <div style={{ width: 60, height: 60, borderRadius: 16, background: 'var(--accent)', display: 'grid', placeItems: 'center', margin: '0 auto 14px' }}><Icon name="check" size={30} color="var(--accent-ink)" sw={2.6} /></div>
              <div style={{ fontSize: 19, fontWeight: 700 }}>{name.trim()} joined</div>
              <div style={{ fontSize: 13.5, color: 'var(--muted)', margin: '6px 0 18px' }}>Added as {ROLE_META[inviteRole][0]}.</div>
              <button className="btn btn-primary btn-block btn-lg" onClick={close}>Done</button>
            </div>
          )}
        </div>
      </Sheet>
    </React.Fragment>
  );
}

/* ---------- audit trail ---------- */
const AUDIT_META = {
  void: ['void', 'var(--danger)', 'var(--danger-soft)', 'Void'],
  refund: ['refresh', 'var(--warning)', 'var(--warning-soft)', 'Refund'],
  comp: ['star', 'var(--info)', 'var(--info-soft)', 'Comp'],
  discount: ['percent', 'var(--accent-strong)', 'var(--accent-tint)', 'Discount'],
};
function AuditScreen() {
  const b = useBytes();
  const [filter, setFilter] = useState('all');
  const types = ['all', 'void', 'refund', 'comp', 'discount'];
  const list = filter === 'all' ? b.audit : b.audit.filter((a) => a.action === filter);
  const ago = (m) => m < 60 ? m + 'm ago' : m < 1440 ? Math.round(m / 60) + 'h ago' : Math.round(m / 1440) + 'd ago';
  return (
    <React.Fragment>
      <Header title={b.t('title.audit')} sub="Every void · refund · comp · override" onBack={b.pop} />
      <div className="chiprow noscroll" style={{ flex: '0 0 auto', paddingBottom: 12 }}>
        {types.map((tp) => <button key={tp} className={'chip' + (filter === tp ? ' active' : '')} onClick={() => setFilter(tp)}>{tp === 'all' ? 'All' : AUDIT_META[tp][3]}</button>)}
      </div>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {list.map((a) => {
          const [ic, fg, bg, label] = AUDIT_META[a.action];
          const [rl, rfg, rbg] = ROLE_META[a.role];
          return (
            <div key={a.id} className="card" style={{ padding: 13 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
                <div style={{ width: 36, height: 36, borderRadius: 9, background: bg, color: fg, display: 'grid', placeItems: 'center', flex: '0 0 36px' }}><Icon name={ic} size={18} /></div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 700 }} className="ell">{a.label}</div>
                  <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 1 }}>{a.who} · {rl} · {ago(a.mins)}</div>
                </div>
                {a.amount > 0 && <span style={{ fontSize: 14, fontWeight: 700, color: fg, flex: '0 0 auto' }} className="tab">−{money(a.amount)}</span>}
              </div>
              <div style={{ marginTop: 9, padding: '8px 11px', background: 'var(--surface-2)', borderRadius: 'var(--r-sm)', fontSize: 12.5, color: 'var(--ink-2)', display: 'flex', gap: 7 }}>
                <Icon name="note" size={15} color="var(--muted)" style={{ flex: '0 0 15px', marginTop: 1 }} /><span>{a.reason}</span>
              </div>
            </div>
          );
        })}
        {list.length === 0 && <div style={{ textAlign: 'center', color: 'var(--muted)', padding: '40px 0', fontSize: 14 }}>No {filter} actions logged.</div>}
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { StaffScreen, AuditScreen, ROLE_META });
