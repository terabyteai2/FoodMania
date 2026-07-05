// Canvas ticket painter — implements the templates in repo-root printer.txt.
// Draws at printer resolution (384 dots = 58mm, 576 dots = 80mm). Bengali text
// renders through the normal font stack (Hind Siliguri / Noto Sans Bengali).

import type { OrderWire } from '../api/types';
import { formatTk } from '../core/money';

const FONT = "'Plus Jakarta Sans','Hind Siliguri','Noto Sans Bengali',sans-serif";

interface Painter {
  canvas: HTMLCanvasElement;
  ctx: CanvasRenderingContext2D;
  width: number;
  y: number;
  margin: number;
}

function createPainter(width: number): Painter {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = 4000; // trimmed at the end
  const ctx = canvas.getContext('2d')!;
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = '#000';
  ctx.textBaseline = 'top';
  return { canvas, ctx, width, y: 12, margin: 8 };
}

function font(p: Painter, size: number, weight = 400) {
  p.ctx.font = `${weight} ${size}px ${FONT}`;
}

function textCenter(p: Painter, text: string, size: number, weight = 400, gap = 6) {
  font(p, size, weight);
  p.ctx.textAlign = 'center';
  p.ctx.fillText(text, p.width / 2, p.y, p.width - p.margin * 2);
  p.y += size + gap;
}

function textLeft(p: Painter, text: string, size: number, weight = 400, gap = 6, indent = 0) {
  font(p, size, weight);
  p.ctx.textAlign = 'left';
  p.ctx.fillText(text, p.margin + indent, p.y, p.width - p.margin * 2 - indent);
  p.y += size + gap;
}

function textRow(p: Painter, left: string, right: string, size: number, weightL = 400, weightR = 400, gap = 6) {
  font(p, size, weightL);
  p.ctx.textAlign = 'left';
  const rightWidth = measure(p, right, size, weightR) + 4;
  p.ctx.fillText(left, p.margin, p.y, p.width - p.margin * 2 - rightWidth);
  font(p, size, weightR);
  p.ctx.textAlign = 'right';
  p.ctx.fillText(right, p.width - p.margin, p.y);
  p.y += size + gap;
}

function measure(p: Painter, text: string, size: number, weight = 400): number {
  font(p, size, weight);
  return p.ctx.measureText(text).width;
}

function hline(p: Painter, dashed = true, gap = 8) {
  p.ctx.save();
  p.ctx.strokeStyle = '#000';
  p.ctx.lineWidth = 2;
  if (dashed) p.ctx.setLineDash([6, 5]);
  p.ctx.beginPath();
  p.ctx.moveTo(p.margin, p.y + 3);
  p.ctx.lineTo(p.width - p.margin, p.y + 3);
  p.ctx.stroke();
  p.ctx.restore();
  p.y += gap + 4;
}

/** Word-wrapped left text (for item names / notes / addresses). */
function textWrap(p: Painter, text: string, size: number, weight = 400, indent = 0, gap = 4) {
  font(p, size, weight);
  p.ctx.textAlign = 'left';
  const max = p.width - p.margin * 2 - indent;
  const words = text.split(/\s+/);
  let line = '';
  for (const w of words) {
    const attempt = line ? `${line} ${w}` : w;
    if (p.ctx.measureText(attempt).width > max && line) {
      p.ctx.fillText(line, p.margin + indent, p.y);
      p.y += size + gap;
      line = w;
    } else {
      line = attempt;
    }
  }
  if (line) {
    p.ctx.fillText(line, p.margin + indent, p.y);
    p.y += size + gap;
  }
}

function trim(p: Painter): HTMLCanvasElement {
  const out = document.createElement('canvas');
  out.width = p.width;
  out.height = Math.min(p.canvas.height, Math.ceil(p.y + 16));
  const ctx = out.getContext('2d')!;
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, out.width, out.height);
  ctx.drawImage(p.canvas, 0, 0);
  return out;
}

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}
function fmtTime(d: Date): string {
  let h = d.getHours();
  const ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12 || 12;
  return `${h}:${String(d.getMinutes()).padStart(2, '0')} ${ampm}`;
}

function serviceLabel(order: OrderWire): string {
  switch (order.serviceType) {
    case 'takeaway': return 'PARCEL';
    case 'delivery': return 'DELIVERY';
    default: return 'DINE-IN';
  }
}

export interface TicketContext {
  restaurantName: string;
  outletName?: string | null;
  serverRole?: string | null;
}

// ---------------------------------------------------------------- KOT --------
export function renderKot(
  width: number,
  ctx: TicketContext,
  order: OrderWire,
  batchLines: { qty: number; name: string; note?: string | null }[],
  kotNote?: string | null,
): HTMLCanvasElement {
  const p = createPainter(width);
  const u = width / 384;
  const now = new Date();

  textCenter(p, 'KITCHEN ORDER', 26 * u, 800, 8);
  hline(p, false);
  textRow(p, `Date: ${fmtDate(now)}`, `Time: ${fmtTime(now)}`, 20 * u);
  p.y += 6;
  textCenter(p, `# ${order.serialNumber}`, 44 * u, 800, 10);
  textRow(
    p,
    `Type: [ ${serviceLabel(order)} ]`,
    order.tableNo ? `Table: ${order.tableNo}` : '',
    20 * u, 600, 600,
  );
  if (ctx.serverRole) textLeft(p, `Server: ${ctx.serverRole}`, 20 * u);
  hline(p);
  for (const line of batchLines) {
    textWrap(p, `[${line.qty}] ${line.name}`, 24 * u, 700);
    if (line.note) textWrap(p, `** ${line.note} **`, 20 * u, 600, 18 * u);
    p.y += 4;
  }
  if (kotNote) {
    p.y += 4;
    textWrap(p, `NOTE: ${kotNote}`, 20 * u, 700);
  }
  hline(p);
  textCenter(p, `Printed: ${fmtTime(now)}`, 18 * u, 400, 4);
  return trim(p);
}

// ------------------------------------------------------------- Receipt -------
export function renderReceipt(
  width: number,
  ctx: TicketContext,
  order: OrderWire,
  opts: { paid?: boolean; paymentLabel?: string | null } = {},
): HTMLCanvasElement {
  const p = createPainter(width);
  const u = width / 384;
  const created = order.createdAt ? new Date(order.createdAt) : new Date();

  textCenter(p, ctx.restaurantName, 26 * u, 800, 4);
  if (ctx.outletName && ctx.outletName !== ctx.restaurantName) {
    textCenter(p, ctx.outletName, 19 * u, 500, 4);
  }
  hline(p, false);
  textCenter(p, `Date: ${fmtDate(created)}   Time: ${fmtTime(created)}`, 18 * u, 400, 8);
  textCenter(p, `#${order.serialNumber}`, 34 * u, 800, 8);

  const badge = `[ ${serviceLabel(order)} ]`;
  const table = order.tableNo ? `Table: ${order.tableNo}` : '';
  const server = order.createdByRole ? `Server: ${order.createdByRole}` : '';
  textCenter(p, [badge, table, server].filter(Boolean).join('   '), 19 * u, 600, 8);
  hline(p);

  // items header + rows
  textRow(p, 'ITEM', 'TOTAL', 17 * u, 700, 700, 4);
  hline(p);
  for (const it of order.items) {
    const name = it.name;
    textRow(p, `${it.qty} x ${name}`, formatTk(it.lineTotal), 20 * u, 500, 600, 3);
    if (it.note) textWrap(p, `- ${it.note}`, 17 * u, 400, 16 * u);
  }
  hline(p);

  textRow(p, 'Subtotal', formatTk(order.subtotal ?? 0), 19 * u);
  if ((order.vatAmount ?? 0) > 0) {
    textRow(p, `VAT (${order.vatRatePercent ?? 0}%)`, formatTk(order.vatAmount ?? 0), 19 * u);
  }
  if ((order.serviceChargeAmount ?? 0) > 0) {
    textRow(p, `Service charge (${order.serviceChargeRatePercent ?? 0}%)`, formatTk(order.serviceChargeAmount ?? 0), 19 * u);
  }
  if ((order.deliveryCharge ?? 0) > 0) {
    textRow(p, 'Delivery', formatTk(order.deliveryCharge ?? 0), 19 * u);
  }
  if ((order.discountAmount ?? 0) > 0) {
    textRow(p, `Discount${order.discountLabel ? ` (${order.discountLabel})` : ''}`, `-${formatTk(order.discountAmount ?? 0)}`, 19 * u, 400, 600);
  }
  p.y += 4;
  textRow(p, 'TOTAL', formatTk(order.totalAmount), 26 * u, 800, 800, 8);

  if (opts.paid) {
    hline(p);
    textCenter(p, `PAID${opts.paymentLabel ? ` — ${opts.paymentLabel.toUpperCase()}` : ''}`, 20 * u, 700, 6);
  }
  if (order.customerName) textLeft(p, `Customer: ${order.customerName}`, 18 * u);
  if (order.deliveryAddress) textWrap(p, `Address: ${order.deliveryAddress}`, 18 * u);
  if (order.mobileNumber) textLeft(p, `Mobile: ${order.mobileNumber}`, 18 * u);

  hline(p, false);
  textCenter(p, 'Thank you! Powered by QuickBytes', 16 * u, 400, 2);
  return trim(p);
}

// ------------------------------------------------------------- Day-end -------
export interface DayEndSummary {
  date: string;
  sales: number;
  orders: number;
  covers: number;
  paymentSplit: Record<string, number>;
  voids: number;
  comps: number;
  refunds: number;
  openingCash?: number | null;
  expectedCash?: number | null;
  countedCash?: number | null;
  varianceCash?: number | null;
}

export function renderDayEnd(width: number, ctx: TicketContext, s: DayEndSummary): HTMLCanvasElement {
  const p = createPainter(width);
  const u = width / 384;

  textCenter(p, ctx.restaurantName, 24 * u, 800, 3);
  if (ctx.outletName && ctx.outletName !== ctx.restaurantName) {
    textCenter(p, ctx.outletName, 18 * u, 500, 4);
  }
  textCenter(p, 'DAY-END REPORT', 22 * u, 800, 4);
  textCenter(p, s.date, 18 * u, 400, 6);
  hline(p);

  textRow(p, 'Net sales', formatTk(s.sales), 22 * u, 800, 800, 6);
  textRow(p, 'Orders', String(s.orders), 19 * u);
  textRow(p, 'Covers', String(s.covers), 19 * u);
  hline(p);

  textLeft(p, 'PAYMENTS', 17 * u, 700, 4);
  const methods = Object.keys(s.paymentSplit);
  if (methods.length === 0) textLeft(p, 'No settlements', 18 * u, 400, 4, 8 * u);
  for (const m of methods) {
    textRow(p, m.toUpperCase(), formatTk(s.paymentSplit[m]), 19 * u);
  }
  hline(p);

  textRow(p, 'Voided orders', String(s.voids), 18 * u);
  textRow(p, 'Complimentary', String(s.comps), 18 * u);
  textRow(p, 'Refunds', String(s.refunds), 18 * u);

  if (s.openingCash != null || s.countedCash != null) {
    hline(p);
    textLeft(p, 'CASH DRAWER', 17 * u, 700, 4);
    if (s.openingCash != null) textRow(p, 'Opening float', formatTk(s.openingCash), 19 * u);
    if (s.expectedCash != null) textRow(p, 'Expected', formatTk(s.expectedCash), 19 * u);
    if (s.countedCash != null) textRow(p, 'Counted', formatTk(s.countedCash), 19 * u);
    if (s.varianceCash != null) {
      textRow(p, 'Variance', `${s.varianceCash > 0 ? '+' : ''}${formatTk(s.varianceCash)}`, 19 * u, 700, 700);
    }
  }

  hline(p, false);
  textCenter(p, 'Powered by QuickBytes', 16 * u, 400, 2);
  return trim(p);
}

// ----------------------------------------------------------- Tax summary -----
export interface TaxSummaryData {
  periodLabel: string;
  taxableBdt: number; // taxable base (net sales)
  vatRatePercent: number;
  taxCollectedBdt: number; // taxAndDuty
  ordersCompleted: number;
  grossSalesBdt: number;
  totalCollectionBdt: number;
}

export function renderTaxSummary(width: number, ctx: TicketContext, s: TaxSummaryData): HTMLCanvasElement {
  const p = createPainter(width);
  const u = width / 384;

  textCenter(p, ctx.restaurantName, 24 * u, 800, 3);
  if (ctx.outletName && ctx.outletName !== ctx.restaurantName) {
    textCenter(p, ctx.outletName, 18 * u, 500, 4);
  }
  textCenter(p, 'TAX SUMMARY', 22 * u, 800, 4);
  textCenter(p, s.periodLabel, 18 * u, 400, 6);
  hline(p);

  textRow(p, 'Orders completed', String(s.ordersCompleted), 19 * u);
  textRow(p, 'Gross sales', formatTk(s.grossSalesBdt), 19 * u);
  textRow(p, 'Total collection', formatTk(s.totalCollectionBdt), 19 * u);
  hline(p);

  textRow(p, 'Taxable amount', formatTk(s.taxableBdt), 20 * u, 700, 700, 6);
  textRow(p, 'VAT rate', `${s.vatRatePercent}%`, 19 * u);
  p.y += 4;
  textRow(p, 'TAX COLLECTED', formatTk(s.taxCollectedBdt), 24 * u, 800, 800, 8);

  hline(p, false);
  textCenter(p, 'Powered by QuickBytes', 16 * u, 400, 2);
  return trim(p);
}

// ---------------------------------------------------------- Test ticket ------
export function renderTestTicket(width: number, label: string): HTMLCanvasElement {
  const p = createPainter(width);
  const u = width / 384;
  textCenter(p, 'QuickBytes POS', 28 * u, 800, 8);
  textCenter(p, 'TEST PRINT', 22 * u, 700, 8);
  hline(p);
  textLeft(p, `Printer: ${label}`, 20 * u);
  textLeft(p, `Width: ${width} dots`, 20 * u);
  textLeft(p, `Time: ${new Date().toLocaleString()}`, 20 * u);
  textLeft(p, 'বাংলা টেস্ট — হিন্দ শিলিগুড়ি', 22 * u);
  hline(p);
  textCenter(p, 'If you can read this, printing works.', 18 * u);
  return trim(p);
}
