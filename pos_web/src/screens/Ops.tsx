// Operations section — petpooja16 icon-hub style, v1 subset: printers, shift + day-end.
// Sync/notifications arrive in Phase 4.

import { useState } from 'react';
import { PrinterSettings } from '../components/PrinterSettings';
import { DayEnd } from './DayEnd';
import { usePos } from '../state/pos';
import { useSession } from '../state/session';
import { useSync } from '../state/sync';
import { formatTk } from '../core/money';
import './ops.css';

type OpsPane = 'home' | 'printers' | 'dayend';

export function Ops() {
  const [pane, setPane] = useState<OpsPane>('home');
  const pos = usePos();
  const session = useSession((s) => s.session)!;
  const sync = useSync();

  if (pane === 'printers') {
    return (
      <div className="ops-root">
        <button className="btn btn-outline btn-sm ops-back" onClick={() => setPane('home')}>← Operations</button>
        <PrinterSettings />
      </div>
    );
  }

  if (pane === 'dayend') {
    return (
      <div className="ops-root ops-root-flush">
        <button className="btn btn-outline btn-sm ops-back" onClick={() => setPane('home')}>← Operations</button>
        <DayEnd />
      </div>
    );
  }

  return (
    <div className="ops-root">
      <div className="ops-header">
        <h2>Operations</h2>
        <span className="ops-outlet">{session.outletName} · Master Billing Station</span>
      </div>
      <div className="ops-grid">
        <button className="ops-tile card" onClick={() => setPane('printers')}>
          <span className="ops-tile-icon">🖨️</span>
          <span>Printers</span>
        </button>
        <button className="ops-tile card" onClick={() => setPane('dayend')}>
          <span className="ops-tile-icon">🌙</span>
          <span>Day End</span>
        </button>
        <button className="ops-tile card" onClick={() => setPane('dayend')}>
          <span className="ops-tile-icon">💵</span>
          <span>{pos.shift ? `Shift open · ${formatTk(pos.shift.openingCash)} float` : 'Open shift'}</span>
        </button>
        <button
          className="ops-tile card"
          onClick={() => sync.flush(session.outletId)}
          disabled={sync.replaying}
        >
          <span className="ops-tile-icon">🔄</span>
          <span>
            {sync.replaying ? 'Syncing…' : sync.queued > 0 ? `Sync now · ${sync.queued} queued` : 'All synced'}
          </span>
        </button>
      </div>

      {(sync.queued > 0 || sync.dead.length > 0) && (
        <section className="card ops-sync">
          <h3>Offline sync</h3>
          <p className="ops-sync-line">
            {sync.queued} queued · {sync.dead.length} failed
            <button className="btn btn-outline btn-sm" disabled={sync.replaying}
              onClick={() => sync.flush(session.outletId)}>Retry now</button>
          </p>
          {sync.dead.map((r) => (
            <div className="ops-dead" key={r.seq}>
              <div>
                <span className="ops-dead-kind">{r.op.kind}</span>
                <span className="ops-dead-err">{r.lastError ?? 'rejected by server'}</span>
              </div>
              <button className="btn btn-danger-outline btn-sm" onClick={() => sync.discardDead(r.seq)}>Discard</button>
            </div>
          ))}
        </section>
      )}
    </div>
  );
}
