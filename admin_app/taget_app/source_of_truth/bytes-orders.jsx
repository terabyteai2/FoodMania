/* ============================================================
   Bytes POS — Orders home (multi-channel) + order detail
   ============================================================ */

function ChannelDot({ channel, size = 34 }) {
  const [ic, , color, soft] = CHANNELS[channel] || CHANNELS.manager;
  return <div style={{ width: size, height: size, flex: '0 0 ' + size + 'px', borderRadius: 8, background: soft, color, display: 'grid', placeItems: 'center' }}><Icon name={ic} size={size * 0.56} /></div>;
}
function typeLabel(o) { return o.type === 'dinein' ? (o.table ? o.table.replace('T', 'Table ') : 'Dine-in') : o.type === 'delivery' ? 'Delivery' : o.type === 'parcel' ? 'Parcel' : o.type === 'pickup' ? 'Parcel' : 'Counter'; }
function typeIcon(o) { return o.type === 'dinein' ? 'table' : o.type === 'delivery' ? 'truck' : o.type === 'parcel' || o.type === 'pickup' ? 'bag' : 'store'; }

function OrderCard({ o, onClick, onAccept, onReject, onKOT, onBill }) {
  const b = useBytes();
  const t = b.t;
  const [, chLabel] = CHANNELS[o.channel] || CHANNELS.manager;
  const count = o.lines.reduce((s, l) => s + l.qty, 0);
  const total = orderTotal(o.lines, o.discount || 0, orderCharge(o));
  const preview = o.lines.slice(0, 2).map((l) => (l.qty > 1 ? l.qty + '× ' : '') + l.name).join(', ');
  const pend = o.state === 'pending';
  const done = o.state === 'completed';
  return (
    <div className="tile" onClick={onClick} style={{ padding: 14, opacity: done ? .82 : 1, borderColor: pend ? '#EAD9A8' : 'var(--line)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
        <ChannelDot channel={o.channel} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
            <span style={{ fontSize: 19, fontWeight: 800, letterSpacing: '-.01em', flex: '0 0 auto' }} className="tab">#{o.serial}</span>
            <span style={{ fontSize: 13.5, color: 'var(--ink-2)', fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{typeLabel(o)}</span>
          </div>
          <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 1, fontWeight: 500 }} className="ell">{chLabel} · {o.mins}m ago</div>
        </div>
        <span style={{ fontSize: 17, fontWeight: 700, flex: '0 0 auto' }} className="tab">{money(total)}</span>
      </div>

      <div style={{ fontSize: 13.5, color: 'var(--ink-2)', lineHeight: 1.45, marginTop: 10 }} className="ell"><span style={{ fontWeight: 700, color: 'var(--ink)' }}>{count} {t('word.items')}</span> · {preview}{o.lines.length > 2 ? '…' : ''}</div>

      {pend && (
        <div style={{ display: 'flex', gap: 8, marginTop: 12, justifyContent: 'flex-end', alignItems: 'center' }} onClick={(e) => e.stopPropagation()}>
          <button className="btn btn-ghost btn-sm" style={{ width: 40, flex: '0 0 40px', color: 'var(--danger)', padding: 0 }} onClick={onReject}><Icon name="x" size={18} /></button>
          <button className="btn btn-sm" style={{ padding: '0 22px', background: 'var(--accent-tint)', border: '1px solid var(--accent-tint-2)', color: 'var(--accent-strong)', fontWeight: 700 }} onClick={onAccept}><Icon name="check2" size={16} sw={2.3} />{t('act.accept')}</button>
        </div>
      )}
      {!pend && !done && (
        <div style={{ display: 'flex', gap: 8, marginTop: 12 }} onClick={(e) => e.stopPropagation()}>
          <button className="btn btn-ghost btn-sm" style={{ flex: 1 }} onClick={onKOT}><Icon name="printer" size={16} />{t('act.printKOT')}</button>
          <button className="btn btn-ghost btn-sm" style={{ flex: 1, color: 'var(--accent-strong)', borderColor: 'var(--accent-tint-2)', background: 'var(--accent-tint)' }} onClick={onBill}><Icon name="receipt" size={16} />{t('act.printBill')}</button>
        </div>
      )}
      {done && (
        <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px solid var(--line)', display: 'flex', alignItems: 'center', gap: 6, fontSize: 12.5, color: 'var(--success)', fontWeight: 600 }}>
          <Icon name="check2" size={15} sw={2.2} />{t('word.completed')} · paid
        </div>
      )}
    </div>
  );
}

const DATE_RANGES = [['today', 'Today'], ['yest', 'Yesterday'], ['7d', '7 days'], ['30d', '30 days'], ['3m', '3 months'], ['12m', '12 months']];
const SOURCE_OPTS = [['all', 'All sources'], ['storefront', 'Website'], ['chatbot', 'Messenger'], ['qr', 'Table QR'], ['waiter', 'Waiter'], ['counter', 'Counter'], ['manager', 'Manager']];

function OrdersScreen() {
  const b = useBytes();
  const t = b.t;
  const [filter, setFilter] = useState('ongoing');
  const [q, setQ] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [range, setRange] = useState('today');
  const [source, setSource] = useState('all');
  const orders = b.orders;
  const pending = orders.filter((o) => o.state === 'pending');
  const ongoing = orders.filter((o) => o.state === 'pending' || o.state === 'accepted');
  const completed = orders.filter((o) => o.state === 'completed');
  const matches = (o) => {
    if (source !== 'all' && o.channel !== source) return false;
    if (q.trim()) {
      const hay = ('#' + o.serial + ' ' + o.token + ' ' + (o.customer || '') + ' ' + typeLabel(o) + ' ' + o.lines.map((l) => l.name).join(' ')).toLowerCase();
      if (!hay.includes(q.trim().toLowerCase())) return false;
    }
    return true;
  };
  const base = filter === 'ongoing' ? ongoing : completed;
  const list = base.filter(matches);
  const liveRev = ongoing.reduce((s, o) => s + orderTotal(o.lines, o.discount || 0, orderCharge(o)), 0);
  const activeFilters = (range !== 'today' ? 1 : 0) + (source !== 'all' ? 1 : 0);

  const billAndComplete = (o) => { b.setOrderState(o.id, 'completed'); b.go({ screen: 'printOut', orderId: o.id, kind: 'complete' }); };

  return (
    <React.Fragment>
      <Header brand sub="Spice Garden · Dhanmondi" right={<TopActions />} />

      {/* search + filters */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px', display: 'flex', gap: 8 }}>
        <div className="field" style={{ flex: 1 }}>
          <Icon name="search" size={18} />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('word.search')} />
          {q && <button onClick={() => setQ('')} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--muted)', display: 'grid', placeItems: 'center' }}><Icon name="x" size={16} /></button>}
        </div>
        <button onClick={() => setShowFilters(true)} style={{ width: 48, flex: '0 0 48px', borderRadius: 'var(--r-md)', border: '1px solid ' + (activeFilters ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: activeFilters ? 'var(--accent-tint)' : 'var(--surface)', color: activeFilters ? 'var(--accent-strong)' : 'var(--ink-2)', display: 'grid', placeItems: 'center', cursor: 'pointer', position: 'relative' }}>
          <Icon name="filter" size={20} />
          {activeFilters > 0 && <span className="tab" style={{ position: 'absolute', top: -5, right: -5, minWidth: 18, height: 18, padding: '0 5px', borderRadius: 9, background: 'var(--accent-strong)', color: '#fff', fontSize: 10.5, fontWeight: 800, display: 'grid', placeItems: 'center', border: '2px solid var(--bg)' }}>{activeFilters}</span>}
        </button>
      </div>

      {/* state seg */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px' }}>
        <div className="seg">
          {[['ongoing', t('word.ongoing'), ongoing.length], ['completed', t('word.completed'), completed.length]].map(([id, label, n]) => (
            <button key={id} className={filter === id ? 'active' : ''} onClick={() => setFilter(id)}>{label}<span style={{ marginLeft: 6, minWidth: 18, height: 18, padding: '0 5px', borderRadius: 9, background: filter === id ? 'var(--accent)' : 'var(--surface-3)', color: filter === id ? 'var(--accent-ink)' : 'var(--muted)', fontSize: 11, fontWeight: 700, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }} className="tab">{n}</span></button>
          ))}
        </div>
      </div>

      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 90px', display: 'flex', flexDirection: 'column', gap: 11 }}>
        {/* calm summary row — scrolls away to give the list its full height */}
        <div style={{ flex: '0 0 auto', display: 'flex', gap: 10 }}>
          <div className="card" style={{ flex: 1.4, padding: '12px 14px' }}>
            <div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>On the floor now</div>
            <div style={{ fontSize: 21, fontWeight: 700, marginTop: 2 }} className="tab">{money(liveRev)}</div>
          </div>
          <div className="card" style={{ flex: 1, padding: '12px 14px', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
              <span style={{ fontSize: 21, fontWeight: 700, color: pending.length ? 'var(--accent-strong)' : 'var(--ink)' }} className="tab">{pending.length}</span>
              <span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>to accept</span>
            </div>
            <div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 500, marginTop: 2 }}>{ongoing.length} ongoing</div>
          </div>
        </div>
        {list.map((o) => <OrderCard key={o.id} o={o} onClick={() => b.push({ screen: 'orderDetail', orderId: o.id })}
          onAccept={() => { b.setOrderState(o.id, 'accepted'); b.go({ screen: 'printOut', orderId: o.id, kind: 'accept' }); }}
          onReject={() => b.setOrderState(o.id, 'rejected')}
          onKOT={() => b.go({ screen: 'printOut', orderId: o.id, kind: 'kot' })}
          onBill={() => billAndComplete(o)} />)}
        {list.length === 0 && (
          <div style={{ textAlign: 'center', color: 'var(--muted)', padding: '52px 20px', fontSize: 14 }}>
            <div style={{ width: 54, height: 54, borderRadius: 14, background: 'var(--surface-2)', display: 'grid', placeItems: 'center', margin: '0 auto 14px', color: 'var(--placeholder)' }}><Icon name={q || activeFilters ? 'search' : filter === 'ongoing' ? 'receipt' : 'check2'} size={26} /></div>
            {q || activeFilters ? 'No orders match.' : filter === 'ongoing' ? 'No ongoing orders.' : 'No completed orders yet.'}
          </div>
        )}
      </div>

      <button className="fab" style={{ position: 'absolute', right: 18, bottom: 18, zIndex: 20 }} onClick={() => b.setTab('tables')}>
        <Icon name="plus" size={26} color="var(--accent-ink)" sw={2.4} />
      </button>

      <Sheet open={showFilters} onClose={() => setShowFilters(false)}>
        <div style={{ padding: '6px 18px 22px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
            <span style={{ fontSize: 19, fontWeight: 700 }}>Filter orders</span>
            {activeFilters > 0 && <button onClick={() => { setRange('today'); setSource('all'); }} style={{ border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 13, fontWeight: 600, color: 'var(--accent-strong)' }}>Reset</button>}
          </div>
          <div className="eyebrow" style={{ marginBottom: 9 }}>Date range</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 18 }}>
            {DATE_RANGES.map(([id, label]) => <button key={id} className={'chip' + (range === id ? ' active' : '')} onClick={() => setRange(id)} style={{ height: 38 }}>{label}</button>)}
          </div>
          <div className="eyebrow" style={{ marginBottom: 9 }}>Source</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 20 }}>
            {SOURCE_OPTS.map(([id, label]) => <button key={id} className={'chip' + (source === id ? ' active' : '')} onClick={() => setSource(id)} style={{ height: 38 }}>{label}</button>)}
          </div>
          <button className="btn btn-primary btn-block btn-lg" onClick={() => setShowFilters(false)}>Show {list.length} orders</button>
        </div>
      </Sheet>
    </React.Fragment>
  );
}

/* ---------- order detail (editable) ---------- */
function OrderDetail({ orderId }) {
  const b = useBytes();
  const o = b.getOrder(orderId);
  const [edit, setEdit] = useState(false);
  if (!o) return <div style={{ padding: 20 }}>Order closed.</div>;
  const [, chLabel] = CHANNELS[o.channel] || CHANNELS.manager;
  const charge = orderCharge(o);
  const pend = o.state === 'pending';
  const done = o.state === 'completed';

  const accept = () => { b.setOrderState(orderId, 'accepted'); b.go({ screen: 'printOut', orderId, kind: 'accept' }); };
  const bill = () => { b.setOrderState(orderId, 'completed'); b.go({ screen: 'printOut', orderId, kind: 'complete' }); };

  return (
    <React.Fragment>
      <Header title={'#' + o.serial} sub={chLabel + ' · ' + typeLabel(o)} onBack={b.pop}
        right={pend ? <span className="badge accent" style={{ height: 26 }}>Pending</span> : done ? <span className="badge success" style={{ height: 26 }}><Icon name="check2" size={13} sw={2.2} />Completed</span> : <span className="badge neutral" style={{ height: 26 }}>Ongoing</span>} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <div className="card" style={{ padding: 14, marginBottom: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
            <ChannelDot channel={o.channel} size={42} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 16, fontWeight: 700 }} className="ell">{o.customer}</div>
              <div style={{ fontSize: 13, color: 'var(--muted)' }} className="ell">{o.phone || (o.server ? 'Waiter · ' + o.server : 'Dine-in')} · {o.mins}m ago</div>
            </div>
            {o.phone && <button style={{ width: 40, height: 40, borderRadius: 9, border: '1px solid var(--line-2)', background: 'var(--surface)', display: 'grid', placeItems: 'center', cursor: 'pointer', color: 'var(--success)' }}><Icon name="phone" size={19} /></button>}
          </div>
          {o.addr && <div style={{ display: 'flex', gap: 8, marginTop: 11, paddingTop: 11, borderTop: '1px solid var(--line)', color: 'var(--ink-2)', fontSize: 13.5 }}><Icon name="pin" size={17} color="var(--muted)" /><span>{o.addr}</span></div>}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '0 2px 10px' }}>
          <span className="eyebrow">Items · {o.lines.reduce((s, l) => s + l.qty, 0)}</span>
          {!done && <button onClick={() => setEdit(!edit)} style={{ display: 'flex', alignItems: 'center', gap: 6, border: 'none', background: 'transparent', cursor: 'pointer', color: edit ? 'var(--accent-strong)' : 'var(--ink-2)', fontWeight: 600, fontSize: 13.5 }}><Icon name={edit ? 'check2' : 'edit'} size={16} sw={2} />{edit ? 'Done' : 'Edit'}</button>}
        </div>

        <LineList lines={o.lines} editable={edit} onQty={(lid, q) => b.setOrderLineQty(orderId, lid, q)} onRemove={(lid) => b.removeOrderLine(orderId, lid)} />

        {edit && (
          <button onClick={() => b.push({ screen: 'orderBuild', orderId })} style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9, padding: '12px', marginTop: 10, border: '1px dashed var(--line-2)', borderRadius: 'var(--r-md)', background: 'var(--surface)', cursor: 'pointer', color: 'var(--accent-strong)', fontWeight: 600, fontSize: 14 }}><Icon name="plus" size={18} sw={2} />Add items</button>
        )}

        <div className="card" style={{ padding: 16, marginTop: 16 }}><OrderSummary lines={o.lines} charge={charge} /></div>
      </div>

      <div className="bottombar">
        {pend ? (
          <React.Fragment>
            <button className="btn btn-ghost" onClick={() => { b.setOrderState(orderId, 'rejected'); b.pop(); }}><Icon name="x" size={18} />Reject</button>
            <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={accept}>Accept order</button>
          </React.Fragment>
        ) : done ? (
          <button className="btn btn-ghost btn-block btn-lg" onClick={() => b.go({ screen: 'printOut', orderId, kind: 'reprint' })}><Icon name="printer" size={19} />Reprint bill</button>
        ) : (
          <React.Fragment>
            <button className="btn btn-ghost btn-lg" style={{ flex: 1 }} onClick={() => b.go({ screen: 'printOut', orderId, kind: 'kot' })}><Icon name="printer" size={18} />Print KOT</button>
            <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={bill}><Icon name="receipt" size={18} color="var(--accent-ink)" />Print Bill</button>
          </React.Fragment>
        )}
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { OrdersScreen, OrderDetail, OrderCard, ChannelDot, typeLabel, typeIcon });
