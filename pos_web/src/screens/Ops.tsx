import { PrinterSettings } from '../components/PrinterSettings';
import { RestaurantSettings } from '../components/RestaurantSettings';
import { TableSettings } from '../components/TableSettings';
import { DayEnd } from './DayEnd';
import { Dashboard } from './Dashboard';
import { Analytics } from './Analytics';
import { Reports } from './Reports';
import { MenuManage } from './MenuManage';
import { Inventory } from './Inventory';
import { useNav } from '../state/nav';
import { usePos } from '../state/pos';
import { useSession } from '../state/session';
import { useSync } from '../state/sync';
import { t } from '../i18n/strings';
import { formatTk } from '../core/money';
import './ops.css';

export function Ops() {
  const pane = useNav((s) => s.opsPane);
  const goOps = useNav((s) => s.goOps);
  const pos = usePos();
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);
  const sync = useSync();
  const isManager = session.role === 'owner' || session.role === 'manager';
  const isOwner = session.role === 'owner';

  const back = <button className="btn btn-outline btn-sm ops-back" onClick={() => goOps('home')}>← Operations</button>;

  if (pane === 'printers') {
    return <div className="ops-root">{back}<PrinterSettings /></div>;
  }
  if (pane === 'restaurant') {
    return <div className="ops-root">{back}<RestaurantSettings /></div>;
  }
  if (pane === 'tablesettings') {
    return <div className="ops-root">{back}<TableSettings /></div>;
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
            <button className="ops-tile card" onClick={() => goOps('dashboard')}>
              <span className="ops-tile-icon">📊</span>
              <span>Dashboard</span>
            </button>
            <button className="ops-tile card" onClick={() => goOps('analytics')}>
              <span className="ops-tile-icon">📈</span>
              <span>Analytics &amp; Tax</span>
            </button>
            <button className="ops-tile card" onClick={() => goOps('reports')}>
              <span className="ops-tile-icon">🧮</span>
              <span>Reports</span>
            </button>
            <button className="ops-tile card" onClick={() => goOps('menu')}>
              <span className="ops-tile-icon">🍽️</span>
              <span>Menu</span>
            </button>
            <button className="ops-tile card" onClick={() => goOps('restaurant')}>
              <span className="ops-tile-icon">🏪</span>
              <span>{t('settingsRestaurantDetails', lang)}</span>
            </button>
            <button className="ops-tile card" onClick={() => goOps('tablesettings')}>
              <span className="ops-tile-icon">🍽️</span>
              <span>{t('settingsTables', lang)}</span>
            </button>
            {isOwner && (
              <button className="ops-tile card" onClick={() => goOps('inventory')}>
                <span className="ops-tile-icon">📦</span>
                <span>Inventory</span>
              </button>
            )}
          </>
        )}
        <button className="ops-tile card" onClick={() => goOps('printers')}>
          <span className="ops-tile-icon">🖨️</span>
          <span>Printers</span>
        </button>
        <button className="ops-tile card" onClick={() => goOps('dayend')}>
          <span className="ops-tile-icon">🌙</span>
          <span>Day End</span>
        </button>
        <button className="ops-tile card" onClick={() => goOps('dayend')}>
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
