// Rastarant wireframes — sketchy mid-fi phone mocks
// Drawn as plain SVG/CSS boxes with hand-lettered labels.
// One Phone shell, then per-screen variants.

const W = 320;        // phone screen width (inside frame)
const H = 640;        // phone screen height
const FRAME_PAD = 10; // bezel thickness
const ACCENT = '#E8C547';
const INK = '#1f1d1a';
const INK_2 = '#5a564f';
const INK_3 = '#a8a39a';
const PAPER = '#fbf8f1';
const PAPER_2 = '#f1ede2';

// ---------- Tiny primitives ----------

const Ink = ({ children, w = 1.5, dash, style, ...rest }) => (
  <div
    {...rest}
    style={{
      border: `${w}px solid ${INK}`,
      borderStyle: dash ? 'dashed' : 'solid',
      borderRadius: 6,
      ...style,
    }}>
    {children}
  </div>
);

// "scribble" — a thin horizontal line representing a text run
const Scribble = ({ w = '80%', h = 7, c = INK_2, mt = 0, mb = 0, style }) => (
  <div style={{
    width: w, height: h, background: c, borderRadius: h,
    marginTop: mt, marginBottom: mb, ...style,
  }} />
);

// hand-drawn header bar (status + title)
const StatusBar = () => (
  <div style={{
    height: 22, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '0 14px', fontFamily: 'Kalam, cursive', fontSize: 11, color: INK,
  }}>
    <span>9:41</span>
    <span style={{ display: 'flex', gap: 4 }}>
      <span>•••</span><span>◐</span><span>▮</span>
    </span>
  </div>
);

// Bottom nav (5 destinations by default)
const BottomNav = ({ active = 0, items }) => {
  const defaults = [
    { en: 'Home', bn: 'হোম', g: '⌂' },
    { en: 'Orders', bn: 'অর্ডার', g: '☷' },
    { en: 'Menu', bn: 'মেনু', g: '☰' },
    { en: 'Stock', bn: 'স্টক', g: '▦' },
    { en: 'More', bn: 'আরও', g: '⋯' },
  ];
  const list = items || defaults;
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, height: 64,
      borderTop: `1.5px solid ${INK}`, background: PAPER,
      display: 'flex', alignItems: 'center', justifyContent: 'space-around',
      padding: '0 8px',
    }}>
      {list.map((it, i) => (
        <div key={i} style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
          padding: '6px 10px', borderRadius: 14,
          background: i === active ? ACCENT : 'transparent',
          border: i === active ? `1.5px solid ${INK}` : '1.5px solid transparent',
          fontFamily: 'Kalam, cursive',
        }}>
          <div style={{
            width: 18, height: 18, display: 'grid', placeItems: 'center',
            fontSize: 14, color: INK,
          }}>{it.g}</div>
          <div style={{ fontSize: 9, color: INK, lineHeight: 1 }}>{it.en}</div>
        </div>
      ))}
    </div>
  );
};

// Page title with EN + BN
const ScreenTitle = ({ en, bn, right }) => (
  <div style={{
    display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between',
    padding: '8px 16px 6px',
  }}>
    <div>
      <div style={{ fontFamily: 'Kalam, cursive', fontSize: 22, color: INK, lineHeight: 1 }}>{en}</div>
      <div style={{
        fontFamily: '"Hind Siliguri", "Noto Sans Bengali", sans-serif',
        fontSize: 12, color: INK_2, marginTop: 2,
      }}>{bn}</div>
    </div>
    {right}
  </div>
);

// Phone shell — chrome around the screen content
const Phone = ({ children, label, note }) => (
  <div style={{
    width: W + FRAME_PAD * 2,
    height: H + FRAME_PAD * 2 + 18,
    background: '#2a2622',
    borderRadius: 32,
    padding: FRAME_PAD,
    boxShadow: '0 1px 0 rgba(255,255,255,0.06) inset, 0 0 0 1.5px #1a1714',
    position: 'relative',
    fontFamily: 'Kalam, cursive',
  }}>
    <div style={{
      width: W, height: H + 18,
      background: PAPER,
      borderRadius: 22,
      position: 'relative',
      overflow: 'hidden',
    }}>
      <StatusBar />
      <div style={{ position: 'absolute', inset: '22px 0 0 0' }}>
        {children}
      </div>
    </div>
  </div>
);

// ---------- DASHBOARD ----------

// D1 — Hero card + 2x2 metric grid + quick actions
const DashHero = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Good morning" bn="শুভ সকাল" right={
      <div style={{
        width: 30, height: 30, borderRadius: 15, border: `1.5px solid ${INK}`,
        display: 'grid', placeItems: 'center', fontSize: 14,
      }}>৳</div>
    } />
    {/* Hero sales */}
    <div style={{ padding: '0 16px 12px' }}>
      <Ink style={{ background: ACCENT, padding: '14px 14px 10px', borderRadius: 14 }}>
        <div style={{ fontSize: 11, color: INK }}>TODAY'S SALES · আজকের বিক্রি</div>
        <div style={{ fontSize: 34, fontWeight: 700, color: INK, lineHeight: 1.1, marginTop: 4 }}>
          ৳ 42,180
        </div>
        <div style={{ fontSize: 11, color: INK_2, marginTop: 2 }}>+12% vs yesterday</div>
        {/* sparkline */}
        <svg viewBox="0 0 200 40" style={{ width: '100%', height: 36, marginTop: 8 }}>
          <polyline fill="none" stroke={INK} strokeWidth="1.5"
            points="0,30 20,28 40,22 60,25 80,18 100,20 120,12 140,16 160,8 180,11 200,4" />
          <polyline fill="none" stroke={INK} strokeWidth="0.7" strokeDasharray="2 3"
            points="0,32 200,32" />
        </svg>
      </Ink>
    </div>
    {/* metric grid 2x2 */}
    <div style={{
      padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10,
    }}>
      {[
        ['Orders', 'অর্ডার', '38'],
        ['Open', 'চলমান', '6'],
        ['Avg ticket', 'গড়', '৳1,109'],
        ['Top item', 'টপ', 'Biriyani'],
      ].map(([en, bn, val], i) => (
        <Ink key={i} style={{ padding: 10 }}>
          <div style={{ fontSize: 9, color: INK_2 }}>{en} · {bn}</div>
          <div style={{ fontSize: 18, color: INK, marginTop: 6, fontWeight: 700 }}>{val}</div>
        </Ink>
      ))}
    </div>
    {/* quick actions */}
    <div style={{ padding: '14px 16px 0', display: 'flex', gap: 8 }}>
      {['+ New', 'Sync', 'Z-Rep.'].map((t, i) => (
        <Ink key={i} style={{
          flex: 1, padding: '8px 0', textAlign: 'center', fontSize: 12,
          background: i === 0 ? INK : PAPER, color: i === 0 ? PAPER : INK,
        }}>{t}</Ink>
      ))}
    </div>
    <BottomNav active={0} />
  </div>
);

// D2 — Giant number, hero takes upper half
const DashGiant = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Today" bn="আজ" />
    <div style={{ padding: '0 16px' }}>
      <div style={{ fontSize: 11, color: INK_2, letterSpacing: 1 }}>SALES · বিক্রি</div>
      <div style={{ fontSize: 56, color: INK, lineHeight: 1, fontWeight: 700, marginTop: 4 }}>
        ৳42,180
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
        <span style={{
          background: ACCENT, padding: '2px 6px', borderRadius: 4,
          fontSize: 10, border: `1.5px solid ${INK}`,
        }}>▲ 12%</span>
        <span style={{ fontSize: 11, color: INK_2 }}>vs yesterday</span>
      </div>
      {/* big sparkline */}
      <svg viewBox="0 0 280 80" style={{ width: '100%', height: 70, marginTop: 14 }}>
        <polyline fill={ACCENT} fillOpacity="0.35" stroke="none"
          points="0,70 0,55 30,50 60,40 90,45 120,28 150,32 180,18 210,22 240,12 280,8 280,70" />
        <polyline fill="none" stroke={INK} strokeWidth="1.8"
          points="0,55 30,50 60,40 90,45 120,28 150,32 180,18 210,22 240,12 280,8" />
      </svg>
    </div>
    {/* tiny metric strip */}
    <div style={{ padding: '12px 16px 0', display: 'flex', gap: 8 }}>
      {[['38', 'orders'], ['6', 'open'], ['৳1.1k', 'avg']].map(([v, l], i) => (
        <div key={i} style={{ flex: 1, padding: '8px 6px', borderTop: `1.5px solid ${INK}` }}>
          <div style={{ fontSize: 18, fontWeight: 700, color: INK }}>{v}</div>
          <div style={{ fontSize: 9, color: INK_2 }}>{l}</div>
        </div>
      ))}
    </div>
    {/* open orders peek */}
    <div style={{ padding: '14px 16px 0' }}>
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        fontSize: 11, color: INK_2, marginBottom: 6,
      }}>
        <span>OPEN · চলমান</span><span style={{ textDecoration: 'underline' }}>see all →</span>
      </div>
      {[
        ['#142', 'Table 6 · 3 items'],
        ['#143', 'Take-away · 2 items'],
      ].map(([id, sub], i) => (
        <Ink key={i} style={{
          display: 'flex', justifyContent: 'space-between', padding: '8px 10px',
          marginBottom: 6, alignItems: 'center',
        }}>
          <div>
            <div style={{ fontSize: 13, fontWeight: 700 }}>{id}</div>
            <div style={{ fontSize: 10, color: INK_2 }}>{sub}</div>
          </div>
          <div style={{
            fontSize: 9, padding: '2px 6px', border: `1.5px solid ${INK}`, borderRadius: 4,
            background: ACCENT,
          }}>NEW</div>
        </Ink>
      ))}
    </div>
    <BottomNav active={0} />
  </div>
);

// D3 — Pulse/kanban peek — small metrics top, open orders kanban
const DashPulse = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Pulse" bn="পালস" right={
      <div style={{ display: 'flex', gap: 4, fontSize: 10 }}>
        <span style={{ padding: '4px 8px', border: `1.5px solid ${INK}`, borderRadius: 12, background: ACCENT }}>Today</span>
        <span style={{ padding: '4px 8px', border: `1.5px solid ${INK_3}`, borderRadius: 12, color: INK_2 }}>Week</span>
      </div>
    } />
    {/* metrics strip */}
    <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 6 }}>
      {[
        ['৳42k', 'sales'],
        ['38', 'ord.'],
        ['6', 'open'],
        ['12m', 'avg t.'],
      ].map(([v, l], i) => (
        <Ink key={i} style={{ padding: 6, textAlign: 'center' }}>
          <div style={{ fontSize: 13, fontWeight: 700 }}>{v}</div>
          <div style={{ fontSize: 8, color: INK_2 }}>{l}</div>
        </Ink>
      ))}
    </div>
    {/* kanban */}
    <div style={{ padding: '14px 0 0 16px' }}>
      <div style={{ fontSize: 11, color: INK_2, marginBottom: 6 }}>FLOW · প্রবাহ</div>
      <div style={{ display: 'flex', gap: 8, overflowX: 'hidden' }}>
        {[
          { t: 'Pending', n: 3, color: '#fff' },
          { t: 'Cooking', n: 2, color: ACCENT },
          { t: 'Ready', n: 1, color: '#cfe7d0' },
        ].map((col, i) => (
          <div key={i} style={{ minWidth: 100, flex: '0 0 auto' }}>
            <div style={{
              display: 'flex', justifyContent: 'space-between', fontSize: 10,
              padding: '3px 6px', background: col.color,
              border: `1.5px solid ${INK}`, borderRadius: 4,
            }}>
              <span>{col.t}</span><span style={{ fontWeight: 700 }}>{col.n}</span>
            </div>
            {[...Array(col.n)].map((_, j) => (
              <Ink key={j} style={{ padding: 6, marginTop: 6, background: PAPER }}>
                <div style={{ fontSize: 11, fontWeight: 700 }}>#1{40 + i * 3 + j}</div>
                <Scribble w="70%" h={4} mt={4} />
                <Scribble w="55%" h={4} mt={3} />
              </Ink>
            ))}
          </div>
        ))}
      </div>
    </div>
    {/* quick action FAB */}
    <div style={{
      position: 'absolute', right: 14, bottom: 78,
      width: 48, height: 48, borderRadius: 24, background: ACCENT,
      border: `1.5px solid ${INK}`, display: 'grid', placeItems: 'center',
      fontSize: 22, color: INK, boxShadow: '0 4px 0 rgba(0,0,0,.15)',
    }}>+</div>
    <BottomNav active={0} />
  </div>
);

// D4 — Open orders first (list-led for counter staff)
const DashList = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="6 open" bn="৬টি চলমান" right={
      <div style={{ fontSize: 11, color: INK_2 }}>৳42,180<br /><span style={{ fontSize: 8 }}>today</span></div>
    } />
    <div style={{ padding: '0 16px' }}>
      <div style={{
        display: 'flex', gap: 6, marginBottom: 8,
      }}>
        {['All', 'Dine-in', 'Take', 'Delivery'].map((t, i) => (
          <div key={i} style={{
            fontSize: 10, padding: '4px 8px', borderRadius: 10,
            border: `1.5px solid ${i === 0 ? INK : INK_3}`,
            background: i === 0 ? INK : 'transparent',
            color: i === 0 ? PAPER : INK_2,
          }}>{t}</div>
        ))}
      </div>
      {[
        ['#142', 'Table 6', '3 items', '৳ 620', 'NEW', ACCENT],
        ['#141', 'Take-away', '2 items', '৳ 340', 'COOK', '#f6d0a0'],
        ['#140', 'Delivery', '5 items', '৳1,180', 'READY', '#cfe7d0'],
        ['#139', 'Table 2', '1 item', '৳ 180', 'NEW', ACCENT],
      ].map(([id, src, items, amt, st, c], i) => (
        <div key={i} style={{ display: 'flex', marginBottom: 8 }}>
          <div style={{ width: 5, background: c, borderRadius: 3, border: `1.5px solid ${INK}` }} />
          <Ink style={{
            flex: 1, marginLeft: 6, padding: '8px 10px',
            display: 'flex', justifyContent: 'space-between',
          }}>
            <div>
              <div style={{ fontSize: 13, fontWeight: 700 }}>{id} · {src}</div>
              <div style={{ fontSize: 10, color: INK_2 }}>{items}</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: 13, fontWeight: 700 }}>{amt}</div>
              <div style={{
                fontSize: 8, padding: '1px 5px', border: `1.2px solid ${INK}`,
                borderRadius: 3, display: 'inline-block', marginTop: 2,
                background: c,
              }}>{st}</div>
            </div>
          </Ink>
        </div>
      ))}
    </div>
    <BottomNav active={0} />
  </div>
);

// ---------- ORDERS ----------

const OrderTabs = ({ active = 0 }) => (
  <div style={{ display: 'flex', padding: '0 16px 10px', gap: 10 }}>
    {[['Active', 'চলমান', 6], ['Done', 'সম্পন্ন', 32]].map(([en, bn, n], i) => (
      <div key={i} style={{
        flex: 1, padding: '8px 0', textAlign: 'center',
        borderBottom: i === active ? `3px solid ${INK}` : `1.5px solid ${INK_3}`,
        fontFamily: 'Kalam, cursive',
      }}>
        <div style={{ fontSize: 14, color: i === active ? INK : INK_2 }}>
          {en} <span style={{ fontSize: 10 }}>({n})</span>
        </div>
        <div style={{
          fontSize: 9, color: INK_3,
          fontFamily: '"Hind Siliguri", "Noto Sans Bengali", sans-serif',
        }}>{bn}</div>
      </div>
    ))}
  </div>
);

// O1 — vertical cards with left-border status accent
const OrdersBordered = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Orders" bn="অর্ডার" right={
      <div style={{
        width: 28, height: 28, borderRadius: 14, border: `1.5px solid ${INK}`,
        display: 'grid', placeItems: 'center', fontSize: 16,
      }}>+</div>
    } />
    <OrderTabs active={0} />
    <div style={{ padding: '0 16px', overflowY: 'hidden' }}>
      {[
        ['#142', 'Table 6', '12:04', 'PENDING', ACCENT, ['Chicken Biriyani × 2', 'Borhani × 1']],
        ['#141', 'Take-away', '11:52', 'COOKING', '#f6d0a0', ['Beef Tehari', 'Coke 500ml']],
        ['#140', 'Delivery #DLV-22', '11:30', 'READY', '#cfe7d0', ['Set Menu A × 1']],
      ].map(([id, src, time, status, c, items], i) => (
        <div key={i} style={{ display: 'flex', marginBottom: 10 }}>
          <div style={{ width: 6, background: c, border: `1.5px solid ${INK}`, borderRadius: 3 }} />
          <Ink style={{ flex: 1, marginLeft: 8, padding: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <div style={{ fontSize: 14, fontWeight: 700 }}>{id} · {src}</div>
              <div style={{
                fontSize: 9, padding: '2px 6px', border: `1.5px solid ${INK}`,
                borderRadius: 4, background: c,
              }}>{status}</div>
            </div>
            <div style={{ fontSize: 10, color: INK_2, marginTop: 2 }}>{time} · 12 min ago</div>
            <div style={{ marginTop: 6 }}>
              {items.map((it, j) => (
                <div key={j} style={{ fontSize: 11, color: INK }}>· {it}</div>
              ))}
            </div>
            {i === 0 && (
              <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
                <Ink style={{
                  flex: 1, textAlign: 'center', padding: '6px 0', fontSize: 11,
                  background: INK, color: PAPER,
                }}>Accept</Ink>
                <Ink style={{
                  flex: 1, textAlign: 'center', padding: '6px 0', fontSize: 11,
                }}>Reject</Ink>
              </div>
            )}
          </Ink>
        </div>
      ))}
    </div>
    <BottomNav active={1} />
  </div>
);

// O2 — Swipeable cards (swipe hint shown)
const OrdersSwipe = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Orders" bn="অর্ডার" />
    <OrderTabs active={0} />
    <div style={{ padding: '0 16px' }}>
      {/* mid-swipe card */}
      <div style={{
        position: 'relative', marginBottom: 10, height: 88,
        background: '#cfe7d0', border: `1.5px solid ${INK}`, borderRadius: 6,
        display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
        padding: '0 16px',
      }}>
        <div style={{ fontSize: 11, color: INK }}>← swipe → Serve ✓</div>
        <div style={{
          position: 'absolute', left: 0, top: -2, right: 60, bottom: -2,
          background: PAPER, border: `1.5px solid ${INK}`, borderRadius: 6,
          padding: 10, transform: 'rotate(-0.3deg)',
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <div style={{ fontSize: 14, fontWeight: 700 }}>#140 · Delivery</div>
            <div style={{
              fontSize: 9, padding: '2px 6px', border: `1.5px solid ${INK}`,
              borderRadius: 4, background: '#cfe7d0',
            }}>READY</div>
          </div>
          <div style={{ fontSize: 10, color: INK_2 }}>5 items · ৳1,180</div>
          <Scribble w="60%" h={4} mt={6} />
        </div>
      </div>
      {[
        ['#142', 'Table 6', 'PENDING', ACCENT],
        ['#141', 'Take-away', 'COOKING', '#f6d0a0'],
        ['#138', 'Table 9', 'PENDING', ACCENT],
      ].map(([id, src, st, c], i) => (
        <Ink key={i} style={{ padding: 10, marginBottom: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <div style={{ fontSize: 14, fontWeight: 700 }}>{id} · {src}</div>
            <div style={{
              fontSize: 9, padding: '2px 6px', border: `1.5px solid ${INK}`,
              borderRadius: 4, background: c,
            }}>{st}</div>
          </div>
          <Scribble w="80%" h={5} mt={6} />
          <Scribble w="55%" h={5} mt={4} />
        </Ink>
      ))}
    </div>
    <BottomNav active={1} />
  </div>
);

// O3 — Kanban columns (horizontally scrollable)
const OrdersKanban = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Flow" bn="অর্ডার প্রবাহ" />
    <div style={{ padding: '0 0 0 12px', display: 'flex', gap: 8, overflow: 'hidden' }}>
      {[
        { t: 'Pending', bn: 'নতুন', n: 3, c: ACCENT, cards: [['#142', 'T6', '3 items'], ['#143', 'TA', '2'], ['#144', 'D', '4']] },
        { t: 'Cooking', bn: 'রান্না', n: 2, c: '#f6d0a0', cards: [['#141', 'TA', '2'], ['#139', 'T2', '1']] },
        { t: 'Ready', bn: 'প্রস্তুত', n: 1, c: '#cfe7d0', cards: [['#140', 'D', '5']] },
      ].map((col, i) => (
        <div key={i} style={{ minWidth: 130, flex: '0 0 auto' }}>
          <div style={{
            background: col.c, border: `1.5px solid ${INK}`, padding: '6px 8px',
            borderRadius: 6, display: 'flex', justifyContent: 'space-between',
          }}>
            <div>
              <div style={{ fontSize: 12, fontWeight: 700 }}>{col.t}</div>
              <div style={{
                fontSize: 9, color: INK_2,
                fontFamily: '"Hind Siliguri", "Noto Sans Bengali", sans-serif',
              }}>{col.bn}</div>
            </div>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{col.n}</div>
          </div>
          {col.cards.map(([id, src, items], j) => (
            <Ink key={j} style={{ padding: 8, marginTop: 8, transform: `rotate(${j % 2 ? 0.3 : -0.2}deg)` }}>
              <div style={{ fontSize: 12, fontWeight: 700 }}>{id}</div>
              <div style={{ fontSize: 10, color: INK_2 }}>{src} · {items}</div>
              <Scribble w="70%" h={3} mt={5} />
              <div style={{
                fontSize: 8, marginTop: 6, color: INK_2,
                borderTop: `1px dashed ${INK_3}`, paddingTop: 4,
              }}>tap → details</div>
            </Ink>
          ))}
        </div>
      ))}
    </div>
    <BottomNav active={1} />
  </div>
);

// O4 — Single-focus mode: ONE pending card at full attention
const OrdersFocus = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Up next" bn="পরবর্তী" right={
      <div style={{ fontSize: 10, color: INK_2 }}>2 / 6</div>
    } />
    <div style={{ padding: '0 16px' }}>
      <div style={{ fontSize: 10, color: INK_2, marginBottom: 6 }}>PENDING · নতুন</div>
      <Ink style={{ padding: 14, background: PAPER }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div style={{ fontSize: 26, fontWeight: 700, lineHeight: 1 }}>#142</div>
            <div style={{ fontSize: 12, color: INK_2, marginTop: 2 }}>Table 6 · 12:04</div>
          </div>
          <div style={{
            background: ACCENT, padding: '4px 10px', border: `1.5px solid ${INK}`,
            borderRadius: 6, fontSize: 11,
          }}>NEW</div>
        </div>
        <div style={{
          marginTop: 12, paddingTop: 10, borderTop: `1px dashed ${INK_3}`,
        }}>
          {[
            ['Chicken Biriyani', '× 2', '৳ 480'],
            ['Borhani', '× 1', '৳ 80'],
            ['Roast Chicken', '× 1', '৳ 220'],
          ].map(([n, q, p], i) => (
            <div key={i} style={{
              display: 'flex', justifyContent: 'space-between', padding: '4px 0',
              fontSize: 12,
            }}>
              <span style={{ flex: 1 }}>{n}</span>
              <span style={{ width: 40, color: INK_2 }}>{q}</span>
              <span style={{ width: 50, textAlign: 'right', fontWeight: 700 }}>{p}</span>
            </div>
          ))}
        </div>
        <div style={{
          display: 'flex', justifyContent: 'space-between', marginTop: 10,
          paddingTop: 8, borderTop: `1.5px solid ${INK}`, fontSize: 14, fontWeight: 700,
        }}>
          <span>Total</span><span>৳ 780</span>
        </div>
      </Ink>
      <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
        <Ink style={{
          width: 60, textAlign: 'center', padding: '12px 0', fontSize: 14,
        }}>✕</Ink>
        <Ink style={{
          flex: 1, textAlign: 'center', padding: '12px 0', fontSize: 14,
          background: INK, color: PAPER, fontWeight: 700,
        }}>Accept →</Ink>
      </div>
      <div style={{
        fontSize: 10, color: INK_3, textAlign: 'center', marginTop: 8,
      }}>swipe up for next pending order</div>
    </div>
    <BottomNav active={1} />
  </div>
);

// ---------- MENU ----------

// M1 — 2-col image grid with availability toggle
const MenuGrid = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Menu" bn="মেনু" right={
      <div style={{
        width: 28, height: 28, borderRadius: 14, border: `1.5px solid ${INK}`,
        display: 'grid', placeItems: 'center', fontSize: 16,
      }}>+</div>
    } />
    {/* category chips */}
    <div style={{ padding: '0 16px 10px', display: 'flex', gap: 6, overflow: 'hidden' }}>
      {['All', 'Rice', 'Curry', 'Drinks', 'Desserts'].map((t, i) => (
        <div key={i} style={{
          fontSize: 10, padding: '4px 8px', borderRadius: 10,
          border: `1.5px solid ${i === 0 ? INK : INK_3}`,
          background: i === 0 ? ACCENT : 'transparent',
          color: INK, flex: '0 0 auto',
        }}>{t}</div>
      ))}
    </div>
    <div style={{
      padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10,
    }}>
      {[
        ['Chicken Biriyani', '৳ 240', true, 42],
        ['Beef Tehari', '৳ 280', true, 18],
        ['Borhani', '৳ 80', true, 60],
        ['Roast Chicken', '৳ 220', false, 0],
        ['Mishti Doi', '৳ 60', true, 24],
        ['Set Menu A', '৳ 480', true, 12],
      ].map(([name, price, avail, stock], i) => (
        <Ink key={i} style={{ padding: 0, overflow: 'hidden', opacity: avail ? 1 : 0.55 }}>
          <ImgPlaceholder h={70} />
          <div style={{ padding: '6px 8px 8px' }}>
            <div style={{ fontSize: 11, fontWeight: 700, lineHeight: 1.2 }}>{name}</div>
            <div style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              marginTop: 6,
            }}>
              <div style={{ fontSize: 12, fontWeight: 700 }}>{price}</div>
              <Toggle on={avail} />
            </div>
            <div style={{ fontSize: 8, color: INK_2, marginTop: 3 }}>
              stock: {avail ? stock : 'OUT'}
            </div>
          </div>
        </Ink>
      ))}
    </div>
    <BottomNav active={2} />
  </div>
);

// M2 — Compact list (denser, faster scanning for counter)
const MenuList = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Menu · 48" bn="মেনু" right={
      <div style={{
        fontSize: 10, padding: '4px 8px', borderRadius: 10,
        border: `1.5px solid ${INK}`, background: PAPER,
      }}>+ Add</div>
    } />
    <div style={{ padding: '0 16px 6px' }}>
      <Ink style={{ padding: '6px 10px', display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 12, color: INK_3 }}>⌕</span>
        <span style={{ fontSize: 11, color: INK_3 }}>Search items · খুঁজুন</span>
      </Ink>
    </div>
    <div style={{ padding: '0 16px' }}>
      {[
        ['Chicken Biriyani', 'Rice', '৳ 240', true, 42],
        ['Beef Tehari', 'Rice', '৳ 280', true, 18],
        ['Borhani', 'Drinks', '৳ 80', true, 60],
        ['Roast Chicken', 'Curry', '৳ 220', false, 0],
        ['Mishti Doi', 'Dessert', '৳ 60', true, 24],
        ['Coke 500ml', 'Drinks', '৳ 50', true, 88],
        ['Naan', 'Sides', '৳ 30', true, 50],
      ].map(([name, cat, price, avail, stock], i) => (
        <div key={i} style={{
          display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0',
          borderBottom: `1px dashed ${INK_3}`, opacity: avail ? 1 : 0.5,
        }}>
          <div style={{
            width: 38, height: 38, border: `1.5px solid ${INK}`, borderRadius: 6,
            background: PAPER_2,
            backgroundImage: `repeating-linear-gradient(45deg, transparent 0 4px, rgba(0,0,0,.08) 4px 5px)`,
          }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12, fontWeight: 700 }}>{name}</div>
            <div style={{ fontSize: 9, color: INK_2 }}>{cat} · stock {avail ? stock : 'OUT'}</div>
          </div>
          <div style={{ fontSize: 12, fontWeight: 700, minWidth: 50, textAlign: 'right' }}>{price}</div>
          <Toggle on={avail} />
        </div>
      ))}
    </div>
    <BottomNav active={2} />
  </div>
);

// M3 — Photo-first hero with category sections
const MenuHero = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Menu" bn="মেনু" />
    {/* big featured */}
    <div style={{ padding: '0 16px 10px' }}>
      <Ink style={{ padding: 0, overflow: 'hidden' }}>
        <ImgPlaceholder h={110} label="hero · best seller" />
        <div style={{ padding: '8px 10px', display: 'flex', justifyContent: 'space-between' }}>
          <div>
            <div style={{ fontSize: 13, fontWeight: 700 }}>Chicken Biriyani</div>
            <div style={{ fontSize: 9, color: INK_2 }}>Rice · ৳240 · 42 in stock</div>
          </div>
          <Toggle on />
        </div>
      </Ink>
    </div>
    {/* category row */}
    <div style={{ padding: '0 16px 6px' }}>
      <div style={{
        display: 'flex', justifyContent: 'space-between', fontSize: 11, color: INK_2,
      }}>
        <span>RICE · ভাত (8)</span><span style={{ textDecoration: 'underline' }}>edit</span>
      </div>
    </div>
    <div style={{
      padding: '0 0 0 16px', display: 'flex', gap: 8, overflow: 'hidden',
    }}>
      {['Tehari', 'Khichuri', 'Plain', 'Pulao'].map((n, i) => (
        <div key={i} style={{ minWidth: 84, flex: '0 0 auto' }}>
          <Ink style={{ padding: 0, overflow: 'hidden' }}>
            <ImgPlaceholder h={62} />
            <div style={{ padding: '4px 6px' }}>
              <div style={{ fontSize: 10, fontWeight: 700 }}>{n}</div>
              <div style={{ fontSize: 9, color: INK_2 }}>৳{180 + i * 20}</div>
            </div>
          </Ink>
        </div>
      ))}
    </div>
    <div style={{ padding: '12px 16px 6px' }}>
      <div style={{
        display: 'flex', justifyContent: 'space-between', fontSize: 11, color: INK_2,
      }}>
        <span>DRINKS · পানীয় (6)</span><span style={{ textDecoration: 'underline' }}>edit</span>
      </div>
    </div>
    <div style={{
      padding: '0 0 0 16px', display: 'flex', gap: 8, overflow: 'hidden',
    }}>
      {['Borhani', 'Coke', 'Lassi', 'Tea'].map((n, i) => (
        <div key={i} style={{ minWidth: 84, flex: '0 0 auto' }}>
          <Ink style={{ padding: 0, overflow: 'hidden', opacity: i === 3 ? 0.5 : 1 }}>
            <ImgPlaceholder h={62} />
            <div style={{ padding: '4px 6px' }}>
              <div style={{ fontSize: 10, fontWeight: 700 }}>{n}</div>
              <div style={{ fontSize: 9, color: INK_2 }}>৳{50 + i * 10}</div>
            </div>
          </Ink>
        </div>
      ))}
    </div>
    <BottomNav active={2} />
  </div>
);

// ---------- SETTINGS ----------

const SettingsGroup = ({ title, items }) => (
  <div style={{ marginBottom: 14 }}>
    <div style={{
      fontSize: 10, color: INK_2, padding: '0 16px 4px', letterSpacing: 0.5,
    }}>{title}</div>
    <Ink style={{ margin: '0 16px', padding: 0, overflow: 'hidden' }}>
      {items.map(([g, en, bn, tr], i) => (
        <div key={i} style={{
          display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px',
          borderBottom: i < items.length - 1 ? `1px dashed ${INK_3}` : 'none',
        }}>
          <div style={{
            width: 24, height: 24, border: `1.5px solid ${INK}`, borderRadius: 6,
            display: 'grid', placeItems: 'center', fontSize: 12, background: PAPER_2,
          }}>{g}</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12, fontWeight: 700 }}>{en}</div>
            <div style={{
              fontSize: 9, color: INK_2,
              fontFamily: '"Hind Siliguri", "Noto Sans Bengali", sans-serif',
            }}>{bn}</div>
          </div>
          {tr === true || tr === false
            ? <Toggle on={tr} />
            : <div style={{ fontSize: 11, color: INK_2 }}>{tr || '›'}</div>}
        </div>
      ))}
    </Ink>
  </div>
);

// S1 — Classic grouped list (most familiar)
const SettingsList = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Settings" bn="সেটিংস" />
    <SettingsGroup title="STORE · দোকান" items={[
      ['◉', 'Restaurant Profile', 'রেস্তোরাঁ', '›'],
      ['৳', 'Currency', 'মুদ্রা', 'BDT'],
      ['☷', 'Tables', 'টেবিল', '12'],
    ]} />
    <SettingsGroup title="DEVICE · ডিভাইস" items={[
      ['☼', 'Dark mode', 'ডার্ক মোড', true],
      ['⎙', 'Printer', 'প্রিন্টার', 'Connected'],
      ['⇅', 'Sync', 'সিঙ্ক', 'Auto'],
    ]} />
    <SettingsGroup title="ACCOUNT · অ্যাকাউন্ট" items={[
      ['☺', 'Staff', 'স্টাফ', '4'],
      ['↪', 'Sign out', 'লগ আউট', '›'],
    ]} />
    <BottomNav active={4} />
  </div>
);

// S2 — Card-grouped with icon tiles
const SettingsCards = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Settings" bn="সেটিংস" />
    <div style={{
      padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10,
    }}>
      {[
        ['◉', 'Profile', 'প্রোফাইল'],
        ['⎙', 'Printer', 'প্রিন্টার'],
        ['⇅', 'Sync', 'সিঙ্ক'],
        ['☷', 'Tables', 'টেবিল'],
        ['☺', 'Staff', 'স্টাফ'],
        ['◐', 'Theme', 'থিম'],
      ].map(([g, en, bn], i) => (
        <Ink key={i} style={{ padding: 12, textAlign: 'center' }}>
          <div style={{
            width: 30, height: 30, border: `1.5px solid ${INK}`, borderRadius: 8,
            display: 'grid', placeItems: 'center', fontSize: 14, margin: '0 auto',
            background: i === 5 ? ACCENT : PAPER_2,
          }}>{g}</div>
          <div style={{ fontSize: 12, fontWeight: 700, marginTop: 6 }}>{en}</div>
          <div style={{
            fontSize: 9, color: INK_2,
            fontFamily: '"Hind Siliguri", "Noto Sans Bengali", sans-serif',
          }}>{bn}</div>
        </Ink>
      ))}
    </div>
    {/* quick toggles */}
    <div style={{ padding: '14px 16px 0' }}>
      <div style={{ fontSize: 10, color: INK_2, marginBottom: 6 }}>QUICK · দ্রুত</div>
      <Ink style={{ padding: 0, overflow: 'hidden' }}>
        {[['Dark mode', 'ডার্ক', true], ['Auto-print', 'অটো প্রিন্ট', false]].map(([en, bn, on], i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '8px 12px',
            borderBottom: i === 0 ? `1px dashed ${INK_3}` : 'none',
          }}>
            <div>
              <div style={{ fontSize: 12, fontWeight: 700 }}>{en}</div>
              <div style={{
                fontSize: 9, color: INK_2,
                fontFamily: '"Hind Siliguri", "Noto Sans Bengali", sans-serif',
              }}>{bn}</div>
            </div>
            <Toggle on={on} />
          </div>
        ))}
      </Ink>
    </div>
    <BottomNav active={4} />
  </div>
);

// S3 — Search-first / minimal
const SettingsSearch = () => (
  <div style={{ position: 'relative', height: '100%' }}>
    <ScreenTitle en="Settings" bn="সেটিংস" />
    <div style={{ padding: '0 16px 12px' }}>
      <Ink style={{ padding: '8px 10px', display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 13, color: INK_3 }}>⌕</span>
        <span style={{ fontSize: 11, color: INK_3 }}>Search settings · সেটিংস খুঁজুন</span>
      </Ink>
    </div>
    <div style={{ padding: '0 16px' }}>
      <div style={{ fontSize: 10, color: INK_2, marginBottom: 6 }}>SUGGESTED · প্রস্তাবিত</div>
      {[
        ['Connect a printer', 'প্রিন্টার সংযোগ করুন', 'Setup'],
        ['Switch to dark mode', 'ডার্ক মোড চালু করুন', 'On'],
        ['Add a staff account', 'স্টাফ যোগ করুন', '+'],
      ].map(([en, bn, action], i) => (
        <Ink key={i} style={{
          padding: '10px 12px', marginBottom: 8,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <div>
            <div style={{ fontSize: 12, fontWeight: 700 }}>{en}</div>
            <div style={{
              fontSize: 9, color: INK_2,
              fontFamily: '"Hind Siliguri", "Noto Sans Bengali", sans-serif',
            }}>{bn}</div>
          </div>
          <div style={{
            fontSize: 10, padding: '3px 8px', border: `1.5px solid ${INK}`,
            borderRadius: 10, background: i === 1 ? ACCENT : PAPER,
          }}>{action}</div>
        </Ink>
      ))}
      <div style={{ fontSize: 10, color: INK_2, margin: '6px 0 6px' }}>ALL · সব</div>
      {['Restaurant Profile · প্রোফাইল', 'Tables · টেবিল', 'Currency · মুদ্রা', 'Sync · সিঙ্ক', 'About · সম্পর্কে'].map((t, i) => (
        <div key={i} style={{
          padding: '8px 0', fontSize: 12, borderBottom: `1px dashed ${INK_3}`,
          display: 'flex', justifyContent: 'space-between',
        }}>
          <span>{t}</span><span style={{ color: INK_3 }}>›</span>
        </div>
      ))}
    </div>
    <BottomNav active={4} />
  </div>
);

// ---------- shared bits ----------

const Toggle = ({ on }) => (
  <div style={{
    width: 30, height: 18, borderRadius: 9, border: `1.5px solid ${INK}`,
    background: on ? ACCENT : PAPER_2, position: 'relative',
    flex: '0 0 auto',
  }}>
    <div style={{
      position: 'absolute', top: 1, left: on ? 13 : 1,
      width: 14, height: 14, borderRadius: 7,
      background: PAPER, border: `1.5px solid ${INK}`,
      transition: 'left .15s',
    }} />
  </div>
);

const ImgPlaceholder = ({ h = 70, label }) => (
  <div style={{
    width: '100%', height: h, background: PAPER_2,
    backgroundImage: `repeating-linear-gradient(45deg, transparent 0 6px, rgba(0,0,0,.07) 6px 7px)`,
    borderBottom: `1.5px solid ${INK}`,
    display: 'grid', placeItems: 'center',
    fontFamily: 'JetBrains Mono, ui-monospace, monospace',
    fontSize: 9, color: INK_2,
  }}>{label || '⬚ photo'}</div>
);

// ---------- System notes card ----------

const SystemNotes = () => (
  <div style={{
    width: 740, padding: 22,
    fontFamily: 'Kalam, cursive', color: INK, background: PAPER,
    border: `1.5px solid ${INK}`, borderRadius: 14,
  }}>
    <div style={{ fontSize: 22 }}>System notes — for the hi-fi pass</div>
    <div style={{ fontSize: 12, color: INK_2, marginBottom: 18 }}>
      These wireframes commit to layout & flow. The values below are starting points to translate
      into the hi-fi Flutter theme — open them up once we pick a layout direction per screen.
    </div>
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 22 }}>
      {/* PALETTE */}
      <div>
        <div style={{ fontSize: 14, marginBottom: 8 }}>Palette · dark-first</div>
        {[
          ['Surface 0', '#14110e', 'app bg'],
          ['Surface 1', '#1f1c18', 'cards'],
          ['Surface 2', '#2a2622', 'raised'],
          ['Ink hi', '#f6f1e4', 'titles'],
          ['Ink lo', '#9a9388', 'support'],
          ['Brand', '#E8C547', 'accent · ▼ from #FFD928'],
          ['Pending', '#E8C547', 'state'],
          ['Cooking', '#E8A14A', 'state'],
          ['Ready', '#7BB47C', 'state'],
          ['Danger', '#D86A55', 'state'],
        ].map(([n, hex, note]) => (
          <div key={n} style={{
            display: 'flex', alignItems: 'center', gap: 10,
            padding: '4px 0', fontSize: 11,
          }}>
            <div style={{
              width: 22, height: 22, background: hex,
              border: `1.5px solid ${INK}`, borderRadius: 4,
            }} />
            <div style={{ width: 70 }}>{n}</div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', color: INK_2, width: 70 }}>{hex}</div>
            <div style={{ color: INK_2 }}>{note}</div>
          </div>
        ))}
      </div>
      {/* TYPE + COMPONENTS */}
      <div>
        <div style={{ fontSize: 14, marginBottom: 8 }}>Type · Inter (no more w900 abuse)</div>
        <div style={{
          fontFamily: 'Inter, system-ui, sans-serif', color: INK,
          padding: '8px 12px', background: PAPER_2, borderRadius: 8,
          border: `1.5px solid ${INK_3}`,
        }}>
          <div style={{ fontSize: 32, fontWeight: 700, lineHeight: 1 }}>৳ 42,180</div>
          <div style={{ fontSize: 11, color: INK_2 }}>display · 32 / 700</div>
          <div style={{ fontSize: 20, fontWeight: 600, marginTop: 8 }}>Orders</div>
          <div style={{ fontSize: 11, color: INK_2 }}>headline · 20 / 600</div>
          <div style={{ fontSize: 16, fontWeight: 600, marginTop: 8 }}>#142 · Table 6</div>
          <div style={{ fontSize: 11, color: INK_2 }}>title · 16 / 600</div>
          <div style={{ fontSize: 13, marginTop: 8 }}>Chicken Biriyani × 2</div>
          <div style={{ fontSize: 11, color: INK_2 }}>body · 13 / 400</div>
          <div style={{
            fontSize: 11, marginTop: 8, letterSpacing: 0.6,
            textTransform: 'uppercase', fontWeight: 600,
          }}>NEW · PENDING</div>
          <div style={{ fontSize: 11, color: INK_2 }}>label · 11 / 600 caps</div>
        </div>

        <div style={{ fontSize: 14, marginTop: 14, marginBottom: 8 }}>Components</div>
        <ul style={{ fontSize: 11, lineHeight: 1.5, color: INK, margin: 0, paddingLeft: 16 }}>
          <li>Cards: radius 14, surface-1 bg, 1px hairline at #2a2622, no shadow on dark.</li>
          <li>Order cards: 4px left-border in state color + status badge top-right (both, not either).</li>
          <li>Bottom nav: 5 dest, 64dp tall, pill-shaped active indicator (brand bg + ink fg).</li>
          <li>Buttons: 48dp min height, primary = brand bg + ink fg, secondary = surface-2 + ink.</li>
          <li>Toggles: brand-on, surface-2 off. Touch target wraps full row.</li>
          <li>Badges: 11/600 caps, pill, 4px vertical pad, hairline outline always.</li>
        </ul>
      </div>
    </div>
  </div>
);

// ---------- Canvas root ----------

function App() {
  return (
    <DesignCanvas>
      <DCSection id="dashboard" title="Dashboard"
        subtitle="Counter-staff homepage — sales pulse + open orders glance">
        <DCArtboard id="d1" label="A · Hero card + 2×2 grid" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><DashHero /></Phone>
        </DCArtboard>
        <DCArtboard id="d2" label="B · Giant number" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><DashGiant /></Phone>
        </DCArtboard>
        <DCArtboard id="d3" label="C · Pulse + kanban peek" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><DashPulse /></Phone>
        </DCArtboard>
        <DCArtboard id="d4" label="D · Open orders first" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><DashList /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection id="orders" title="Orders"
        subtitle="Active / Done tabs · status = left border + badge">
        <DCArtboard id="o1" label="A · Tabs + bordered cards" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><OrdersBordered /></Phone>
        </DCArtboard>
        <DCArtboard id="o2" label="B · Swipe-to-act" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><OrdersSwipe /></Phone>
        </DCArtboard>
        <DCArtboard id="o3" label="C · Kanban columns" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><OrdersKanban /></Phone>
        </DCArtboard>
        <DCArtboard id="o4" label="D · One-up focus" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><OrdersFocus /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection id="menu" title="Menu management"
        subtitle="Edit items, toggle availability, view stock">
        <DCArtboard id="m1" label="A · 2-col image grid" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><MenuGrid /></Phone>
        </DCArtboard>
        <DCArtboard id="m2" label="B · Dense list (fast scan)" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><MenuList /></Phone>
        </DCArtboard>
        <DCArtboard id="m3" label="C · Photo-first by category" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><MenuHero /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection id="settings" title="Settings"
        subtitle="Grouped controls, toggles, account">
        <DCArtboard id="s1" label="A · Grouped list (classic)" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><SettingsList /></Phone>
        </DCArtboard>
        <DCArtboard id="s2" label="B · Icon tiles + quick toggles" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><SettingsCards /></Phone>
        </DCArtboard>
        <DCArtboard id="s3" label="C · Search-first" width={W + FRAME_PAD * 2} height={H + FRAME_PAD * 2 + 18}>
          <Phone><SettingsSearch /></Phone>
        </DCArtboard>
      </DCSection>

      <DCSection id="system" title="System notes"
        subtitle="Palette + type + component rules to carry into the hi-fi Flutter theme">
        <DCArtboard id="sys" label="Dark-first tokens" width={780} height={620}>
          <SystemNotes />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
