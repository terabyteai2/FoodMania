// Terafoods · Inventory · Stock-In page
// Opened from the "Stock in" button on the inventory home.
// Brief: small AI Scan camera button bottom right; AI Scan auto-fills
// item measurements so the operator doesn't have to type.

// One stock-in line — item, quantity (with unit), and cost.
// The AI-filled state shows a "Filled by AI Scan" sparkle chip.
const StockInRow = ({ letter, name, qty, unit, cost, aiFilled, first }) => (
  <div style={{
    padding: '14px 14px',
    borderTop: first ? 'none' : `1px solid ${DASH.divider}`,
    background: DASH.surface,
  }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <InvAvatar letter={letter} size={36} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
          <span style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text, lineHeight: 1.2 }}>{name}</span>
          {aiFilled && (
            <span style={{
              display: 'inline-flex', alignItems: 'center', gap: 4,
              padding: '2px 7px', borderRadius: 5,
              background: DASH.accentWash, color: DASH.accentInk,
              fontSize: 9.5, fontFamily: DASH.mono, fontWeight: 700,
              letterSpacing: 0.6, ...DASH.num,
            }}>
              <InvIcon kind="sparkles" s={10} color={DASH.accentInk} />
              AI-FILLED
            </span>
          )}
        </div>
        <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3, fontFamily: DASH.mono, ...DASH.num }}>
          unit price · {cost}
        </div>
      </div>
      <div style={{
        height: 44, minWidth: 100, padding: '0 12px',
        background: aiFilled ? DASH.accentWash : DASH.surfaceAlt,
        border: `1px solid ${aiFilled ? DASH.accent + '33' : 'transparent'}`,
        borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 6,
      }}>
        <span style={{
          fontSize: 17, fontWeight: 700,
          color: qty != null ? DASH.text : DASH.textTer,
          ...DASH.num, letterSpacing: -0.3,
        }}>
          {qty != null ? qty : '—'}
        </span>
        <span style={{ fontSize: 11, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 600 }}>{unit}</span>
      </div>
    </div>
  </div>
);

const Inv_StockIn = () => (
  <InvScreen
    padBottom={70 + 96}
    bottomBar={(
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 70,
        background: DASH.surface, borderTop: `1px solid ${DASH.border}`,
      }}>
        {/* Aggregation drawer · running total */}
        <div style={{
          padding: '10px 16px',
          background: DASH.surfaceAlt,
          borderBottom: `1px solid ${DASH.divider}`,
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 10.5, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase' }}>
              Total received
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
              <span style={{ fontSize: 16, fontWeight: 700, color: DASH.text, ...DASH.num, letterSpacing: -0.3 }}>৳3,460</span>
              <span style={{ fontSize: 11, color: DASH.textSec, ...DASH.num }}>· 5 items</span>
            </div>
          </div>
          <span style={{
            fontSize: 10.5, fontFamily: DASH.mono, fontWeight: 700, color: DASH.accentInk,
            background: DASH.accentWash, padding: '4px 8px', borderRadius: 5,
            letterSpacing: 0.5,
          }}>3 AI-FILLED</span>
        </div>
        {/* CTA */}
        <div style={{ padding: '12px 16px' }}>
          <InvAction variant="accent" icon="check">Save stock-in</InvAction>
        </div>
      </div>
    )}
  >
    <div style={{
      padding: '14px 16px 4px', display: 'flex', alignItems: 'center', gap: 10,
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: 10, background: DASH.surface,
        border: `1px solid ${DASH.border}`, display: 'grid', placeItems: 'center',
      }}>
        <InvIcon kind="back" s={18} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 20, fontWeight: 700, color: DASH.text, letterSpacing: -0.4, lineHeight: 1.1 }}>
          Stock in
        </div>
        <div style={{ fontSize: 11.5, color: DASH.textSec, marginTop: 4, ...DASH.num }}>
          May 24 · 8:14 AM · supplier intake
        </div>
      </div>
      <HeaderIconBtn><NavIcon kind="bell" /></HeaderIconBtn>
      <HeaderIconBtn><NavIcon kind="settings" /></HeaderIconBtn>
    </div>

    {/* Supplier strip */}
    <Section top={10}>
      <div style={{
        background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 12,
        padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
      }}>
        <div style={{
          width: 36, height: 36, borderRadius: 10,
          background: DASH.surfaceAlt, color: DASH.textSec,
          display: 'grid', placeItems: 'center',
        }}>
          <InvIcon kind="truck" s={18} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text }}>Karim Goshto · Karwan Bazar</div>
          <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3, fontFamily: DASH.mono, ...DASH.num }}>
            +880 1712-345 678 · invoice #4218
          </div>
        </div>
        <span style={{
          fontSize: 11, color: DASH.textSec, fontWeight: 600,
          padding: '5px 10px', borderRadius: 6,
          border: `1px solid ${DASH.border}`,
        }}>Change</span>
      </div>
    </Section>

    {/* Items received */}
    <Section top={18}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 10, padding: '0 2px' }}>
        <Eyebrow>Items received</Eyebrow>
        <div style={{ flex: 1 }} />
        <Eyebrow color={DASH.accentInk}>Tap AI Scan to auto-fill</Eyebrow>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <StockInRow first letter="M" name="Mutton"  qty="8.0" unit="kg"  cost="৳720/kg" aiFilled />
        <StockInRow       letter="C" name="Chicken" qty="12.0" unit="kg"  cost="৳280/kg" aiFilled />
        <StockInRow       letter="R" name="Rice"    qty="40.0" unit="kg"  cost="৳60/kg" />
        <StockInRow       letter="T" name="Tomato"  qty="6.0"  unit="kg"  cost="৳80/kg" aiFilled />
        <StockInRow       letter="O" name="Oil"     qty="10.0" unit="ltr" cost="৳180/ltr" />
      </DashCard>
    </Section>

    {/* Add another item · dashed */}
    <Section top={10}>
      <div style={{
        padding: '14px 14px', borderRadius: 12,
        background: DASH.surface, border: `1px dashed ${DASH.borderStrong}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        color: DASH.textSec, fontSize: 13, fontWeight: 600,
      }}>
        <InvIcon kind="plus" s={16} />
        Add item manually
      </div>
    </Section>

    {/* AI Scan floating button — bottom-right, accent. The brief calls for
        a SMALL camera button labelled "AI Scan" that lives above the bottom
        bar in the bottom-right of the viewport. */}
    <div style={{
      position: 'absolute', right: 16, bottom: 70 + 96 + 12, zIndex: 5,
    }}>
      <div style={{
        height: 44, padding: '0 14px',
        background: DASH.accent, color: DASH.accentInk,
        borderRadius: 999,
        display: 'inline-flex', alignItems: 'center', gap: 8,
        boxShadow: DASH.shadowRaised,
        fontSize: 13, fontWeight: 700, letterSpacing: -0.1,
      }}>
        <InvIcon kind="camera" s={16} />
        AI Scan
      </div>
    </div>
  </InvScreen>
);

Object.assign(window, { Inv_StockIn, StockInRow });
