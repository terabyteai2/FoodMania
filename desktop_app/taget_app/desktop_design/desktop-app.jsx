/* ============================================================
   QuickBytes Desktop — root store, routing, render.
   One counter-station surface scaled to a 1280×800 terminal.
   ============================================================ */
const { useState: dAppState, useMemo: dAppMemo, useCallback: dAppCb } = React;

const DeskCtx = React.createContext(null);
function useDesk() { return React.useContext(DeskCtx); }
window.useDesk = useDesk;

const blankDraft = () => ({ type: 'dinein', table: null, customer: '', phone: '', addr: '', area: null, charge: 0, lines: [], discount: null });

function DeskApp() {
  const [role, setRoleRaw] = dAppState('manager');
  const [lang, setLang] = dAppState('en');
  const [tab, setTab] = dAppState('register');
  const [pop, setPop] = dAppState(null);
  const [msgOpen, setMsgOpen] = dAppState(false);

  const [orders, setOrders] = dAppState(() => seedOrders());
  const [inventory] = dAppState(() => seedInventory());
  const [chats, setChats] = dAppState(() => seedChats());
  const [notifs, setNotifs] = dAppState(() => seedNotifs());
  const [staff] = dAppState(() => seedStaff());

  const [draft, setDraft] = dAppState(blankDraft);
  const [modItem, setModItem] = dAppState(null);
  const [pay, setPay] = dAppState(false);
  const [success, setSuccess] = dAppState(null);
  const [selOrder, setSelOrder] = dAppState(null);
  const [toastMsg, setToastMsg] = dAppState(null);
  const tokenRef = React.useRef(2061);

  const toast = dAppCb((m) => { setToastMsg(m); clearTimeout(window.__dkT); window.__dkT = setTimeout(() => setToastMsg(null), 1900); }, []);

  /* ---- derived ---- */
  const pendingCount = orders.filter((o) => o.state === 'pending').length;
  const occupiedTables = dAppMemo(() => {
    const m = {};
    orders.forEach((o) => { if (o.type === 'dinein' && o.table && o.state !== 'completed') m[o.table] = o; });
    return m;
  }, [orders]);

  /* ---- role / nav ---- */
  const setRole = (r) => {
    setRoleRaw(r);
    const allowed = (DESK_NAV[r] || []).map((x) => x[0]);
    if (!allowed.includes(tab)) setTab('register');
    setPop(null);
  };

  /* ---- draft mutations ---- */
  const mergeLine = (lines, line) => {
    if (Object.keys(line.mods).length === 0 && !line.note) {
      const idx = lines.findIndex((l) => l.id === line.id && Object.keys(l.mods).length === 0 && !l.note);
      if (idx >= 0) { const copy = lines.slice(); copy[idx] = { ...copy[idx], qty: copy[idx].qty + line.qty }; return copy; }
    }
    return [...lines, line];
  };
  const pickItem = (item) => { if (item.mods && item.mods.length > 0) setModItem(item); else setDraft((d) => ({ ...d, lines: mergeLine(d.lines, makeLine(item, 1, {}, '')) })); };
  const commitMod = (line) => { setDraft((d) => ({ ...d, lines: mergeLine(d.lines, line) })); setModItem(null); };
  const setQty = (lid, q) => setDraft((d) => ({ ...d, lines: q < 1 ? d.lines.filter((l) => l.lid !== lid) : d.lines.map((l) => l.lid === lid ? { ...l, qty: q } : l) }));
  const removeLine = (lid) => setDraft((d) => ({ ...d, lines: d.lines.filter((l) => l.lid !== lid) }));
  const setType = (type) => setDraft((d) => ({ ...d, type, table: type === 'dinein' ? d.table : null, area: type === 'delivery' ? d.area : null, charge: type === 'delivery' ? d.charge : 0 }));
  const setTable = (table) => setDraft((d) => ({ ...d, table }));
  const setArea = (area, charge) => setDraft((d) => ({ ...d, area, charge }));
  const setDraftField = (k, v) => setDraft((d) => ({ ...d, [k]: v }));
  const setDiscount = (disc) => setDraft((d) => ({ ...d, discount: disc }));
  const clearDraft = () => setDraft(blankDraft());

  const startDineIn = (tableId) => { setDraft({ ...blankDraft(), type: 'dinein', table: tableId }); setTab('register'); };
  const startType = (type) => { setDraft({ ...blankDraft(), type }); setTab('register'); };

  /* ---- payment / success ---- */
  const openPay = () => setPay(true);
  const closePay = () => setPay(false);
  const confirmPay = (method, change) => {
    const t = deskTotals(draft);
    const token = ++tokenRef.current;
    const typeLabel = draft.type === 'dinein' ? (draft.table ? 'Table ' + draft.table.replace('T', '') : 'Dine-in') : draft.type === 'parcel' ? 'Parcel' : 'Delivery';
    const methodLabel = method === 'cash' ? 'Cash' : method === 'card' ? 'Card' : 'bKash / Nagad';
    const newOrd = {
      id: 'd' + Date.now(), serial: 25 + orders.filter((o) => o.id.startsWith('d')).length, token,
      channel: 'counter', type: draft.type, state: 'completed', mins: 0,
      customer: draft.customer || typeLabel, phone: draft.phone || null, addr: draft.addr || null, area: draft.area || null,
      charge: t.charge, table: draft.table, discount: t.disc, lines: draft.lines,
    };
    setOrders((o) => [newOrd, ...o]);
    setPay(false);
    setSuccess({ token, total: t.total, count: t.count, typeLabel, methodLabel, change: change || 0 });
  };
  const newOrder = () => { setSuccess(null); setDraft(blankDraft()); };
  const finishSuccess = () => { setSuccess(null); setDraft(blankDraft()); };

  /* ---- order queue ops ---- */
  const acceptOrder = (id) => { setOrders((os) => os.map((o) => o.id === id ? { ...o, state: 'accepted' } : o)); toast(lang === 'bn' ? 'গ্রহণ করা হয়েছে · KOT প্রিন্ট' : 'Accepted · KOT printed'); };
  const rejectOrder = (id) => { setOrders((os) => os.filter((o) => o.id !== id)); setSelOrder(null); toast(lang === 'bn' ? 'অর্ডার বাতিল' : 'Order rejected'); };
  const completeOrder = (id) => { setOrders((os) => os.map((o) => o.id === id ? { ...o, state: 'completed' } : o)); toast(lang === 'bn' ? 'বিল প্রিন্ট · সম্পন্ন' : 'Bill printed · completed'); };
  const openTableOrder = (id) => { setSelOrder(id); setTab('orders'); };

  /* ---- notifications ---- */
  const markAllRead = () => setNotifs((ns) => ns.map((n) => ({ ...n, read: true })));
  const openNotif = (n) => {
    setNotifs((ns) => ns.map((x) => x.id === n.id ? { ...x, read: true } : x));
    setPop(null);
    if (n.route.screen === 'messages') setMsgOpen(true);
    else if (n.route.screen === 'tower') setTab('tower');
    else if (n.route.tab) setTab(n.route.tab);
  };

  /* ---- messages ---- */
  const nowTime = () => { const d = new Date(); let h = d.getHours(); const ap = h >= 12 ? 'PM' : 'AM'; h = h % 12 || 12; return h + ':' + ('' + d.getMinutes()).padStart(2, '0') + ' ' + ap; };
  const sendReply = (chatId, text, kind) => setChats((cs) => cs.map((c) => c.id === chatId ? { ...c, status: 'replied', unread: 0, messages: [...c.messages, { from: 'manager', text, time: nowTime(), kind }] } : c));
  const handBack = (chatId) => setChats((cs) => cs.map((c) => c.id === chatId ? { ...c, status: 'bot', unread: 0, messages: [...c.messages, { from: 'system', text: lang === 'bn' ? 'চ্যাট বটের কাছে ফেরত দেওয়া হয়েছে' : 'Chat handed back to the bot.', time: nowTime() }] } : c));

  const store = {
    role, lang, tab, pop, msgOpen, orders, inventory, chats, notifs, staff,
    draft, modItem, pay, success, selOrder, toastMsg,
    pendingCount, occupiedTables,
    setRole, setLang, setTab, setPop, setMsgOpen, setSelOrder, toast,
    pickItem, commitMod, closeMod: () => setModItem(null), setQty, removeLine, setType, setTable, setArea, setDraftField, setDiscount, clearDraft,
    startDineIn, startType, openPay, closePay, confirmPay, newOrder, finishSuccess,
    acceptOrder, rejectOrder, completeOrder, openTableOrder,
    markAllRead, openNotif, sendReply, handBack,
  };

  const allowed = (DESK_NAV[role] || []).map((x) => x[0]);
  const active = allowed.includes(tab) ? tab : 'register';

  let screen;
  if (active === 'register') screen = (
    <div className="dk-main">
      <DeskHead title={lang === 'bn' ? 'রেজিস্টার' : 'Register'} sub={lang === 'bn' ? 'কাউন্টার · স্পাইস গার্ডেন' : 'Counter · Spice Garden, Dhanmondi'}
        right={<div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 13, color: 'var(--muted)', fontWeight: 600 }} className="tab">Tue 9 Jun · 7:42 PM</span>
          <button className="btn btn-ghost btn-sm" onClick={() => clearDraft()}><Icon name="refresh" size={16} />{lang === 'bn' ? 'রিসেট' : 'Reset'}</button>
        </div>} />
      <Register />
    </div>
  );
  else if (active === 'orders') screen = <OrdersScreen />;
  else if (active === 'tables') screen = <TablesScreen />;
  else if (active === 'inventory') screen = <StockScreen />;
  else screen = <DashboardScreen />;

  return (
    <DeskCtx.Provider value={store}>
      <Frame>
        <NavRail />
        {screen}
        {msgOpen && <MessagesOverlay />}
        {toastMsg && (
          <div className="dk-fadein" style={{ position: 'absolute', bottom: 22, left: '50%', transform: 'translateX(-50%)', zIndex: 80, background: 'var(--ink)', color: '#fff', borderRadius: 'var(--r-md)', padding: '11px 18px', fontSize: 14, fontWeight: 600, boxShadow: 'var(--e3)', display: 'flex', alignItems: 'center', gap: 8 }}>
            <Icon name="check2" size={17} color="var(--accent)" />{toastMsg}
          </div>
        )}
      </Frame>
    </DeskCtx.Provider>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<DeskApp />);
