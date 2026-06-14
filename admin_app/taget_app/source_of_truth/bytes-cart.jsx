/* ============================================================
   Bytes POS — shared cart bits + menu browser + item sheet
   ============================================================ */

function LineRow({ line, editable, onQty, onRemove }) {
  const summary = modSummary(line);
  return (
    <div className="cartline">
      <Thumb cat={line.cat} size={40} />
      <div className="ct">
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
          <span className="cn ell" style={{ flex: 1 }}>{line.name}</span>
          <span className="cp">{money(lineTotal(line))}</span>
        </div>
        {summary && <div className="cm">{summary}</div>}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 8 }}>
          {editable
            ? <Qty value={line.qty} onChange={(q) => q === 0 ? onRemove(line.lid) : onQty(line.lid, q)} min={0} />
            : <span style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--muted)' }} className="tab">Qty {line.qty} · {money(lineUnit(line))} ea</span>}
          {editable && <button onClick={() => onRemove(line.lid)} style={{ width: 32, height: 32, border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--muted)', display: 'grid', placeItems: 'center' }}><Icon name="trash" size={17} /></button>}
        </div>
      </div>
    </div>
  );
}
function LineList({ lines, editable, onQty, onRemove }) {
  return <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>{lines.map((l) => <LineRow key={l.lid} line={l} editable={editable} onQty={onQty} onRemove={onRemove} />)}</div>;
}

function OrderSummary({ lines, discount = 0, charge = 0, chargeLabel = 'Delivery' }) {
  const raw = lines.reduce((s, l) => s + lineTotal(l), 0);
  const sub = raw - discount;
  const vat = sub * 0.05;
  const total = sub + vat + charge;
  return (
    <div className="summary">
      <div className="sr"><span className="l">Subtotal</span><span className="v tab">{money(raw)}</span></div>
      {discount > 0 && <div className="sr"><span className="l" style={{ color: 'var(--success)' }}>Discount</span><span className="v tab" style={{ color: 'var(--success)' }}>−{money(discount)}</span></div>}
      <div className="sr"><span className="l">VAT (5%)</span><span className="v tab">{money(vat)}</span></div>
      {charge > 0 && <div className="sr"><span className="l">{chargeLabel}</span><span className="v tab">{money(charge)}</span></div>}
      <div className="total"><span className="l">Total</span><span className="v">{money(total)}</span></div>
    </div>
  );
}
function orderTotal(lines, discount = 0, charge = 0) {
  const sub = lines.reduce((s, l) => s + lineTotal(l), 0) - discount;
  return sub + sub * 0.05 + charge;
}
function orderCharge(o) { return o.charge != null ? o.charge : (o.type === 'delivery' ? 60 : 0); }

/* ---------- menu browser (search + chips + rows/grid) ---------- */
function MenuBrowser({ onAdd, onSub, lines = [] }) {
  const [q, setQ] = useState('');
  const [cat, setCat] = useState('All');
  const [foc, setFoc] = useState(false);
  const [view, setView] = useState('list');
  const [cols, setCols] = useState(3);
  const [colMenu, setColMenu] = useState(false);
  const counts = useMemo(() => { const c = { All: MENU.length }; CATS.forEach((k) => c[k] = MENU.filter((m) => m.cat === k).length); return c; }, []);
  const countById = useMemo(() => { const m = {}; lines.forEach((l) => m[l.id] = (m[l.id] || 0) + l.qty); return m; }, [lines]);
  const items = MENU.filter((m) => (cat === 'All' || m.cat === cat) && (q === '' || m.name.toLowerCase().includes(q.toLowerCase())));
  const groups = (cat === 'All' ? CATS : [cat]).map((k) => [k, items.filter((m) => m.cat === k)]).filter(([, arr]) => arr.length);

  const Stepper = ({ n, item }) => (
    <div className="qty" onClick={(e) => e.stopPropagation()}>
      <button onClick={() => onSub && onSub(item)}><Icon name="minus" size={16} /></button>
      <span className="v tab">{n}</span>
      <button onClick={() => onAdd(item)}><Icon name="plus" size={16} /></button>
    </div>
  );

  return (
    <React.Fragment>
      <div style={{ flex: '0 0 auto', padding: '0 16px 10px', display: 'flex', gap: 8 }}>
        <div className={'field' + (foc ? ' focus' : '')} style={{ flex: 1 }}>
          <Icon name="search" size={18} />
          <input value={q} onChange={(e) => setQ(e.target.value)} onFocus={() => setFoc(true)} onBlur={() => setFoc(false)} placeholder="Search menu…" />
          {q && <button onClick={() => setQ('')} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--muted)', display: 'grid', placeItems: 'center' }}><Icon name="x" size={16} /></button>}
        </div>
        <div className="seg" style={{ padding: 3, gap: 2, flex: '0 0 auto', position: 'relative' }}>
          <button onClick={() => setView('list')} className={view === 'list' ? 'active' : ''} style={{ width: 40, flex: 'none', height: 38 }}><Icon name="list" size={18} /></button>
          <button onClick={() => setView('grid')} className={view === 'grid' ? 'active' : ''} style={{ width: 40, flex: 'none', height: 38 }}><Icon name="grid" size={17} /></button>
          {view === 'grid' && (
            <button onClick={() => setColMenu((v) => !v)} className={colMenu ? 'active' : ''} style={{ width: 46, flex: 'none', height: 38, gap: 2 }}>
              <span className="tab" style={{ fontSize: 13, fontWeight: 700 }}>{cols}</span><Icon name="chevd" size={13} sw={2.2} />
            </button>
          )}
          {colMenu && view === 'grid' && (
            <React.Fragment>
              <div onClick={() => setColMenu(false)} style={{ position: 'fixed', inset: 0, zIndex: 30 }} />
              <div style={{ position: 'absolute', top: 46, right: 0, zIndex: 31, background: 'var(--surface)', border: '1px solid var(--line-2)', borderRadius: 'var(--r-md)', boxShadow: 'var(--e3)', padding: 4, width: 122 }}>
                {[2, 3, 4].map((n) => (
                  <button key={n} onClick={() => { setCols(n); setColMenu(false); }} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 9, padding: '9px 10px', border: 'none', borderRadius: 'var(--r-sm)', background: cols === n ? 'var(--accent-tint)' : 'transparent', color: cols === n ? 'var(--accent-strong)' : 'var(--ink-2)', cursor: 'pointer', font: 'inherit', fontSize: 13.5, fontWeight: 600 }}>
                    <Icon name="grid" size={15} />{n} columns{cols === n && <Icon name="check2" size={15} sw={2.2} style={{ marginLeft: 'auto' }} />}
                  </button>
                ))}
              </div>
            </React.Fragment>
          )}
        </div>
      </div>
      <div className="chiprow noscroll" style={{ flex: '0 0 auto', paddingBottom: 12 }}>
        {['All', ...CATS].map((k) => <button key={k} className={'chip' + (cat === k ? ' active' : '')} onClick={() => setCat(k)}>{k}<span className="ct">{counts[k]}</span></button>)}
      </div>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        {view === 'grid' ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(' + cols + ', 1fr)', gap: 10 }}>
            {items.map((m) => {
              const n = countById[m.id] || 0;
              const off = m.stock === 'no';
              const thumbH = cols === 2 ? 130 : cols === 3 ? 88 : 64;
              return (
                <div key={m.id} className="tile" onClick={() => !off && onAdd(m)} style={{ padding: 8, opacity: off ? .5 : 1, display: 'flex', flexDirection: 'column', gap: 8, position: 'relative', borderColor: n > 0 ? 'var(--accent-press)' : 'var(--line)', background: n > 0 ? 'var(--accent-tint)' : 'var(--surface)' }}>
                  <div style={{ position: 'relative' }}>
                    <Thumb cat={m.cat} size={thumbH} fill />
                    {n > 0 && <span className="tab" style={{ position: 'absolute', top: 6, left: 6, minWidth: 22, height: 22, padding: '0 6px', borderRadius: 11, background: 'var(--accent)', color: 'var(--accent-ink)', fontSize: 12.5, fontWeight: 800, display: 'grid', placeItems: 'center' }}>{n}</span>}
                    {n > 0 && <button onClick={(e) => { e.stopPropagation(); onSub && onSub(m); }} style={{ position: 'absolute', top: 6, right: 6, width: 24, height: 24, borderRadius: 7, border: 'none', background: 'var(--surface)', boxShadow: '0 1px 3px rgba(20,24,14,.18)', display: 'grid', placeItems: 'center', cursor: 'pointer', color: 'var(--danger)' }}><Icon name="minus" size={16} sw={2.4} /></button>}
                    {off && <span style={{ position: 'absolute', right: 6, bottom: 6, fontSize: 10.5, fontWeight: 700, color: '#fff', background: 'var(--danger)', borderRadius: 5, padding: '3px 6px' }}>86'd</span>}
                  </div>
                  <div>
                    <div className="nm ell2" style={{ fontSize: cols === 4 ? 12.5 : 14, lineHeight: 1.25, minHeight: '2.5em' }}>{m.name}</div>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 3 }}>
                      <span style={{ fontSize: cols === 4 ? 12.5 : 14, fontWeight: 700 }} className="tab">{money(m.price)}</span>
                      {m.stock === 'low' && cols < 4 && <span style={{ fontSize: 11, color: 'var(--warning)', fontWeight: 600 }}>Low</span>}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          groups.map(([gcat, gitems]) => (
            <div key={gcat} style={{ marginBottom: 18 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '0 2px 10px' }}>
                <span className="eyebrow">{gcat}</span><span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>{gitems.length}</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {gitems.map((m) => {
                  const n = countById[m.id] || 0;
                  const off = m.stock === 'no';
                  return (
                    <div className="row" key={m.id} onClick={() => !off && n === 0 && onAdd(m)} style={{ opacity: off ? .5 : 1, cursor: off ? 'default' : 'pointer', borderColor: n > 0 ? 'var(--accent-press)' : 'var(--line)', background: n > 0 ? 'var(--accent-tint)' : 'var(--surface)' }}>
                      <Thumb cat={m.cat} />
                      <div className="mid">
                        <div className="nm ell">{m.name}</div>
                        <div className="ds ell">{m.desc}</div>
                        {m.stock === 'low' && <div style={{ fontSize: 12, color: 'var(--warning)', fontWeight: 600, marginTop: 3 }}>Low stock</div>}
                      </div>
                      <div className="trail">
                        <span className="price">{money(m.price)}</span>
                        {off ? <span style={{ fontSize: 11.5, color: 'var(--danger)', fontWeight: 700 }}>86'd</span>
                          : n > 0 ? <Stepper n={n} item={m} />
                          : <button className="addbtn" onClick={(e) => { e.stopPropagation(); onAdd(m); }}><Icon name="plus" size={20} color="var(--accent-ink)" sw={2.2} /></button>}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))
        )}
        {items.length === 0 && <div style={{ textAlign: 'center', color: 'var(--muted)', padding: '40px 0', fontSize: 14 }}>No items match “{q}”.</div>}
      </div>
    </React.Fragment>
  );
}

/* ---------- item modifier sheet ---------- */
function ItemSheet({ item, onClose, onConfirm }) {
  const groups = item.mods.map((g) => [g, MODS[g]]).filter(([, v]) => v);
  const init = {}; groups.forEach(([g, def]) => { init[g] = def.type === 'single' ? def.opts[0][0] : []; });
  const [sel, setSel] = useState(init);
  const [qty, setQty] = useState(1);
  const [note, setNote] = useState('');
  const [noteOpen, setNoteOpen] = useState(false);
  const pick = (g, id, multi) => setSel((s) => { if (!multi) return { ...s, [g]: id }; const cur = s[g] || []; return { ...s, [g]: cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id] }; });
  const line = makeLine(item, qty, sel, note);
  const unit = lineUnit(line);
  return (
    <Sheet open onClose={onClose}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '4px 18px 14px' }}>
        <Thumb cat={item.cat} size={56} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: '-.01em' }} className="ell">{item.name}</div>
          <div style={{ fontSize: 13, color: 'var(--muted)', marginTop: 1 }} className="ell">{item.desc}</div>
        </div>
        <button onClick={onClose} style={{ width: 36, height: 36, border: '1px solid var(--line-2)', borderRadius: 7, background: 'var(--surface)', display: 'grid', placeItems: 'center', cursor: 'pointer', color: 'var(--ink-2)' }}><Icon name="x" size={18} /></button>
      </div>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 18px 8px', display: 'flex', flexDirection: 'column', gap: 18 }}>
        {groups.map(([g, def]) => (
          <div key={g}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 9 }}>
              <span className="eyebrow">{def.label}</span>
              {def.req ? <span className="badge neutral" style={{ height: 18, fontSize: 10.5 }}>Required</span> : <span style={{ fontSize: 11.5, color: 'var(--placeholder)', fontWeight: 500 }}>Optional</span>}
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {def.opts.map(([id, label, price]) => {
                const on = def.type === 'single' ? sel[g] === id : (sel[g] || []).includes(id);
                return (
                  <button key={id} onClick={() => pick(g, id, def.type === 'multi')} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '11px 13px', cursor: 'pointer',
                    border: '1px solid ' + (on ? 'var(--accent-press)' : 'var(--line-2)'), background: on ? 'var(--accent-tint)' : 'var(--surface)', borderRadius: 'var(--r-md)', textAlign: 'left', font: 'inherit' }}>
                    <span style={{ width: 20, height: 20, flex: '0 0 20px', borderRadius: def.type === 'single' ? '50%' : 5, border: '2px solid ' + (on ? 'var(--accent-strong)' : 'var(--line-2)'), background: on ? 'var(--accent)' : 'transparent', display: 'grid', placeItems: 'center' }}>
                      {on && <Icon name="check" size={12} color="var(--accent-ink)" sw={2.8} />}
                    </span>
                    <span style={{ flex: 1, fontSize: 15, fontWeight: 500, color: 'var(--ink)' }}>{label}</span>
                    {price > 0 && <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--accent-strong)' }} className="tab">+{money(price)}</span>}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
        <div>
          {!noteOpen ? (
            <button onClick={() => setNoteOpen(true)} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 0', border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--accent-strong)', fontWeight: 600, fontSize: 14 }}><Icon name="note" size={18} />Add a kitchen note</button>
          ) : (
            <div>
              <div className="eyebrow" style={{ marginBottom: 9 }}>Kitchen note</div>
              <textarea autoFocus value={note} onChange={(e) => setNote(e.target.value)} placeholder="e.g. no onion, less spicy" style={{ width: '100%', minHeight: 60, resize: 'none', border: '1px solid var(--line-2)', borderRadius: 'var(--r-md)', padding: 11, font: 'inherit', fontSize: 14, color: 'var(--ink)', outline: 'none', background: 'var(--surface)' }} />
            </div>
          )}
        </div>
      </div>
      <div className="bottombar" style={{ alignItems: 'center', paddingBottom: 14 }}>
        <Qty value={qty} onChange={setQty} />
        <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={() => { onConfirm(makeLine(item, qty, sel, note)); onClose(); }}>
          <span>Add to order</span><span style={{ marginLeft: 'auto', fontWeight: 700 }} className="tab">{money(unit * qty)}</span>
        </button>
      </div>
    </Sheet>
  );
}

Object.assign(window, { LineRow, LineList, OrderSummary, orderTotal, orderCharge, MenuBrowser, ItemSheet });
