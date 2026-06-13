/* ============================================================
   Bytes POS — Master filtered sales table (owner analytics)
   Fits the phone surface — NO horizontal scroll. Item name
   flexes (service · category as a subline); up to 3 numeric
   metrics show as fixed right-aligned columns (Stock pattern).
   Primary slice (Service) is surfaced as an on-screen segment;
   deeper slices live in the Filters sheet.
   ============================================================ */

/* numeric metric registry — key, header, width, money?, default-on, formatter */
const ST_METRICS = [
  { k: 'units',  h: 'Units',   w: 46, money: false, def: true,  fmt: (r) => r.units.toLocaleString() },
  { k: 'orders', h: 'Orders',  w: 50, money: false, def: false, fmt: (r) => r.orders.toLocaleString() },
  { k: 'rev',    h: 'Revenue', w: 72, money: true,  def: true,  fmt: (r) => money(r.rev) },
  { k: 'aov',    h: 'AOV',     w: 60, money: true,  def: false, fmt: (r) => money(r.aov) },
  { k: 'cost',   h: 'Cost',    w: 60, money: true,  def: false, fmt: (r) => money(r.cost) },
  { k: 'profit', h: 'Profit',  w: 64, money: true,  def: false, fmt: (r) => money(r.profit) },
  { k: 'margin', h: 'Margin',  w: 48, money: false, def: true,  fmt: (r) => Math.round(r.margin * 100) + '%' },
];
const ST_MAX_METRICS = 3;
const ST_SUM_KEYS = ['units', 'orders', 'rev', 'cost', 'profit'];
const ST_SERVICES = ['All services', 'Dine-in', 'Takeaway', 'Delivery'];
const ST_TF_SCALE = { today: 0.16, week: 1, month: 4.3, custom: 1.22 };

function SalesTableScreen({ filterState }) {
  const b = useBytes();
  const fs = filterState || {};
  const [tf, setTf] = useState(fs.tf || 'week');
  const [ch, setCh] = useState(fs.ch || 'All channels');
  const [svc, setSvc] = useState('All services');
  const [sh, setSh] = useState(fs.sh || 'All shifts');
  const [term, setTerm] = useState(fs.term || 'All terminals');
  const [stf, setStf] = useState(fs.stf || 'All staff');
  const [sortBy, setSortBy] = useState('rev');
  const [sortDir, setSortDir] = useState('desc');
  const [vis, setVis] = useState(() => { const o = {}; ST_METRICS.forEach((m) => { o[m.k] = m.def; }); return o; });
  const [metricsOpen, setMetricsOpen] = useState(false);
  const [filtOpen, setFiltOpen] = useState(false);

  const base = useMemo(() => buildSalesRows(), []);
  const scale = ST_TF_SCALE[tf] || 1;

  // apply equality filters + time scale
  const rows = useMemo(() => base
    .filter((r) => (svc === 'All services' || r.service === svc)
      && (ch === 'All channels' || channelMatch(r, ch))
      && (sh === 'All shifts' || r.shift === sh)
      && (term === 'All terminals' || r.terminal === term)
      && (stf === 'All staff' || r.staff === stf))
    .map((r) => {
      const units = Math.max(1, Math.round(r.units * scale));
      const orders = Math.max(1, Math.round(r.orders * scale));
      const rev = Math.round(r.rev * scale);
      const cost = Math.round(r.cost * scale);
      return { ...r, units, orders, rev, cost, profit: rev - cost, aov: Math.round(rev / orders), margin: (rev - cost) / rev };
    }), [base, svc, ch, sh, term, stf, scale]);

  const sorted = useMemo(() => {
    const dir = sortDir === 'desc' ? -1 : 1;
    if (sortBy === 'name') return [...rows].sort((x, y) => x.name.localeCompare(y.name) * dir);
    return [...rows].sort((x, y) => (x[sortBy] - y[sortBy]) * dir);
  }, [rows, sortBy, sortDir]);

  const metrics = ST_METRICS.filter((m) => vis[m.k]);
  const totals = {};
  ST_SUM_KEYS.forEach((k) => { totals[k] = rows.reduce((s, r) => s + r[k], 0); });
  const totalRev = totals.rev || 0;

  const activeFilters = (ch !== 'All channels' ? 1 : 0) + (sh !== 'All shifts' ? 1 : 0) + (term !== 'All terminals' ? 1 : 0) + (stf !== 'All staff' ? 1 : 0);
  const visCount = metrics.length;

  const setSort = (k) => { if (sortBy === k) setSortDir((d) => d === 'desc' ? 'asc' : 'desc'); else { setSortBy(k); setSortDir(k === 'name' ? 'asc' : 'desc'); } };
  const toggleMetric = (k) => setVis((v) => {
    const on = !!v[k];
    if (!on && metrics.length >= ST_MAX_METRICS) return v; // cap so the table always fits
    return { ...v, [k]: !on };
  });

  const fmtTotal = (m) => {
    if (m.k === 'margin') return totalRev ? Math.round((totals.profit / totalRev) * 100) + '%' : '—';
    if (m.k === 'aov') return totals.orders ? money(Math.round(totalRev / totals.orders)) : '—';
    if (m.money) return money(totals[m.k]);
    return totals[m.k].toLocaleString();
  };

  const subOf = (r) => svc === 'All services' ? r.service + ' · ' + r.cat : r.cat;

  // caret shown left of right-aligned metric headers, inline for the item header
  const Caret = ({ k }) => sortBy === k
    ? <Icon name={sortDir === 'desc' ? 'chevd' : 'chevu'} size={11} color="var(--accent-strong)" sw={2.4} style={{ display: 'inline-block', flex: '0 0 auto' }} />
    : null;

  return (
    <React.Fragment>
      <Header title="Sales table" sub={sorted.length + ' rows · ' + money(totalRev) + ' net'} onBack={b.pop} />

      {/* time range */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 10px' }}>
        <div className="seg">{TF_OPTS.map(([id, l]) => <button key={id} className={tf === id ? 'active' : ''} onClick={() => setTf(id)}>{id === 'custom' ? <Icon name="clock" size={14} /> : null}{l}</button>)}</div>
      </div>

      {/* service slice — surfaced on-screen (primary filter) */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 10px' }}>
        <div className="seg">{ST_SERVICES.map((s) => <button key={s} className={svc === s ? 'active' : ''} onClick={() => setSvc(s)}>{s === 'All services' ? 'All' : s}</button>)}</div>
      </div>

      {/* toolbar: metrics + deeper filters */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 12px', display: 'flex', gap: 8 }}>
        <button onClick={() => setMetricsOpen(true)} style={tbBtn(false)}><Icon name="count" size={16} />Metrics · {visCount}</button>
        <button onClick={() => setFiltOpen(true)} style={tbBtn(activeFilters > 0)}><Icon name="filter" size={16} />Filters{activeFilters ? ' · ' + activeFilters : ''}</button>
      </div>

      {/* fit-to-width ranked table (no horizontal scroll) */}
      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
        <div className="card" style={{ padding: '4px 15px 8px' }}>
          {/* header row */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '11px 0 9px', borderBottom: '1.5px solid var(--line-2)' }}>
            <span style={{ width: 16, flex: '0 0 16px' }} />
            <button onClick={() => setSort('name')} style={hBtn('flex-start')} className="ell">
              <span className="eyebrow" style={{ fontSize: 10.5, color: sortBy === 'name' ? 'var(--accent-strong)' : 'var(--muted)' }}>Item</span><Caret k="name" />
            </button>
            {metrics.map((m) => (
              <button key={m.k} onClick={() => setSort(m.k)} style={{ ...hBtn('flex-end'), width: m.w, flex: '0 0 ' + m.w + 'px' }}>
                <Caret k={m.k} /><span className="eyebrow" style={{ fontSize: 10.5, color: sortBy === m.k ? 'var(--accent-strong)' : 'var(--muted)' }}>{m.h}</span>
              </button>
            ))}
          </div>

          {/* body */}
          {sorted.map((r, i) => (
            <div key={r.id} style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '11px 0', borderBottom: i === sorted.length - 1 ? 'none' : '1px solid var(--line)' }}>
              <span style={{ width: 16, flex: '0 0 16px', textAlign: 'right', fontSize: 12, fontWeight: 800, color: i === 0 ? 'var(--accent-strong)' : 'var(--placeholder)' }} className="tab">{i + 1}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14.5, fontWeight: 600, color: 'var(--ink)' }} className="ell">{r.name}</div>
                <div style={{ fontSize: 11.5, fontWeight: 500, color: 'var(--muted)', marginTop: 1 }} className="ell">{subOf(r)}</div>
              </div>
              {metrics.map((m) => (
                <div key={m.k} style={{ width: m.w, flex: '0 0 ' + m.w + 'px', textAlign: 'right', fontSize: 13.5, fontWeight: 700, color: m.k === 'profit' ? 'var(--success)' : (m.k === 'margin' ? 'var(--ink-2)' : 'var(--ink)') }} className="tab">{m.fmt(r)}</div>
              ))}
            </div>
          ))}
          {sorted.length === 0 && (
            <div style={{ textAlign: 'center', color: 'var(--muted)', padding: '32px 0', fontSize: 14 }}>No rows match these filters.</div>
          )}

          {/* totals */}
          {sorted.length > 0 && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '12px 0 6px', borderTop: '1.5px solid var(--line-2)', marginTop: 2 }}>
              <span style={{ width: 16, flex: '0 0 16px' }} />
              <div style={{ flex: 1, minWidth: 0, fontSize: 12.5, fontWeight: 700, color: 'var(--ink-2)' }}>Total · {sorted.length}</div>
              {metrics.map((m) => (
                <div key={m.k} style={{ width: m.w, flex: '0 0 ' + m.w + 'px', textAlign: 'right', fontSize: 13.5, fontWeight: 800, color: 'var(--ink)' }} className="tab">{fmtTotal(m)}</div>
              ))}
            </div>
          )}
        </div>
        <div style={{ fontSize: 11.5, color: 'var(--placeholder)', marginTop: 10, textAlign: 'center' }}>Tap a column to sort · choose metrics &amp; filters above</div>
      </div>

      <div className="bottombar">
        <button className="btn btn-primary btn-block btn-lg"><Icon name="download" size={19} color="var(--accent-ink)" />Export filtered table · CSV</button>
      </div>

      {/* metric picker sheet */}
      {metricsOpen && (
        <Sheet open onClose={() => setMetricsOpen(false)}>
          <div className="scrollY noscroll" style={{ padding: '4px 18px 16px', maxHeight: '100%' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 }}>
              <span style={{ fontSize: 18, fontWeight: 700 }}>Metrics</span>
              <button onClick={() => { const o = {}; ST_METRICS.forEach((m) => { o[m.k] = m.def; }); setVis(o); }} style={{ border: 'none', background: 'transparent', color: 'var(--accent-strong)', fontWeight: 600, fontSize: 13.5, cursor: 'pointer' }}>Reset</button>
            </div>
            <div style={{ fontSize: 12.5, color: 'var(--muted)', marginBottom: 12 }}>Show up to {ST_MAX_METRICS} columns — {visCount}/{ST_MAX_METRICS} selected</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              {ST_METRICS.map((m) => {
                const on = !!vis[m.k];
                const disabled = !on && visCount >= ST_MAX_METRICS;
                return (
                  <div key={m.k} onClick={() => !disabled && toggleMetric(m.k)} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '11px 2px', borderBottom: '1px solid var(--line)', cursor: disabled ? 'default' : 'pointer', opacity: disabled ? 0.4 : 1 }}>
                    <span style={{ fontSize: 14.5, fontWeight: 600, color: 'var(--ink)' }}>{m.h}{m.money && <span style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 500, marginLeft: 7 }}>৳</span>}</span>
                    <div className={'toggle' + (on ? ' on' : '')} style={{ pointerEvents: 'none' }}><div className="knob" /></div>
                  </div>
                );
              })}
            </div>
            <button className="btn btn-primary btn-block btn-lg" style={{ marginTop: 16 }} onClick={() => setMetricsOpen(false)}>Show {visCount} {visCount === 1 ? 'metric' : 'metrics'}</button>
          </div>
        </Sheet>
      )}

      {/* deeper filters sheet (service lives on-screen now) */}
      {filtOpen && (
        <Sheet open onClose={() => setFiltOpen(false)}>
          <div className="scrollY noscroll" style={{ padding: '4px 18px 16px', maxHeight: '100%' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
              <span style={{ fontSize: 18, fontWeight: 700 }}>Filters</span>
              <button onClick={() => { setCh('All channels'); setSh('All shifts'); setTerm('All terminals'); setStf('All staff'); }} style={{ border: 'none', background: 'transparent', color: 'var(--accent-strong)', fontWeight: 600, fontSize: 13.5, cursor: 'pointer' }}>Reset</button>
            </div>
            <StFilterGroup label="Channel" opts={['All channels', 'POS', 'Messenger', 'Website']} val={ch} set={setCh} />
            <StFilterGroup label="Shift" opts={['All shifts', ...SHIFTS]} val={sh} set={setSh} />
            <StFilterGroup label="Terminal" opts={['All terminals', ...TERMINALS]} val={term} set={setTerm} />
            <StFilterGroup label="Staff / user" opts={['All staff', ...ANALYTICS_STAFF]} val={stf} set={setStf} last />
            <button className="btn btn-primary btn-block btn-lg" onClick={() => setFiltOpen(false)}>Apply filters</button>
          </div>
        </Sheet>
      )}
    </React.Fragment>
  );
}

function StFilterGroup({ label, opts, val, set, last }) {
  return (
    <React.Fragment>
      <div className="eyebrow" style={{ marginBottom: 9 }}>{label}</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: last ? 20 : 18 }}>
        {opts.map((o) => <button key={o} className={'chip tint' + (val === o ? ' active' : '')} onClick={() => set(o)} style={{ height: 38 }}>{o}</button>)}
      </div>
    </React.Fragment>
  );
}

function channelMatch(r, ch) {
  // analytics channel filter labels → row channel/service
  if (ch === 'POS' || ch === 'Messenger' || ch === 'Website') return r.channel === ch;
  if (ch === 'Dine-in') return r.service === 'Dine-in';
  if (ch === 'Delivery') return r.service === 'Delivery';
  if (ch === 'Counter') return r.channel === 'POS';
  if (ch === 'Pickup') return r.service === 'Takeaway';
  return true;
}

function hBtn(justify) {
  return { border: 'none', background: 'transparent', cursor: 'pointer', padding: 0, display: 'flex', alignItems: 'center', justifyContent: justify, gap: 3, font: 'inherit', flex: justify === 'flex-start' ? 1 : '0 0 auto', minWidth: 0 };
}

function tbBtn(active) {
  return { height: 36, padding: '0 12px', borderRadius: 7, border: '1px solid ' + (active ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: active ? 'var(--accent-tint)' : 'var(--surface)', color: active ? 'var(--accent-strong)' : 'var(--ink-2)', display: 'flex', alignItems: 'center', gap: 7, cursor: 'pointer', fontFamily: 'var(--font)', fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap', flex: '0 0 auto' };
}

Object.assign(window, { SalesTableScreen });
