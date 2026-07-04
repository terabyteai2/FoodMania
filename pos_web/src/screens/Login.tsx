import { useState } from 'react';
import { api, ApiError } from '../api/client';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';
import './login.css';

type Mode = 'password' | 'otp';

export function Login() {
  const { login, lang, setLang } = useSession();
  const [mode, setMode] = useState<Mode>('password');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // password mode
  const [serverId, setServerId] = useState('');
  const [identity, setIdentity] = useState('');
  const [password, setPassword] = useState('');

  // otp mode
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [otpInfo, setOtpInfo] = useState<string | null>(null);

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

  const submitPassword = () =>
    run(async () => {
      const payload = await api.login(serverId.trim(), identity.trim(), password);
      login(payload);
    });

  const sendOtp = () =>
    run(async () => {
      const res = await api.sendPhoneOtp(phone.trim());
      setOtpSent(true);
      setOtpInfo(res.devOtpCode ? `Dev code: ${res.devOtpCode}` : res.message ?? null);
    });

  const verifyOtp = () =>
    run(async () => {
      const res = await api.verifyPhoneOtp(phone.trim(), code.trim());
      if (res.status === 'login' && res.login) {
        login(res.login);
      } else {
        setError(t('noAccountForPhone', lang));
      }
    });

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

          <h2 className="login-title">{t('signIn', lang)}</h2>

          <div className="login-tabs">
            <button
              className={`login-tab ${mode === 'password' ? 'active' : ''}`}
              onClick={() => { setMode('password'); setError(null); }}
            >{t('password', lang)}</button>
            <button
              className={`login-tab ${mode === 'otp' ? 'active' : ''}`}
              onClick={() => { setMode('otp'); setError(null); }}
            >{t('phoneOtp', lang)}</button>
          </div>

          {mode === 'password' ? (
            <form
              className="login-form"
              onSubmit={(e) => { e.preventDefault(); void submitPassword(); }}
            >
              <div className="field">
                <label>{t('serverId', lang)}</label>
                <input
                  className="input" value={serverId}
                  onChange={(e) => setServerId(e.target.value)}
                  placeholder={t('serverIdHint', lang)} autoFocus
                />
              </div>
              <div className="field">
                <label>{t('usernameOrEmail', lang)}</label>
                <input
                  className="input" value={identity}
                  onChange={(e) => setIdentity(e.target.value)}
                  autoComplete="username"
                />
              </div>
              <div className="field">
                <label>{t('password', lang)}</label>
                <input
                  className="input" type="password" value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                />
              </div>
              {error && <div className="error-text">{error}</div>}
              <button
                className="btn btn-primary login-submit" type="submit"
                disabled={busy || !serverId.trim() || !identity.trim() || !password}
              >
                {busy ? t('loggingIn', lang) : t('signIn', lang)}
              </button>
            </form>
          ) : (
            <form
              className="login-form"
              onSubmit={(e) => { e.preventDefault(); void (otpSent ? verifyOtp() : sendOtp()); }}
            >
              <div className="field">
                <label>{t('phoneNumber', lang)}</label>
                <input
                  className="input" value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="01XXXXXXXXX" inputMode="tel" autoFocus
                />
              </div>
              {otpSent && (
                <div className="field">
                  <label>{t('otpCode', lang)}</label>
                  <input
                    className="input" value={code}
                    onChange={(e) => setCode(e.target.value)}
                    inputMode="numeric" maxLength={6}
                  />
                </div>
              )}
              {otpInfo && <div className="login-otp-info">{otpInfo}</div>}
              {error && <div className="error-text">{error}</div>}
              <button
                className="btn btn-primary login-submit" type="submit"
                disabled={busy || !phone.trim() || (otpSent && code.trim().length < 4)}
              >
                {busy
                  ? t('loggingIn', lang)
                  : otpSent ? t('verify', lang) : t('sendCode', lang)}
              </button>
            </form>
          )}

          {import.meta.env.DEV && (
            <button className="btn btn-outline login-demo" onClick={() => void demo()} disabled={busy}>
              {t('demoLogin', lang)}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
