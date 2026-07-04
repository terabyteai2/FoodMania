import { create } from 'zustand';
import type { AuthPayload } from '../api/types';
import { setDeviceToken } from '../api/client';
import type { Lang } from '../i18n/strings';

const SESSION_KEY = 'qbpos.session';
const LANG_KEY = 'qbpos.lang';

function loadSession(): AuthPayload | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as AuthPayload;
    if (!parsed.deviceToken || !parsed.outletId) return null;
    return parsed;
  } catch {
    return null;
  }
}

const initialSession = loadSession();
if (initialSession) setDeviceToken(initialSession.deviceToken);

interface SessionState {
  session: AuthPayload | null;
  lang: Lang;
  login: (payload: AuthPayload) => void;
  logout: () => void;
  setLang: (lang: Lang) => void;
}

export const useSession = create<SessionState>((set) => ({
  session: initialSession,
  lang: (localStorage.getItem(LANG_KEY) as Lang) || 'en',
  login: (payload) => {
    localStorage.setItem(SESSION_KEY, JSON.stringify(payload));
    setDeviceToken(payload.deviceToken);
    set({ session: payload });
  },
  logout: () => {
    localStorage.removeItem(SESSION_KEY);
    setDeviceToken(null);
    set({ session: null });
  },
  setLang: (lang) => {
    localStorage.setItem(LANG_KEY, lang);
    set({ lang });
  },
}));
