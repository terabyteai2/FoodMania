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
  addons?: string[];
  subscriptionPrices?: Record<string, number>;
  addonPrices?: Record<string, number>;
}

export interface BlockingNotice {
  enabled: boolean;
  title: string | null;
  message: string | null;
  imageUrl: string | null;
  inputField: boolean;
  inputLabel: string | null;
  updatedAt: string | null;
  type: string | null;
  ctaLabel: string | null;
  ctaUrl: string | null;
  dismissible: boolean;
}

export interface BlockingNoticeRespondRequest {
  response: string;
}

export interface AdminAccessResult {
  hasAppAccess: boolean;
  subscriptionStatus?: string | null;
  subscriptionPlan?: string | null;
  subscriptionPackage?: string | null;
  subscriptionExpiresAt?: string | null;
  addons?: string[];
  subscriptionPrices?: Record<string, number>;
  addonPrices?: Record<string, number>;
}

export interface PhoneOtpSendResult {
  smsSent: boolean;
  phoneOtpMode?: string | null;
  message?: string | null;
  devOtpCode?: string | null;
  phone?: string | null;
}

export interface PhoneVerifyResult {
  status: string; // "authenticated" | "needs_restaurant_setup" | "pending_staff_invite"
  deviceToken?: string | null;
  serverId?: string | null;
  restaurantId?: string | null;
  outletId?: string | null;
  restaurantName?: string | null;
  outletName?: string | null;
  account?: AccountInfo | null;
  role?: string | null;
  tableCount?: number | null;
  signupToken?: string | null;
  inviteId?: string | null;
  invitedBy?: string | null;
  phone?: string | null;
}

export interface PhoneCompleteManagerSignupRequest {
  signupToken: string;
  restaurantName: string;
  managerName?: string;
  outletName?: string;
  serverId?: string;
  outletId?: string;
  tableCount?: number;
}

export interface StaffInviteRespondRequest {
  signupToken: string;
  inviteId: string;
  accept: boolean;
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
  isFavorite?: boolean | null; // backend round-trips this; preserve it on edits
  imageUrl?: string | null;
  tags?: string[] | null; // "icon:pizza", "option:Large:50", "addon:30:Cheese", "size:Name:price", "discount:percent:n"
  shortCode?: number | null;
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

// ---------- Phase B: dashboard (live tower) ----------
export interface DashKpisWire { orders: number; openOrders: number; avgTicket: number; profitPct: number | null; }
export interface DashMoverWire {
  menuItemId: string; nameEn?: string | null; nameBn?: string | null;
  qty: number; salesBdt: number; sharePct: number; // sharePct is a 0..1 fraction vs leader
}
export interface DashServiceMixWire { key: string; label: string; valueBdt: number; pct: number; }
export interface DashMoneyFirstWire {
  earnedToday: number; earnedYesterday: number; deltaPct: number; deltaNote: string;
  sparkline: number[]; kpis: DashKpisWire; topMovers: DashMoverWire[];
  serviceMix: DashServiceMixWire[]; closeTodayHintBdt: number;
}
export interface DashNeedsAttentionWire { kind: string; title: string; body: string; cta?: string | null; refId?: string | null; }
export interface DashRightNowWire {
  tablesSeated: number; tablesTotal: number; ordersInKitchen: number;
  lateOrders: number; lateMinThreshold: number; needsAttention: DashNeedsAttentionWire[];
  todaySoFarBdt: number; todaySoFarDeltaPct: number;
}
export interface DashboardSummaryWire {
  asOf: string;
  moneyFirst: DashMoneyFirstWire;
  rightNow: DashRightNowWire;
  review?: Record<string, unknown> | null;
}

// ---------- Phase B: analytics summary (Sales Breakdown report) ----------
export type AnalyticsRange = 'today' | 'week' | 'month' | 'custom';
export interface MoneyRowWire { key: string; label: string; valueBdt: number; }
export interface AnalyticsTrendPointWire { date: string; revenue: number; orders: number; }
export interface AnalyticsItemWire { menuItemId: string; name: string; units: number; avgUnitPrice: number; totalPrice: number; }
export interface AnalyticsCategoryWire { category: string; units: number; totalPrice: number; items: AnalyticsItemWire[]; }
export interface AnalyticsProfitWire {
  netSales: number; serviceCharge: number; deliveryCharge: number;
  preparationCost: number; wastage: number; paymentFee: number; taxes: number; grossProfit: number;
}
export interface AnalyticsSummaryWire {
  rangeStart: string;
  rangeEnd: string;
  salesSummary: { ordersCompleted: number; grossSales: number; discountByStaff: number; netSales: number };
  totalCollection: number;
  discountAndCommission: number;
  otherIncome: number;
  taxAndDuty: number;
  dueReceivable?: number | null;
  duePaid?: number | null;
  trend: AnalyticsTrendPointWire[];
  collection: MoneyRowWire[];
  serviceWise: MoneyRowWire[];
  profit: AnalyticsProfitWire;
  popularDishes: { name: string; qty: number; salesBdt: number }[];
  itemWise: AnalyticsCategoryWire[];
}

// ---------- Phase B: reports hub ----------
export interface OrderBucketWire { key: string; label: string; count: number; totalBdt: number; }
export interface OrderBucketsWire {
  rangeStart: string; rangeEnd: string;
  buckets: OrderBucketWire[];
  payments: { key: string; label: string; totalBdt: number }[];
}
export interface PerformanceItemWire {
  menuItemId: string; name: string; category: string; qty: number; salesBdt: number; avgUnitPrice: number;
}
export interface PerformanceReportWire {
  granularity: string; category?: string | null; days: number;
  rangeStart: string; rangeEnd: string; items: PerformanceItemWire[];
}

// ---------- Phase B3: inventory ----------
// Adjustment kinds the backend accepts (routers/inventory.py ADJUSTMENT_TYPES).
export type AdjustmentType = 'restock' | 'usage' | 'waste' | 'correction';
// Stock-hub per-item status (inventory/summary varianceStatus).
export type VarianceStatus = 'ok' | 'low' | 'out' | 'variance';

// Raw material (pull + upsert result — _item_to_dict).
export interface InventoryItemWire {
  id: string;
  outletId: string;
  name: string;
  category: string;
  unit: string; // kg | gm | ltr | ml | pcs
  quantity: number;
  minThreshold: number;
  costPerUnit: number;
  notes: string;
  defaultSupplierId?: string | null;
  defaultReorderQty: number;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string | null;
}

export interface InventorySupplierWire {
  id: string;
  name: string;
  phone: string;
  notes: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface StockAdjustmentWire {
  id: string;
  inventoryItemId: string;
  delta: number;
  type: AdjustmentType;
  note: string;
  totalCostBdt: number;
  supplierId?: string | null;
  supplierName: string;
  reason: string;
  billRef: string;
  createdByAccountId?: string | null;
  createdByRole?: string | null;
  createdAt: string;
}

export interface DailyStockCountWire {
  id: string;
  inventoryItemId: string;
  countDate: string; // YYYY-MM-DD
  quantity: number;
  createdAt: string;
}

// GET /inventory (owner pull).
export interface InventoryPullWire {
  items: InventoryItemWire[];
  adjustments: StockAdjustmentWire[];
  dailyCounts: DailyStockCountWire[];
  suppliers: InventorySupplierWire[];
}

// GET /inventory/summary — stock hub.
export interface InventoryCategoryWire { key: string; labelEn: string; labelBn: string; count: number; }
export interface InventorySummaryItemWire {
  id: string;
  nameEn: string;
  nameBn: string;
  category: string;
  unit: string;
  onHand: number;
  minThreshold: number;
  todayIn: number;
  todayOut: number;
  todaySpendBdt: number;
  varianceQty: number;
  varianceStatus: VarianceStatus;
  costPerUnit: number;
}
export interface InventorySummaryWire {
  asOf: string;
  stockValueBdt: number;
  varianceTodayBdt: number;
  varianceItemCount: number;
  alerts: number;
  categories: InventoryCategoryWire[];
  items: InventorySummaryItemWire[];
}

// GET /inventory/daily-report.
export interface InventoryVarianceRowWire {
  itemId: string;
  nameEn: string;
  nameBn: string;
  varianceQty: number;
  unit: string;
  expectedQty: number;
  actualQty: number;
  recurringWeeks: number;
  noteEn: string;
  varianceBdt: number;
}
export interface InventoryReorderWire {
  itemId: string;
  nameEn: string;
  nameBn: string;
  qtyToOrder: number;
  unit: string;
  ctaEn: string;
  supplierId?: string | null;
  defaultReorderQty: number;
}
export interface InventoryRevenueSplitWire { key: string; label: string; valueBdt: number; pct: number; }
export interface InventoryTopSellerWire { name: string; qty: number; salesBdt: number; }
export interface InventoryDailyReportWire {
  date: string;
  unexplainedVarianceBdt: number;
  varianceItemCount: number;
  headlineEn: string;
  headlineBn: string;
  breakdown: InventoryVarianceRowWire[];
  reorderSuggestions: InventoryReorderWire[];
  stockFlow: { inQty: number; outQty: number; spendBdt: number };
  revenueSplit: InventoryRevenueSplitWire[];
  topSellers: InventoryTopSellerWire[];
}

// ---------- Phase B3: inventory write payloads ----------
export interface InventoryItemPayload {
  id: string;
  name: string;
  category?: string | null;
  unit?: string | null;
  quantity: number;
  minThreshold: number;
  costPerUnit: number;
  notes?: string | null;
  defaultSupplierId?: string | null;
  defaultReorderQty: number;
  createdAt?: string | null;
  updatedAt?: string | null;
}
export interface StockAdjustmentPayload {
  id?: string;
  inventoryItemId: string;
  delta: number;
  type: AdjustmentType;
  note?: string | null;
  totalCostBdt?: number;
  supplierId?: string | null;
  supplierName?: string | null;
  reason?: string | null;
  billRef?: string | null;
  createdAt?: string | null;
}
export interface DailyStockCountPayload {
  id?: string;
  inventoryItemId: string;
  countDate: string;
  quantity: number;
  createdAt?: string | null;
}
export interface InventorySupplierPayload {
  id?: string;
  name: string;
  phone?: string | null;
  notes?: string | null;
}
// POST /inventory/adjustments and /daily-counts return the updated item alongside the record.
export interface StockAdjustmentResult { item: InventoryItemWire; adjustment: StockAdjustmentWire; }
export interface DailyStockCountResult { item: InventoryItemWire; dailyCount: DailyStockCountWire; }

// ---------- Phase B: menu write payload (POST /menu upsert, PATCH /menu/{id} full-replace) ----------
export interface MenuItemPayload {
  id: string;
  name: string;
  nameEn?: string | null;
  nameBn?: string | null;
  description?: string | null;
  descriptionEn?: string | null;
  descriptionBn?: string | null;
  price: number;
  costPrice?: number | null;
  shortCode?: number | null;
  isFavorite?: boolean;
  category?: string | null;
  categoryEn?: string | null;
  categoryBn?: string | null;
  isAvailable?: boolean;
  imageUrl?: string | null;
  tags?: string[] | null;
  version?: number;
}
