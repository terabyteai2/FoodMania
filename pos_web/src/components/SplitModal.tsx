// Split payment editor — N settlement lines that must sum to the bill total
// (server 422s otherwise, so we validate the same rule here).

import { useMemo, useState } from 'react';
import { Modal } from './Modal';
import type { PaymentMethod, PosSettlementLineWire } from '../api/types';
import { formatTk } from '../core/money';
import { round2 } from '../core/tags';

const METHODS: { id: PaymentMethod; label: string }[] = [
  { id: 'cash', label: 'Cash' },
  { id: 'card', label: 'Card' },
  { id: 'bkash', label: 'bKash' },
  { id: 'nagad', label: 'Nagad' },
  { id: 'pay_later', label: 'Due' },
];

interface SplitRow {
  method: PaymentMethod;
  amount: string;
  payerLabel: string;
}

export function SplitModal(props: {
  total: number;
  onConfirm: (lines: PosSettlementLineWire[]) => void;
  onClose: () => void;
}) {
  const [rows, setRows] = useState<SplitRow[]>([
    { method: 'cash', amount: String(props.total), payerLabel: '' },
  ]);

  const sum = useMemo(
    () => round2(rows.reduce((acc, r) => acc + (Number(r.amount) || 0), 0)),
    [rows],
  );
  const remaining = round2(props.total - sum);

  const update = (i: number, patch: Partial<SplitRow>) =>
    setRows(rows.map((r, idx) => (idx === i ? { ...r, ...patch } : r)));

  const addRow = () =>
    setRows([...rows, { method: 'cash', amount: remaining > 0 ? String(remaining) : '0', payerLabel: '' }]);

  const confirm = () => {
    props.onConfirm(
      rows
        .filter((r) => (Number(r.amount) || 0) > 0)
        .map((r) => ({
          eventId: crypto.randomUUID(),
          paymentMethod: r.method,
          amount: round2(Number(r.amount)),
          payerLabel: r.payerLabel.trim() || null,
        })),
    );
  };

  return (
    <Modal
      title="Split payment"
      onClose={props.onClose}
      width={560}
      footer={
        <>
          <span className={`split-remaining ${remaining === 0 ? 'ok' : 'bad'}`}>
            {remaining === 0 ? `Total ${formatTk(props.total)} ✓` : `Remaining ${formatTk(remaining)}`}
          </span>
          <button className="btn btn-primary" disabled={remaining !== 0 || sum <= 0} onClick={confirm}>
            Settle {formatTk(props.total)}
          </button>
        </>
      }
    >
      <div className="split-rows">
        {rows.map((row, i) => (
          <div className="split-row" key={i}>
            <select
              className="input split-method"
              value={row.method}
              onChange={(e) => update(i, { method: e.target.value as PaymentMethod })}
            >
              {METHODS.map((m) => (
                <option key={m.id} value={m.id}>{m.label}</option>
              ))}
            </select>
            <input
              className="input split-amount" type="number" min="0" step="0.01"
              value={row.amount}
              onChange={(e) => update(i, { amount: e.target.value })}
            />
            <input
              className="input split-payer" placeholder="Payer (optional)"
              value={row.payerLabel}
              onChange={(e) => update(i, { payerLabel: e.target.value })}
            />
            <button
              className="btn btn-outline btn-sm" disabled={rows.length === 1}
              onClick={() => setRows(rows.filter((_, idx) => idx !== i))}
            >✕</button>
          </div>
        ))}
      </div>
      <button className="btn btn-outline btn-sm" onClick={addRow}>+ Add payment</button>
    </Modal>
  );
}
