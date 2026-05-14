// Orders screen — default home. Active / Done tabs.
// Single active state = ACCEPTED. Counter staff swipes Serve to close.

const ACTIVE_ORDERS = [
  { id: '#142', src: 'Table 6', srcKind: 'table', time: '12:04', wait: '2 min',
    items: [
      ['Chicken Biriyani', 2, 480],
      ['Borhani', 1, 80],
      ['Roast Chicken', 1, 220],
    ], total: 780, accepted: '12:05' },
  { id: '#141', src: 'Take-away', srcKind: 'bag', time: '11:52', wait: '14 min',
    items: [
      ['Beef Tehari', 1, 280],
      ['Coke 500ml', 1, 50],
    ], total: 330, accepted: '11:53' },
  { id: '#140', src: 'Delivery · DLV-22', srcKind: 'truck', time: '11:30', wait: '36 min',
    items: [
      ['Set Menu A', 1, 480],
      ['Lassi', 2, 120],
      ['Naan', 3, 90],
    ], total: 690, accepted: '11:32', flagged: true },
  { id: '#138', src: 'Table 2', srcKind: 'table', time: '11:18', wait: '48 min',
    items: [
      ['Plain Pulao', 1, 180],
      ['Chicken Curry', 1, 220],
      ['Roti', 4, 40],
    ], total: 440, accepted: '11:19' },
];

const DONE_ORDERS = [
  { id: '#139', src: 'Table 4', srcKind: 'table', time: '10:58', total: 920, items: 5 },
  { id: '#137', src: 'Take-away', srcKind: 'bag', time: '10:42', total: 280, items: 2 },
  { id: '#136', src: 'Delivery · DLV-21', srcKind: 'truck', time: '10:31', total: 1180, items: 6 },
  { id: '#135', src: 'Table 9', srcKind: 'table', time: '10:18', total: 520, items: 3 },
  { id: '#134', src: 'Table 1', srcKind: 'table', time: '10:02', total: 380, items: 2 },
];

const OrderCard = ({ o, onServe }) => (
  <div style={{
    display: 'flex', marginBottom: 12,
    fontFamily: fontUI,
  }}>
    {/* status rail */}
    <div style={{
      width: 4, borderRadius: 4,
      background: o.flagged ? tokens.danger : tokens.brand,
      marginRight: 12, flexShrink: 0,
    }} />
    <div style={{
      flex: 1, background: tokens.bg1,
      border: `1px solid ${tokens.hairline}`, borderRadius: 16,
      padding: 14,
    }}>
      {/* row 1: id + status badge */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{
            fontFamily: fontMono, fontSize: 16, fontWeight: 600, color: tokens.inkHi,
          }}>{o.id}</span>
          <span style={{ color: tokens.inkLow, fontSize: 14 }}>·</span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: tokens.inkMid, fontSize: 13 }}>
            <Icon name={o.srcKind} size={14} />
            {o.src}
          </span>
        </div>
        <Badge kind={o.flagged ? 'danger' : 'brand'}>
          {o.flagged ? 'Late' : 'Accepted'}
        </Badge>
      </div>
      {/* row 2: time + wait */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 6, marginTop: 6,
        color: tokens.inkLow, fontSize: 12,
      }}>
        <Icon name="clock" size={12} />
        <span>placed {o.time}</span>
        <span>·</span>
        <span style={{ color: o.flagged ? tokens.danger : tokens.inkMid }}>{o.wait}</span>
      </div>
      {/* items */}
      <div style={{
        marginTop: 12, paddingTop: 12,
        borderTop: `1px dashed ${tokens.hairline}`,
      }}>
        {o.items.map(([n, q, p], i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '3px 0',
          }}>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 0,
            }}>
              <span style={{
                width: 22, fontFamily: fontMono, fontSize: 12, color: tokens.inkLow,
              }}>×{q}</span>
              <span style={{
                fontSize: 14, color: tokens.inkHi, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
              }}>{n}</span>
            </div>
            <span style={{
              fontFamily: fontMono, fontSize: 13, color: tokens.inkMid,
            }}>৳{p}</span>
          </div>
        ))}
      </div>
      {/* total + serve */}
      <div style={{
        marginTop: 12, paddingTop: 12,
        borderTop: `1px solid ${tokens.hairline}`,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div>
          <div style={{ fontSize: 11, color: tokens.inkLow, letterSpacing: 0.5, textTransform: 'uppercase' }}>Total</div>
          <div style={{
            fontFamily: fontMono, fontSize: 19, fontWeight: 600, color: tokens.inkHi, marginTop: 2,
          }}>৳ {o.total.toLocaleString()}</div>
        </div>
        <button onClick={onServe} style={{
          background: tokens.brand, color: tokens.inkInvert, border: 'none',
          padding: '12px 22px', borderRadius: 12, minHeight: 48,
          fontFamily: fontUI, fontSize: 14, fontWeight: 600,
          cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <Icon name="check" size={18} strokeWidth={2.2} />
          Serve
        </button>
      </div>
    </div>
  </div>
);

const DoneRow = ({ o }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 12, padding: '14px 0',
    borderBottom: `1px solid ${tokens.hairline}`,
    fontFamily: fontUI,
  }}>
    <div style={{
      width: 36, height: 36, borderRadius: 12, background: tokens.bg1,
      border: `1px solid ${tokens.hairline}`,
      display: 'grid', placeItems: 'center', color: tokens.inkMid,
    }}>
      <Icon name={o.srcKind} size={16} />
    </div>
    <div style={{ flex: 1 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span style={{ fontFamily: fontMono, fontSize: 14, fontWeight: 600 }}>{o.id}</span>
        <span style={{ fontSize: 13, color: tokens.inkMid }}>{o.src}</span>
      </div>
      <div style={{ fontSize: 11, color: tokens.inkLow, marginTop: 2 }}>
        {o.time} · {o.items} items
      </div>
    </div>
    <div style={{ textAlign: 'right' }}>
      <div style={{ fontFamily: fontMono, fontSize: 14, fontWeight: 600, color: tokens.inkHi }}>
        ৳{o.total.toLocaleString()}
      </div>
      <div style={{ marginTop: 4 }}>
        <Badge kind="success">Served</Badge>
      </div>
    </div>
  </div>
);

const Tabs = ({ active, onChange, tabs }) => (
  <div style={{
    display: 'flex', padding: '0 20px', gap: 6, marginBottom: 4,
  }}>
    {tabs.map((t, i) => {
      const on = i === active;
      return (
        <button key={i} onClick={() => onChange(i)} style={{
          flex: 1, background: on ? tokens.bg1 : 'transparent',
          border: `1px solid ${on ? tokens.hairlineHi : 'transparent'}`,
          color: on ? tokens.inkHi : tokens.inkMid,
          padding: '12px 0', borderRadius: 14, cursor: 'pointer',
          fontFamily: fontUI, fontSize: 14, fontWeight: 600,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          minHeight: 48,
        }}>
          <span>{t.en}</span>
          <span style={{
            fontSize: 11, fontWeight: 600,
            padding: '2px 7px', borderRadius: 999,
            background: on ? tokens.brand : tokens.bg2,
            color: on ? tokens.inkInvert : tokens.inkMid,
          }}>{t.n}</span>
        </button>
      );
    })}
  </div>
);

const OrdersScreen = () => {
  const [tab, setTab] = React.useState(0);
  const [serving, setServing] = React.useState(null);
  const [served, setServed] = React.useState([]);
  const active = ACTIVE_ORDERS.filter(o => !served.includes(o.id));

  return (
    <ScreenScroll>
      <PageHeader
        title="Orders"
        sub="অর্ডার · 4 active · ৳ 2,240 open"
        right={
          <div style={{ display: 'flex', gap: 8 }}>
            <IconBtn name="filter" ariaLabel="Filter" />
            <IconBtn name="plus" ariaLabel="New order" />
          </div>
        } />
      <Tabs active={tab} onChange={setTab} tabs={[
        { en: 'Active', n: active.length },
        { en: 'Done', n: DONE_ORDERS.length },
      ]} />
      {/* incoming banner */}
      {tab === 0 && (
        <div style={{ padding: '14px 20px 6px' }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 12,
            background: tokens.brandDim, border: `1px solid ${tokens.brandRim}`,
            borderRadius: 14, padding: '12px 14px',
          }}>
            <div style={{
              width: 38, height: 38, borderRadius: 12, background: tokens.brand,
              display: 'grid', placeItems: 'center', color: tokens.inkInvert,
            }}>
              <Icon name="bell" size={18} strokeWidth={2} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: tokens.inkHi }}>
                1 new order pending
              </div>
              <div style={{ fontSize: 11, color: tokens.inkMid, marginTop: 2 }}>
                Table 8 · ৳420 · placed 30 sec ago
              </div>
            </div>
            <button style={{
              background: tokens.brand, color: tokens.inkInvert,
              border: 'none', padding: '8px 14px', borderRadius: 10,
              fontFamily: fontUI, fontSize: 13, fontWeight: 600, cursor: 'pointer',
              minHeight: 36,
            }}>Accept</button>
          </div>
        </div>
      )}
      <div style={{ padding: '14px 20px 0' }}>
        {tab === 0 ? (
          active.length === 0
            ? <div style={{
                padding: 40, textAlign: 'center', color: tokens.inkLow,
                fontSize: 13,
              }}>All caught up · কোনো চলমান অর্ডার নেই</div>
            : active.map(o => (
                <OrderCard key={o.id} o={o} onServe={() => setServing(o.id)} />
              ))
        ) : (
          DONE_ORDERS.map(o => <DoneRow key={o.id} o={o} />)
        )}
      </div>
      {/* confirm sheet */}
      {serving && (
        <div onClick={() => setServing(null)} style={{
          position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.55)',
          display: 'flex', alignItems: 'flex-end', zIndex: 20,
        }}>
          <div onClick={(e) => e.stopPropagation()} style={{
            width: '100%', background: tokens.bg1,
            borderTopLeftRadius: 24, borderTopRightRadius: 24,
            padding: '20px 22px 28px',
            border: `1px solid ${tokens.hairline}`,
          }}>
            <div style={{ width: 36, height: 4, borderRadius: 2, background: tokens.bg3, margin: '0 auto 18px' }} />
            <div style={{
              fontFamily: fontUI, fontSize: 20, fontWeight: 600, color: tokens.inkHi,
            }}>Mark {serving} as served?</div>
            <div style={{
              fontFamily: fontBn, fontSize: 13, color: tokens.inkMid, marginTop: 6,
            }}>সার্ভ হিসেবে চিহ্নিত করুন</div>
            <div style={{ display: 'flex', gap: 10, marginTop: 22 }}>
              <button onClick={() => setServing(null)} style={{
                flex: 1, background: tokens.bg2, color: tokens.inkHi,
                border: `1px solid ${tokens.hairline}`, padding: '14px 0',
                borderRadius: 14, fontFamily: fontUI, fontSize: 15, fontWeight: 600,
                minHeight: 52, cursor: 'pointer',
              }}>Cancel</button>
              <button onClick={() => { setServed([...served, serving]); setServing(null); }} style={{
                flex: 1, background: tokens.brand, color: tokens.inkInvert,
                border: 'none', padding: '14px 0',
                borderRadius: 14, fontFamily: fontUI, fontSize: 15, fontWeight: 600,
                minHeight: 52, cursor: 'pointer',
              }}>Serve ✓</button>
            </div>
          </div>
        </div>
      )}
    </ScreenScroll>
  );
};

Object.assign(window, { OrdersScreen });
