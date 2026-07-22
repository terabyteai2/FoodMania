import { useEffect, useState } from 'react';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';

interface BeforeInstallPromptEvent extends Event {
  readonly platforms: string[];
  readonly userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
  prompt(): Promise<void>;
}

export function InstallToast() {
  const { lang } = useSession();
  const [deferred, setDeferred] = useState<BeforeInstallPromptEvent | null>(null);
  const [dismissed, setDismissed] = useState(false);
  const [busy, setBusy] = useState(false);

  const standalone = window.matchMedia('(display-mode: standalone)').matches;

  useEffect(() => {
    if (standalone) return;

    const onPrompt = (e: Event) => {
      e.preventDefault();
      setDeferred(e as unknown as BeforeInstallPromptEvent);
    };
    const onInstalled = () => {
      setDeferred(null);
      setDismissed(true);
    };

    window.addEventListener('beforeinstallprompt' as string, onPrompt);
    window.addEventListener('appinstalled', onInstalled);
    return () => {
      window.removeEventListener('beforeinstallprompt' as string, onPrompt);
      window.removeEventListener('appinstalled', onInstalled);
    };
  }, [standalone]);

  const install = async () => {
    if (!deferred) return;
    setBusy(true);
    deferred.prompt();
    const { outcome } = await deferred.userChoice;
    setBusy(false);
    if (outcome === 'accepted') {
      setDeferred(null);
      setDismissed(true);
    } else {
      setDeferred(null);
    }
  };

  if (standalone || dismissed || !deferred) return null;

  return (
    <div className="install-toast">
      <span className="install-toast-text">{t('installApp', lang)}</span>
      <button className="btn btn-sm install-toast-btn" onClick={install} disabled={busy}>
        {busy ? '…' : t('installBtn', lang)}
      </button>
      <button className="install-toast-close" onClick={() => setDismissed(true)} aria-label={t('installDismiss', lang)}>
        ✕
      </button>
    </div>
  );
}
