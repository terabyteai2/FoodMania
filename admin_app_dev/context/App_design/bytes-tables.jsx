/* ============================================================
   Bytes POS — Tables (FOH entry) + Order build + Counter
   ============================================================ */

function TablesScreen() {
  const b = useBytes();
  const [otype, setOtype] = useState('dinein');

  if (b.mode === 'counter') return <CounterScreen />;

  const orderForTable = (id) => b.orders.find((o) => o.table === id && (o.state === 'pending' || o.state === 'accepted'));
  const openTable = (tb) => { const ex = orderForTable(tb.id); if (ex) { b.push({ screen: 'orderDetail', orderId: ex.id }); return; } const oid = b.startOrder({ type: 'dinein', table: tb.id }); b.push({ screen: 'orderBuild', orderId: oid }); };
  const cardHandlers = (o) => ({
    onClick: () => b.push({ screen: 'orderDetail', orderId: o.id }),
    onAccept: () => { b.setOrderState(o.id, 'accepted'); b.go({ screen: 'printOut', orderId: o.id, kind: 'accept' }); },
    onReject: () => b.setOrderState(o.id, 'rejected'),
    onKOT: () => b.go({ screen: 'printOut', orderId: o.id, kind: 'kot' }),
    onBill: () => { b.setOrderState(o.id, 'completed'); b.go({ screen: 'printOut', orderId: o.id, kind: 'complete' }); },
  });

  const occupied = TABLES.filter((t) => orderForTable(t.id)).length;
  const startNew = () => {
    if (otype === 'delivery') { b.push({ screen: 'deliveryInfo', mode: 'new' }); return; }
    const oid = b.startOrder({ type: otype });
    b.push({ screen: 'orderBuild', orderId: oid });
  };

  return (
    <React.Fragment>
      <Header title={b.t('title.tables')} sub="Spice Garden · Ground floor" big right={<TopActions />} />
      <div style={{ flex: '0 0 auto', padding: '0 16px 14px' }}>
        <div className="seg">
          {[['dinein', 'Dine-in', 'table'], ['parcel', 'Parcel', 'bag'], ['delivery', 'Delivery', 'truck']].map(([id, label, ic]) => (
            <button key={id} className={otype === id ? 'active' : ''} onClick={() => setOtype(id)}><Icon name={ic} size={16} sw={1.9} />{label}</button>
          ))}
        </div>
      </div>

      {otype === 'dinein' ? (
        <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '0 2px 12px' }}>
            <span className="eyebrow">Tap a table to start</span>
            <div style={{ display: 'flex', gap: 12, fontSize: 12, fontWeight: 600 }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, color: 'var(--seat-ink)' }}><span style={{ width: 9, height: 9, borderRadius: 3, background: 'var(--seat-ink)' }} />{occupied} occupied</span>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, color: 'var(--muted)' }}><span style={{ width: 9, height: 9, borderRadius: 3, border: '1.5px solid var(--line-2)' }} />{TABLES.length - occupied} free</span>
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
            {TABLES.map((tb) => {
              const o = orderForTable(tb.id);
              const seated = !!o;
              const total = o ? orderTotal(o.lines) : 0;
              return (
                <div key={tb.id} className="tile" onClick={() => openTable(tb)} style={{ minHeight: 84, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', padding: 12,
                  borderColor: seated ? 'var(--seat-line)' : 'var(--line-2)', background: seated ? 'var(--seat-tint)' : 'var(--surface)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ fontSize: 17, fontWeight: 700, color: 'var(--ink)' }}>{tb.id}</span>
                    <span style={{ width: 8, height: 8, borderRadius: '50%', flex: '0 0 8px', background: seated ? 'var(--seat-ink)' : 'transparent', border: seated ? 'none' : '1.5px solid var(--line-2)' }} />
                  </div>
                  {seated ? (
                    <div>
                      <div style={{ fontSize: 11.5, color: 'var(--seat-ink)', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="clock" size={12} />{o.mins}m</div>
                      <div style={{ fontSize: 15, fontWeight: 700, marginTop: 2 }} className="tab">{money(total)}</div>
                    </div>
                  ) : (
                    <div style={{ fontSize: 12, color: 'var(--placeholder)', fontWeight: 600 }}>Vacant</div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      ) : (
        <React.Fragment>
          <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 12px', display: 'flex', flexDirection: 'column', gap: 11 }}>
            <span className="eyebrow" style={{ margin: '0 2px' }}>{otype === 'delivery' ? 'Delivery orders' : 'Parcel orders'}</span>
            {b.orders.filter((o) => o.type === otype && (o.state === 'pending' || o.state === 'accepted')).map((o) => <OrderCard key={o.id} o={o} {...cardHandlers(o)} />)}
            {b.orders.filter((o) => o.type === otype && (o.state === 'pending' || o.state === 'accepted')).length === 0 && <div style={{ textAlign: 'center', color: 'var(--muted)', padding: '40px 0', fontSize: 14 }}>No active {otype} orders.</div>}
          </div>
          <div className="bottombar">
            <button className="btn btn-primary btn-block btn-lg" onClick={startNew}>
              <Icon name={otype === 'delivery' ? 'truck' : 'plus'} size={20} color="var(--accent-ink)" sw={2.2} />New {otype} order
            </button>
          </div>
        </React.Fragment>
      )}
    </React.Fragment>
  );
}

/* ---------- order build (menu select for a ticket) ---------- */
function OrderBuild({ orderId }) {
  const b = useBytes();
  const o = b.getOrder(orderId);
  const [sheetItem, setSheetItem] = useState(null);
  if (!o) return <div style={{ padding: 20 }}>Order not found.</div>;
  const onAdd = (item) => { if (item.mods.length === 0) b.addOrderLine(orderId, makeLine(item, 1, {}, '')); else setSheetItem(item); };
  const onSub = (item) => {
    const matches = o.lines.filter((l) => l.id === item.id);
    if (!matches.length) return;
    const last = matches[matches.length - 1];
    if (last.qty > 1) b.setOrderLineQty(orderId, last.lid, last.qty - 1);
    else b.removeOrderLine(orderId, last.lid);
  };
  const count = o.lines.reduce((s, l) => s + l.qty, 0);
  const sub = o.lines.reduce((s, l) => s + lineTotal(l), 0);
  const head = o.table ? o.table.replace('T', 'Table ') : typeLabel(o);

  return (
    <React.Fragment>
      <Header title={head} sub="Add menu items" onBack={b.pop}
        right={<span className="badge neutral" style={{ height: 26 }}><Icon name={o.type === 'dinein' ? 'table' : o.type === 'delivery' ? 'truck' : 'bag'} size={14} />{typeLabel(o)}</span>} />
      <MenuBrowser onAdd={onAdd} onSub={onSub} lines={o.lines} />
      <div className="bottombar">
        <button className="btn btn-primary btn-block" style={{ opacity: count ? 1 : .5, pointerEvents: count ? 'auto' : 'none' }} onClick={() => b.push({ screen: 'review', orderId })}>
          <span style={{ width: 24, height: 24, borderRadius: 6, background: 'rgba(20,24,14,.18)', display: 'grid', placeItems: 'center', fontSize: 12.5, fontWeight: 700 }} className="tab">{count}</span>
          <span>Review order</span>
          <span style={{ marginLeft: 'auto', fontWeight: 700 }} className="tab">{money(sub)}</span>
        </button>
      </div>
      {sheetItem && <ItemSheet item={sheetItem} onClose={() => setSheetItem(null)} onConfirm={(line) => b.addOrderLine(orderId, line)} />}
    </React.Fragment>
  );
}

/* ---------- counter mode: quick-sell ring-up grid ---------- */
function CounterScreen() {
  const b = useBytes();
  const [draftId, setDraftId] = useState(null);
  const [cat, setCat] = useState('All');
  const draft = draftId ? b.getOrder(draftId) : null;
  const ensure = () => { if (draftId && b.getOrder(draftId)) return draftId; const id = b.startOrder({ type: 'counter' }); setDraftId(id); return id; };
  const ring = (item) => { const id = ensure(); b.addOrderLine(id, makeLine(item, 1, {}, '')); };
  const items = MENU.filter((m) => (cat === 'All' || m.cat === cat) && m.stock !== 'no');
  const count = draft ? draft.lines.reduce((s, l) => s + l.qty, 0) : 0;
  const sub = draft ? draft.lines.reduce((s, l) => s + lineTotal(l), 0) : 0;
  const counts = useMemo(() => { const c = { All: MENU.length }; CATS.forEach((k) => c[k] = MENU.filter((m) => m.cat === k).length); return c; }, []);

  return (
    <React.Fragment>
      <Header title="Quick sell" sub="Tap to ring up" big right={<TopActions />} />
      <div className="chiprow noscroll" style={{ flex: '0 0 auto', paddingBottom: 12 }}>
        {['All', ...CATS].map((k) => <button key={k} className={'chip' + (cat === k ? ' active' : '')} onClick={() => setCat(k)}>{k}<span className="ct">{counts[k]}</span></button>)}
      </div>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px ' + (count ? 96 : 16) + 'px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {items.map((m) => {
            const inCart = draft ? draft.lines.filter((l) => l.id === m.id).reduce((s, l) => s + l.qty, 0) : 0;
            return (
              <button key={m.id} onClick={() => ring(m)} style={{ position: 'relative', textAlign: 'left', cursor: 'pointer', fontFamily: 'var(--font)', border: '1px solid ' + (inCart ? 'var(--accent-tint-2)' : 'var(--line)'), background: inCart ? 'var(--accent-tint)' : 'var(--surface)', borderRadius: 'var(--r-lg)', padding: 13, minHeight: 92, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', transition: 'transform .05s' }}>
                {inCart > 0 && <span className="tab" style={{ position: 'absolute', top: 10, right: 10, minWidth: 22, height: 22, padding: '0 6px', borderRadius: 11, background: 'var(--accent)', color: 'var(--accent-ink)', fontSize: 12.5, fontWeight: 800, display: 'grid', placeItems: 'center' }}>{inCart}</span>}
                <div style={{ width: 36, height: 36, borderRadius: 9, background: (CAT_TINT[m.cat] || [])[0] || 'var(--surface-2)', display: 'grid', placeItems: 'center' }}><Icon name={(CAT_TINT[m.cat] || [])[2] || 'bag'} size={20} color={(CAT_TINT[m.cat] || [])[1] || 'var(--muted)'} /></div>
                <div>
                  <div style={{ fontSize: 14, fontWeight: 600, lineHeight: 1.25 }} className="ell2">{m.name}</div>
                  <div style={{ fontSize: 14, fontWeight: 700, marginTop: 3 }} className="tab">{money(m.price)}</div>
                </div>
              </button>
            );
          })}
        </div>
      </div>
      {count > 0 && (
        <div className="bottombar">
          <button className="btn btn-ghost" style={{ width: 48, flex: '0 0 48px', padding: 0 }} onClick={() => { b.setOrderState(draftId, 'rejected'); setDraftId(null); }}><Icon name="trash" size={19} /></button>
          <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={() => b.push({ screen: 'review', orderId: draftId })}>
            <span style={{ width: 24, height: 24, borderRadius: 6, background: 'rgba(20,24,14,.18)', display: 'grid', placeItems: 'center', fontSize: 12.5, fontWeight: 700 }} className="tab">{count}</span>
            <span>Charge &amp; print</span><span style={{ marginLeft: 'auto', fontWeight: 700 }} className="tab">{money(sub)}</span>
          </button>
        </div>
      )}
    </React.Fragment>
  );
}

Object.assign(window, { TablesScreen, OrderBuild, CounterScreen });
