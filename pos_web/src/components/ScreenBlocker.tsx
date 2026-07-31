import { useRef, useState } from 'react';
import type { BlockingNotice, UpgradeInfo } from '../api/types';
import { useSession } from '../state/session';
import { t, type StringKey } from '../i18n/strings';

const EYEBROW_ICONS: Record<string, string> = {
  subscription: '🔒',
  announcement: '📢',
  paymentLink: '💳',
  adminNotice: '🔒',
};

interface ScreenBlockerProps {
  notice: BlockingNotice;
  upgradeInfo?: UpgradeInfo | null;
  refreshing: boolean;
  error: string | null;
  onRetry: () => void;
  onRespond: (response: string) => Promise<boolean>;
  onDismiss?: () => void;
}

export function ScreenBlocker({ notice, upgradeInfo, refreshing, error, onRetry, onRespond }: ScreenBlockerProps) {
  const { lang, logout, session } = useSession();
  const inputRef = useRef<HTMLInputElement>(null);
  const [responding, setResponding] = useState(false);
  const [checkedAddons, setCheckedAddons] = useState(new Set<string>());

  const EYEBROW_KEYS: Record<string, string> = {
    subscription: 'screenBlocker.eyebrowSubscription',
    announcement: 'screenBlocker.eyebrowAnnouncement',
    paymentLink: 'screenBlocker.eyebrowPaymentLink',
    adminNotice: 'screenBlocker.eyebrowSubscription',
  };

  const rawType = notice.type || 'adminNotice';
  const eyebrowKey = EYEBROW_KEYS[rawType] || 'screenBlocker.eyebrowSubscription';
  const eyebrow = t(eyebrowKey as StringKey, lang);

  const handlePrimary = async () => {
    if (notice.ctaUrl) {
      window.open(notice.ctaUrl, '_blank', 'noopener');
      return;
    }
    if (notice.inputField && inputRef.current) {
      const val = inputRef.current.value.trim();
      if (!val) return;
      setResponding(true);
      await onRespond(val);
      setResponding(false);
      onRetry();
      return;
    }
    onRetry();
  };

  const primaryLabel = notice.ctaLabel || t('refreshAccess', lang);

  const basePrice = upgradeInfo
    ? (upgradeInfo.subscriptionPrices[upgradeInfo.currentPackage] ?? 500)
    : 0;
  let addonTotal = 0;
  if (upgradeInfo) {
    for (const opt of upgradeInfo.addonOptions) {
      if (opt.owned || checkedAddons.has(opt.key)) addonTotal += opt.price;
    }
  }
  const grandTotal = basePrice + addonTotal;
  const showPricing = upgradeInfo && (rawType === 'subscription');

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 9999,
      backgroundColor: 'var(--bg)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <div style={{
        maxWidth: 520, width: '100%', margin: '0 16px',
        backgroundColor: 'var(--surface)',
        border: '1px solid var(--line)', borderRadius: 'var(--r-lg)',
        boxShadow: 'var(--shadow-pop)', padding: 32,
      }}>
        <div style={{
          width: 48, height: 48, borderRadius: 'var(--r-sm)',
          backgroundColor: 'var(--warning)', opacity: 0.12,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          marginBottom: 24,
        }}>
          <span style={{ fontSize: 22, lineHeight: 1 }}>{EYEBROW_ICONS[rawType] || '🔒'}</span>
        </div>

        {notice.imageUrl && (
          <div style={{ marginBottom: 20 }}>
            <img
              src={notice.imageUrl}
              alt=""
              style={{ width: '100%', maxHeight: 220, objectFit: 'contain', borderRadius: 'var(--r-md)' }}
            />
          </div>
        )}

        <p style={{
          fontSize: 11, fontWeight: 600, letterSpacing: 0.77,
          color: 'var(--warning)', marginBottom: 12,
        }}>
          {eyebrow}
        </p>

        {notice.message && (
          <p style={{
            fontSize: 15, fontWeight: 400,
            color: 'var(--ink-2)', lineHeight: 1.55, marginBottom: 8,
          }}>
            {notice.message}
          </p>
        )}

        {notice.title && (
          <h3 style={{
            fontSize: 18, fontWeight: 600,
            color: 'var(--heading)', lineHeight: 1.25, marginBottom: 12,
          }}>
            {notice.title}
          </h3>
        )}

        {showPricing && upgradeInfo.addonOptions.length > 0 && (
          <div style={{ marginBottom: 16 }}>
            <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink-2)', marginBottom: 8 }}>
              Add-ons
            </p>
            {upgradeInfo.addonOptions.map(opt => (
              <label key={opt.key} style={{
                display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0',
              }}>
                <input
                  type="checkbox"
                  checked={opt.owned || checkedAddons.has(opt.key)}
                  disabled={opt.owned}
                  onChange={(e) => {
                    const next = new Set(checkedAddons);
                    if (e.target.checked) next.add(opt.key);
                    else next.delete(opt.key);
                    setCheckedAddons(next);
                  }}
                />
                <span style={{ fontSize: 13, color: 'var(--ink-2)' }}>
                  {opt.label} (৳{opt.price}/mo)
                </span>
                {opt.owned && (
                  <span style={{ color: 'var(--success)', fontSize: 12 }}>
                    Already owned
                  </span>
                )}
              </label>
            ))}
          </div>
        )}

        {showPricing && (
          <>
            <hr style={{ border: 'none', borderTop: '1px solid var(--line)', margin: '8px 0' }} />
            <div style={{
              display: 'flex', justifyContent: 'space-between',
              fontSize: 13, color: 'var(--ink-2)', padding: '4px 0',
            }}>
              <span>Plan ({upgradeInfo.currentPackage.charAt(0).toUpperCase() + upgradeInfo.currentPackage.slice(1)})</span>
              <span style={{ color: 'var(--heading)', fontWeight: 600 }}>৳{basePrice}/mo</span>
            </div>
            {addonTotal > 0 && (
              <div style={{
                display: 'flex', justifyContent: 'space-between',
                fontSize: 13, color: 'var(--ink-2)', padding: '4px 0',
              }}>
                <span>Add-ons</span>
                <span style={{ color: 'var(--heading)', fontWeight: 600 }}>৳{addonTotal}/mo</span>
              </div>
            )}
            <hr style={{ border: 'none', borderTop: '1px solid var(--line)', margin: '8px 0' }} />
            <div style={{
              display: 'flex', justifyContent: 'space-between',
              fontSize: 16, fontWeight: 700, color: 'var(--heading)', padding: '4px 0',
            }}>
              <span>Total</span>
              <span style={{ color: 'var(--success)', fontWeight: 700 }}>৳{grandTotal}/mo</span>
            </div>
          </>
        )}

        <p style={{
          fontSize: 12, fontWeight: 400,
          color: 'var(--muted)', lineHeight: 1.45, marginBottom: 20,
        }}>
          {t('screenBlocker.helper', lang)}
        </p>

        {notice.inputField && (
          <div style={{ marginBottom: 20 }}>
            <input
              ref={inputRef}
              placeholder={notice.inputLabel || ''}
              className="input"
              style={{ height: 44, fontSize: 15 }}
            />
          </div>
        )}

        {error && (
          <div style={{
            padding: '10px 12px', marginBottom: 16,
            borderRadius: 'var(--r-md)',
            backgroundColor: 'var(--danger-soft)',
            color: 'var(--danger)', fontSize: 'var(--fs-12)',
            fontWeight: 500,
          }}>
            {error}
          </div>
        )}

        <button
          className="btn btn-primary"
          style={{ width: '100%', height: 48, fontSize: 15, marginBottom: 12 }}
          disabled={refreshing || responding}
          onClick={handlePrimary}
        >
          {refreshing || responding ? t('loggingIn', lang) : primaryLabel}
        </button>

        {notice.dismissible && (
          <button
            className="btn btn-outline"
            style={{ width: '100%', height: 48, fontSize: 15 }}
            onClick={onRetry}
          >
            {t('refreshAccess', lang)}
          </button>
        )}

        <div style={{ marginTop: 24, textAlign: 'center' }}>
          <p style={{ fontSize: 12, color: 'var(--muted)', marginBottom: 8 }}>
            {session?.outletName}
          </p>
          <button
            className="btn btn-sm btn-outline"
            onClick={logout}
          >
            {t('logout', lang)}
          </button>
        </div>
      </div>
    </div>
  );
}
