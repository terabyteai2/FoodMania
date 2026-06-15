/* ============================================================
   QuickBytes POS — Stock over time (owner; read-only trends)
   Whole-inventory health across periods. Reuses the Analytics
   AreaChart for the focused metric + small-multiple sparklines
   for an at-a-glance read of every measure.
   ============================================================ */

/* compact full-width sparkline — line + faint area, no axes */
function MiniSpark({ values, h = 30, stroke = '#67C81E' }) {
  if (!values || values.length < 2) return null;
  const W = 120, pad = 2;
  const max = Math.max(...values), min = Math.min(...values), span = (max - min) || 1;
  const x = (i) => pad + i * (W - pad * 2) / (values.length - 1);
  const y = (v) => h - pad - (v - min) / span * (h - pad * 2);
  const line = values.map((v, i) => (i ? 'L' : 'M') + x(i).toFixed(1) + ' ' + y(v).toFixed(1)).join(' ');
  const area = line + ' L' + x(values.length - 1).toFixed(1) + ' ' + (h - pad) + ' L' + pad + ' ' + (h - pad) + ' Z';
  return (
    <svg viewBox={'0 0 ' + W + ' ' + h} preserveAspectRatio="none" style={{ width: '100%', height: h, display: 'block' }}>
      <path d={area} fill={stroke} fillOpacity="0.13" />
      <path d={line} fill="none" stroke={stroke} strokeWidth="1.6" vectorEffect="non-scaling-stroke" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/* big focused-card value */
function heroVal(v, kind) {
  if (kind === 'money') return money(v);
  if (kind === 'days') return (Math.round(v * 10) / 10).toString();
  return Math.round(v).toLocaleString('en-US');
}
const STK_SUFFIX = { money: '', units: 'units', count: 'items', days: 'days' };
/* terse small-card value */
function miniVal(v, kind) {
  if (kind === 'money') return TK + kfmt(v);
  if (kind === 'days') return (Math.round(v * 10) / 10) + 'd';
  if (kind === 'count') return '' + Math.round(v);
  return kfmt(v);
}

const STK_TF = [['today', 'Today'], ['week', '7 days'], ['month', '30 days'], ['custom', 'Custom']];

function StockTrendsScreen() {
  const b = useBytes();
  const [tf, setTf] = useState('month');
  const [custom, setCustom] = useState('12w');
  const [metric, setMetric] = useState('value');

  const tfLabel = { today: 'Today · since 11 AM', week: 'Last 7 days', month: 'Last 30 days',
    custom: (STOCK_TREND_CUSTOM.find((c) => c[0] === custom) || [])[1] }[tf];

  const sel = stockTrend(metric, tf, custom);
  const perWord = tf === 'custom' ? 'week' : 'day';

  const footer = (() => {
    if (metric === 'usage') return tf === 'today' ? 'used so far today' : 'avg ' + kfmt(Math.round(sel.avg)) + ' / ' + perWord;
    if (metric === 'stockin') {
      const d = sel.deliveries + (sel.deliveries === 1 ? ' delivery' : ' deliveries');
      return tf === 'today' ? d + ' today' : (sel.deliveries ? d + ' · avg ' + TK + kfmt(sel.total / sel.deliveries) : 'no deliveries');
    }
    if (metric === 'value') return 'avg ' + TK + kfmt(sel.avg) + ' · peak ' + TK + kfmt(sel.peak);
    if (metric === 'belowpar') return 'avg ' + Math.round(sel.avg) + ' · peak ' + sel.peak;
    return 'avg ' + (Math.round(sel.avg * 10) / 10) + 'd · low ' + (Math.round(sel.low * 10) / 10) + 'd';
  })();

  return (
    <React.Fragment>
      <Header title="Stock over time" sub="Whole-inventory health" onBack={b.pop} />

      {/* timeframe */}
      <div style={{ flex: '0 0 auto', padding: '0 16px 10px' }}>
        <div className="seg">{STK_TF.map(([id, l]) => <button key={id} className={tf === id ? 'active' : ''} onClick={() => setTf(id)}>{id === 'custom' ? <Icon name="clock" size={14} /> : null}{l}</button>)}</div>
      </div>
      {tf === 'custom' && (
        <div style={{ flex: '0 0 auto', padding: '0 16px 10px' }}>
          <div className="card" style={{ padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
            <Icon name="clock" size={18} color="var(--muted)" />
            <div style={{ flex: 1, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              {STOCK_TREND_CUSTOM.map(([id, l]) => <button key={id} onClick={() => setCustom(id)} style={{ height: 30, padding: '0 11px', borderRadius: 6, border: '1px solid ' + (custom === id ? 'var(--accent-tint-2)' : 'var(--line-2)'), background: custom === id ? 'var(--accent-tint)' : 'var(--surface)', color: custom === id ? 'var(--accent-strong)' : 'var(--ink-2)', fontSize: 12.5, fontWeight: 600, cursor: 'pointer', fontFamily: 'var(--font)' }}>{l}</button>)}
            </div>
          </div>
        </div>
      )}

      {/* metric switcher */}
      <div className="chiprow noscroll" style={{ flex: '0 0 auto', paddingBottom: 12 }}>
        {STOCK_TREND_METRICS.map((m) => <button key={m.id} className={'chip tint' + (metric === m.id ? ' active' : '')} onClick={() => setMetric(m.id)} style={{ height: 34 }}>{m.short}</button>)}
      </div>

      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 20px' }}>
        {/* focused hero chart */}
        <div className="card" style={{ padding: 16, marginBottom: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--accent-strong)' }}>{sel.def.label}</div>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 3 }}>
                <span style={{ fontSize: 32, fontWeight: 800, letterSpacing: '-.025em' }} className="tab">{heroVal(sel.headline, sel.def.kind)}</span>
                {STK_SUFFIX[sel.def.kind] && <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--muted)' }}>{STK_SUFFIX[sel.def.kind]}</span>}
              </div>
              <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 3, fontWeight: 500 }}>{footer}</div>
            </div>
            <div style={{ fontSize: 11, color: 'var(--placeholder)', fontWeight: 600, textAlign: 'right', flex: '0 0 auto', maxWidth: 100, marginTop: 2 }}>{tfLabel}</div>
          </div>
          <AreaChart values={sel.vals} labels={sel.labels} height={140} />
        </div>

        {/* all measures — small multiples */}
        <div className="eyebrow" style={{ margin: '2px 2px 10px' }}>All measures</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {STOCK_TREND_METRICS.map((m) => {
            const s = stockTrend(m.id, tf, custom);
            const on = metric === m.id;
            return (
              <div key={m.id} onClick={() => setMetric(m.id)} className="card" style={{ padding: '12px 13px', cursor: 'pointer', borderColor: on ? 'var(--accent-tint-2)' : 'var(--line)', background: on ? 'var(--accent-tint)' : 'var(--surface)', transition: 'background .12s' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 9 }}>
                  <Icon name={m.icon} size={15} color={on ? 'var(--accent-strong)' : 'var(--muted)'} />
                  <span style={{ fontSize: 12, fontWeight: 600, color: on ? 'var(--accent-strong)' : 'var(--muted)' }} className="ell">{m.label}</span>
                </div>
                <div style={{ fontSize: 19, fontWeight: 800, marginBottom: 9 }} className="tab">{miniVal(s.headline, m.kind)}</div>
                <MiniSpark values={s.vals} stroke={on ? '#3E7E14' : '#67C81E'} />
              </div>
            );
          })}
        </div>

        <div style={{ textAlign: 'center', color: 'var(--placeholder)', fontSize: 11.5, padding: '16px 0 0' }}>End-of-day snapshots · synced 7:42 PM</div>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { StockTrendsScreen, MiniSpark });
