import { useState } from 'react';
import { useSession } from './state/session';
import { Login } from './screens/Login';
import { Shell } from './screens/Shell';
import { t } from './i18n/strings';
import { ScreenBlocker } from './components/ScreenBlocker';
import { useRegisterSW } from 'virtual:pwa-register/react';

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
  useRegisterSW();
  const { session, lang, blockingNotice, refreshAccess, respondBlockingNotice } = useSession();
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
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

  if (session.hasAppAccess === false || blockingNotice?.enabled) {
    const isOfflineBlocked = !navigator.onLine && session.hasAppAccess === false;

    const handleRetry = async () => {
      if (!navigator.onLine) {
        setError(t('subscriptionExpiredOffline', lang));
        return;
      }
      setRefreshing(true);
      setError(null);
      try {
        await refreshAccess();
      } catch {
        setError(t('screenBlocker.error', lang));
      } finally {
        setRefreshing(false);
      }
    };

    const handleRespond = async (response: string): Promise<boolean> => {
      setError(null);
      try {
        const ok = await respondBlockingNotice(response);
        if (!ok) setError(t('screenBlocker.error', lang));
        return ok;
      } catch {
        setError(t('screenBlocker.error', lang));
        return false;
      }
    };

    return (
      <ScreenBlocker
        notice={blockingNotice || {
          enabled: true,
          title: t(isOfflineBlocked ? 'subscriptionExpiredOffline' : 'subscriptionBlocked', lang),
          message: '',
          imageUrl: null,
          inputField: false,
          inputLabel: null,
          updatedAt: null,
          type: 'subscription',
          ctaLabel: null,
          ctaUrl: null,
          dismissible: false,
        }}
        refreshing={refreshing}
        error={error}
        onRetry={handleRetry}
        onRespond={handleRespond}
      />
    );
  }

  return <Shell />;
}
