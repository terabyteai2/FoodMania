// Shift open / close modal. Open captures the opening float; close captures the
// counted drawer cash — the backend computes expected/variance and returns the
// closed shift (shown to the caller for the day-end summary).

import { useState } from 'react';
import { usePos } from '../state/pos';
import { useSession } from '../state/session';
import type { PosShiftWire } from '../api/types';
import { Modal } from './Modal';
import { DenominationCounter } from './DenominationCounter';

export function ShiftModal({
  mode, onClose, onDone,
}: {
  mode: 'open' | 'close';
  onClose: () => void;
  onDone: (shift?: PosShiftWire) => void;
}) {
  const session = useSession((s) => s.session)!;
  const pos = usePos();
  const [total, setTotal] = useState(0);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const submit = () => {
    setBusy(true);
    setErr(null);
    const run =
      mode === 'open'
        ? pos.openShift(session.outletId, total, counts).then(() => onDone())
        : pos.closeShift(session.outletId, total, counts).then((s) => onDone(s));
    run
      .catch((e: unknown) => setErr(e instanceof Error ? e.message : String(e)))
      .finally(() => setBusy(false));
  };

  return (
    <Modal
      title={mode === 'open' ? 'Open shift' : 'Close shift'} onClose={onClose} width={420}
      footer={
        <button className="btn btn-primary" disabled={busy} onClick={submit}>
          {busy ? 'Working…' : mode === 'open' ? 'Open shift' : 'Close & count drawer'}
        </button>
      }
    >
      <p className="shift-hint">
        {mode === 'open'
          ? 'Count the opening float placed in the cash drawer.'
          : 'Count the cash currently in the drawer to close the shift.'}
      </p>
      <DenominationCounter onChange={(t, c) => { setTotal(t); setCounts(c); }} />
      {err && <div className="error-text">{err}</div>}
    </Modal>
  );
}
