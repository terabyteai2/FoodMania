// Terafoods · Inventory · SCREEN 4 — End-of-day count
// AI scan banner + sequential input matrix + floating aggregation drawer + CTA.

// Sequential count row — historic anchor "was X" + numeric modifier + live message.
const CountRow = ({ letter, name, bn, was, unit, entered, status, msg, msgTone, first }) => {
  const tone = {
    good:   { bg: DASH.goodSoft,   color: DASH.good,    bar: DASH.good },
    warn:   { bg: DASH.warnSoft,   color: DASH.warn,    bar: DASH.warn },
    danger: { bg: DASH.dangerSoft, color: DASH.danger,  bar: DASH.danger },
    urgent: { bg: DASH.lateSoft,   color: DASH.late,    bar: DASH.late },
    pending:{ bg: DASH.surfaceAlt, color: DASH.textTer, bar: DASH.borderStrong },
  }[msgTone || 'pending'];
  return (
    <div style={{
      padding: '14px 14px',
      borderTop: first ? 'none' : `1px solid ${DASH.divider}`,
      background: DASH.surface,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <InvAvatar letter={letter} size={36} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.text, lineHeight: 1.2 }}>{name}</div>
          <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3, ...DASH.num }}>
            was <span style={{ fontFamily: DASH.mono, color: DASH.textSec, fontWeight: 600 }}>{was} {unit}</span>
          </div>
        </div>
        {/* Numeric modifier cell */}
        <div style={{
          height: 44, minWidth: 92, padding: '0 10px',
          background: status === 'focus' ? DASH.surface : DASH.surfaceAlt,
          border: `${status === 'focus' ? 1.5 : 1}px solid ${status === 'focus' ? DASH.accent : 'transparent'}`,
          borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 6,
          boxShadow: status === 'focus' ? `0 0 0 3px ${DASH.accentWash}` : 'none',
        }}>
          <span style={{
            fontSize: 18, fontWeight: 600,
            color: entered != null ? DASH.text : DASH.textTer,
            ...DASH.num, letterSpacing: -0.3,
          }}>
            {entered != null ? entered : '—'}
            {status === 'focus' && <span style={{ marginLeft: 1, color: DASH.text }}>|</span>}
          </span>
          <span style={{ fontSize: 11, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 600 }}>{unit}</span>
        </div>
      </div>
      {/* Live reactive message field */}
      <div style={{
        marginTop: 10, marginLeft: 48,
        padding: '7px 10px', borderRadius: 8,
        background: tone.bg, color: tone.color,
        display: 'flex', alignItems: 'center', gap: 6,
      }}>
        <span style={{ width: 4, height: 4, borderRadius: 2, background: tone.color }} />
        <span style={{ fontSize: 11.5, fontWeight: 600, ...DASH.num, letterSpacing: -0.1 }}>{msg}</span>
      </div>
    </div>
  );
};

const Inv4_Count = () => (
  <InvScreen
    padBottom={70 + 96 /* nav + drawer+CTA */}
    bottomBar={(
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 70,
        background: DASH.surface, borderTop: `1px solid ${DASH.border}`,
      }}>
        {/* Aggregation drawer */}
        <div style={{
          padding: '10px 16px',
          background: DASH.surfaceAlt,
          borderBottom: `1px solid ${DASH.divider}`,
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <div style={{
            width: 24, height: 24, borderRadius: 6,
            background: DASH.lateSoft, color: DASH.late,
            display: 'grid', placeItems: 'center',
          }}>
            <InvIcon kind="alertOctagon" s={13} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 11, color: DASH.textTer, fontFamily: DASH.mono, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase' }}>
              Total variance
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
              <span style={{ fontSize: 15, fontWeight: 600, color: DASH.late, ...DASH.num, letterSpacing: -0.2 }}>−0.7 kg</span>
              <span style={{ fontSize: 11, color: DASH.textSec, ...DASH.num }}>· ৳56 loss</span>
            </div>
          </div>
          <span style={{
            fontSize: 10.5, fontFamily: DASH.mono, fontWeight: 700, color: DASH.textSec,
            letterSpacing: 0.5, textTransform: 'uppercase',
            ...DASH.num,
          }}>5 of 8 counted</span>
        </div>
        {/* CTA */}
        <div style={{ padding: '12px 16px' }}>
          <InvAction variant="accent" icon="check">Confirm count</InvAction>
        </div>
      </div>
    )}
  >
    <InvAppBar
      leading={(
        <div style={{
          width: 36, height: 36, borderRadius: 10, background: DASH.surface,
          border: `1px solid ${DASH.border}`, display: 'grid', placeItems: 'center',
        }}>
          <InvIcon kind="back" s={18} />
        </div>
      )}
      title="End-of-day count"
      sub="May 24 · 6:42 PM"
      trailing={null}
    />

    {/* AI Scan Module Banner */}
    <Section top={4}>
      <div style={{
        background: DASH.accentWash, borderRadius: 14,
        border: `1px solid ${DASH.accent}33`,
        padding: '12px 14px',
        display: 'flex', alignItems: 'center', gap: 12,
      }}>
        <div style={{
          width: 36, height: 36, borderRadius: 10,
          background: DASH.accent, color: '#FFF',
          display: 'grid', placeItems: 'center', flexShrink: 0,
        }}>
          <InvIcon kind="sparkles" s={18} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13.5, fontWeight: 600, color: DASH.accentInk, lineHeight: 1.2 }}>
            Scan the shelf
          </div>
          <div style={{ fontSize: 11.5, color: DASH.accentInk, opacity: 0.78, marginTop: 3, lineHeight: 1.35 }}>
            Point camera at storage — auto-fills counts.
          </div>
        </div>
        <div style={{
          height: 36, padding: '0 14px',
          background: DASH.ink, color: DASH.onInk,
          borderRadius: 10,
          display: 'inline-flex', alignItems: 'center', gap: 6,
          fontSize: 13, fontWeight: 600, flexShrink: 0,
        }}>
          <InvIcon kind="camera" s={15} />
          Scan
        </div>
      </div>
    </Section>

    {/* Sequential input matrix */}
    <Section top={14}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 10, padding: '0 2px' }}>
        <Eyebrow>Count each item</Eyebrow>
        <div style={{ flex: 1 }} />
        <Eyebrow color={DASH.textTer}>5 / 8 done</Eyebrow>
      </div>
      <DashCard padded={false} style={{ overflow: 'hidden' }}>
        <CountRow
          first letter="R" name="Rice" bn="চাল" was="13.2" unit="kg"
          entered="12.0" msg="−1.2 kg · matches average use"
          msgTone="good"
        />
        <CountRow
          letter="C" name="Chicken" bn="মুরগি" was="6.7" unit="kg"
          entered="4.2" msg="−2.5 kg · within forecast"
          msgTone="good"
        />
        <CountRow
          letter="M" name="Mutton" bn="খাসি" was="2.6" unit="kg"
          entered="0.8" status="focus"
          msg="−1.8 kg variance · ৳1,980 — verify"
          msgTone="urgent"
        />
        <CountRow
          letter="O" name="Onion" bn="পেঁয়াজ" was="6.7" unit="kg"
          entered="6.0" msg="−0.7 kg · expected"
          msgTone="good"
        />
        <CountRow
          letter="S" name="Soy oil" bn="তেল" was="8.9" unit="ltr"
          entered="8.5" msg="−0.4 ltr · expected"
          msgTone="good"
        />
        <CountRow
          letter="P" name="Potato" bn="আলু" was="4.5" unit="kg"
          entered={null} msg="Awaiting count"
          msgTone="pending"
        />
        <CountRow
          letter="E" name="Eggs" bn="ডিম" was="48" unit="pcs"
          entered={null} msg="Awaiting count"
          msgTone="pending"
        />
        <CountRow
          letter="G" name="Ginger" bn="আদা" was="1.4" unit="kg"
          entered={null} msg="Awaiting count"
          msgTone="pending"
        />
      </DashCard>
    </Section>
  </InvScreen>
);

Object.assign(window, { Inv4_Count });
