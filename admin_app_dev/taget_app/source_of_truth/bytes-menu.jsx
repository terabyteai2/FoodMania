/* ============================================================
   Bytes POS — Menu management + item editor + scan menu card
   ============================================================ */

function MenuManageScreen() {
  const b = useBytes();
  const [scan, setScan] = useState(false);
  const [scanned, setScanned] = useState(false);
  const [delivery, setDelivery] = useState(true);
  const [avail, setAvail] = useState(() => { const m = {}; MENU.forEach((x) => m[x.id] = x.stock !== 'no'); return m; });

  const ActionBtn = ({ icon, label, on, onClick, badge }) => (
    <button onClick={onClick} style={{ flex: 1, minWidth: 0, height: 60, borderRadius: 'var(--r-md)', cursor: 'pointer', fontFamily: 'var(--font)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 5, position: 'relative',
      border: '1px solid ' + (on ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: on ? 'var(--accent-tint)' : 'var(--surface)', color: on ? 'var(--accent-strong)' : 'var(--ink-2)' }}>
      <Icon name={icon} size={19} />
      <span style={{ fontSize: 11.5, fontWeight: 600 }}>{label}</span>
      {badge && <span style={{ position: 'absolute', top: 7, right: 9, width: 7, height: 7, borderRadius: '50%', background: 'var(--accent)' }} />}
    </button>
  );

  return (
    <React.Fragment>
      <Header title={b.t('title.menu')} sub={MENU.length + ' items · ' + CATS.length + ' categories'} onBack={b.pop} />

      {/* compact action row */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px', display: 'flex', gap: 8 }}>
        <ActionBtn icon="truck" label={delivery ? 'Delivery on' : 'Delivery off'} on={delivery} onClick={() => setDelivery(!delivery)} />
        <ActionBtn icon="camera" label="Scan" onClick={() => setScan(true)} badge />
        <ActionBtn icon="tag" label="Discounts" onClick={() => b.push({ screen: 'discountPresets' })} />
        <ActionBtn icon="settings" label="Settings" onClick={() => b.push({ screen: 'settings' })} />
      </div>
      {scanned && <div style={{ flex: '0 0 auto', padding: '0 18px 10px', fontSize: 12.5, color: 'var(--success)', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}><Icon name="check2" size={15} sw={2.2} />6 items imported from scan</div>}

      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        {CATS.map((cat) => {
          const items = MENU.filter((m) => m.cat === cat);
          if (!items.length) return null;
          return (
            <div key={cat} style={{ marginBottom: 20 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '0 2px 11px' }}>
                <span className="eyebrow">{cat}</span><span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>{items.length}</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {items.map((m) => {
                  const on = avail[m.id];
                  return (
                    <div key={m.id} className="row" onClick={() => b.push({ screen: 'itemEdit', itemId: m.id })} style={{ cursor: 'pointer', opacity: on ? 1 : .55 }}>
                      <Thumb cat={m.cat} />
                      <div className="mid">
                        <div className="nm ell">{m.name}</div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 2 }}>
                          <span style={{ fontSize: 14, fontWeight: 700 }} className="tab">{money(m.price)}</span>
                          {m.stock === 'low' && on && <span style={{ fontSize: 12, color: 'var(--warning)', fontWeight: 600 }}>Low stock</span>}
                          {!on && <span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>Hidden</span>}
                        </div>
                      </div>
                      <div onClick={(e) => e.stopPropagation()}><Toggle on={on} onChange={(v) => setAvail((s) => ({ ...s, [m.id]: v }))} /></div>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>

      {scan && <AIScan variant="menu" onClose={() => setScan(false)} onApply={() => { setScan(false); setScanned(true); }} />}
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg" onClick={() => b.push({ screen: 'itemEdit', itemId: null })}><Icon name="plus" size={20} color="var(--accent-ink)" sw={2.2} />Add item</button>
      </div>
    </React.Fragment>
  );
}

/* ---------- item editor ---------- */
const MField = ({ label, children }) => (
  <div style={{ marginBottom: 16 }}><div className="eyebrow" style={{ marginBottom: 8 }}>{label}</div>{children}</div>
);
function ItemEdit({ itemId }) {
  const b = useBytes();
  const item = itemId ? MENU.find((m) => m.id === itemId) : null;
  const [name, setName] = useState(item ? item.name : '');
  const [price, setPrice] = useState(item ? item.price : '');
  const [cat, setCat] = useState(item ? item.cat : CATS[0]);
  const [avail, setAvail] = useState(item ? item.stock !== 'no' : true);
  const [delivery, setDelivery] = useState(item ? item.delivery : true);
  const [discOn, setDiscOn] = useState(false);
  const [disc, setDisc] = useState(10);
  const Field = MField;

  return (
    <React.Fragment>
      <Header title={item ? 'Edit item' : 'New item'} onBack={b.pop}
        right={item ? <button style={{ width: 40, height: 40, border: 'none', background: 'transparent', cursor: 'pointer', display: 'grid', placeItems: 'center', color: 'var(--danger)' }}><Icon name="trash" size={20} /></button> : null} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        {/* photo */}
        <div style={{ display: 'flex', gap: 12, marginBottom: 18 }}>
          <div style={{ width: 80, height: 80, borderRadius: 'var(--r-lg)', background: 'var(--surface-2)', border: '1px dashed var(--line-2)', display: 'grid', placeItems: 'center', color: 'var(--muted)', flex: '0 0 80px' }}>
            {item ? <Thumb cat={item.cat} size={78} /> : <Icon name="camera" size={26} />}
          </div>
          <button style={{ flex: 1, border: '1px solid var(--line-2)', borderRadius: 'var(--r-lg)', background: 'var(--surface)', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6, color: 'var(--accent-strong)' }}>
            <Icon name="camera" size={22} /><span style={{ fontSize: 13, fontWeight: 600 }}>Add photo</span>
          </button>
        </div>

        <Field label="Item name"><div className="field"><input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Chicken Biryani" /></div></Field>
        <Field label="Price"><div className="field"><Icon name="taka" size={18} /><input value={price} onChange={(e) => setPrice(e.target.value.replace(/\D/g, ''))} placeholder="0" inputMode="numeric" /></div></Field>
        <Field label="Category">
          <div className="chiprow noscroll" style={{ padding: 0, margin: '0 -2px', flexWrap: 'nowrap' }}>
            {CATS.map((c) => <button key={c} className={'chip' + (cat === c ? ' active' : '')} onClick={() => setCat(c)}>{c}</button>)}
          </div>
        </Field>

        {/* toggles */}
        <div className="card" style={{ overflow: 'hidden', marginBottom: 16 }}>
          <ToggleRow icon="check2" label="Available" hint="Show on all order channels" on={avail} onChange={setAvail} first />
          <ToggleRow icon="tag" label="Set discount" hint={discOn ? disc + '% off this item' : 'No discount'} on={discOn} onChange={setDiscOn} />
          {discOn && (
            <div style={{ padding: '4px 14px 14px' }}>
              <div className="seg">
                {[5, 10, 15, 20, 25].map((v) => <button key={v} className={disc === v ? 'active' : ''} onClick={() => setDisc(v)}>{v}%</button>)}
              </div>
            </div>
          )}
        </div>

        {/* variations summary */}
        <button onClick={() => {}} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 11, padding: 14, border: '1px solid var(--line)', borderRadius: 'var(--r-lg)', background: 'var(--surface)', cursor: 'pointer', marginBottom: 10 }}>
          <div style={{ width: 36, height: 36, borderRadius: 8, background: 'var(--surface-2)', display: 'grid', placeItems: 'center', color: 'var(--ink-2)' }}><Icon name="list" size={19} /></div>
          <div style={{ flex: 1, textAlign: 'left' }}><div style={{ fontSize: 14.5, fontWeight: 600 }}>Variations &amp; add-ons</div><div style={{ fontSize: 12.5, color: 'var(--muted)' }}>{item && item.mods.length ? item.mods.length + ' groups · size, add-ons' : 'None yet'}</div></div>
          <Icon name="chev" size={18} color="var(--muted)" />
        </button>
      </div>
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg" onClick={b.pop}><Icon name="check" size={19} color="var(--accent-ink)" sw={2.4} />Save item</button>
      </div>
    </React.Fragment>
  );
}

function ToggleRow({ icon, label, hint, on, onChange, first }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 14px', borderTop: first ? 'none' : '1px solid var(--line)' }}>
      <div style={{ width: 34, height: 34, borderRadius: 8, background: 'var(--surface-2)', display: 'grid', placeItems: 'center', color: 'var(--ink-2)', flex: '0 0 34px' }}><Icon name={icon} size={18} /></div>
      <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 14.5, fontWeight: 600 }}>{label}</div><div style={{ fontSize: 12.5, color: 'var(--muted)' }} className="ell">{hint}</div></div>
      <Toggle on={on} onChange={onChange} />
    </div>
  );
}

Object.assign(window, { MenuManageScreen, ItemEdit, ToggleRow });
