// Bill math — MUST agree with backend settle validation (backend/routers/pos.py):
//   expected_total = subtotal + vat_amount + delivery_charge + service_charge_amount - discount_amount
// VAT and service charge are computed on the item subtotal.

import { round2 } from './tags';

export interface CartLineLike {
  qty: number;
  unitPrice: number;
}

export interface DiscountInput {
  kind: 'percent' | 'flat' | 'fixed' | null;
  value: number;
  label?: string | null;
}

export interface BillTotals {
  subtotal: number;
  vatAmount: number;
  serviceChargeAmount: number;
  discountAmount: number;
  deliveryCharge: number;
  total: number;
}

export function lineTotal(line: CartLineLike): number {
  return round2(line.qty * line.unitPrice);
}

export function computeTotals(opts: {
  lines: CartLineLike[];
  vatRatePercent: number;
  serviceChargeRatePercent: number;
  discount?: DiscountInput | null;
  deliveryCharge?: number;
}): BillTotals {
  const subtotal = round2(opts.lines.reduce((sum, l) => sum + lineTotal(l), 0));
  const vatAmount = round2((subtotal * (opts.vatRatePercent || 0)) / 100);
  const serviceChargeAmount = round2((subtotal * (opts.serviceChargeRatePercent || 0)) / 100);
  const deliveryCharge = round2(opts.deliveryCharge || 0);

  let discountAmount = 0;
  const d = opts.discount;
  if (d && d.value > 0) {
    discountAmount =
      d.kind === 'percent'
        ? round2((subtotal * Math.min(d.value, 100)) / 100)
        : round2(d.value); // flat | fixed
  }
  // A discount can never push the bill negative.
  discountAmount = Math.min(discountAmount, round2(subtotal + vatAmount + serviceChargeAmount + deliveryCharge));

  const total = round2(subtotal + vatAmount + serviceChargeAmount + deliveryCharge - discountAmount);
  return { subtotal, vatAmount, serviceChargeAmount, discountAmount, deliveryCharge, total };
}

const BN_DIGITS = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

export function toBnDigits(s: string): string {
  return s.replace(/[0-9]/g, (d) => BN_DIGITS[Number(d)]);
}

export function formatTk(v: number, bn = false): string {
  const negative = v < 0;
  const abs = Math.abs(v);
  const hasPaisa = Math.round(abs * 100) % 100 !== 0;
  const s = hasPaisa
    ? abs.toFixed(2)
    : Math.round(abs).toLocaleString('en-IN');
  return `${negative ? '-' : ''}৳${bn ? toBnDigits(s) : s}`;
}
