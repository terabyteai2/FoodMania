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

  const res = await fetch(`${API_BASE}${path}`, { ...options, headers });
  const body = (await res.json()) as ApiResponse<T> & { detail?: string };

  if (!res.ok) {
    const msg =
      body.error ||
      (typeof body.detail === "string" ? body.detail : undefined) ||
      res.statusText;
    throw new ApiError(msg, res.status);
  }
  if (body.error) {
    throw new ApiError(body.error, res.status);
  }
  return body.data as T;
}

export type PlatformAdmin = {
  id: string;
  email: string;
  displayName: string | null;
  role: string;
};

export type Outlet = {
  id: string;
  restaurantId: string;
  restaurantName?: string;
  name: string;
  serverId: string;
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
  role: string;
  displayName: string | null;
  authProvider: string;
  isActive: boolean;
  createdAt: string;
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
  pendingPayments: number;
  ordersLast7Days: number;
  recentOutlets: Outlet[];
  recentPayments: Payment[];
};

export type Restaurant = {
  id: string;
  name: string;
  createdAt: string;
  outlets: Outlet[];
};
