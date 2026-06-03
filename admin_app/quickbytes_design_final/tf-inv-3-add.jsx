// Terafoods · Inventory · SCREEN 3 — Add Item
// Full-screen form (no modals). 5 stacked sections + sticky bottom CTA.

// Section title — short eyebrow + bn translation, sits above each form group.
const FormSection = ({ n, label, bn, children, top = 18 }) => (
  <div style={{ marginTop: top, padding: '0 16px' }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
      <span style={{
        fontSize: 10, fontFamily: DASH.mono, fontWeight: 700, color: DASH.textTer,
        letterSpacing: 0.8, ...DASH.num,
      }}>{String(n).padStart(2, '0')}</span>
      <span style={{ fontSize: 13, fontWeight: 600, color: DASH.text, letterSpacing: -0.1 }}>{label}</span>
      {bn && <Bn>· {bn}</Bn>}
    </div>
    {children}
  </div>
);

// Two-column row of fields with a small gap.
const FieldRow = ({ children }) => (
  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>{children}</div>
);

// Field label + sunk input wrapper.
const FormField = ({ label, children }) => (
  <div>
    <div style={{ fontSize: 11.5, fontWeight: 600, color: DASH.textSec, marginBottom: 6, marginLeft: 2 }}>{label}</div>
    {children}
  </div>
);

const Inv3_Add = () => (
  <InvScreen
    bottomBar={(
      <InvBottomBar>
        <InvAction variant="accent">Save item</InvAction>
      </InvBottomBar>
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
      title="Add item"
      sub="New SKU · live for tonight's count"
      trailing={null}
    />

    {/* SECTION 1 — Identity */}
    <FormSection n={1} label="Identity" bn="পরিচয়" top={4}>
      <FormField label="Item name">
        {/* Active focus stroke uses ink (1px) — accent reserved for CTA */}
        <div style={{
          height: 48, padding: '0 14px',
          background: DASH.surface, border: `1.5px solid ${DASH.accent}`,
          borderRadius: 10, display: 'flex', alignItems: 'center', gap: 8,
          boxShadow: `0 0 0 3px ${DASH.accentWash}`,
        }}>
          <div style={{ flex: 1, fontSize: 15, color: DASH.text, fontWeight: 600 }}>
            Beef Tehari<span style={{ marginLeft: 1, color: DASH.text }}>|</span>
          </div>
          <Bn>বিফ তেহারি</Bn>
        </div>
      </FormField>
      <div style={{ height: 12 }} />
      <FormField label="Category">
        <div style={{
          height: 48, padding: '0 14px',
          background: DASH.surfaceAlt, border: `1px solid transparent`,
          borderRadius: 10, display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ width: 8, height: 8, borderRadius: 4, background: DASH.accentInk }} />
            <span style={{ fontSize: 15, fontWeight: 600, color: DASH.text }}>Meat</span>
            <Bn>মাংস</Bn>
          </div>
          <span style={{
            fontSize: 11, fontWeight: 600, color: DASH.accentInk,
            display: 'inline-flex', alignItems: 'center', gap: 4, padding: '4px 8px',
            background: DASH.accentWash, borderRadius: 6,
          }}>
            <InvIcon kind="plus" s={12} color={DASH.accentInk} />
            New
          </span>
          <InvIcon kind="chevronDown" s={16} color={DASH.textSec} />
        </div>
      </FormField>
    </FormSection>

    {/* SECTION 2 — Measurement */}
    <FormSection n={2} label="Measurement" bn="পরিমাপ">
      <div style={{
        display: 'flex', gap: 0, padding: 4,
        background: DASH.surfaceAlt, borderRadius: 10,
      }}>
        {['kg', 'gm', 'ltr', 'ml', 'pcs'].map((u, i) => {
          const on = i === 0;
          return (
            <div key={u} style={{
              flex: 1, height: 36, borderRadius: 6,
              background: on ? DASH.surface : 'transparent',
              border: on ? `1px solid ${DASH.borderStrong}` : '1px solid transparent',
              color: on ? DASH.text : DASH.textSec,
              fontSize: 13, fontWeight: 600, fontFamily: DASH.mono,
              display: 'grid', placeItems: 'center',
            }}>{u}</div>
          );
        })}
      </div>
    </FormSection>

    {/* SECTION 3 — Pricing */}
    <FormSection n={3} label="Pricing" bn="দাম">
      <FormField label="Cost price · per kg">
        <InvInput value="320" prefix="৳" suffix="/ kg" numeric align="left" />
      </FormField>
      <div style={{
        marginTop: 8, padding: '8px 12px',
        background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 8,
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <div style={{ width: 24, height: 24, borderRadius: 6, background: DASH.surfaceAlt, color: DASH.textSec, display: 'grid', placeItems: 'center' }}>
          <InvIcon kind="sparkles" s={13} />
        </div>
        <div style={{ flex: 1, fontSize: 11.5, color: DASH.textSec }}>
          Last 3 purchases averaged <span style={{ color: DASH.text, fontWeight: 600, ...DASH.num }}>৳315/kg</span>
        </div>
      </div>
    </FormSection>

    {/* SECTION 4 — Stock constraints */}
    <FormSection n={4} label="Stock constraints" bn="মজুদ সীমা">
      <FieldRow>
        <FormField label="Current stock">
          <InvInput value="3.5" suffix="kg" numeric align="left" />
        </FormField>
        <FormField label="Low-stock at">
          <InvInput value="1.0" suffix="kg" numeric align="left" />
        </FormField>
      </FieldRow>
    </FormSection>

    {/* SECTION 5 — Supplier (accordion, collapsed) */}
    <FormSection n={5} label="Supplier" bn="সরবরাহকারী">
      <div style={{
        background: DASH.surface, border: `1px solid ${DASH.border}`, borderRadius: 14,
        overflow: 'hidden',
      }}>
        {/* Accordion head — collapsed */}
        <div style={{
          padding: '14px 14px',
          display: 'flex', alignItems: 'center', gap: 10,
          borderBottom: `1px solid ${DASH.divider}`,
        }}>
          <div style={{ width: 28, height: 28, borderRadius: 8, background: DASH.surfaceAlt, color: DASH.textSec, display: 'grid', placeItems: 'center' }}>
            <InvIcon kind="truck" s={14} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: DASH.text }}>Karim Goshto · Karwan Bazar</div>
            <div style={{ fontSize: 11, color: DASH.textTer, marginTop: 3, ...DASH.num }}>+880 1712-345 678 · default 5 kg</div>
          </div>
          <InvIcon kind="chevronDown" s={16} color={DASH.textSec} />
        </div>
        {/* Expanded body */}
        <div style={{ padding: '10px 14px 14px' }}>
          <FormField label="Partner name">
            <InvInput value="Karim Goshto" />
          </FormField>
          <div style={{ height: 10 }} />
          <FieldRow>
            <FormField label="Contact">
              <InvInput value="+880 1712-345 678" prefix={<InvIcon kind="phone" s={14} color={DASH.textSec} />} numeric />
            </FormField>
            <FormField label="Default reorder">
              <InvInput value="5" suffix="kg" numeric align="left" />
            </FormField>
          </FieldRow>
        </div>
      </div>
    </FormSection>

    {/* Spacer so nothing sits behind the bottom bar */}
    <div style={{ height: 24 }} />
  </InvScreen>
);

Object.assign(window, { Inv3_Add });
