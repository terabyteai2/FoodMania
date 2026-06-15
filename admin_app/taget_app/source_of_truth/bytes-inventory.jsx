/* ============================================================
   Quick Bytes POS — Stock (ranked white table), stock-in,
   count, and advanced drill-downs (item detail / variance /
   suppliers / usage). Owner + manager.
   ============================================================ */

function stockKind(it) { const r = it.qty / it.par; return r >= 0.6 ? 'ok' : r >= 0.3 ? 'low' : 'no'; }
function coverDays(it) { return it.used7 > 0 ? Math.round(it.qty / it.used7 * 7) : 99; }
/* believable per-item daily usage derived from the 7-day figure (deterministic, demo only) */
function usedToday(it) { const seed = it.id.split('').reduce((s, c) => s + c.charCodeAt(0), 0); const j = 0.78 + (seed % 7) * 0.06; return Math.max(1, Math.round(it.used7 / 7 * j)); }

const SORT_LABELS = { low: 'Low stock first', qty: 'Quantity', value: 'Value', name: 'A–Z', cover: 'Cover days' };

function InventoryScreen() {
  const b = useBytes();
  const [view, setView] = useState('stock');   // 'stock' | 'used'
  const [sort, setSort] = useState('low');      // default: most depleted on top
  const [dir, setDir] = useState(1);            // low/name/cover ascend by default
  const [adv, setAdv] = useState(false);
  const [showSort, setShowSort] = useState(false);
  const ascByDefault = { name: 1, low: 1, cover: 1 };
  const pickSort = (key) => { setSort(key); setDir(ascByDefault[key] || -1); setShowSort(false); };
  const val = (it) => it.qty * it.cost;
  const sorted = [...b.inventory].sort((a, c) => {
    if (view === 'used') return usedToday(c) - usedToday(a);   // biggest usage first
    let r;
    if (sort === 'name') r = a.name.localeCompare(c.name);
    else if (sort === 'qty') r = a.qty - c.qty;
    else if (sort === 'value') r = val(a) - val(c);
    else if (sort === 'cover') r = coverDays(a) - coverDays(c);
    else r = (a.qty / a.par) - (c.qty / c.par);                // 'low'
    return r * dir;
  });
  const lowCount = b.inventory.filter((i) => stockKind(i) !== 'ok').length;
  const value = b.inventory.reduce((s, i) => s + i.qty * i.cost, 0);
  const usedVal = b.inventory.reduce((s, i) => s + usedToday(i) * i.cost, 0);
  const topMover = [...b.inventory].sort((a, c) => usedToday(c) - usedToday(a))[0];
  const showCover = adv && view === 'stock';
  const heroW = showCover ? 64 : 92;
  const openRow = (it) => b.push({ screen: (view === 'used' || adv) ? 'itemDetail' : 'stockIn', itemId: it.id });
  const sortOpts = ['low', 'qty', 'value', 'name'].concat(adv ? ['cover'] : []);

  return (
    <React.Fragment>
      <Header brand={false} title={b.t('title.stock')} sub={b.inventory.length + ' items'} big right={<TopActions />} />

      {/* summary strip — swaps with the view */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px', display: 'flex', gap: 10 }}>
        {view === 'stock' ? (
          <React.Fragment>
            <div className="card" style={{ flex: 1, padding: '12px 14px' }}>
              <div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>Stock value</div>
              <div style={{ fontSize: 20, fontWeight: 700, marginTop: 2 }} className="tab">{money(value)}</div>
            </div>
            <div onClick={() => pickSort('low')} className="card" style={{ flex: 1, padding: '12px 14px', cursor: 'pointer', borderColor: sort === 'low' ? 'var(--accent-tint-2)' : 'var(--line)', background: sort === 'low' ? 'var(--accent-tint)' : 'var(--surface)' }}>
              <div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>Below par</div>
              <div style={{ fontSize: 20, fontWeight: 700, marginTop: 2, color: lowCount ? 'var(--warning)' : 'var(--ink)' }} className="tab">{lowCount} <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--muted)' }}>items</span></div>
            </div>
          </React.Fragment>
        ) : (
          <React.Fragment>
            <div className="card" style={{ flex: 1, padding: '12px 14px' }}>
              <div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>Used today</div>
              <div style={{ fontSize: 20, fontWeight: 700, marginTop: 2 }} className="tab">{money(usedVal)}</div>
            </div>
            <div className="card" style={{ flex: 1, padding: '12px 14px' }}>
              <div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>Top item</div>
              <div style={{ fontSize: 15, fontWeight: 700, marginTop: 3 }} className="ell">{topMover.name}</div>
              <div style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 500, marginTop: 1 }}>{usedToday(topMover)} {topMover.unit} today</div>
            </div>
          </React.Fragment>
        )}
      </div>

      {/* view toggle + advanced */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
        <div className="seg lime" style={{ flex: '0 0 auto', width: 224 }}>
          <button className={view === 'stock' ? 'active' : ''} onClick={() => setView('stock')}>In stock</button>
          <button className={view === 'used' ? 'active' : ''} onClick={() => setView('used')}>Used today</button>
        </div>
        {view === 'stock' && <AdvToggle on={adv} onChange={setAdv} label={b.t('word.advanced')} />}
      </div>

      {/* stock table — qty is the hero, value is demoted under the name */}
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <div className="card" style={{ padding: '4px 15px 10px' }}>
          {/* header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 0 9px', borderBottom: '1.5px solid var(--line-2)' }}>
            <span style={{ width: 10, flex: '0 0 10px' }} />
            <span className="eyebrow" style={{ flex: 1, fontSize: 10.5 }}>Item</span>
            {showCover && <span className="eyebrow" style={{ width: 46, flex: '0 0 46px', textAlign: 'right', fontSize: 10.5 }}>Cover</span>}
            {view === 'stock' ? (
              <button onClick={() => setShowSort(true)} style={{ width: heroW, flex: '0 0 ' + heroW + 'px', border: 'none', background: 'transparent', cursor: 'pointer', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 3, font: 'inherit' }}>
                <span className="eyebrow" style={{ fontSize: 10.5, color: 'var(--ink-2)' }}>On hand</span><Icon name="chevd" size={11} color="var(--muted)" sw={2.4} />
              </button>
            ) : (
              <span className="eyebrow" style={{ width: heroW, flex: '0 0 ' + heroW + 'px', textAlign: 'right', fontSize: 10.5 }}>Used today</span>
            )}
          </div>
          {sorted.map((it, i) => {
            const k = stockKind(it);
            const cv = coverDays(it);
            const ut = usedToday(it);
            const last = i === sorted.length - 1;
            return (
              <div key={it.id} onClick={() => openRow(it)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 0', cursor: 'pointer', borderBottom: last ? 'none' : '1px solid var(--line)' }}>
                {/* status lane — fixed width keeps the hero column aligned */}
                <span style={{ width: 10, flex: '0 0 10px', display: 'grid', placeItems: 'center' }}>
                  {view === 'stock' && k !== 'ok' && <span style={{ width: 8, height: 8, borderRadius: '50%', background: k === 'low' ? 'var(--warning)' : 'var(--danger)' }} />}
                </span>
                {/* name + demoted secondary value */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 15, fontWeight: 600 }} className="ell">{it.name}</div>
                  <div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 500, marginTop: 2 }} className="ell">{view === 'stock' ? money(it.qty * it.cost) : money(ut * it.cost) + ' used'}</div>
                </div>
                {showCover && <div style={{ width: 46, flex: '0 0 46px', textAlign: 'right', fontSize: 13, fontWeight: 600, color: cv <= 2 ? 'var(--danger)' : cv <= 5 ? 'var(--warning)' : 'var(--ink-2)' }} className="tab">{cv >= 99 ? '—' : cv + 'd'}</div>}
                {/* hero number */}
                <div style={{ width: heroW, flex: '0 0 ' + heroW + 'px', textAlign: 'right' }} className="tab">
                  <span style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-.01em', color: view === 'used' ? 'var(--ink)' : k === 'no' ? 'var(--danger)' : k === 'low' ? 'var(--warning)' : 'var(--ink)' }}>{view === 'stock' ? it.qty : ut}</span>
                  <span style={{ fontSize: 12.5, color: 'var(--muted)', fontWeight: 600 }}> {it.unit}</span>
                </div>
              </div>
            );
          })}
        </div>

        {/* advanced drill-downs (stock view only) */}
        {adv && view === 'stock' && (
          <div style={{ marginTop: 14 }}>
            <div className="eyebrow" style={{ margin: '0 2px 9px' }}>Advanced</div>
            <div onClick={() => b.push({ screen: 'stockTrends' })} className="card" style={{ padding: 14, cursor: 'pointer', marginBottom: 10, display: 'flex', alignItems: 'center', gap: 12, background: 'var(--accent-tint)', borderColor: 'var(--accent-tint-2)' }}>
              <div style={{ width: 38, height: 38, borderRadius: 10, background: 'var(--accent)', display: 'grid', placeItems: 'center', flex: '0 0 38px' }}><Icon name="chart" size={20} color="var(--accent-ink)" /></div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14.5, fontWeight: 700 }}>Stock over time</div>
                <div style={{ fontSize: 12, color: 'var(--ink-2)', marginTop: 1 }} className="ell">Value, usage, cover &amp; spend across periods</div>
              </div>
              <Icon name="chev" size={18} color="var(--accent-strong)" />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              {[['variance', 'Daily variance', 'variance', 'Expected vs counted'], ['suppliers', 'Suppliers', 'truck', b.suppliers.length + ' active']].map(([scr, label, ic, hint]) => (
                <div key={scr} onClick={() => b.push({ screen: scr })} className="card" style={{ padding: 13, cursor: 'pointer' }}>
                  <div style={{ width: 34, height: 34, borderRadius: 9, background: 'var(--surface-2)', color: 'var(--ink-2)', display: 'grid', placeItems: 'center', marginBottom: 9 }}><Icon name={ic} size={18} /></div>
                  <div style={{ fontSize: 14, fontWeight: 700 }}>{label}</div>
                  <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 1 }} className="ell">{hint}</div>
                </div>
              ))}
            </div>
            <div style={{ fontSize: 12, color: 'var(--muted)', margin: '12px 2px 0', display: 'flex', alignItems: 'center', gap: 6 }}><Icon name="bolt" size={14} color="var(--accent-strong)" />Tap any item above for usage &amp; adjustment history.</div>
          </div>
        )}
      </div>

      {/* labeled actions at the bottom — no top-bar buttons */}
      <div className="bottombar" style={{ gap: 9 }}>
        <button className="btn btn-ghost btn-lg" style={{ flex: '0 0 auto', width: 132 }} onClick={() => b.push({ screen: 'startCount' })}><Icon name="count" size={19} />{b.t('act.count')}</button>
        <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={() => b.push({ screen: 'stockIn', itemId: null })}><Icon name="boxin" size={20} color="var(--accent-ink)" sw={2} />{b.t('act.stockin')}</button>
      </div>

      {/* sort sheet */}
      <Sheet open={showSort} onClose={() => setShowSort(false)}>
        <div style={{ padding: '6px 18px 22px' }}>
          <div style={{ fontSize: 19, fontWeight: 700, marginBottom: 14 }}>Sort stock by</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {sortOpts.map((key) => (
              <button key={key} onClick={() => pickSort(key)} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '13px 15px', borderRadius: 'var(--r-md)', border: '1px solid ' + (sort === key ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: sort === key ? 'var(--accent-tint)' : 'var(--surface)', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 15, fontWeight: 600, color: sort === key ? 'var(--accent-strong)' : 'var(--ink)' }}>
                {SORT_LABELS[key]}
                {sort === key && <Icon name="check2" size={18} sw={2.2} />}
              </button>
            ))}
          </div>
        </div>
      </Sheet>
    </React.Fragment>
  );
}

/* ---------- stock-in ---------- */
function StockIn({ itemId, fromScan }) {
  const b = useBytes();
  const item = itemId ? b.inventory.find((i) => i.id === itemId) : null;
  const [rows, setRows] = useState(() => {
    if (fromScan) return [
      { name: 'Chicken (whole)', qty: 40, unit: 'kg', cost: 230 },
      { name: 'Basmati Rice', qty: 50, unit: 'kg', cost: 138 },
      { name: 'Cooking Oil', qty: 20, unit: 'L', cost: 182 },
      { name: 'Onions', qty: 25, unit: 'kg', cost: 52 },
      { name: 'Potatoes', qty: 30, unit: 'kg', cost: 34 },
    ];
    if (item) return [{ name: item.name, qty: 10, unit: item.unit, cost: item.cost }];
    return [{ name: '', qty: '', unit: 'kg', cost: '' }];
  });
  const [scan, setScan] = useState(false);
  const total = rows.reduce((s, r) => s + (Number(r.qty) || 0) * (Number(r.cost) || 0), 0);
  const setRow = (i, k, v) => setRows((rs) => rs.map((r, j) => j === i ? { ...r, [k]: v } : r));

  return (
    <React.Fragment>
      <Header title={fromScan ? 'Confirm stock-in' : b.t('act.stockin')} sub={fromScan ? 'From scanned bill · Karim Traders' : item ? item.name : 'Add received stock'} onBack={b.pop} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {fromScan && (
          <div className="card" style={{ padding: '11px 13px', display: 'flex', alignItems: 'center', gap: 10, background: 'var(--accent-tint)', borderColor: 'var(--accent-tint-2)', marginBottom: 2 }}>
            <Icon name="sparkle" size={19} color="var(--accent-strong)" fill /><div style={{ fontSize: 13, color: 'var(--ink-2)' }}><b>{rows.length} lines</b> read from the bill · tweak any value</div>
          </div>
        )}
        {rows.map((r, i) => (
          <div key={i} className="card" style={{ padding: 13 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
              <div style={{ width: 36, height: 36, borderRadius: 8, background: 'var(--surface-2)', display: 'grid', placeItems: 'center', color: 'var(--ink-2)', flex: '0 0 36px' }}><Icon name="box" size={19} /></div>
              <input value={r.name} onChange={(e) => setRow(i, 'name', e.target.value)} placeholder="Item name" style={{ flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent', fontFamily: 'var(--font)', fontSize: 15, fontWeight: 600, color: 'var(--ink)' }} />
              {rows.length > 1 && <button onClick={() => setRows((rs) => rs.filter((_, j) => j !== i))} style={{ width: 30, height: 30, border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--muted)', flex: '0 0 30px' }}><Icon name="x" size={17} /></button>}
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 600, marginBottom: 4 }}>Quantity</div><div className="field" style={{ height: 40 }}><input value={r.qty} onChange={(e) => setRow(i, 'qty', e.target.value.replace(/\D/g, ''))} placeholder="0" inputMode="numeric" style={{ minWidth: 0 }} /><span style={{ fontSize: 13, color: 'var(--muted)', fontWeight: 600 }}>{r.unit}</span></div></div>
              <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 600, marginBottom: 4 }}>Cost / {r.unit}</div><div className="field" style={{ height: 40 }}><Icon name="taka" size={16} /><input value={r.cost} onChange={(e) => setRow(i, 'cost', e.target.value.replace(/\D/g, ''))} placeholder="0" inputMode="numeric" style={{ minWidth: 0 }} /></div></div>
            </div>
          </div>
        ))}
        <button onClick={() => setRows((rs) => [...rs, { name: '', qty: '', unit: 'kg', cost: '' }])} style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9, padding: 12, border: '1px dashed var(--line-2)', borderRadius: 'var(--r-md)', background: 'var(--surface)', cursor: 'pointer', color: 'var(--accent-strong)', fontWeight: 600, fontSize: 14 }}><Icon name="plus" size={18} sw={2} />Add another line</button>
      </div>
      <div className="bottombar" style={{ flexDirection: 'column', gap: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', width: '100%', marginBottom: 10 }}>
          <span style={{ fontSize: 13, color: 'var(--muted)', fontWeight: 600 }}>Total stock-in value</span>
          <span style={{ fontSize: 20, fontWeight: 700 }} className="tab">{money(total)}</span>
        </div>
        <div style={{ display: 'flex', gap: 9, width: '100%' }}>
          <button className="btn btn-ghost btn-lg" style={{ flex: '0 0 auto', width: 130 }} onClick={() => setScan(true)}><Icon name="camera" size={19} />{b.t('act.scanBill')}</button>
          <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={b.pop}><Icon name="check" size={19} color="var(--accent-ink)" sw={2.4} />{b.t('act.addInv')}</button>
        </div>
      </div>
      {scan && <AIScan variant="bill" onClose={() => setScan(false)} onApply={(r) => { setScan(false); setRows(r.map((x) => ({ name: x.name, qty: x.qty, unit: x.unit, cost: x.cost }))); }} />}
    </React.Fragment>
  );
}

/* ---------- start count ---------- */
function StartCount() {
  const b = useBytes();
  const items = [...b.inventory].sort((a, c) => c.moves - a.moves);
  const [counts, setCounts] = useState({});
  const [scan, setScan] = useState(false);
  const done = Object.keys(counts).length;

  return (
    <React.Fragment>
      <Header title="Stock count" sub={done + ' of ' + items.length + ' counted'} onBack={b.pop} />
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px' }}>
        <div style={{ height: 6, borderRadius: 3, background: 'var(--surface-2)', overflow: 'hidden' }}><div style={{ width: (done / items.length * 100) + '%', height: '100%', background: 'var(--accent)', borderRadius: 3, transition: 'width .2s' }} /></div>
      </div>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {items.map((it) => {
          const c = counts[it.id];
          const variance = c != null && c !== '' ? Number(c) - it.qty : null;
          return (
            <div key={it.id} className="row" style={{ borderColor: c != null && c !== '' ? 'var(--accent-tint-2)' : 'var(--line)' }}>
              <div style={{ width: 36, height: 36, borderRadius: 8, background: c != null && c !== '' ? 'var(--accent)' : 'var(--surface-2)', display: 'grid', placeItems: 'center', color: c != null && c !== '' ? 'var(--accent-ink)' : 'var(--ink-2)', flex: '0 0 36px' }}><Icon name={c != null && c !== '' ? 'check' : 'box'} size={18} sw={c != null && c !== '' ? 2.4 : 1.8} /></div>
              <div className="mid">
                <div className="nm ell">{it.name}</div>
                <div className="ds">System: {it.qty} {it.unit}{variance != null && variance !== 0 && <span style={{ color: variance < 0 ? 'var(--danger)' : 'var(--success)', fontWeight: 600 }}> · {variance > 0 ? '+' : ''}{variance} variance</span>}</div>
              </div>
              <div className="field" style={{ width: 78, height: 42, flex: '0 0 78px', padding: '0 10px' }}><input value={c ?? ''} onChange={(e) => setCounts((s) => ({ ...s, [it.id]: e.target.value.replace(/\D/g, '') }))} placeholder="—" inputMode="numeric" style={{ textAlign: 'center', fontWeight: 700 }} /></div>
            </div>
          );
        })}
      </div>
      <div className="bottombar" style={{ gap: 9 }}>
        <button className="btn btn-ghost btn-lg" style={{ flex: '0 0 auto', width: 120 }} onClick={() => setScan(true)}><Icon name="camera" size={19} />{b.t('act.scan')}</button>
        <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={b.pop}><Icon name="check" size={19} color="var(--accent-ink)" sw={2.4} />{b.t('act.finishCount')}{done > 0 ? ' · ' + done : ''}</button>
      </div>
      {scan && <AIScan variant="bill" onClose={() => setScan(false)} onApply={() => setScan(false)} />}
    </React.Fragment>
  );
}

/* ---------- item detail (advanced) — usage + adjustment history ---------- */
function ItemDetail({ itemId }) {
  const b = useBytes();
  const it = b.inventory.find((i) => i.id === itemId);
  if (!it) return <div style={{ padding: 20 }}>Item not found.</div>;
  const cv = coverDays(it);
  const history = [
    { kind: 'in', label: 'Stock-in · Karim Traders', qty: '+40 ' + it.unit, mins: 180 },
    { kind: 'use', label: 'Sold (recipe usage)', qty: '−12 ' + it.unit, mins: 360 },
    { kind: 'waste', label: 'Wastage · spoiled', qty: '−2 ' + it.unit, mins: 720 },
    { kind: 'count', label: 'Count adjustment', qty: '−1 ' + it.unit, mins: 1440 },
    { kind: 'meal', label: 'Staff meal', qty: '−1.5 ' + it.unit, mins: 1500 },
  ];
  const HK = { in: ['boxin', 'var(--success)'], use: ['receipt', 'var(--ink-2)'], waste: ['trash', 'var(--danger)'], count: ['count', 'var(--info)'], meal: ['users', 'var(--warning)'] };
  const Stat = ({ label, value, sub }) => (
    <div className="card" style={{ flex: 1, padding: '11px 13px' }}><div style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>{label}</div><div style={{ fontSize: 18, fontWeight: 700, marginTop: 2 }} className="tab">{value}</div>{sub && <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 1 }}>{sub}</div>}</div>
  );
  return (
    <React.Fragment>
      <Header title={it.name} sub={it.cat + ' · ' + it.unit} onBack={b.pop} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <div style={{ display: 'flex', gap: 10, marginBottom: 10 }}>
          <Stat label="On hand" value={it.qty + ' ' + it.unit} sub={'par ' + it.par} />
          <Stat label="Cover" value={cv >= 99 ? '—' : cv + ' days'} sub={'~' + Math.round(it.used7 / 7) + '/day'} />
          <Stat label="Value" value={money(it.qty * it.cost)} sub={'@ ' + money(it.cost)} />
        </div>
        <div className="card" style={{ padding: '12px 14px', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12.5, color: 'var(--muted)', fontWeight: 600 }}>7-day usage</div>
            <div style={{ fontSize: 16, fontWeight: 700, marginTop: 1 }} className="tab">{it.used7} {it.unit} <span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>used</span></div>
          </div>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 3, height: 34 }}>
            {[6, 9, 5, 11, 8, 13, 10].map((h, i) => <div key={i} style={{ width: 6, height: h * 2.4, borderRadius: 2, background: i === 5 ? 'var(--accent)' : 'var(--surface-3)' }} />)}
          </div>
        </div>
        <div className="eyebrow" style={{ margin: '0 2px 10px' }}>Adjustment history</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
          {history.map((h, i) => {
            const [ic, fg] = HK[h.kind];
            return (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
                <div style={{ width: 32, height: 32, borderRadius: 8, background: 'var(--surface-2)', color: fg, display: 'grid', placeItems: 'center', flex: '0 0 32px' }}><Icon name={ic} size={16} /></div>
                <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 13.5, fontWeight: 600 }} className="ell">{h.label}</div><div style={{ fontSize: 11.5, color: 'var(--muted)' }}>{h.mins < 60 ? h.mins + 'm' : Math.round(h.mins / 60) + 'h'} ago</div></div>
                <span style={{ fontSize: 14, fontWeight: 700, color: h.qty[0] === '+' ? 'var(--success)' : 'var(--ink)', flex: '0 0 auto' }} className="tab">{h.qty}</span>
              </div>
            );
          })}
        </div>
      </div>
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg" onClick={() => b.push({ screen: 'stockIn', itemId })}><Icon name="boxin" size={20} color="var(--accent-ink)" sw={2} />{b.t('act.stockin')}</button>
      </div>
    </React.Fragment>
  );
}

/* ---------- daily variance (advanced) ---------- */
function VarianceScreen() {
  const b = useBytes();
  const rows = b.inventory.map((it) => { const counted = Math.max(0, it.qty - (it.id.charCodeAt(1) % 3)); return { ...it, counted, diff: counted - it.qty }; }).filter((r) => r.diff !== 0);
  const lossVal = rows.reduce((s, r) => s + Math.min(0, r.diff) * r.cost, 0);
  return (
    <React.Fragment>
      <Header title="Daily variance" sub="Expected vs counted · today" onBack={b.pop} />
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px', display: 'flex', gap: 10 }}>
        <div className="card" style={{ flex: 1, padding: '12px 14px' }}><div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>Variance loss</div><div style={{ fontSize: 20, fontWeight: 700, marginTop: 2, color: 'var(--danger)' }} className="tab">{money(lossVal)}</div></div>
        <div className="card" style={{ flex: 1, padding: '12px 14px' }}><div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>Items off</div><div style={{ fontSize: 20, fontWeight: 700, marginTop: 2 }} className="tab">{rows.length}</div></div>
      </div>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <div className="card" style={{ padding: '4px 14px 8px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 0 8px', borderBottom: '1.5px solid var(--line-2)' }}>
            <span className="eyebrow" style={{ flex: 1, fontSize: 10.5 }}>ITEM</span>
            <span className="eyebrow" style={{ width: 56, textAlign: 'right', fontSize: 10.5 }}>SYSTEM</span>
            <span className="eyebrow" style={{ width: 56, textAlign: 'right', fontSize: 10.5 }}>COUNTED</span>
            <span className="eyebrow" style={{ width: 50, textAlign: 'right', fontSize: 10.5 }}>DIFF</span>
          </div>
          {rows.map((r, i) => (
            <div key={r.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '11px 0', borderBottom: i === rows.length - 1 ? 'none' : '1px solid var(--line)' }}>
              <span style={{ flex: 1, fontSize: 14, fontWeight: 600 }} className="ell">{r.name}</span>
              <span style={{ width: 56, textAlign: 'right', fontSize: 13.5, color: 'var(--muted)' }} className="tab">{r.qty}</span>
              <span style={{ width: 56, textAlign: 'right', fontSize: 13.5, fontWeight: 600 }} className="tab">{r.counted}</span>
              <span style={{ width: 50, textAlign: 'right', fontSize: 14, fontWeight: 700, color: r.diff < 0 ? 'var(--danger)' : 'var(--success)' }} className="tab">{r.diff > 0 ? '+' : ''}{r.diff}</span>
            </div>
          ))}
        </div>
      </div>
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg" onClick={b.pop}><Icon name="download" size={19} color="var(--accent-ink)" />Share variance report</button>
      </div>
    </React.Fragment>
  );
}

/* ---------- suppliers (advanced) ---------- */
function SuppliersScreen() {
  const b = useBytes();
  return (
    <React.Fragment>
      <Header title="Suppliers" sub={b.suppliers.length + ' suppliers'} onBack={b.pop} />
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {b.suppliers.map((s) => (
          <div key={s.id} className="card" style={{ padding: 13, display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 42, height: 42, borderRadius: 11, background: 'var(--surface-2)', color: 'var(--ink-2)', display: 'grid', placeItems: 'center', flex: '0 0 42px' }}><Icon name="truck" size={20} /></div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14.5, fontWeight: 700 }} className="ell">{s.name}</div>
              <div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 1 }} className="ell">{s.items}</div>
              <div style={{ fontSize: 11.5, color: 'var(--placeholder)', marginTop: 2 }}>Last order {s.last} · {s.phone}</div>
            </div>
            <button style={{ width: 38, height: 38, borderRadius: 9, border: '1px solid var(--line-2)', background: 'var(--surface)', display: 'grid', placeItems: 'center', cursor: 'pointer', color: 'var(--ink-2)', flex: '0 0 38px' }}><Icon name="phone" size={18} /></button>
          </div>
        ))}
      </div>
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg"><Icon name="plus" size={20} color="var(--accent-ink)" sw={2} />Add supplier</button>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { InventoryScreen, StockIn, StartCount, ItemDetail, VarianceScreen, SuppliersScreen, stockKind, coverDays, usedToday });
