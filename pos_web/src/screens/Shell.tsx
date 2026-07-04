import { useEffect, useState } from 'react';
import { useSession } from '../state/session';
import { useMenu } from '../state/menu';
import { usePos } from '../state/pos';
import { useCart } from '../state/cart';
import { useNav, type NavSection } from '../state/nav';
import { useOrders } from '../state/orders';
import { useSync } from '../state/sync';
import { t } from '../i18n/strings';
import { Billing } from './Billing';
import { Tables } from './Tables';
import { Orders } from './Orders';
import { Ops } from './Ops';
import './shell.css';

const NAV: { id: NavSection; icon: string; labelEn: string; labelBn: string }[] = [
  { id: 'billing', icon: '🧾', labelEn: 'Billing', labelBn: 'বিলিং' },
  { id: 'tables', icon: '🍽️', labelEn: 'Tables', labelBn: 'টেবিল' },
  { id: 'orders', icon: '📋', labelEn: 'Orders', labelBn: 'অর্ডার' },
  { id: 'ops', icon: '⚙️', labelEn: 'Operations', labelBn: 'অপারেশনস' },
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
          <span className="topbar-logo">QuickBytes</span>
          <span className="topbar-outlet">{session.outletName}</span>
        </div>

        <button className="btn btn-primary topbar-new-order" onClick={newOrder}>
          {t('newOrder', lang)}
        </button>

        <input className="input topbar-billno" placeholder={t('billNo', lang)} />

        <nav className="topbar-nav">
          {NAV.map((n) => (
            <button
              key={n.id}
              className={`topbar-nav-btn ${section === n.id ? 'active' : ''}`}
              title={lang === 'bn' ? n.labelBn : n.labelEn}
              onClick={() => go(n.id)}
            >
              <span className="topbar-nav-icon">{n.icon}</span>
              <span className="topbar-nav-label">{lang === 'bn' ? n.labelBn : n.labelEn}</span>
              {n.id === 'tables' && orders.unseen > 0 && (
                <span className="topbar-nav-badge">{orders.unseen}</span>
              )}
            </button>
          ))}
        </nav>

        <div className="topbar-right">
          {sync.queued > 0 && (
            <span className="topbar-sync" title="Writes queued offline — will sync when back online">
              ⇅ {sync.queued}{sync.replaying ? '…' : ''}
            </span>
          )}
          {sync.dead.length > 0 && (
            <button
              className="topbar-sync bad" title="Failed writes — open Operations"
              onClick={() => go('ops')}
            >⚠ {sync.dead.length}</button>
          )}
          <span className={`topbar-conn ${orders.connected ? 'up' : 'down'}`} title={orders.connected ? 'Live' : 'Reconnecting'} />
          <button
            className="topbar-lang"
            onClick={() => setLang(lang === 'en' ? 'bn' : 'en')}
          >{lang === 'en' ? 'বাংলা' : 'EN'}</button>
          <span className="topbar-user">{session.account.displayName || session.account.username || session.role}</span>
          <button className="btn btn-outline btn-sm" onClick={logout}>{t('logout', lang)}</button>
        </div>
      </header>

      {!online && <div className="offline-banner">{t('offline', lang)}</div>}

      <main className="shell-body">
        {section === 'billing' && <Billing />}
        {section === 'tables' && <Tables />}
        {section === 'orders' && <Orders />}
        {section === 'ops' && <Ops />}
      </main>
    </div>
  );
}
