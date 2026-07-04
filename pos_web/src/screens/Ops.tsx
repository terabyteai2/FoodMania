// Operations section — petpooja16 icon-hub style, v1 subset: printers + shift status.
// Day-end/report tiles arrive in Phase 3; sync/notifications in Phase 2/4.

import { useState } from 'react';
import { PrinterSettings } from '../components/PrinterSettings';
import { usePos } from '../state/pos';
import { useSession } from '../state/session';
import { formatTk } from '../core/money';
import './ops.css';

type OpsPane = 'home' | 'printers';

export function Ops() {
  const [pane, setPane] = useState<OpsPane>('home');
  const pos = usePos();
  const session = useSession((s) => s.session)!;

  if (pane === 'printers') {
    return (
      <div className="ops-root">
        <button className="btn btn-outline btn-sm ops-back" onClick={() => setPane('home')}>← Operations</button>
        <PrinterSettings />
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
        <div className="ops-tile card ops-tile-static">
          <span className="ops-tile-icon">💵</span>
          <span>{pos.shift ? `Shift open · ${formatTk(pos.shift.openingCash)} float` : 'No open shift'}</span>
        </div>
        <div className="ops-tile card ops-tile-static ops-tile-soon">
          <span className="ops-tile-icon">🌙</span>
          <span>Day End (Phase 3)</span>
        </div>
        <div className="ops-tile card ops-tile-static ops-tile-soon">
          <span className="ops-tile-icon">🔄</span>
          <span>Sync (Phase 4)</span>
        </div>
      </div>
    </div>
  );
}
