// Terafoods · Manage Mode — TIER 1 · Counter
// Business: "Lebu Fresh" — juice & smoothie counter, Dhanmondi. Owner: Rina.
// CASH-ONLY. Priority for a counter operator who taps items all day:
//   1. Active order + Take-cash CTA (sticky)   2. Sell grid (hero)
//   3. Cash-today status strip
//   ─── REVIEW ───
//   4. Top items today                          5. Close day

const T1_NAV = [
  { kind: 'home', label: 'Sell' },
  { kind: 'chart', label: 'Sales' },
  { kind: 'menu', label: 'Items' },
  { kind: 'settings', label: 'More' },
];

// FOH product tile — the surface Rina taps all day.
// Active (in-cart) tiles use accentSoft as the selected-state surface per the
// system's selected-state rule — never DASH.ink (ink is a text token, not a
// card fill). The + affordance is a plain icon, not a chip with surfaceAlt
// fill (surfaceAlt is for wells, not interactive controls).
const SellTile = ({ emoji, n, bn, p, tint, qty }) => {
  const active = !!qty;
  return (
    <div style={{
      position: 'relative',
      background: active ? DASH.accentSoft : DASH.surface,
      border: `1px solid ${active ? DASH.accentSoft : DASH.border}`,
      borderRadius: 14, padding: '12px 12px', minHeight: 110,
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      color: DASH.ink,
    }}>
      {active && (
        <div style={{
          position: 'absolute', top: -8, right: -6, minWidth: 24, height: 24, padding: '0 7px',
          borderRadius: 12, background: DASH.ink, color: DASH.onInk, fontSize: 12, fontWeight: 700,
          display: 'grid', placeItems: 'center', border: `2px solid ${DASH.bg}`, ...DASH.num,
        }}>{qty}</div>
      )}
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
        <div style={{
          width: 40, height: 40, borderRadius: 10,
          background: active ? DASH.surface : (tint || DASH.surfaceAlt),
          display: 'grid', placeItems: 'center',
        }}>
          <span style={{ fontSize: 22 }}>{emoji}</span>
        </div>
        <div style={{
          width: 26, height: 26,
          display: 'grid', placeItems: 'center',
          color: active ? DASH.ink : DASH.textSec,
        }}>
          <NavIcon kind="plus" />
        </div>
      </div>
      <div>
        <div style={{ fontSize: 13.5, fontWeight: 600, lineHeight: 1.2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{n}</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 3 }}>
          <span style={{ fontSize: 13, fontWeight: 600, ...DASH.num }}>{p}</span>
          {bn && <span style={{ fontSize: 10.5, color: DASH.textTer, fontFamily: DASH.bn, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{bn}</span>}
        </div>
      </div>
    </div>
  );
};

const Dash_T1_Counter = () => (
  <DashScreen nav={T1_NAV} navActive={0}>
    <DashHeader
      greet="Morning, Rina" emoji=""
      biz="Lebu Fresh" bn="ধানমন্ডি" date="Sat · 10:12 AM"
      tier="Counter · cash only" tierBn="কাউন্টার" tierTone="paper" badge={null}
    />

    {/* 1 · Cash-today status strip — quick reassurance */}
    <Section top={4}>
      <div style={dashCardStyle({ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 })}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <MicroLabel>Cash drawer · today</MicroLabel>
          <div style={{ fontSize: 26, fontWeight: 600, color: DASH.text, marginTop: 5, letterSpacing: -0.8, lineHeight: 1, ...DASH.num }}>৳6,240</div>
          <div style={{ fontSize: 11, color: DASH.textSec, marginTop: 4, ...DASH.num }}>
            38 orders · <Bn dim={DASH.textTer}>আজকের নগদ</Bn>
          </div>
        </div>
        {/* Neutral status chip — not accentSoft. accentSoft is reserved for
            selected-state backgrounds; ALL-CASH is a passive status fact. */}
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          background: DASH.surfaceAlt, color: DASH.textSec,
          padding: '6px 11px', borderRadius: 999,
          border: `1px solid ${DASH.border}`,
          fontSize: 11, fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.5,
        }}>
          <span style={{ width: 6, height: 6, borderRadius: 3, background: DASH.textTer }} />ALL CASH
        </div>
      </div>
    </Section>

    {/* 2 · THE HERO — sell grid */}
    <Section top={16}>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 4, padding: '0 2px' }}>
        <div style={{ fontSize: 15, fontWeight: 600, color: DASH.text, letterSpacing: -0.2 }}>
          Ring it up <Bn>বিক্রি করুন</Bn>
        </div>
        <span style={{ fontSize: 12, color: DASH.textSec, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 3 }}>
          Edit items <span style={{ opacity: 0.5 }}><NavIcon kind="chevron" /></span>
        </span>
      </div>
      <div style={{ fontSize: 11.5, color: DASH.textSec, marginBottom: 12, lineHeight: 1.4, padding: '0 2px' }}>
        Tap items to build an order, then take cash.
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0,1fr) minmax(0,1fr)', gap: 10 }}>
        <SellTile emoji="🍋" n="Lemon Mint" bn="লেবু" p="৳60" qty={2} />
        <SellTile emoji="🥭" n="Mango Lassi" bn="লাচ্ছি" p="৳120" tint="#FEF3D1" qty={1} />
        <SellTile emoji="🍊" n="Orange Fresh" bn="কমলা" p="৳80" tint="#FCEEDC" />
        <SellTile emoji="🥤" n="Sugarcane" bn="আখ" p="৳50" tint="#E8F4F0" />
        <SellTile emoji="☕" n="Cold Coffee" bn="কফি" p="৳140" tint="#EEEAE2" />
        <SellTile emoji="🍉" n="Watermelon" bn="তরমুজ" p="৳70" tint="#FBE4DB" />
        <SellTile emoji="🍓" n="Strawberry" bn="স্ট্রবেরি" p="৳130" tint="#FBE4DB" />
        <SellTile emoji="🥥" n="Coconut" bn="ডাব" p="৳90" tint="#E8F4F0" />
      </div>
    </Section>

    {/* ─── below the grid: review zone ─── */}
    <Section top={20}>
      <Divider label="Today so far" bn="আজকের হিসাব" />
    </Section>

    <Section top={12}>
      <SecHead title="Top items" bn="টপ আইটেম" action="See all" />
      <MoverRow rank={1} name="Lemon Mint" qty={18} rev="৳1,080" pct={1} />
      <MoverRow rank={2} name="Mango Lassi" qty={9}  rev="৳1,080" pct={0.92} />
      <MoverRow rank={3} name="Cold Coffee" qty={5}  rev="৳700"   pct={0.6} />
    </Section>

    <Section top={14}>
      <div style={{ paddingBottom: 8 }}>
        <CloseCard amount="৳6,240" title="Close counter · ৳6,240" kicker="End of day" warn="3 items left in current order — clear before closing" />
      </div>
    </Section>

    {/* spacer so the sticky tray doesn't cover the last card */}
    <div style={{ height: 84 }} />

    {/* Live order tray — surface card with a raised shadow per the stacking
        rule. Was a DASH.ink dark card — ink is a text token, not a card fill.
        Take-cash CTA stays as the one full-accent element on this viewport. */}
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 70, padding: '0 12px 10px' }}>
      <div style={{
        background: DASH.surface, borderRadius: 14, padding: '11px 11px 11px 14px',
        display: 'flex', alignItems: 'center', gap: 10,
        boxShadow: DASH.shadowRaised,
        border: `1px solid ${DASH.border}`,
      }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <MicroLabel>3 items · current order</MicroLabel>
          <div style={{
            fontSize: 13, color: DASH.text, marginTop: 3, fontWeight: 600,
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          }}>Lemon Mint ×2 · Mango Lassi</div>
        </div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          background: DASH.accent, color: DASH.accentInk,
          padding: '10px 14px', borderRadius: 11, flexShrink: 0,
          boxShadow: DASH.shadowGlow,
        }}>
          <span style={{ fontSize: 13, fontWeight: 600 }}>Take cash</span>
          <span style={{ fontSize: 15, fontWeight: 700, letterSpacing: -0.3, ...DASH.num }}>৳240</span>
        </div>
      </div>
    </div>
  </DashScreen>
);

Object.assign(window, { Dash_T1_Counter, SellTile });
