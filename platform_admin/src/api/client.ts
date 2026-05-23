const API_BASE =
  import.meta.env.VITE_API_BASE_URL?.replace(/\/$/, "") || "";

const TOKEN_KEY = "platform_token";

export function getToken(): string | null {
  return sessionStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  sessionStorage.setItem(TOKEN_KEY, token);
}

export function clearToken(): void {
  sessionStorage.removeItem(TOKEN_KEY);
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

type ApiResponse<T> = { data: T; error: null } | { data?: undefined; error: string };

export async function apiFetch<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  const token = getToken();
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  let res: Response;
  try {
    res = await fetch(`${API_BASE}${path}`, { ...options, headers });
  } catch (networkErr) {
    throw new ApiError(
      `Cannot reach server at ${API_BASE || "/"} — check your connection`,
      0,
    );
  }

  // Parse response body safely — server may return empty body or HTML error pages
  let body: (ApiResponse<T> & { detail?: string }) | null = null;
  try {
    const text = await res.text();
    if (text.trim()) {
      body = JSON.parse(text) as ApiResponse<T> & { detail?: string };
    }
  } catch {
    throw new ApiError(`Server returned non-JSON response (HTTP ${res.status})`, res.status);
  }

  if (!res.ok) {
    const msg =
      (body?.error) ||
      (body && typeof body.detail === "string" ? body.detail : undefined) ||
      `HTTP ${res.status}: ${res.statusText}`;
    throw new ApiError(msg, res.status);
  }

  if (body?.error) {
    throw new ApiError(body.error, res.status);
  }

  return (body?.data ?? undefined) as T;
}

// ── Core types ────────────────────────────────────────────────────────────────

export type PlatformAdmin = {
  id: string;
  email: string;
  displayName: string | null;
  role: string;
  isActive?: boolean;
  createdAt?: string;
};

export type Outlet = {
  id: string;
  restaurantId: string;
  restaurantName?: string;
  name: string;
  serverId: string;
  publicSlug?: string | null;
  status: string;
  notes: string | null;
  customerMenuUrl: string;
  createdAt: string;
  subscription?: Subscription | null;
};

export type Subscription = {
  id: string;
  outletId: string;
  outletName?: string;
  restaurantName?: string;
  plan: string;
  status: string;
  startsAt: string;
  expiresAt: string | null;
  lastPaymentSessionId: string | null;
  updatedAt: string;
};

export type AdminAccount = {
  id: string;
  outletId: string;
  email: string;
  username: string;
  phone: string | null;
  role: string;
  displayName: string | null;
  authProvider: string;
  isActive: boolean;
  inviteStatus: string | null;
  createdAt: string;
};

export type Activation = {
  outletId: string;
  outletName: string;
  restaurantName: string;
  serverId: string;
  managerEmail: string | null;
  managerPhone: string | null;
  plan: string;
  status: string;
  hasAppAccess: boolean;
  createdAt: string;
  requestedAt: string;
};

export type Payment = {
  paymentId: string;
  gateway: string;
  outletId: string | null;
  outletName: string | null;
  restaurantName: string | null;
  serverId: string;
  amount: number;
  currency: string;
  purpose: string;
  plan: string | null;
  status: string;
  invoiceId: string | null;
  transactionId: string | null;
  createdAt: string;
};

export type Order = {
  id: string;
  outletId: string;
  serialNumber: number;
  source: string;
  status: string;
  totalAmount: number;
  items: unknown[];
  notes: string | null;
  createdAt: string;
  updatedAt: string;
};

export type Stats = {
  restaurants: number;
  outlets: number;
  activeSubscriptions: number;
  pendingActivations: number;
  pendingPayments?: number;
  ordersLast7Days: number;
  mrr: number;
  expiringSoon: number;
  recentOutlets: Outlet[];
  pendingActivationsList?: Activation[];
  recentPayments?: Payment[];
};

export type Restaurant = {
  id: string;
  name: string;
  createdAt: string;
  outlets: Outlet[];
};

// ── Analytics types ───────────────────────────────────────────────────────────

export type Analytics = {
  mrr: number;
  arr: number;
  totalRevenue: number;
  revenueByMonth: { month: string; revenue: number; count: number }[];
  outletsByMonth: { month: string; count: number }[];
  subscriptionBreakdown: Record<string, number>;
  topOutlets: {
    outletId: string;
    outletName: string;
    restaurantName: string;
    totalRevenue: number;
    paymentCount: number;
  }[];
};

// ── Alert types ───────────────────────────────────────────────────────────────

export type Alert = {
  type: string;
  severity: "info" | "warning" | "critical" | "success";
  title: string;
  message: string;
  outletId: string | null;
  meta: Record<string, unknown>;
};

// ── System config types ───────────────────────────────────────────────────────

export type SystemConfig = {
  baseUrl: string;
  uddoktaPayEnabled: boolean;
  uddoktaPaySandbox: boolean;
  bkashEnabled: boolean;
  maintenanceMode: boolean;
  supportEmail: string;
};

export type AppUpdateConfig = {
  enabled: boolean;
  versionName: string;
  versionCode: number;
  apkUrl: string;
  releaseNotes: string;
  required: boolean;
  publishedAt: string | null;
  notifiedOutlets?: number;
};

// ── Health types ──────────────────────────────────────────────────────────────

export type PlatformHealth = {
  api: string;
  database: string;
  storageMode: string;
  baseUrl: string;
  uddoktaPayConfigured: boolean;
  restaurants: number;
  outlets: number;
  ordersLast24h: number;
  checkedAt: string;
};

// ── Outlet activity types ─────────────────────────────────────────────────────

export type OutletActivity = {
  outletId: string;
  totalOrders: number;
  ordersLast30Days: number;
  lastOrderAt: string | null;
  accountCount: number;
  deviceCount: number;
  totalRevenue: number;
};
