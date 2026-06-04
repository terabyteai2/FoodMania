// Terafoods · FOH (Front of House) · complexity-dial tiers
// P1 SIMPLE   — counter mode, direct items, receipt only (Lebu Fresh)
// P2 STANDARD — table + waiter, send to kitchen (Cha Ghor)
// P3 ADVANCED — table + waiter + modifiers + dietary tags + sent markers + comp/discount (Spice Garden)

// ============================================================================
// Shared FOH primitives
// ============================================================================

const FOHHeader = ({ title, sub, trailing }) => (
  <div style={{
    padding: '14px 16px 12px', display: 'flex', alignItems: 'center', gap: 10,
    background: DASH.bg,
  }}>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 20, fontWeight: 600, color: DASH.text, letterSpacing: -0.3, lineHeight: 1.1 }}>{title}</div>
      {sub && <div style={{ fontSize: 11.5, color: DASH.textSec, marginTop: 4, ...DASH.num }}>{sub}</div>}
    </div>
    {trailing && <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexShrink: 0 }}>{trailing}</div>}
  </div>
);

const FOHChip = ({ label, count, on }) => (
  <div style={{
    padding: '8px 12px', borderRadius: 8, whiteSpace: 'nowrap',
    background: on ? DASH.ink : DASH.surface,
    color: on ? DASH.onInk : DASH.text,
    border: `1px solid ${on ? DASH.ink : DASH.border}`,
    fontSize: 12.5, fontWeight: 600,
    display: 'inline-flex', alignItems: 'center', gap: 6,
  }}>
    {label}
    {count != null && (
      <span style={{
        fontSize: 10.5, fontFamily: DASH.mono, fontWeight: 700,
        color: on ? DASH.onInkSec : DASH.textTer, ...DASH.num,
      }}>{count}</span>
    )}
  </div>
);

// Sticky cart footer — sits above bottom nav. Compact at P1/P2, expanded at P3.
const FOHCart = ({ children, padding = 12 }) => (
  <div style={{
    position: 'absolute', left: 0, right: 0, bottom: 70,
    background: DASH.ink, color: DASH.onInk,
    padding: `${padding}px 16px`,
    display: 'flex', alignItems: 'center', gap: 12,
  }}>{children}</div>
);

// ============================================================================
// FOH_Simple — P1 · counter mode (Lebu Fresh)
//   Direct order entry, photo-tile grid, receipt-only at the end.
// ============================================================================

const SIMPLE_ITEMS = [
  { n: 'Lemon Mint',   bn: '', p: 60,  tone: '#EAF4EE' },
  { n: 'Lebu Soda',    bn: '',  p: 50,  tone: '#FFF3E0' },
  { n: 'Ginger Lemon', bn: '',   p: 70,  tone: '#FBE4DB' },
  { n: 'Plain Lebu',   bn: '',       p: 40,  tone: '#EAF4EE' },
  { n: 'Cha',          bn: '',         p: 20,  tone: '#FFF9E0' },
  { n: 'Singara',      bn: '',   p: 15,  tone: '#FEF1C5' },
];

const FOH_Simple = () => (
  <div style={{
    position: 'relative', height: '100%', background: DASH.bg, overflow: 'hidden',
    fontFamily: DASH.font, color: DASH.text,
  }}>
    <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', paddingBottom: 70 + 70 }}>
      <UnifiedTopNav
        title="New order"
        sub="Lebu Fresh · Dhanmondi"
        mode="foodcart"
      />

      {/* Category chips */}
      <Section top={4}>
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', scrollbarWidth: 'none' }}>
          <FOHChip label="All" count={12} on />
          <FOHChip label="Juices" count={4} />
          <FOHChip label="Cha" count={3} />
          <FOHChip label="Snacks" count={5} />
        </div>
      </Section>

      {/* Item grid · 2-col photo tiles */}
      <Section top={14}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {SIMPLE_ITEMS.map((it, i) => (
            <div key={i} style={{
              background: DASH.surface, border: `1px solid ${DASH.border}`,
              borderRadius: 12, padding: 10, display: 'flex', flexDirection: 'column', gap: 8,
            }}>
              <div style={{
                height: 72, borderRadius: 8, background: it.tone,
                display: 'grid', placeItems: 'center',
                fontSize: 24, fontWeight: 600, color: DASH.text + 'AA', letterSpacing: -0.5,
              }}>
                {it.n[0]}
              </div>
              <div>
                <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text, lineHeight: 1.15 }}>{it.n}</div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ fontSize: 14, fontWeight: 600, color: DASH.text, ...DASH.num }}>৳{it.p}</span>
                <div style={{
                  width: 28, height: 28, borderRadius: 8,
                  background: DASH.accent, color: DASH.accentInk,
                  display: 'grid', placeItems: 'center',
                }}><InvIcon kind="plus" s={16} /></div>
              </div>
            </div>
          ))}
        </div>
      </Section>
    </div>

    {/* Cart — receipt only at P1 */}
    <FOHCart>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 11, color: DASH.onInkSec, fontFamily: DASH.mono, fontWeight: 600, letterSpacing: 0.5 }}>3 ITEMS · CASH</div>
        <div style={{ fontSize: 20, fontWeight: 600, color: DASH.onInk, marginTop: 2, ...DASH.num }}>৳180</div>
      </div>
      <div style={{
        padding: '10px 16px', height: 48, borderRadius: 10,
        background: DASH.accent, color: DASH.accentInk,
        fontSize: 14, fontWeight: 700,
        display: 'inline-flex', alignItems: 'center', gap: 8,
      }}>
        <InvIcon kind="check" s={16} />
        Charge &amp; print
      </div>
    </FOHCart>

    <DashBottomNav active={0} />
  </div>
);

// ============================================================================
// FOH_Standard — P2 · dine-in with table + waiter (Cha Ghor)
//   Table selected, waiter tagged, items added, sent to kitchen.
// ============================================================================

const STD_TABLES = [
  { n: 1, s: 'idle' }, { n: 2, s: 'seated' }, { n: 3, s: 'idle' },
  { n: 4, s: 'selected' }, { n: 5, s: 'kitchen' }, { n: 6, s: 'bill' },
];

const STD_MENU = [
  { n: 'Milk Tea (Cha)', bn: '',    p: 30,  cat: 'Cha' },
  { n: 'Lemon Tea',      bn: '',   p: 20,  cat: 'Cha' },
  { n: 'Singara',        bn: '', p: 15,  cat: 'Snacks', qty: 4 },
  { n: 'Samosa',         bn: '',     p: 30,  cat: 'Snacks', qty: 2 },
  { n: 'Egg Toast',      bn: '', p: 25,  cat: 'Snacks' },
];

const FOH_Standard = () => (
  <div style={{
    position: 'relative', height: '100%', background: DASH.bg, overflow: 'hidden',
    fontFamily: DASH.font, color: DASH.text,
  }}>
    <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', paddingBottom: 70 + 74 }}>
      <UnifiedTopNav
        title="New order"
        sub="Cha Ghor · Dhanmondi 27"
        mode="cafe"
      />

      {/* Table strip — compact floor map */}
      <Section top={4}>
        <div style={{
          background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 12,
          padding: '10px 12px',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
            <span style={{ fontSize: 10.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase' }}>Tables</span>
            <span style={{ fontSize: 11, color: DASH.textSec, fontWeight: 600 }}>T4 · 2 covers</span>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 6 }}>
            {STD_TABLES.map((t) => {
              const sty = {
                idle:     { bg: DASH.surface,    bd: DASH.border,       fg: DASH.textSec },
                seated:   { bg: DASH.accentSoft, bd: DASH.accent + '55',fg: DASH.accentInk },
                kitchen:  { bg: DASH.goodSoft,   bd: DASH.good + '55',  fg: DASH.good },
                bill:     { bg: DASH.warnSoft,   bd: DASH.warn + '55',  fg: DASH.warn },
                selected: { bg: DASH.ink,        bd: DASH.ink,          fg: DASH.onInk },
              }[t.s];
              return (
                <div key={t.n} style={{
                  background: sty.bg, border: `1px solid ${sty.bd}`, color: sty.fg,
                  borderRadius: 8, padding: '8px 4px', textAlign: 'center',
                  fontSize: 13, fontWeight: 600, ...DASH.num,
                }}>T{t.n}</div>
              );
            })}
          </div>
        </div>
      </Section>

      {/* Waiter attribution */}
      <Section top={10}>
        <div style={{
          background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 12,
          padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <span style={{ fontSize: 10.5, fontFamily: DASH.mono, color: DASH.textTer, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase' }}>Waiter</span>
          <div style={{
            width: 28, height: 28, borderRadius: 14,
            background: DASH.accentSoft, color: DASH.accentInk,
            display: 'grid', placeItems: 'center',
            fontSize: 12, fontWeight: 700,
          }}>A</div>
          <span style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text }}>Anwar</span>
          <span style={{ fontSize: 11, color: DASH.textTer, fontFamily: DASH.mono, ...DASH.num }}>· clocked in 11:42 AM</span>
          <div style={{ flex: 1 }} />
          <span style={{ fontSize: 12, color: DASH.textSec, fontWeight: 600 }}>Change</span>
        </div>
      </Section>

      {/* Category chips */}
      <Section top={10}>
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', scrollbarWidth: 'none' }}>
          <FOHChip label="All" count={18} on />
          <FOHChip label="Cha" count={6} />
          <FOHChip label="Snacks" count={8} />
          <FOHChip label="Cold" count={4} />
        </div>
      </Section>

      {/* Menu list with qty steppers for items already in cart */}
      <Section top={14}>
        <DashCard padded={false} style={{ overflow: 'hidden' }}>
          {STD_MENU.map((it, i) => (
            <div key={i} style={{
              padding: '12px 14px',
              borderTop: i ? `1px solid ${DASH.divider}` : 'none',
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text }}>{it.n}</div>
                <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 2, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontFamily: DASH.mono, ...DASH.num }}>৳{it.p}</span>
                </div>
              </div>
              {it.qty ? (
                <div style={{
                  display: 'flex', alignItems: 'center', gap: 8,
                  background: DASH.ink, color: DASH.onInk, borderRadius: 8, padding: '4px 6px',
                }}>
                  <div style={{ width: 24, height: 24, display: 'grid', placeItems: 'center' }}><InvIcon kind="minus" s={14} /></div>
                  <span style={{ fontSize: 13, fontWeight: 700, minWidth: 14, textAlign: 'center', ...DASH.num }}>{it.qty}</span>
                  <div style={{ width: 24, height: 24, display: 'grid', placeItems: 'center' }}><InvIcon kind="plus" s={14} /></div>
                </div>
              ) : (
                <div style={{
                  width: 36, height: 36, borderRadius: 10,
                  background: DASH.accent, color: DASH.accentInk,
                  display: 'grid', placeItems: 'center',
                }}><InvIcon kind="plus" s={18} /></div>
              )}
            </div>
          ))}
        </DashCard>
      </Section>
    </div>

    {/* Cart footer — send to kitchen */}
    <FOHCart>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 11, color: DASH.onInkSec, fontFamily: DASH.mono, fontWeight: 600, letterSpacing: 0.5 }}>
          6 ITEMS · T4 · ANWAR
        </div>
        <div style={{ fontSize: 20, fontWeight: 600, color: DASH.onInk, marginTop: 2, ...DASH.num }}>৳180</div>
      </div>
      <div style={{
        padding: '10px 16px', height: 48, borderRadius: 10,
        background: DASH.accent, color: DASH.accentInk,
        fontSize: 14, fontWeight: 700,
        display: 'inline-flex', alignItems: 'center', gap: 8,
      }}>
        Send to kitchen
        <InvIcon kind="chevronRight" s={16} />
      </div>
    </FOHCart>

    <DashBottomNav active={0} />
  </div>
);

// ============================================================================
// FOH_Advanced — P3 · full-service (Spice Garden)
//   Table + covers + waiter context · live order card with modifier badges +
//   dietary tags + kitchen-sent markers · discount with reason · comp tracking.
// ============================================================================

const Tag = ({ label, tone = 'neutral' }) => {
  const styles = {
    halal:   { bg: DASH.goodSoft,   c: DASH.good   },
    veg:     { bg: DASH.goodSoft,   c: DASH.good   },
    spicy:   { bg: DASH.lateSoft,   c: DASH.late   },
    nut:     { bg: DASH.warnSoft,   c: DASH.warn   },
    neutral: { bg: DASH.surfaceAlt, c: DASH.textSec},
  };
  const s = styles[tone] || styles.neutral;
  return (
    <span style={{
      padding: '1px 6px', borderRadius: 4,
      background: s.bg, color: s.c,
      fontSize: 9.5, fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.5,
      textTransform: 'uppercase',
    }}>{label}</span>
  );
};

const ADV_LINES = [
  {
    n: 'Beef Tehari', bn: '', qty: 2, price: 900,
    mods: ['no onion', 'extra raita'],
    tags: [{ l: 'Halal', t: 'halal' }],
    sent: '7:48 PM',
  },
  {
    n: 'Mutton Roast', bn: '', qty: 1, price: 400,
    mods: ['medium spicy'],
    tags: [{ l: 'Halal', t: 'halal' }, { l: 'Nut', t: 'nut' }],
    sent: '7:48 PM',
  },
  {
    n: 'Borhani', bn: '', qty: 4, price: 200,
    mods: [],
    tags: [{ l: 'Veg', t: 'veg' }],
    sent: null,
  },
];

const FOH_Advanced = () => (
  <div style={{
    position: 'relative', height: '100%', background: DASH.bg, overflow: 'hidden',
    fontFamily: DASH.font, color: DASH.text,
  }}>
    <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', paddingBottom: 70 + 96 }}>
      <UnifiedTopNav
        title="New order"
        sub="Spice Garden · Gulshan 2"
        mode="restaurant"
      />

      {/* Order context strip — table / cover / waiter (was inside the header) */}
      <div style={{
        padding: '2px 16px 8px', display: 'flex', alignItems: 'center', gap: 10,
        fontSize: 12, color: DASH.textSec,
      }}>
        <span style={{ fontWeight: 600, color: DASH.text, letterSpacing: -0.1 }}>Table 12 · 4 covers</span>
        <span style={{ width: 3, height: 3, borderRadius: 2, background: DASH.textTer }} />
        <span style={{ fontFamily: DASH.mono, fontWeight: 600, ...DASH.num }}>seated 7:42 PM</span>
        <div style={{ flex: 1 }} />
        <span style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '4px 8px 4px 4px', borderRadius: 999,
          background: DASH.surface, border: `1px solid ${DASH.border}`,
          fontSize: 11.5, fontWeight: 600, color: DASH.text,
        }}>
          <span style={{
            width: 18, height: 18, borderRadius: 9,
            background: DASH.accentSoft, color: DASH.accentInk,
            display: 'grid', placeItems: 'center',
            fontSize: 9, fontWeight: 700,
          }}>S</span>
          Salim
        </span>
      </div>

      {/* Active order card */}
      <Section top={4}>
        <div style={{ display: 'flex', alignItems: 'baseline', marginBottom: 8, padding: '0 2px' }}>
          <span style={{ fontSize: 10.5, fontFamily: DASH.mono, color: DASH.textSec, fontWeight: 700, letterSpacing: 0.7, textTransform: 'uppercase' }}>Order #2104</span>
          <div style={{ flex: 1 }} />
          <span style={{ fontSize: 11, color: DASH.textTer, fontFamily: DASH.mono, ...DASH.num }}>3 lines · 7 items</span>
        </div>
        <DashCard padded={false} style={{ overflow: 'hidden' }}>
          {ADV_LINES.map((it, i) => (
            <div key={i} style={{
              padding: '12px 14px',
              borderTop: i ? `1px solid ${DASH.divider}` : 'none',
            }}>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
                <span style={{
                  fontSize: 13, fontFamily: DASH.mono, fontWeight: 700, color: DASH.textSec,
                  minWidth: 18, ...DASH.num,
                }}>×{it.qty}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                    <span style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text }}>{it.n}</span>
                    {it.tags.map((tg, j) => <Tag key={j} label={tg.l} tone={tg.t} />)}
                  </div>
                  {it.mods.length > 0 && (
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 6 }}>
                      {it.mods.map((m, j) => (
                        <span key={j} style={{
                          fontSize: 11, color: DASH.accentInk, fontWeight: 600,
                          background: DASH.accentSoft,
                          padding: '2px 7px', borderRadius: 4,
                        }}>+ {m}</span>
                      ))}
                    </div>
                  )}
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text, ...DASH.num }}>৳{it.price}</div>
                  {it.sent ? (
                    <div style={{
                      display: 'inline-flex', alignItems: 'center', gap: 4, marginTop: 6,
                      padding: '2px 7px', borderRadius: 4,
                      background: DASH.goodSoft, color: DASH.good,
                      fontSize: 9.5, fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.5,
                    }}>
                      <InvIcon kind="check" s={10} color={DASH.good} />
                      SENT {it.sent}
                    </div>
                  ) : (
                    <div style={{
                      display: 'inline-flex', alignItems: 'center', gap: 4, marginTop: 6,
                      padding: '2px 7px', borderRadius: 4,
                      background: DASH.warnSoft, color: DASH.warn,
                      fontSize: 9.5, fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.5,
                    }}>PENDING</div>
                  )}
                </div>
              </div>
            </div>
          ))}
        </DashCard>
      </Section>

      {/* Add item button */}
      <Section top={10}>
        <div style={{
          padding: '12px 14px', borderRadius: 10,
          background: DASH.surface, border: `1px dashed ${DASH.borderStrong}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          color: DASH.textSec, fontSize: 13, fontWeight: 600,
        }}>
          <InvIcon kind="plus" s={16} />
          Add item
        </div>
      </Section>

      {/* Discount + comp tracking */}
      <Section top={14}>
        <div style={{ display: 'flex', alignItems: 'baseline', marginBottom: 8, padding: '0 2px' }}>
          <span style={{ fontSize: 10.5, fontFamily: DASH.mono, color: DASH.textSec, fontWeight: 700, letterSpacing: 0.7, textTransform: 'uppercase' }}>Adjustments</span>
        </div>
        <DashCard padded={false} style={{ overflow: 'hidden' }}>
          {/* Discount row */}
          <div style={{
            padding: '12px 14px',
            display: 'flex', alignItems: 'center', gap: 12,
          }}>
            <div style={{
              width: 32, height: 32, borderRadius: 8,
              background: DASH.accentSoft, color: DASH.accentInk,
              display: 'grid', placeItems: 'center',
              fontSize: 13, fontWeight: 700,
            }}>%</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text }}>Loyalty discount · 10%</div>
              <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 2, fontFamily: DASH.mono, ...DASH.num }}>
                reason · Card #142 · applied by Salim
              </div>
            </div>
            <div style={{ fontSize: 13, fontWeight: 700, color: DASH.good, ...DASH.num }}>−৳284</div>
          </div>
          {/* Comp row */}
          <div style={{
            padding: '12px 14px',
            borderTop: `1px solid ${DASH.divider}`,
            display: 'flex', alignItems: 'center', gap: 12,
          }}>
            <div style={{
              width: 32, height: 32, borderRadius: 8,
              background: DASH.warnSoft, color: DASH.warn,
              display: 'grid', placeItems: 'center',
              fontSize: 13, fontWeight: 700,
            }}>!</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text }}>1 comp · Naan ×2</div>
              <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 2, fontFamily: DASH.mono, ...DASH.num }}>
                reason · server delay > 18 min
              </div>
            </div>
            <div style={{ fontSize: 13, fontWeight: 700, color: DASH.warn, ...DASH.num }}>−৳120</div>
          </div>
        </DashCard>
      </Section>
    </div>

    {/* Cart footer — bill summary + 2 actions */}
    <FOHCart padding={14}>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 11, color: DASH.onInkSec, fontFamily: DASH.mono, fontWeight: 600, letterSpacing: 0.5 }}>
          SUBTOTAL ৳2,960 · −৳404
        </div>
        <div style={{ fontSize: 22, fontWeight: 600, color: DASH.onInk, marginTop: 2, ...DASH.num }}>৳2,556</div>
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <div style={{
          padding: '10px 14px', height: 48, borderRadius: 10,
          background: 'transparent', border: `1px solid ${DASH.onInkSec}`,
          color: DASH.onInk, fontSize: 13, fontWeight: 600,
          display: 'inline-flex', alignItems: 'center', gap: 6,
        }}>
          Print bill
        </div>
        <div style={{
          padding: '10px 14px', height: 48, borderRadius: 10,
          background: DASH.accent, color: DASH.accentInk,
          fontSize: 13, fontWeight: 700,
          display: 'inline-flex', alignItems: 'center', gap: 6,
        }}>
          Send pending
          <InvIcon kind="chevronRight" s={16} />
        </div>
      </div>
    </FOHCart>

    <DashBottomNav active={0} />
  </div>
);

Object.assign(window, { FOH_Simple, FOH_Standard, FOH_Advanced });
