// Add / edit a raw material (petpooja21 "Add New Raw Material"). Quantity is only
// set here on create — for an existing item, stock changes go through Stock-in /
// Usage / Count so the adjustment history stays truthful.
import { useState } from 'react';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import { Modal } from './Modal';
import { mergeInventoryPayload, UNITS } from '../core/inventory';
import type { InventoryItemPayload, InventoryItemWire, InventorySupplierWire } from '../api/types';

interface Props {
  existing: InventoryItemWire | null; // null = create
  categories: string[];
  suppliers: InventorySupplierWire[];
  onClose: () => void;
  onSave: (payload: InventoryItemPayload) => Promise<void>;
}

export function InventoryItemModal({ existing, categories, suppliers, onClose, onSave }: Props) {
  const lang = useSession((s) => s.lang);
  const [name, setName] = useState(existing?.name ?? '');
  const [category, setCategory] = useState(existing?.category ?? '');
  const [unit, setUnit] = useState(existing?.unit ?? 'pcs');
  const [quantity, setQuantity] = useState(existing ? String(existing.quantity) : '');
  const [minThreshold, setMinThreshold] = useState(existing ? String(existing.minThreshold) : '');
  const [costPerUnit, setCostPerUnit] = useState(existing ? String(existing.costPerUnit) : '');
  const [defaultReorderQty, setDefaultReorderQty] = useState(existing ? String(existing.defaultReorderQty) : '');
  const [defaultSupplierId, setDefaultSupplierId] = useState(existing?.defaultSupplierId ?? '');
  const [notes, setNotes] = useState(existing?.notes ?? '');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const num = (s: string) => { const n = Number(s); return Number.isFinite(n) && n >= 0 ? n : 0; };
  const valid = name.trim().length > 0;

  const submit = async () => {
    if (!valid) { setErr(t('im.enterName', lang)); return; }
    setBusy(true); setErr(null);
    const shared = {
      name: name.trim(),
      category: category.trim() || '',
      unit,
      minThreshold: num(minThreshold),
      costPerUnit: num(costPerUnit),
      defaultReorderQty: num(defaultReorderQty),
      defaultSupplierId: defaultSupplierId || null,
      notes: notes.trim() || '',
    };
    const payload: InventoryItemPayload = existing
      ? mergeInventoryPayload(existing, shared) // quantity preserved
      : {
          id: crypto.randomUUID(),
          quantity: num(quantity),
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          ...shared,
        };
    try {
      await onSave(payload);
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
      setBusy(false);
    }
  };

  return (
    <Modal
      title={existing ? t('im.editMaterial', lang) : t('im.addMaterial', lang)}
      onClose={onClose}
      width={520}
      footer={
        <>
          <button className="btn btn-outline" onClick={onClose} disabled={busy}>{t('cancel', lang)}</button>
          <button className="btn btn-primary" onClick={() => void submit()} disabled={busy || !valid}>
            {busy ? t('save', lang) + '…' : t('save', lang)}
          </button>
        </>
      }
    >
      <div className="mm-form">
        <label className="field"><span>{t('im.materialName', lang)}</span>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} autoFocus
            placeholder={t('im.namePlaceholder', lang)} />
        </label>
        <div className="mm-form-row">
          <label className="field"><span>{t('im.category', lang)}</span>
            <input className="input" list="inv-categories" value={category} onChange={(e) => setCategory(e.target.value)}
              placeholder={t('im.categoryPlaceholder', lang)} />
            <datalist id="inv-categories">{categories.map((c) => <option key={c} value={c} />)}</datalist>
          </label>
          <label className="field"><span>{t('im.unit', lang)}</span>
            <select className="input" value={unit} onChange={(e) => setUnit(e.target.value)}>
              {UNITS.map((u) => <option key={u} value={u}>{u}</option>)}
            </select>
          </label>
        </div>
        <div className="mm-form-row">
          {existing ? (
            <label className="field"><span>{t('im.onHand', lang)}</span>
              <input className="input" value={`${existing.quantity} ${existing.unit}`} disabled
                title={t('im.handHint', lang)} />
            </label>
          ) : (
            <label className="field"><span>{t('im.openingQty', lang)} ({unit})</span>
              <input className="input" type="number" inputMode="decimal" value={quantity}
                onChange={(e) => setQuantity(e.target.value)} />
            </label>
          )}
          <label className="field"><span>{t('im.minThreshold', lang)} ({unit})</span>
            <input className="input" type="number" inputMode="decimal" value={minThreshold}
              onChange={(e) => setMinThreshold(e.target.value)} />
          </label>
        </div>
        <div className="mm-form-row">
          <label className="field"><span>{t('im.costPerUnit', lang)}{unit} (৳)</span>
            <input className="input" type="number" inputMode="decimal" value={costPerUnit}
              onChange={(e) => setCostPerUnit(e.target.value)} />
          </label>
          <label className="field"><span>{t('im.reorderQty', lang)} ({unit})</span>
            <input className="input" type="number" inputMode="decimal" value={defaultReorderQty}
              onChange={(e) => setDefaultReorderQty(e.target.value)} />
          </label>
        </div>
        <label className="field"><span>{t('im.defaultSupplier', lang)}</span>
          <select className="input" value={defaultSupplierId} onChange={(e) => setDefaultSupplierId(e.target.value)}>
            <option value="">{t('im.none', lang)}</option>
            {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </label>
        <label className="field"><span>{t('im.notes', lang)}</span>
          <textarea className="input mm-area" value={notes} onChange={(e) => setNotes(e.target.value)} rows={2} />
        </label>
        {err && <div className="bo-err">{err}</div>}
      </div>
    </Modal>
  );
}
