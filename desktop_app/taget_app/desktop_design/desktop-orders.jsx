/* ============================================================
   QuickBytes Desktop — Orders: two-pane queue (list + detail).
   Pending → Accept (accent-wash, not solid lime). Accepted →
   Print KOT / Print Bill (Bill → completed). Serial is the hero,
   type replaces the customer name, channel is a quiet glyph.
   ============================================================ */
const { useState: dOrdState, useMemo: dOrdMemo } = React;

function orderTypeLabel(o, lang) {
  if (o.type === 'delivery') return lang === 'bn' ? 'ডেলিভারি' : 'Delivery';
  if (o.type === 'parcel') return lang === 'bn' ? 'পার্সেল' : 'Parcel';
  return (lang === 'bn' ? 'টেবিল ' : 'Table ') + (o.table ? o.table.replace('T', '') : '');
}
function orderTotal(o) {
  const sub = o.lines.reduce((s, l) => s + lineTotal(l), 0) - (o.discount || 0);
  return Math.round(sub * (1 + DK_VAT)) + (o.charge || 0);
}

function OrdersScreen() {
  const d = useDesk();
  const lang = d.lang;
  const [seg, setSeg] = dOrdState('ongoing');
  const [q, setQ] = dOrdState('');
  const list = dOrdMemo(() => {
    const ql = q.trim().toLowerCase();
    return d.orders.filter((o) => {
      const inSeg = seg === 'ongoing' ? (o.state === 'pending' || o.state === 'accepted') : o.state === 'completed';
      if (!inSeg) return false;
      if (!ql) return true;
      return ('' + o.serial).includes(ql) || (o.customer || '').toLowerCase().includes(ql) || orderTypeLabel(o, 'en').toLowerCase().includes(ql);
    });
  }, [d.orders, seg, q]);
  const sel = d.orders.find((o) => o.id === d.selOrder) || list[0];
  const pend = d.orders.filter((o) => o.state === 'pending').length;
  const ong = d.orders.filter((o) => o.state === 'pending' || o.state === 'accepted').length;
  const comp = d.orders.filter((o) => o.state === 'completed').length;

  return (
    <div className="dk-main">
      <DeskHead title={lang === 'bn' ? 'অর্ডার' : 'Orders'} sub={(lang === 'bn' ? 'গ্রহণযোগ্য ' : '') + pend + (lang === 'bn' ? ' অপেক্ষমাণ · ' : ' to accept · ') + ong + (lang === 'bn' ? ' চলমান' : ' ongoing')}
        right={<button className="btn btn-primary" onClick={() => d.setTab('register')}><Icon name="plus" size={18} sw={2.2} />{lang === 'bn' ? 'নতুন অর্ডার' : 'New order'}</button>} />
      <div className="dk-2pane">
        {/* list */}
        <div className="dk-listcol">
          <div style={{ padding: '14px 16px 12px', borderBottom: '1px solid var(--line)', display: 'flex', flexDirection: 'column', gap: 11 }}>
            <DeskField value={q} onChange={setQ} placeholder={lang === 'bn' ? 'অর্ডার খুঁজুন…' : 'Search orders…'} />
            <div className="dk-seg">
              <button className={seg === 'ongoing' ? 'on' : ''} onClick={() => setSeg('ongoing')}>{lang === 'bn' ? 'চলমান' : 'Ongoing'} <span style={{ opacity: .6, marginLeft: 4 }}>{ong}</span></button>
              <button className={seg === 'completed' ? 'on' : ''} onClick={() => setSeg('completed')}>{lang === 'bn' ? 'সম্পন্ন' : 'Completed'} <span style={{ opacity: .6, marginLeft: 4 }}>{comp}</span></button>
            </div>
          </div>
          <div className="scrollY noscroll" style={{ flex: 1 }}>
            {list.map((o) => {
              const ch = CHANNELS[o.channel] || CHANNELS.counter;
              const pending = o.state === 'pending';
              return (
                <div key={o.id} className={'dk-orow' + (sel && sel.id === o.id ? ' on' : '')} onClick={() => d.setSelOrder(o.id)} style={pending ? { boxShadow: 'inset 3px 0 0 var(--accent)' } : null}>
                  <div style={{ width: 38, textAlign: 'center', flex: '0 0 38px' }}><div className="dk-serial">{o.serial}</div></div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                      <span style={{ fontSize: 14.5, fontWeight: 700 }}>{orderTypeLabel(o, lang)}</span>
                      {pending && <span className="badge" style={{ background: 'var(--accent-tint)', color: 'var(--accent-strong)' }}>{lang === 'bn' ? 'নতুন' : 'New'}</span>}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 12.5, color: 'var(--muted)', marginTop: 2 }}>
                      <Icon name={ch[0]} size={13} color={ch[2]} /><span>{ch[1]} · {o.mins}m</span>
                    </div>
                  </div>
                  <div style={{ textAlign: 'right', flex: '0 0 auto' }}>
                    <div className="price">{money(orderTotal(o))}</div>
                    <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 2 }}>{o.lines.reduce((s, l) => s + l.qty, 0)} {lang === 'bn' ? 'আইটেম' : 'items'}</div>
                  </div>
                </div>
              );
            })}
            {list.length === 0 && <div style={{ textAlign: 'center', color: 'var(--muted)', padding: '50px 0', fontSize: 14 }}>{lang === 'bn' ? 'কোনো অর্ডার নেই' : 'No orders here.'}</div>}
          </div>
        </div>
        {/* detail */}
        <div className="dk-detailcol">
          {sel ? <OrderDetail key={sel.id} o={sel} /> : <div style={{ flex: 1, display: 'grid', placeItems: 'center', color: 'var(--muted)' }}>{lang === 'bn' ? 'একটি অর্ডার নির্বাচন করুন' : 'Select an order'}</div>}
        </div>
      </div>
    </div>
  );
}

function OrderDetail({ o }) {
  const d = useDesk();
  const lang = d.lang;
  const ch = CHANNELS[o.channel] || CHANNELS.counter;
  const sub = o.lines.reduce((s, l) => s + lineTotal(l), 0);
  const vat = Math.round((sub - (o.discount || 0)) * DK_VAT);
  const total = orderTotal(o);
  return (
    <React.Fragment>
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: 24 }} className="noscroll">
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
              <span style={{ fontSize: 34, fontWeight: 800, letterSpacing: '-.03em' }}>#{o.serial}</span>
              <span style={{ fontSize: 18, fontWeight: 600, color: 'var(--ink-2)' }}>{orderTypeLabel(o, lang)}</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13.5, color: 'var(--muted)', marginTop: 4 }}>
              <Icon name={ch[0]} size={15} color={ch[2]} /><span>{ch[1]} · {lang === 'bn' ? 'প্লেস করা হয়েছে ' : 'placed '}{o.mins}m {lang === 'bn' ? 'আগে' : 'ago'}</span>
              {o.server && <span>· {lang === 'bn' ? 'ওয়েটার ' : 'Server '}{o.server}</span>}
            </div>
          </div>
          <div style={{ marginLeft: 'auto' }}>
            {o.state === 'pending' ? <span className="badge" style={{ height: 26, padding: '0 11px', background: 'var(--accent-tint)', color: 'var(--accent-strong)' }}>{lang === 'bn' ? 'গ্রহণের অপেক্ষায়' : 'Awaiting accept'}</span>
              : o.state === 'accepted' ? <span className="badge info" style={{ height: 26, padding: '0 11px' }}>{lang === 'bn' ? 'চলমান' : 'Ongoing'}</span>
                : <span className="badge success" style={{ height: 26, padding: '0 11px' }}>{lang === 'bn' ? 'সম্পন্ন' : 'Completed'}</span>}
          </div>
        </div>

        {/* customer / context card */}
        {(o.customer || o.phone || o.addr) && (
          <div className="card" style={{ padding: 16, marginTop: 18, display: 'flex', gap: 22 }}>
            {o.customer && <div><div className="eyebrow">{lang === 'bn' ? 'কাস্টমার' : 'Customer'}</div><div style={{ fontSize: 14.5, fontWeight: 600, marginTop: 3 }}>{o.customer}</div></div>}
            {o.phone && <div><div className="eyebrow">{lang === 'bn' ? 'ফোন' : 'Phone'}</div><div style={{ fontSize: 14.5, fontWeight: 600, marginTop: 3 }} className="tab">{o.phone}</div></div>}
            {o.addr && <div style={{ minWidth: 0 }}><div className="eyebrow">{lang === 'bn' ? 'ঠিকানা' : 'Address'}</div><div style={{ fontSize: 14.5, fontWeight: 600, marginTop: 3 }} className="ell">{o.addr}</div></div>}
          </div>
        )}

        {/* lines */}
        <div className="card" style={{ marginTop: 16, overflow: 'hidden' }}>
          {o.lines.map((l, i) => (
            <div key={l.lid} style={{ display: 'flex', gap: 13, alignItems: 'flex-start', padding: '14px 16px', borderBottom: i < o.lines.length - 1 ? '1px solid var(--line)' : 'none' }}>
              <span className="tab" style={{ fontSize: 15, fontWeight: 700, color: 'var(--ink-2)', flex: '0 0 26px' }}>{l.qty}×</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14.5, fontWeight: 600 }}>{l.name}</div>
                {modSummary(l) && <div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 2 }}>{modSummary(l)}</div>}
              </div>
              <span className="price">{money(lineTotal(l))}</span>
            </div>
          ))}
        </div>

        {/* summary */}
        <div className="card" style={{ marginTop: 16, padding: '14px 18px' }}>
          <div className="summary">
            <div className="sr"><span className="l">{lang === 'bn' ? 'সাবটোটাল' : 'Subtotal'}</span><span className="v tab">{money(sub)}</span></div>
            {o.discount > 0 && <div className="sr"><span className="l" style={{ color: 'var(--accent-strong)' }}>{lang === 'bn' ? 'ছাড়' : 'Discount'}</span><span className="v tab" style={{ color: 'var(--accent-strong)' }}>−{money(o.discount)}</span></div>}
            <div className="sr"><span className="l">{lang === 'bn' ? 'ভ্যাট' : 'VAT'} (5%)</span><span className="v tab">{money(vat)}</span></div>
            {o.charge > 0 && <div className="sr"><span className="l">{lang === 'bn' ? 'ডেলিভারি' : 'Delivery'}{o.area ? ' · ' + o.area : ''}</span><span className="v tab">{money(o.charge)}</span></div>}
            <div className="total"><span className="l">{lang === 'bn' ? 'মোট' : 'Total'}</span><span className="v tab">{money(total)}</span></div>
          </div>
        </div>
      </div>

      {/* action bar */}
      <div style={{ flex: '0 0 auto', borderTop: '1px solid var(--line)', padding: '14px 24px', background: 'var(--surface)', display: 'flex', gap: 10 }}>
        {o.state === 'pending' ? (
          <React.Fragment>
            <button className="btn btn-ghost btn-lg" onClick={() => d.rejectOrder(o.id)} style={{ flex: '0 0 auto', color: 'var(--danger)' }}><Icon name="x" size={18} sw={2} />{lang === 'bn' ? 'বাতিল' : 'Reject'}</button>
            <button className="btn btn-soft btn-lg" style={{ flex: 1 }} onClick={() => d.acceptOrder(o.id)}><Icon name="check" size={19} sw={2.2} />{lang === 'bn' ? 'গ্রহণ করুন ও KOT প্রিন্ট' : 'Accept & print KOT'}</button>
          </React.Fragment>
        ) : o.state === 'accepted' ? (
          <React.Fragment>
            <button className="btn btn-ghost btn-lg" style={{ flex: 1 }} onClick={() => d.toast(lang === 'bn' ? 'KOT প্রিন্ট হচ্ছে' : 'Printing KOT')}><Icon name="printer" size={18} />{lang === 'bn' ? 'KOT প্রিন্ট' : 'Print KOT'}</button>
            <button className="btn btn-primary btn-lg" style={{ flex: 1.3 }} onClick={() => d.completeOrder(o.id)}><Icon name="taka" size={18} sw={2} />{lang === 'bn' ? 'বিল প্রিন্ট ও সম্পন্ন' : 'Print bill & complete'}</button>
          </React.Fragment>
        ) : (
          <button className="btn btn-ghost btn-lg btn-block" onClick={() => d.toast(lang === 'bn' ? 'রসিদ রিপ্রিন্ট' : 'Reprinting receipt')}><Icon name="printer" size={18} />{lang === 'bn' ? 'রসিদ রিপ্রিন্ট' : 'Reprint receipt'}</button>
        )}
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { OrdersScreen, orderTotal, orderTypeLabel });
