// Terafoods · Design Canvas composition

const PW = TF.W + TF.FRAME_PAD * 2;
const PH = TF.H + TF.FRAME_PAD * 2;

const SystemNotes = () => (
  <div style={{
    width: 760, padding: 24, background: TFC.paper,
    border: `0.5px solid ${TFC.border}`, borderRadius: 14,
    fontFamily: 'Inter, sans-serif', color: TFC.text,
  }}>
    <div style={{ fontSize: 22, fontWeight: 500, letterSpacing: -0.3 }}>What changed</div>
    <div style={{ fontSize: 13, color: TFC.textSec, marginTop: 4, lineHeight: 1.5 }}>
      Hi-fi pass on top of the master design prompt. Same paper-white + amber, two weights only, bilingual labels, 44px tap targets.
    </div>

    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 26, marginTop: 18 }}>
      <div>
        <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 8 }}>Onboarding · 4 steps</div>
        <ol style={{ fontSize: 12.5, lineHeight: 1.7, paddingLeft: 18, margin: 0, color: TFC.textSec }}>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Basics</b> — name + restaurant + type chips. Required.</li>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Menu</b> — AI scan as the hero (dark card, ~30s). Manual fallback below. Review screen flags low-confidence items in red.</li>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Printer</b> — NEW. Bluetooth scan with radar pulse, found list (with signal bars), connected confirmation + test-print. Skippable.</li>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Online page</b> — URL handle, hero video slot, photo grid. Optional.</li>
        </ol>
        <div style={{ fontSize: 12, color: TFC.textSec, marginTop: 6, lineHeight: 1.5 }}>
          Done screen shows a 3-line summary (menu, printer, online) before opening the dashboard.
        </div>

        <div style={{ fontSize: 14, fontWeight: 500, marginTop: 18, marginBottom: 8 }}>Orders</div>
        <ul style={{ fontSize: 12.5, lineHeight: 1.7, paddingLeft: 18, margin: 0, color: TFC.textSec }}>
          <li>Two tabs only: <b style={{ color: TFC.text, fontWeight: 500 }}>Pending</b> (the action) and <b style={{ color: TFC.text, fontWeight: 500 }}>Accepted</b> (in kitchen). Pill counter on each.</li>
          <li>Each card carries the source colour rail — amber for pending, green for in-kitchen, red for late.</li>
          <li>Single primary action per row — <b style={{ color: TFC.text, fontWeight: 500 }}>Accept · send to kitchen</b> on pending (auto-prints) or <b style={{ color: TFC.text, fontWeight: 500 }}>Served</b> on accepted.</li>
          <li>56px yellow FAB bottom-right, sticky above bottom nav, with shadow halo.</li>
          <li>Bottom nav: 5 items, active = yellow pip below the icon (not filled icon).</li>
        </ul>

        <div style={{ fontSize: 14, fontWeight: 500, marginTop: 18, marginBottom: 8 }}>Notifications</div>
        <ul style={{ fontSize: 12.5, lineHeight: 1.7, paddingLeft: 18, margin: 0, color: TFC.textSec }}>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Inbox</b> — grouped Today / Earlier, filter chips, inline accept/view buttons per row.</li>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>In-app toast</b> — dark banner pops over Orders with a 30s auto-accept countdown. Big enough to act on with thumb.</li>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Lockscreen push</b> — full Android-style with quick actions baked in (Accept / View / Snooze).</li>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Settings</b> — Don't-disturb hours, but new online orders always ring through.</li>
        </ul>
      </div>

      <div>
        <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 8 }}>Add-order · 3 steps</div>
        <ol style={{ fontSize: 12.5, lineHeight: 1.7, paddingLeft: 18, margin: 0, color: TFC.textSec }}>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Source + table</b> — 3-tile picker (Dine-in / Takeaway / Delivery). For dine-in: 4×3 table grid (busy vs free), then covers (1–6, 7+).</li>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Items</b> — search + category chips + tap-to-add cards. Once in cart, qty stepper replaces the + button. Dark sticky cart footer with running total.</li>
          <li><b style={{ color: TFC.text, fontWeight: 500 }}>Review</b> — items, kitchen note, totals (with discount/charges), payment method (Cash / Card / bKash / Pay later). Two CTAs: Print only or Send to kitchen.</li>
        </ol>
        <div style={{ fontSize: 12, color: TFC.textSec, marginTop: 6, lineHeight: 1.5 }}>
          Confirmation screen shows a mini-receipt preview and three follow-ups: Reprint, Share, or Take another order.
        </div>

        <div style={{ fontSize: 14, fontWeight: 500, marginTop: 18, marginBottom: 8 }}>Tokens used (from design prompt)</div>
        {[
          ['Primary', '#F5C127', 'CTA · active states · pip'],
          ['Dark anchor', '#1C1A17', 'header bar · dark buttons'],
          ['Background', '#F7F4EE', 'app bg'],
          ['Card surface', '#FFFFFF + 0.5px #E8E4DC', 'all cards'],
          ['Body / Sec', '#1C1A17 / #888780', 'text'],
          ['Green', '#3D7A5A on #EAF4EE', 'positive · accepted'],
          ['Error', '#A32D2D on #FCEBEB', 'late · low stock'],
        ].map(([n, hex, note]) => (
          <div key={n} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '3px 0', fontSize: 12 }}>
            <div style={{
              width: 22, height: 22, borderRadius: 4,
              background: hex.split(' ')[0], border: `0.5px solid ${TFC.border}`,
            }} />
            <div style={{ width: 90 }}>{n}</div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', color: TFC.textSec, fontSize: 11, flex: 1 }}>{hex}</div>
            <div style={{ color: TFC.textSec, fontSize: 11 }}>{note}</div>
          </div>
        ))}

        <div style={{ fontSize: 14, fontWeight: 500, marginTop: 18, marginBottom: 8 }}>Open questions</div>
        <ol style={{ fontSize: 12.5, lineHeight: 1.7, paddingLeft: 18, margin: 0, color: TFC.textSec }}>
          <li>Auto-accept online orders after 30s — keep, or always require manual tap?</li>
          <li>Printer step required, or skip-by-default with a "Pair printer" card on the dashboard until done?</li>
          <li>Pay-later (Bakir khata) — model as a payment method like above, or separate flow?</li>
          <li>Covers (number of people) — required for dine-in or always optional?</li>
        </ol>
      </div>
    </div>
  </div>
);

// --- Tweaks ---------------------------------------------------------------
// Three expressive controls that reshape the design's feel:
//   • Menu items: List vs Grid (rewires the add-order step 2)
//   • Brand palette: Amber / Chili / Saffron (whole-app identity)
//   • Mood: Warm paper / Crisp white (app bg + card border feel)

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "menu_layout": "grid",
  "brand": "amber",
  "mood": "warm",
  "orders_accent": "teal"
}/*EDITMODE-END*/;

const BRAND_PALETTES = {
  amber:   { primary: '#F5C127', primarySoft: '#FEF1C5', primaryWash: '#FFF9E0' },
  chili:   { primary: '#D7472D', primarySoft: '#F8D9D2', primaryWash: '#FBEDE9' },
  saffron: { primary: '#E68A1A', primarySoft: '#FBE3C2', primaryWash: '#FCF1DE' },
};
const MOOD_BG = {
  warm:  { bg: '#F7F4EE', border: '#E8E4DC' },
  crisp: { bg: '#FFFFFF', border: '#E3E1DC' },
};

function applyTweaks(t) {
  const b = BRAND_PALETTES[t.brand] || BRAND_PALETTES.amber;
  TFC.primary = b.primary;
  TFC.primarySoft = b.primarySoft;
  TFC.primaryWash = b.primaryWash;
  const m = MOOD_BG[t.mood] || MOOD_BG.warm;
  TFC.bg = m.bg;
  TFC.border = m.border;
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  applyTweaks(t);

  return (
    <TfTweaksContext.Provider value={t}>
      <DesignCanvasTree />
      <TweaksPanel>
        <TweakSection label="Layout" />
        <TweakRadio label="Menu items" value={t.menu_layout}
          options={['list', 'grid']}
          onChange={(v) => setTweak('menu_layout', v)} />

        <TweakSection label="Identity" />
        <TweakColor label="Brand" value={BRAND_PALETTES[t.brand].primary}
          options={[BRAND_PALETTES.amber.primary, BRAND_PALETTES.chili.primary, BRAND_PALETTES.saffron.primary]}
          onChange={(hex) => {
            const name = Object.keys(BRAND_PALETTES).find(k => BRAND_PALETTES[k].primary === hex) || 'amber';
            setTweak('brand', name);
          }} />

        <TweakSection label="Mood" />
        <TweakRadio label="Background" value={t.mood}
          options={['warm', 'crisp']}
          onChange={(v) => setTweak('mood', v)} />

        <TweakSection label="Orders · accent (per-outlet)" />
        <TweakColor label="Accent" value={V2.ACCENTS[t.orders_accent || 'teal'].hex}
          options={Object.values(V2.ACCENTS).map(a => a.hex)}
          onChange={(hex) => {
            const name = Object.keys(V2.ACCENTS).find(k => V2.ACCENTS[k].hex === hex) || 'teal';
            setTweak('orders_accent', name);
          }} />
      </TweaksPanel>
    </TfTweaksContext.Provider>
  );
}

function DesignCanvasTree() {
  const t = useTfTweaks();
  return (
    <DesignCanvas>
      <DCSection id="dashboard" title="Manager dashboard · by tier"
        subtitle="Manage Mode home, one tier per artboard. Features APPEAR as the business grows — T1 is one card + buttons; T4 is a fleet console. Each screen scrolls.">
        <DCArtboard id="dash-t1" label="Tier 1 · Counter — juice bar (Lebu Fresh)" width={PW} height={PH}><Phone><Dash_T1_Counter /></Phone></DCArtboard>
        <DCArtboard id="dash-t2" label="Tier 2 · Small dine-in — café (Cha Ghor)" width={PW} height={PH}><Phone><Dash_T2_Dinein /></Phone></DCArtboard>
        <DCArtboard id="dash-t3" label="Tier 3 · Full-service — restaurant (Spice Garden)" width={PW} height={PH}><Phone><Dash_T3_Full /></Phone></DCArtboard>
        <DCArtboard id="dash-t4" label="Tier 4 · Multi-unit — fleet ops (5 outlets)" width={PW} height={PH}><Phone><Dash_T4_Fleet /></Phone></DCArtboard>
      </DCSection>



      <DCSection id="dashboard-review" title="Dashboard · Review tab (owner)"
        subtitle="The retrospective view: today vs yesterday, where money came from, what's actually making margin, who's carrying the floor. Three positions of the complexity dial — Standard appears when there's a floor to watch; Advanced adds margin + staff; Enterprise pivots to fleet comparison.">
        <DCArtboard id="rev-std" label="STANDARD · small dine-in (Cha Ghor)" width={PW} height={PH}><Phone><Review_Standard /></Phone></DCArtboard>
        <DCArtboard id="rev-adv" label="ADVANCED · full-service (Spice Garden)" width={PW} height={PH}><Phone><Review_Advanced /></Phone></DCArtboard>
        <DCArtboard id="rev-ent" label="ENTERPRISE · fleet (5 outlets)" width={PW} height={PH}><Phone><Review_Enterprise /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="inventory-tier" title="Inventory · home by tier"
        subtitle="Same complexity dial as the dashboard. P1 is two KPIs + top movers + actions; P2 adds category filter + a full item list; P3 layers food-cost %, 7-day reorder suggestions, daily reconciliation variance, and menu-item costing.">
        <DCArtboard id="inv-simple"   label="SIMPLE · juice bar (Lebu Fresh)"          width={PW} height={PH}><Phone><Inv_Simple /></Phone></DCArtboard>
        <DCArtboard id="inv-standard" label="STANDARD · small dine-in (Cha Ghor)"      width={PW} height={PH}><Phone><Inv_Standard /></Phone></DCArtboard>
        <DCArtboard id="inv-advanced" label="ADVANCED · full-service (Spice Garden)"   width={PW} height={PH}><Phone><Inv_Advanced /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="inventory" title="Inventory · 6 screens"
        subtitle="Home → Item → Add → Stock-in → End-of-day count → Daily report. Same DASH tokens as the dashboard. Burnt orange reserved for CTAs (≤ 5% per viewport); signal colors do the talking on data.">
        <DCArtboard id="inv-1" label="1 · Inventory home" width={PW} height={PH}><Phone><Inv1_Home /></Phone></DCArtboard>
        <DCArtboard id="inv-2" label="2 · Item detail · Rice" width={PW} height={PH}><Phone><Inv2_Detail /></Phone></DCArtboard>
        <DCArtboard id="inv-3" label="3 · Add item" width={PW} height={PH}><Phone><Inv3_Add /></Phone></DCArtboard>
        <DCArtboard id="inv-stockin" label="4 · Stock-in · AI Scan" width={PW} height={PH}><Phone><Inv_StockIn /></Phone></DCArtboard>
        <DCArtboard id="inv-4" label="5 · End-of-day count" width={PW} height={PH}><Phone><Inv4_Count /></Phone></DCArtboard>
        <DCArtboard id="inv-5" label="6 · Daily report" width={PW} height={PH}><Phone><Inv5_Report /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="onboarding" title="Onboarding · 4 steps"
        subtitle="Picks up after OTP. Steps 2-4 skippable. Bluetooth printer added in step 3.">
        <DCArtboard id="ob-1" label="1 · Restaurant name" width={PW} height={PH}><Phone><OB1_Restaurant /></Phone></DCArtboard>
        <DCArtboard id="ob-1b" label="1 · Owner name (menu auto-setup)" width={PW} height={PH}><Phone><OB2_Owner /></Phone></DCArtboard>
        <DCArtboard id="ob-2a" label="2 · Menu · pitch (AI scan)" width={PW} height={PH}><Phone><OB2a_MenuPitch /></Phone></DCArtboard>
        <DCArtboard id="ob-2b" label="2 · Menu · scanning" width={PW} height={PH}><Phone><OB2b_Scanning /></Phone></DCArtboard>
        <DCArtboard id="ob-2c" label="2 · Menu · review" width={PW} height={PH}><Phone><OB2c_Review /></Phone></DCArtboard>
        <DCArtboard id="ob-3a" label="3 · Printer · intro" width={PW} height={PH}><Phone><OB3a_PrinterIntro /></Phone></DCArtboard>
        <DCArtboard id="ob-3b" label="3 · Printer · searching" width={PW} height={PH}><Phone><OB3b_PrinterSearch /></Phone></DCArtboard>
        <DCArtboard id="ob-3c" label="3 · Printer · connected + test" width={PW} height={PH}><Phone><OB3c_PrinterConnected /></Phone></DCArtboard>
        <DCArtboard id="ob-4" label="4 · Online page (optional)" width={PW} height={PH}><Phone><OB4_Online /></Phone></DCArtboard>
        <DCArtboard id="ob-done" label="Done → dashboard" width={PW} height={PH}><Phone><OBDone /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="orders" title="Orders · migrated to neutral base + accent"
        subtitle={`Layouts unchanged — tokens replaced per the new design system. Neutral cool-gray base (fixed, all tiers). Accent picked per outlet during onboarding (currently “${V2.ACCENTS[t.orders_accent || 'teal'].label}” · change in Tweaks). Late = urgent (#C2410C), never red. Card shadows → 1px borders; FAB keeps a single 6px-blur shadow.`}>
        <DCArtboard id="ord-t1" label="Tier 1 · Counter — cash sales log (Lebu Fresh)" width={PW} height={PH}>
          <WithAccentV2 accent={t.orders_accent}><Phone><Orders_T1_V2 /></Phone></WithAccentV2>
        </DCArtboard>
        <DCArtboard id="ord-t2" label="Tier 2 · Dine-in — New / In-kitchen (Cha Ghor)" width={PW} height={PH}>
          <WithAccentV2 accent={t.orders_accent}><Phone><Orders_T2_V2 /></Phone></WithAccentV2>
        </DCArtboard>
        <DCArtboard id="ord-t3" label="Tier 3 · Full-service — pending + online (Spice Garden)" width={PW} height={PH}>
          <WithAccentV2 accent={t.orders_accent}><Phone><Orders_Pending_V2 /></Phone></WithAccentV2>
        </DCArtboard>
        <DCArtboard id="ord-t3b" label="Tier 3 · accepted + LATE tracking" width={PW} height={PH}>
          <WithAccentV2 accent={t.orders_accent}><Phone><Orders_Accepted_V2 /></Phone></WithAccentV2>
        </DCArtboard>
        <DCArtboard id="ord-t4" label="Tier 4 · Multi-unit — fleet live feed (5 outlets)" width={PW} height={PH}>
          <WithAccentV2 accent={t.orders_accent}><Phone><Orders_T4_V2 /></Phone></WithAccentV2>
        </DCArtboard>
        <DCArtboard id="ord-e" label="Empty state" width={PW} height={PH}>
          <WithAccentV2 accent={t.orders_accent}><Phone><Orders_Empty_V2 /></Phone></WithAccentV2>
        </DCArtboard>
      </DCSection>

      <DCSection id="orders-accents" title="Orders · the six accent options"
        subtitle="Same T3 “Pending” screen, swapped through each owner-pickable accent. Neutral base, signal colors, layout: identical.">
        {Object.keys(V2.ACCENTS).map((k) => (
          <DCArtboard key={k} id={`ord-acc-${k}`} label={`${V2.ACCENTS[k].label} · ${V2.ACCENTS[k].sub}`} width={PW} height={PH}>
            <WithAccentV2 accent={k}><Phone><Orders_Pending_V2 /></Phone></WithAccentV2>
          </DCArtboard>
        ))}
      </DCSection>

      <DCSection id="orders-tokens" title="Orders · token migration map"
        subtitle="What replaces what. Hand this to the developer.">
        <DCArtboard id="ord-tokens" label="Token map + enforcement" width={808} height={920}>
          <OrdersV2Notes />
        </DCArtboard>
      </DCSection>

      <DCSection id="foh-tier" title="FOH · order entry by tier"
        subtitle="The act of taking an order. P1 is counter-only — direct item entry, receipt at the end. P2 adds table selection, a floor-map strip, and waiter attribution before sending to kitchen. P3 layers per-item modifiers, dietary tags, kitchen-sent markers per line, and tracked adjustments (loyalty discount + comped item with reason).">
        <DCArtboard id="foh-simple"   label="SIMPLE · counter (Lebu Fresh)"          width={PW} height={PH}><Phone><FOH_Simple /></Phone></DCArtboard>
        <DCArtboard id="foh-standard" label="STANDARD · dine-in (Cha Ghor)"          width={PW} height={PH}><Phone><FOH_Standard /></Phone></DCArtboard>
        <DCArtboard id="foh-advanced" label="ADVANCED · full-service (Spice Garden)" width={PW} height={PH}><Phone><FOH_Advanced /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="addorder" title="Add order · 3 steps"
        subtitle="Waiter/manager flow. Source → items → review.">
        <DCArtboard id="ao-1" label="1 · Source + table" width={PW} height={PH}><Phone><AO1_Source /></Phone></DCArtboard>
        <DCArtboard id="ao-2" label="2 · Add items + cart" width={PW} height={PH}><Phone><AO2_Items /></Phone></DCArtboard>
        <DCArtboard id="ao-3" label="3 · Review & send" width={PW} height={PH}><Phone><AO3_Review /></Phone></DCArtboard>
        <DCArtboard id="ao-4" label="Sent to kitchen" width={PW} height={PH}><Phone><AO4_Sent /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="notifs" title="Notifications"
        subtitle="Three surfaces: inbox · in-app toast · lockscreen push.">
        <DCArtboard id="nt-inbox" label="Inbox · today + earlier" width={PW} height={PH}><Phone><Notif_Inbox /></Phone></DCArtboard>
        <DCArtboard id="nt-toast" label="In-app toast over Orders" width={PW} height={PH}><Phone><Notif_InAppToast /></Phone></DCArtboard>
        <DCArtboard id="nt-push" label="Android lockscreen push" width={PW} height={PH}><Phone bg={TFC.dark}><Notif_Push /></Phone></DCArtboard>
        <DCArtboard id="nt-empty" label="Empty state" width={PW} height={PH}><Phone><Notif_Empty /></Phone></DCArtboard>
        <DCArtboard id="nt-set" label="Settings / preferences" width={PW} height={PH}><Phone><Notif_Settings /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="notes" title="System notes"
        subtitle="Changelog + tokens + open questions">
        <DCArtboard id="notes-1" label="Notes" width={780} height={760}>
          <SystemNotes />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
