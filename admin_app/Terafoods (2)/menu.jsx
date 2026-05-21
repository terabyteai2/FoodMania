// Menu screen — dense list. Image, name, category, price, stock, availability.
// Optimized for fast scanning at the counter.

const MENU_ITEMS = [
  { name: 'Chicken Biriyani', bn: 'চিকেন বিরিয়ানি', cat: 'Rice', price: 240, stock: 42, avail: true, hue: 32 },
  { name: 'Beef Tehari', bn: 'বিফ তেহারি', cat: 'Rice', price: 280, stock: 18, avail: true, hue: 18 },
  { name: 'Plain Pulao', bn: 'প্লেইন পোলাও', cat: 'Rice', price: 180, stock: 30, avail: true, hue: 50 },
  { name: 'Borhani', bn: 'বোরহানি', cat: 'Drinks', price: 80, stock: 60, avail: true, hue: 140 },
  { name: 'Lassi', bn: 'লাচ্ছি', cat: 'Drinks', price: 90, stock: 24, avail: true, hue: 180 },
  { name: 'Coke 500ml', bn: 'কোক', cat: 'Drinks', price: 50, stock: 88, avail: true, hue: 0 },
  { name: 'Roast Chicken', bn: 'রোস্ট', cat: 'Curry', price: 220, stock: 0, avail: false, hue: 22 },
  { name: 'Chicken Curry', bn: 'চিকেন কারি', cat: 'Curry', price: 220, stock: 14, avail: true, hue: 12 },
  { name: 'Mishti Doi', bn: 'মিষ্টি দই', cat: 'Dessert', price: 60, stock: 24, avail: true, hue: 35 },
  { name: 'Set Menu A', bn: 'সেট মেনু এ', cat: 'Combo', price: 480, stock: 12, avail: true, hue: 28 },
  { name: 'Naan', bn: 'নান', cat: 'Sides', price: 30, stock: 50, avail: true, hue: 40 },
  { name: 'Roti', bn: 'রুটি', cat: 'Sides', price: 10, stock: 80, avail: true, hue: 38 },
];

// Visual placeholder — colored swatch with monogram (no SVG drawing of food)
const ItemSwatch = ({ name, hue, avail }) => (
  <div style={{
    width: 48, height: 48, borderRadius: 12,
    background: `oklch(0.32 0.05 ${hue})`,
    border: `1px solid ${tokens.hairline}`,
    display: 'grid', placeItems: 'center',
    color: `oklch(0.88 0.07 ${hue})`,
    fontFamily: fontUI, fontSize: 17, fontWeight: 600,
    flexShrink: 0, position: 'relative',
    filter: avail ? 'none' : 'grayscale(1)',
    opacity: avail ? 1 : 0.45,
  }}>
    {name.split(' ').slice(0, 2).map(w => w[0]).join('')}
  </div>
);

const StockChip = ({ stock, avail }) => {
  if (!avail) return <span style={{ fontSize: 11, color: tokens.danger, fontWeight: 600 }}>Out</span>;
  const low = stock < 15;
  return (
    <span style={{
      fontFamily: fontMono, fontSize: 11,
      color: low ? tokens.danger : tokens.inkMid,
    }}>{stock} left</span>
  );
};

const MenuScreen = () => {
  const [cat, setCat] = React.useState('All');
  const [query, setQuery] = React.useState('');
  const [items, setItems] = React.useState(MENU_ITEMS);
  const categories = ['All', 'Rice', 'Curry', 'Drinks', 'Dessert', 'Sides', 'Combo'];

  const filtered = items.filter(it =>
    (cat === 'All' || it.cat === cat)
    && (!query || it.name.toLowerCase().includes(query.toLowerCase()))
  );

  const toggleAvail = (name) => setItems(items.map(it =>
    it.name === name ? { ...it, avail: !it.avail } : it
  ));

  return (
    <ScreenScroll>
      <PageHeader
        title="Menu"
        sub={`মেনু · ${items.length} items · ${items.filter(i => !i.avail).length} out`}
        right={
          <button style={{
            background: tokens.brand, color: tokens.inkInvert, border: 'none',
            padding: '10px 14px', borderRadius: 12, fontFamily: fontUI,
            fontSize: 13, fontWeight: 600, cursor: 'pointer',
            display: 'flex', alignItems: 'center', gap: 6, minHeight: 44,
          }}>
            <Icon name="plus" size={16} strokeWidth={2.2} />
            New
          </button>
        } />

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
            placeholder="Search items · খুঁজুন"
            style={{
              flex: 1, background: 'transparent', border: 'none', outline: 'none',
              color: tokens.inkHi, fontFamily: fontUI, fontSize: 14,
            }} />
        </div>
      </div>

      {/* category chips */}
      <div style={{
        padding: '0 20px 18px',
        display: 'flex', gap: 6, overflowX: 'auto',
      }}>
        {categories.map(c => {
          const on = c === cat;
          const count = c === 'All' ? items.length : items.filter(i => i.cat === c).length;
          return (
            <button key={c} onClick={() => setCat(c)} style={{
              background: on ? tokens.brand : tokens.bg1,
              border: `1px solid ${on ? tokens.brand : tokens.hairline}`,
              color: on ? tokens.inkInvert : tokens.inkMid,
              padding: '8px 14px', borderRadius: 999,
              fontFamily: fontUI, fontSize: 13, fontWeight: 600,
              cursor: 'pointer', whiteSpace: 'nowrap', flexShrink: 0,
              minHeight: 36, display: 'flex', alignItems: 'center', gap: 6,
            }}>
              {c}
              <span style={{
                fontFamily: fontMono, fontSize: 11,
                color: on ? tokens.inkInvert : tokens.inkLow,
                opacity: on ? 0.8 : 1,
              }}>{count}</span>
            </button>
          );
        })}
      </div>

      {/* dense list */}
      <div style={{ padding: '0 20px' }}>
        {filtered.map((it, i) => (
          <div key={it.name} style={{
            display: 'flex', alignItems: 'center', gap: 12,
            padding: '11px 0',
            borderBottom: i < filtered.length - 1 ? `1px solid ${tokens.hairline}` : 'none',
            opacity: it.avail ? 1 : 0.7,
          }}>
            <ItemSwatch name={it.name} hue={it.hue} avail={it.avail} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{
                fontSize: 14, fontWeight: 600, color: tokens.inkHi,
                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
              }}>{it.name}</div>
              <div style={{
                fontFamily: fontBn, fontSize: 11, color: tokens.inkLow, marginTop: 2,
              }}>{it.bn} · {it.cat}</div>
              <div style={{ marginTop: 6 }}>
                <StockChip stock={it.stock} avail={it.avail} />
              </div>
            </div>
            <div style={{
              display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 10,
            }}>
              <div style={{
                fontFamily: fontMono, fontSize: 15, fontWeight: 600, color: tokens.inkHi,
              }}>৳{it.price}</div>
              <Toggle on={it.avail} onChange={() => toggleAvail(it.name)} />
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <div style={{
            padding: 40, textAlign: 'center', color: tokens.inkLow,
            fontSize: 13,
          }}>No items match · কোনো ফলাফল নেই</div>
        )}
      </div>
    </ScreenScroll>
  );
};

Object.assign(window, { MenuScreen });
