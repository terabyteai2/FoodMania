import { useEffect, useState } from 'react';
import { useSession } from '../state/session';
import { useMenu } from '../state/menu';
import { usePos } from '../state/pos';
import { useCart } from '../state/cart';
import { useNav, type NavSection } from '../state/nav';
import { useOrders } from '../state/orders';
import { useSync } from '../state/sync';
import { t, type StringKey } from '../i18n/strings';
import { Billing } from './Billing';
import { Tables } from './Tables';
import { Orders } from './Orders';
import { Ops } from './Ops';
import { InstallToast } from '../components/InstallToast';
import { Sidebar } from '../components/Sidebar';
import './shell.css';

const NAV: { id: NavSection; icon: string; labelKey: string }[] = [
  { id: 'tables', icon: '🍽️', labelKey: 'shell.tables' },
  { id: 'billing', icon: '🧾', labelKey: 'shell.billing' },
  { id: 'orders', icon: '📋', labelKey: 'shell.orders' },
  { id: 'ops', icon: '⚙️', labelKey: 'shell.operations' },
];

export function Shell() {
  const { session, lang, setLang, logout } = useSession();
  const section = useNav((s) => s.section);
  const go = useNav((s) => s.go);
  const [online, setOnline] = useState(navigator.onLine);
  const loadMenu = useMenu((s) => s.load);
  const loadPos = usePos((s) => s.load);
  const clearCart = useCart((s) => s.clear);
  const orders = useOrders();
  const sync = useSync();
  const settings = usePos((s) => s.settings);
  const autoPrint = useCart((s) => s.autoPrint);
  const isCounter = settings?.tableCount === 0;

  useEffect(() => {
    const up = () => {
      setOnline(true);
      const outletId = useSession.getState().session?.outletId;
      if (outletId) void useSync.getState().flush(outletId);
    };
    const down = () => setOnline(false);
    window.addEventListener('online', up);
    window.addEventListener('offline', down);
    return () => {
      window.removeEventListener('online', up);
      window.removeEventListener('offline', down);
    };
  }, []);

  // boot data: menu + POS settings/shift + orders, then open the realtime socket
  useEffect(() => {
    if (!session) return;
    void loadMenu(session.outletId);
    void loadPos(session.outletId);
    void orders.load(session.outletId);
    orders.connect(session.outletId, session.deviceToken);
    // drain anything queued from a previous (offline) session
    void useSync.getState().refreshCounts();
    void useSync.getState().flush(session.outletId);
    return () => orders.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  // flush the outbox whenever the realtime socket (re)connects
  useEffect(() => {
    if (orders.connected && session) void useSync.getState().flush(session.outletId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [orders.connected]);

  // redirect to billing in counter mode
  useEffect(() => {
    if (isCounter && section === 'tables') go('billing');
  }, [isCounter, section, go]);

  // viewing Tables clears the "new online order" badge
  useEffect(() => {
    if (section === 'tables') orders.markSeen();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [section]);

  if (!session) return null;

  const newOrder = () => {
    clearCart();
    go('billing');
  };

  return (
    <div className="shell-root">
      <header className="topbar">
        <div className="topbar-brand">
          <span className="topbar-logo">{t('shell.quickbytes', lang)}</span>
          <span className="topbar-outlet">{session.outletName}</span>
        </div>

        <button className="btn btn-primary topbar-new-order" onClick={newOrder}>
          {t('newOrder', lang)}
        </button>

        <input className="input topbar-billno" placeholder={t('billNo', lang)} />

        <nav className="topbar-nav">
          {NAV.filter((n) => !(n.id === 'tables' && isCounter)).map((n) => (
            <button
              key={n.id}
              className={`topbar-nav-btn ${section === n.id ? 'active' : ''}`}
              title={t(n.labelKey as StringKey, lang)}
              onClick={() => go(n.id)}
            >
              <span className="topbar-nav-icon">{n.icon}</span>
              <span className="topbar-nav-label">{t(n.labelKey as StringKey, lang)}</span>
              {n.id === 'tables' && orders.unseen > 0 && (
                <span className="topbar-nav-badge">{orders.unseen}</span>
              )}
            </button>
          ))}
        </nav>

        <div className="topbar-right">
          {sync.queued > 0 && (
            <span className="topbar-sync" title={t('shell.writesQueued', lang)}>
              ⇅ {sync.queued}{sync.replaying ? '…' : ''}
            </span>
          )}
          <button className="topbar-autoprint" onClick={() => useCart.getState().toggleAutoPrint()}>
            🖨️ {autoPrint ? t('shell.autoPrintOn', lang) : t('shell.autoPrintOff', lang)}
          </button>
          {sync.dead.length > 0 && (
            <button
              className="topbar-sync bad" title={t('shell.failedWrites', lang)}
              onClick={() => go('ops')}
            >⚠ {sync.dead.length}</button>
          )}
          <span className={`topbar-conn ${orders.connected ? 'up' : 'down'}`} title={orders.connected ? t('shell.live', lang) : t('shell.reconnecting', lang)} />
          <button
            className="topbar-lang"
            onClick={() => setLang(lang === 'en' ? 'bn' : 'en')}
          >{lang === 'en' ? 'বাংলা' : 'EN'}</button>
          <span className="topbar-user">{session.account.displayName || session.account.username || session.role}</span>
          <button className="btn btn-outline btn-sm" onClick={logout}>{t('logout', lang)}</button>
        </div>
      </header>

      {!online && <div className="offline-banner">{t('offlineBanner', lang)}</div>}
      <InstallToast />

      <div className="shell-body-row">
        <Sidebar />
        <main className="shell-body">
          {section === 'billing' && <Billing />}
          {section === 'tables' && !isCounter && <Tables />}
          {section === 'orders' && <Orders />}
          {section === 'ops' && <Ops />}
        </main>
      </div>
    </div>
  );
}
