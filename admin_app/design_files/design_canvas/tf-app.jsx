// Terafoods · Design Canvas composition

const PW = TF.W + TF.FRAME_PAD * 2;
const PH = TF.H + TF.FRAME_PAD * 2;

// --- Tweaks ---------------------------------------------------------------
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "menu_layout": "grid",
  "brand": "amber",
  "mood": "warm"
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
      </TweaksPanel>
    </TfTweaksContext.Provider>
  );
}

function DesignCanvasTree() {
  return (
    <DesignCanvas>
      <DCSection id="dashboard" title="Manager dashboard · by tier"
        subtitle="Manage Mode home, one tier per artboard. Features APPEAR as the business grows — STANDARD is one card + buttons; ENTERPRISE is a fleet console. Each screen scrolls.">
        <DCArtboard id="dash-t1" label="STANDARD · food cart — juice bar (Lebu Fresh)" width={PW} height={PH}><Phone><Dash_T1_Counter /></Phone></DCArtboard>
        <DCArtboard id="dash-t2" label="STANDARD · cafe — small dine-in (Cha Ghor)" width={PW} height={PH}><Phone><Dash_T2_Dinein /></Phone></DCArtboard>
        <DCArtboard id="dash-t3" label="ADVANCED · restaurant — full-service (Spice Garden)" width={PW} height={PH}><Phone><Dash_T3_Full /></Phone></DCArtboard>
        <DCArtboard id="dash-t4" label="ENTERPRISE · chain — multi-unit (5 outlets)" width={PW} height={PH}><Phone><Dash_T4_Fleet /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="inventory-tier" title="Inventory · home by tier"
        subtitle="Same complexity dial as the dashboard. STANDARD is two KPIs + top movers + actions (food cart, then cafe); ADVANCED layers food-cost %, 7-day reorder suggestions, daily reconciliation variance, and menu-item costing for the full-service restaurant.">
        <DCArtboard id="inv-simple"   label="STANDARD · food cart — juice bar (Lebu Fresh)" width={PW} height={PH}><Phone><Inv_Simple /></Phone></DCArtboard>
        <DCArtboard id="inv-standard" label="STANDARD · cafe — small dine-in (Cha Ghor)"  width={PW} height={PH}><Phone><Inv_Standard /></Phone></DCArtboard>
        <DCArtboard id="inv-advanced" label="ADVANCED · restaurant — full-service (Spice Garden)" width={PW} height={PH}><Phone><Inv_Advanced /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="inventory" title="Inventory · 5 screens"
        subtitle="Home → Item → Add → End-of-day count → Daily report. Same DASH tokens as the dashboard. Burnt orange reserved for CTAs (≤ 5% per viewport); signal colors do the talking on data.">
        <DCArtboard id="inv-1" label="1 · Inventory home" width={PW} height={PH}><Phone><Inv1_Home /></Phone></DCArtboard>
        <DCArtboard id="inv-2" label="2 · Item detail · Rice" width={PW} height={PH}><Phone><Inv2_Detail /></Phone></DCArtboard>
        <DCArtboard id="inv-3" label="3 · Add item" width={PW} height={PH}><Phone><Inv3_Add /></Phone></DCArtboard>
        <DCArtboard id="inv-4" label="4 · End-of-day count" width={PW} height={PH}><Phone><Inv4_Count /></Phone></DCArtboard>
        <DCArtboard id="inv-5" label="5 · Daily report" width={PW} height={PH}><Phone><Inv5_Report /></Phone></DCArtboard>
      </DCSection>

      <DCSection id="foh-tier" title="FOH · order entry by tier"
        subtitle="The act of taking an order. P1 is counter-only — direct item entry, receipt at the end. P2 adds table selection, a floor-map strip, and waiter attribution before sending to kitchen. P3 layers per-item modifiers, dietary tags, kitchen-sent markers per line, and tracked adjustments (loyalty discount + comped item with reason).">
        <DCArtboard id="foh-simple"   label="SIMPLE · counter (Lebu Fresh)"          width={PW} height={PH}><Phone><FOH_Simple /></Phone></DCArtboard>
        <DCArtboard id="foh-standard" label="STANDARD · dine-in (Cha Ghor)"          width={PW} height={PH}><Phone><FOH_Standard /></Phone></DCArtboard>
        <DCArtboard id="foh-advanced" label="ADVANCED · full-service (Spice Garden)" width={PW} height={PH}><Phone><FOH_Advanced /></Phone></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
