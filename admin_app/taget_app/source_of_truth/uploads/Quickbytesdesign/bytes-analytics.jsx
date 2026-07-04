/* ============================================================
   Bytes POS — Owner Analytics (intelligence, not ops)
   ============================================================ */

function Donut({ data, size = 116, label }) {
  const r = size / 2 - 10, c = 2 * Math.PI * r, cx = size / 2;
  let off = 0;
  return (
    <svg width={size} height={size} viewBox={'0 0 ' + size + ' ' + size}>
      <circle cx={cx} cy={cx} r={r} fill="none" stroke="var(--surface-2)" strokeWidth="13" />
      {data.map(([l, pct, color], i) => {
        const len = c * pct / 100;
        const el = <circle key={i} cx={cx} cy={cx} r={r} fill="none" stroke={color} strokeWidth="13" strokeDasharray={len + ' ' + (c - len)} strokeDashoffset={-off} transform={'rotate(-90 ' + cx + ' ' + cx + ')'} />;
        off += len; return el;
      })}
      <text x={cx} y={cx - 2} textAnchor="middle" style={{ fontSize: 20, fontWeight: 800, fill: 'var(--ink)' }} className="tab">{data[0][1]}%</text>
      <text x={cx} y={cx + 13} textAnchor="middle" style={{ fontSize: 9.5, fontWeight: 600, fill: 'var(--muted)' }}>{(label || data[0][0]).toLowerCase()}</text>
    </svg>
  );
}

/* line + area, optional compare line */
function AreaChart({ values, compare, labels, height = 132 }) {
  const W = 300, H = height, pad = 8;
  const all = compare ? values.concat(compare) : values;
  const max = Math.max(...all) * 1.12, min = Math.min(...all) * 0.82;
  const x = (i) => pad + i * (W - pad * 2) / (values.length - 1);
  const y = (v) => H - pad - (v - min) / (max - min) * (H - pad * 2);
  const path = (arr) => arr.map((v, i) => (i ? 'L' : 'M') + x(i).toFixed(1) + ' ' + y(v).toFixed(1)).join(' ');
  const area = path(values) + ' L' + x(values.length - 1) + ' ' + (H - pad) + ' L' + x(0) + ' ' + (H - pad) + ' Z';
  const last = values.length - 1;
  return (
    <svg viewBox={'0 0 ' + W + ' ' + (H + 18)} style={{ width: '100%', display: 'block' }}>
      <defs><linearGradient id="areaFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#99FF47" stopOpacity="0.34" /><stop offset="1" stopColor="#99FF47" stopOpacity="0" /></linearGradient></defs>
      {[0.25, 0.5, 0.75].map((g) => <line key={g} x1={pad} x2={W - pad} y1={pad + g * (H - pad * 2)} y2={pad + g * (H - pad * 2)} stroke="var(--line)" strokeWidth="1" strokeDasharray="3 4" />)}
      <path d={area} fill="url(#areaFill)" />
      {compare && <path d={path(compare)} fill="none" stroke="var(--placeholder)" strokeWidth="1.8" strokeDasharray="4 4" strokeLinecap="round" />}
      <path d={path(values)} fill="none" stroke="#67C81E" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
      {values.map((v, i) => <circle key={i} cx={x(i)} cy={y(v)} r={i === last ? 4 : 2.3} fill={i === last ? '#67C81E' : '#fff'} stroke="#67C81E" strokeWidth={i === last ? 0 : 1.6} />)}
      {labels.map((l, i) => <text key={i} x={x(i)} y={H + 12} textAnchor="middle" style={{ fontSize: 10, fontWeight: i === last ? 700 : 500, fill: i === last ? 'var(--ink)' : 'var(--muted)' }}>{l}</text>)}
    </svg>
  );
}

function SectionTitle({ children, note }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 12 }}>
      <span style={{ fontSize: 15, fontWeight: 700 }}>{children}</span>
      {note && <span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>{note}</span>}
    </div>
  );
}
function Delta({ v }) {
  const up = v >= 0;
  return <span style={{ display: 'inline-flex', alignItems: 'center', gap: 2, fontSize: 11.5, fontWeight: 700, color: up ? 'var(--success)' : 'var(--danger)' }}><Icon name={up ? 'trendup' : 'trenddn'} size={12} sw={2.3} />{up ? '+' : ''}{v}%</span>;
}

const TF_OPTS = [['today', 'Today'], ['week', '7 days'], ['month', '30 days'], ['custom', 'Custom']];
const CH_FILTERS = ['All channels', 'Dine-in', 'Delivery', 'Pickup', 'Counter'];
const DP_FILTERS = ['All day', 'Lunch', 'Dinner', 'Late'];

function AnalyticsScreen({ tabMode }) {
  const b = useBytes();
  const a = ANALYTICS;
  const [tf, setTf] = useState('week');
  const [advanced, setAdvanced] = useState(false);
  const [sortBy, setSortBy] = useState('rev');
  const [range, setRange] = useState('1–8 Jun');
  const [filters, setFilters] = useState(false);
  const [ch, setCh] = useState('All channels');
  const [dp, setDp] = useState('All day');
  const compare = advanced; // comparisons live inside Advanced now

  const chMul = ch === 'All channels' ? 1 : (a.channelMix.find((c) => c[0] === ch) || [0, 100])[1] / 100;
  const dpMul = dp === 'All day' ? 1 : (a.dayparts.find((d) => d[0] === dp) || [0, 0, 1])[2];
  const tfMul = { today: 1, week: 6.4, month: 27.5, custom: 7.8 }[tf];
  const tfLabel = { today: 'Today', week: 'This week', month: 'This month', custom: range }[tf];
  const rev = Math.round(a.today.revenue * tfMul * chMul * dpMul);
  const prevRev = Math.round(a.today.prevRevenue * tfMul * chMul * dpMul);
  const orders = Math.round(a.today.orders * tfMul * chMul * dpMul);
  const growth = Math.round((rev - prevRev) / prevRev * 100);
  const maxHr = Math.max(...a.peakHours);
  const activeFilters = (ch !== 'All channels' ? 1 : 0) + (dp !== 'All day' ? 1 : 0);

  const GROW = { 'Chicken Biryani': 14, 'Coke 250ml': 6, 'Masala Fries': 9, 'Borhani': 5, 'Beef Tehari': -3, 'Kacchi Biryani': 11, 'Beef Smash Burger': 7 };
  const CATMETA = { 'Rice & Curry': [0.61, 12], 'Burgers': [0.57, 8], 'Kebab': [0.59, -3], 'Beverages': [0.66, 5], 'Sides': [0.70, 9], 'Desserts': [0.64, 2] };
  const products = a.topItems.map((it) => ({ ...it, orders: Math.round(it.qty * 0.78), aov: Math.round(it.rev / Math.round(it.qty * 0.78)), growth: GROW[it.name] || 4 }));
  const sortKey = { rev: 'rev', units: 'qty', orders: 'orders', margin: 'margin', aov: 'aov', growth: 'growth' }[sortBy];
  const sorted = [...products].sort((x, y) => y[sortKey] - x[sortKey]).slice(0, advanced ? 7 : 5);
  const metricVal = (it) => sortBy === 'rev' ? money(it.rev) : sortBy === 'units' ? it.qty + ' sold' : sortBy === 'orders' ? it.orders : sortBy === 'aov' ? money(it.aov) : sortBy === 'growth' ? (it.growth > 0 ? '+' : '') + it.growth + '%' : Math.round(it.margin * 100) + '%';
  const maxCat = Math.max(...a.categoryRev.map((c) => c[1]));

  return (
    <React.Fragment>
      <Header title={b.t('title.analytics')} sub="Owner view · Spice Garden" big={tabMode} onBack={tabMode ? undefined : b.pop}
        right={tabMode ? <TopActions /> : <button style={{ width: 42, height: 42, borderRadius: 10, border: '1px solid var(--line-2)', background: 'var(--surface)', display: 'grid', placeItems: 'center', cursor: 'pointer', color: 'var(--ink)' }}><Icon name="download" size={20} /></button>} />

      {/* timeframe */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 10px' }}>
        <div className="seg">{TF_OPTS.map(([id, l]) => <button key={id} className={tf === id ? 'active' : ''} onClick={() => setTf(id)}>{id === 'custom' ? <Icon name="clock" size={14} /> : null}{l}</button>)}</div>
      </div>
      {tf === 'custom' && (
        <div style={{ flex: '0 0 auto', padding: '0 16px 10px' }}>
          <div className="card" style={{ padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
            <Icon name="clock" size={18} color="var(--muted)" />
            <div style={{ flex: 1, display: 'flex', gap: 6 }}>{['1–8 Jun', 'Last month', 'This quarter', 'YTD'].map((r) => <button key={r} onClick={() => setRange(r)} style={{ height: 30, padding: '0 11px', borderRadius: 6, border: '1px solid ' + (range === r ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: range === r ? 'var(--accent-tint)' : 'var(--surface)', color: range === r ? 'var(--accent-strong)' : 'var(--ink-2)', fontSize: 12.5, fontWeight: 600, cursor: 'pointer', fontFamily: 'var(--font)' }}>{r}</button>)}</div>
          </div>
        </div>
      )}

      {/* advanced toggle — minimal */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px', display: 'flex', justifyContent: 'flex-end' }}>
        <AdvToggle on={advanced} onChange={setAdvanced} label="Advanced analytics" />
      </div>

      {/* filter bar */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px', display: 'flex', gap: 8, alignItems: 'center' }}>
        <button onClick={() => setFilters(true)} style={{ height: 36, padding: '0 12px', borderRadius: 7, border: '1px solid ' + (activeFilters ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: activeFilters ? 'var(--accent-tint)' : 'var(--surface)', color: activeFilters ? 'var(--accent-strong)' : 'var(--ink-2)', display: 'flex', alignItems: 'center', gap: 7, cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 13, fontWeight: 600, flex: '0 0 auto' }}>
          <Icon name="filter" size={16} />Filters{activeFilters ? ' · ' + activeFilters : ''}
        </button>
        <div className="chiprow noscroll" style={{ padding: 0, flex: 1 }}>
          {ch !== 'All channels' && <button className="chip tint active" onClick={() => setCh('All channels')} style={{ height: 36 }}>{ch}<Icon name="x" size={13} /></button>}
          {dp !== 'All day' && <button className="chip tint active" onClick={() => setDp('All day')} style={{ height: 36 }}>{dp}<Icon name="x" size={13} /></button>}
          {!activeFilters && <span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 500, alignSelf: 'center' }}>All channels · all day</span>}
        </div>
      </div>

      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 24px' }}>
        {/* hero — accent wash */}
        <div style={{ borderRadius: 'var(--r-lg)', padding: 16, marginBottom: 12, background: 'var(--accent-tint)', border: '1px solid var(--accent-tint-2)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--accent-strong)' }}>{tfLabel} · Net sales</div>
              <div style={{ fontSize: 34, fontWeight: 800, marginTop: 4, letterSpacing: '-.025em' }} className="tab">{money(rev)}</div>
              {compare && <div style={{ fontSize: 12, color: 'var(--ink-2)', marginTop: 3 }}>vs {money(prevRev)} prior · <Delta v={growth} /></div>}
            </div>
            <div style={{ width: 40, height: 40, borderRadius: 10, background: 'var(--accent)', display: 'grid', placeItems: 'center', flex: '0 0 40px' }}><Icon name="trendup" size={22} color="var(--accent-ink)" sw={2.2} /></div>
          </div>
          <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
            {[['Orders', orders, null], ['Avg order', money(a.today.aov), '+3%'], ['Gross margin', Math.round(a.today.margin * 100) + '%', '+1.4pt']].map(([l, v, d]) => (
              <div key={l} style={{ flex: 1, background: 'var(--surface)', borderRadius: 'var(--r-md)', padding: '10px 11px' }}>
                <div style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 600 }} className="ell">{l}</div>
                <div style={{ fontSize: 16, fontWeight: 700, marginTop: 2 }} className="tab">{v}</div>
                {compare && d && <div style={{ fontSize: 10.5, color: 'var(--success)', fontWeight: 700, marginTop: 1 }}>{d}</div>}
              </div>
            ))}
          </div>
        </div>

        {/* sales trend */}
        <div className="card" style={{ padding: 16, marginBottom: 12 }}>
          <SectionTitle note={compare ? 'vs prior · ৳ thousands' : '৳ thousands'}>Sales trend</SectionTitle>
          <AreaChart values={a.sales7} compare={compare ? a.prevSales7 : null} labels={a.sales7Labels} />
        </div>

        {/* revenue by category */}
        <div className="card" style={{ padding: 16, marginBottom: 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 13 }}>
            <SectionTitle note={advanced ? 'share · margin · growth' : 'share of net sales'}>Revenue by category</SectionTitle>
            <button onClick={() => b.push({ screen: 'categoryAll' })} style={{ border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 12.5, fontWeight: 700, color: 'var(--accent-strong)', display: 'inline-flex', alignItems: 'center', gap: 2, flex: '0 0 auto', marginTop: -2 }}>See all<Icon name="chev" size={15} /></button>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: advanced ? 13 : 11 }}>
            {a.categoryRev.slice(0, advanced ? 6 : 4).map(([name, share, val], i) => {
              const [cm, cg] = CATMETA[name] || [0.6, 4];
              return (
                <div key={name}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', fontSize: 13, marginBottom: 5 }}>
                    <span style={{ fontWeight: 600, color: 'var(--ink-2)' }}>{name}</span>
                    <span className="tab" style={{ color: 'var(--muted)', fontWeight: 600 }}>{money(Math.round(val * tfMul / 27.5))} · {Math.round(share * 100)}%</span>
                  </div>
                  <div style={{ height: 8, borderRadius: 4, background: 'var(--surface-2)', overflow: 'hidden' }}><div style={{ width: (share / maxCat * 100) + '%', height: '100%', borderRadius: 4, background: i === 0 ? 'var(--accent)' : i < 3 ? 'var(--accent-tint-2)' : 'var(--surface-3)' }} /></div>
                  {advanced && (
                    <div style={{ display: 'flex', gap: 14, marginTop: 6, fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>
                      <span>Margin <b style={{ color: 'var(--ink-2)' }}>{Math.round(cm * 100)}%</b></span>
                      <span>WoW <b style={{ color: cg >= 0 ? 'var(--success)' : 'var(--danger)' }}>{cg >= 0 ? '+' : ''}{cg}%</b></span>
                      <span style={{ marginLeft: 'auto', color: 'var(--accent-strong)' }}>Drill in ›</span>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        {/* product performance — sortable */}
        <div className="card" style={{ padding: 16, marginBottom: 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 11 }}>
            <div style={{ fontSize: 15, fontWeight: 700 }}>Product performance</div>
            <button onClick={() => b.push({ screen: 'productsAll', sortBy })} style={{ border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 12.5, fontWeight: 700, color: 'var(--accent-strong)', display: 'inline-flex', alignItems: 'center', gap: 2 }}>See all<Icon name="chev" size={15} /></button>
          </div>
          <div className="chiprow noscroll" style={{ padding: 0, margin: '0 0 12px' }}>
            {[['rev', 'Revenue'], ['units', 'Units'], ['orders', 'Orders'], ['margin', 'Margin'], ...(advanced ? [['aov', 'AOV'], ['growth', 'Growth']] : [])].map(([id, label]) => <button key={id} className={'chip tint' + (sortBy === id ? ' active' : '')} onClick={() => setSortBy(id)} style={{ height: 32 }}>{label}</button>)}
          </div>
          {advanced && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '0 0 8px', borderBottom: '1.5px solid var(--line-2)', fontSize: 10.5, fontWeight: 700, letterSpacing: '.04em', textTransform: 'uppercase', color: 'var(--muted)' }}>
              <span style={{ width: 16 }}>#</span><span style={{ flex: 1 }}>Item</span><span style={{ width: 54, textAlign: 'right' }}>Units</span><span style={{ width: 50, textAlign: 'right' }}>Margin</span><span style={{ width: 44, textAlign: 'right' }}>WoW</span><span style={{ width: 70, textAlign: 'right' }}>Revenue</span>
            </div>
          )}
          {sorted.map((it, i) => advanced ? (
            <div key={it.name} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '11px 0', borderBottom: '1px solid var(--line)', fontSize: 13 }}>
              <span style={{ width: 16, fontSize: 12.5, fontWeight: 800, color: i === 0 ? 'var(--accent-strong)' : 'var(--placeholder)' }} className="tab">{i + 1}</span>
              <span style={{ flex: 1, minWidth: 0, fontWeight: 600 }} className="ell">{it.name}</span>
              <span style={{ width: 54, textAlign: 'right', fontWeight: 600 }} className="tab">{it.qty}</span>
              <span style={{ width: 50, textAlign: 'right', fontWeight: 600 }} className="tab">{Math.round(it.margin * 100)}%</span>
              <span style={{ width: 44, textAlign: 'right', fontWeight: 700, color: it.growth >= 0 ? 'var(--success)' : 'var(--danger)' }} className="tab">{it.growth >= 0 ? '+' : ''}{it.growth}</span>
              <span style={{ width: 70, textAlign: 'right', fontWeight: 700 }} className="tab">{money(it.rev)}</span>
            </div>
          ) : (
            <div key={it.name} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '10px 0', borderTop: i === 0 ? 'none' : '1px solid var(--line)' }}>
              <span style={{ fontSize: 13, fontWeight: 800, color: i === 0 ? 'var(--accent-strong)' : 'var(--placeholder)', width: 16 }} className="tab">{i + 1}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 600 }} className="ell">{it.name}</div>
                <div style={{ fontSize: 11.5, color: 'var(--muted)', marginTop: 1 }} className="tab">{it.qty} sold · {Math.round(it.margin * 100)}% margin</div>
              </div>
              <span style={{ fontSize: 14.5, fontWeight: 700, flex: '0 0 auto' }} className="tab">{metricVal(it)}</span>
            </div>
          ))}
          {advanced && <button style={{ width: '100%', marginTop: 12, padding: '10px', border: '1px solid var(--line-2)', borderRadius: 'var(--r-md)', background: 'var(--surface)', cursor: 'pointer', fontWeight: 600, fontSize: 13, color: 'var(--ink-2)', fontFamily: 'var(--font)' }}>Full menu report · export CSV</button>}
        </div>

        {/* channel + payment mix side by side */}
        <div style={{ display: 'flex', gap: 10, marginBottom: 12 }}>
          <div className="card" style={{ flex: 1, padding: 14, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <div style={{ fontSize: 13, fontWeight: 700, alignSelf: 'flex-start', marginBottom: 8 }}>Channels</div>
            <Donut data={a.channelMix} size={104} />
            <div style={{ marginTop: 10, width: '100%', display: 'flex', flexDirection: 'column', gap: 5 }}>
              {a.channelMix.slice(0, 4).map(([l, p, c]) => <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11.5 }}><span style={{ width: 8, height: 8, borderRadius: 2, background: c }} /><span style={{ flex: 1, color: 'var(--ink-2)' }}>{l}</span><span className="tab" style={{ fontWeight: 700 }}>{p}%</span></div>)}
            </div>
          </div>
          <div className="card" style={{ flex: 1, padding: 14, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <div style={{ fontSize: 13, fontWeight: 700, alignSelf: 'flex-start', marginBottom: 8 }}>Payments</div>
            <Donut data={a.paymentMix} size={104} label="bKash" />
            <div style={{ marginTop: 10, width: '100%', display: 'flex', flexDirection: 'column', gap: 5 }}>
              {a.paymentMix.map(([l, p, c]) => <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11.5 }}><span style={{ width: 8, height: 8, borderRadius: 2, background: c }} /><span style={{ flex: 1, color: 'var(--ink-2)' }} className="ell">{l}</span><span className="tab" style={{ fontWeight: 700 }}>{p}%</span></div>)}
            </div>
          </div>
        </div>

        {/* daypart */}
        <div className="card" style={{ padding: 16, marginBottom: 12 }}>
          <SectionTitle note="revenue share · margin">Daypart performance</SectionTitle>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {a.dayparts.map(([name, time, share, ord, margin], i) => (
              <div key={name} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', borderRadius: 'var(--r-md)', background: i === 1 ? 'var(--accent-tint)' : 'var(--surface-2)' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 700 }}>{name} <span style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 500 }}>{time}</span></div>
                  <div style={{ fontSize: 11.5, color: 'var(--muted)', marginTop: 1 }} className="tab">{ord} orders · {Math.round(margin * 100)}% margin</div>
                </div>
                <div style={{ fontSize: 19, fontWeight: 800 }} className="tab">{Math.round(share * 100)}%</div>
              </div>
            ))}
          </div>
        </div>

        {advanced && <AdvancedAnalytics a={a} tfMul={tfMul} />}

        {/* peak hours — demoted, compact */}
        <div className="card" style={{ padding: 14, marginBottom: 12, opacity: .92 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <span style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--ink-2)' }}>Peak hours</span>
            <span style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>Busiest 8–9 PM</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 3, height: 48 }}>
            {a.peakHours.map((v, i) => <div key={i} style={{ flex: 1, height: (v / maxHr * 100) + '%', minHeight: 2, background: v / maxHr > 0.85 ? 'var(--accent-tint-2)' : 'var(--surface-3)', borderRadius: '2px 2px 0 0' }} />)}
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 5, fontSize: 9.5, color: 'var(--placeholder)' }}><span>11 AM</span><span>4 PM</span><span>8 PM</span><span>12 AM</span></div>
        </div>

        <div style={{ textAlign: 'center', color: 'var(--placeholder)', fontSize: 11.5, padding: '6px 0 0' }}>VAT-inclusive · synced 7:42 PM</div>
      </div>

      {/* filters sheet */}
      {filters && (
        <Sheet open onClose={() => setFilters(false)}>
          <div style={{ padding: '4px 18px 16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
              <span style={{ fontSize: 18, fontWeight: 700 }}>Filters</span>
              <button onClick={() => { setCh('All channels'); setDp('All day'); }} style={{ border: 'none', background: 'transparent', color: 'var(--accent-strong)', fontWeight: 600, fontSize: 13.5, cursor: 'pointer' }}>Reset</button>
            </div>
            <div className="eyebrow" style={{ marginBottom: 9 }}>Channel</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 18 }}>
              {CH_FILTERS.map((c) => <button key={c} className={'chip tint' + (ch === c ? ' active' : '')} onClick={() => setCh(c)} style={{ height: 38 }}>{c}</button>)}
            </div>
            <div className="eyebrow" style={{ marginBottom: 9 }}>Daypart</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 20 }}>
              {DP_FILTERS.map((d) => <button key={d} className={'chip tint' + (dp === d ? ' active' : '')} onClick={() => setDp(d)} style={{ height: 38 }}>{d}</button>)}
            </div>
            <button className="btn btn-primary btn-block btn-lg" onClick={() => setFilters(false)}>Apply filters</button>
          </div>
        </Sheet>
      )}
    </React.Fragment>
  );
}

/* ---------- advanced ---------- */
function AdvancedAnalytics({ a, tfMul }) {
  const Bar = ({ label, pct, val, color }) => (
    <div style={{ marginBottom: 11 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, marginBottom: 5 }}><span style={{ color: 'var(--ink-2)', fontWeight: 500 }}>{label}</span><span style={{ fontWeight: 700 }} className="tab">{val}</span></div>
      <div style={{ height: 7, borderRadius: 4, background: 'var(--surface-2)', overflow: 'hidden' }}><div style={{ width: pct + '%', height: '100%', background: color, borderRadius: 4 }} /></div>
    </div>
  );
  const f = a.forecast;
  return (
    <React.Fragment>
      {/* forecast & targets */}
      <div className="card" style={{ padding: 16, marginBottom: 12 }}>
        <SectionTitle note={f.eom}>Forecast vs target</SectionTitle>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 10 }}>
          <span style={{ fontSize: 26, fontWeight: 800, letterSpacing: '-.02em' }} className="tab">{money(f.projected)}</span>
          <span style={{ fontSize: 13, color: 'var(--muted)', fontWeight: 600 }}>proj. month-end</span>
        </div>
        <div style={{ height: 10, borderRadius: 5, background: 'var(--surface-2)', overflow: 'hidden', position: 'relative' }}>
          <div style={{ width: Math.min(100, f.pace * 100) + '%', height: '100%', background: 'var(--accent)', borderRadius: 5 }} />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 7, fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}><span>{Math.round(f.pace * 100)}% of target</span><span>target {money(f.target)}</span></div>
      </div>

      {/* unit economics */}
      <div className="card" style={{ padding: 16, marginBottom: 12 }}>
        <SectionTitle note="% of revenue">Unit economics</SectionTitle>
        <Bar label="Food cost (COGS)" pct={32} val="32%" color="var(--info)" />
        <Bar label="Labour" pct={24} val="24%" color="var(--warning)" />
        <div style={{ borderTop: '1px solid var(--line)', margin: '4px 0 12px' }} />
        <div style={{ display: 'flex', gap: 10 }}>
          <div style={{ flex: 1, background: 'var(--accent-tint)', borderRadius: 'var(--r-md)', padding: '11px 12px' }}><div style={{ fontSize: 22, fontWeight: 800 }} className="tab">56%</div><div style={{ fontSize: 11, color: 'var(--accent-strong)', fontWeight: 700 }}>Prime cost</div></div>
          <div style={{ flex: 1, background: 'var(--surface-2)', borderRadius: 'var(--r-md)', padding: '11px 12px' }}><div style={{ fontSize: 22, fontWeight: 800 }} className="tab">৳354</div><div style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 700 }}>Contribution / order</div></div>
        </div>
      </div>

      {/* customer cohort */}
      <div className="card" style={{ padding: 16, marginBottom: 12 }}>
        <SectionTitle>Customer cohort</SectionTitle>
        <div style={{ display: 'flex', gap: 10, marginBottom: 14 }}>
          <div style={{ flex: 1, background: 'var(--surface-2)', borderRadius: 'var(--r-md)', padding: '11px 12px' }}><div style={{ fontSize: 21, fontWeight: 800 }} className="tab">{Math.round(a.cohort.repeat * 100)}%</div><div style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 600 }}>Repeat rate</div></div>
          <div style={{ flex: 1, background: 'var(--surface-2)', borderRadius: 'var(--r-md)', padding: '11px 12px' }}><div style={{ fontSize: 21, fontWeight: 800 }} className="tab">{money(a.cohort.ltv)}</div><div style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 600 }}>Est. LTV</div></div>
          <div style={{ flex: 1, background: 'var(--surface-2)', borderRadius: 'var(--r-md)', padding: '11px 12px' }}><div style={{ fontSize: 21, fontWeight: 800 }} className="tab">{a.cohort.freq}×</div><div style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 600 }}>Visits/mo</div></div>
        </div>
        <Bar label="Returning" pct={a.cohort.returnPct} val={a.cohort.returnPct + '%'} color="var(--accent-strong)" />
        <Bar label="New" pct={a.cohort.newPct} val={a.cohort.newPct + '%'} color="var(--surface-3)" />
      </div>

      {/* discount + wastage */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 12 }}>
        <div className="card" style={{ flex: 1, padding: 14 }}>
          <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>Discounts</div>
          <div style={{ fontSize: 20, fontWeight: 800 }} className="tab">{money(Math.round(a.discounts.given * tfMul / 27.5))}</div>
          <div style={{ fontSize: 11.5, color: 'var(--muted)', marginTop: 2 }}>on {Math.round(a.discounts.orders * 100)}% of orders</div>
          <div style={{ fontSize: 11.5, color: 'var(--danger)', fontWeight: 600, marginTop: 6 }}>−{Math.round(a.discounts.marginHit * 100)}pt margin</div>
        </div>
        <div className="card" style={{ flex: 1, padding: 14 }}>
          <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>Wastage</div>
          <div style={{ fontSize: 20, fontWeight: 800 }} className="tab">{money(Math.round(a.wastage.cost * tfMul / 27.5))}</div>
          <div style={{ fontSize: 11.5, color: 'var(--muted)', marginTop: 2 }}>{Math.round(a.wastage.pct * 100)}% of COGS</div>
          <div style={{ fontSize: 11.5, color: 'var(--warning)', fontWeight: 600, marginTop: 6 }}>Top: {a.wastage.topItem}</div>
        </div>
      </div>

      {/* basket / AI insight */}
      <div className="card" style={{ padding: 16, marginBottom: 12 }}>
        <SectionTitle>Basket analysis</SectionTitle>
        <div style={{ display: 'flex', gap: 16, marginBottom: 13 }}>
          <div style={{ flex: 1 }}><div style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>Items / order</div><div style={{ fontSize: 20, fontWeight: 800, marginTop: 2 }} className="tab">3.4</div></div>
          <div style={{ flex: 1 }}><div style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>Drink attach</div><div style={{ fontSize: 20, fontWeight: 800, marginTop: 2 }} className="tab">71%</div></div>
          <div style={{ flex: 1 }}><div style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>Upsell rate</div><div style={{ fontSize: 20, fontWeight: 800, marginTop: 2 }} className="tab">29%</div></div>
        </div>
        <div style={{ padding: '11px 12px', borderRadius: 'var(--r-md)', background: 'var(--accent-tint)', fontSize: 12.5, color: 'var(--ink-2)', display: 'flex', gap: 8, alignItems: 'flex-start' }}>
          <Icon name="sparkle" size={16} color="var(--accent-strong)" fill style={{ marginTop: 1, flex: '0 0 16px' }} />
          <span>Biryani + Borhani pair in <b>64%</b> of orders — a combo could lift AOV ~৳90.</span>
        </div>
      </div>
    </React.Fragment>
  );
}

/* ---------- See-all: Revenue by category (full) ---------- */
const CAT_META_FULL = { 'Rice & Curry': [0.61, 12], 'Burgers': [0.57, 8], 'Kebab': [0.59, -3], 'Beverages': [0.66, 5], 'Sides': [0.70, 9], 'Desserts': [0.64, 2] };
function CategoryAllScreen() {
  const b = useBytes();
  const a = ANALYTICS;
  const [sortBy, setSortBy] = useState('rev');
  const rows = a.categoryRev.map(([name, share, val]) => {
    const [margin, growth] = CAT_META_FULL[name] || [0.6, 4];
    const items = a.topItems.filter((it) => it.cat === name);
    const units = items.reduce((s, it) => s + it.qty, 0);
    return { name, share, val, margin, growth, units, nItems: items.length };
  });
  const sortKey = { rev: 'val', share: 'share', margin: 'margin', growth: 'growth', units: 'units' }[sortBy];
  const sorted = [...rows].sort((x, y) => y[sortKey] - x[sortKey]);
  const maxV = Math.max(...rows.map((r) => r.val));
  const totalRev = rows.reduce((s, r) => s + r.val, 0);

  return (
    <React.Fragment>
      <Header title="Revenue by category" sub={money(totalRev) + ' net · last 7 days'} onBack={b.pop} />
      <div className="chiprow noscroll" style={{ flex: '0 0 auto', paddingBottom: 12 }}>
        {[['rev', 'Revenue'], ['share', 'Share'], ['margin', 'Margin'], ['growth', 'Growth'], ['units', 'Units']].map(([id, label]) => <button key={id} className={'chip tint' + (sortBy === id ? ' active' : '')} onClick={() => setSortBy(id)}>{label}</button>)}
      </div>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px', display: 'flex', flexDirection: 'column', gap: 11 }}>
        {sorted.map((r, i) => (
          <div key={r.name} className="card" style={{ padding: 14 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
              <span style={{ fontSize: 12.5, fontWeight: 800, color: i === 0 ? 'var(--accent-strong)' : 'var(--placeholder)', flex: '0 0 auto' }} className="tab">{i + 1}</span>
              <span style={{ flex: 1, fontSize: 15, fontWeight: 700 }} className="ell">{r.name}</span>
              <span style={{ fontSize: 16, fontWeight: 700 }} className="tab">{money(r.val)}</span>
            </div>
            <div style={{ height: 8, borderRadius: 4, background: 'var(--surface-2)', overflow: 'hidden', margin: '10px 0 11px' }}><div style={{ width: (r.val / maxV * 100) + '%', height: '100%', borderRadius: 4, background: i === 0 ? 'var(--accent)' : i < 3 ? 'var(--accent-tint-2)' : 'var(--surface-3)' }} /></div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              {[['Share', Math.round(r.share * 100) + '%', 'var(--ink-2)'], ['Margin', Math.round(r.margin * 100) + '%', 'var(--ink-2)'], ['WoW', (r.growth >= 0 ? '+' : '') + r.growth + '%', r.growth >= 0 ? 'var(--success)' : 'var(--danger)'], ['Units', '' + r.units, 'var(--ink-2)']].map(([l, v, c]) => (
                <div key={l} style={{ flex: 1 }}>
                  <div style={{ fontSize: 10.5, fontWeight: 700, letterSpacing: '.04em', textTransform: 'uppercase', color: 'var(--muted)' }}>{l}</div>
                  <div style={{ fontSize: 14, fontWeight: 700, marginTop: 2, color: c }} className="tab">{v}</div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg" onClick={b.pop}><Icon name="download" size={19} color="var(--accent-ink)" />Export category report</button>
      </div>
    </React.Fragment>
  );
}

/* ---------- See-all: Product performance (full, sortable) ---------- */
const GROW_FULL = { 'Chicken Biryani': 14, 'Coke 250ml': 6, 'Masala Fries': 9, 'Borhani': 5, 'Beef Tehari': -3, 'Kacchi Biryani': 11, 'Beef Smash Burger': 7 };
function ProductsAllScreen({ sortBy: initSort }) {
  const b = useBytes();
  const a = ANALYTICS;
  const [sortBy, setSortBy] = useState(initSort || 'rev');
  const [q, setQ] = useState('');
  const products = a.topItems.map((it) => { const orders = Math.round(it.qty * 0.78); return { ...it, orders, aov: Math.round(it.rev / orders), growth: GROW_FULL[it.name] || 4 }; });
  const sortKey = { rev: 'rev', units: 'qty', orders: 'orders', margin: 'margin', aov: 'aov', growth: 'growth' }[sortBy] || 'rev';
  const filtered = products.filter((p) => q === '' || p.name.toLowerCase().includes(q.toLowerCase()) || p.cat.toLowerCase().includes(q.toLowerCase()));
  const sorted = [...filtered].sort((x, y) => y[sortKey] - x[sortKey]);
  const metricCell = (it) => sortBy === 'rev' ? money(it.rev) : sortBy === 'units' ? it.qty : sortBy === 'orders' ? it.orders : sortBy === 'aov' ? money(it.aov) : sortBy === 'margin' ? Math.round(it.margin * 100) + '%' : (it.growth >= 0 ? '+' : '') + it.growth + '%';
  const colLabel = { rev: 'Revenue', units: 'Units', orders: 'Orders', margin: 'Margin', aov: 'AOV', growth: 'Growth' }[sortBy];

  return (
    <React.Fragment>
      <Header title="Product performance" sub={products.length + ' menu items · last 7 days'} onBack={b.pop} />
      <div style={{ flex: '0 0 auto', padding: '0 16px 10px' }}>
        <div className="field"><Icon name="search" size={18} /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search items…" />{q && <button onClick={() => setQ('')} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--muted)', display: 'grid', placeItems: 'center' }}><Icon name="x" size={16} /></button>}</div>
      </div>
      <div className="chiprow noscroll" style={{ flex: '0 0 auto', paddingBottom: 12 }}>
        {[['rev', 'Revenue'], ['units', 'Units'], ['orders', 'Orders'], ['margin', 'Margin'], ['aov', 'AOV'], ['growth', 'Growth']].map(([id, label]) => <button key={id} className={'chip tint' + (sortBy === id ? ' active' : '')} onClick={() => setSortBy(id)}>{label}</button>)}
      </div>
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <div className="card" style={{ padding: '4px 15px 10px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 0 9px', borderBottom: '1.5px solid var(--line-2)', fontSize: 10.5, fontWeight: 700, letterSpacing: '.04em', textTransform: 'uppercase', color: 'var(--muted)' }}>
            <span style={{ width: 14, textAlign: 'right' }}>#</span><span style={{ flex: 1 }}>Item</span><span style={{ width: 86, textAlign: 'right', color: 'var(--accent-strong)' }}>{colLabel}</span>
          </div>
          {sorted.map((it, i) => (
            <div key={it.name} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 0', borderBottom: i === sorted.length - 1 ? 'none' : '1px solid var(--line)' }}>
              <span style={{ width: 14, textAlign: 'right', fontSize: 12, fontWeight: 800, color: i === 0 ? 'var(--accent-strong)' : 'var(--placeholder)' }} className="tab">{i + 1}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14.5, fontWeight: 600 }} className="ell">{it.name}</div>
                <div style={{ fontSize: 11.5, color: 'var(--muted)', marginTop: 1 }} className="ell">{it.cat} · {Math.round(it.margin * 100)}% margin</div>
              </div>
              <span style={{ width: 86, textAlign: 'right', fontSize: 15, fontWeight: 700, color: sortBy === 'growth' ? (it.growth >= 0 ? 'var(--success)' : 'var(--danger)') : 'var(--ink)' }} className="tab">{metricCell(it)}</span>
            </div>
          ))}
          {sorted.length === 0 && <div style={{ textAlign: 'center', color: 'var(--muted)', padding: '32px 0', fontSize: 14 }}>No items match “{q}”.</div>}
        </div>
      </div>
      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg" onClick={b.pop}><Icon name="download" size={19} color="var(--accent-ink)" />Export full menu report</button>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { AnalyticsScreen, CategoryAllScreen, ProductsAllScreen, Donut, AreaChart, AdvancedAnalytics });
