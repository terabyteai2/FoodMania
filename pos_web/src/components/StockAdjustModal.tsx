// Stock movement for a single raw material: Stock-in (restock), Usage, Waste, or an
// end-of-day Count. Restock/usage/waste post an adjustment (signed delta); Count posts
// a daily stock count (absolute quantity) on the Bangladesh business date.
import { useState } from 'react';
import { Modal } from './Modal';
import { adjustmentDelta, todayBdtDate } from '../core/inventory';
import type {
  AdjustmentType, DailyStockCountPayload, InventorySupplierWire, StockAdjustmentPayload,
} from '../api/types';

export type AdjustMode = AdjustmentType | 'count';

interface Props {
  item: { id: string; name: string; unit: string; onHand: number };
  mode: AdjustMode;
  suppliers: InventorySupplierWire[];
  onClose: () => void;
  onAdjust: (payload: StockAdjustmentPayload) => Promise<void>;
  onCount: (payload: DailyStockCountPayload) => Promise<void>;
}

const MODES: { key: AdjustMode; label: string }[] = [
  { key: 'restock', label: 'Stock-in' },
  { key: 'usage', label: 'Usage' },
  { key: 'waste', label: 'Waste' },
  { key: 'count', label: 'Count' },
];

export function StockAdjustModal({ item, mode: initialMode, suppliers, onClose, onAdjust, onCount }: Props) {
  const [mode, setMode] = useState<AdjustMode>(initialMode);
  const [qty, setQty] = useState('');
  const [cost, setCost] = useState('');
  const [supplierId, setSupplierId] = useState('');
  const [billRef, setBillRef] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const qtyNum = Number(qty);
  const qtyValid = Number.isFinite(qtyNum) && (mode === 'count' ? qtyNum >= 0 : qtyNum > 0);

  const projected = !qtyValid
    ? item.onHand
    : mode === 'restock'
      ? item.onHand + qtyNum
      : mode === 'count'
        ? qtyNum
        : Math.max(0, item.onHand - qtyNum);

  const submit = async () => {
    if (!qtyValid) { setErr(mode === 'count' ? 'Enter the counted quantity.' : 'Enter a quantity greater than zero.'); return; }
    setBusy(true); setErr(null);
    try {
      if (mode === 'count') {
        await onCount({ inventoryItemId: item.id, countDate: todayBdtDate(), quantity: qtyNum });
      } else {
        const payload: StockAdjustmentPayload = {
          inventoryItemId: item.id,
          delta: adjustmentDelta(mode, qtyNum),
          type: mode,
          note: note.trim() || undefined,
        };
        if (mode === 'restock') {
          payload.totalCostBdt = Number(cost) || 0;
          payload.supplierId = supplierId || undefined;
          payload.billRef = billRef.trim() || undefined;
        } else {
          payload.reason = note.trim() || undefined;
        }
        await onAdjust(payload);
      }
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
      setBusy(false);
    }
  };

  return (
    <Modal
      title={`${item.name}`}
      onClose={onClose}
      width={480}
      footer={
        <>
          <button className="btn btn-outline" onClick={onClose} disabled={busy}>Cancel</button>
          <button className="btn btn-primary" onClick={() => void submit()} disabled={busy || !qtyValid}>
            {busy ? 'Saving…' : 'Confirm'}
          </button>
        </>
      }
    >
      <div className="mm-form">
        <div className="inv-mode-seg">
          {MODES.map((m) => (
            <button key={m.key} className={`inv-mode-btn ${mode === m.key ? 'active' : ''}`}
              onClick={() => setMode(m.key)}>{m.label}</button>
          ))}
        </div>

        <label className="field">
          <span>{mode === 'count' ? `Counted on hand (${item.unit})` : mode === 'restock' ? `Quantity added (${item.unit})` : `Quantity used (${item.unit})`}</span>
          <input className="input" type="number" inputMode="decimal" value={qty}
            onChange={(e) => setQty(e.target.value)} autoFocus />
        </label>

        {mode === 'restock' && (
          <>
            <div className="mm-form-row">
              <label className="field"><span>Total cost (৳)</span>
                <input className="input" type="number" inputMode="decimal" value={cost}
                  onChange={(e) => setCost(e.target.value)} placeholder="bill amount" />
              </label>
              <label className="field"><span>Bill / invoice ref</span>
                <input className="input" value={billRef} onChange={(e) => setBillRef(e.target.value)} />
              </label>
            </div>
            <label className="field"><span>Supplier</span>
              <select className="input" value={supplierId} onChange={(e) => setSupplierId(e.target.value)}>
                <option value="">— none —</option>
                {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </label>
          </>
        )}

        {mode !== 'count' && (
          <label className="field"><span>{mode === 'restock' ? 'Note' : 'Reason'}</span>
            <input className="input" value={note} onChange={(e) => setNote(e.target.value)}
              placeholder={mode === 'waste' ? 'e.g. spoilage' : undefined} />
          </label>
        )}

        <div className="inv-projected">
          <span>On hand</span>
          <span><b>{item.onHand}</b> → <b>{Math.round(projected * 1000) / 1000}</b> {item.unit}</span>
        </div>
        {mode === 'restock' && Number(cost) > 0 && qtyValid && (
          <div className="inv-projected sub">
            <span>New cost / {item.unit}</span>
            <span>৳{Math.round((Number(cost) / qtyNum) * 100) / 100}</span>
          </div>
        )}
        {err && <div className="bo-err">{err}</div>}
      </div>
    </Modal>
  );
}
