/* ============================================================
   QuickBytes Desktop — Register (the counter station heart):
   menu grid + persistent order ticket, modifier modal, payment
   (cash keypad / card / mobile), success token. Accept-wash for
   emphasis; the single solid-lime action per view is Charge/Pay.
   ============================================================ */
const { useState: dRegState, useMemo: dRegMemo } = React;

const DK_VAT = 0.05;
function deskTotals(draft) {
  const subtotal = draft.lines.reduce((s, l) => s + lineTotal(l), 0);
  let disc = 0;
  if (draft.discount) disc = draft.discount.kind === 'pct' ? Math.round(subtotal * draft.discount.val / 100) : draft.discount.val;
  disc = Math.min(disc, subtotal);
  const vat = Math.round((subtotal - disc) * DK_VAT);
  const charge = draft.type === 'delivery' ? (draft.charge || 0) : 0;
  const total = subtotal - disc + vat + charge;
  return { subtotal, disc, vat, charge, total, count: draft.lines.reduce((s, l) => s + l.qty, 0) };
}
function deliveryValid(draft) {
  return draft.type !== 'delivery' || (draft.customer.trim() && draft.phone.trim().length >= 6 && draft.addr.trim() && draft.area);
}

/* ---------- order-type segmented ---------- */
const DK_TYPES = [['dinein', 'Dine-in', 'ডাইন-ইন', 'table'], ['parcel', 'Parcel', 'পার্সেল', 'bag'], ['delivery', 'Delivery', 'ডেলিভারি', 'truck']];

/* ============================ REGISTER ============================ */
function Register() {
  const d = useDesk();
  const [cat, setCat] = dRegState('All');
  const [q, setQ] = dRegState('');
  const lang = d.lang;
  const menu = dRegMemo(() => {
    const ql = q.trim().toLowerCase();
    return MENU.filter((m) => (cat === 'All' || m.cat === cat) && (!ql || m.name.toLowerCase().includes(ql) || m.cat.toLowerCase().includes(ql)));
  }, [cat, q]);
  const qtyById = dRegMemo(() => {
    const m = {};
    d.draft.lines.forEach((l) => { m[l.id] = (m[l.id] || 0) + l.qty; });
    return m;
  }, [d.draft.lines]);

  return (
    <div className="dk-reg">
      {/* ---- menu column ---- */}
      <div className="dk-menucol">
        <div className="dk-menubar">
          <div className="dk-seg" style={{ flex: '0 0 auto' }}>
            {DK_TYPES.map(([id, en, bn, ic]) => (
              <button key={id} className={d.draft.type === id ? 'on' : ''} onClick={() => d.setType(id)}>
                <Icon name={ic} size={17} />{lang === 'bn' ? bn : en}
              </button>
            ))}
          </div>
          <DeskField value={q} onChange={setQ} placeholder={lang === 'bn' ? 'মেনু খুঁজুন…' : 'Search the menu…'} />
          <div style={{ marginLeft: 'auto', fontSize: 12.5, color: 'var(--muted)', fontWeight: 500 }}>{lang === 'bn' ? 'যোগ করতে আইটেমে চাপুন' : 'Tap an item to add it'}</div>
        </div>
        <div className="dk-catrow noscroll">
          {['All', ...CATS].map((c) => (
            <button key={c} className={'chip dk-chip-lg' + (cat === c ? ' active' : '')} onClick={() => setCat(c)}>{c === 'All' ? (lang === 'bn' ? 'সব' : 'All') : c}</button>
          ))}
        </div>
        <div className="dk-menuscroll noscroll">
          <div className="dk-grid">
            {menu.map((m) => {
              const tint = CAT_TINT[m.cat] || ['#ECEFE4', '#7C8270', 'bag'];
              const n = qtyById[m.id] || 0;
              const out = m.stock === 'no';
              return (
                <button key={m.id} className={'dk-card' + (n > 0 ? ' sel' : '')} disabled={out} onClick={() => d.pickItem(m)}>
                  <div className="pic" style={{ background: tint[0] }}>
                    <Icon name={tint[2]} size={42} color={tint[1]} sw={1.6} />
                    {n > 0 && <span className="qbadge tab">{n}</span>}
                    {m.mods && m.mods.length > 0 && <span className="modtag"><Icon name="sort" size={12} />{lang === 'bn' ? 'অপশন' : 'Options'}</span>}
                    {m.stock === 'low' && <span style={{ position: 'absolute', right: 8, bottom: 8 }}><Status kind="low">{lang === 'bn' ? 'কম' : 'Low'}</Status></span>}
                    {out && <div className="soldout"><span className="badge danger">{lang === 'bn' ? 'শেষ' : 'Sold out'}</span></div>}
                  </div>
                  <div className="body">
                    <div className="nm">{m.name}</div>
                    <div className="ds ell">{m.desc}</div>
                    <div className="ft"><span className="pr">{money(m.price)}</span></div>
                  </div>
                </button>
              );
            })}
          </div>
          {menu.length === 0 && <div style={{ textAlign: 'center', color: 'var(--muted)', padding: '60px 0', fontSize: 14 }}>{lang === 'bn' ? 'কিছু পাওয়া যায়নি' : 'Nothing matches that search.'}</div>}
        </div>
      </div>

      {/* ---- ticket ---- */}
      <Ticket />

      {d.modItem && <ModifierModal />}
      {d.pay && <PaymentModal />}
      {d.success && <SuccessOverlay />}
    </div>
  );
}

/* ============================ TICKET ============================ */
function Ticket() {
  const d = useDesk();
  const lang = d.lang;
  const dr = d.draft;
  const t = deskTotals(dr);
  const valid = deliveryValid(dr);
  const ctx = dr.type === 'dinein' ? (dr.table ? (lang === 'bn' ? 'টেবিল ' : 'Table ') + dr.table.replace('T', '') : (lang === 'bn' ? 'টেবিল নির্বাচন করুন' : 'Pick a table'))
    : dr.type === 'parcel' ? (lang === 'bn' ? 'পার্সেল · টেকঅ্যাওয়ে' : 'Parcel · Takeaway')
      : (lang === 'bn' ? 'ডেলিভারি' : 'Delivery order');
  const typeMeta = DK_TYPES.find((x) => x[0] === dr.type);

  return (
    <div className="dk-ticket">
      <div className="dk-tk-head">
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 34, height: 34, borderRadius: 8, background: 'var(--accent-tint)', display: 'grid', placeItems: 'center', flex: '0 0 34px' }}><Icon name={typeMeta[3]} size={19} color="var(--accent-strong)" /></div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 16, fontWeight: 700 }} className="ell">{ctx}</div>
            <div style={{ fontSize: 12, color: 'var(--muted)' }}>{lang === 'bn' ? (typeMeta[2] + ' অর্ডার') : (typeMeta[1] + ' order')}</div>
          </div>
          {dr.lines.length > 0 && (
            <button className="dk-xbtn" title="Clear order" onClick={d.clearDraft} style={{ width: 34, height: 34 }}><Icon name="trash" size={16} /></button>
          )}
        </div>
        {dr.type === 'dinein' && <TableField />}
        {dr.type === 'delivery' && <DeliveryForm />}
        {dr.type === 'parcel' && <ParcelField />}
      </div>

      <div className="dk-tk-body noscroll">
        {dr.lines.length === 0 ? (
          <div style={{ flex: 1, display: 'grid', placeItems: 'center', textAlign: 'center', padding: '30px 20px' }}>
            <div>
              <div style={{ width: 60, height: 60, borderRadius: 16, background: 'var(--surface-2)', display: 'grid', placeItems: 'center', margin: '0 auto 14px' }}><Icon name="bag" size={28} color="var(--placeholder)" /></div>
              <div style={{ fontSize: 15, fontWeight: 600, color: 'var(--ink-2)' }}>{lang === 'bn' ? 'অর্ডার খালি' : 'No items yet'}</div>
              <div style={{ fontSize: 13, color: 'var(--muted)', marginTop: 4, maxWidth: 220 }}>{lang === 'bn' ? 'বাম পাশের মেনু থেকে আইটেম যোগ করুন' : 'Tap dishes on the left to build this order.'}</div>
            </div>
          </div>
        ) : dr.lines.map((l) => (
          <div key={l.lid} className="dk-tkline">
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="nm">{l.name}</div>
              {modSummary(l) && <div className="md">{modSummary(l)}</div>}
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 8 }}>
                <div className="qty">
                  <button onClick={() => d.setQty(l.lid, l.qty - 1)}><Icon name="minus" size={15} /></button>
                  <span className="v tab">{l.qty}</span>
                  <button onClick={() => d.setQty(l.lid, l.qty + 1)}><Icon name="plus" size={15} /></button>
                </div>
                <button className="dk-xbtn" onClick={() => d.removeLine(l.lid)}><Icon name="trash" size={14} /></button>
              </div>
            </div>
            <div className="lp">{money(lineTotal(l))}</div>
          </div>
        ))}
      </div>

      <div className="dk-tk-foot">
        {dr.lines.length > 0 && (
          <React.Fragment>
            <div style={{ display: 'flex', gap: 6, overflowX: 'auto', paddingBottom: 12 }} className="noscroll">
              <button className={'chip' + (!dr.discount ? ' active' : '')} onClick={() => d.setDiscount(null)}>{lang === 'bn' ? 'ছাড় নেই' : 'No disc.'}</button>
              {DISCOUNT_PRESETS.map(([label, kind, val]) => {
                const on = dr.discount && dr.discount.label === label;
                return <button key={label} className={'chip tint' + (on ? ' active' : '')} onClick={() => d.setDiscount({ label, kind, val })}>{label}</button>;
              })}
            </div>
            <div className="summary" style={{ marginBottom: 12 }}>
              <div className="sr"><span className="l">{lang === 'bn' ? 'সাবটোটাল' : 'Subtotal'}</span><span className="v tab">{money(t.subtotal)}</span></div>
              {t.disc > 0 && <div className="sr"><span className="l" style={{ color: 'var(--accent-strong)' }}>{lang === 'bn' ? 'ছাড়' : 'Discount'} ({dr.discount.label})</span><span className="v tab" style={{ color: 'var(--accent-strong)' }}>−{money(t.disc)}</span></div>}
              <div className="sr"><span className="l">{lang === 'bn' ? 'ভ্যাট' : 'VAT'} (5%)</span><span className="v tab">{money(t.vat)}</span></div>
              {dr.type === 'delivery' && <div className="sr"><span className="l">{lang === 'bn' ? 'ডেলিভারি' : 'Delivery'}{dr.area ? ' · ' + dr.area : ''}</span><span className="v tab">{money(t.charge)}</span></div>}
            </div>
          </React.Fragment>
        )}
        <div style={{ display: 'flex', gap: 8, marginBottom: 9 }}>
          <button className="btn btn-ghost" style={{ flex: 1 }} disabled={!dr.lines.length} onClick={() => d.toast(lang === 'bn' ? 'অর্ডার হোল্ডে রাখা হয়েছে' : 'Order held')}><Icon name="clock" size={17} />{lang === 'bn' ? 'হোল্ড' : 'Hold'}</button>
          <button className="btn btn-ghost" style={{ flex: 1 }} disabled={!dr.lines.length} onClick={() => d.toast(lang === 'bn' ? 'KOT রান্নাঘরে পাঠানো হয়েছে' : 'KOT sent to kitchen')}><Icon name="printer" size={17} />KOT</button>
        </div>
        <button className="btn btn-primary btn-lg btn-block" disabled={!dr.lines.length || !valid} onClick={d.openPay}>
          <Icon name="taka" size={19} sw={2} />
          {lang === 'bn' ? 'চার্জ' : 'Charge'} {money(t.total)}
        </button>
        {!valid && dr.lines.length > 0 && <div style={{ fontSize: 12, color: 'var(--warning)', textAlign: 'center', marginTop: 8 }}>{lang === 'bn' ? 'ডেলিভারির তথ্য পূরণ করুন' : 'Complete delivery details to charge'}</div>}
      </div>
    </div>
  );
}

/* ---------- table picker (dine-in) ---------- */
function TableField() {
  const d = useDesk();
  const [open, setOpen] = dRegState(false);
  const lang = d.lang;
  return (
    <div style={{ position: 'relative', marginTop: 12 }}>
      <button onClick={() => setOpen((v) => !v)} className="field" style={{ width: '100%', cursor: 'pointer', justifyContent: 'space-between' }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: 9 }}><Icon name="table" size={18} color="var(--muted)" /><span style={{ fontSize: 14, fontWeight: 600, color: d.draft.table ? 'var(--ink)' : 'var(--placeholder)' }}>{d.draft.table ? (lang === 'bn' ? 'টেবিল ' : 'Table ') + d.draft.table.replace('T', '') : (lang === 'bn' ? 'টেবিল নির্বাচন করুন' : 'Select a table')}</span></span>
        <Icon name="chevd" size={16} color="var(--muted)" />
      </button>
      {open && (
        <React.Fragment>
          <div onClick={() => setOpen(false)} style={{ position: 'fixed', inset: 0, zIndex: 30 }} />
          <div className="dk-pop dk-fadein" style={{ left: 0, right: 0, top: 50, zIndex: 31, padding: 12 }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 7 }}>
              {TABLES.map((tb) => {
                const occ = d.occupiedTables[tb.id];
                const sel = d.draft.table === tb.id;
                return (
                  <button key={tb.id} disabled={occ} onClick={() => { d.setTable(tb.id); setOpen(false); }} style={{ height: 46, borderRadius: 'var(--r-md)', border: '1px solid ' + (sel ? 'var(--accent)' : occ ? 'var(--seat-line)' : 'var(--line-2)'), background: sel ? 'var(--accent-tint)' : occ ? 'var(--seat-tint)' : 'var(--surface)', cursor: occ ? 'not-allowed' : 'pointer', fontFamily: 'var(--font)', fontSize: 14, fontWeight: 700, color: occ ? 'var(--seat-ink)' : 'var(--ink)', opacity: occ ? 0.6 : 1 }}>{tb.id.replace('T', '')}</button>
                );
              })}
            </div>
          </div>
        </React.Fragment>
      )}
    </div>
  );
}

/* ---------- parcel customer (optional) ---------- */
function ParcelField() {
  const d = useDesk();
  const lang = d.lang;
  return (
    <div className="field" style={{ marginTop: 12 }}>
      <Icon name="user" size={18} />
      <input value={d.draft.customer} onChange={(e) => d.setDraftField('customer', e.target.value)} placeholder={lang === 'bn' ? 'কাস্টমারের নাম (ঐচ্ছিক)' : 'Customer name (optional)'} />
    </div>
  );
}

/* ---------- delivery form (form-first, inline in ticket) ---------- */
function DeliveryForm() {
  const d = useDesk();
  const lang = d.lang;
  return (
    <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div className="field"><Icon name="user" size={18} /><input value={d.draft.customer} onChange={(e) => d.setDraftField('customer', e.target.value)} placeholder={lang === 'bn' ? 'প্রাপকের নাম' : 'Recipient name'} /></div>
      <div className="field"><Icon name="phone" size={18} /><input value={d.draft.phone} onChange={(e) => d.setDraftField('phone', e.target.value)} placeholder="01XXX-XXXXXX" inputMode="tel" /></div>
      <div className="field"><Icon name="pin" size={18} /><input value={d.draft.addr} onChange={(e) => d.setDraftField('addr', e.target.value)} placeholder={lang === 'bn' ? 'বাসা, রোড, এলাকা' : 'House, road, landmark'} /></div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        {DELIVERY_AREAS.map(([name, charge]) => {
          const on = d.draft.area === name;
          return <button key={name} className={'chip' + (on ? ' active' : '')} onClick={() => d.setArea(name, charge)}>{name} <span className="ct">{money(charge)}</span></button>;
        })}
      </div>
    </div>
  );
}

/* ============================ MODIFIER MODAL ============================ */
function ModifierModal() {
  const d = useDesk();
  const item = d.modItem;
  const lang = d.lang;
  const groups = (item.mods || []).map((g) => [g, MODS[g]]).filter((x) => x[1]);
  const initSel = {};
  groups.forEach(([id, g]) => { if (g.type === 'single') initSel[id] = g.req ? g.opts[0][0] : (g.opts[0][0]); else initSel[id] = []; });
  const [sel, setSel] = dRegState(initSel);
  const [qty, setQty] = dRegState(1);
  const [note, setNote] = dRegState('');
  const tmpLine = makeLine(item, qty, sel, note);
  const unit = lineUnit(tmpLine);

  const toggle = (gid, g, optId) => {
    setSel((s) => {
      if (g.type === 'single') return { ...s, [gid]: optId };
      const arr = s[gid] || [];
      return { ...s, [gid]: arr.includes(optId) ? arr.filter((x) => x !== optId) : [...arr, optId] };
    });
  };

  return (
    <div className="dk-scrim" onClick={d.closeMod}>
      <div className="dk-modal dk-fadein" style={{ width: 540, maxHeight: 680 }} onClick={(e) => e.stopPropagation()}>
        <div style={{ display: 'flex', gap: 14, padding: '18px 20px', borderBottom: '1px solid var(--line)', alignItems: 'center' }}>
          <Thumb cat={item.cat} size={52} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{item.name}</div>
            <div style={{ fontSize: 13, color: 'var(--muted)' }} className="ell">{item.desc}</div>
          </div>
          <button className="dk-xbtn" style={{ width: 34, height: 34 }} onClick={d.closeMod}><Icon name="x" size={17} /></button>
        </div>
        <div className="scrollY" style={{ padding: '6px 20px 16px', flex: 1 }}>
          {groups.map(([gid, g]) => (
            <div key={gid} style={{ padding: '14px 0', borderBottom: '1px solid var(--line)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                <span style={{ fontSize: 14, fontWeight: 700 }}>{g.label}</span>
                {g.req && <span className="badge neutral">{lang === 'bn' ? 'প্রয়োজন' : 'Required'}</span>}
                <span style={{ fontSize: 12, color: 'var(--muted)', marginLeft: 'auto' }}>{g.type === 'single' ? (lang === 'bn' ? 'একটি বাছুন' : 'Pick one') : (lang === 'bn' ? 'একাধিক' : 'Any number')}</span>
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {g.opts.map(([oid, olabel, delta]) => {
                  const on = g.type === 'single' ? sel[gid] === oid : (sel[gid] || []).includes(oid);
                  return (
                    <button key={oid} onClick={() => toggle(gid, g, oid)} style={{ height: 42, padding: '0 14px', borderRadius: 'var(--r-md)', border: '1px solid ' + (on ? 'var(--accent)' : 'var(--line-2)'), background: on ? 'var(--accent-tint)' : 'var(--surface)', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 14, fontWeight: 600, color: on ? 'var(--accent-strong)' : 'var(--ink)', display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                      {olabel}{delta > 0 && <span style={{ fontVariantNumeric: 'tabular-nums', color: on ? 'var(--accent-strong)' : 'var(--muted)', fontWeight: 700 }}>+{money(delta)}</span>}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
          <div style={{ padding: '14px 0 4px' }}>
            <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 10 }}>{lang === 'bn' ? 'রান্নাঘরের নোট' : 'Kitchen note'}</div>
            <div className="field"><Icon name="note" size={18} /><input value={note} onChange={(e) => setNote(e.target.value)} placeholder={lang === 'bn' ? 'যেমন: কম ঝাল' : 'e.g. less spicy, no onion'} /></div>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 20px', borderTop: '1px solid var(--line)' }}>
          <div className="qty" style={{ transform: 'scale(1.1)', transformOrigin: 'left center' }}>
            <button onClick={() => setQty(Math.max(1, qty - 1))}><Icon name="minus" size={16} /></button>
            <span className="v tab">{qty}</span>
            <button onClick={() => setQty(qty + 1)}><Icon name="plus" size={16} /></button>
          </div>
          <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={() => d.commitMod(makeLine(item, qty, sel, note))}>
            {lang === 'bn' ? 'অর্ডারে যোগ করুন' : 'Add to order'} · {money(unit * qty)}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ============================ PAYMENT MODAL ============================ */
const DK_PAYMETHODS = [['cash', 'Cash', 'নগদ', 'cash'], ['card', 'Card', 'কার্ড', 'card'], ['mobile', 'bKash · Nagad', 'বিকাশ · নগদ', 'phone']];
function PaymentModal() {
  const d = useDesk();
  const lang = d.lang;
  const t = deskTotals(d.draft);
  const [method, setMethod] = dRegState('cash');
  const [tendered, setTendered] = dRegState('');
  const tNum = parseInt(tendered || '0', 10);
  const change = tNum - t.total;
  const press = (k) => setTendered((s) => (k === 'del' ? s.slice(0, -1) : (s + k).replace(/^0+(\d)/, '$1')).slice(0, 7));
  const quick = [t.total, Math.ceil(t.total / 100) * 100, Math.ceil(t.total / 500) * 500, 1000, 2000].filter((v, i, a) => a.indexOf(v) === i && v >= t.total).slice(0, 4);
  const canPay = method === 'cash' ? tNum >= t.total : true;

  return (
    <div className="dk-scrim" onClick={d.closePay}>
      <div className="dk-modal dk-fadein" style={{ width: 760, maxWidth: '92%' }} onClick={(e) => e.stopPropagation()}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '18px 22px', borderBottom: '1px solid var(--line)' }}>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{lang === 'bn' ? 'পেমেন্ট নিন' : 'Take payment'}</div>
          <button className="dk-xbtn" style={{ width: 34, height: 34 }} onClick={d.closePay}><Icon name="x" size={17} /></button>
        </div>
        <div style={{ display: 'flex' }}>
          {/* left: amount + method */}
          <div style={{ flex: '0 0 320px', width: 320, padding: 22, borderRight: '1px solid var(--line)' }}>
            <div style={{ fontSize: 13, color: 'var(--muted)', fontWeight: 600 }}>{lang === 'bn' ? 'মোট বকেয়া' : 'Total due'}</div>
            <div style={{ fontSize: 44, fontWeight: 800, letterSpacing: '-.03em', fontVariantNumeric: 'tabular-nums', marginTop: 2 }}>{money(t.total)}</div>
            <div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 2 }}>{t.count} {lang === 'bn' ? 'আইটেম · ভ্যাট সহ' : 'items · incl. VAT'}{t.charge ? ' + delivery' : ''}</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 22 }}>
              {DK_PAYMETHODS.map(([id, en, bn, ic]) => (
                <button key={id} onClick={() => setMethod(id)} style={{ display: 'flex', alignItems: 'center', gap: 11, height: 52, padding: '0 16px', borderRadius: 'var(--r-md)', border: '1px solid ' + (method === id ? 'var(--accent)' : 'var(--line-2)'), background: method === id ? 'var(--accent-tint)' : 'var(--surface)', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 15, fontWeight: 600, color: method === id ? 'var(--accent-strong)' : 'var(--ink)' }}>
                  <Icon name={ic} size={20} />{lang === 'bn' ? bn : en}
                  {method === id && <Icon name="check" size={18} style={{ marginLeft: 'auto' }} />}
                </button>
              ))}
            </div>
          </div>
          {/* right: method body */}
          <div style={{ flex: 1, padding: 22, minHeight: 360, display: 'flex', flexDirection: 'column' }}>
            {method === 'cash' ? (
              <React.Fragment>
                <div style={{ display: 'flex', gap: 12, marginBottom: 14 }}>
                  <div style={{ flex: 1, border: '1px solid var(--line-2)', borderRadius: 'var(--r-md)', padding: '10px 14px' }}>
                    <div style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>{lang === 'bn' ? 'গৃহীত' : 'Tendered'}</div>
                    <div style={{ fontSize: 24, fontWeight: 700, fontVariantNumeric: 'tabular-nums' }}>{tendered ? money(tNum) : '—'}</div>
                  </div>
                  <div style={{ flex: 1, border: '1px solid ' + (change >= 0 && tendered ? 'var(--accent)' : 'var(--line-2)'), borderRadius: 'var(--r-md)', padding: '10px 14px', background: change >= 0 && tendered ? 'var(--accent-tint)' : 'var(--surface)' }}>
                    <div style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>{lang === 'bn' ? 'ফেরত' : 'Change'}</div>
                    <div style={{ fontSize: 24, fontWeight: 700, fontVariantNumeric: 'tabular-nums', color: change >= 0 && tendered ? 'var(--accent-strong)' : 'var(--ink)' }}>{tendered && change >= 0 ? money(change) : '—'}</div>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 7, marginBottom: 14, flexWrap: 'wrap' }}>
                  {quick.map((v) => <button key={v} className="chip dk-chip-lg" onClick={() => setTendered('' + v)}>{v === t.total ? (lang === 'bn' ? 'সঠিক' : 'Exact') : money(v)}</button>)}
                </div>
                <div className="dk-keypad" style={{ marginTop: 'auto' }}>
                  {['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', 'del'].map((k) => (
                    <button key={k} className="dk-key" onClick={() => press(k)}>{k === 'del' ? '⌫' : k}</button>
                  ))}
                </div>
              </React.Fragment>
            ) : (
              <div style={{ flex: 1, display: 'grid', placeItems: 'center', textAlign: 'center' }}>
                <div>
                  <div style={{ width: 96, height: 96, borderRadius: 24, background: 'var(--accent-tint)', display: 'grid', placeItems: 'center', margin: '0 auto 18px' }}><Icon name={method === 'card' ? 'card' : 'phone'} size={46} color="var(--accent-strong)" /></div>
                  <div style={{ fontSize: 17, fontWeight: 700 }}>{method === 'card' ? (lang === 'bn' ? 'টার্মিনালে কার্ড দিন' : 'Insert or tap card on terminal') : (lang === 'bn' ? 'ফোনে পেমেন্ট রিকোয়েস্ট পাঠানো হয়েছে' : 'Payment request sent to phone')}</div>
                  <div style={{ fontSize: 13.5, color: 'var(--muted)', marginTop: 6, maxWidth: 280 }}>{method === 'card' ? (lang === 'bn' ? 'গ্রাহক অনুমোদন করলে নিশ্চিত করুন' : 'Confirm once the customer approves the charge.') : (lang === 'bn' ? 'গ্রাহক বিকাশ/নগদে অনুমোদন করলে নিশ্চিত করুন' : 'Confirm once paid via bKash or Nagad.')}</div>
                </div>
              </div>
            )}
            <button className="btn btn-primary btn-lg btn-block" style={{ marginTop: 16 }} disabled={!canPay} onClick={() => d.confirmPay(method, method === 'cash' ? change : 0)}>
              <Icon name="check" size={19} sw={2.2} />{lang === 'bn' ? 'পেমেন্ট নিশ্চিত করুন' : 'Confirm payment'} · {money(t.total)}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ============================ SUCCESS ============================ */
function SuccessOverlay() {
  const d = useDesk();
  const lang = d.lang;
  const s = d.success;
  return (
    <div className="dk-scrim" style={{ background: 'rgba(20,24,14,.55)' }}>
      <div className="dk-modal dk-fadein" style={{ width: 480, padding: '34px 34px 26px', alignItems: 'stretch' }}>
        <div style={{ width: 72, height: 72, borderRadius: '50%', background: 'var(--accent)', display: 'grid', placeItems: 'center', margin: '0 auto 16px' }}><Icon name="check" size={40} color="var(--accent-ink)" sw={2.4} /></div>
        <div style={{ textAlign: 'center', fontSize: 22, fontWeight: 800, letterSpacing: '-.02em' }}>{lang === 'bn' ? 'অর্ডার নিশ্চিত' : 'Order confirmed'}</div>
        <div style={{ textAlign: 'center', fontSize: 13.5, color: 'var(--muted)', marginTop: 4 }}>{s.typeLabel} · {s.count} {lang === 'bn' ? 'আইটেম' : 'items'} · {money(s.total)} · {s.methodLabel}{s.change > 0 ? ' · ' + (lang === 'bn' ? 'ফেরত ' : 'change ') + money(s.change) : ''}</div>

        <div style={{ border: '2px solid var(--ink)', borderRadius: 'var(--r-lg)', padding: '18px 20px', margin: '22px 0 18px', textAlign: 'center' }}>
          <div className="eyebrow" style={{ color: 'var(--ink-2)' }}>{lang === 'bn' ? 'কাস্টমার টোকেন' : 'Customer token'}</div>
          <div style={{ fontSize: 64, fontWeight: 800, letterSpacing: '-.03em', fontVariantNumeric: 'tabular-nums', lineHeight: 1.05, marginTop: 2 }}>{s.token}</div>
        </div>

        <div style={{ display: 'flex', gap: 8, marginBottom: 14 }}>
          {[['printer', lang === 'bn' ? 'KOT' : 'KOT'], ['receipt', lang === 'bn' ? 'টোকেন' : 'Token'], ['taka', lang === 'bn' ? 'বিল' : 'Bill']].map(([ic, lb]) => (
            <button key={lb} className="btn btn-ghost" style={{ flex: 1, flexDirection: 'column', height: 60, gap: 4, fontSize: 12.5 }} onClick={() => d.toast((lang === 'bn' ? 'প্রিন্ট: ' : 'Printing ') + lb)}><Icon name={ic} size={20} />{lb}</button>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="btn btn-ghost btn-lg" style={{ flex: 1 }} onClick={d.finishSuccess}>{lang === 'bn' ? 'সম্পন্ন' : 'Done'}</button>
          <button className="btn btn-primary btn-lg" style={{ flex: 1.4 }} onClick={d.newOrder}><Icon name="plus" size={18} sw={2.2} />{lang === 'bn' ? 'নতুন অর্ডার' : 'New order'}</button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { Register, deskTotals, DK_TYPES });
