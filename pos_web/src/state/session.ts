import { create } from 'zustand';
import type { AdminAccessResult, AuthPayload, BlockingNotice } from '../api/types';
import { api, setDeviceToken } from '../api/client';
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
  blockingNotice: BlockingNotice | null;
  subscriptionPrices: Record<string, number>;
  addonPrices: Record<string, number>;
  login: (payload: AuthPayload) => void;
  logout: () => void;
  setLang: (lang: Lang) => void;
  refreshAccess: () => Promise<void>;
  fetchBlockingNotice: () => Promise<void>;
  respondBlockingNotice: (phone: string) => Promise<boolean>;
}

function applyAdminAccess(set: any, access: AdminAccessResult) {
  const current = useSession.getState().session;
  if (!current) return;
  set({
    session: { ...current, hasAppAccess: access.hasAppAccess },
    subscriptionPrices: access.subscriptionPrices ?? {},
    addonPrices: access.addonPrices ?? {},
  });
  if (access.hasAppAccess) {
    set({ blockingNotice: null });
  }
}

export const useSession = create<SessionState>((set, get) => ({
  session: initialSession,
  lang: (localStorage.getItem(LANG_KEY) as Lang) || 'en',
  blockingNotice: null,
  subscriptionPrices: {},
  addonPrices: {},

  login: (payload) => {
    localStorage.setItem(SESSION_KEY, JSON.stringify(payload));
    setDeviceToken(payload.deviceToken);
    set({ session: payload });
    // background fetch of access + blocking notice
    api.adminAccess().then((access) => applyAdminAccess(set, access));
    api.fetchBlockingNotice().then((notice) => {
      const s = useSession.getState();
      // only set blocking notice if app does not have access
      if (!s.session?.hasAppAccess) {
        set({ blockingNotice: notice });
      }
    });
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

  refreshAccess: async () => {
    const access = await api.adminAccess();
    applyAdminAccess(set, access);
    // re-fetch the blocking notice since access may have changed
    api.fetchBlockingNotice().then((notice) => {
      const s = useSession.getState();
      if (!s.session?.hasAppAccess) {
        set({ blockingNotice: notice });
      } else {
        set({ blockingNotice: null });
      }
    });
  },

  fetchBlockingNotice: async () => {
    const notice = await api.fetchBlockingNotice();
    set({ blockingNotice: notice });
  },

  respondBlockingNotice: async (phone: string) => {
    const result = await api.respondBlockingNotice({ phone });
    return result.ok;
  },
}));
