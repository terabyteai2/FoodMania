import { useSession } from './state/session';
import { Login } from './screens/Login';
import { Shell } from './screens/Shell';
import { t } from './i18n/strings';

function OfflineNoSession() {
  const { lang } = useSession();
  return (
    <div style={{ display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center' }}>
      <div className="card" style={{ maxWidth: 400, padding: 32, textAlign: 'center' }}>
        <h2 style={{ marginBottom: 10 }}>{t('appName', lang)}</h2>
        <p style={{ color: 'var(--ink-2)', lineHeight: 1.5 }}>
          {t('offlineNoSession', lang)}
        </p>
        <button className="btn btn-primary" style={{ marginTop: 18 }} disabled>
          {t('offlineRetry', lang)}
        </button>
      </div>
    </div>
  );
}

export function App() {
  const { session, lang, logout } = useSession();
  const path = window.location.pathname;

  if (!session) {
    if (path === '/login') return <Login />;
    if (navigator.onLine) {
      window.location.href = '/landing/';
      return null;
    }
    return <OfflineNoSession />;
  }

  if (path === '/login') {
    window.location.href = '/';
    return null;
  }

  if (session.hasAppAccess === false) {
    return (
      <div style={{ display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center' }}>
        <div className="card" style={{ maxWidth: 440, padding: 28, textAlign: 'center' }}>
          <h3 style={{ marginBottom: 10 }}>{session.outletName}</h3>
          <p style={{ color: 'var(--ink-2)', marginBottom: 18 }}>{t('subscriptionBlocked', lang)}</p>
          <button className="btn btn-outline" onClick={logout}>{t('logout', lang)}</button>
        </div>
      </div>
    );
  }

  return <Shell />;
}
