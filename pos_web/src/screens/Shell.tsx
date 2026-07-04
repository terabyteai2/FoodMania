import { useEffect, useState } from 'react';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import './shell.css';

export type NavSection = 'billing' | 'tables' | 'orders' | 'ops';

const NAV: { id: NavSection; icon: string; labelEn: string; labelBn: string }[] = [
  { id: 'billing', icon: '🧾', labelEn: 'Billing', labelBn: 'বিলিং' },
  { id: 'tables', icon: '🍽️', labelEn: 'Tables', labelBn: 'টেবিল' },
  { id: 'orders', icon: '📋', labelEn: 'Orders', labelBn: 'অর্ডার' },
  { id: 'ops', icon: '⚙️', labelEn: 'Operations', labelBn: 'অপারেশনস' },
];

export function Shell() {
  const { session, lang, setLang, logout } = useSession();
  const [section, setSection] = useState<NavSection>('billing');
  const [online, setOnline] = useState(navigator.onLine);

  useEffect(() => {
    const up = () => setOnline(true);
    const down = () => setOnline(false);
    window.addEventListener('online', up);
    window.addEventListener('offline', down);
    return () => {
      window.removeEventListener('online', up);
      window.removeEventListener('offline', down);
    };
  }, []);

  if (!session) return null;

  return (
    <div className="shell-root">
      <header className="topbar">
        <div className="topbar-brand">
          <span className="topbar-logo">QuickBytes</span>
          <span className="topbar-outlet">{session.outletName}</span>
        </div>

        <button className="btn btn-primary topbar-new-order" onClick={() => setSection('billing')}>
          {t('newOrder', lang)}
        </button>

        <input className="input topbar-billno" placeholder={t('billNo', lang)} />

        <nav className="topbar-nav">
          {NAV.map((n) => (
            <button
              key={n.id}
              className={`topbar-nav-btn ${section === n.id ? 'active' : ''}`}
              title={lang === 'bn' ? n.labelBn : n.labelEn}
              onClick={() => setSection(n.id)}
            >
              <span className="topbar-nav-icon">{n.icon}</span>
              <span className="topbar-nav-label">{lang === 'bn' ? n.labelBn : n.labelEn}</span>
            </button>
          ))}
        </nav>

        <div className="topbar-right">
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
        <div className="shell-placeholder card">
          <h2>{NAV.find((n) => n.id === section)?.[lang === 'bn' ? 'labelBn' : 'labelEn']}</h2>
          <p>{t('comingSoon', lang)}</p>
        </div>
      </main>
    </div>
  );
}
