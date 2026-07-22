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

  const back = <button className="btn btn-outline btn-sm ops-back" onClick={() => goOps('home')}>← {t('ops.back', lang)}</button>;

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
        <h2>{t('ops.title', lang)}</h2>
        <span className="ops-outlet">{session.outletName} · {t('ops.masterBilling', lang)}</span>
      </div>
      <div className="ops-grid">
        {isManager && (
          <>
            <button className="ops-tile card" onClick={() => goOps('dashboard')}>
              <span className="ops-tile-icon">📊</span>
              <span>{t('ops.dashboard', lang)}</span>
            </button>
            <button className="ops-tile card" onClick={() => goOps('analytics')}>
              <span className="ops-tile-icon">📈</span>
              <span>{t('ops.analytics', lang)}</span>
            </button>
            <button className="ops-tile card" onClick={() => goOps('reports')}>
              <span className="ops-tile-icon">🧮</span>
              <span>{t('ops.reports', lang)}</span>
            </button>
            <button className="ops-tile card" onClick={() => goOps('menu')}>
              <span className="ops-tile-icon">🍽️</span>
              <span>{t('ops.menu', lang)}</span>
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
                <span>{t('ops.inventory', lang)}</span>
              </button>
            )}
          </>
        )}
        <button className="ops-tile card" onClick={() => goOps('printers')}>
          <span className="ops-tile-icon">🖨️</span>
          <span>{t('ops.printers', lang)}</span>
        </button>
        <button className="ops-tile card" onClick={() => goOps('dayend')}>
          <span className="ops-tile-icon">🌙</span>
          <span>{t('ops.dayEnd', lang)}</span>
        </button>
        <button className="ops-tile card" onClick={() => goOps('dayend')}>
          <span className="ops-tile-icon">💵</span>
          <span>{pos.shift ? t('ops.shiftOpen', lang).replace('{t}', formatTk(pos.shift.openingCash)) : t('ops.openShift', lang)}</span>
        </button>
        <button
          className="ops-tile card"
          onClick={() => sync.flush(session.outletId)}
          disabled={sync.replaying}
        >
          <span className="ops-tile-icon">🔄</span>
          <span>
            {sync.replaying ? t('ops.syncing', lang) : sync.queued > 0 ? t('ops.syncNow', lang).replace('{n}', String(sync.queued)) : t('ops.allSynced', lang)}
          </span>
        </button>
      </div>

      {(sync.queued > 0 || sync.dead.length > 0) && (
        <section className="card ops-sync">
          <h3>{t('ops.offlineSync', lang)}</h3>
          <p className="ops-sync-line">
            {t('ops.queuedFailed', lang).replace('{q}', String(sync.queued)).replace('{d}', String(sync.dead.length))}
            <button className="btn btn-outline btn-sm" disabled={sync.replaying}
              onClick={() => sync.flush(session.outletId)}>{t('ops.retryNow', lang)}</button>
          </p>
          {sync.dead.map((r) => (
            <div className="ops-dead" key={r.seq}>
              <div>
                <span className="ops-dead-kind">{r.op.kind}</span>
                <span className="ops-dead-err">{r.lastError ?? t('ops.rejectedByServer', lang)}</span>
              </div>
              <button className="btn btn-danger-outline btn-sm" onClick={() => sync.discardDead(r.seq)}>{t('ops.discard', lang)}</button>
            </div>
          ))}
        </section>
      )}
    </div>
  );
}
