// Rastarant wireframes v2 — light bg, Pending/Accepted tabs, FAB, better stats

const W = 320;
const H = 640;
const FRAME_PAD = 10;
const ACCENT = '#F4C534';
const INK = '#171513';
const INK_2 = '#5b5650';
const INK_3 = '#b2ada3';
const PAPER = '#ffffff';
const PAPER_2 = '#f4f1e8';
const PAPER_3 = '#ebe6d8';

// ---------- primitives ----------

const Ink = ({ children, w = 1.5, dash, style, ...rest }) => (
  <div {...rest} style={{
    border: `${w}px solid ${INK}`,
    borderStyle: dash ? 'dashed' : 'solid',
    borderRadius: 6, ...style,
  }}>{children}</div>
);

const Scribble = ({ w = '80%', h = 7, c = INK_2, mt = 0, style }) => (
  <div style={{ width: w, height: h, background: c, borderRadius: h, marginTop: mt, ...style }} />
);

const StatusBar = () => (
  <div style={{
    height: 22, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '0 14px', fontFamily: 'Kalam, cursive', fontSize: 11, color: INK,
  }}>
    <span>9:41</span>
    <span style={{ display: 'flex', gap: 4 }}><span>•••</span><span>◐</span><span>▮</span></span>
  </div>
);

const BottomNav = ({ active = 0 }) => {
  const items = [
    { en: 'Orders', g: '☷' },
    { en: 'Stats', g: '◫' },
    { en: 'Menu', g: '☰' },
    { en: 'Settings', g: '⚙' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, height: 64,
      borderTop: `1.5px solid ${INK}`, background: PAPER,
      display: 'flex', alignItems: 'center', justifyContent: 'space-around',
      padding: '0 8px',
    }}>
      {items.map((it, i) => (
        <div key={i} style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
          padding: '6px 10px', borderRadius: 14,
          background: i === active ? ACCENT : 'transparent',
          border: i === active ? `1.5px solid ${INK}` : '1.5px solid transparent',
          fontFamily: 'Kalam, cursive',
        }}>
          <div style={{ width: 18, height: 18, display: 'grid', placeItems: 'center', fontSize: 14, color: INK }}>{it.g}</div>
          <div style={{ fontSize: 9, color: INK, lineHeight: 1 }}>{it.en}</div>
        </div>
      ))}
    </div>
  );
};

const ScreenTitle = ({ en, bn, right }) => (
  <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', padding: '8px 16px 6px' }}>
    <div>
      <div style={{ fontFamily: 'Kalam, cursive', fontSize: 22, color: INK, lineHeight: 1 }}>{en}</div>
      {bn && <div style={{ fontFamily: '"Hind Siliguri", sans-serif', fontSize: 12, color: INK_2, marginTop: 2 }}>{bn}</div>}
    </div>
    {right}
  </div>
);

const Phone = ({ children }) => (
  <div style={{
    width: W + FRAME_PAD * 2, height: H + FRAME_PAD * 2 + 18,
    background: '#2a2622', borderRadius: 32, padding: FRAME_PAD,
    boxShadow: '0 1px 0 rgba(255,255,255,0.06) inset, 0 0 0 1.5px #1a1714',
    position: 'relative', fontFamily: 'Kalam, cursive',
  }}>
    <div style={{ width: W, height: H + 18, background: PAPER, borderRadius: 22, position: 'relative', overflow: 'hidden' }}>
      <StatusBar />
      <div style={{ position: 'absolute', inset: '22px 0 0 0' }}>{children}</div>
    </div>
  </div>
);

// big floating + button
const FAB = ({ bottom = 80, right = 16, size = 56 }) => (
  <div style={{
    position: 'absolute', right, bottom, width: size, height: size,
    borderRadius: size / 2, background: ACCENT, border: `1.5px solid ${INK}`,
    display: 'grid', placeItems: 'center', fontSize: size * 0.5,
    color: INK, boxShadow: '0 4px 0 rgba(0,0,0,.18), 0 8px 16px rgba(0,0,0,.12)',
    fontFamily: 'Inter, sans-serif', fontWeight: 300, lineHeight: 1, paddingBottom: 4,
  }}>+</div>
);

const Tabs = ({ a, b, active = 0, ac, bc }) => (
  <div style={{ display: 'flex', padding: '0 16px 10px', gap: 8 }}>
    {[[a, ac], [b, bc]].map(([t, n], i) => (
      <div key={i} style={{
        flex: 1, padding: '8px 0', textAlign: 'center',
        borderBottom: i === active ? `3px solid ${INK}` : `1.5px solid ${INK_3}`,
      }}>
        <div style={{ fontSize: 13, color: i === active ? INK : INK_2 }}>{t}<span style={{ fontSize: 10, marginLeft: 4 }}>({n})</span></div>
      </div>
    ))}
  </div>
);

// ---------- ORDERS — Pending (3 variants) ----------

// O-P · A — cards w/ left rail + Accept button (default landing)
const OrdersPendingA = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Orders" bn="অর্ডার · 3 pending" right={
      <div style={{ display: 'flex', gap: 6 }}>
        <div style={{ width: 26, height: 26, borderRadius: 13, border: `1.5px solid ${INK}`, display: 'grid', placeItems: 'center', fontSize: 12 }}>⌕</div>
        <div style={{ width: 26, height: 26, borderRadius: 13, border: `1.5px solid ${INK}`, display: 'grid', placeItems: 'center', fontSize: 11 }}>◔</div>
      </div>
    } />
    <Tabs a="Pending" b="Accepted" active={0} ac={3} bc={4} />
    <div style={{ padding: '0 16px' }}>
      {[
        ['#143', 'Table 8', '30 sec', '৳420', 3],
        ['#142', 'Take-away', '2 min', '৳780', 4],
        ['#141', 'Delivery', '5 min', '৳1,180', 5],
      ].map(([id, src, t, amt, n], i) => (
        <div key={i} style={{ display: 'flex', marginBottom: 10 }}>
          <div style={{ width: 5, background: ACCENT, border: `1.5px solid ${INK}`, borderRadius: 3 }} />
          <Ink style={{ flex: 1, marginLeft: 8, padding: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <div style={{ fontSize: 13, fontWeight: 700 }}>{id} · {src}</div>
              <div style={{ fontSize: 9, padding: '2px 6px', border: `1.5px solid ${INK}`, borderRadius: 4, background: ACCENT }}>PENDING</div>
            </div>
            <div style={{ fontSize: 10, color: INK_2, marginTop: 3 }}>{t} ago · {n} items · {amt}</div>
            <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
              <Ink style={{ flex: 1, textAlign: 'center', padding: '7px 0', fontSize: 11, background: INK, color: PAPER }}>Accept</Ink>
              <Ink style={{ width: 70, textAlign: 'center', padding: '7px 0', fontSize: 11 }}>Reject</Ink>
            </div>
          </Ink>
        </div>
      ))}
    </div>
    <FAB />
    <BottomNav active={0} />
  </div>
);

// O-P · B — compact rows + swipe-to-accept hint
const OrdersPendingB = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Pending" bn="৩টি নতুন অর্ডার" />
    <Tabs a="Pending" b="Accepted" active={0} ac={3} bc={4} />
    <div style={{ padding: '0 16px', fontSize: 10, color: INK_2, marginBottom: 8 }}>
      ⇠ swipe ⇢ accept · long-press for details
    </div>
    <div style={{ padding: '0 16px' }}>
      {[
        ['#143', 'Table 8', '30s', '৳420', false],
        ['#142', 'Take-away', '2m', '৳780', true],
        ['#141', 'Delivery #22', '5m', '৳1,180', false],
      ].map(([id, src, t, amt, mid], i) => (
        <div key={i} style={{ position: 'relative', marginBottom: 8, height: 62 }}>
          {mid && (
            <div style={{
              position: 'absolute', inset: 0, background: ACCENT, border: `1.5px solid ${INK}`,
              borderRadius: 6, display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
              padding: '0 14px', fontSize: 11,
            }}>Accept ✓</div>
          )}
          <Ink style={{
            position: 'absolute', left: mid ? -40 : 0, right: mid ? 50 : 0, top: 0, bottom: 0,
            padding: '10px 12px', background: PAPER,
            display: 'flex', alignItems: 'center', gap: 10,
            transform: mid ? 'rotate(-0.4deg)' : 'none',
          }}>
            <div style={{ width: 4, background: ACCENT, alignSelf: 'stretch', borderRadius: 2 }} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, fontWeight: 700 }}>{id} · {src}</div>
              <div style={{ fontSize: 10, color: INK_2, marginTop: 2 }}>{t} ago</div>
            </div>
            <div style={{ fontSize: 13, fontWeight: 700 }}>{amt}</div>
          </Ink>
        </div>
      ))}
    </div>
    <FAB />
    <BottomNav active={0} />
  </div>
);

// O-P · C — one-up focus, all attention on next pending order
const OrdersPendingC = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Up next" bn="পরবর্তী · 1 of 3" />
    <Tabs a="Pending" b="Accepted" active={0} ac={3} bc={4} />
    <div style={{ padding: '0 16px' }}>
      <Ink style={{ padding: 14 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div style={{ fontSize: 26, fontWeight: 700, lineHeight: 1 }}>#143</div>
            <div style={{ fontSize: 11, color: INK_2, marginTop: 2 }}>Table 8 · 30 sec ago</div>
          </div>
          <div style={{ background: ACCENT, padding: '4px 10px', border: `1.5px solid ${INK}`, borderRadius: 6, fontSize: 11 }}>PENDING</div>
        </div>
        <div style={{ marginTop: 12, paddingTop: 10, borderTop: `1px dashed ${INK_3}` }}>
          {[['Chicken Biriyani', '×2', '৳480'], ['Borhani', '×1', '৳80'], ['Roast', '×1', '৳220']].map(([n, q, p], i) => (
            <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '3px 0', fontSize: 12 }}>
              <span style={{ flex: 1 }}>{n}</span><span style={{ width: 36, color: INK_2 }}>{q}</span><span style={{ width: 50, textAlign: 'right' }}>{p}</span>
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, paddingTop: 8, borderTop: `1.5px solid ${INK}`, fontWeight: 700, fontSize: 14 }}>
          <span>Total</span><span>৳ 780</span>
        </div>
      </Ink>
      <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
        <Ink style={{ width: 56, textAlign: 'center', padding: '12px 0', fontSize: 14 }}>✕</Ink>
        <Ink style={{ flex: 1, textAlign: 'center', padding: '12px 0', fontSize: 14, background: INK, color: PAPER, fontWeight: 700 }}>Accept →</Ink>
      </div>
      <div style={{ fontSize: 10, color: INK_3, textAlign: 'center', marginTop: 10 }}>2 more pending · swipe to skip</div>
    </div>
    <FAB />
    <BottomNav active={0} />
  </div>
);

// ---------- ORDERS — Accepted tab ----------

const OrdersAccepted = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Orders" bn="অর্ডার · 4 in progress" right={
      <div style={{ width: 26, height: 26, borderRadius: 13, border: `1.5px solid ${INK}`, display: 'grid', placeItems: 'center', fontSize: 12 }}>⌕</div>
    } />
    <Tabs a="Pending" b="Accepted" active={1} ac={3} bc={4} />
    <div style={{ padding: '0 16px' }}>
      {[
        ['#140', 'Table 6', '4 min', '৳620', 'on-time'],
        ['#139', 'Take-away', '12 min', '৳330', 'on-time'],
        ['#138', 'Delivery #21', '34 min', '৳1,180', 'LATE'],
        ['#137', 'Table 2', '48 min', '৳440', 'LATE'],
      ].map(([id, src, t, amt, st], i) => {
        const late = st === 'LATE';
        return (
          <div key={i} style={{ display: 'flex', marginBottom: 10 }}>
            <div style={{ width: 5, background: late ? '#E88060' : ACCENT, border: `1.5px solid ${INK}`, borderRadius: 3 }} />
            <Ink style={{ flex: 1, marginLeft: 8, padding: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <div style={{ fontSize: 13, fontWeight: 700 }}>{id} · {src}</div>
                <div style={{
                  fontSize: 9, padding: '2px 6px', border: `1.5px solid ${INK}`, borderRadius: 4,
                  background: late ? '#E88060' : ACCENT,
                }}>{late ? 'LATE' : 'ACCEPTED'}</div>
              </div>
              <div style={{ fontSize: 10, color: INK_2, marginTop: 3 }}>{t} elapsed · {amt}</div>
              <Scribble w="80%" h={4} mt={6} />
              <Scribble w="55%" h={4} mt={3} />
              <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
                <Ink style={{ flex: 1, textAlign: 'center', padding: '6px 0', fontSize: 11, background: INK, color: PAPER }}>Mark served</Ink>
              </div>
            </Ink>
          </div>
        );
      })}
    </div>
    <FAB />
    <BottomNav active={0} />
  </div>
);

// ---------- STATISTICS — 4 variants ----------

const Spark = ({ w = 280, h = 40 }) => (
  <svg viewBox={`0 0 ${w} ${h}`} style={{ width: '100%', height: h, display: 'block' }}>
    <polyline fill={ACCENT} fillOpacity="0.3" stroke="none"
      points={`0,${h} 0,${h - 14} 28,${h - 12} 56,${h - 18} 84,${h - 16} 112,${h - 22} 140,${h - 20} 168,${h - 28} 196,${h - 26} 224,${h - 34} 252,${h - 32} ${w},${h - 38} ${w},${h}`} />
    <polyline fill="none" stroke={INK} strokeWidth="1.5"
      points={`0,${h - 14} 28,${h - 12} 56,${h - 18} 84,${h - 16} 112,${h - 22} 140,${h - 20} 168,${h - 28} 196,${h - 26} 224,${h - 34} 252,${h - 32} ${w},${h - 38}`} />
  </svg>
);

const RangePicker = () => (
  <div style={{ display: 'flex', gap: 4, padding: 3, border: `1.5px solid ${INK}`, borderRadius: 12 }}>
    {['D', 'W', 'M', 'Y'].map((t, i) => (
      <div key={t} style={{
        padding: '4px 10px', fontSize: 11, borderRadius: 8,
        background: i === 0 ? INK : 'transparent',
        color: i === 0 ? PAPER : INK,
      }}>{t}</div>
    ))}
  </div>
);

// S · A — Hero number + key cards + small trend rows
const StatsHero = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Statistics" bn="পরিসংখ্যান" right={<RangePicker />} />
    <div style={{ padding: '0 16px 10px' }}>
      <div style={{ fontSize: 10, color: INK_2, letterSpacing: 1 }}>TODAY · আজ</div>
      <div style={{ fontSize: 44, color: INK, lineHeight: 1, fontWeight: 700, marginTop: 4 }}>৳42,180</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
        <span style={{ background: ACCENT, padding: '2px 6px', borderRadius: 4, fontSize: 10, border: `1.5px solid ${INK}` }}>▲ 12%</span>
        <span style={{ fontSize: 11, color: INK_2 }}>+৳4.6k vs yesterday</span>
      </div>
      <div style={{ marginTop: 10 }}><Spark h={44} /></div>
    </div>
    <div style={{ padding: '6px 16px', display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
      {[['38', 'orders'], ['4', 'open'], ['৳1.1k', 'avg']].map(([v, l], i) => (
        <Ink key={i} style={{ padding: 8 }}>
          <div style={{ fontSize: 16, fontWeight: 700 }}>{v}</div>
          <div style={{ fontSize: 9, color: INK_2 }}>{l}</div>
        </Ink>
      ))}
    </div>
    <div style={{ padding: '14px 16px 0' }}>
      <div style={{ fontSize: 10, color: INK_2, marginBottom: 6 }}>TOP ITEMS · টপ আইটেম</div>
      {[
        ['Chicken Biriyani', 22, '৳5,280', 1],
        ['Beef Tehari', 12, '৳3,360', 0.6],
        ['Borhani', 18, '৳1,440', 0.4],
        ['Roast', 8, '৳1,760', 0.35],
      ].map(([n, q, rev, p], i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 0', borderBottom: i < 3 ? `1px dashed ${INK_3}` : 'none' }}>
          <div style={{ width: 18, fontSize: 10, color: INK_2 }}>#{i + 1}</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 11, fontWeight: 700 }}>{n}</div>
            <div style={{ height: 4, background: PAPER_2, borderRadius: 2, marginTop: 4, border: `1px solid ${INK_3}`, overflow: 'hidden' }}>
              <div style={{ width: `${p * 100}%`, height: '100%', background: ACCENT }} />
            </div>
          </div>
          <div style={{ fontSize: 10, color: INK_2, width: 30, textAlign: 'right' }}>×{q}</div>
          <div style={{ fontSize: 11, fontWeight: 700, width: 50, textAlign: 'right' }}>{rev}</div>
        </div>
      ))}
    </div>
    <BottomNav active={1} />
  </div>
);

// S · B — Bar chart focused (revenue by hour)
const StatsBars = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Today" bn="আজকের ফ্লো" right={<RangePicker />} />
    <div style={{ padding: '0 16px 10px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
        <div>
          <div style={{ fontSize: 10, color: INK_2 }}>REVENUE</div>
          <div style={{ fontSize: 26, fontWeight: 700 }}>৳42,180</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 10, color: INK_2 }}>ORDERS</div>
          <div style={{ fontSize: 26, fontWeight: 700 }}>38</div>
        </div>
      </div>
    </div>
    {/* bar chart */}
    <div style={{ padding: '8px 16px 0' }}>
      <div style={{ fontSize: 10, color: INK_2, marginBottom: 8 }}>BY HOUR · সময় অনুযায়ী</div>
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 140, borderBottom: `1.5px solid ${INK}`, paddingBottom: 2 }}>
        {[20, 35, 28, 45, 60, 80, 95, 70, 55, 40, 65, 90].map((h, i) => (
          <div key={i} style={{
            flex: 1, height: `${h}%`,
            background: i === 6 || i === 11 ? ACCENT : PAPER_2,
            border: `1.5px solid ${INK}`, borderRadius: '4px 4px 0 0',
          }} />
        ))}
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 8, color: INK_2, marginTop: 4 }}>
        <span>9</span><span>11</span><span>1p</span><span>3</span><span>5</span><span>7</span><span>9</span>
      </div>
    </div>
    {/* breakdown by source */}
    <div style={{ padding: '14px 16px 0' }}>
      <div style={{ fontSize: 10, color: INK_2, marginBottom: 6 }}>BY SOURCE · উৎস</div>
      {[
        ['Dine-in', 0.55, '৳23.2k', 22],
        ['Take-away', 0.28, '৳11.8k', 11],
        ['Delivery', 0.17, '৳7.2k', 5],
      ].map(([n, p, rev, ord], i) => (
        <div key={i} style={{ marginBottom: 8 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, marginBottom: 3 }}>
            <span>{n}</span><span style={{ fontWeight: 700 }}>{rev} <span style={{ color: INK_2, fontWeight: 400 }}>· {ord}</span></span>
          </div>
          <div style={{ height: 6, background: PAPER_2, border: `1.5px solid ${INK}`, borderRadius: 3, overflow: 'hidden' }}>
            <div style={{ width: `${p * 100}%`, height: '100%', background: ACCENT }} />
          </div>
        </div>
      ))}
    </div>
    <BottomNav active={1} />
  </div>
);

// S · C — Multi-metric dashboard with comparison
const StatsCompare = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="This week" bn="এই সপ্তাহ" right={<RangePicker />} />
    {/* big KPIs in a 2x2 grid w/ deltas */}
    <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
      {[
        ['Revenue', '৳284k', '+18%', true],
        ['Orders', '262', '+9%', true],
        ['Avg', '৳1,084', '+৳68', true],
        ['Late %', '4.2%', '-1.1%', true],
      ].map(([l, v, d, up], i) => (
        <Ink key={i} style={{ padding: 10 }}>
          <div style={{ fontSize: 9, color: INK_2 }}>{l.toUpperCase()}</div>
          <div style={{ fontSize: 20, fontWeight: 700, marginTop: 6 }}>{v}</div>
          <div style={{ fontSize: 10, color: up ? '#3a8a3c' : '#D8694F', marginTop: 4 }}>{d} vs last wk</div>
          <svg viewBox="0 0 80 16" style={{ width: '100%', height: 14, marginTop: 4 }}>
            <polyline fill="none" stroke={INK} strokeWidth="1.2"
              points="0,12 12,10 24,11 36,7 48,8 60,5 72,6 80,3" />
          </svg>
        </Ink>
      ))}
    </div>
    {/* day-by-day comparison */}
    <div style={{ padding: '12px 16px 0' }}>
      <div style={{ fontSize: 10, color: INK_2, marginBottom: 6 }}>DAY-BY-DAY · এই vs গত সপ্তাহ</div>
      <Ink style={{ padding: 10 }}>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 100 }}>
          {[
            [50, 30], [62, 50], [70, 55], [55, 60], [80, 65], [95, 75], [42, 40],
          ].map(([t, l], i) => (
            <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
              <div style={{ width: '100%', display: 'flex', alignItems: 'flex-end', gap: 2, height: 80 }}>
                <div style={{ flex: 1, height: `${t}%`, background: ACCENT, border: `1.2px solid ${INK}` }} />
                <div style={{ flex: 1, height: `${l}%`, background: PAPER_2, border: `1.2px solid ${INK_3}` }} />
              </div>
              <div style={{ fontSize: 8, color: INK_2 }}>{['M', 'T', 'W', 'T', 'F', 'S', 'S'][i]}</div>
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 12, marginTop: 8, fontSize: 9, color: INK_2 }}>
          <span><span style={{ display: 'inline-block', width: 10, height: 8, background: ACCENT, border: `1px solid ${INK}`, marginRight: 4, verticalAlign: 'middle' }} />This week</span>
          <span><span style={{ display: 'inline-block', width: 10, height: 8, background: PAPER_2, border: `1px solid ${INK_3}`, marginRight: 4, verticalAlign: 'middle' }} />Last week</span>
        </div>
      </Ink>
    </div>
    <BottomNav active={1} />
  </div>
);

// S · D — Insights / narrative cards
const StatsInsights = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Stats" bn="পরিসংখ্যান" right={<RangePicker />} />
    {/* hero with mini stats */}
    <div style={{ padding: '0 16px 10px' }}>
      <Ink style={{ padding: 12, background: ACCENT }}>
        <div style={{ fontSize: 10, color: INK }}>TODAY · আজ</div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginTop: 4 }}>
          <div style={{ fontSize: 32, fontWeight: 700, lineHeight: 1 }}>৳42,180</div>
          <div style={{ fontSize: 12, fontWeight: 700 }}>▲12%</div>
        </div>
        <div style={{ display: 'flex', gap: 12, marginTop: 10, fontSize: 10 }}>
          <span>38 ord</span><span>4 open</span><span>৳1.1k avg</span><span>4 late</span>
        </div>
      </Ink>
    </div>
    <div style={{ padding: '6px 16px 0' }}>
      <div style={{ fontSize: 10, color: INK_2, marginBottom: 6 }}>INSIGHTS · অন্তর্দৃষ্টি</div>
      {[
        ['🔥', 'Lunch was your best ever', '6 hrs hit ৳18k — 38% above avg'],
        ['📉', 'Roast Chicken sold out at 1pm', 'Lost ~৳1,200 in turn-aways. Restock?'],
        ['⏱', 'Avg cook time up 4 min', 'Table 6 & 2 waited > 30 min today'],
        ['📈', 'Borhani trending +24% this wk', 'Promote a combo with Biriyani?'],
      ].map(([g, t, sub], i) => (
        <Ink key={i} style={{ padding: 10, marginBottom: 8, display: 'flex', gap: 10 }}>
          <div style={{ fontSize: 20, lineHeight: 1 }}>{g}</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12, fontWeight: 700 }}>{t}</div>
            <div style={{ fontSize: 10, color: INK_2, marginTop: 3 }}>{sub}</div>
          </div>
          <div style={{ fontSize: 14, color: INK_2 }}>›</div>
        </Ink>
      ))}
    </div>
    <BottomNav active={1} />
  </div>
);

// ---------- System notes ----------

const SystemNotes = () => (
  <div style={{
    width: 700, padding: 22, background: PAPER,
    border: `1.5px solid ${INK}`, borderRadius: 14,
    fontFamily: 'Kalam, cursive', color: INK,
  }}>
    <div style={{ fontSize: 22 }}>System notes · v2 (light)</div>
    <div style={{ fontSize: 12, color: INK_2, marginBottom: 16 }}>
      Switching to a light/paper base. Yellow stays as the brand accent, but the rest of the system
      goes warm-paper to keep that hospitality feel.
    </div>
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 22 }}>
      <div>
        <div style={{ fontSize: 14, marginBottom: 8 }}>Palette · light-first</div>
        {[
          ['Paper 0', '#FFFFFF', 'app bg'],
          ['Paper 1', '#FAF7EF', 'cards (warm)'],
          ['Paper 2', '#F2EDDD', 'raised / chip'],
          ['Hairline', '#E5DDC8', 'borders'],
          ['Ink hi', '#171513', 'titles'],
          ['Ink mid', '#5B5650', 'body'],
          ['Ink low', '#9A9388', 'caption'],
          ['Brand', '#F4C534', 'accent (refined ▼ #FFD928)'],
          ['Pending', '#F4C534', 'state'],
          ['Accepted', '#F4C534', 'state (same · differentiated by tab)'],
          ['Late', '#E88060', 'state'],
          ['Served', '#7BB47C', 'state'],
        ].map(([n, hex, note]) => (
          <div key={n} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 0', fontSize: 11 }}>
            <div style={{ width: 22, height: 22, background: hex, border: `1.5px solid ${INK}`, borderRadius: 4 }} />
            <div style={{ width: 70 }}>{n}</div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', color: INK_2, width: 80 }}>{hex}</div>
            <div style={{ color: INK_2 }}>{note}</div>
          </div>
        ))}
      </div>
      <div>
        <div style={{ fontSize: 14, marginBottom: 8 }}>Patterns to commit to</div>
        <ul style={{ fontSize: 11, lineHeight: 1.6, color: INK, margin: 0, paddingLeft: 16 }}>
          <li><b>Orders is the home tab</b> — opens directly to Pending list.</li>
          <li><b>Two tabs</b>: Pending (incoming, needs accept) · Accepted (in progress).</li>
          <li><b>FAB +</b> bottom-right on Orders screen for "New order" (56×56, brand bg, ink stroke).</li>
          <li><b>One status badge color</b> per tab is enough — Late is a special-case override.</li>
          <li><b>Stats screen renamed</b> from Dashboard; range picker (D/W/M/Y) is global.</li>
          <li>Cards: 1px hairline (#E5DDC8) at radius 14. No shadows in light mode.</li>
          <li>Bottom nav: 4 dests; active dest gets the pill + label, inactive icon-only.</li>
          <li>Touch targets: every actionable row ≥ 48dp.</li>
        </ul>
        <div style={{ fontSize: 14, marginTop: 14, marginBottom: 8 }}>What to pick from stats</div>
        <ul style={{ fontSize: 11, lineHeight: 1.6, color: INK, margin: 0, paddingLeft: 16 }}>
          <li><b>A · Hero + top items</b> — clean, one screen, very glanceable.</li>
          <li><b>B · Bar chart by hour</b> — best for spotting daypart trends.</li>
          <li><b>C · Compare to last week</b> — twin-bar; great for owner reviews.</li>
          <li><b>D · Narrative insights</b> — text-led; pushes the question "what should I do?"</li>
        </ul>
      </div>
    </div>
  </div>
);

// ---------- Canvas ----------

function App() {
  return (
    <DesignCanvas>
      <DCSection id="orders-pending" title="Orders · Pending (home)"
        subtitle="Default screen on launch. Big + FAB for new order.">
        <DCArtboard id="op-a" label="A · Cards + Accept/Reject" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><OrdersPendingA /></Phone>
        </DCArtboard>
        <DCArtboard id="op-b" label="B · Compact + swipe" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><OrdersPendingB /></Phone>
        </DCArtboard>
        <DCArtboard id="op-c" label="C · One-up focus" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><OrdersPendingC /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection id="orders-accepted" title="Orders · Accepted"
        subtitle="Right tab — orders currently being prepared. Late = special override.">
        <DCArtboard id="oa-a" label="A · Accepted list" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><OrdersAccepted /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection id="stats" title="Statistics"
        subtitle="4 different angles — pick one (or combine).">
        <DCArtboard id="s-a" label="A · Hero + top items" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><StatsHero /></Phone>
        </DCArtboard>
        <DCArtboard id="s-b" label="B · Bars by hour + source" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><StatsBars /></Phone>
        </DCArtboard>
        <DCArtboard id="s-c" label="C · Compare to last wk" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><StatsCompare /></Phone>
        </DCArtboard>
        <DCArtboard id="s-d" label="D · Narrative insights" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><StatsInsights /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection id="system" title="System notes" subtitle="Light-first palette + patterns">
        <DCArtboard id="sys" label="v2 tokens" width={740} height={620}>
          <SystemNotes />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
