// Wire types — mirror backend/schemas.py + routers/admin.py payloads (camelCase JSON).

export interface ApiEnvelope<T> {
  data?: T;
  error?: string | null;
}

// ---------- auth ----------
export interface AccountInfo {
  id: string;
  email?: string | null;
  username?: string | null;
  role: string;
  displayName?: string | null;
  phone?: string | null;
}

export interface AuthPayload {
  serverId: string;
  restaurantId: string;
  outletId: string;
  restaurantName: string;
  outletName: string;
  outletPhone?: string | null;
  publicSlug?: string | null;
  customerMenuUrl?: string | null;
  tableCount: number;
  deviceToken: string;
  account: AccountInfo;
  role: string; // owner | manager | waiter
  publicApiBaseUrl?: string | null;
  logoUrl?: string | null;
  logoBitmapUrl?: string | null;
  hasAppAccess?: boolean;
  subscriptionStatus?: string | null;
  subscriptionPlan?: string | null;
  subscriptionExpiresAt?: string | null;
}

export interface PhoneOtpSendResult {
  smsSent: boolean;
  phoneOtpMode?: string | null;
  message?: string | null;
  devOtpCode?: string | null;
  phone?: string | null;
}

export interface PhoneVerifyResult {
  status: string; // "login" | "signup" | "invite" ...
  login?: AuthPayload | null;
  signupToken?: string | null;
  phone?: string | null;
}

// ---------- menu ----------
export interface MenuItemWire {
  id: string;
  name: string;
  nameEn?: string | null;
  nameBn?: string | null;
  description?: string | null;
  descriptionEn?: string | null;
  descriptionBn?: string | null;
  price: number;
  costPrice?: number | null;
  category?: string | null;
  categoryEn?: string | null;
  categoryBn?: string | null;
  isAvailable: boolean;
  imageUrl?: string | null;
  tags?: string[] | null; // "icon:pizza", "option:Large:50", "addon:30:Cheese", "size:...", short-code tag
  version: number;
  updatedAt?: string | null;
  deletedAt?: string | null;
}

// ---------- orders ----------
export type OrderStatus =
  | 'pending' | 'accepted' | 'completed' | 'rejected'
  | 'preparing' | 'ready' | 'served' | 'cancelled'; // legacy read-side
export type ServiceType = 'dine_in' | 'takeaway' | 'delivery';
export type PaymentMethod = 'cash' | 'card' | 'bkash' | 'nagad' | 'pay_later';

export interface OrderLineWire {
  id?: string | null;
  menuItemId?: string | null;
  name: string;
  nameEn?: string | null;
  nameBn?: string | null;
  qty: number;
  price: number;
  lineTotal: number;
  costPriceSnapshot?: number | null;
  note?: string | null;
  kotBatchId?: string | null;
  kotSentAt?: string | null;
}

export interface KotBatchWire {
  batchId: string;
  itemIds: string[];
  note?: string | null;
  createdAt?: string | null;
}

export interface OrderWire {
  id: string;
  serialNumber: number;
  source: string;
  status: OrderStatus;
  totalAmount: number;
  subtotal?: number | null;
  vatRatePercent?: number | null;
  vatAmount?: number | null;
  deliveryCharge?: number | null;
  serviceType?: ServiceType | null;
  covers?: number | null;
  paymentMethod?: PaymentMethod | null;
  tableNo?: string | null;
  items: OrderLineWire[];
  notes?: string | null;
  customerName?: string | null;
  deliveryAddress?: string | null;
  mobileNumber?: string | null;
  createdByAccountId?: string | null;
  createdByRole?: string | null;
  shiftId?: string | null;
  discountLabel?: string | null;
  discountAmount?: number | null;
  serviceChargeRatePercent?: number | null;
  serviceChargeAmount?: number | null;
  billingSnapshot?: Record<string, unknown> | null;
  kotBatches?: KotBatchWire[] | null;
  settledAt?: string | null;
  createdAt?: string | null;
  updatedAt?: string | null;
}

// ---------- POS settings / shift / reports ----------
export interface PosFloorTableWire { id: string; label: string; seats: number; sortOrder: number; }
export interface PosFloorZoneWire { id: string; name: string; sortOrder: number; tables: PosFloorTableWire[]; }
export interface PosDiscountPresetWire { id: string; label: string; kind: 'percent' | 'flat' | 'fixed'; value: number; }

export interface PosSettingsWire {
  floorLayout: PosFloorZoneWire[];
  vatRatePercent: number;
  serviceChargePercent: number;
  discountPresets: PosDiscountPresetWire[];
  tableCount?: number;
  dailySalesTarget?: number | null;
  logoUrl?: string | null;
  logoBitmapUrl?: string | null;
}

export interface PosShiftWire {
  id: string;
  status: string; // open | closed
  openingCash: number;
  expectedCash?: number | null;
  countedCash?: number | null;
  varianceCash?: number | null;
  openingDenominations?: Record<string, number> | null;
  closingDenominations?: Record<string, number> | null;
  openedByAccountId?: string | null;
  closedByAccountId?: string | null;
  openedAt: string;
  closedAt?: string | null;
}

export interface PosSettlementLineWire {
  eventId: string;
  paymentMethod: PaymentMethod | string;
  amount: number;
  payerLabel?: string | null;
}

export interface PosReportWire {
  days: number;
  sales: number;
  orders: number;
  covers: number;
  hourlySales: number[];
  priorSameWeekdayHourlyAverage?: number[] | null;
  coversByHour?: number[] | null;
  paymentSplit: Record<string, number>;
  items: { menuItemId?: string | null; name: string; qty: number; sales: number; margin?: number | null }[];
  staff: { accountId?: string | null; orders: number; sales: number }[];
  auditCounts?: Record<string, number> | null;
}
