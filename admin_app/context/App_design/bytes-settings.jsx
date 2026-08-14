/* ============================================================
   Quick Bytes POS — Settings hub + delivery areas + discount
   presets + theme picker. Owner/manager only.
   ============================================================ */

const setRowStyle = { display: 'flex', alignItems: 'center', gap: 13, padding: '13px 14px', cursor: 'pointer', borderBottom: '1px solid var(--line)' };
function SetRow({ icon, label, hint, value, onClick, right, last }) {
  return (
    <div onClick={onClick} style={{ ...setRowStyle, borderBottom: last ? 'none' : '1px solid var(--line)', cursor: onClick ? 'pointer' : 'default' }}>
      <div style={{ width: 36, height: 36, borderRadius: 9, background: 'var(--surface-2)', color: 'var(--ink-2)', display: 'grid', placeItems: 'center', flex: '0 0 36px' }}><Icon name={icon} size={19} /></div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14.5, fontWeight: 600 }}>{label}</div>
        {hint && <div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 1 }} className="ell">{hint}</div>}
      </div>
      {value && <span style={{ fontSize: 13, color: 'var(--muted)', fontWeight: 600, flex: '0 0 auto' }} className="tab">{value}</span>}
      {right}
      {onClick && <Icon name="chev" size={18} color="var(--placeholder)" />}
    </div>
  );
}
const setGroupStyle = { fontSize: 11.5, fontWeight: 700, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--muted)', margin: '0 4px 9px' };

function SettingsScreen() {
  const b = useBytes();
  const s = b.settings;
  const owner = b.role === 'owner';

  return (
    <React.Fragment>
      <Header title={b.t('title.settings')} sub={owner ? 'Owner access' : 'Manager access'} onBack={b.pop} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 20px', display: 'flex', flexDirection: 'column', gap: 18 }}>

        <div>
          <div style={setGroupStyle}>Storefront</div>
          <div className="card">
            <SetRow icon="link" label="Public URL" hint={s.slug + '.quickbytes.buzz'} onClick={() => b.push({ screen: 'themePicker', focus: 'url' })} />
            <SetRow icon="image" label="Hero media" hint="Outlet photos for your storefront" onClick={() => {}} />
            <SetRow icon="store" label="Outlet logo" hint="Shown on receipts & storefront" onClick={() => {}} />
            <SetRow icon="palette" label="Menu theme" value={s.theme} onClick={() => b.push({ screen: 'themePicker' })} last />
          </div>
        </div>

        <div>
          <div style={setGroupStyle}>Ordering</div>
          <div className="card">
            <SetRow icon="truck" label="Delivery areas" hint={s.areas.length + ' areas · ৳' + s.areas[0].charge + '–৳' + Math.max(...s.areas.map((a) => a.charge))} onClick={() => b.push({ screen: 'deliveryAreas' })} />
            <SetRow icon="tag" label="Discount presets" hint={s.discounts.map((d) => d.label).join(' · ')} onClick={() => b.push({ screen: 'discountPresets' })} />
            <VatRow />
            <SetRow icon="printer" label="Auto-print on accept" hint="Print KOT + bill automatically" right={<Toggle on={s.autoprint} onChange={(v) => b.updateSettings({ autoprint: v })} />} last />
          </div>
        </div>

        <div>
          <div style={setGroupStyle}>App</div>
          <div className="card">
            <div style={{ ...setRowStyle, cursor: 'default' }}>
              <div style={{ width: 36, height: 36, borderRadius: 9, background: 'var(--surface-2)', color: 'var(--ink-2)', display: 'grid', placeItems: 'center', flex: '0 0 36px' }}><Icon name="language" size={19} /></div>
              <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 600 }}>Language · ভাষা</div><div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 1 }}>Whole app switches instantly</div></div>
            </div>
            <div style={{ padding: '0 14px 14px' }}>
              <div className="seg">
                <button className={b.lang === 'en' ? 'active' : ''} onClick={() => b.setLang('en')}>English</button>
                <button className={b.lang === 'bn' ? 'active' : ''} onClick={() => b.setLang('bn')}>বাংলা</button>
              </div>
            </div>
            <SetRow icon="shield" label="About us / Privacy" onClick={() => {}} last />
          </div>
        </div>

        {owner && (
          <button style={{ width: '100%', padding: '13px', border: '1px solid var(--danger-soft)', borderRadius: 'var(--r-md)', background: 'var(--danger-soft)', color: 'var(--danger)', cursor: 'pointer', fontFamily: 'var(--font)', fontWeight: 700, fontSize: 14, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><Icon name="trash" size={18} />Wipe outlet data</button>
        )}
      </div>
    </React.Fragment>
  );
}

function VatRow() {
  const b = useBytes();
  const vat = b.settings.vat;
  return (
    <div style={{ ...setRowStyle, cursor: 'default' }}>
      <div style={{ width: 36, height: 36, borderRadius: 9, background: 'var(--surface-2)', color: 'var(--ink-2)', display: 'grid', placeItems: 'center', flex: '0 0 36px' }}><Icon name="percent" size={19} /></div>
      <div style={{ flex: 1 }}><div style={{ fontSize: 14.5, fontWeight: 600 }}>VAT rate</div><div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 1 }}>Applied to every bill</div></div>
      <div className="qty">
        <button onClick={() => b.updateSettings({ vat: Math.max(0, vat - 1) })}><Icon name="minus" size={16} /></button>
        <span className="v tab">{vat}%</span>
        <button onClick={() => b.updateSettings({ vat: Math.min(20, vat + 1) })}><Icon name="plus" size={16} /></button>
      </div>
    </div>
  );
}

/* ---------- delivery areas editor ---------- */
function DeliveryAreasScreen() {
  const b = useBytes();
  const areas = b.settings.areas;
  const [name, setName] = useState('');
  const [charge, setCharge] = useState('');
  const add = () => { if (!name.trim() || !charge) return; b.updateSettings({ areas: [...areas, { name: name.trim(), charge: +charge }] }); setName(''); setCharge(''); };
  const remove = (i) => b.updateSettings({ areas: areas.filter((_, x) => x !== i) });
  return (
    <React.Fragment>
      <Header title="Delivery areas" sub="Per-area delivery charge" onBack={b.pop} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <div className="card" style={{ overflow: 'hidden' }}>
          {areas.map((a, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 14px', borderBottom: i === areas.length - 1 ? 'none' : '1px solid var(--line)' }}>
              <Icon name="pin" size={18} color="var(--muted)" />
              <span style={{ flex: 1, fontSize: 14.5, fontWeight: 600 }}>{a.name}</span>
              <span style={{ fontSize: 14.5, fontWeight: 700 }} className="tab">{money(a.charge)}</span>
              <button onClick={() => remove(i)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--placeholder)', display: 'grid', placeItems: 'center', padding: 2 }}><Icon name="x" size={17} /></button>
            </div>
          ))}
        </div>
      </div>
      <div className="bottombar" style={{ gap: 8 }}>
        <div className="field" style={{ flex: 1 }}><Icon name="pin" size={17} /><input value={name} onChange={(e) => setName(e.target.value)} placeholder="Area name" /></div>
        <div className="field" style={{ width: 96, flex: '0 0 96px' }}><span style={{ color: 'var(--muted)', fontWeight: 700 }}>৳</span><input value={charge} onChange={(e) => setCharge(e.target.value.replace(/\D/g, ''))} placeholder="60" inputMode="numeric" /></div>
        <button className="btn btn-primary" style={{ width: 48, flex: '0 0 48px', padding: 0 }} onClick={add}><Icon name="plus" size={22} color="var(--accent-ink)" sw={2.2} /></button>
      </div>
    </React.Fragment>
  );
}

/* ---------- discount presets editor ---------- */
function DiscountPresetsScreen() {
  const b = useBytes();
  const presets = b.settings.discounts;
  const [val, setVal] = useState('');
  const [kind, setKind] = useState('pct');
  const add = () => { if (!val) return; b.updateSettings({ discounts: [...presets, { label: kind === 'pct' ? val + '%' : '৳' + val, kind, val: +val }] }); setVal(''); };
  const remove = (i) => b.updateSettings({ discounts: presets.filter((_, x) => x !== i) });
  return (
    <React.Fragment>
      <Header title="Discount presets" sub="Quick-apply at checkout" onBack={b.pop} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
          {presets.map((d, i) => (
            <div key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 8, height: 44, padding: '0 10px 0 15px', borderRadius: 'var(--r-md)', border: '1px solid var(--line-2)', background: 'var(--surface)' }}>
              <span style={{ fontSize: 15, fontWeight: 700 }} className="tab">{d.label}</span>
              <span style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 600 }}>{d.kind === 'pct' ? 'percent' : 'flat'}</span>
              <button onClick={() => remove(i)} style={{ border: 'none', background: 'var(--surface-2)', cursor: 'pointer', color: 'var(--muted)', width: 26, height: 26, borderRadius: 7, display: 'grid', placeItems: 'center' }}><Icon name="x" size={15} /></button>
            </div>
          ))}
        </div>
      </div>
      <div className="bottombar" style={{ gap: 8 }}>
        <div className="seg" style={{ flex: '0 0 130px', padding: 3 }}>
          <button className={kind === 'pct' ? 'active' : ''} onClick={() => setKind('pct')} style={{ height: 38 }}>Percent</button>
          <button className={kind === 'flat' ? 'active' : ''} onClick={() => setKind('flat')} style={{ height: 38 }}>Flat ৳</button>
        </div>
        <div className="field" style={{ flex: 1 }}><span style={{ color: 'var(--muted)', fontWeight: 700 }}>{kind === 'pct' ? '%' : '৳'}</span><input value={val} onChange={(e) => setVal(e.target.value.replace(/\D/g, ''))} placeholder={kind === 'pct' ? '10' : '50'} inputMode="numeric" /></div>
        <button className="btn btn-primary" style={{ width: 48, flex: '0 0 48px', padding: 0 }} onClick={add}><Icon name="plus" size={22} color="var(--accent-ink)" sw={2.2} /></button>
      </div>
    </React.Fragment>
  );
}

/* ---------- menu theme picker (storefront) ---------- */
function ThemePicker() {
  const b = useBytes();
  const [slug, setSlug] = useState(b.settings.slug);
  return (
    <React.Fragment>
      <Header title="Storefront" sub="Customer-facing website" onBack={b.pop} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <div className="eyebrow" style={{ margin: '0 2px 8px' }}>Public URL</div>
        <div className="field" style={{ marginBottom: 20 }}>
          <Icon name="link" size={17} />
          <input value={slug} onChange={(e) => setSlug(e.target.value.replace(/[^a-z0-9-]/g, ''))} onBlur={() => b.updateSettings({ slug })} placeholder="spicegarden" />
          <span style={{ color: 'var(--muted)', fontSize: 13, fontWeight: 500, flex: '0 0 auto' }}>.quickbytes.buzz</span>
        </div>
        <div className="eyebrow" style={{ margin: '0 2px 10px' }}>Theme</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {MENU_THEMES.map(([name, bg, fg]) => {
            const on = b.settings.theme === name;
            return (
              <div key={name} onClick={() => b.updateSettings({ theme: name })} style={{ borderRadius: 'var(--r-lg)', border: '2px solid ' + (on ? 'var(--accent-press)' : 'var(--line-2)'), overflow: 'hidden', cursor: 'pointer', background: 'var(--surface)' }}>
                <div style={{ height: 74, background: bg, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', padding: 10, gap: 5 }}>
                  <div style={{ width: 30, height: 6, borderRadius: 3, background: fg, opacity: .9 }} />
                  <div style={{ width: 46, height: 6, borderRadius: 3, background: fg, opacity: .5 }} />
                </div>
                <div style={{ padding: '9px 11px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <span style={{ fontSize: 13.5, fontWeight: 700 }}>{name}</span>
                  {on && <Icon name="check2" size={16} color="var(--accent-strong)" sw={2.4} />}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { SettingsScreen, DeliveryAreasScreen, DiscountPresetsScreen, ThemePicker });
