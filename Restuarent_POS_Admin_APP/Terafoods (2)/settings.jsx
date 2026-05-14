// Settings — grouped list with a search bar on top.

const GROUPS = [
  {
    label: 'STORE', bn: 'দোকান',
    rows: [
      { icon: 'user', en: 'Restaurant Profile', bn: 'রেস্তোরাঁ প্রোফাইল', value: 'Spice Garden' },
      { icon: 'coin', en: 'Currency', bn: 'মুদ্রা', value: 'BDT (৳)' },
      { icon: 'table', en: 'Tables', bn: 'টেবিল ব্যবস্থাপনা', value: '12 tables' },
      { icon: 'receipt', en: 'Receipt template', bn: 'রসিদ টেমপ্লেট', chev: true },
    ],
  },
  {
    label: 'DEVICE', bn: 'ডিভাইস',
    rows: [
      { icon: 'moon', en: 'Dark mode', bn: 'ডার্ক মোড', toggle: true },
      { icon: 'printer', en: 'Printer', bn: 'প্রিন্টার', value: 'EPSON TM-m30', dot: 'success' },
      { icon: 'sync', en: 'Auto-sync', bn: 'অটো-সিঙ্ক', toggle: true },
      { icon: 'bell', en: 'Order alerts', bn: 'অর্ডার অ্যালার্ট', toggle: true },
    ],
  },
  {
    label: 'ACCOUNT', bn: 'অ্যাকাউন্ট',
    rows: [
      { icon: 'user', en: 'Staff', bn: 'স্টাফ', value: '4 active' },
      { icon: 'settings', en: 'Preferences', bn: 'পছন্দসমূহ', chev: true },
      { icon: 'x', en: 'Sign out', bn: 'লগ আউট', danger: true },
    ],
  },
];

const SettingsRow = ({ row, isLast }) => {
  const [on, setOn] = React.useState(row.toggle === true);
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 14,
      padding: '14px 16px', minHeight: 56, cursor: 'pointer',
      borderBottom: isLast ? 'none' : `1px solid ${tokens.hairline}`,
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: 10,
        background: row.danger ? tokens.dangerDim : tokens.bg2,
        color: row.danger ? tokens.danger : tokens.inkMid,
        display: 'grid', placeItems: 'center', flexShrink: 0,
        border: `1px solid ${row.danger ? 'rgba(216,105,79,0.2)' : tokens.hairline}`,
      }}>
        <Icon name={row.icon} size={17} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontFamily: fontUI, fontSize: 14, fontWeight: 600,
          color: row.danger ? tokens.danger : tokens.inkHi,
        }}>{row.en}</div>
        <div style={{
          fontFamily: fontBn, fontSize: 12, color: tokens.inkLow, marginTop: 2,
        }}>{row.bn}</div>
      </div>
      {row.toggle != null
        ? <Toggle on={on} onChange={() => setOn(!on)} />
        : row.value
          ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              {row.dot === 'success' && (
                <span style={{ width: 7, height: 7, borderRadius: 4, background: tokens.success }} />
              )}
              <span style={{
                fontFamily: fontUI, fontSize: 13, color: tokens.inkMid, marginRight: 4,
              }}>{row.value}</span>
              <Icon name="chevR" size={16} color={tokens.inkLow} />
            </div>
          )
          : row.chev
            ? <Icon name="chevR" size={16} color={tokens.inkLow} />
            : null}
    </div>
  );
};

const SettingsScreen = () => {
  const [query, setQuery] = React.useState('');

  // flatten + filter for search
  const flatHits = !query ? null : GROUPS.flatMap(g => g.rows
    .filter(r => r.en.toLowerCase().includes(query.toLowerCase()))
    .map(r => ({ ...r, group: g.label }))
  );

  return (
    <ScreenScroll>
      <PageHeader
        title="Settings"
        sub="সেটিংস · v2.3.1" />

      {/* search */}
      <div style={{ padding: '0 20px 14px' }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          background: tokens.bg1, border: `1px solid ${tokens.hairline}`,
          borderRadius: 14, padding: '0 14px', height: 48,
        }}>
          <Icon name="search" size={18} color={tokens.inkLow} />
          <input
            value={query} onChange={e => setQuery(e.target.value)}
            placeholder="Search settings · সেটিংস খুঁজুন"
            style={{
              flex: 1, background: 'transparent', border: 'none', outline: 'none',
              color: tokens.inkHi, fontFamily: fontUI, fontSize: 14,
            }} />
          {query && (
            <button onClick={() => setQuery('')} style={{
              background: 'transparent', border: 'none', color: tokens.inkLow,
              cursor: 'pointer', padding: 0, display: 'grid', placeItems: 'center',
            }}>
              <Icon name="x" size={16} />
            </button>
          )}
        </div>
      </div>

      {flatHits ? (
        <>
          <SectionLabel>{flatHits.length} results</SectionLabel>
          <div style={{ padding: '0 20px' }}>
            <div style={{
              background: tokens.bg1, border: `1px solid ${tokens.hairline}`,
              borderRadius: 16, overflow: 'hidden',
            }}>
              {flatHits.map((r, i) => (
                <SettingsRow key={r.en} row={r} isLast={i === flatHits.length - 1} />
              ))}
              {flatHits.length === 0 && (
                <div style={{ padding: 30, textAlign: 'center', color: tokens.inkLow, fontSize: 13 }}>
                  No matches · কোনো ফলাফল নেই
                </div>
              )}
            </div>
          </div>
        </>
      ) : (
        GROUPS.map(g => (
          <div key={g.label} style={{ marginBottom: 22 }}>
            <SectionLabel>{g.label} · <span style={{ fontFamily: fontBn, textTransform: 'none', letterSpacing: 0 }}>{g.bn}</span></SectionLabel>
            <div style={{ padding: '0 20px' }}>
              <div style={{
                background: tokens.bg1, border: `1px solid ${tokens.hairline}`,
                borderRadius: 16, overflow: 'hidden',
              }}>
                {g.rows.map((r, i) => (
                  <SettingsRow key={r.en} row={r} isLast={i === g.rows.length - 1} />
                ))}
              </div>
            </div>
          </div>
        ))
      )}

      <div style={{
        padding: '4px 20px 0', textAlign: 'center',
        fontFamily: fontMono, fontSize: 11, color: tokens.inkLow,
      }}>
        Rastarant POS · 2.3.1 (build 412)
      </div>
    </ScreenScroll>
  );
};

Object.assign(window, { SettingsScreen });
