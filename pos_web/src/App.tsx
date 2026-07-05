import { useSession } from './state/session';
import { Login } from './screens/Login';
import { Shell } from './screens/Shell';
import { t } from './i18n/strings';

export function App() {
  const { session, lang, logout } = useSession();
  const path = window.location.pathname;

  if (!session) {
    if (path === '/login') return <Login />;
    window.location.href = '/landing/';
    return null;
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
