/* ============================================================
   Bytes POS — Review + Print success (KOT · Token · Bill)
   ============================================================ */

function ReviewScreen({ orderId }) {
  const b = useBytes();
  const o = b.getOrder(orderId);
  const [disc, setDisc] = useState(0);
  if (!o) return <div style={{ padding: 20 }}>Order not found.</div>;
  const count = o.lines.reduce((s, l) => s + l.qty, 0);
  const charge = orderCharge(o);
  const head = o.table ? o.table.replace('T', 'Table ') : typeLabel(o);
  const sub = o.lines.reduce((s, l) => s + lineTotal(l), 0);
  const presets = b.settings.discounts.slice(0, 4);

  const confirm = () => {
    b.setOrderDiscount(orderId, disc);
    b.setOrderState(orderId, 'accepted');
    b.go({ screen: 'printOut', orderId, kind: 'new' });
  };

  return (
    <React.Fragment>
      <Header title={b.t('act.review')} sub={head + ' · #' + o.token} onBack={b.pop}
        right={<span className="badge neutral" style={{ height: 26 }}>{count} {b.t('word.items')}</span>} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <button onClick={b.pop} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 9, padding: '11px 13px', marginBottom: 12, border: '1px dashed var(--line-2)', borderRadius: 'var(--r-md)', background: 'var(--surface)', cursor: 'pointer', color: 'var(--accent-strong)', fontWeight: 600, fontSize: 14 }}><Icon name="plus" size={18} sw={2} />Add more items</button>

        <LineList lines={o.lines} editable onQty={(lid, q) => b.setOrderLineQty(orderId, lid, q)} onRemove={(lid) => b.removeOrderLine(orderId, lid)} />

        {/* quick discount — from your configured presets */}
        <div className="card" style={{ padding: 14, marginTop: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}><Icon name="tag" size={17} color="var(--accent-strong)" /><span style={{ fontSize: 14, fontWeight: 600 }}>Discount</span></div>
          <div className="seg">
            <button className={disc === 0 ? 'active' : ''} onClick={() => setDisc(0)}>None</button>
            {presets.map((d, i) => {
              const amt = d.kind === 'pct' ? Math.round(sub * d.val / 100) : d.val;
              return <button key={i} className={disc === amt && disc !== 0 ? 'active' : ''} onClick={() => setDisc(amt)}>{d.label}</button>;
            })}
          </div>
        </div>

        <div className="card" style={{ padding: 16, marginTop: 14 }}><OrderSummary lines={o.lines} discount={disc} charge={charge} /></div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 14, padding: '0 2px', color: 'var(--muted)', fontSize: 12.5 }}>
          <Icon name="printer" size={15} /><span>Confirming prints the KOT, customer token &amp; bill</span>
        </div>
      </div>
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg" disabled={count === 0} onClick={confirm}>
          <Icon name="check" size={19} color="var(--accent-ink)" sw={2.4} />{b.t('act.confirmPrint')}
          <span style={{ marginLeft: 'auto', fontWeight: 700 }} className="tab">{money(orderTotal(o.lines, disc, charge))}</span>
        </button>
      </div>
    </React.Fragment>
  );
}

/* ---------- delivery details — collected up front for delivery orders ---------- */
const DField = ({ label, children }) => (
  <div style={{ marginBottom: 14 }}><div className="eyebrow" style={{ marginBottom: 8 }}>{label}</div>{children}</div>
);
function DeliveryInfo({ orderId, mode }) {
  const b = useBytes();
  const isNew = mode === 'new';
  const o = orderId ? b.getOrder(orderId) : null;
  const areas = b.settings.areas;
  const [name, setName] = useState(o && o.customer && !o.customer.startsWith('New') ? o.customer : '');
  const [phone, setPhone] = useState((o && o.phone) || '');
  const [addr, setAddr] = useState((o && o.addr) || '');
  const [area, setArea] = useState((o && o.area) || areas[0].name);
  const charge = (areas.find((a) => a.name === area) || areas[0]).charge;
  const valid = name.trim() && phone.trim().length >= 6 && addr.trim();

  const confirm = () => {
    const info = { customer: name.trim() || 'Delivery', phone: phone.trim(), addr: addr.trim(), area, charge };
    if (isNew) {
      const id = b.startOrder({ type: 'delivery', channel: 'manager', ...info });
      b.go({ screen: 'orderBuild', orderId: id });
    } else {
      b.setOrderInfo(orderId, info);
      b.pop();
    }
  };
  const Field = DField;

  return (
    <React.Fragment>
      <Header title="Delivery details" sub={isNew ? 'Step 1 · recipient & address' : 'Edit recipient & address'} onBack={b.pop}
        right={<span className="badge neutral" style={{ height: 26 }}><Icon name="truck" size={14} />{b.t('word.delivery')}</span>} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <Field label="Recipient name"><div className="field"><Icon name="user" size={18} /><input value={name} onChange={(e) => setName(e.target.value)} placeholder="Customer name" /></div></Field>
        <Field label="Phone number"><div className="field"><Icon name="phone" size={17} /><input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="01XXX-XXXXXX" inputMode="tel" /></div></Field>
        <Field label="Delivery address"><textarea value={addr} onChange={(e) => setAddr(e.target.value)} placeholder="House, road, area, landmark…" style={{ width: '100%', minHeight: 64, resize: 'none', border: '1px solid var(--line-2)', borderRadius: 'var(--r-md)', padding: 11, font: 'inherit', fontSize: 15, color: 'var(--ink)', outline: 'none', background: 'var(--surface)' }} /></Field>
        <Field label="Area · sets delivery charge">
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {areas.map((a) => (
              <button key={a.name} onClick={() => setArea(a.name)} style={{ height: 40, padding: '0 13px', borderRadius: 'var(--r-md)', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 13.5, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 7,
                border: '1px solid ' + (area === a.name ? 'var(--accent-press)' : 'var(--line-2)'), background: area === a.name ? 'var(--accent-tint)' : 'var(--surface)', color: area === a.name ? 'var(--accent-strong)' : 'var(--ink-2)' }}>
                {a.name}<span className="tab" style={{ fontSize: 12, color: area === a.name ? 'var(--accent-strong)' : 'var(--muted)' }}>{money(a.charge)}</span>
              </button>
            ))}
          </div>
        </Field>
      </div>
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg" disabled={!valid} onClick={confirm}>
          {isNew ? <React.Fragment><Icon name="arrowr" size={19} color="var(--accent-ink)" />Continue to menu</React.Fragment> : <React.Fragment><Icon name="check" size={19} color="var(--accent-ink)" sw={2.4} />{b.t('act.save')}</React.Fragment>}
          <span style={{ marginLeft: 'auto', fontWeight: 700 }} className="tab">{money(charge)} delivery</span>
        </button>
      </div>
    </React.Fragment>
  );
}

/* ---------- printable doc preview (thermal receipt look) ---------- */
function PrintDoc({ kind, o }) {
  const charge = orderCharge(o);
  const total = orderTotal(o.lines, o.discount || 0, charge);
  const head = o.table ? o.table.replace('T', 'Table ') : typeLabel(o);
  const wrap = { fontFamily: "'Inter', monospace", background: '#fff', border: '1px solid var(--line-2)', borderRadius: 'var(--r-sm)', padding: '16px 16px', color: '#14180E' };
  const dashed = { borderTop: '1px dashed #B9BDAE', margin: '10px 0' };

  if (kind === 'token') {
    return (
      <div style={{ ...wrap, textAlign: 'center', padding: '20px 16px' }}>
        <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '.1em', color: '#7C8270' }}>SPICE GARDEN</div>
        <div style={{ fontSize: 13, color: '#7C8270', marginTop: 8, fontWeight: 600 }}>YOUR TOKEN</div>
        <div style={{ fontSize: 64, fontWeight: 800, letterSpacing: '-.02em', lineHeight: 1, margin: '6px 0' }} className="tab">{o.token}</div>
        <div style={{ ...dashed }} />
        <div style={{ fontSize: 13, fontWeight: 600 }}>{head} · {o.lines.reduce((s, l) => s + l.qty, 0)} items</div>
        <div style={{ fontSize: 12, color: '#7C8270', marginTop: 4 }}>Please wait for your number</div>
      </div>
    );
  }
  if (kind === 'kot') {
    return (
      <div style={wrap}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <span style={{ fontSize: 15, fontWeight: 800, letterSpacing: '.04em' }}>KITCHEN — KOT</span>
          <span style={{ fontSize: 14, fontWeight: 700 }} className="tab">#{o.token}</span>
        </div>
        <div style={{ fontSize: 12, color: '#7C8270', marginTop: 3, fontWeight: 600 }}>{head} · {typeLabel(o)} · 7:42 PM</div>
        <div style={dashed} />
        {o.lines.map((l) => (
          <div key={l.lid} style={{ marginBottom: 9 }}>
            <div style={{ display: 'flex', gap: 8 }}>
              <span style={{ fontSize: 16, fontWeight: 800, minWidth: 22 }} className="tab">{l.qty}×</span>
              <span style={{ fontSize: 15, fontWeight: 700, flex: 1 }}>{l.name}</span>
            </div>
            {modSummary(l) && <div style={{ fontSize: 12.5, color: '#4C5142', paddingLeft: 30, marginTop: 1 }}>↳ {modSummary(l)}</div>}
          </div>
        ))}
        <div style={dashed} />
        <div style={{ fontSize: 12, color: '#7C8270', textAlign: 'center', fontWeight: 600 }}>{o.lines.reduce((s, l) => s + l.qty, 0)} items · fire now</div>
      </div>
    );
  }
  // bill
  return (
    <div style={wrap}>
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '.06em' }}>SPICE GARDEN</div>
        <div style={{ fontSize: 11.5, color: '#7C8270', marginTop: 2 }}>Road 7, Dhanmondi · 01711-000000</div>
        <div style={{ fontSize: 11.5, color: '#7C8270' }}>BIN: 0041-2938-1029</div>
      </div>
      <div style={dashed} />
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, color: '#4C5142', fontWeight: 600 }}><span>#{o.token} · {head}</span><span>7:42 PM</span></div>
      <div style={dashed} />
      {o.lines.map((l) => (
        <div key={l.lid} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13.5, marginBottom: 6 }}>
          <span style={{ flex: 1 }}><span style={{ fontWeight: 700 }} className="tab">{l.qty}× </span>{l.name}</span>
          <span style={{ fontWeight: 600 }} className="tab">{money(lineTotal(l))}</span>
        </div>
      ))}
      <div style={dashed} />
      <Row l="Subtotal" v={money(o.lines.reduce((s, l) => s + lineTotal(l), 0))} />
      {o.discount > 0 && <Row l="Discount" v={'−' + money(o.discount)} />}
      <Row l="VAT 5%" v={money((o.lines.reduce((s, l) => s + lineTotal(l), 0) - (o.discount || 0)) * 0.05)} />
      {charge > 0 && <Row l="Delivery" v={money(charge)} />}
      <div style={dashed} />
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 18, fontWeight: 800 }}><span>TOTAL</span><span className="tab">{money(total)}</span></div>
      <div style={{ fontSize: 11.5, color: '#7C8270', textAlign: 'center', marginTop: 12 }}>Thank you · ধন্যবাদ</div>
    </div>
  );
}
function Row({ l, v }) { return <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, color: '#4C5142', padding: '2px 0' }}><span>{l}</span><span className="tab" style={{ fontWeight: 600 }}>{v}</span></div>; }

/* ---------- success screen — hero token + print actions ---------- */
function PrintOut({ orderId, kind }) {
  const b = useBytes();
  const o = b.getOrder(orderId);
  const [sent, setSent] = useState({});
  if (!o) return <div style={{ padding: 20 }}>Order closed.</div>;
  const title = kind === 'reprint' ? 'Reprint ready' : kind === 'accept' ? 'Order accepted' : kind === 'kot' ? 'Kitchen ticket sent' : kind === 'complete' ? 'Order completed' : 'Order confirmed';
  const head = o.table ? o.table.replace('T', 'Table ') : typeLabel(o);
  const total = orderTotal(o.lines, o.discount || 0, orderCharge(o));
  const count = o.lines.reduce((s, l) => s + l.qty, 0);
  const docs = [['kot', 'KOT', 'flame', 'Kitchen'], ['token', 'Token', 'receipt', 'Customer'], ['bill', 'Bill', 'coins', 'Payment']];

  return (
    <React.Fragment>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '20px 22px', textAlign: 'center' }}>
        {/* success mark */}
        <div style={{ width: 68, height: 68, borderRadius: 19, background: 'var(--accent)', display: 'grid', placeItems: 'center', margin: '0 auto 18px' }}><Icon name="check" size={36} color="var(--accent-ink)" sw={2.8} /></div>
        <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-.02em' }}>{title}</div>
        <div style={{ fontSize: 13.5, color: 'var(--muted)', marginTop: 5 }}>{head} · {count} items · {money(total)}</div>

        {/* hero token */}
        <div style={{ margin: '26px auto 0', maxWidth: 280, padding: '22px 18px', borderRadius: 'var(--r-xl)', background: 'var(--accent-tint)', border: '1px solid var(--accent-tint-2)' }}>
          <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '.12em', color: 'var(--accent-strong)' }}>CUSTOMER TOKEN</div>
          <div style={{ fontSize: 76, fontWeight: 800, letterSpacing: '-.03em', lineHeight: 1, margin: '8px 0 4px' }} className="tab">{o.token}</div>
          <div style={{ fontSize: 12.5, color: 'var(--ink-2)', fontWeight: 500 }}>Order #{o.serial} · {head}</div>
        </div>

        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 16, fontSize: 12.5, color: 'var(--success)', fontWeight: 600 }}>
          <Icon name="check2" size={15} sw={2.2} />All tickets sent to printer
        </div>
      </div>

      {/* print actions around the bottom */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 10px', display: 'flex', gap: 8 }}>
        {docs.map(([id, label, ic, role]) => {
          const on = sent[id];
          return (
            <button key={id} onClick={() => setSent((s) => ({ ...s, [id]: true }))} style={{ flex: 1, minWidth: 0, height: 66, borderRadius: 'var(--r-lg)', cursor: 'pointer', fontFamily: 'var(--font)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 5,
              border: '1px solid ' + (on ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: on ? 'var(--accent-tint)' : 'var(--surface)', color: on ? 'var(--accent-strong)' : 'var(--ink-2)' }}>
              <Icon name={on ? 'check2' : 'printer'} size={19} sw={on ? 2.3 : 1.8} />
              <span style={{ fontSize: 12.5, fontWeight: 700 }}>{label}</span>
              <span style={{ fontSize: 10, color: 'var(--muted)', fontWeight: 500 }}>{on ? 'Reprint' : role}</span>
            </button>
          );
        })}
      </div>

      <div className="bottombar" style={{ gap: 9 }}>
        <button className="btn btn-ghost btn-lg" style={{ flex: '0 0 auto', width: 116 }} onClick={() => { b.reset(); b.setTab('tables'); }}>{b.t('act.newOrder')}</button>
        <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={() => { b.reset(); b.setTab('orders'); }}>{b.t('act.done')}</button>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { ReviewScreen, DeliveryInfo, PrintDoc, PrintOut });
