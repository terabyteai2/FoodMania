// Terafoods · Computer OS — POS screens
// Counter (quick sell), Dine-in floor, Order detail + bill split, Day open/close.

// ────────────────────────────────────────────────────────────────
// Data: menu items (used in both counter + order detail)
// ────────────────────────────────────────────────────────────────
const PC_CATS = [
  { id: 'all', l: 'All', n: 84 },
  { id: 'tea', l: 'Tea & Coffee', n: 14 },
  { id: 'rice', l: 'Rice & Biryani', n: 12, hot: true },
  { id: 'curry', l: 'Curries', n: 18 },
  { id: 'kebab', l: 'Kebab & Grill', n: 9 },
  { id: 'snack', l: 'Snacks', n: 16 },
  { id: 'cold', l: 'Cold drinks', n: 8 },
  { id: 'dessert', l: 'Desserts', n: 7 },
];

const PC_ITEMS = [
  { n: 'Cha · doodh',        p: 25,  em: '🍵', cat: 'tea', tag: 'Top' },
  { n: 'Cha · lemon',        p: 25,  em: '🍋', cat: 'tea' },
  { n: 'Cha · masala',       p: 30,  em: '🌶', cat: 'tea' },
  { n: 'Coffee · black',     p: 60,  em: '☕', cat: 'tea' },
  { n: 'Chicken biryani',    p: 320, em: '🍛', cat: 'rice', tag: 'Top' },
  { n: 'Beef tehari',        p: 280, em: '🥘', cat: 'rice' },
  { n: 'Khichuri',           p: 150, em: '🍚', cat: 'rice' },
  { n: 'Plain rice',         p: 60,  em: '🍚', cat: 'rice' },
  { n: 'Beef bhuna',         p: 280, em: '🥩', cat: 'curry' },
  { n: 'Chicken curry',      p: 220, em: '🍗', cat: 'curry' },
  { n: 'Dal · ghono',        p: 80,  em: '🍲', cat: 'curry' },
  { n: 'Mutton rezala',      p: 380, em: '🍖', cat: 'curry' },
  { n: 'Seekh kebab · 2pc',  p: 180, em: '🍢', cat: 'kebab' },
  { n: 'Chicken tikka',      p: 220, em: '🍗', cat: 'kebab' },
  { n: 'Beef shashlik',      p: 360, em: '🥩', cat: 'kebab', tag: 'New' },
  { n: 'Singara · 2pc',      p: 30,  em: '🥟', cat: 'snack' },
  { n: 'Samosa · 2pc',       p: 30,  em: '🥟', cat: 'snack' },
  { n: 'Naan · butter',      p: 50,  em: '🫓', cat: 'snack' },
  { n: 'Paratha',            p: 25,  em: '🫓', cat: 'snack' },
  { n: 'Borhani · glass',    p: 60,  em: '🥛', cat: 'cold' },
  { n: 'Lassi · sweet',      p: 80,  em: '🥛', cat: 'cold' },
  { n: 'Coke · 250ml',       p: 35,  em: '🥤', cat: 'cold' },
  { n: 'Mineral water',      p: 25,  em: '💧', cat: 'cold' },
  { n: 'Firni',              p: 100, em: '🍮', cat: 'dessert' },
];

const PcCatTab = ({ c, on }) => (
  <div style={{
    padding: '7px 14px', borderRadius: 8,
    background: on ? PC.C.ink : 'transparent',
    color: on ? PC.C.onInk : PC.C.text,
    border: `1px solid ${on ? PC.C.ink : PC.C.border}`,
    fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap',
    display: 'inline-flex', alignItems: 'center', gap: 8,
  }}>
    <span>{c.l}</span>
    <span style={{
      fontSize: 10.5, fontFamily: PC.C.mono, fontWeight: 700,
      color: on ? 'rgba(255,255,255,0.7)' : PC.C.textTer,
      padding: '0 5px', borderRadius: 3,
      background: on ? 'rgba(255,255,255,0.12)' : PC.C.surfaceAlt,
    }}>{c.n}</span>
    {c.hot && <span style={{ width: 5, height: 5, borderRadius: 3, background: PC.C.late }} />}
  </div>
);

const PcMenuTile = ({ it, qty, low }) => (
  <div style={{
    background: qty ? PC.C.accentSoft : PC.C.surface,
    border: `1px solid ${qty ? PC.C.accentSoft : PC.C.border}`,
    borderRadius: 10, padding: '12px 12px', minHeight: 122,
    display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
    position: 'relative',
  }}>
    {qty && (
      <span style={{
        position: 'absolute', top: -8, right: -8, minWidth: 26, height: 26, padding: '0 7px',
        borderRadius: 13, background: PC.C.ink, color: PC.C.onInk,
        fontSize: 12, fontWeight: 700, display: 'grid', placeItems: 'center',
        border: `2px solid ${PC.C.bg}`, ...PC.C.num,
      }}>{qty}</span>
    )}
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
      <div style={{
        width: 42, height: 42, borderRadius: 10,
        background: qty ? PC.C.surface : PC.C.surfaceAlt, display: 'grid', placeItems: 'center',
      }}>
        <span style={{ fontSize: 22 }}>{it.em}</span>
      </div>
      {(it.tag || low) && (
        <span style={{
          fontSize: 9.5, fontFamily: PC.C.mono, fontWeight: 700,
          padding: '2px 6px', borderRadius: 4, letterSpacing: 0.6,
          background: low ? PC.C.warnSoft : it.tag === 'New' ? PC.C.accentSoft : PC.C.goodSoft,
          color: low ? PC.C.warn : it.tag === 'New' ? PC.C.accent : PC.C.good,
        }}>{low ? 'LOW' : it.tag}</span>
      )}
    </div>
    <div>
      <div style={{ fontSize: 13, fontWeight: 600, color: PC.C.text, lineHeight: 1.2 }}>{it.n}</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 4 }}>
        <span style={{ fontSize: 14, fontWeight: 700, color: PC.C.text, ...PC.C.num }}>৳{it.p}</span>
        <span style={{ fontSize: 10.5, color: PC.C.textTer, fontFamily: PC.C.mono, fontWeight: 600 }}>· {it.cat.toUpperCase()}</span>
      </div>
    </div>
  </div>
);

// ────────────────────────────────────────────────────────────────
// 1 · POS Counter mode (the daily driver — quick sell, no table)
// Two panes: menu grid (flex 1) + right ticket panel (400 fixed)
// ────────────────────────────────────────────────────────────────
const PC_Counter = () => {
  const cart = [
    { ...PC_ITEMS[4], q: 2, note: 'extra spicy' },
    { ...PC_ITEMS[8], q: 1, mod: 'half plate · -৳40' },
    { ...PC_ITEMS[17], q: 3 },
    { ...PC_ITEMS[0], q: 4 },
  ];
  const items = PC_ITEMS.slice(0, 18);
  const cartQty = Object.fromEntries(cart.map(c => [c.n, c.q]));

  return (
    <PcShell activeNav="counter" chromeTitle="Counter · Quick sell"
      title="Counter · Quick sell"
      sub="Walk-in customer · no table · auto-print on settle"
      topActions={
        <PcBtn variant="ghost" icon="people" sk="F2">Switch to dine-in</PcBtn>
      }>
      {/* menu pane */}
      <div style={{ flex: 1, minWidth: 0, padding: 18, display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* category tabs */}
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {PC_CATS.map((c, i) => <PcCatTab key={c.id} c={c} on={i === 2} />)}
        </div>
        {/* grid */}
        <div style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 10 }}>
            {items.map((it, i) => (
              <PcMenuTile key={i} it={it} qty={cartQty[it.n]} low={it.n === 'Beef bhuna'} />
            ))}
          </div>
        </div>
      </div>

      {/* ticket panel */}
      <div style={{ width: 400, flexShrink: 0, background: PC.C.surface, borderLeft: `1px solid ${PC.C.border}`, display: 'flex', flexDirection: 'column' }}>
        {/* header */}
        <div style={{ padding: '14px 18px', borderBottom: `1px solid ${PC.C.border}`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <PcEyebrow>Ticket · #4218</PcEyebrow>
            <div style={{ fontSize: 14, fontWeight: 700, color: PC.C.text, marginTop: 4, letterSpacing: -0.2 }}>
              Walk-in · takeaway
            </div>
          </div>
          <PcBtn variant="ghost" size="sm" icon="close">Hold</PcBtn>
        </div>

        {/* lines */}
        <div style={{ flex: 1, padding: '4px 8px 4px 8px', overflow: 'hidden' }}>
          {cart.map((c, i) => (
            <div key={i} style={{
              padding: '10px 12px', borderRadius: 8,
              display: 'flex', gap: 10, alignItems: 'flex-start',
              background: i === 0 ? PC.C.accentWash : 'transparent',
            }}>
              <div style={{
                width: 32, height: 32, borderRadius: 8, background: PC.C.surfaceAlt,
                display: 'grid', placeItems: 'center', fontSize: 16, flexShrink: 0,
              }}>{c.em}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 6 }}>
                  <span style={{ fontSize: 13, fontWeight: 600, color: PC.C.text, lineHeight: 1.25 }}>{c.n}</span>
                  <span style={{ fontSize: 13.5, fontWeight: 700, color: PC.C.text, ...PC.C.num }}>৳{(c.p * c.q).toLocaleString()}</span>
                </div>
                {(c.note || c.mod) && (
                  <div style={{ fontSize: 11, color: PC.C.textSec, marginTop: 3, lineHeight: 1.3 }}>
                    {c.note && <>· <i>{c.note}</i> </>}{c.mod && <>· {c.mod}</>}
                  </div>
                )}
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6 }}>
                  <PcQtyStep q={c.q} />
                  <span style={{ fontSize: 11, color: PC.C.textTer, fontFamily: PC.C.mono, fontWeight: 600, ...PC.C.num }}>
                    @ ৳{c.p}
                  </span>
                  <div style={{ flex: 1 }} />
                  <button style={{
                    border: 'none', background: 'transparent', color: PC.C.textTer,
                    cursor: 'pointer', padding: 4, borderRadius: 4,
                  }}><NavIcon kind="close" /></button>
                </div>
              </div>
            </div>
          ))}
          {/* note row */}
          <div style={{
            margin: '8px 12px 0', padding: '10px 12px', borderRadius: 8,
            background: PC.C.surfaceAlt, border: `1px dashed ${PC.C.borderStrong}`,
            display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: PC.C.textSec,
          }}>
            <span style={{ color: PC.C.textTer }}><NavIcon kind="menu" /></span>
            <span>Kitchen note · "no onion in biryani"</span>
          </div>
        </div>

        {/* totals */}
        <div style={{ padding: '12px 18px 4px', borderTop: `1px solid ${PC.C.border}` }}>
          {[
            ['Subtotal', '৳1,090'],
            ['Discount · Staff 10%', '−৳109', PC.C.late],
            ['Service · 5%', '৳49'],
            ['VAT · 5%', '৳52'],
          ].map(([l, v, col], i) => (
            <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', fontSize: 12.5 }}>
              <span style={{ color: PC.C.textSec }}>{l}</span>
              <span style={{ color: col || PC.C.text, fontWeight: 600, ...PC.C.num }}>{v}</span>
            </div>
          ))}
          <div style={{ height: 1, background: PC.C.border, margin: '10px 0' }} />
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
            <span style={{ fontSize: 13, fontWeight: 600, color: PC.C.text }}>Total due</span>
            <span style={{ fontSize: 28, fontWeight: 700, color: PC.C.ink, letterSpacing: '-0.02em', ...PC.C.num }}>৳1,082</span>
          </div>
        </div>

        {/* payment buttons */}
        <div style={{ padding: '14px 18px 18px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          {[
            { l: 'Cash',      icon: 'shop',     sk: 'F9',  v: 'primary' },
            { l: 'bKash',     icon: 'wifi',     sk: 'F10' },
            { l: 'Nagad',     icon: 'wifi',     sk: 'F11' },
            { l: 'Card',      icon: 'orders',   sk: 'F12' },
            { l: 'Pay later', icon: 'people' },
            { l: 'Split bill', icon: 'menu', sk: 'Ctrl+B' },
          ].map((p, i) => (
            <PcBtn key={i} variant={p.v || 'surface'} size="lg" icon={p.icon} sk={p.sk} full>{p.l}</PcBtn>
          ))}
          <div style={{ gridColumn: '1 / -1', marginTop: 6 }}>
            <PcBtn variant="dark" size="xl" icon="printer" sk="Ctrl+P" full>Settle · print receipt · ৳1,082</PcBtn>
          </div>
        </div>
      </div>
    </PcShell>
  );
};

const PcQtyStep = ({ q }) => (
  <div style={{ display: 'inline-flex', alignItems: 'center', height: 26, borderRadius: 6, border: `1px solid ${PC.C.border}`, background: PC.C.surface }}>
    <button style={btnStep}><NavIcon kind="minus" /></button>
    <span style={{ fontSize: 12, fontWeight: 700, padding: '0 10px', minWidth: 24, textAlign: 'center', ...PC.C.num }}>{q}</span>
    <button style={btnStep}><NavIcon kind="plus" /></button>
  </div>
);
const btnStep = {
  border: 'none', background: 'transparent', width: 22, height: 24,
  display: 'grid', placeItems: 'center', color: PC.C.textSec, cursor: 'pointer',
};

// ────────────────────────────────────────────────────────────────
// 2 · Dine-in floor map — table grid by zone with live status
// ────────────────────────────────────────────────────────────────
const PC_FLOOR_ZONES = [
  {
    name: 'Hall A · main', cols: 6, tables: [
      { n: 'T1', s: 'seated', cov: 4, dur: '12m', t: '৳620' },
      { n: 'T2', s: 'idle',   cov: 2 },
      { n: 'T3', s: 'kitchen', cov: 6, dur: '34m', t: '৳1,840', kot: 'sent 7:34' },
      { n: 'T4', s: 'bill',    cov: 3, dur: '48m', t: '৳1,205', flag: 'bill' },
      { n: 'T5', s: 'late',    cov: 4, dur: '1h 12m', t: '৳980', flag: 'late' },
      { n: 'T6', s: 'served',  cov: 2, dur: '22m', t: '৳540' },
      { n: 'T7', s: 'seated',  cov: 4, dur: '4m', t: '৳—', live: true },
      { n: 'T8', s: 'idle',    cov: 2 },
      { n: 'T9', s: 'kitchen', cov: 5, dur: '18m', t: '৳1,420' },
      { n: 'T10', s: 'idle',   cov: 4 },
      { n: 'T11', s: 'idle',   cov: 4 },
      { n: 'T12', s: 'seated', cov: 3, dur: '8m', t: '৳280' },
    ],
  },
  {
    name: 'Hall B · family', cols: 6, tables: [
      { n: 'F1', s: 'kitchen', cov: 6, dur: '24m', t: '৳2,340' },
      { n: 'F2', s: 'idle',    cov: 6 },
      { n: 'F3', s: 'seated',  cov: 4, dur: '18m', t: '৳780' },
      { n: 'F4', s: 'bill',    cov: 5, dur: '52m', t: '৳1,890', flag: 'bill' },
      { n: 'F5', s: 'idle',    cov: 4 },
      { n: 'F6', s: 'idle',    cov: 8 },
    ],
  },
  {
    name: 'Outside · veranda', cols: 6, tables: [
      { n: 'V1', s: 'seated', cov: 2, dur: '6m', t: '৳120' },
      { n: 'V2', s: 'served', cov: 2, dur: '32m', t: '৳420' },
      { n: 'V3', s: 'idle',   cov: 2 },
      { n: 'V4', s: 'idle',   cov: 2 },
    ],
  },
];

const PC_FloorTable = ({ t }) => {
  const s = TABLE_STATES[t.s];
  const flagged = !!t.flag;
  return (
    <div style={{
      background: s.bg, border: `1px solid ${s.border}${t.s === 'idle' ? '' : '55'}`,
      borderRadius: 12, padding: 12, minHeight: 116, position: 'relative',
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      ...(t.live ? { boxShadow: `0 0 0 2px ${PC.C.accentSoft}, 0 0 0 3px ${PC.C.accent}40` } : {}),
    }}>
      {flagged && (
        <span style={{
          position: 'absolute', top: -6, right: 10,
          padding: '2px 7px', borderRadius: 4, fontSize: 9.5,
          fontFamily: PC.C.mono, fontWeight: 700, letterSpacing: 0.7,
          background: t.flag === 'late' ? PC.C.late : PC.C.ink,
          color: '#FFF',
        }}>{t.flag === 'late' ? 'LATE' : 'BILL'}</span>
      )}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 18, fontWeight: 700, color: s.fg, letterSpacing: -0.3, ...PC.C.num }}>{t.n}</span>
        <span style={{ width: 8, height: 8, borderRadius: 4, background: s.dot }} />
      </div>
      <div>
        <div style={{ fontSize: 10.5, fontFamily: PC.C.mono, fontWeight: 700, color: s.fg, opacity: 0.7, letterSpacing: 0.4, textTransform: 'uppercase' }}>
          {s.label}{t.kot && ` · ${t.kot}`}
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginTop: 6 }}>
          <span style={{ fontSize: 11, color: s.fg, opacity: 0.8, ...PC.C.num }}>
            {t.cov}P{t.dur && ` · ${t.dur}`}
          </span>
          {t.t && t.t !== '৳—' && (
            <span style={{ fontSize: 13, fontWeight: 700, color: s.fg, ...PC.C.num }}>{t.t}</span>
          )}
        </div>
      </div>
    </div>
  );
};

const PC_Floor = () => {
  const stats = [
    { l: 'Tables open',   v: '14 / 22', s: '8 idle · 14 active' },
    { l: 'Covers seated', v: '52',     s: '+6 since last hour' },
    { l: 'Avg dwell',     v: '34m',    s: 'on target · ≤ 45m' },
    { l: 'Late tables',   v: '1',      s: 'T5 · 1h 12m', tone: 'late' },
  ];
  return (
    <PcShell activeNav="floor" chromeTitle="Dine-in · floor map"
      title="Dine-in · floor"
      sub="Mon 2 Jun · dinner service · 7:42 PM"
      topActions={
        <>
          <PcBtn variant="ghost" icon="search" sk="F8">Find table</PcBtn>
          <PcBtn variant="dark" icon="plus" sk="F4">New walk-in</PcBtn>
        </>
      }>
      {/* main */}
      <div style={{ flex: 1, minWidth: 0, padding: 20, overflow: 'hidden' }}>
        {/* filters */}
        <div style={{ display: 'flex', gap: 6, marginBottom: 14, alignItems: 'center' }}>
          {[
            ['All', 22, true],
            ['Idle', 8],
            ['Seated', 5],
            ['In kitchen', 3],
            ['Served', 2],
            ['Bill ready', 2, false, 'bill'],
            ['Late', 1, false, 'late'],
          ].map(([l, n, on, tag], i) => (
            <div key={i} style={{
              padding: '6px 12px', borderRadius: 7,
              background: on ? PC.C.ink : PC.C.surface,
              color: on ? PC.C.onInk : PC.C.text,
              border: `1px solid ${on ? PC.C.ink : PC.C.border}`,
              fontSize: 12.5, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 7,
            }}>
              {tag === 'late' && <span style={{ width: 6, height: 6, borderRadius: 3, background: PC.C.late }} />}
              {tag === 'bill' && <span style={{ width: 6, height: 6, borderRadius: 3, background: PC.C.ink }} />}
              <span>{l}</span>
              <span style={{
                fontSize: 10.5, fontFamily: PC.C.mono, fontWeight: 700,
                padding: '0 5px', borderRadius: 3,
                background: on ? 'rgba(255,255,255,0.14)' : PC.C.surfaceAlt,
                color: on ? 'rgba(255,255,255,0.85)' : PC.C.textTer,
              }}>{n}</span>
            </div>
          ))}
          <div style={{ flex: 1 }} />
          <span style={{ fontSize: 11.5, color: PC.C.textSec, fontFamily: PC.C.mono, fontWeight: 600 }}>
            Auto-refresh · 30s
          </span>
        </div>

        {/* zones */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          {PC_FLOOR_ZONES.map(z => (
            <div key={z.name}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
                <span style={{ fontSize: 12, fontWeight: 700, color: PC.C.text, letterSpacing: -0.1 }}>{z.name}</span>
                <span style={{ flex: 1, height: 1, background: PC.C.border }} />
                <PcEyebrow>{z.tables.length} tables · {z.tables.reduce((s, t) => s + (t.cov || 0), 0)} covers</PcEyebrow>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: `repeat(${z.cols}, 1fr)`, gap: 8 }}>
                {z.tables.map((t, i) => <PC_FloorTable key={i} t={t} />)}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* right rail · snapshot */}
      <div style={{ width: 280, flexShrink: 0, background: PC.C.surface, borderLeft: `1px solid ${PC.C.border}`, padding: '20px 18px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        <PcEyebrow>Service snapshot · live</PcEyebrow>
        {stats.map((s, i) => (
          <div key={i} style={{ paddingBottom: 12, borderBottom: i < 3 ? `1px solid ${PC.C.border}` : 'none' }}>
            <PcEyebrow color={s.tone === 'late' ? PC.C.late : PC.C.textSec}>{s.l}</PcEyebrow>
            <div style={{
              fontSize: 26, fontWeight: 700,
              color: s.tone === 'late' ? PC.C.late : PC.C.ink,
              marginTop: 6, letterSpacing: '-0.025em', lineHeight: 1, ...PC.C.num,
            }}>{s.v}</div>
            <div style={{ fontSize: 11.5, color: PC.C.textSec, marginTop: 4 }}>{s.s}</div>
          </div>
        ))}
        <div style={{
          marginTop: 'auto', padding: 12, borderRadius: 10,
          background: PC.C.lateSoft, border: `1px solid ${PC.C.late}30`,
        }}>
          <PcEyebrow color={PC.C.late}>Needs you</PcEyebrow>
          <div style={{ fontSize: 13, fontWeight: 600, color: PC.C.text, marginTop: 6 }}>T5 has been seated 1h 12m</div>
          <div style={{ fontSize: 11.5, color: PC.C.textSec, marginTop: 4 }}>No order placed yet. Check on guests.</div>
          <PcBtn variant="dark" size="sm" full style={{ marginTop: 10 }}>Go to T5 →</PcBtn>
        </div>
      </div>
    </PcShell>
  );
};

Object.assign(window, { PC_Counter, PC_Floor, PC_FLOOR_ZONES });
