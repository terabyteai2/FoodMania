/* ============================================================
   Bytes POS — AI scan flow (camera → scanning → extracted)
   variant: 'menu' (menu card) | 'bill' (supplier invoice)
   ============================================================ */

function AIScan({ variant, onClose, onApply }) {
  const [stage, setStage] = useState('camera'); // camera → scanning → review
  const isMenu = variant === 'menu';

  useEffect(() => { if (stage === 'scanning') { const t = setTimeout(() => setStage('review'), 1900); return () => clearTimeout(t); } }, [stage]);

  const menuRows = [
    { name: 'Beef Smash Burger', cat: 'Burgers', price: 380, conf: 0.99 },
    { name: 'Crispy Chicken Burger', cat: 'Burgers', price: 340, conf: 0.98 },
    { name: 'Chicken Biryani', cat: 'Rice & Curry', price: 320, conf: 0.99 },
    { name: 'Kacchi Biryani', cat: 'Rice & Curry', price: 480, conf: 0.97 },
    { name: 'Borhani', cat: 'Beverages', price: 80, conf: 0.95 },
    { name: 'Lemon Mint', cat: 'Beverages', price: 110, conf: 0.92 },
  ];
  const billRows = [
    { name: 'Chicken (whole)', qty: 40, unit: 'kg', cost: 230, conf: 0.98 },
    { name: 'Basmati Rice', qty: 50, unit: 'kg', cost: 138, conf: 0.99 },
    { name: 'Cooking Oil', qty: 20, unit: 'L', cost: 182, conf: 0.96 },
    { name: 'Onions', qty: 25, unit: 'kg', cost: 52, conf: 0.94 },
    { name: 'Potatoes', qty: 30, unit: 'kg', cost: 34, conf: 0.91 },
  ];
  const rows = isMenu ? menuRows : billRows;

  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 60, background: stage === 'camera' || stage === 'scanning' ? '#0a0c07' : 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      {/* top bar */}
      <div style={{ flex: '0 0 auto', padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 10, color: stage === 'review' ? 'var(--ink)' : '#fff' }}>
        <button onClick={onClose} style={{ width: 38, height: 38, marginLeft: -6, border: 'none', background: 'transparent', cursor: 'pointer', display: 'grid', placeItems: 'center', color: 'inherit' }}><Icon name="x" size={22} /></button>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 16, fontWeight: 700 }}>{isMenu ? 'Scan menu card' : 'Scan supplier bill'}</div>
          <div style={{ fontSize: 12, opacity: .6 }}>{stage === 'review' ? 'Review extracted items' : 'AI reads it for you'}</div>
        </div>
        <span className="badge" style={{ height: 24, background: 'rgba(153,255,71,.18)', color: 'var(--accent)' }}><Icon name="sparkle" size={13} fill color="var(--accent)" />AI</span>
      </div>

      {(stage === 'camera' || stage === 'scanning') && (
        <div style={{ flex: 1, minHeight: 0, position: 'relative', display: 'grid', placeItems: 'center', padding: 24 }}>
          {/* faux paper */}
          <div style={{ width: '78%', maxWidth: 280, aspectRatio: isMenu ? '0.72' : '0.62', background: '#fbfbf6', borderRadius: 6, padding: '20px 18px', boxShadow: '0 20px 60px rgba(0,0,0,.5)', transform: 'rotate(-1.4deg)', position: 'relative', overflow: 'hidden' }}>
            <div style={{ textAlign: 'center', fontSize: 12, fontWeight: 800, letterSpacing: '.08em', color: '#2a2a22' }}>{isMenu ? 'SPICE GARDEN MENU' : 'KARIM TRADERS — INVOICE'}</div>
            <div style={{ height: 1, background: '#ddd', margin: '12px 0' }} />
            {rows.slice(0, isMenu ? 6 : 5).map((r, i) => (
              <div key={i} style={{ display: 'flex', justifyContent: 'space-between', fontSize: isMenu ? 11 : 10.5, color: '#3a3a30', marginBottom: 9, fontFamily: isMenu ? 'inherit' : 'monospace' }}>
                <span style={{ fontStyle: isMenu ? 'normal' : 'normal' }}>{isMenu ? r.name : r.qty + r.unit + '  ' + r.name}</span>
                <span style={{ fontWeight: 600 }}>{r.price || r.cost}</span>
              </div>
            ))}
            {/* scan laser */}
            {stage === 'scanning' && <div style={{ position: 'absolute', left: 0, right: 0, height: 60, background: 'linear-gradient(transparent, rgba(153,255,71,.45), transparent)', animation: 'scanmove 1.6s ease-in-out infinite', borderTop: '2px solid #99FF47', borderBottom: '2px solid #99FF47' }} />}
          </div>
          {/* corner guides */}
          {stage === 'camera' && ['tl', 'tr', 'bl', 'br'].map((c) => {
            const pos = { tl: { top: '20%', left: '8%' }, tr: { top: '20%', right: '8%' }, bl: { bottom: '14%', left: '8%' }, br: { bottom: '14%', right: '8%' } }[c];
            const rot = { tl: 0, tr: 90, br: 180, bl: 270 }[c];
            return <div key={c} style={{ position: 'absolute', ...pos, width: 26, height: 26, borderTop: '3px solid #99FF47', borderLeft: '3px solid #99FF47', transform: 'rotate(' + rot + 'deg)' }} />;
          })}
          <div style={{ position: 'absolute', bottom: 24, left: 0, right: 0, textAlign: 'center', color: 'rgba(255,255,255,.7)', fontSize: 13.5, fontWeight: 500 }}>
            {stage === 'scanning' ? 'Reading text · extracting items…' : (isMenu ? 'Frame the whole menu card' : 'Frame the handwritten bill')}
          </div>
        </div>
      )}

      {stage === 'camera' && (
        <div className="bottombar" style={{ background: 'transparent', borderTop: 'none', boxShadow: 'none', justifyContent: 'center', paddingBottom: 24 }}>
          <button onClick={() => setStage('scanning')} style={{ width: 70, height: 70, borderRadius: '50%', border: '4px solid rgba(255,255,255,.4)', background: '#99FF47', cursor: 'pointer', display: 'grid', placeItems: 'center' }}><Icon name="camera" size={28} color="#14180E" /></button>
        </div>
      )}

      {stage === 'review' && (
        <React.Fragment>
          <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px' }}>
            <div className="card" style={{ padding: '12px 14px', marginBottom: 14, display: 'flex', alignItems: 'center', gap: 10, background: 'var(--accent-tint)', borderColor: 'var(--accent-tint-2)' }}>
              <Icon name="sparkle" size={20} color="var(--accent-strong)" fill />
              <div style={{ flex: 1, fontSize: 13, color: 'var(--ink-2)' }}><b>{rows.length} items</b> extracted · {Math.round(rows.reduce((s, r) => s + r.conf, 0) / rows.length * 100)}% avg confidence</div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {rows.map((r, i) => (
                <div key={i} className="row" style={{ padding: 11 }}>
                  <div style={{ width: 22, height: 22, borderRadius: 6, background: 'var(--accent)', display: 'grid', placeItems: 'center', flex: '0 0 22px' }}><Icon name="check" size={13} color="var(--accent-ink)" sw={2.6} /></div>
                  <div className="mid">
                    <div className="nm ell">{r.name}</div>
                    <div className="ds">{isMenu ? r.cat : r.qty + ' ' + r.unit + ' @ ' + money(r.cost) + '/' + r.unit}{r.conf < 0.95 && <span style={{ color: 'var(--warning)', fontWeight: 600 }}> · check</span>}</div>
                  </div>
                  <div className="trail"><span className="price">{money(r.price || r.cost)}</span></div>
                </div>
              ))}
            </div>
          </div>
          <div className="bottombar">
            <button className="btn btn-ghost" onClick={() => setStage('camera')}><Icon name="refresh" size={18} />Rescan</button>
            <button className="btn btn-primary btn-lg" style={{ flex: 1 }} onClick={() => onApply(rows)}><Icon name="check" size={19} color="var(--accent-ink)" sw={2.4} />{isMenu ? 'Add ' + rows.length + ' items' : 'Add to stock'}</button>
          </div>
        </React.Fragment>
      )}
    </div>
  );
}

window.AIScan = AIScan;
