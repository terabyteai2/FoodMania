// Thin fetch wrapper over the FastAPI backend.
// Prod: same origin (app is served at the site root). Dev: set VITE_API_BASE.

import type {
  AdminAccessResult, AnalyticsInsightsWire, AnalyticsItemDetailWire, AnalyticsRange,
  AnalyticsSummaryWire, ApiEnvelope, AuthPayload,
  BlockingNotice, BlockingNoticeRespondRequest, UpgradeInfo,
  DailyStockCountPayload, DailyStockCountResult, DashboardSummaryWire,
  InventoryDailyReportWire, InventoryItemPayload,
  InventoryItemWire, InventoryPullWire, InventorySummaryWire, InventorySupplierPayload,
  InventorySupplierWire, MenuItemPayload, MenuItemWire, OrderBucketsWire, OrderWire,
  PerformanceReportWire, PhoneCompleteManagerSignupRequest, PhoneOtpSendResult,
  PhoneVerifyResult, PosReportWire, PosSettingsWire,
  PosSettlementLineWire, PosShiftWire, StaffInviteRespondRequest,
  StockAdjustmentPayload, StockAdjustmentResult,
} from './types';

function qs(params: Record<string, string | number | undefined | null>): string {
  const pairs = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== null && v !== '')
    .map(([k, v]) => `${k}=${encodeURIComponent(String(v))}`);
  return pairs.length ? `?${pairs.join('&')}` : '';
}

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

  completeManagerSignup: (body: PhoneCompleteManagerSignupRequest) =>
    request<AuthPayload>('/admin/phone/complete-manager-signup', {
      method: 'POST', auth: false, body,
    }),

  respondStaffInvite: (body: StaffInviteRespondRequest) =>
    request<AuthPayload>('/admin/staff/invite/respond', {
      method: 'POST', auth: false, body,
    }),

  adminAccess: () => request<AdminAccessResult>('/admin/access'),
  fetchBlockingNotice: () => request<BlockingNotice>('/admin/blocking-notice'),
  respondBlockingNotice: (body: BlockingNoticeRespondRequest) =>
    request<{ ok: boolean }>('/admin/blocking-notice/respond', { method: 'POST', body }),
  fetchUpgradeInfo: () => request<UpgradeInfo>('/admin/subscription/upgrade'),

  // ---------- data pulls ----------
  fetchMenu: (outletId: string) => request<MenuItemWire[]>(`/outlets/${outletId}/menu`),
  fetchOrders: (outletId: string, since?: string) =>
    request<OrderWire[]>(`/outlets/${outletId}/orders${since ? `?since=${encodeURIComponent(since)}` : ''}`),
  fetchPosSettings: (outletId: string) => request<PosSettingsWire>(`/outlets/${outletId}/pos/settings`),
  fetchCurrentShift: (outletId: string) => request<PosShiftWire | null>(`/outlets/${outletId}/pos/shifts/current`),
  fetchPosReport: (outletId: string, days = 1) =>
    request<PosReportWire>(`/outlets/${outletId}/pos/reports?days=${days}`),

  // ---------- Phase B: back-office reads ----------
  fetchDashboardSummary: (outletId: string, asOf?: string) =>
    request<DashboardSummaryWire>(`/outlets/${outletId}/dashboard/summary${qs({ as_of: asOf })}`),
  fetchAnalyticsSummary: (
    outletId: string,
    params: { range: AnalyticsRange; start?: string; end?: string; service?: string; paymentMethod?: string },
  ) =>
    request<AnalyticsSummaryWire>(`/outlets/${outletId}/analytics/summary${qs({
      range: params.range, start: params.start, end: params.end,
      service: params.service, payment_method: params.paymentMethod,
    })}`),
  fetchAnalyticsInsights: (
    outletId: string,
    params: { range: AnalyticsRange; start?: string; end?: string },
  ) =>
    request<AnalyticsInsightsWire>(`/outlets/${outletId}/analytics${qs({
      range: params.range, start: params.start, end: params.end,
    })}`),
  fetchAnalyticsItemDetail: (
    outletId: string,
    menuItemId: string,
    params: { range: AnalyticsRange; start?: string; end?: string },
  ) =>
    request<AnalyticsItemDetailWire>(`/outlets/${outletId}/analytics/item/${encodeURIComponent(menuItemId)}${qs({
      range: params.range, start: params.start, end: params.end,
    })}`),
  fetchOrderBuckets: (outletId: string, range: AnalyticsRange, start?: string, end?: string) =>
    request<OrderBucketsWire>(`/outlets/${outletId}/reports/order-buckets${qs({ range, start, end })}`),
  fetchPerformanceReport: (
    outletId: string,
    params: { granularity?: string; category?: string; start?: string; days?: number },
  ) =>
    request<PerformanceReportWire>(`/outlets/${outletId}/reports/performance${qs({
      granularity: params.granularity, category: params.category, start: params.start, days: params.days,
    })}`),

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
    request<{ eventId: string; action: string }>(
      `/outlets/${outletId}/pos/orders/${orderId}/audit`, { method: 'POST', body },
    ),

  // ---------- Phase B: menu management writes ----------
  // POST /menu is an upsert keyed on `id` — used for both create and edit (send the full,
  // merged MenuItemPayload; backend replaces every field, shortCode only when non-null).
  pushMenuItem: (outletId: string, item: MenuItemPayload) =>
    request<MenuItemWire>(`/outlets/${outletId}/menu`, { method: 'POST', body: item }),
  deleteMenuItem: (outletId: string, itemId: string) =>
    request<{ deleted: boolean }>(`/outlets/${outletId}/menu/${itemId}`, { method: 'DELETE' }),

  // ---------- Phase B3: inventory (owner-only on the backend) ----------
  fetchInventorySummary: (outletId: string, params: { asOf?: string; start?: string; end?: string } = {}) =>
    request<InventorySummaryWire>(`/outlets/${outletId}/inventory/summary${qs({
      as_of: params.asOf, start: params.start, end: params.end,
    })}`),
  pullInventory: (outletId: string, since?: string) =>
    request<InventoryPullWire>(`/outlets/${outletId}/inventory${qs({ since })}`),
  fetchInventoryDailyReport: (outletId: string, date?: string) =>
    request<InventoryDailyReportWire>(`/outlets/${outletId}/inventory/daily-report${qs({ date })}`),
  fetchInventorySuppliers: (outletId: string, includeArchived = false) =>
    request<InventorySupplierWire[]>(`/outlets/${outletId}/inventory/suppliers${qs({
      include_archived: includeArchived ? 'true' : undefined,
    })}`),
  pushInventoryItem: (outletId: string, item: InventoryItemPayload) =>
    request<InventoryItemWire>(`/outlets/${outletId}/inventory/items`, { method: 'POST', body: item }),
  deleteInventoryItem: (outletId: string, itemId: string) =>
    request<{ id: string; deletedAt: string }>(`/outlets/${outletId}/inventory/items/${itemId}`, { method: 'DELETE' }),
  postInventoryAdjustment: (outletId: string, body: StockAdjustmentPayload) =>
    request<StockAdjustmentResult>(`/outlets/${outletId}/inventory/adjustments`, { method: 'POST', body }),
  postDailyStockCount: (outletId: string, body: DailyStockCountPayload) =>
    request<DailyStockCountResult>(`/outlets/${outletId}/inventory/daily-counts`, { method: 'POST', body }),
  saveInventorySupplier: (outletId: string, body: InventorySupplierPayload) =>
    request<InventorySupplierWire>(`/outlets/${outletId}/inventory/suppliers`, { method: 'POST', body }),

  // ---------- account / outlet profile ----------
  updateDisplayName: (displayName: string) =>
    request<{ displayName: string }>('/admin/me', {
      method: 'PATCH', body: { displayName },
    }),

  updateOutletProfile: (body: { restaurantName?: string; phone?: string }) =>
    request<{ restaurantName: string; outletPhone: string | null }>('/admin/outlet-profile', {
      method: 'PATCH', body,
    }),

  updatePublicUrl: (publicSlug: string) =>
    request<{ publicSlug: string; customerMenuUrl: string }>('/admin/public-url', {
      method: 'PATCH', body: { publicSlug },
    }),
};

export function wsUrl(outletId: string, token: string): string {
  const base = API_BASE || window.location.origin;
  return `${base.replace(/^http/, 'ws')}/ws/${outletId}?token=${encodeURIComponent(token)}`;
}
