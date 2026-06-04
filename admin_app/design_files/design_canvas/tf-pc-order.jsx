// Terafoods · Computer OS — Order detail + bill-split modal + Day open/close

// ────────────────────────────────────────────────────────────────
// 3 · Order detail · Table T7 · Hall A
//   Left rail: table context, kitchen status timeline, history
//   Center:    order items, with KOT sent markers per line + add tile
//   Right:     bill summary + discount/charges + payment buttons
// ────────────────────────────────────────────────────────────────
const PC_ORDER_LINES = [
  { ...PC_ITEMS[4], q: 2, note: 'extra spicy · no cucumber', sent: '7:34 PM' },
  { ...PC_ITEMS[8], q: 1, mod: 'half plate', sent: '7:34 PM' },
  { ...PC_ITEMS[17], q: 4, sent: '7:34 PM' },
  { ...PC_ITEMS[0], q: 4, sent: '7:34 PM' },
  // Added later, not yet sent:
  { ...PC_ITEMS[13], q: 2, note: 'medium', pending: true },
  { ...PC_ITEMS[19], q: 2, pending: true },
];

const PC_OrderLine = ({ l, i }) => (
  <div style={{
    display: 'grid', gridTemplateColumns: '36px 1fr 90px 80px 100px 28px',
    gap: 12, padding: '12px 14px',
    borderBottom: `1px solid ${PC.C.border}`, alignItems: 'center',
    background: l.pending ? PC.C.accentWash : PC.C.surface,
  }}>
    <span style={{
      fontSize: 11, fontFamily: PC.C.mono, fontWeight: 700,
      color: PC.C.textTer, letterSpacing: 0.4, ...PC.C.num,
    }}>{String(i + 1).padStart(2, '0')}</span>
    <div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span style={{ fontSize: 14, fontWeight: 600, color: PC.C.text }}>{l.n}</span>
        {l.mod && <span style={{ fontSize: 11.5, color: PC.C.textSec }}>· {l.mod}</span>}
        {l.pending ? (
          <span style={{
            padding: '1px 6px', borderRadius: 4, fontSize: 9.5,
            fontFamily: PC.C.mono, fontWeight: 700, letterSpacing: 0.6,
            background: PC.C.accentSoft, color: PC.C.accent,
          }}>NEW · UNSENT</span>
        ) : (
          <span style={{
            padding: '1px 6px', borderRadius: 4, fontSize: 9.5,
            fontFamily: PC.C.mono, fontWeight: 700, letterSpacing: 0.6,
            background: PC.C.goodSoft, color: PC.C.good,
          }}>SENT {l.sent}</span>
        )}
      </div>
      {l.note && <div style={{ fontSize: 11.5, color: PC.C.textSec, marginTop: 3, fontStyle: 'italic' }}>"{l.note}"</div>}
    </div>
    <PcQtyStep q={l.q} />
    <span style={{ fontSize: 12.5, color: PC.C.textSec, ...PC.C.num }}>@ ৳{l.p}</span>
    <span style={{ fontSize: 14, fontWeight: 700, color: PC.C.text, textAlign: 'right', ...PC.C.num }}>৳{(l.p * l.q).toLocaleString()}</span>
    <button style={{ border: 'none', background: 'transparent', color: PC.C.textTer, cursor: 'pointer', padding: 4 }}>
      <NavIcon kind="close" />
    </button>
  </div>
);

const PC_Order = ({ withSplitModal = false }) => {
  const subtotal = PC_ORDER_LINES.reduce((s, l) => s + l.p * l.q, 0);
  return (
    <PcShell activeNav="floor" chromeTitle="Table T7 · Hall A"
      title="Table T7 · Hall A"
      sub="Waiter · Salma · 4 covers · seated 7:30 PM · 18 min"
      topActions={
        <>
          <PcBtn variant="ghost" icon="back">Back to floor</PcBtn>
          <PcBtn variant="ghost" icon="printer" sk="Ctrl+P">Reprint KOT</PcBtn>
          <PcBtn variant="dark" icon="check">Mark served</PcBtn>
        </>
      }>
      {/* left rail · table + kitchen timeline */}
      <div style={{ width: 260, flexShrink: 0, background: PC.C.surface, borderRight: `1px solid ${PC.C.border}`, padding: '18px 16px', display: 'flex', flexDirection: 'column', gap: 16, overflow: 'hidden' }}>
        <div>
          <PcEyebrow>Table</PcEyebrow>
          <div style={{ fontSize: 32, fontWeight: 700, color: PC.C.ink, letterSpacing: '-0.03em', lineHeight: 1, marginTop: 6, ...PC.C.num }}>T7</div>
          <div style={{ fontSize: 12, color: PC.C.textSec, marginTop: 4 }}>Hall A · seats 4</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          {[
            ['Covers', '4'], ['Waiter', 'Salma'],
            ['Seated', '7:30 PM'], ['Dwell', '18m'],
          ].map(([l, v], i) => (
            <div key={i} style={{ padding: '8px 10px', background: PC.C.surfaceAlt, borderRadius: 8 }}>
              <PcEyebrow>{l}</PcEyebrow>
              <div style={{ fontSize: 13, fontWeight: 700, color: PC.C.text, marginTop: 3, ...PC.C.num }}>{v}</div>
            </div>
          ))}
        </div>

        <div>
          <PcEyebrow>Kitchen timeline</PcEyebrow>
          <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 12, position: 'relative' }}>
            <div style={{ position: 'absolute', left: 5, top: 6, bottom: 6, width: 1, background: PC.C.border }} />
            {[
              ['7:30 PM', 'Seated · 4 covers', PC.C.good],
              ['7:34 PM', 'KOT #1 sent · curry station + tea', PC.C.good],
              ['7:42 PM', 'KOT #1 acknowledged', PC.C.good],
              ['7:48 PM', 'KOT #2 (added items) — UNSENT', PC.C.accent],
            ].map(([t, l, c], i) => (
              <div key={i} style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                <span style={{
                  width: 11, height: 11, borderRadius: 6, background: c, marginTop: 3, flexShrink: 0,
                  border: `2px solid ${PC.C.surface}`, position: 'relative', zIndex: 1,
                }} />
                <div>
                  <div style={{ fontSize: 10.5, fontFamily: PC.C.mono, fontWeight: 700, color: PC.C.textSec, letterSpacing: 0.3 }}>{t}</div>
                  <div style={{ fontSize: 12, color: PC.C.text, marginTop: 2, lineHeight: 1.4 }}>{l}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div style={{ marginTop: 'auto', padding: 12, borderRadius: 10, background: PC.C.surfaceAlt }}>
          <PcEyebrow>Customer · regular</PcEyebrow>
          <div style={{ fontSize: 13, fontWeight: 600, color: PC.C.text, marginTop: 4 }}>Mr. Karim</div>
          <div style={{ fontSize: 11.5, color: PC.C.textSec, marginTop: 2, ...PC.C.num }}>01711-203455 · 24 visits · avg ৳1,840</div>
        </div>
      </div>

      {/* center · items + add tile */}
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* kitchen note bar */}
        <div style={{
          margin: 18, padding: '10px 14px', borderRadius: 10,
          background: PC.C.surface, border: `1px solid ${PC.C.border}`,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <span style={{
            padding: '3px 8px', borderRadius: 5, background: PC.C.surfaceAlt,
            fontSize: 10, fontFamily: PC.C.mono, fontWeight: 700, color: PC.C.textSec, letterSpacing: 0.6,
          }}>KITCHEN NOTE</span>
          <span style={{ fontSize: 13, color: PC.C.text, fontStyle: 'italic' }}>
            "Customer is vegetarian — no beef anywhere. Lady has nut allergy."
          </span>
          <div style={{ flex: 1 }} />
          <button style={{ border: 'none', background: 'transparent', color: PC.C.textSec, fontSize: 12, fontWeight: 600, cursor: 'pointer' }}>Edit</button>
        </div>

        {/* items list */}
        <div style={{
          margin: '0 18px', background: PC.C.surface,
          border: `1px solid ${PC.C.border}`, borderRadius: 12,
          flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column',
        }}>
          {/* header row */}
          <div style={{
            display: 'grid', gridTemplateColumns: '36px 1fr 90px 80px 100px 28px',
            gap: 12, padding: '10px 14px',
            background: PC.C.surfaceAlt, borderBottom: `1px solid ${PC.C.border}`,
          }}>
            {['#', 'ITEM', 'QTY', 'PRICE', 'LINE TOTAL', ''].map((h, i) => (
              <span key={i} style={{ fontSize: 9.5, fontFamily: PC.C.mono, fontWeight: 700, color: PC.C.textSec, letterSpacing: 0.7, textAlign: i === 4 ? 'right' : 'left' }}>{h}</span>
            ))}
          </div>
          {PC_ORDER_LINES.map((l, i) => <PC_OrderLine key={i} l={l} i={i} />)}
          {/* add row */}
          <div style={{
            padding: '14px', display: 'flex', alignItems: 'center', gap: 10,
            background: PC.C.surfaceAlt,
          }}>
            <span style={{ color: PC.C.textTer }}><NavIcon kind="plus" /></span>
            <span style={{ fontSize: 13, color: PC.C.textSec }}>Add item · scan / search / pick from menu</span>
            <div style={{ flex: 1 }} />
            <PcBtn variant="surface" size="sm" sk="F4">Open menu</PcBtn>
          </div>
        </div>

        {/* footer · primary actions */}
        <div style={{ padding: 18, display: 'flex', gap: 10 }}>
          <PcBtn variant="ghost" size="lg" icon="close" sk="Esc">Cancel changes</PcBtn>
          <PcBtn variant="ghost" size="lg" icon="people">Move to other table</PcBtn>
          <div style={{ flex: 1 }} />
          <PcBtn variant="surface" size="lg" icon="printer">Print bill (pre-bill)</PcBtn>
          <PcBtn variant="primary" size="lg" icon="check" sk="Ctrl+Enter">Send 2 items to kitchen</PcBtn>
        </div>
      </div>

      {/* right · bill */}
      <PC_OrderBill subtotal={subtotal} />

      {withSplitModal && <PC_SplitModal />}
    </PcShell>
  );
};

const PC_OrderBill = ({ subtotal }) => {
  const disc = Math.round(subtotal * 0.05);
  const svc = Math.round((subtotal - disc) * 0.05);
  const vat = Math.round((subtotal - disc) * 0.05);
  const total = subtotal - disc + svc + vat;
  return (
    <div style={{ width: 340, flexShrink: 0, background: PC.C.surface, borderLeft: `1px solid ${PC.C.border}`, display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '16px 18px 14px', borderBottom: `1px solid ${PC.C.border}` }}>
        <PcEyebrow>Bill · Table T7</PcEyebrow>
        <div style={{ fontSize: 14, fontWeight: 700, color: PC.C.text, marginTop: 4, letterSpacing: -0.2 }}>
          Running total · 4 covers
        </div>
      </div>

      <div style={{ padding: '14px 18px', borderBottom: `1px solid ${PC.C.border}` }}>
        {[
          ['Subtotal · 6 items', `৳${subtotal.toLocaleString()}`],
          ['Discount · Loyalty 5%', `−৳${disc}`, PC.C.late],
          ['Service · 5%', `৳${svc}`],
          ['VAT · 5%', `৳${vat}`],
        ].map(([l, v, col], i) => (
          <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '5px 0', fontSize: 13 }}>
            <span style={{ color: PC.C.textSec }}>{l}</span>
            <span style={{ color: col || PC.C.text, fontWeight: 600, ...PC.C.num }}>{v}</span>
          </div>
        ))}
        <div style={{ height: 1, background: PC.C.border, margin: '10px 0' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <span style={{ fontSize: 13, fontWeight: 600, color: PC.C.text }}>Total due</span>
          <span style={{ fontSize: 32, fontWeight: 700, color: PC.C.ink, letterSpacing: '-0.025em', ...PC.C.num }}>৳{total.toLocaleString()}</span>
        </div>
      </div>

      {/* discount tools */}
      <div style={{ padding: '14px 18px', borderBottom: `1px solid ${PC.C.border}` }}>
        <PcEyebrow>Adjustments · Manager PIN required</PcEyebrow>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, marginTop: 8 }}>
          <PcBtn variant="surface" size="sm">Discount %</PcBtn>
          <PcBtn variant="surface" size="sm">Discount ৳</PcBtn>
          <PcBtn variant="surface" size="sm">Void item</PcBtn>
          <PcBtn variant="surface" size="sm">Comp item</PcBtn>
        </div>
      </div>

      {/* payment */}
      <div style={{ flex: 1, padding: '14px 18px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <PcEyebrow>Settle bill</PcEyebrow>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, marginTop: 4 }}>
          <PcBtn variant="surface" icon="shop" sk="F9">Cash</PcBtn>
          <PcBtn variant="surface" icon="wifi" sk="F10">bKash</PcBtn>
          <PcBtn variant="surface" icon="wifi" sk="F11">Nagad</PcBtn>
          <PcBtn variant="surface" icon="orders" sk="F12">Card</PcBtn>
        </div>
        <PcBtn variant="ghost" icon="menu" sk="Ctrl+B" full>Split bill · by item · by % · equal</PcBtn>
        <div style={{ flex: 1 }} />
        <PcBtn variant="dark" size="xl" icon="printer" sk="Ctrl+Enter" full>Settle · ৳{total.toLocaleString()}</PcBtn>
      </div>
    </div>
  );
};

// ────────────────────────────────────────────────────────────────
// Bill split modal — overlays the Order screen
// ────────────────────────────────────────────────────────────────
const PC_SplitModal = () => (
  <div style={{
    position: 'absolute', inset: 0, background: 'rgba(22,16,30,0.45)',
    backdropFilter: 'blur(2px)', zIndex: 50,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
  }}>
    <div style={{
      width: 880, background: PC.C.surface, borderRadius: 16,
      boxShadow: PC.C.shadowRaised, overflow: 'hidden',
      border: `1px solid ${PC.C.border}`,
    }}>
      {/* header */}
      <div style={{ padding: '18px 22px', borderBottom: `1px solid ${PC.C.border}`, display: 'flex', alignItems: 'center', gap: 12 }}>
        <div>
          <PcEyebrow>Split bill · Table T7</PcEyebrow>
          <div style={{ fontSize: 18, fontWeight: 700, color: PC.C.text, marginTop: 4, letterSpacing: -0.3 }}>
            Total ৳3,059 · 4 covers
          </div>
        </div>
        <div style={{ flex: 1 }} />
        <button style={{
          width: 32, height: 32, borderRadius: 8, border: `1px solid ${PC.C.border}`,
          background: PC.C.surface, display: 'grid', placeItems: 'center', cursor: 'pointer',
        }}><NavIcon kind="close" /></button>
      </div>

      {/* tabs */}
      <div style={{ padding: '14px 22px 0', display: 'flex', gap: 4 }}>
        {[['By item', true], ['By percentage'], ['Equal split']].map(([l, on], i) => (
          <div key={i} style={{
            padding: '8px 14px', borderRadius: 7,
            background: on ? PC.C.accentSoft : 'transparent',
            color: on ? PC.C.accent : PC.C.textSec,
            fontSize: 13, fontWeight: 700,
          }}>{l}</div>
        ))}
      </div>

      {/* body · two payers */}
      <div style={{ padding: 22, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
        {[
          {
            name: 'Payer 1 · Mr. Karim',
            lines: [['Chicken biryani × 2', 640], ['Beef bhuna · half', 140], ['Cha doodh × 2', 50]],
            total: 830, pay: 'bKash',
          },
          {
            name: 'Payer 2 · friend',
            lines: [['Naan × 4', 200], ['Cha doodh × 2', 50], ['Service + VAT', 81]],
            total: 331, pay: 'Cash',
          },
        ].map((p, i) => (
          <div key={i} style={{
            background: PC.C.bg, borderRadius: 12, padding: 16,
            border: `1px solid ${PC.C.border}`,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 13, fontWeight: 700, color: PC.C.text }}>{p.name}</span>
              <span style={{
                padding: '3px 8px', borderRadius: 5, fontSize: 10,
                fontFamily: PC.C.mono, fontWeight: 700, letterSpacing: 0.5,
                background: PC.C.accentSoft, color: PC.C.accent,
              }}>{p.pay.toUpperCase()}</span>
            </div>
            <div style={{ marginTop: 12 }}>
              {p.lines.map((l, j) => (
                <div key={j} style={{ display: 'flex', justifyContent: 'space-between', padding: '5px 0', fontSize: 12.5 }}>
                  <span style={{ color: PC.C.textSec }}>{l[0]}</span>
                  <span style={{ color: PC.C.text, fontWeight: 600, ...PC.C.num }}>৳{l[1]}</span>
                </div>
              ))}
            </div>
            <div style={{ height: 1, background: PC.C.border, margin: '10px 0' }} />
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
              <span style={{ fontSize: 12, color: PC.C.textSec, fontWeight: 600 }}>Subtotal · their share</span>
              <span style={{ fontSize: 22, fontWeight: 700, color: PC.C.ink, ...PC.C.num }}>৳{p.total}</span>
            </div>
          </div>
        ))}
      </div>

      {/* split balance */}
      <div style={{
        margin: '0 22px 18px', padding: '12px 14px', borderRadius: 10,
        background: PC.C.goodSoft, color: PC.C.good,
        display: 'flex', alignItems: 'center', gap: 12,
      }}>
        <NavIcon kind="check" />
        <span style={{ fontSize: 13, fontWeight: 700 }}>Split balanced · all ৳3,059 assigned · no unassigned items</span>
      </div>

      {/* actions */}
      <div style={{
        padding: '14px 22px', borderTop: `1px solid ${PC.C.border}`,
        display: 'flex', gap: 10, background: PC.C.surfaceAlt,
      }}>
        <PcBtn variant="ghost" icon="plus">Add 3rd payer</PcBtn>
        <div style={{ flex: 1 }} />
        <PcBtn variant="ghost" sk="Esc">Cancel</PcBtn>
        <PcBtn variant="primary" size="lg" icon="printer">Settle both · print 2 receipts</PcBtn>
      </div>
    </div>
  </div>
);

// ────────────────────────────────────────────────────────────────
// 4 · Day open — cash drawer count to start the shift
// ────────────────────────────────────────────────────────────────
const PC_DayOpen = () => {
  const denoms = [
    [1000, 5, 5000], [500, 8, 4000], [100, 22, 2200], [50, 14, 700],
    [20, 26, 520], [10, 32, 320], [5, 18, 90], [2, 22, 44], [1, 36, 36],
  ];
  const total = denoms.reduce((s, [_, __, t]) => s + t, 0);
  return (
    <PcShell activeNav="counter" chromeTitle="Open day"
      title="Open day · Monday 2 June"
      sub="Last shift closed Sun 1 Jun · 11:48 PM by Rashed Hossain"
      statusTools={['offline','bn','printer','drawer','shift']}
      footerHints={[{ k: 'Enter', l: 'Confirm field' }, { k: 'Tab', l: 'Next' }, { k: 'F2', l: 'Skip count' }, { k: 'Esc', l: 'Cancel' }]}>
      <div style={{ flex: 1, minWidth: 0, padding: 28, display: 'flex', justifyContent: 'center', overflow: 'hidden' }}>
        <div style={{ width: 980, display: 'grid', gridTemplateColumns: '1fr 360px', gap: 20 }}>
          {/* left · denomination count */}
          <PcCard pad={22}>
            <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
              <div>
                <PcEyebrow>Step 1 of 2 · count opening cash</PcEyebrow>
                <div style={{ fontSize: 22, fontWeight: 700, color: PC.C.text, marginTop: 6, letterSpacing: -0.4 }}>
                  How much is in the drawer right now?
                </div>
                <div style={{ fontSize: 12.5, color: PC.C.textSec, marginTop: 4 }}>
                  Count notes & coins by denomination. The system uses this as the float for today's variance check.
                </div>
              </div>
              <PcPill tone="muted" icon="clock">Expected float ৳12,000 (yesterday's close)</PcPill>
            </div>

            <div style={{ marginTop: 22, border: `1px solid ${PC.C.border}`, borderRadius: 10, overflow: 'hidden' }}>
              <div style={{
                display: 'grid', gridTemplateColumns: '120px 1fr 120px 130px',
                padding: '10px 14px', background: PC.C.surfaceAlt,
                borderBottom: `1px solid ${PC.C.border}`,
              }}>
                {['DENOM', 'COUNT', 'PER UNIT', 'TOTAL'].map((h, i) => (
                  <span key={i} style={{ fontSize: 9.5, fontFamily: PC.C.mono, fontWeight: 700, color: PC.C.textSec, letterSpacing: 0.7, textAlign: i >= 2 ? 'right' : 'left' }}>{h}</span>
                ))}
              </div>
              {denoms.map(([d, c, t], i) => (
                <div key={d} style={{
                  display: 'grid', gridTemplateColumns: '120px 1fr 120px 130px',
                  padding: '8px 14px', alignItems: 'center',
                  borderBottom: i < denoms.length - 1 ? `1px solid ${PC.C.border}` : 'none',
                  background: c > 0 ? PC.C.surface : PC.C.bg,
                }}>
                  <span style={{ fontSize: 14, fontWeight: 700, color: PC.C.text, ...PC.C.num }}>৳{d}</span>
                  <div style={{
                    display: 'inline-flex', alignItems: 'center',
                    background: PC.C.surface, border: `1px solid ${PC.C.border}`,
                    borderRadius: 7, height: 32, width: 140, justifySelf: 'start',
                  }}>
                    <button style={btnStep}><NavIcon kind="minus" /></button>
                    <span style={{ flex: 1, textAlign: 'center', fontSize: 14, fontWeight: 700, ...PC.C.num, color: c > 0 ? PC.C.text : PC.C.textTer }}>{c}</span>
                    <button style={btnStep}><NavIcon kind="plus" /></button>
                  </div>
                  <span style={{ fontSize: 12.5, color: PC.C.textSec, textAlign: 'right', ...PC.C.num }}>× ৳{d}</span>
                  <span style={{ fontSize: 14, fontWeight: 700, color: c > 0 ? PC.C.text : PC.C.textTer, textAlign: 'right', ...PC.C.num }}>৳{t.toLocaleString()}</span>
                </div>
              ))}
            </div>
          </PcCard>

          {/* right · summary + start */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <PcCard pad={20}>
              <PcEyebrow>Counted opening cash</PcEyebrow>
              <div style={{ fontSize: 44, fontWeight: 700, color: PC.C.ink, marginTop: 10, letterSpacing: '-0.03em', ...PC.C.num }}>
                ৳{total.toLocaleString()}
              </div>
              <div style={{ marginTop: 18, display: 'flex', flexDirection: 'column', gap: 8 }}>
                {[
                  ['Expected float', '৳12,000'],
                  ['Variance', `+৳${(total - 12000).toLocaleString()}`, PC.C.good],
                  ['Sun close · by', 'Rashed · 11:48 PM'],
                ].map(([l, v, col], i) => (
                  <div key={i} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12.5 }}>
                    <span style={{ color: PC.C.textSec }}>{l}</span>
                    <span style={{ color: col || PC.C.text, fontWeight: 600, ...PC.C.num }}>{v}</span>
                  </div>
                ))}
              </div>
            </PcCard>

            <PcCard pad={16}>
              <PcEyebrow>Step 2 · choose printers</PcEyebrow>
              <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 6 }}>
                {[
                  ['Receipt printer', 'RP-80 · USB · ready', 'good'],
                  ['Kitchen · curry station', 'KP-58 · Bluetooth · ready', 'good'],
                  ['Kitchen · grill', 'KP-58 · disconnected · pair', 'warn'],
                ].map(([l, s, t], i) => (
                  <div key={i} style={{
                    display: 'flex', alignItems: 'center', gap: 10,
                    padding: '8px 10px', borderRadius: 7,
                    background: PC.C.surfaceAlt,
                  }}>
                    <span style={{ color: PC.C.textSec }}><NavIcon kind="printer" /></span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: 12.5, fontWeight: 600, color: PC.C.text }}>{l}</div>
                      <div style={{ fontSize: 11, color: PC.C.textSec, marginTop: 2 }}>{s}</div>
                    </div>
                    <span style={{
                      width: 7, height: 7, borderRadius: 4,
                      background: t === 'good' ? PC.C.good : PC.C.warn,
                    }} />
                  </div>
                ))}
              </div>
            </PcCard>

            <PcBtn variant="primary" size="xl" icon="check" full>Start day · open POS</PcBtn>
          </div>
        </div>
      </div>
    </PcShell>
  );
};

Object.assign(window, { PC_Order, PC_DayOpen });
