// Operations section — petpooja16 icon-hub style, v1 subset: printers, shift + day-end.
// Sync/notifications arrive in Phase 4.

import { useState } from 'react';
import { PrinterSettings } from '../components/PrinterSettings';
import { DayEnd } from './DayEnd';
import { Dashboard } from './Dashboard';
import { Analytics } from './Analytics';
import { Reports } from './Reports';
import { MenuManage } from './MenuManage';
import { Inventory } from './Inventory';
import { usePos } from '../state/pos';
import { useSession } from '../state/session';
import { useSync } from '../state/sync';
import { formatTk } from '../core/money';
import './ops.css';

type OpsPane = 'home' | 'printers' | 'dayend' | 'dashboard' | 'analytics' | 'reports' | 'menu' | 'inventory';

export function Ops() {
  const [pane, setPane] = useState<OpsPane>('home');
  const pos = usePos();
  const session = useSession((s) => s.session)!;
  const sync = useSync();
  const isManager = session.role === 'owner' || session.role === 'manager';
  const isOwner = session.role === 'owner'; // inventory is owner-only on the backend

  const back = <button className="btn btn-outline btn-sm ops-back" onClick={() => setPane('home')}>← Operations</button>;

  if (pane === 'printers') {
    return <div className="ops-root">{back}<PrinterSettings /></div>;
  }
  if (pane === 'dayend') {
    return <div className="ops-root ops-root-flush">{back}<DayEnd /></div>;
  }
  // Back-office panes (owner/manager only). The child screen owns its own scroll.
  if (isManager && (pane === 'dashboard' || pane === 'analytics' || pane === 'reports' || pane === 'menu')) {
    return (
      <div className="ops-root ops-root-flush">
        {back}
        {pane === 'dashboard' && <Dashboard />}
        {pane === 'analytics' && <Analytics />}
        {pane === 'reports' && <Reports />}
        {pane === 'menu' && <MenuManage />}
      </div>
    );
  }
  if (isOwner && pane === 'inventory') {
    return <div className="ops-root ops-root-flush">{back}<Inventory /></div>;
  }

  return (
    <div className="ops-root">
      <div className="ops-header">
        <h2>Operations</h2>
        <span className="ops-outlet">{session.outletName} · Master Billing Station</span>
      </div>
      <div className="ops-grid">
        {isManager && (
          <>
            <button className="ops-tile card" onClick={() => setPane('dashboard')}>
              <span className="ops-tile-icon">📊</span>
              <span>Dashboard</span>
            </button>
            <button className="ops-tile card" onClick={() => setPane('analytics')}>
              <span className="ops-tile-icon">📈</span>
              <span>Analytics &amp; Tax</span>
            </button>
            <button className="ops-tile card" onClick={() => setPane('reports')}>
              <span className="ops-tile-icon">🧮</span>
              <span>Reports</span>
            </button>
            <button className="ops-tile card" onClick={() => setPane('menu')}>
              <span className="ops-tile-icon">🍽️</span>
              <span>Menu</span>
            </button>
            {isOwner && (
              <button className="ops-tile card" onClick={() => setPane('inventory')}>
                <span className="ops-tile-icon">📦</span>
                <span>Inventory</span>
              </button>
            )}
          </>
        )}
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
