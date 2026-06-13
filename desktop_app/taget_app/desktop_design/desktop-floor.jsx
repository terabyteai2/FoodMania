/* ============================================================
   QuickBytes Desktop — Tables (floor), Stock (ranked table),
   and the role-aware Dashboard (Owner = Analytics, Manager =
   Live / Control Tower). Occupied tables = calm slate wash.
   ============================================================ */
const { useState: dFloorState, useMemo: dFloorMemo } = React;

/* ============================ TABLES (floor) ============================ */
function TablesScreen() {
  const d = useDesk();
  const lang = d.lang;
  const occ = d.occupiedTables;
  const occCount = Object.keys(occ).length;
  return (
    <div className="dk-main">
      <DeskHead title={lang === 'bn' ? 'টেবিল' : 'Tables'} sub={(lang === 'bn' ? '' : '') + occCount + (lang === 'bn' ? ' টেবিল চলছে · ' : ' seated · ') + (TABLES.length - occCount) + (lang === 'bn' ? ' খালি' : ' free')}
        right={(
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="btn btn-ghost" onClick={() => d.startType('parcel')}><Icon name="bag" size={17} />{lang === 'bn' ? 'নতুন পার্সেল' : 'New parcel'}</button>
            <button className="btn btn-ghost" onClick={() => d.startType('delivery')}><Icon name="truck" size={17} />{lang === 'bn' ? 'নতুন ডেলিভারি' : 'New delivery'}</button>
          </div>
        )} />
      <div className="dk-pane noscroll">
        <div style={{ display: 'flex', gap: 16, marginBottom: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13.5, color: 'var(--ink-2)', fontWeight: 600 }}><span style={{ width: 12, height: 12, borderRadius: 3, background: 'var(--seat-tint)', border: '1px solid var(--seat-line)' }} />{lang === 'bn' ? 'চলছে' : 'Occupied'} {occCount}</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13.5, color: 'var(--ink-2)', fontWeight: 600 }}><span style={{ width: 12, height: 12, borderRadius: 3, background: 'var(--surface)', border: '1px solid var(--line-2)' }} />{lang === 'bn' ? 'খালি' : 'Free'} {TABLES.length - occCount}</div>
        </div>
        <div className="dk-floor">
          {TABLES.map((tb) => {
            const o = occ[tb.id];
            if (o) {
              const total = orderTotal(o);
              return (
                <button key={tb.id} className="dk-tableqr occ" onClick={() => d.openTableOrder(o.id)}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ fontSize: 24, fontWeight: 800, color: 'var(--seat-ink)' }}>{tb.id.replace('T', '')}</span>
                    <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--seat-ink)', display: 'inline-flex', alignItems: 'center', gap: 4 }}><Icon name="clock" size={13} />{o.mins}m</span>
                  </div>
                  <div style={{ marginTop: 'auto', textAlign: 'left' }}>
                    <div style={{ fontSize: 12, color: 'var(--seat-ink)', fontWeight: 600 }}>{o.lines.reduce((s, l) => s + l.qty, 0)} {lang === 'bn' ? 'আইটেম' : 'items'}{o.server ? ' · ' + o.server : ''}</div>
                    <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--ink)', fontVariantNumeric: 'tabular-nums', marginTop: 1 }}>{money(total)}</div>
                  </div>
                  <div style={{ marginTop: 8 }}><span className="badge" style={{ background: 'var(--seat-line)', color: 'var(--seat-ink)' }}>{o.state === 'pending' ? (lang === 'bn' ? 'নতুন' : 'New') : (lang === 'bn' ? 'চলছে' : 'Running')}</span></div>
                </button>
              );
            }
            return (
              <button key={tb.id} className="dk-tableqr" onClick={() => d.startDineIn(tb.id)}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <span style={{ fontSize: 24, fontWeight: 800 }}>{tb.id.replace('T', '')}</span>
                  <span style={{ fontSize: 12, color: 'var(--muted)', display: 'inline-flex', alignItems: 'center', gap: 4 }}><Icon name="user" size={13} />{tb.seats}</span>
                </div>
                <div style={{ marginTop: 'auto', textAlign: 'left' }}>
                  <div style={{ fontSize: 13.5, color: 'var(--muted)', fontWeight: 600 }}>{lang === 'bn' ? 'খালি' : 'Free'}</div>
                </div>
                <div style={{ marginTop: 8, display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 12.5, fontWeight: 700, color: 'var(--accent-strong)' }}><Icon name="plus" size={14} sw={2.2} />{lang === 'bn' ? 'অর্ডার শুরু' : 'Start order'}</div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

/* ============================ STOCK (ranked) ============================ */
function stockKind(it) { const r = it.qty / it.par; return r >= 0.6 ? 'ok' : r >= 0.3 ? 'low' : 'no'; }
function StockScreen() {
  const d = useDesk();
  const lang = d.lang;
  const [adv, setAdv] = dFloorState(false);
  const [sort, setSort] = dFloorState('value');
  const rows = dFloorMemo(() => {
    const arr = d.inventory.map((it) => ({ ...it, value: it.qty * it.cost, cover: Math.round(it.qty / it.used7 * 7), kind: stockKind(it) }));
    arr.sort((a, b) => sort === 'value' ? b.value - a.value : sort === 'qty' ? b.qty - a.qty : sort === 'cover' ? a.cover - b.cover : a.name.localeCompare(b.name));
    return arr;
  }, [d.inventory, sort]);
  const totalValue = rows.reduce((s, r) => s + r.value, 0);
  const below = rows.filter((r) => r.kind !== 'ok').length;
  const SK = { ok: null, low: 'var(--warning)', no: 'var(--danger)' };

  return (
    <div className="dk-main">
      <DeskHead title={lang === 'bn' ? 'স্টক' : 'Stock'} sub="Spice Garden · Dhanmondi"
        right={<div onClick={() => setAdv(!adv)} style={{ display: 'inline-flex', alignItems: 'center', gap: 9, height: 38, padding: '0 8px 0 14px', borderRadius: 'var(--r-md)', border: '1px solid ' + (adv ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: adv ? 'var(--accent-tint)' : 'var(--surface)', cursor: 'pointer' }}>
          <span style={{ fontSize: 13, fontWeight: 700, color: adv ? 'var(--accent-strong)' : 'var(--ink-2)' }}>{lang === 'bn' ? 'অ্যাডভান্সড' : 'Advanced'}</span>
          <div className={'toggle' + (adv ? ' on' : '')} style={{ width: 40, height: 23, flex: '0 0 40px' }}><div className="knob" style={{ width: 17, height: 17, top: 3, left: adv ? 20 : 3 }} /></div>
        </div>} />
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', gap: 14, padding: '18px 22px 14px' }}>
          <div className="dk-kpi" style={{ flex: 1 }}><div className="k">{lang === 'bn' ? 'স্টক মূল্য' : 'Stock value'}</div><div className="v">{money(totalValue)}</div></div>
          <div className="dk-kpi" style={{ flex: 1 }}><div className="k">{lang === 'bn' ? 'পার-এর নিচে' : 'Below par'}</div><div className="v" style={{ color: below ? 'var(--warning)' : 'var(--ink)' }}>{below} {lang === 'bn' ? 'আইটেম' : 'items'}</div></div>
          <div className="dk-kpi" style={{ flex: 1 }}><div className="k">{lang === 'bn' ? 'মোট আইটেম' : 'Tracked items'}</div><div className="v">{rows.length}</div></div>
          <div style={{ flex: 1.4, display: 'flex', alignItems: 'flex-end', justifyContent: 'flex-end', gap: 7 }}>
            {[['value', lang === 'bn' ? 'মূল্য' : 'Value'], ['qty', lang === 'bn' ? 'পরিমাণ' : 'Qty'], ...(adv ? [['cover', lang === 'bn' ? 'কভার' : 'Cover']] : []), ['name', 'A–Z']].map(([id, lb]) => (
              <button key={id} className={'chip' + (sort === id ? ' active' : '')} onClick={() => setSort(id)}>{lb}</button>
            ))}
          </div>
        </div>
        <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '0 22px' }} className="noscroll">
          <table className="dk-table">
            <thead><tr>
              <th style={{ width: 34 }}></th>
              <th style={{ width: 30 }}>#</th>
              <th>{lang === 'bn' ? 'আইটেম' : 'Item'}</th>
              {adv && <th className="dk-num" style={{ width: 110 }}>{lang === 'bn' ? 'কভার' : 'Cover'}</th>}
              <th className="dk-num" style={{ width: 130 }}>{lang === 'bn' ? 'মূল্য' : 'Value'}</th>
              <th style={{ width: 110 }}>{lang === 'bn' ? 'পরিমাণ' : 'Qty'}</th>
            </tr></thead>
            <tbody>
              {rows.map((r, i) => (
                <tr key={r.id}>
                  <td style={{ textAlign: 'center' }}>{SK[r.kind] && <span style={{ display: 'inline-block', width: 9, height: 9, borderRadius: '50%', background: SK[r.kind] }} />}</td>
                  <td className="tab" style={{ color: 'var(--muted)', fontWeight: 600 }}>{i + 1}</td>
                  <td><div style={{ fontWeight: 600 }}>{r.name}</div><div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 1 }}>{r.cat}{r.kind !== 'ok' ? ' · ' + (lang === 'bn' ? 'পার ' : 'par ') + r.par + ' ' + r.unit : ''}</div></td>
                  {adv && <td className="dk-num" style={{ fontWeight: 600, color: r.cover <= 2 ? 'var(--danger)' : r.cover <= 4 ? 'var(--warning)' : 'var(--ink-2)' }}>{r.cover} {lang === 'bn' ? 'দিন' : 'days'}</td>}
                  <td className="dk-num" style={{ fontWeight: 700 }}>{money(r.value)}</td>
                  <td className="tab" style={{ fontWeight: 700 }}>{r.qty} <span style={{ color: 'var(--muted)', fontWeight: 500 }}>{r.unit}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div style={{ flex: '0 0 auto', borderTop: '1px solid var(--line)', padding: '12px 22px', background: 'var(--surface)', display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
          <button className="btn btn-ghost btn-lg" onClick={() => d.toast(lang === 'bn' ? 'স্টক গণনা শুরু' : 'Starting count')}><Icon name="count" size={18} />{lang === 'bn' ? 'গণনা' : 'Count'}</button>
          <button className="btn btn-primary btn-lg" onClick={() => d.toast(lang === 'bn' ? 'স্টক ইন' : 'Stock in')}><Icon name="boxin" size={18} />{lang === 'bn' ? 'স্টক ইন' : 'Stock in'}</button>
        </div>
      </div>
    </div>
  );
}

/* ============================ DASHBOARD (Analytics / Live) ============================ */
function Donut({ data, size = 116 }) {
  const r = size / 2 - 11, c = 2 * Math.PI * r;
  let acc = 0;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <g transform={`rotate(-90 ${size / 2} ${size / 2})`}>
        {data.map(([label, pct, color], i) => {
          const len = c * pct / 100; const off = c * acc / 100; acc += pct;
          return <circle key={i} cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={14} strokeDasharray={`${len} ${c - len}`} strokeDashoffset={-off} />;
        })}
      </g>
    </svg>
  );
}
function DashboardScreen() {
  const d = useDesk();
  const lang = d.lang;
  const owner = d.role === 'owner';
  const A = ANALYTICS;
  const maxBar = Math.max(...A.sales7);
  const delta = Math.round((A.today.revenue - A.today.prevRevenue) / A.today.prevRevenue * 100);

  return (
    <div className="dk-main">
      <DeskHead title={owner ? (lang === 'bn' ? 'বিশ্লেষণ' : 'Analytics') : (lang === 'bn' ? 'কন্ট্রোল টাওয়ার' : 'Control Tower')} sub={owner ? (lang === 'bn' ? 'আজ · স্পাইস গার্ডেন' : 'Today · Spice Garden') : (lang === 'bn' ? 'লাইভ অপারেশন' : 'Live operations')}
        right={<div className="dk-seg"><button className="on">{lang === 'bn' ? 'আজ' : 'Today'}</button><button>7d</button><button>30d</button></div>} />
      <div className="dk-pane noscroll">
        {/* hero + KPIs */}
        <div style={{ display: 'flex', gap: 16 }}>
          <div style={{ flex: '0 0 320px', background: 'var(--accent-tint)', border: '1px solid var(--accent-tint-2)', borderRadius: 'var(--r-lg)', padding: 20 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--accent-strong)' }}>{lang === 'bn' ? 'নেট সেলস' : 'Net sales'}</div>
            <div style={{ fontSize: 40, fontWeight: 800, letterSpacing: '-.03em', fontVariantNumeric: 'tabular-nums', marginTop: 4 }}>{money(A.today.revenue)}</div>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, marginTop: 8, fontSize: 13.5, fontWeight: 700, color: 'var(--success)' }}><Icon name="trendup" size={16} />{delta}% {lang === 'bn' ? 'গতকালের তুলনায়' : 'vs yesterday'}</div>
          </div>
          {[[lang === 'bn' ? 'অর্ডার' : 'Orders', A.today.orders], [lang === 'bn' ? 'গড় অর্ডার' : 'Avg order', money(A.today.aov)], [lang === 'bn' ? 'মার্জিন' : 'Margin', Math.round(A.today.margin * 100) + '%'], [owner ? (lang === 'bn' ? 'ডাইন-ইন' : 'Dine-in share') : (lang === 'bn' ? 'খোলা অর্ডার' : 'Open orders'), owner ? Math.round(A.today.dineRev * 100) + '%' : d.orders.filter((o) => o.state !== 'completed').length]].map(([k, v], i) => (
            <div key={i} className="dk-kpi" style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}><div className="k">{k}</div><div className="v">{v}</div></div>
          ))}
        </div>

        {/* manager: attention row */}
        {!owner && (
          <div style={{ display: 'flex', gap: 12, marginTop: 16 }}>
            <div className="card" style={{ flex: 1, padding: 14, display: 'flex', alignItems: 'center', gap: 11, borderColor: 'var(--warning-soft)' }}>
              <div style={{ width: 36, height: 36, borderRadius: 9, background: 'var(--warning-soft)', color: 'var(--warning)', display: 'grid', placeItems: 'center', flex: '0 0 36px' }}><Icon name="clock" size={19} /></div>
              <div><div style={{ fontSize: 14, fontWeight: 700 }}>{lang === 'bn' ? '২টি অর্ডার দেরিতে' : '2 orders running late'}</div><div style={{ fontSize: 12.5, color: 'var(--muted)' }}>{lang === 'bn' ? '#22 ও #19 · ১৫ মিনিটের বেশি' : '#22 and #19 · over 15 min'}</div></div>
              <button className="btn btn-ghost btn-sm" style={{ marginLeft: 'auto' }} onClick={() => d.setTab('orders')}>{lang === 'bn' ? 'দেখুন' : 'View'}</button>
            </div>
            <div className="card" style={{ flex: 1, padding: 14, display: 'flex', alignItems: 'center', gap: 11, borderColor: 'var(--danger-soft)' }}>
              <div style={{ width: 36, height: 36, borderRadius: 9, background: 'var(--danger-soft)', color: 'var(--danger)', display: 'grid', placeItems: 'center', flex: '0 0 36px' }}><Icon name="box" size={19} /></div>
              <div><div style={{ fontSize: 14, fontWeight: 700 }}>{lang === 'bn' ? '৪টি আইটেম পার-এর নিচে' : '4 items below par'}</div><div style={{ fontSize: 12.5, color: 'var(--muted)' }}>{lang === 'bn' ? 'বিফ, মোজারেলা…' : 'Beef, Mozzarella, Buns…'}</div></div>
              <button className="btn btn-ghost btn-sm" style={{ marginLeft: 'auto' }} onClick={() => d.setTab('inventory')}>{lang === 'bn' ? 'স্টক' : 'Stock'}</button>
            </div>
          </div>
        )}

        {/* trend + breakdowns */}
        <div style={{ display: 'flex', gap: 16, marginTop: 16, alignItems: 'stretch' }}>
          <div className="card" style={{ flex: 1.5, padding: 18 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
              <span style={{ fontSize: 15, fontWeight: 700 }}>{lang === 'bn' ? 'সাপ্তাহিক সেলস' : 'Sales this week'}</span>
              <span style={{ fontSize: 12.5, color: 'var(--muted)' }}>{lang === 'bn' ? 'হাজার ৳' : '৳ thousands'}</span>
            </div>
            <div className="bars" style={{ height: 150 }}>
              {A.sales7.map((v, i) => (
                <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7, justifyContent: 'flex-end' }}>
                  <div className={'b' + (i === A.sales7.length - 1 ? ' hi' : '')} style={{ width: '100%', height: v / maxBar * 130, borderRadius: '4px 4px 0 0' }} />
                  <span style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>{A.sales7Labels[i]}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="card" style={{ flex: 1, padding: 18 }}>
            <div style={{ fontSize: 15, fontWeight: 700, marginBottom: 12 }}>{lang === 'bn' ? 'চ্যানেল মিক্স' : 'Channel mix'}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
              <Donut data={A.channelMix} />
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 9 }}>
                {A.channelMix.map(([label, pct, color]) => (
                  <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                    <span style={{ width: 11, height: 11, borderRadius: 3, background: color, flex: '0 0 11px' }} />
                    <span style={{ flex: 1, color: 'var(--ink-2)' }}>{label}</span>
                    <span style={{ fontWeight: 700, fontVariantNumeric: 'tabular-nums' }}>{pct}%</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* top items */}
        <div className="card" style={{ marginTop: 16, padding: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
            <span style={{ fontSize: 15, fontWeight: 700 }}>{lang === 'bn' ? 'টপ আইটেম' : 'Top performers'}</span>
            <span style={{ fontSize: 12.5, color: 'var(--muted)' }}>{lang === 'bn' ? 'রাজস্ব অনুসারে' : 'by revenue'}</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            {A.topItems.slice(0, 5).map((it, i) => {
              const max = A.topItems[0].rev;
              return (
                <div key={it.name} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '9px 0', borderBottom: i < 4 ? '1px solid var(--line)' : 'none' }}>
                  <span className="tab" style={{ width: 18, fontSize: 13, fontWeight: 700, color: 'var(--muted)' }}>{i + 1}</span>
                  <div style={{ flex: '0 0 200px', width: 200 }}>
                    <div style={{ fontSize: 14, fontWeight: 600 }}>{it.name}</div>
                    <div style={{ fontSize: 12, color: 'var(--muted)' }}>{it.qty} {lang === 'bn' ? 'বিক্রি' : 'sold'} · {Math.round(it.margin * 100)}% {lang === 'bn' ? 'মার্জিন' : 'margin'}</div>
                  </div>
                  <div style={{ flex: 1, height: 8, background: 'var(--surface-2)', borderRadius: 4, overflow: 'hidden' }}><div style={{ width: it.rev / max * 100 + '%', height: '100%', background: i === 0 ? 'var(--accent)' : 'var(--accent-tint-2)' }} /></div>
                  <span className="price" style={{ flex: '0 0 auto', width: 92, textAlign: 'right' }}>{money(it.rev)}</span>
                </div>
              );
            })}
          </div>
        </div>
        {owner && <div style={{ fontSize: 12.5, color: 'var(--muted)', textAlign: 'center', marginTop: 16 }}>{lang === 'bn' ? 'বিস্তারিত ড্রিল-ডাউন ও ফোরকাস্ট মোবাইল অ্যানালিটিক্সে' : 'Full drill-downs, forecast & unit economics live in mobile Analytics'}</div>}
      </div>
    </div>
  );
}

Object.assign(window, { TablesScreen, StockScreen, DashboardScreen });
