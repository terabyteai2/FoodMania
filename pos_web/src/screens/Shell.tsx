import { useEffect, useRef, useState } from 'react';
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
import { VoiceAgent } from './VoiceAgent';
import { SarvamVoiceAgent } from './SarvamVoiceAgent';
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
  const opsPane = useNav((s) => s.opsPane);
  const go = useNav((s) => s.go);
  const goOps = useNav((s) => s.goOps);
  const [online, setOnline] = useState(navigator.onLine);
  const loadMenu = useMenu((s) => s.load);
  const loadPos = usePos((s) => s.load);
  const clearCart = useCart((s) => s.clear);
  const orders = useOrders();
  const sync = useSync();
  const settings = usePos((s) => s.settings);
  const isCounter = settings?.tableCount === 0;
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const hoverTimer = useRef<number>();
  const [sidebarHover, setSidebarHover] = useState(false);
  const sidebarVisible = sidebarOpen || sidebarHover;

  const openHover = () => {
    if (hoverTimer.current) clearTimeout(hoverTimer.current);
    setSidebarHover(true);
  };
  const closeHover = () => {
    hoverTimer.current = window.setTimeout(() => setSidebarHover(false), 200);
  };

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
          <button className="topbar-menu-btn" onClick={() => setSidebarOpen((o) => !o)}>
            <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor"><path d="M4 18h16c.55 0 1-.45 1-1s-.45-1-1-1H4c-.55 0-1 .45-1 1s.45 1 1 1zm0-5h16c.55 0 1-.45 1-1s-.45-1-1-1H4c-.55 0-1 .45-1 1s.45 1 1 1zM3 7c0 .55.45 1 1 1h16c.55 0 1-.45 1-1s-.45-1-1-1H4c-.55 0-1 .45-1 1z"/></svg>
          </button>
          <div className="topbar-brand-titles">
            <span className="topbar-logo"><span className="topbar-logo-volt">Volt</span> <span className="topbar-logo-pos">POS</span></span>
            <span className="topbar-restaurant">{session.restaurantName}</span>
          </div>
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

        <button
          className={`topbar-nav-btn${section === 'ops' && opsPane === 'printers' ? ' active' : ''}`}
          title={t('ops.printers', lang)}
          onClick={() => goOps('printers')}
        >
          <span className="topbar-nav-icon">
            <svg viewBox="0 0 24 24" width="17" height="17" fill="currentColor"><path d="M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z"/></svg>
          </span>
          <span className="topbar-nav-label">{t('ops.printers', lang)}</span>
        </button>

        <div className="topbar-right">
          {sync.queued > 0 && (
            <span className="topbar-sync" title={t('shell.writesQueued', lang)}>
              ⇅ {sync.queued}{sync.replaying ? '…' : ''}
            </span>
          )}
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
        <div className="sidebar-hover-zone" onMouseEnter={openHover} />
        <Sidebar open={sidebarVisible} onMouseEnter={openHover} onMouseLeave={closeHover} />
        <main className="shell-body">
          {section === 'billing' && <Billing />}
          {section === 'tables' && !isCounter && <Tables />}
          {section === 'orders' && <Orders />}
          {section === 'ops' && opsPane === 'voiceagent' && <VoiceAgent />}
          {section === 'ops' && opsPane === 'sarvamvoice' && <SarvamVoiceAgent />}
          {section === 'ops' && opsPane !== 'voiceagent' && opsPane !== 'sarvamvoice' && <Ops />}
        </main>
      </div>
    </div>
  );
}
