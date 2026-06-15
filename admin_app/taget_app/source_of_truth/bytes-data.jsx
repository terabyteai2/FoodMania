/* ============================================================
   Bytes POS — data (Dhaka casual restaurant, ৳ Taka)
   ============================================================ */

const MENU = [
  // Burgers
  { id:'b1', cat:'Burgers', name:'Beef Smash Burger', desc:'Double patty, cheddar, house sauce', price:380, cost:165, stock:'ok', sold:218, delivery:true, mods:['bsize','baddons'] },
  { id:'b2', cat:'Burgers', name:'Crispy Chicken Burger', desc:'Buttermilk fried, slaw, pickles', price:340, cost:140, stock:'ok', sold:301, delivery:true, mods:['spice','baddons'] },
  { id:'b3', cat:'Burgers', name:'Mushroom Swiss', desc:'Beef, sautéed mushroom, swiss', price:420, cost:185, stock:'low', sold:96, delivery:true, mods:['bsize','baddons'] },

  // Rice & Curry
  { id:'r1', cat:'Rice & Curry', name:'Chicken Biryani', desc:'Basmati, raita, borhani', price:320, cost:120, stock:'ok', sold:512, delivery:true, mods:['portion','rprotein'] },
  { id:'r2', cat:'Rice & Curry', name:'Beef Tehari', desc:'Spiced short-grain, salad', price:300, cost:115, stock:'ok', sold:347, delivery:true, mods:['portion'] },
  { id:'r3', cat:'Rice & Curry', name:'Kacchi Biryani', desc:'Mutton, aloo, signature blend', price:480, cost:230, stock:'ok', sold:289, delivery:true, mods:['portion'] },
  { id:'r4', cat:'Rice & Curry', name:'Vegetable Khichuri', desc:'Lentil rice, fried egg, achar', price:240, cost:80, stock:'ok', sold:134, delivery:true, mods:['portion','rprotein'] },

  // Kebab
  { id:'k1', cat:'Kebab', name:'Chicken Seekh Kebab', desc:'Char-grilled, mint chutney', price:280, cost:110, stock:'ok', sold:176, delivery:true, mods:['kqty'] },
  { id:'k2', cat:'Kebab', name:'Beef Sheek Platter', desc:'Naan, salad, two skewers', price:520, cost:240, stock:'low', sold:88, delivery:true, mods:[] },

  // Sides
  { id:'s1', cat:'Sides', name:'Masala Fries', desc:'Chaat masala, coriander', price:150, cost:45, stock:'ok', sold:402, delivery:true, mods:['dips'] },
  { id:'s2', cat:'Sides', name:'Cheese Naan', desc:'Stone-baked, garlic butter', price:120, cost:38, stock:'ok', sold:233, delivery:true, mods:[] },
  { id:'s3', cat:'Sides', name:'Chicken Wings ×6', desc:'Hot or BBQ glaze', price:260, cost:105, stock:'ok', sold:187, delivery:true, mods:['spice','dips'] },

  // Beverages
  { id:'d1', cat:'Beverages', name:'Borhani', desc:'Spiced yogurt drink', price:80, cost:25, stock:'ok', sold:368, delivery:true, mods:['dsize'] },
  { id:'d2', cat:'Beverages', name:'Lemon Mint', desc:'Fresh lime, mint, soda', price:110, cost:30, stock:'ok', sold:295, delivery:true, mods:['dsize'] },
  { id:'d3', cat:'Beverages', name:'Cold Coffee', desc:'Iced, whipped cream', price:160, cost:55, stock:'ok', sold:214, delivery:true, mods:['dsize'] },
  { id:'d4', cat:'Beverages', name:'Coke 250ml', desc:'Chilled can', price:60, cost:35, stock:'ok', sold:431, delivery:true, mods:[] },

  // Desserts
  { id:'x1', cat:'Desserts', name:'Chocolate Lava Cake', desc:'Warm, vanilla scoop', price:220, cost:75, stock:'ok', sold:148, delivery:true, mods:[] },
  { id:'x2', cat:'Desserts', name:'Mishti Doi', desc:'Caramelised sweet yogurt', price:90, cost:28, stock:'low', sold:121, delivery:false, mods:[] },
];
const CATS = ['Burgers', 'Rice & Curry', 'Kebab', 'Sides', 'Beverages', 'Desserts'];

const MODS = {
  bsize:   { label:'Size', type:'single', req:true, opts:[['reg','Regular',0],['dbl','Make it a double',120]] },
  baddons: { label:'Add-ons', type:'multi', req:false, opts:[['cheese','Extra cheese',40],['egg','Fried egg',40],['bacon','Beef bacon',70],['jal','Jalapeños',30]] },
  spice:   { label:'Spice level', type:'single', req:true, opts:[['mild','Mild',0],['med','Medium',0],['hot','Hot',0],['xhot','Extra hot',0]] },
  portion: { label:'Portion', type:'single', req:true, opts:[['half','Half',0],['full','Full',90]] },
  rprotein:{ label:'Add protein', type:'single', req:false, opts:[['none','None',0],['chick','Chicken',90],['beef','Beef',120],['egg','Egg',40]] },
  kqty:    { label:'Skewers', type:'single', req:true, opts:[['2','2 skewers',0],['4','4 skewers',240]] },
  dips:    { label:'Dips', type:'multi', req:false, opts:[['ranch','Ranch',30],['garlic','Garlic mayo',30],['bbq','BBQ',30]] },
  dsize:   { label:'Size', type:'single', req:true, opts:[['reg','Regular',0],['lg','Large',40]] },
};

let _lid = 1;
function makeLine(item, qty, mods, note) {
  return { lid:'L'+(_lid++), id:item.id, name:item.name, cat:item.cat, base:item.price, qty:qty||1, mods:mods||{}, note:note||'' };
}
function lineUnit(line) {
  let p = line.base;
  for (const g in line.mods) {
    const sel = line.mods[g]; const group = MODS[g]; if (!group) continue;
    const ids = Array.isArray(sel) ? sel : [sel];
    for (const id of ids) { const o = group.opts.find(o => o[0] === id); if (o) p += o[2]; }
  }
  return p;
}
function lineTotal(line) { return lineUnit(line) * line.qty; }
function modSummary(line) {
  const parts = [];
  for (const g in line.mods) {
    const sel = line.mods[g]; const group = MODS[g]; if (!group) continue;
    const ids = Array.isArray(sel) ? sel : [sel];
    for (const id of ids) {
      const o = group.opts.find(o => o[0] === id); if (!o) continue;
      const skip = group.type === 'single' && o[2] === 0 && ['reg','none','half'].includes(id);
      if (!skip || g === 'spice' || g === 'kqty' || g === 'portion') parts.push(o[1]);
    }
  }
  if (line.note) parts.push('“' + line.note + '”');
  return parts.join(' · ');
}

const TABLES = [
  { id:'T1', seats:4 }, { id:'T2', seats:4 }, { id:'T3', seats:2 }, { id:'T4', seats:2 },
  { id:'T5', seats:6 }, { id:'T6', seats:4 }, { id:'T7', seats:4 }, { id:'T8', seats:2 },
  { id:'T9', seats:6 }, { id:'T10', seats:4 }, { id:'T11', seats:2 }, { id:'T12', seats:8 },
];

/* ---- orders: multi-channel, 2 states (pending / accepted) ---- */
function seedOrders() {
  const t = (id, qty, mods) => makeLine(MENU.find(m => m.id === id), qty, mods);
  let n = 2048;
  let sn = 24; // short daily serial — newest first gets the highest
  const mk = (o) => ({ token: ++n, serial: sn--, ...o });
  return [
    mk({ id:'o1', channel:'storefront', type:'delivery', state:'pending', mins:1, customer:'Tahmid Rahman', phone:'01711-203045', addr:'House 12, Road 7, Dhanmondi', table:null,
      lines:[ t('r3',2,{portion:'full'}), t('d1',2,{dsize:'reg'}), t('s2',1,{}) ] }),
    mk({ id:'o2', channel:'chatbot', type:'delivery', state:'pending', mins:3, customer:'Nusrat J.', phone:'01822-771290', addr:'Banani Block C, Flat 4B', table:null,
      lines:[ t('b1',1,{bsize:'dbl',baddons:['cheese']}), t('s1',1,{}), t('d2',1,{dsize:'lg'}) ] }),
    mk({ id:'o3', channel:'qr', type:'dinein', state:'pending', mins:4, customer:'Table 5', phone:null, table:'T5',
      lines:[ t('r1',3,{portion:'full'}), t('k1',1,{kqty:'2'}), t('d1',3,{dsize:'reg'}) ] }),
    mk({ id:'o4', channel:'waiter', type:'dinein', state:'accepted', mins:9, customer:'Table 2', phone:null, table:'T2', server:'Rafiq',
      lines:[ t('b2',2,{spice:'med'}), t('s3',1,{spice:'hot'}), t('d4',2,{}) ] }),
    mk({ id:'o5', channel:'storefront', type:'parcel', state:'accepted', mins:12, customer:'Sadia Karim', phone:'01933-560871', table:null,
      lines:[ t('r2',1,{portion:'full'}), t('x1',1,{}) ] }),
    mk({ id:'o6', channel:'qr', type:'dinein', state:'accepted', mins:18, customer:'Table 9', phone:null, table:'T9',
      lines:[ t('r3',1,{portion:'full'}), t('k2',1,{}), t('s2',2,{}), t('d2',2,{dsize:'reg'}), t('x1',2,{}) ] }),
    mk({ id:'o7', channel:'chatbot', type:'delivery', state:'accepted', mins:22, customer:'Imran H.', phone:'01710-884512', addr:'Mohakhali DOHS, Road 11', table:null,
      lines:[ t('b3',1,{bsize:'reg'}), t('b2',1,{spice:'hot'}), t('s1',2,{}), t('d3',2,{dsize:'reg'}) ] }),
    mk({ id:'o8', channel:'qr', type:'dinein', state:'completed', mins:34, customer:'Table 3', phone:null, table:'T3',
      lines:[ t('r1',2,{portion:'full'}), t('d1',2,{dsize:'reg'}), t('x1',1,{}) ] }),
    mk({ id:'o9', channel:'waiter', type:'dinein', state:'completed', mins:46, customer:'Table 8', phone:null, table:'T8', server:'Rafiq',
      lines:[ t('r3',1,{portion:'full'}), t('k1',1,{kqty:'4'}), t('s2',2,{}), t('d2',3,{dsize:'reg'}) ] }),
    mk({ id:'o10', channel:'storefront', type:'parcel', state:'completed', mins:52, customer:'Faria Hossain', phone:'01612-445098', table:null,
      lines:[ t('b1',2,{bsize:'reg'}), t('s1',1,{}), t('d4',2,{}) ] }),
  ];
}

/* ---- inventory (sorted by movement = sold velocity) ---- */
const UNITS = { kg:'kg', l:'L', pcs:'pcs', pkt:'pkt', btl:'btl' };
function seedInventory() {
  return [
    { id:'i1', name:'Chicken (whole)', cat:'Protein', unit:'kg', qty:24, par:30, cost:230, used7:86, moves:512 },
    { id:'i2', name:'Basmati Rice', cat:'Grains', unit:'kg', qty:62, par:50, cost:140, used7:140, moves:847 },
    { id:'i3', name:'Beef (boneless)', cat:'Protein', unit:'kg', qty:9, par:20, cost:680, used7:54, moves:435 },
    { id:'i4', name:'Burger Buns', cat:'Bakery', unit:'pcs', qty:48, par:120, cost:14, used7:210, moves:415 },
    { id:'i5', name:'Mutton', cat:'Protein', unit:'kg', qty:14, par:15, cost:1050, used7:31, moves:289 },
    { id:'i6', name:'Cheddar Slices', cat:'Dairy', unit:'pkt', qty:6, par:12, cost:320, used7:18, moves:264 },
    { id:'i7', name:'Potatoes', cat:'Produce', unit:'kg', qty:38, par:25, cost:35, used7:44, moves:402 },
    { id:'i8', name:'Yogurt', cat:'Dairy', unit:'l', qty:11, par:15, cost:120, used7:26, moves:368 },
    { id:'i9', name:'Cooking Oil', cat:'Pantry', unit:'l', qty:28, par:30, cost:185, used7:35, moves:330 },
    { id:'i10', name:'Coke Cans 250ml', cat:'Beverage', unit:'pcs', qty:96, par:144, cost:42, used7:180, moves:431 },
    { id:'i11', name:'Onions', cat:'Produce', unit:'kg', qty:19, par:20, cost:55, used7:40, moves:380 },
    { id:'i12', name:'Mozzarella', cat:'Dairy', unit:'kg', qty:4, par:8, cost:720, used7:9, moves:198 },
  ];
}

/* ---- analytics ---- */
const ANALYTICS = {
  today: { revenue: 184600, orders: 312, aov: 592, margin: 0.62, dineRev: 0.41, prevRevenue: 162400 },
  sales7: [142, 158, 121, 176, 198, 241, 184],
  prevSales7: [128, 139, 132, 150, 171, 205, 162],
  sales7Labels: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
  channelMix: [ ['Dine-in', 41, '#99FF47'], ['Delivery', 33, '#3E6FE0'], ['Pickup', 14, '#B0760A'], ['Counter', 12, '#878C79'] ],
  topItems: [
    { name:'Chicken Biryani', cat:'Rice & Curry', qty:512, rev:163840, margin:0.63 },
    { name:'Coke 250ml', cat:'Beverages', qty:431, rev:25860, margin:0.42 },
    { name:'Masala Fries', cat:'Sides', qty:402, rev:60300, margin:0.70 },
    { name:'Borhani', cat:'Beverages', qty:368, rev:29440, margin:0.69 },
    { name:'Beef Tehari', cat:'Rice & Curry', qty:347, rev:104100, margin:0.62 },
    { name:'Kacchi Biryani', cat:'Rice & Curry', qty:289, rev:138720, margin:0.58 },
    { name:'Beef Smash Burger', cat:'Burgers', qty:218, rev:82840, margin:0.57 },
  ],
  peakHours: [4, 8, 14, 22, 38, 64, 71, 48, 30, 52, 88, 96, 70, 34],
  hourLabels: ['11','12','1','2','3','4','5','6','7','8','9','10','11','12'],
  categoryRev: [ ['Rice & Curry', 0.42, 612000], ['Burgers', 0.21, 306000], ['Kebab', 0.14, 204000], ['Beverages', 0.12, 175000], ['Sides', 0.08, 116000], ['Desserts', 0.03, 44000] ],
  dayparts: [ ['Lunch', '11–4 PM', 0.34, 612, 0.61], ['Dinner', '6–10 PM', 0.52, 938, 0.64], ['Late', '10–12 AM', 0.14, 252, 0.58] ],
  paymentMix: [ ['bKash / Nagad', 46, '#99FF47'], ['Cash', 31, '#878C79'], ['Card', 23, '#3E6FE0'] ],
  cohort: { repeat: 0.38, ltv: 1840, newPct: 62, returnPct: 38, freq: 2.3 },
  forecast: { projected: 5180000, target: 5400000, pace: 0.96, eom: 'on track' },
  discounts: { given: 142000, orders: 0.27, marginHit: 0.04 },
  wastage: { cost: 38400, pct: 0.062, topItem: 'Mutton' },
};

window.ANALYTICS_EXT = true;

/* ---- analytics: global filter dimensions (shift / terminal / user) ----
   Shares are fractions of net sales; selecting one scopes every metric
   on the page (same multiplier model as channel/daypart). ---- */
const SHIFTS = ['Morning', 'Evening', 'Night'];
const TERMINALS = ['Counter 1', 'Counter 2'];
const SHIFT_SHARE = { 'Morning': 0.27, 'Evening': 0.53, 'Night': 0.20 };
const TERMINAL_SHARE = { 'Counter 1': 0.58, 'Counter 2': 0.42 };
/* per-staff share of attributed sales (waiters + managers who ring orders) */
const STAFF_SHARE = { 'Sabbir Ahmed': 0.31, 'Tania Akter': 0.24, 'Nadia Islam': 0.27, 'Rakib Hasan': 0.18 };
const ANALYTICS_STAFF = ['Sabbir Ahmed', 'Tania Akter', 'Nadia Islam', 'Rakib Hasan'];

/* Service-type split — Dine-in / Takeaway / Delivery (share of net sales). */
const SERVICE_TYPES = [
  ['Dine-in', 0.46, '#99FF47'],
  ['Delivery', 0.32, '#3E6FE0'],
  ['Takeaway', 0.22, '#B0760A'],
];

/* Accounting waterfall — each ratio is relative to Net Sales (the hero figure).
   grossUp lifts net back to gross sales; the rest are deductions from net. */
const ACCT_RATIOS = {
  grossUp: 1.068,      // net ÷ → gross (discounts ≈ 6.4% of gross)
  serviceCharge: 0.05,
  taxes: 0.05,         // VAT
  customerFee: 0.012,
  deliveryCharge: 0.031,
  prepCost: 0.378,     // COGS / preparation
  wastage: 0.022,
  paymentFees: 0.017,
};
function acctBreakdown(net) {
  const gross = Math.round(net * ACCT_RATIOS.grossUp);
  const discounts = gross - net;
  const serviceCharge = Math.round(net * ACCT_RATIOS.serviceCharge);
  const taxes = Math.round(net * ACCT_RATIOS.taxes);
  const customerFee = Math.round(net * ACCT_RATIOS.customerFee);
  const deliveryCharge = Math.round(net * ACCT_RATIOS.deliveryCharge);
  const prepCost = Math.round(net * ACCT_RATIOS.prepCost);
  const wastage = Math.round(net * ACCT_RATIOS.wastage);
  const paymentFees = Math.round(net * ACCT_RATIOS.paymentFees);
  const grossProfit = net - serviceCharge - taxes - customerFee - deliveryCharge - prepCost - wastage - paymentFees;
  return [
    { k: 'gross', label: 'Gross sales', val: gross, type: 'base' },
    { k: 'discounts', label: 'Discounts', val: -discounts, type: 'sub' },
    { k: 'net', label: 'Net sales', val: net, type: 'total' },
    { k: 'service', label: 'Service charge', val: -serviceCharge, type: 'sub' },
    { k: 'taxes', label: 'Taxes (VAT)', val: -taxes, type: 'sub' },
    { k: 'custfee', label: 'Customer fee', val: -customerFee, type: 'sub' },
    { k: 'delivery', label: 'Delivery charge', val: -deliveryCharge, type: 'sub' },
    { k: 'prep', label: 'Preparation cost', val: -prepCost, type: 'sub' },
    { k: 'wastage', label: 'Wastage', val: -wastage, type: 'sub' },
    { k: 'payfee', label: 'Payment fees', val: -paymentFees, type: 'sub' },
    { k: 'profit', label: 'Gross profit', val: grossProfit, type: 'profit' },
  ];
}

/* Master sales dataset — item rows split across service/channel/shift/staff/
   terminal/daypart so the filtered sales table has real dimensions to slice. */
function buildSalesRows() {
  const channels = ['POS', 'Messenger', 'Website'];
  const services = ['Dine-in', 'Takeaway', 'Delivery'];
  const shifts = ['Morning', 'Evening', 'Night'];
  const terminals = ['Counter 1', 'Counter 2'];
  const dayparts = ['Lunch', 'Dinner', 'Late'];
  const staff = ANALYTICS_STAFF;
  const rows = [];
  let k = 0;
  MENU.forEach((m, mi) => {
    const splits = 2 + (mi % 2); // 2 or 3 rows per item
    let remaining = m.sold;
    for (let s = 0; s < splits; s++) {
      const seed = mi * 7 + s * 3;
      const units = s === splits - 1 ? remaining : Math.max(1, Math.round(m.sold * (s === 0 ? 0.5 : 0.3)));
      remaining -= units;
      if (units <= 0) continue;
      const svc = services[seed % 3];
      const rev = units * m.price;
      const cost = units * m.cost;
      const orders = Math.max(1, Math.round(units / (2 + (seed % 3))));
      rows.push({
        id: 'sr' + (k++),
        name: m.name, cat: m.cat,
        service: svc,
        channel: svc === 'Dine-in' ? 'POS' : channels[(seed + 1) % 3],
        units, orders, rev, cost,
        profit: rev - cost,
        margin: (rev - cost) / rev,
        aov: Math.round(rev / orders),
        shift: shifts[seed % 3],
        staff: staff[seed % staff.length],
        terminal: terminals[seed % 2],
        daypart: svc === 'Delivery' ? dayparts[(seed + 2) % 3] : dayparts[seed % 3],
      });
    }
  });
  return rows;
}

/* ---- Messenger chatbot escalations (manager hand-off) ----
   The Facebook bot auto-answers; when it hits something it can't
   resolve (photo request, delivery quote for a far area, custom
   ask) it pings the manager, who takes over the chat in-app. ---- */
function seedChats() {
  return [
    {
      id: 'c1', name: 'Rumana Akter', handle: 'Messenger', init: 'RA', mins: 2,
      status: 'needs', reason: 'Photo requested', unread: 2,
      messages: [
        { from: 'customer', text: 'Assalamu alaikum, do you deliver to Mohammadpur?', time: '7:31 PM' },
        { from: 'bot', text: 'Walaikum assalam! Yes — we deliver to Mohammadpur. Delivery is ৳60 and takes 35–45 min. What would you like to order?', time: '7:31 PM' },
        { from: 'customer', text: 'Can you show me what the Kacchi Biryani actually looks like? Full plate or half?', time: '7:33 PM' },
        { from: 'system', text: 'Chatbot needs your help — customer asked for a real photo of an item.', time: '7:33 PM' },
      ],
    },
    {
      id: 'c2', name: 'Tanvir Hasan', handle: 'Messenger', init: 'TH', mins: 6,
      status: 'needs', reason: 'Delivery quote', unread: 1,
      messages: [
        { from: 'customer', text: 'Hi, I want 2 Beef Smash Burgers + 1 Borhani delivered to Uttara Sector 11.', time: '7:25 PM' },
        { from: 'bot', text: 'Great choice! That comes to ৳820 for the items. Uttara is outside our standard delivery zone though — let me check the charge for you.', time: '7:25 PM' },
        { from: 'system', text: 'Chatbot needs your help — quote a delivery charge for a distant location (Uttara, ~14 km).', time: '7:26 PM' },
      ],
    },
    {
      id: 'c3', name: 'Sharmin Sultana', handle: 'Messenger', init: 'SS', mins: 24,
      status: 'replied', reason: 'Catering ask', unread: 0,
      messages: [
        { from: 'customer', text: 'Do you take bulk orders? Need 30 plates of biryani for an office event on Friday.', time: '6:58 PM' },
        { from: 'system', text: 'Chatbot handed off — custom catering request.', time: '6:58 PM' },
        { from: 'manager', text: 'Hi Sharmin! Yes, we handle catering. For 30 plates of Chicken Biryani it would be ৳280/plate (10% off bulk). Shall I reserve Friday for you?', time: '7:02 PM' },
        { from: 'customer', text: 'That works. Please reserve it 🙏', time: '7:05 PM' },
      ],
    },
    {
      id: 'c4', name: 'Imran Kabir', handle: 'Messenger', init: 'IK', mins: 51,
      status: 'bot', reason: 'Bot handling', unread: 0,
      messages: [
        { from: 'customer', text: 'What time do you close today?', time: '6:31 PM' },
        { from: 'bot', text: 'We are open until 11:30 PM today. Last delivery order is taken at 10:45 PM. Anything you’d like to order?', time: '6:31 PM' },
        { from: 'customer', text: 'No thanks, just checking 😊', time: '6:32 PM' },
        { from: 'bot', text: 'No problem at all — see you soon! 🌿', time: '6:32 PM' },
      ],
    },
  ];
}

/* ---- notification center ---- */
function seedNotifs() {
  return [
    { id:'n1', type:'pending', title:'New order #25', body:'Delivery · Messenger · ৳640', mins:1, read:false, route:{ tab:'orders' } },
    { id:'n2', type:'escalation', title:'Chatbot needs you', body:'Rumana asked for a Kacchi photo', mins:2, read:false, route:{ screen:'messages' } },
    { id:'n3', type:'stock', title:'Low stock · Beef (boneless)', body:'9 kg left · below par (20 kg)', mins:14, read:false, route:{ tab:'inventory' } },
    { id:'n4', type:'table', title:'Table 7 · seated 1h 12m', body:'Bill not yet printed', mins:22, read:true, route:{ tab:'tables' } },
    { id:'n5', type:'stock', title:'Stockout · Mozzarella', body:'4 kg — runs out by dinner', mins:38, read:true, route:{ tab:'inventory' } },
    { id:'n6', type:'shift', title:'Day-end handover due', body:'Close the 7:00 AM shift report', mins:74, read:true, route:{ screen:'tower' } },
  ];
}

/* ---- staff (role invites) ---- */
function seedStaff() {
  return [
    { id:'s1', name:'Arif Rahman', role:'owner', phone:'01711-100200', init:'AR', active:true, tables:0, sales:0 },
    { id:'s2', name:'Nadia Islam', role:'manager', phone:'01811-330440', init:'NI', active:true, tables:0, sales:0 },
    { id:'s3', name:'Sabbir Ahmed', role:'waiter', phone:'01911-550660', init:'SA', active:true, tables:5, sales:18400 },
    { id:'s4', name:'Tania Akter', role:'waiter', phone:'01611-770880', init:'TA', active:true, tables:3, sales:12600 },
    { id:'s5', name:'Rakib Hasan', role:'waiter', phone:'01511-990100', init:'RH', active:false, tables:0, sales:0 },
  ];
}

/* ---- audit trail (destructive actions, reason-logged) ---- */
function seedAudit() {
  return [
    { id:'a1', action:'void', label:'Voided order #19', who:'Nadia Islam', role:'manager', reason:'Customer cancelled before kitchen', amount:520, mins:18 },
    { id:'a2', action:'discount', label:'Discount override · #22', who:'Arif Rahman', role:'owner', reason:'Regular — loyalty 15%', amount:96, mins:41 },
    { id:'a3', action:'comp', label:'Comped Borhani · #17', who:'Nadia Islam', role:'manager', reason:'Served late, kitchen delay', amount:80, mins:96 },
    { id:'a4', action:'refund', label:'Refund · #11', who:'Arif Rahman', role:'owner', reason:'Wrong item delivered', amount:340, mins:184 },
    { id:'a5', action:'void', label:'Voided item · #9', who:'Sabbir Ahmed', role:'waiter', reason:'Duplicate ring-in', amount:240, mins:240 },
  ];
}

/* ---- settings: delivery areas, discount presets, suppliers ---- */
const DELIVERY_AREAS = [ ['Dhanmondi', 60], ['Mohammadpur', 80], ['Banani', 100], ['Mirpur', 110], ['Uttara', 150], ['Other', 130] ];
const DISCOUNT_PRESETS = [ ['10%', 'pct', 10], ['15%', 'pct', 15], ['20%', 'pct', 20], ['৳50', 'flat', 50], ['৳100', 'flat', 100] ];
const MENU_THEMES = [ ['Lime', '#99FF47', '#14180E'], ['Charcoal', '#1F2318', '#99FF47'], ['Saffron', '#F4A52A', '#1A1206'], ['Berry', '#C2185B', '#FFF0F4'], ['Ocean', '#1C6CB0', '#EAF4FF'], ['Mint', '#1E9E6A', '#F0FFF7'] ];
function seedSuppliers() {
  return [
    { id:'sup1', name:'Kawran Bazar Poultry', items:'Chicken, Eggs', phone:'01712-220330', last:'2 days ago' },
    { id:'sup2', name:'Mohammadpur Rice Traders', items:'Basmati, Chinigura', phone:'01812-440550', last:'5 days ago' },
    { id:'sup3', name:'Dhaka Dairy Co.', items:'Cheese, Yogurt, Milk', phone:'01912-660770', last:'1 day ago' },
    { id:'sup4', name:'Fresh Veg Express', items:'Onions, Potatoes, Produce', phone:'01612-880990', last:'Today' },
  ];
}

/* ---- inventory trends (owner: whole-stockroom health over time) ----
   Read-only series for the "Stock over time" screen. Latest points are
   pinned to the live snapshot (value ৳53,399 · 4 below par · ~3.3d cover)
   so the trend lands exactly where the Stock screen reads today.
   `flow` metrics (usage, stock-in) headline the PERIOD TOTAL; level
   metrics (value, below-par, cover) headline the LATEST point. ---- */
const STOCK_TREND_METRICS = [
  { id:'value',    label:'Stock value',    short:'Value',     kind:'money', flow:false, icon:'box' },
  { id:'usage',    label:'Consumption',    short:'Usage',     kind:'units', flow:true,  icon:'flame' },
  { id:'stockin',  label:'Stock-in spend', short:'Stock-in',  kind:'money', flow:true,  icon:'boxin' },
  { id:'belowpar', label:'Below par',      short:'Below par', kind:'count', flow:false, icon:'warn' },
  { id:'cover',    label:'Days of cover',  short:'Cover',     kind:'days',  flow:false, icon:'clock' },
];

function _srng(seed){ let s=(seed>>>0)||1; return ()=>{ s=(Math.imul(s,1664525)+1013904223)>>>0; return s/4294967296; }; }

/* 30 daily points, oldest→newest, last pinned to live snapshot */
const _stk30 = (() => {
  const N=30, value=[], usage=[], stockin=[], belowpar=[], cover=[];
  const r=_srng(20240607);
  for (let i=0;i<N;i++){
    const wd=(i+3)%7, weekend=wd===5||wd===6;
    value.push(Math.round(49800 + 3700*Math.sin((i+2)/4.6) + (r()-0.5)*2600));
    usage.push(Math.round(110 + (weekend?40:0) + 22*Math.sin(i/3) + (r()-0.5)*20));
    const deliv = i%4===1;
    stockin.push(deliv ? Math.round(17000 + r()*27000) : Math.round(r()*2100));
    belowpar.push(Math.max(1, Math.min(7, Math.round(3.7 + 1.5*Math.sin(i/3.4) + (r()-0.5)*1.5))));
    cover.push(Math.round((3.4 + 0.7*Math.sin((i+1)/4) + (r()-0.5)*0.7)*10)/10);
  }
  value[N-1]=53399; usage[N-1]=126; belowpar[N-1]=4; cover[N-1]=3.3;
  if (stockin[N-2] < 5000) stockin[N-2]=24800;
  return { value, usage, stockin, belowpar, cover };
})();

/* intraday (today): per-hour flow for usage/stock-in, level snapshots otherwise */
const _stkToday = {
  labels:['11a','12','1','2','3','4','5','6','7'],
  value:   [57600,57100,56300,55500,54800,54200,53800,53500,53399],
  usage:   [6,16,19,14,15,18,16,14,8],
  stockin: [0,38600,0,0,0,0,0,0,0],
  belowpar:[2,2,3,3,3,4,4,4,4],
  cover:   [4.1,4.0,3.8,3.7,3.5,3.4,3.4,3.3,3.3],
};

/* 12 weekly points for the Custom horizon, oldest→newest (flow = per-week) */
const _stkWeek = (() => {
  const N=12, value=[], usage=[], stockin=[], belowpar=[], cover=[];
  const r=_srng(515);
  for (let i=0;i<N;i++){
    value.push(Math.round(49500 + 3200*Math.sin(i/2.4) + (r()-0.5)*3000));
    usage.push(Math.round(820 + 90*Math.sin(i/2) + (r()-0.5)*120));
    stockin.push(Math.round(96000 + 30000*Math.sin(i/2.6) + (r()-0.5)*40000));
    belowpar.push(Math.max(1, Math.min(7, Math.round(3.8 + 1.2*Math.sin(i/2.2) + (r()-0.5)*1.4))));
    cover.push(Math.round((3.4 + 0.6*Math.sin(i/2.5) + (r()-0.5)*0.6)*10)/10);
  }
  value[N-1]=53399; usage[N-1]=873; belowpar[N-1]=4; cover[N-1]=3.3;
  return { value, usage, stockin, belowpar, cover };
})();

const STOCK_TREND_CUSTOM = [ ['4w','Last 4 weeks',4], ['8w','Last 8 weeks',8], ['12w','Last 12 weeks',12], ['q','This quarter',12] ];

function _stkStats(vals){
  const peak=Math.max(...vals), low=Math.min(...vals);
  const total=vals.reduce((s,v)=>s+v,0), avg=total/vals.length;
  return { peak, low, total, avg };
}

function stockTrend(metric, tf, customKey){
  let vals, labels;
  if (tf==='today'){ vals=_stkToday[metric]; labels=_stkToday.labels; }
  else if (tf==='week'){ vals=_stk30[metric].slice(-7); labels=['Mon','Tue','Wed','Thu','Fri','Sat','Sun']; }
  else if (tf==='custom'){
    const n=(STOCK_TREND_CUSTOM.find(c=>c[0]===customKey)||STOCK_TREND_CUSTOM[2])[2];
    vals=_stkWeek[metric].slice(-n);
    const L=vals.length, mid=Math.floor(L/2);
    labels=vals.map((_,i)=> i===1 ? (n+'w') : (i===mid ? (Math.round(n/2)+'w') : (i===L-2 ? 'now' : '')));
  } else {
    vals=_stk30[metric];
    labels=vals.map((_,i)=> i===2?'30d':(i===11?'20d':(i===20?'10d':(i===27?'now':''))));
  }
  const st=_stkStats(vals);
  const deliveries = metric==='stockin' ? vals.filter(v=>v>3000).length : 0;
  const def = STOCK_TREND_METRICS.find(m=>m.id===metric);
  const headline = def.flow ? st.total : vals[vals.length-1];
  return { vals, labels, ...st, deliveries, headline, def };
}

Object.assign(window, { MENU, CATS, MODS, TABLES, UNITS, makeLine, lineUnit, lineTotal, modSummary, seedOrders, seedInventory, ANALYTICS, seedChats, seedNotifs, seedStaff, seedAudit, seedSuppliers, DELIVERY_AREAS, DISCOUNT_PRESETS, MENU_THEMES, SHIFTS, TERMINALS, SHIFT_SHARE, TERMINAL_SHARE, STAFF_SHARE, ANALYTICS_STAFF, SERVICE_TYPES, ACCT_RATIOS, acctBreakdown, buildSalesRows, STOCK_TREND_METRICS, STOCK_TREND_CUSTOM, stockTrend });
