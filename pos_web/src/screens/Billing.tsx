// Billing screen — petpooja13/14: category rail · item grid w/ search + short code ·
// cart panel (service tabs, lines, totals, payment strip, actions).

import { useMemo, useRef, useState } from 'react';
import { useSession } from '../state/session';
import { useMenu, itemDisplayName, matchShortCode, type PosMenuItem } from '../state/menu';
import { useCart, type CartLine } from '../state/cart';
import { usePos } from '../state/pos';
import { usePrinters } from '../print/printManager';
import { renderKot, renderReceipt, type TicketContext } from '../print/ticketRenderer';
import { formatTk } from '../core/money';
import { needsCustomization } from '../core/tags';
import type { PaymentMethod, PosSettlementLineWire } from '../api/types';
import { t, type Lang, type StringKey } from '../i18n/strings';
import { Modal } from '../components/Modal';
import { CustomizeModal, type CustomizeResult } from '../components/CustomizeModal';
import { SplitModal } from '../components/SplitModal';
import { ShiftModal } from '../components/ShiftModal';
import './billing.css';

function catHue(cat: string): number {
  let h = 0;
  for (let i = 0; i < cat.length; i++) h = cat.charCodeAt(i) + ((h << 5) - h);
  return ((h % 360) + 360) % 360;
}

const PAYMENT_IDS: PaymentMethod[] = ['cash', 'card', 'bkash', 'nagad', 'pay_later'];

type ModalKind =
  | { kind: 'customize'; item: PosMenuItem }
  | { kind: 'table' }
  | { kind: 'delivery' }
  | { kind: 'discount' }
  | { kind: 'held' }
  | { kind: 'split' }
  | { kind: 'shiftOpen'; then?: () => void }
  | null;

export function Billing() {
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);
  const bn = lang === 'bn';
  const menu = useMenu();
  const cart = useCart();
  const pos = usePos();
  const printers = usePrinters();

  const [category, setCategory] = useState<string>('__all');
  const [search, setSearch] = useState('');
  const [shortCode, setShortCode] = useState('');
  const [modal, setModal] = useState<ModalKind>(null);
  const [toast, setToast] = useState<{ msg: string; bad?: boolean } | null>(null);
  const toastTimer = useRef<number | undefined>(undefined);

  const notify = (msg: string, bad = false) => {
    setToast({ msg, bad });
    window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(null), bad ? 5000 : 2600);
  };

  const ticketCtx: TicketContext = {
    restaurantName: session.restaurantName,
    outletName: session.outletName,
    serverRole: session.role,
  };

  const visibleItems = useMemo(() => {
    const q = search.trim().toLowerCase();
    return menu.items.filter((it) => {
      if (!it.raw.isAvailable && !q) return false;
      if (q) {
        const hay = `${it.raw.name} ${it.raw.nameEn ?? ''} ${it.raw.nameBn ?? ''}`.toLowerCase();
        if (!hay.includes(q)) return false;
        return true;
      }
      if (category === '__fav') return menu.favorites.has(it.raw.id);
      if (category === '__all') return true;
      return it.category === category;
    });
  }, [menu.items, menu.favorites, category, search]);

  const inCartIds = useMemo(() => new Set(cart.lines.map((l) => l.menuItemId)), [cart.lines]);
  const totals = cart.totals();

  // ---------- item entry ----------
  const addItem = (item: PosMenuItem, custom?: CustomizeResult) => {
    cart.addLine({
      menuItemId: item.raw.id,
      nameEn: item.raw.nameEn || item.raw.name,
      nameBn: item.raw.nameBn ?? null,
      suffix: custom?.suffix ?? null,
      unitPrice: custom?.unitPrice ?? item.price,
      note: custom?.note ?? null,
    });
  };

  const tapItem = (item: PosMenuItem) => {
    if (needsCustomization(item.extras)) setModal({ kind: 'customize', item });
    else addItem(item);
  };

  const submitShortCode = () => {
    const trimmed = shortCode.trim();
    if (trimmed === '') return;
    const item = matchShortCode(menu.items, trimmed);
    if (!item) {
      notify(t('foh.noShortCode', lang) + trimmed, true);
      return;
    }
    tapItem(item);
    setShortCode('');
  };

  // ---------- actions ----------
  const guard = (fn: () => Promise<void>) => () => {
    void fn().catch((e: unknown) => notify(e instanceof Error ? e.message : String(e), true));
  };

  const doSave = (print: boolean) =>
    guard(async () => {
      const order = await cart.saveOrder();
      notify(t('foh.orderSaved', lang) + order.serialNumber + t('foh.saved', lang));
      if (print) {
        const canvas = renderReceipt(printers.paperDots(), ticketCtx, order);
        await printers.print(canvas);
      }
      cart.clear();
    })();

  const doKot = (print: boolean) =>
    guard(async () => {
      const { order, batchLines } = await cart.sendKot(cart.note ?? undefined);
      notify(t('foh.kotSent', lang) + order.serialNumber);
      if (print) {
        const canvas = renderKot(
          printers.paperDots(), ticketCtx, order,
          batchLines.map((l: CartLine) => ({
            qty: l.qty,
            name: l.suffix ? `${l.nameEn} ${l.suffix}` : l.nameEn,
            note: l.note,
          })),
          cart.note,
        );
        await printers.print(canvas);
      }
    })();

  const doSettle = (lines?: PosSettlementLineWire[]) => {
    if (!pos.shift || pos.shift.status !== 'open') {
      setModal({ kind: 'shiftOpen', then: () => doSettle(lines) });
      return;
    }
    void guard(async () => {
      const settlements: PosSettlementLineWire[] =
        lines ?? [{ eventId: crypto.randomUUID(), paymentMethod: cart.paymentMethod, amount: totals.total, payerLabel: null }];
      const settled = await cart.settle(settlements);
      notify(t('foh.billSettled', lang) + settled.serialNumber + t('foh.settled', lang) + formatTk(settled.totalAmount));
      if (cart.autoPrint) {
        const canvas = renderReceipt(printers.paperDots(), ticketCtx, settled, {
          paid: true,
          paymentLabel: settlements.length === 1 ? settlements[0].paymentMethod : 'split',
        });
        await printers.print(canvas, { kickDrawer: settlements.some((s) => s.paymentMethod === 'cash') });
      }
      cart.clear();
    })();
  };

  const serviceTabs: { id: typeof cart.serviceType; label: string }[] = [
    { id: 'dine_in', label: t('foh.dineIn', lang) },
    { id: 'delivery', label: t('foh.delivery', lang) },
    { id: 'takeaway', label: t('foh.pickUp', lang) },
  ];

  return (
    <div className="billing-root">
      {/* ---------- category rail ---------- */}
      <aside className="cat-rail">
        <button
          className={`cat-item cat-fav ${category === '__fav' && !search ? 'active' : ''}`}
          onClick={() => { setCategory('__fav'); setSearch(''); }}
        >{t('foh.favItems', lang)}</button>
        <button
          className={`cat-item ${category === '__all' && !search ? 'active' : ''}`}
          onClick={() => { setCategory('__all'); setSearch(''); }}
        >{t('foh.allItems', lang)}</button>
        {menu.categories.map((c) => (
          <button
            key={c}
            className={`cat-item ${category === c && !search ? 'active' : ''}`}
            onClick={() => { setCategory(c); setSearch(''); }}
          >{c}</button>
        ))}
      </aside>

      {/* ---------- item grid ---------- */}
      <section className="item-pane">
        <div className="item-search-row">
          <input
            className="input item-search" placeholder={t('foh.searchItem', lang)}
            value={search} onChange={(e) => setSearch(e.target.value)}
          />
          <input
            className="input item-shortcode" placeholder={t('foh.shortCode', lang)}
            value={shortCode} inputMode="numeric"
            onChange={(e) => setShortCode(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') submitShortCode(); }}
          />
        </div>
        {menu.loading ? (
          <div className="item-empty">{t('foh.loadingMenu', lang)}</div>
        ) : visibleItems.length === 0 ? (
          <div className="item-empty">
            {category === '__fav' && !search
              ? t('foh.noFav', lang)
              : t('foh.noItems', lang)}
          </div>
        ) : (
          <div className="item-grid">
            {visibleItems.map((item) => (
              <button
                key={item.raw.id}
                className={`item-tile ${inCartIds.has(item.raw.id) ? 'in-cart' : ''} ${!item.raw.isAvailable ? 'unavailable' : ''}`}
                style={{ '--cat-hue': catHue(item.category) } as React.CSSProperties}
                onClick={() => item.raw.isAvailable && tapItem(item)}
                onContextMenu={(e) => { e.preventDefault(); menu.toggleFavorite(item.raw.id); }}
                title={`${itemDisplayName(item, bn)}${item.raw.shortCode != null ? ` · ${t('foh.code', lang)} ${item.raw.shortCode}` : ''}`}
              >
                {menu.favorites.has(item.raw.id) && <span className="item-fav-dot">♥</span>}
                <span className="item-name">{itemDisplayName(item, bn)}</span>
              </button>
            ))}
          </div>
        )}
      </section>

      {/* ---------- cart panel ---------- */}
      <aside className="cart-pane">
        <div className="service-tabs">
          {serviceTabs.map((tab) => (
            <button
              key={tab.id}
              className={`service-tab ${cart.serviceType === tab.id ? 'active' : ''}`}
              onClick={() => {
                cart.setService(tab.id);
                if (tab.id === 'dine_in' && !cart.tableNo) setModal({ kind: 'table' });
                if (tab.id === 'delivery') setModal({ kind: 'delivery' });
              }}
            >{tab.label}</button>
          ))}
        </div>

        <div className="cart-context">
          {cart.serviceType === 'dine_in' && (
            <button className="ctx-chip" onClick={() => setModal({ kind: 'table' })}>
              {cart.tableNo ? t('foh.table', lang) + cart.tableNo : t('foh.selectTable', lang)}
            </button>
          )}
          {cart.serviceType === 'delivery' && (
            <button className="ctx-chip" onClick={() => setModal({ kind: 'delivery' })}>
              {cart.customerName || cart.mobileNumber ? `${cart.customerName ?? ''} ${cart.mobileNumber ?? ''}`.trim() : t('foh.deliveryDetails', lang)}
            </button>
          )}
          {cart.order && <span className="ctx-serial">#{cart.order.serialNumber}</span>}
          <span className="ctx-spacer" />
          {cart.held.length > 0 && (
            <button className="ctx-chip ctx-held" onClick={() => setModal({ kind: 'held' })}>
              {t('foh.held', lang)}{cart.held.length}
            </button>
          )}
        </div>

        <div className="cart-header">
          <span className="ch-items">{t('foh.cartItems', lang)}</span>
          <span className="ch-qty">{t('foh.cartQty', lang)}</span>
          <span className="ch-price">{t('foh.cartPrice', lang)}</span>
        </div>

        <div className="cart-lines">
          {cart.lines.length === 0 ? (
            <div className="cart-empty">{t('foh.emptyCart', lang)}</div>
          ) : (
            cart.lines.map((line) => (
              <div className={`cart-line ${line.kotSentAt ? 'kot-sent' : ''}`} key={line.lineId}>
                <button className="cl-remove" onClick={() => cart.removeLine(line.lineId)}>✕</button>
                <div className="cl-name">
                  {bn && line.nameBn ? line.nameBn : line.nameEn}
                  {line.suffix && <span className="cl-suffix"> {line.suffix}</span>}
                  {line.note && <div className="cl-note">{line.note}</div>}
                  {line.kotSentAt && <span className="cl-kot" title={t('foh.sentToKitchen', lang)}>KOT ✓</span>}
                </div>
                <div className="cl-qty">
                  <button onClick={() => cart.setQty(line.lineId, line.qty - 1)}>−</button>
                  <span>{line.qty}</span>
                  <button onClick={() => cart.setQty(line.lineId, line.qty + 1)}>+</button>
                </div>
                <div className="cl-price">{formatTk(line.qty * line.unitPrice)}</div>
              </div>
            ))
          )}
        </div>

        <div className="cart-totals">
          <div className="ct-row"><span>{t('foh.subtotal', lang)}</span><span>{formatTk(totals.subtotal)}</span></div>
          {totals.vatAmount > 0 && (
            <div className="ct-row"><span>{t('foh.vat', lang)} ({pos.settings?.vatRatePercent ?? 0}%)</span><span>{formatTk(totals.vatAmount)}</span></div>
          )}
          {totals.serviceChargeAmount > 0 && (
            <div className="ct-row"><span>{t('foh.service', lang)} ({pos.settings?.serviceChargePercent ?? 0}%)</span><span>{formatTk(totals.serviceChargeAmount)}</span></div>
          )}
          <div className="ct-row">
            <button className="ct-discount-btn" onClick={() => setModal({ kind: 'discount' })}>
              {cart.discount ? t('foh.discountLabel', lang) + ' (' + (cart.discount.label ?? t('foh.custom', lang)) + ')' : t('foh.addDiscount', lang)}
            </button>
            <span>{totals.discountAmount > 0 ? `−${formatTk(totals.discountAmount)}` : ''}</span>
          </div>
          <div className="ct-total"><span>{t('foh.total', lang)}</span><span>{formatTk(totals.total)}</span></div>
        </div>

        <div className="pay-strip">
          {PAYMENT_IDS.map((id) => (
            <label key={id} className={`pay-radio ${cart.paymentMethod === id ? 'active' : ''}`}>
              <input
                type="radio" name="pm" checked={cart.paymentMethod === id}
                onChange={() => cart.setPaymentMethod(id)}
              />
              {t(('foh.' + id) as StringKey, lang)}
            </label>
          ))}
          <button className="pay-split" onClick={() => cart.lines.length && setModal({ kind: 'split' })}>{t('foh.split', lang)}</button>
          <span className="pay-total">{t('foh.total', lang)} <b>{formatTk(totals.total)}</b></span>
        </div>

        <div className="cart-actions">
          <button className="btn btn-dark" disabled={cart.busy || cart.lines.every((l) => l.kotSentAt !== null)} onClick={() => doKot(cart.autoPrint)}>{t('foh.kot', lang)}</button>
          <button className="btn btn-primary" disabled={cart.busy || cart.lines.length === 0} onClick={() => doSave(cart.autoPrint)}>{t('foh.printBill', lang)}</button>
          <button className="btn btn-primary" disabled={cart.busy || cart.lines.length === 0} onClick={() => doSettle()}>{t('foh.settleBill', lang)}</button>
        </div>
      </aside>

      {/* ---------- modals ---------- */}
      {modal?.kind === 'customize' && (
        <CustomizeModal
          lang={lang} item={modal.item} bn={bn}
          onClose={() => setModal(null)}
          onConfirm={(r) => { addItem(modal.item, r); setModal(null); }}
        />
      )}
      {modal?.kind === 'table' && <TableModal lang={lang} onClose={() => setModal(null)} />}
      {modal?.kind === 'delivery' && <DeliveryModal lang={lang} onClose={() => setModal(null)} />}
      {modal?.kind === 'discount' && <DiscountModal lang={lang} onClose={() => setModal(null)} />}
      {modal?.kind === 'held' && <HeldModal lang={lang} onClose={() => setModal(null)} />}
      {modal?.kind === 'split' && (
        <SplitModal
          lang={lang}
          total={totals.total}
          onClose={() => setModal(null)}
          onConfirm={(lines) => { setModal(null); doSettle(lines); }}
        />
      )}
      {modal?.kind === 'shiftOpen' && (
        <ShiftModal
          mode="open"
          onClose={() => setModal(null)}
          onDone={() => { const then = modal.then; setModal(null); then?.(); }}
        />
      )}

      {toast && <div className={`toast ${toast.bad ? 'bad' : ''}`}>{toast.msg}</div>}
    </div>
  );
}

// ================= small modals =================

function TableModal({ lang, onClose }: { lang: Lang; onClose: () => void }) {
  const settings = usePos((s) => s.settings);
  const cart = useCart();
  const zones = settings?.floorLayout ?? [];
  return (
    <Modal title={t('foh.selectTable', lang)} onClose={onClose} width={640}>
      {zones.length === 0 && <div className="cart-empty">{t('foh.noFloorLayout', lang)}</div>}
      {zones.map((zone) => (
        <div key={zone.id} className="tablepick-zone">
          <div className="tablepick-zone-name">{zone.name}</div>
          <div className="tablepick-grid">
            {zone.tables.map((tb) => (
              <button
                key={tb.id}
                className={`tablepick-tile ${cart.tableNo === tb.label ? 'active' : ''}`}
                onClick={() => { cart.setTable(tb.label); onClose(); }}
              >{tb.label}</button>
            ))}
          </div>
        </div>
      ))}
    </Modal>
  );
}

function DeliveryModal({ lang, onClose }: { lang: Lang; onClose: () => void }) {
  const cart = useCart();
  const [name, setName] = useState(cart.customerName ?? '');
  const [phone, setPhone] = useState(cart.mobileNumber ?? '');
  const [address, setAddress] = useState(cart.deliveryAddress ?? '');
  return (
    <Modal
      title={t('foh.deliveryDetails', lang)} onClose={onClose}
      footer={
        <button
          className="btn btn-primary"
          onClick={() => {
            cart.setCustomer({
              customerName: name.trim() || null,
              mobileNumber: phone.trim() || null,
              deliveryAddress: address.trim() || null,
            });
            onClose();
          }}
        >{t('foh.done', lang)}</button>
      }
    >
      <div className="field"><label>{t('foh.customerName', lang)}</label>
        <input className="input" value={name} onChange={(e) => setName(e.target.value)} /></div>
      <div className="field"><label>{t('foh.mobileNumber', lang)}</label>
        <input className="input" value={phone} onChange={(e) => setPhone(e.target.value)} inputMode="tel" /></div>
      <div className="field"><label>{t('foh.address', lang)}</label>
        <textarea className="input delivery-address" value={address} onChange={(e) => setAddress(e.target.value)} /></div>
    </Modal>
  );
}

function DiscountModal({ lang, onClose }: { lang: Lang; onClose: () => void }) {
  const settings = usePos((s) => s.settings);
  const cart = useCart();
  const [customValue, setCustomValue] = useState('');
  const [customKind, setCustomKind] = useState<'percent' | 'flat'>('percent');
  const [customLabel, setCustomLabel] = useState('');
  const presets = settings?.discountPresets ?? [];
  return (
    <Modal title={t('foh.discountTitle', lang)} onClose={onClose}>
      {presets.length > 0 && (
        <div className="customize-group">
          <div className="customize-group-title">{t('foh.presets', lang)}</div>
          <div className="customize-choices">
            {presets.map((p) => (
              <button
                key={p.id}
                className={`choice ${cart.discount?.presetId === p.id ? 'active' : ''}`}
                onClick={() => {
                  cart.setDiscount({ kind: p.kind === 'percent' ? 'percent' : 'flat', value: p.value, label: p.label, presetId: p.id });
                  onClose();
                }}
              >
                {p.label} <span className="choice-price">{p.kind === 'percent' ? `${p.value}%` : formatTk(p.value)}</span>
              </button>
            ))}
          </div>
        </div>
      )}
      <div className="customize-group">
        <div className="customize-group-title">{t('foh.customManager', lang)}</div>
        <div className="discount-custom">
          <select className="input" value={customKind} onChange={(e) => setCustomKind(e.target.value as 'percent' | 'flat')}>
            <option value="percent">{t('foh.percent', lang)}</option>
            <option value="flat">{t('foh.flat', lang)}</option>
          </select>
          <input className="input" type="number" min="0" placeholder={t('foh.value', lang)} value={customValue} onChange={(e) => setCustomValue(e.target.value)} />
          <input className="input" placeholder={t('foh.label', lang)} value={customLabel} onChange={(e) => setCustomLabel(e.target.value)} />
        </div>
        <div className="discount-actions">
          <button
            className="btn btn-primary btn-sm"
            disabled={!Number(customValue)}
            onClick={() => {
              cart.setDiscount({ kind: customKind, value: Number(customValue), label: customLabel.trim() || t('foh.custom', lang), presetId: null });
              onClose();
            }}
          >{t('foh.apply', lang)}</button>
          {cart.discount && (
            <button className="btn btn-outline btn-sm" onClick={() => { cart.setDiscount(null); onClose(); }}>
              {t('foh.removeDiscount', lang)}
            </button>
          )}
        </div>
      </div>
    </Modal>
  );
}

function HeldModal({ lang, onClose }: { lang: Lang; onClose: () => void }) {
  const cart = useCart();
  return (
    <Modal title={t('foh.heldOrders', lang)} onClose={onClose}>
      {cart.held.map((h) => (
        <div className="held-row" key={h.id}>
          <div className="held-info">
            <b>{h.serviceType === 'dine_in' ? t('foh.table', lang) + (h.tableNo ?? '—') : h.serviceType === 'delivery' ? t('foh.delivery', lang) : t('foh.pickUp', lang)}</b>
            <span>{h.lines.reduce((n, l) => n + l.qty, 0)}{t('foh.items', lang)} · {new Date(h.heldAt).toLocaleTimeString()}</span>
          </div>
          <button className="btn btn-primary btn-sm" onClick={() => { cart.resumeHeld(h.id); onClose(); }}>{t('foh.resume', lang)}</button>
          <button className="btn btn-danger-outline btn-sm" onClick={() => cart.discardHeld(h.id)}>{t('foh.discard', lang)}</button>
        </div>
      ))}
      {cart.held.length === 0 && <div className="cart-empty">{t('foh.nothingHeld', lang)}</div>}
    </Modal>
  );
}

