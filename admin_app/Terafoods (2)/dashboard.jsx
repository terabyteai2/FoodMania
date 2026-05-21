// Dashboard ("Insights") — Layout A (hero + grid) and Layout B (giant number)
// Selected via Tweaks panel.

const Sparkline = ({ data, w = 320, h = 56, fill = true }) => {
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1)) * w;
    const y = h - ((v - min) / range) * (h - 6) - 3;
    return [x, y];
  });
  const line = pts.map(([x, y]) => `${x},${y}`).join(' ');
  const area = `0,${h} ${line} ${w},${h}`;
  return (
    <svg viewBox={`0 0 ${w} ${h}`} style={{ width: '100%', height: h, display: 'block' }}>
      {fill && <polyline fill={tokens.brand} fillOpacity="0.18" stroke="none" points={area} />}
      <polyline fill="none" stroke={tokens.brand} strokeWidth="2"
        strokeLinecap="round" strokeLinejoin="round" points={line} />
      {pts.slice(-1).map(([x, y], i) => (
        <circle key={i} cx={x} cy={y} r="3.5" fill={tokens.brand} stroke={tokens.bg1} strokeWidth="2" />
      ))}
    </svg>
  );
};

const HERO_DATA = [22, 28, 25, 34, 30, 38, 32, 42, 38, 45, 48, 52];

const MetricCard = ({ label, bn, value, delta, accent }) => (
  <div style={{
    background: tokens.bg1, border: `1px solid ${tokens.hairline}`,
    borderRadius: 16, padding: 14, fontFamily: fontUI,
  }}>
    <div style={{
      fontSize: 11, fontWeight: 600, color: tokens.inkLow,
      letterSpacing: 0.6, textTransform: 'uppercase',
    }}>{label}</div>
    <div style={{ fontFamily: fontBn, fontSize: 11, color: tokens.inkLow, marginTop: 1 }}>{bn}</div>
    <div style={{
      fontFamily: fontMono, fontSize: 24, fontWeight: 600,
      color: accent ? tokens.brand : tokens.inkHi, marginTop: 10, lineHeight: 1,
    }}>{value}</div>
    {delta && (
      <div style={{
        fontSize: 11, color: delta.startsWith('+') ? tokens.success : tokens.danger,
        marginTop: 6,
      }}>{delta}</div>
    )}
  </div>
);

const QuickAction = ({ icon, label, onClick }) => (
  <button onClick={onClick} style={{
    flex: 1, background: tokens.bg1, border: `1px solid ${tokens.hairline}`,
    borderRadius: 14, padding: '12px 8px', cursor: 'pointer',
    display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
    color: tokens.inkHi, minHeight: 64, fontFamily: fontUI,
  }}>
    <Icon name={icon} size={20} />
    <span style={{ fontSize: 11, fontWeight: 600 }}>{label}</span>
  </button>
);

// ---------- Layout A: Hero card + 2x2 metric grid + quick actions ----------
const DashboardA = () => (
  <ScreenScroll>
    <PageHeader
      title="Good morning"
      sub="শুভ সকাল · Sat, May 12"
      right={<IconBtn name="bell" ariaLabel="Notifications" />} />

    {/* Hero sales card */}
    <div style={{ padding: '0 20px 16px' }}>
      <div style={{
        background: `linear-gradient(135deg, ${tokens.bg1} 0%, ${tokens.bg2} 100%)`,
        border: `1px solid ${tokens.hairline}`, borderRadius: 20,
        padding: '18px 20px 6px', position: 'relative', overflow: 'hidden',
      }}>
        <div style={{
          position: 'absolute', top: -40, right: -40, width: 160, height: 160,
          borderRadius: '50%', background: tokens.brandDim, filter: 'blur(40px)',
        }} />
        <div style={{ position: 'relative' }}>
          <div style={{
            fontSize: 11, color: tokens.inkLow, fontFamily: fontUI, fontWeight: 600,
            letterSpacing: 1, textTransform: 'uppercase',
          }}>Today's sales</div>
          <div style={{ fontFamily: fontBn, fontSize: 12, color: tokens.inkLow, marginTop: 1 }}>আজকের বিক্রি</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 12 }}>
            <span style={{
              fontFamily: fontMono, fontSize: 40, fontWeight: 600,
              color: tokens.inkHi, lineHeight: 1, letterSpacing: -1,
            }}>৳ 42,180</span>
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8, marginTop: 8,
          }}>
            <Badge kind="success">▲ 12%</Badge>
            <span style={{ fontSize: 12, color: tokens.inkMid }}>vs yesterday</span>
          </div>
          <div style={{ marginTop: 14 }}>
            <Sparkline data={HERO_DATA} h={50} />
          </div>
          <div style={{
            display: 'flex', justifyContent: 'space-between',
            fontFamily: fontMono, fontSize: 10, color: tokens.inkLow,
            paddingTop: 4, paddingBottom: 10,
          }}>
            <span>9 AM</span><span>12 PM</span><span>3 PM</span><span>now</span>
          </div>
        </div>
      </div>
    </div>

    {/* metric grid */}
    <SectionLabel>Today · আজ</SectionLabel>
    <div style={{
      padding: '0 20px 18px',
      display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10,
    }}>
      <MetricCard label="Orders" bn="অর্ডার" value="38" delta="+5 vs yest." />
      <MetricCard label="Open" bn="চলমান" value="4" accent />
      <MetricCard label="Avg ticket" bn="গড় টিকেট" value="৳1,109" delta="+৳82" />
      <MetricCard label="Top item" bn="টপ আইটেম" value="Biriyani" />
    </div>

    {/* quick actions */}
    <SectionLabel>Quick actions</SectionLabel>
    <div style={{ padding: '0 20px 18px', display: 'flex', gap: 8 }}>
      <QuickAction icon="plus" label="New order" />
      <QuickAction icon="printer" label="Z-Report" />
      <QuickAction icon="sync" label="Sync" />
      <QuickAction icon="boxes" label="Stock" />
    </div>

    {/* Top items */}
    <SectionLabel right={
      <span style={{
        fontFamily: fontUI, fontSize: 12, fontWeight: 600, color: tokens.brand,
      }}>See all →</span>
    }>Top items today</SectionLabel>
    <div style={{ padding: '0 20px 0' }}>
      {[
        ['Chicken Biriyani', 22, 5280],
        ['Beef Tehari', 12, 3360],
        ['Borhani', 18, 1440],
        ['Roast Chicken', 8, 1760],
      ].map(([n, q, rev], i) => (
        <div key={i} style={{
          display: 'flex', alignItems: 'center', gap: 12,
          padding: '12px 0',
          borderBottom: i < 3 ? `1px solid ${tokens.hairline}` : 'none',
        }}>
          <div style={{
            width: 28, height: 28, borderRadius: 8, background: tokens.bg2,
            color: tokens.inkMid, display: 'grid', placeItems: 'center',
            fontFamily: fontMono, fontSize: 12, fontWeight: 600,
          }}>{i + 1}</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, color: tokens.inkHi, fontWeight: 500 }}>{n}</div>
            <div style={{
              height: 4, borderRadius: 2, background: tokens.bg2, marginTop: 6,
              width: '100%', position: 'relative', overflow: 'hidden',
            }}>
              <div style={{
                position: 'absolute', inset: 0, width: `${(q / 22) * 100}%`,
                background: tokens.brand, borderRadius: 2,
              }} />
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ fontFamily: fontMono, fontSize: 13, fontWeight: 600 }}>×{q}</div>
            <div style={{ fontFamily: fontMono, fontSize: 11, color: tokens.inkMid }}>৳{rev.toLocaleString()}</div>
          </div>
        </div>
      ))}
    </div>
  </ScreenScroll>
);

// ---------- Layout B: Giant number focused ----------
const DashboardB = () => (
  <ScreenScroll>
    <div style={{ padding: '14px 20px 6px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ display: 'flex', gap: 6, background: tokens.bg1, padding: 4, borderRadius: 12, border: `1px solid ${tokens.hairline}` }}>
        {['Today', 'Week', 'Month'].map((t, i) => (
          <button key={t} style={{
            background: i === 0 ? tokens.brand : 'transparent',
            color: i === 0 ? tokens.inkInvert : tokens.inkMid,
            border: 'none', padding: '7px 14px', borderRadius: 8,
            fontFamily: fontUI, fontSize: 12, fontWeight: 600, cursor: 'pointer',
            minHeight: 34,
          }}>{t}</button>
        ))}
      </div>
      <IconBtn name="bell" ariaLabel="Notifications" />
    </div>

    {/* GIANT */}
    <div style={{ padding: '24px 20px 0' }}>
      <div style={{
        fontSize: 11, fontWeight: 600, color: tokens.inkLow,
        letterSpacing: 1.2, textTransform: 'uppercase', fontFamily: fontUI,
      }}>Sales · বিক্রি</div>
      <div style={{
        fontFamily: fontMono, fontWeight: 600, color: tokens.inkHi,
        fontSize: 64, lineHeight: 1, letterSpacing: -2, marginTop: 6,
      }}>৳42,180</div>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10, marginTop: 12,
      }}>
        <Badge kind="success">▲ 12.4%</Badge>
        <span style={{ fontSize: 13, color: tokens.inkMid }}>+৳4,650 vs yesterday</span>
      </div>
      <div style={{ marginTop: 22 }}>
        <Sparkline data={HERO_DATA} h={100} />
      </div>
      <div style={{
        display: 'flex', justifyContent: 'space-between', marginTop: 6,
        fontFamily: fontMono, fontSize: 10, color: tokens.inkLow,
      }}>
        <span>9 AM</span><span>12 PM</span><span>3 PM</span><span>6 PM</span><span>now</span>
      </div>
    </div>

    {/* strip metrics */}
    <div style={{
      padding: '24px 20px 0',
      display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 0,
      borderTop: `1px solid ${tokens.hairline}`, marginTop: 24,
    }}>
      {[
        ['38', 'orders', 'অর্ডার'],
        ['4', 'open', 'চলমান'],
        ['৳1.1k', 'avg', 'গড়'],
      ].map(([v, l, bn], i) => (
        <div key={i} style={{
          padding: '16px 0',
          borderRight: i < 2 ? `1px solid ${tokens.hairline}` : 'none',
          textAlign: 'center',
        }}>
          <div style={{
            fontFamily: fontMono, fontSize: 22, fontWeight: 600, color: tokens.inkHi,
          }}>{v}</div>
          <div style={{
            fontSize: 11, color: tokens.inkLow, marginTop: 4,
            letterSpacing: 0.6, textTransform: 'uppercase',
          }}>{l}</div>
          <div style={{ fontFamily: fontBn, fontSize: 11, color: tokens.inkLow }}>{bn}</div>
        </div>
      ))}
    </div>

    {/* open orders peek */}
    <div style={{ padding: '20px 0 0' }}>
      <SectionLabel right={
        <span style={{ fontFamily: fontUI, fontSize: 12, fontWeight: 600, color: tokens.brand }}>See all →</span>
      }>Open orders · 4</SectionLabel>
      <div style={{ padding: '0 20px' }}>
        {[
          ['#142', 'Table 6', 'table', '2 min', '৳780', false],
          ['#141', 'Take-away', 'bag', '14 min', '৳330', false],
          ['#140', 'Delivery', 'truck', '36 min', '৳690', true],
        ].map(([id, src, ic, wait, total, late], i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 12, padding: '11px 0',
            borderBottom: i < 2 ? `1px solid ${tokens.hairline}` : 'none',
          }}>
            <div style={{ width: 3, height: 32, borderRadius: 3,
              background: late ? tokens.danger : tokens.brand }} />
            <div style={{
              width: 32, height: 32, borderRadius: 10, background: tokens.bg1,
              border: `1px solid ${tokens.hairline}`,
              display: 'grid', placeItems: 'center', color: tokens.inkMid,
            }}>
              <Icon name={ic} size={14} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: fontMono, fontSize: 14, fontWeight: 600 }}>{id}</div>
              <div style={{ fontSize: 11, color: tokens.inkLow, marginTop: 2 }}>{src} · {wait}</div>
            </div>
            <div style={{ fontFamily: fontMono, fontSize: 14, fontWeight: 600 }}>{total}</div>
          </div>
        ))}
      </div>
    </div>
  </ScreenScroll>
);

const DashboardScreen = ({ layout = 'A' }) => layout === 'A' ? <DashboardA /> : <DashboardB />;

Object.assign(window, { DashboardScreen });
