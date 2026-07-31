import { create } from 'zustand';
import type { AdminAccessResult, AuthPayload, BlockingNotice } from '../api/types';
import { api, setDeviceToken } from '../api/client';
import type { Lang } from '../i18n/strings';

const STORAGE_KEY = 'qbpos.auth';
const OLD_STORAGE_KEY = 'qbpos.session';
const LANG_KEY = 'qbpos.lang';

const XOR_KEY = '!F0odMan!a@2024#Offline';

function fnv1a32(data: Uint8Array): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < data.length; i++) {
    h ^= data[i];
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h;
}

function encodeSession(payload: AuthPayload): string {
  const json = JSON.stringify(payload);
  const bytes = new TextEncoder().encode(json);
  const hash = fnv1a32(bytes);
  let binary = '';
  binary += String.fromCharCode(hash & 0xFF, (hash >> 8) & 0xFF, (hash >> 16) & 0xFF, (hash >>> 24) & 0xFF);
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i] ^ XOR_KEY.charCodeAt(i % XOR_KEY.length));
  }
  return btoa(binary);
}

function decodeSession(encoded: string): AuthPayload | null {
  try {
    const chars = atob(encoded);
    const len = chars.length;
    if (len < 5) { console.log('[auth] decodeSession: too short len=' + len); return null; }
    const storedHash =
      chars.charCodeAt(0) | (chars.charCodeAt(1) << 8) | (chars.charCodeAt(2) << 16) | (chars.charCodeAt(3) << 24);
    const decBytes = new Uint8Array(len - 4);
    for (let i = 4; i < len; i++) {
      decBytes[i - 4] = chars.charCodeAt(i) ^ XOR_KEY.charCodeAt((i - 4) % XOR_KEY.length);
    }
    const computedHash = fnv1a32(decBytes);
    if (computedHash !== storedHash) {
      console.log('[auth] decodeSession: hash mismatch stored=' + storedHash + ' computed=' + computedHash);
      return null;
    }
    const json = new TextDecoder().decode(decBytes);
    const parsed = JSON.parse(json) as AuthPayload;
    if (!parsed.deviceToken || !parsed.outletId) {
      console.log('[auth] decodeSession: missing deviceToken or outletId');
      return null;
    }
    return parsed;
  } catch (e) {
    console.log('[auth] decodeSession: catch', e);
    return null;
  }
}

function saveSession(payload: AuthPayload) {
  localStorage.setItem(STORAGE_KEY, encodeSession(payload));
}

function loadSession(): AuthPayload | null {
  const oldRaw = localStorage.getItem(OLD_STORAGE_KEY);
  if (oldRaw && !localStorage.getItem(STORAGE_KEY)) {
    try {
      const parsed = JSON.parse(oldRaw) as AuthPayload;
      if (parsed.deviceToken && parsed.outletId) {
        saveSession(parsed);
        localStorage.removeItem(OLD_STORAGE_KEY);
      }
    } catch { }
  }

  const encoded = localStorage.getItem(STORAGE_KEY);
  if (!encoded) {
    console.log('[auth] loadSession: no stored session');
    return null;
  }
  const payload = decodeSession(encoded);
  if (!payload) {
    console.log('[auth] loadSession: decode failed, clearing');
    localStorage.removeItem(STORAGE_KEY);
    return null;
  }

  if (payload.subscriptionExpiresAt) {
    const expiresAt = new Date(payload.subscriptionExpiresAt).getTime();
    if (!isNaN(expiresAt) && expiresAt < Date.now()) {
      console.log('[auth] loadSession: locally expired, hasAppAccess=false');
      payload.hasAppAccess = false;
    }
  }

  console.log('[auth] loadSession: ok outletId=' + payload.outletId + ' hasAppAccess=' + payload.hasAppAccess);
  return payload;
}

const initialSession = loadSession();
if (initialSession) {
  setDeviceToken(initialSession.deviceToken);
}

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

export const useSession = create<SessionState>((set) => ({
  session: initialSession,
  lang: (localStorage.getItem(LANG_KEY) as Lang) || 'en',
  blockingNotice: null,
  subscriptionPrices: {},
  addonPrices: {},

  login: (payload) => {
    console.log('[auth] login: outletId=' + payload.outletId + ' hasAppAccess=' + payload.hasAppAccess);
    saveSession(payload);
    setDeviceToken(payload.deviceToken);
    set({ session: payload });
    api.adminAccess().then((access) => {
      applyAdminAccess(set, access);
      if (!access.hasAppAccess) {
        api.fetchBlockingNotice().then((notice) => set({ blockingNotice: notice }));
      }
    });
  },

  logout: () => {
    console.log('[auth] logout');
    localStorage.removeItem(STORAGE_KEY);
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
    const result = await api.respondBlockingNotice({ response: phone });
    return result.ok;
  },
}));
