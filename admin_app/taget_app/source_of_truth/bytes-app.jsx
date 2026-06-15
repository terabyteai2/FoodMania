/* ============================================================
   QuickBytes POS — root: store, navigation, responsive shell
   ============================================================ */
const BytesCtx = createContext(null);
const useBytes = () => useContext(BytesCtx);
window.useBytes = useBytes;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "device": "phone",
  "density": "comfortable"
}/*EDITMODE-END*/;

/* screen registries (single source of routing truth) */
const PUSH_REG = {
  orderDetail: OrderDetail, orderBuild: OrderBuild, review: ReviewScreen, deliveryInfo: DeliveryInfo, printOut: PrintOut,
  itemEdit: ItemEdit, menu: MenuManageScreen, stockIn: StockIn, startCount: StartCount, itemDetail: ItemDetail, variance: VarianceScreen, suppliers: SuppliersScreen, stockTrends: StockTrendsScreen,
  analytics: AnalyticsScreen, tower: ControlTower, messages: MessagesScreen, chatThread: ChatThread,
  categoryAll: CategoryAllScreen, productsAll: ProductsAllScreen, salesTable: SalesTableScreen,
  settings: SettingsScreen, deliveryAreas: DeliveryAreasScreen, discountPresets: DiscountPresetsScreen, themePicker: ThemePicker, staff: StaffScreen, audit: AuditScreen,
};
const TAB_REG = { orders: OrdersScreen, tables: TablesScreen, inventory: InventoryScreen, more: MoreScreen, analytics: AnalyticsScreen, tower: ControlTower };
/* tabs that use a list→detail two-pane layout on wide surfaces */
const MD_TABS = ['orders', 'tables', 'inventory'];
const EMPTY_DETAIL = {
  orders: { icon: 'receipt', title: 'No order selected', sub: 'Pick an order from the list to view, accept or print it.' },
  tables: { icon: 'table', title: 'No table selected', sub: 'Tap a table or order to manage the floor.' },
  inventory: { icon: 'box', title: 'No item selected', sub: 'Tap an item to see usage and adjustment history.' },
};

let _oid = 100;
function App() {
  const [orders, setOrders] = useState(seedOrders);
  const [inventory] = useState(seedInventory);
  const [chats, setChats] = useState(seedChats);
  const [notifs, setNotifs] = useState(seedNotifs);
  const [staff, setStaff] = useState(seedStaff);
  const [audit] = useState(seedAudit);
  const [suppliers] = useState(seedSuppliers);
  const [settings, setSettings] = useState({ areas: DELIVERY_AREAS.map((a) => ({ name: a[0], charge: a[1] })), discounts: DISCOUNT_PRESETS.map((d) => ({ label: d[0], kind: d[1], val: d[2] })), vat: 5, slug: 'spicegarden', theme: 'Lime', autoprint: false });
  const [role, setRole] = useState('manager');
  const [lang, setLang] = useState('en');
  const [mode, setMode] = useState('full');
  const [tab, setTabRaw] = useState('orders');
  const [nav, setNav] = useState([]);
  const t = useMemo(() => makeT(lang), [lang]);
  const _qs = (typeof location !== 'undefined') ? new URLSearchParams(location.search) : new URLSearchParams();
  const _defaults = { ...TWEAK_DEFAULTS };
  if (_qs.get('device')) _defaults.device = _qs.get('device');
  if (_qs.get('density')) _defaults.density = _qs.get('density');
  const [tw, setTweak] = useTweaks(_defaults);

  const setTab = (tb) => { setNav([]); setTabRaw(tb); };
  const switchRole = (r) => {
    setRole(r); setNav([]);
    const allowed = (NAV_BY_ROLE[r] || []).map((x) => x[0]);
    setTabRaw((cur) => allowed.includes(cur) ? cur : 'orders');
  };
  const push = (f) => setNav((n) => [...n, f]);
  const pop = () => setNav((n) => n.slice(0, -1));
  const reset = () => setNav([]);
  const go = (f) => setNav([f]);
  const updateSettings = (patch) => setSettings((s) => ({ ...s, ...patch }));

  const getOrder = (id) => orders.find((o) => o.id === id);
  const startOrder = (opts = {}) => {
    const id = 'n' + (_oid++);
    const serial = Math.max(0, ...orders.map((o) => o.serial || 0)) + 1;
    setOrders((os) => [{ id, serial, token: 2060 + Math.floor(Math.random() * 40), channel: opts.channel || 'manager', type: opts.type || 'dinein', state: 'open', mins: 0, customer: opts.customer || (opts.table ? opts.table.replace('T', 'Table ') : (opts.type === 'delivery' ? 'New delivery' : opts.type === 'parcel' ? 'New parcel' : 'Counter order')), phone: opts.phone || null, addr: opts.addr || null, area: opts.area || null, charge: opts.charge != null ? opts.charge : null, table: opts.table || null, lines: [], discount: 0 }, ...os]);
    return id;
  };
  const addOrderLine = (id, line) => setOrders((os) => os.map((o) => {
    if (o.id !== id) return o;
    const key = (l) => l.id + JSON.stringify(l.mods) + l.note;
    const ex = o.lines.find((l) => key(l) === key(line));
    if (ex) return { ...o, lines: o.lines.map((l) => l === ex ? { ...l, qty: l.qty + line.qty } : l) };
    return { ...o, lines: [...o.lines, line] };
  }));
  const setOrderLineQty = (id, lid, q) => setOrders((os) => os.map((o) => o.id !== id ? o : { ...o, lines: o.lines.map((l) => l.lid === lid ? { ...l, qty: q } : l) }));
  const removeOrderLine = (id, lid) => setOrders((os) => os.map((o) => o.id !== id ? o : { ...o, lines: o.lines.filter((l) => l.lid !== lid) }));
  const setOrderState = (id, state) => { setOrders((os) => state === 'rejected' ? os.filter((o) => o.id !== id) : os.map((o) => o.id === id ? { ...o, state } : o)); return true; };
  const setOrderDiscount = (id, d) => setOrders((os) => os.map((o) => o.id === id ? { ...o, discount: d } : o));
  const setOrderInfo = (id, info) => setOrders((os) => os.map((o) => o.id === id ? { ...o, ...info } : o));
  const sendChat = (id, text, kind) => setChats((cs) => cs.map((c) => c.id === id ? { ...c, status: kind === 'handback' ? 'bot' : 'replied', unread: 0, messages: [...c.messages, kind === 'handback' ? { from: 'system', text } : { from: 'manager', text, kind, time: 'now' }] } : c));
  const readChat = (id) => setChats((cs) => cs.map((c) => c.id === id ? { ...c, unread: 0 } : c));
  const markNotifsRead = () => setNotifs((ns) => ns.map((n) => ({ ...n, read: true })));
  const markNotifRead = (id) => setNotifs((ns) => ns.map((n) => n.id === id ? { ...n, read: true } : n));
  const addStaff = (s) => setStaff((xs) => [...xs, { id: 's' + (xs.length + 1), active: true, tables: 0, sales: 0, ...s }]);
  const toggleStaff = (id) => setStaff((xs) => xs.map((s) => s.id === id ? { ...s, active: !s.active } : s));

  const store = {
    orders, inventory, chats, notifs, staff, audit, suppliers, settings, role, lang, t, mode, setMode, tab, setTab, switchRole, nav, push, pop, reset, go, updateSettings, setLang,
    getOrder, startOrder, addOrderLine, setOrderLineQty, removeOrderLine, setOrderState, setOrderDiscount, setOrderInfo, sendChat, readChat, markNotifsRead, markNotifRead, addStaff, toggleStaff,
  };

  return (
    <BytesCtx.Provider value={store}>
      <Shell device={tw.device} density={tw.density} />
      <TweaksPanel>
        <TweakSection label="Preview" />
        <TweakSelect label="Device" value={tw.device}
          options={Object.keys(DEVICES).map((k) => ({ value: k, label: DEVICES[k].label }))}
          onChange={(v) => setTweak('device', v)} />
        <TweakRadio label="Density" value={tw.density}
          options={['comfortable', 'cozy', 'compact']}
          onChange={(v) => setTweak('density', v)} />
      </TweaksPanel>
    </BytesCtx.Provider>
  );
}

/* ── responsive shell: device frame + adaptive chrome + panes ── */
function Shell({ device, density }) {
  const b = useBytes();
  const appRef = useRef(null);
  const size = useSize(appRef);
  const dev = DEVICES[device] || DEVICES.phone;
  const w = size.w || (device === 'fill' ? (typeof window !== 'undefined' ? window.innerWidth : 412) : dev.w);
  const mode = modeFor(w);
  const top = b.nav[b.nav.length - 1];
  const pendingCount = b.orders.filter((o) => o.state === 'pending').length;

  const screenEl = (f) => { const S = PUSH_REG[f.screen]; return S ? <S {...f} /> : <div style={{ padding: 20 }}>Unknown screen</div>; };
  const tabEl = (tb) => { const T = TAB_REG[tb]; return T ? <T tabMode /> : null; };

  let body;
  if (mode === 'wide' && MD_TABS.includes(b.tab)) {
    body = (
      <React.Fragment>
        <div className="pane pane--master">{tabEl(b.tab)}</div>
        <div className="pane pane--detail">{top ? screenEl(top) : <EmptyDetail {...EMPTY_DETAIL[b.tab]} />}</div>
      </React.Fragment>
    );
  } else {
    const single = top ? screenEl(top) : tabEl(b.tab);
    body = <div className={'pane pane--single' + (mode !== 'compact' ? ' pane--wide' : '')}>{single}</div>;
  }

  return (
    <LayoutCtx.Provider value={{ mode, width: w }}>
      <DeviceFrame device={device} density={density} appRef={appRef}>
        {dev.frame === 'phone' && <StatusBar />}
        <NavRail role={b.role} tab={b.tab} setTab={b.setTab} badge={pendingCount} t={b.t} />
        <div className="app-body">{body}</div>
        <div className="app-bottomnav"><TabBar tab={b.tab} setTab={b.setTab} badge={pendingCount} role={b.role} t={b.t} /></div>
      </DeviceFrame>
    </LayoutCtx.Provider>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
