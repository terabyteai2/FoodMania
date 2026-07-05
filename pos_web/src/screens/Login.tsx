import { useState } from 'react';
import { api, ApiError } from '../api/client';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import type { AuthPayload } from '../api/types';
import './login.css';

type Step = 'phone' | 'code' | 'setup' | 'invite' | 'serverIdDisplay';

export function Login() {
  const { login, lang, setLang } = useSession();
  const [step, setStep] = useState<Step>('phone');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // otp flow
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [otpInfo, setOtpInfo] = useState<string | null>(null);
  const [signupToken, setSignupToken] = useState('');

  // setup flow (new restaurant)
  const [restaurantName, setRestaurantName] = useState('');
  const [ownerName, setOwnerName] = useState('');
  const [outletName, setOutletName] = useState('');
  const [tableCount, setTableCount] = useState('10');

  // invite flow
  const [inviteId, setInviteId] = useState('');
  const [inviteRestaurantName, setInviteRestaurantName] = useState('');
  const [inviteOutletName, setInviteOutletName] = useState('');
  const [inviteRole, setInviteRole] = useState('');
  const [invitedBy, setInvitedBy] = useState('');

  // post-signup server ID display
  const [pendingPayload, setPendingPayload] = useState<AuthPayload | null>(null);
  const [copied, setCopied] = useState(false);

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  const sendOtp = () =>
    run(async () => {
      const res = await api.sendPhoneOtp(phone.trim());
      setStep('code');
      setOtpInfo(res.devOtpCode ? `Dev code: ${res.devOtpCode}` : res.message ?? null);
    });

  const verifyOtp = () =>
    run(async () => {
      const res = await api.verifyPhoneOtp(phone.trim(), code.trim());
      if (res.status === 'authenticated') {
        login(res as unknown as AuthPayload);
      } else if (res.status === 'needs_restaurant_setup') {
        setSignupToken(res.signupToken ?? '');
        setStep('setup');
      } else if (res.status === 'pending_staff_invite') {
        setSignupToken(res.signupToken ?? '');
        setInviteId(res.inviteId ?? '');
        setInviteRestaurantName(res.restaurantName ?? '');
        setInviteOutletName(res.outletName ?? '');
        setInviteRole(res.role ?? '');
        setInvitedBy(res.invitedBy ?? '');
        setStep('invite');
      } else {
        setError(t('noAccountForPhone', lang));
      }
    });

  const completeSignup = () =>
    run(async () => {
      const payload = await api.completeManagerSignup({
        signupToken,
        restaurantName: restaurantName.trim(),
        managerName: ownerName.trim() || undefined,
        outletName: outletName.trim() || undefined,
        tableCount: tableCount.trim() ? Number(tableCount) : undefined,
      });
      setPendingPayload(payload);
      setStep('serverIdDisplay');
    });

  const acceptInvite = () =>
    run(async () => {
      const result = await api.respondStaffInvite({ signupToken, inviteId, accept: true });
      login(result as unknown as AuthPayload);
    });

  const declineInvite = () =>
    run(async () => {
      await api.respondStaffInvite({ signupToken, inviteId, accept: false });
      resetToPhone();
    });

  const copyServerId = async () => {
    if (!pendingPayload) return;
    try {
      await navigator.clipboard.writeText(pendingPayload.serverId);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard API unavailable — the Server ID is still shown and selectable.
    }
  };

  const continueToDashboard = () => {
    if (!pendingPayload) return;
    login(pendingPayload);
    window.location.href = '/';
  };

  function resetToPhone() {
    setStep('phone');
    setCode('');
    setOtpInfo(null);
    setSignupToken('');
    setError(null);
  }

  const demo = () =>
    run(async () => {
      const payload = await api.demoManagerLogin();
      login(payload);
    });

  return (
    <div className="login-root">
      <div className="login-brand">
        <div className="login-brand-inner">
          <div className="login-logo">QuickBytes</div>
          <div className="login-tagline">{t('tagline', lang)}</div>
        </div>
      </div>

      <div className="login-panel">
        <div className="login-card card">
          <div className="login-lang">
            <button
              className={`login-lang-btn ${lang === 'en' ? 'active' : ''}`}
              onClick={() => setLang('en')}
            >EN</button>
            <button
              className={`login-lang-btn ${lang === 'bn' ? 'active' : ''}`}
              onClick={() => setLang('bn')}
            >বাংলা</button>
          </div>

          {step === 'phone' && (
            <>
              <h2 className="login-title">{t('signIn', lang)}</h2>
              <form
                className="login-form"
                onSubmit={(e) => { e.preventDefault(); void sendOtp(); }}
              >
                <div className="field">
                  <label>{t('phoneNumber', lang)}</label>
                  <input
                    className="input" value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="01XXXXXXXXX" inputMode="tel" autoFocus
                  />
                </div>
                {error && <div className="error-text">{error}</div>}
                <button
                  className="btn btn-primary login-submit" type="submit"
                  disabled={busy || phone.trim().length < 8}
                >
                  {busy ? t('loggingIn', lang) : t('sendCode', lang)}
                </button>
              </form>
              {import.meta.env.DEV && (
                <button className="btn btn-outline login-demo" onClick={() => void demo()} disabled={busy}>
                  {t('demoLogin', lang)}
                </button>
              )}
            </>
          )}

          {step === 'code' && (
            <>
              <h2 className="login-title">{t('signIn', lang)}</h2>
              <form
                className="login-form"
                onSubmit={(e) => { e.preventDefault(); void verifyOtp(); }}
              >
                <div className="field">
                  <label>{t('phoneNumber', lang)}</label>
                  <input className="input" value={phone} readOnly />
                </div>
                <div className="field">
                  <label>{t('otpCode', lang)}</label>
                  <input
                    className="input" value={code}
                    onChange={(e) => setCode(e.target.value)}
                    inputMode="numeric" maxLength={6} autoFocus
                  />
                </div>
                {otpInfo && <div className="login-otp-info">{otpInfo}</div>}
                {error && <div className="error-text">{error}</div>}
                <button
                  className="btn btn-primary login-submit" type="submit"
                  disabled={busy || code.trim().length < 4}
                >
                  {busy ? t('loggingIn', lang) : t('verify', lang)}
                </button>
                <button
                  type="button" className="btn btn-outline login-demo"
                  onClick={resetToPhone} disabled={busy}
                  style={{ marginTop: 8 }}
                >
                  {t('changePhone', lang)}
                </button>
              </form>
            </>
          )}

          {step === 'setup' && (
            <>
              <h2 className="login-title">{t('createRestaurant', lang)}</h2>
              <form
                className="login-form"
                onSubmit={(e) => { e.preventDefault(); void completeSignup(); }}
              >
                <div className="field">
                  <label>{t('restaurantName', lang)}</label>
                  <input
                    className="input" value={restaurantName}
                    onChange={(e) => setRestaurantName(e.target.value)} autoFocus
                  />
                </div>
                <div className="field">
                  <label>{t('ownerName', lang)}</label>
                  <input
                    className="input" value={ownerName}
                    onChange={(e) => setOwnerName(e.target.value)}
                  />
                </div>
                <div className="field">
                  <label>{t('outletName', lang)}</label>
                  <input
                    className="input" value={outletName}
                    onChange={(e) => setOutletName(e.target.value)}
                    placeholder={t('outletNameHint', lang)}
                  />
                </div>
                <div className="field">
                  <label>{t('tableCount', lang)}</label>
                  <input
                    className="input" type="number" min={0} max={200}
                    value={tableCount} onChange={(e) => setTableCount(e.target.value)}
                  />
                </div>
                {error && <div className="error-text">{error}</div>}
                <button
                  className="btn btn-primary login-submit" type="submit"
                  disabled={busy || !restaurantName.trim()}
                >
                  {busy ? t('creating', lang) : t('create', lang)}
                </button>
              </form>
            </>
          )}

          {step === 'invite' && (
            <>
              <h2 className="login-title">{t('staffInvite', lang)}</h2>
              <div className="login-form">
                <p style={{ marginBottom: 12, lineHeight: 1.5 }}>
                  {t('inviteDescription', lang)}
                </p>
                <div className="field">
                  <label>{t('restaurant', lang)}</label>
                  <div className="input" style={{ fontWeight: 600 }}>{inviteRestaurantName}</div>
                </div>
                {inviteOutletName && (
                  <div className="field">
                    <label>{t('outlet', lang)}</label>
                    <div className="input" style={{ fontWeight: 600 }}>{inviteOutletName}</div>
                  </div>
                )}
                <div className="field">
                  <label>{t('role', lang)}</label>
                  <div className="input" style={{ fontWeight: 600 }}>{inviteRole}</div>
                </div>
                {invitedBy && (
                  <div className="field">
                    <label>{t('invitedBy', lang)}</label>
                    <div className="input" style={{ fontWeight: 600 }}>{invitedBy}</div>
                  </div>
                )}
                {error && <div className="error-text">{error}</div>}
                <button
                  className="btn btn-primary login-submit" type="button"
                  disabled={busy} onClick={() => void acceptInvite()}
                >
                  {busy ? t('accepting', lang) : t('accept', lang)}
                </button>
                <button
                  className="btn btn-outline login-demo" type="button"
                  disabled={busy} onClick={() => void declineInvite()}
                  style={{ marginTop: 8 }}
                >
                  {t('decline', lang)}
                </button>
              </div>
            </>
          )}

          {step === 'serverIdDisplay' && pendingPayload && (
            <>
              <h2 className="login-title">{t('saveServerId', lang)}</h2>
              <div className="login-form">
                <div className="field">
                  <label>{t('serverId', lang)}</label>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <input
                      className="input" value={pendingPayload.serverId} readOnly
                      style={{ fontWeight: 700, letterSpacing: '1px' }}
                    />
                    <button className="btn btn-outline" type="button" onClick={() => void copyServerId()}>
                      {copied ? t('copied', lang) : t('copy', lang)}
                    </button>
                  </div>
                </div>
                <button
                  className="btn btn-primary login-submit" type="button"
                  onClick={continueToDashboard}
                >
                  {t('continueToDashboard', lang)}
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
