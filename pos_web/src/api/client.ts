// Thin fetch wrapper over the FastAPI backend.
// Prod: same origin (app is served at /pos/*). Dev: set VITE_API_BASE.

import type {
  ApiEnvelope, AuthPayload, MenuItemWire, OrderWire, PhoneOtpSendResult,
  PhoneVerifyResult, PosReportWire, PosSettingsWire, PosSettlementLineWire,
  PosShiftWire,
} from './types';

export const API_BASE: string = (import.meta.env.VITE_API_BASE as string | undefined)?.replace(/\/$/, '') ?? '';

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public offline = false,
  ) {
    super(message);
  }
}

let deviceToken: string | null = null;
export function setDeviceToken(token: string | null): void {
  deviceToken = token;
}

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  body?: unknown;
  auth?: boolean;
  signal?: AbortSignal;
}

async function request<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (opts.auth !== false && deviceToken) headers.Authorization = `Bearer ${deviceToken}`;

  let res: Response;
  try {
    res = await fetch(`${API_BASE}${path}`, {
      method: opts.method ?? 'GET',
      headers,
      body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
      signal: opts.signal,
    });
  } catch (e) {
    throw new ApiError(0, e instanceof Error ? e.message : 'Network error', true);
  }

  let payload: ApiEnvelope<T> | null = null;
  try {
    payload = (await res.json()) as ApiEnvelope<T>;
  } catch {
    /* non-JSON body */
  }
  if (!res.ok) {
    const detail =
      (payload as { detail?: string } | null)?.detail ??
      payload?.error ??
      `HTTP ${res.status}`;
    throw new ApiError(res.status, String(detail));
  }
  if (payload?.error) throw new ApiError(res.status, payload.error);
  // Backend wraps success as {data, error:null}; some endpoints return raw JSON.
  return (payload && 'data' in payload ? (payload.data as T) : (payload as unknown as T));
}

// ---------- auth ----------
export const api = {
  login: (serverId: string, usernameOrEmail: string, password: string) =>
    request<AuthPayload>('/admin/login', {
      method: 'POST', auth: false,
      body: { serverId, usernameOrEmail, password },
    }),

  demoManagerLogin: () =>
    request<AuthPayload>('/admin/demo/manager-login', { method: 'POST', auth: false }),

  sendPhoneOtp: (phone: string) =>
    request<PhoneOtpSendResult>('/admin/phone/send-otp', {
      method: 'POST', auth: false, body: { phone },
    }),

  verifyPhoneOtp: (phone: string, code: string) =>
    request<PhoneVerifyResult>('/admin/phone/verify-otp', {
      method: 'POST', auth: false, body: { phone, code },
    }),

  adminAccess: () => request<{ hasAppAccess: boolean; subscriptionStatus?: string }>('/admin/access'),

  // ---------- data pulls ----------
  fetchMenu: (outletId: string) => request<MenuItemWire[]>(`/outlets/${outletId}/menu`),
  fetchOrders: (outletId: string, since?: string) =>
    request<OrderWire[]>(`/outlets/${outletId}/orders${since ? `?since=${encodeURIComponent(since)}` : ''}`),
  fetchPosSettings: (outletId: string) => request<PosSettingsWire>(`/outlets/${outletId}/pos/settings`),
  fetchCurrentShift: (outletId: string) => request<PosShiftWire | null>(`/outlets/${outletId}/pos/shifts/current`),
  fetchPosReport: (outletId: string, days = 1) =>
    request<PosReportWire>(`/outlets/${outletId}/pos/reports?days=${days}`),

  // ---------- mutations ----------
  createOrder: (outletId: string, order: Record<string, unknown>) =>
    request<OrderWire>(`/outlets/${outletId}/orders`, { method: 'POST', body: order }),
  updateOrderStatus: (outletId: string, orderId: string, status: string, updatedAt?: string) =>
    request<OrderWire>(`/outlets/${outletId}/orders/${orderId}/status`, {
      method: 'PATCH', body: { status, updatedAt },
    }),
  updateOrderItems: (outletId: string, orderId: string, body: Record<string, unknown>) =>
    request<OrderWire>(`/outlets/${outletId}/orders/${orderId}/items`, { method: 'PATCH', body }),
  updateOrderDetails: (outletId: string, orderId: string, body: Record<string, unknown>) =>
    request<OrderWire>(`/outlets/${outletId}/orders/${orderId}`, { method: 'PATCH', body }),

  patchPosSettings: (outletId: string, body: Record<string, unknown>) =>
    request<PosSettingsWire>(`/outlets/${outletId}/pos/settings`, { method: 'PATCH', body }),
  openShift: (outletId: string, body: { id: string; openingCash: number; denominations: Record<string, number> }) =>
    request<PosShiftWire>(`/outlets/${outletId}/pos/shifts/open`, { method: 'POST', body }),
  closeShift: (outletId: string, shiftId: string, body: { countedCash: number; denominations: Record<string, number> }) =>
    request<PosShiftWire>(`/outlets/${outletId}/pos/shifts/${shiftId}/close`, { method: 'POST', body }),
  sendKot: (outletId: string, orderId: string, body: { batchId: string; itemIds: string[]; note?: string }) =>
    request<OrderWire>(`/outlets/${outletId}/pos/orders/${orderId}/kot`, { method: 'POST', body }),
  settleOrder: (
    outletId: string, orderId: string,
    body: {
      shiftId: string; discountPresetId?: string | null; customDiscountLabel?: string | null;
      discountAmount: number; serviceChargeRatePercent: number; serviceChargeAmount: number;
      totalAmount: number; settlements: PosSettlementLineWire[];
    },
  ) => request<OrderWire>(`/outlets/${outletId}/pos/orders/${orderId}/settle`, { method: 'POST', body }),
  auditOrder: (outletId: string, orderId: string, body: Record<string, unknown>) =>
    request<OrderWire>(`/outlets/${outletId}/pos/orders/${orderId}/audit`, { method: 'POST', body }),
};

export function wsUrl(outletId: string, token: string): string {
  const base = API_BASE || window.location.origin;
  return `${base.replace(/^http/, 'ws')}/ws/${outletId}?token=${encodeURIComponent(token)}`;
}
