// Orders — ongoing / completed lists with rich cards and action CTAs.
// Ongoing shows pending + accepted orders with Accept/Reject/KOT/Print Bill.
// Completed shows settled orders with item rows and Reprint.

import { useEffect, useMemo, useState } from 'react';
import { useSession } from '../state/session';
import { useCart } from '../state/cart';
import { useNav } from '../state/nav';
import { useOrders, ongoingOrders, completedOrders } from '../state/orders';
import { usePrinters } from '../print/printManager';
import { renderKot, renderReceipt, type TicketContext } from '../print/ticketRenderer';
import { formatTk } from '../core/money';
import { api } from '../api/client';
import type { OrderWire, ServiceType } from '../api/types';
import { t, type Lang } from '../i18n/strings';
import { Modal } from '../components/Modal';
import './orders.css';

function serviceBadge(s: ServiceType | null | undefined, lang: Lang): string {
  if (s === 'delivery') return t('foh.delivery', lang);
  if (s === 'takeaway') return t('foh.pickUp', lang);
  return t('foh.dineIn', lang);
}
function agoMin(iso: string): number {
  return Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
}
function timeOfDay(iso: string): string {
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

type Tab = 'ongoing' | 'completed';

export function Orders() {
  const lang = useSession((s) => s.lang);
  const session = useSession((s) => s.session)!;
  const cart = useCart();
  const orders = useOrders();
  const printers = usePrinters();
  const go = useNav((s) => s.go);

  const [tab, setTab] = useState<Tab>('ongoing');
  const [voiding, setVoiding] = useState<OrderWire | null>(null);
  const [accepting, setAccepting] = useState<OrderWire | null>(null);
  const [rejecting, setRejecting] = useState<OrderWire | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  // Tick every 30s to refresh age displays
  const [, tick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => tick((n) => n + 1), 30000);
    return () => clearInterval(id);
  }, []);

  const isManager = session.role === 'owner' || session.role === 'manager';
  const ongoing = useMemo(() => ongoingOrders(orders.orders), [orders.orders]);
  const done = useMemo(() => completedOrders(orders.orders), [orders.orders]);

  const ticketCtx: TicketContext = {
    restaurantName: session.restaurantName,
    outletName: session.outletName,
    serverRole: session.role,
  };

  const flash = (msg: string) => {
    setToast(msg);
    window.setTimeout(() => setToast(null), 2600);
  };

  const open = (order: OrderWire) => {
    cart.loadOrder(order);
    go('billing');
  };

  const reprint = async (order: OrderWire, paid: boolean) => {
    try {
      const canvas = renderReceipt(printers.paperDots(), ticketCtx, order, {
        paid,
        paymentLabel: order.paymentMethod,
      });
      await printers.print(canvas);
      flash(t('orders.reprinted', lang) + order.serialNumber);
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const handleAccept = async (order: OrderWire, prepMinutes: number, printKot: boolean) => {
    try {
      const updated = await orders.accept(session.outletId, order, prepMinutes);
      if (printKot) {
        const canvas = renderKot(
          printers.paperDots(), ticketCtx, updated,
          updated.items.map((it) => ({ qty: it.qty, name: it.name, note: it.note })),
        );
        await printers.print(canvas);
      }
      flash(t('orders.accepted', lang) + order.serialNumber);
      setAccepting(null);
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const handleReject = async (order: OrderWire) => {
    try {
      await orders.reject(session.outletId, order);
      flash(t('orders.rejected', lang) + order.serialNumber);
      setRejecting(null);
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const handleKot = async (order: OrderWire) => {
    try {
      const unsent = order.items.filter((it) => !it.kotSentAt);
      if (unsent.length === 0) {
        flash(t('orders.kotAlreadySent', lang));
        return;
      }
      const batchId = crypto.randomUUID();
      await api.sendKot(session.outletId, order.id, {
        batchId,
        itemIds: unsent.map((it) => it.id).filter((id): id is string => !!id),
      });
      const canvas = renderKot(
        printers.paperDots(), ticketCtx, order,
        unsent.map((it) => ({ qty: it.qty, name: it.name, note: it.note })),
        order.notes ?? undefined,
      );
      await printers.print(canvas);
      await orders.refresh(session.outletId);
      flash(t('foh.kotSent', lang) + order.serialNumber);
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const handlePrintBill = async (order: OrderWire) => {
    try {
      const canvas = renderReceipt(printers.paperDots(), ticketCtx, order, {
        paid: false,
        paymentLabel: order.paymentMethod,
      });
      await printers.print(canvas);
      flash(t('orders.billPrinted', lang) + order.serialNumber);
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const rows = tab === 'ongoing' ? ongoing : done;

  return (
    <div className="orders-root">
      <div className="orders-tabs">
        <button className={`orders-tab ${tab === 'ongoing' ? 'active' : ''}`} onClick={() => setTab('ongoing')}>
          {t('orders.ongoing', lang)} <span className="orders-count">{ongoing.length}</span>
        </button>
        <button className={`orders-tab ${tab === 'completed' ? 'active' : ''}`} onClick={() => setTab('completed')}>
          {t('orders.completed', lang)} <span className="orders-count">{done.length}</span>
        </button>
        <div className="orders-tabs-spacer" />
        <button className="tables-refresh" title={t('tables.refresh', lang)} onClick={() => void orders.refresh(session.outletId)}>⟳</button>
      </div>

      {rows.length === 0 ? (
        <div className="orders-empty card">{tab === 'ongoing' ? t('orders.noOngoing', lang) : t('orders.noCompleted', lang)}</div>
      ) : (
        <div className="orders-list">
          {rows.map((o) => tab === 'ongoing' ? (
            <OngoingCard
              key={o.id}
              lang={lang}
              order={o}
              isManager={isManager}
              onOpen={() => open(o)}
              onReprint={() => reprint(o, false)}
              onVoid={() => setVoiding(o)}
              onAccept={() => setAccepting(o)}
              onReject={() => setRejecting(o)}
              onKot={() => handleKot(o)}
              onPrintBill={() => handlePrintBill(o)}
            />
          ) : (
            <CompletedCard
              key={o.id}
              lang={lang}
              order={o}
              onReprint={() => reprint(o, true)}
            />
          ))}
        </div>
      )}

      {voiding && (
        <VoidModal
          lang={lang}
          order={voiding}
          onClose={() => setVoiding(null)}
          onConfirm={async (reason) => {
            try {
              await orders.voidOrder(session.outletId, voiding, reason);
              flash(t('orders.voided', lang) + voiding.serialNumber);
              setVoiding(null);
            } catch (e) {
              flash(e instanceof Error ? e.message : String(e));
            }
          }}
        />
      )}

      {accepting && (
        <AcceptModal
          lang={lang}
          order={accepting}
          onClose={() => setAccepting(null)}
          onAccept={(prep, pk) => handleAccept(accepting, prep, pk)}
        />
      )}

      {rejecting && (
        <ConfirmModal
          lang={lang}
          title={t('orders.rejectTitle', lang) + ' #' + rejecting.serialNumber + '?'}
          onClose={() => setRejecting(null)}
          onConfirm={() => handleReject(rejecting)}
          busy={false}
        >
          <p>{t('orders.rejectDesc', lang) + formatTk(rejecting.totalAmount) + t('orders.notifyCustomer', lang)}</p>
        </ConfirmModal>
      )}

      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

// --------------------------------------------------------- Ongoing card --------

function OngoingCard({
  lang, order, isManager,
  onOpen, onReprint, onVoid, onAccept, onReject, onKot, onPrintBill,
}: {
  lang: Lang;
  order: OrderWire;
  isManager: boolean;
  onOpen: () => void;
  onReprint: () => void;
  onVoid: () => void;
  onAccept: () => void;
  onReject: () => void;
  onKot: () => void;
  onPrintBill: () => void;
}) {
  const createdAt = order.createdAt;
  const ageMin = createdAt ? agoMin(createdAt) : 0;
  const isPending = order.status === 'pending';
  const isAccepted = order.status === 'accepted';

  const lateMinutes = isPending && ageMin > 20 ? ageMin - 20 : 0;
  const ageColor = !createdAt ? undefined :
    isAccepted && ageMin >= 120 ? '#DC2626' :
    isAccepted && ageMin >= 45 ? '#D97706' :
    undefined;

  const kotDone = (order.kotBatches?.length ?? 0) > 0 || order.items.some((it) => it.kotSentAt);

  const totalQty = order.items.reduce((n, it) => n + it.qty, 0);
  const previewItems = order.items.slice(0, 2).map((it) => {
    const prefix = it.qty > 1 ? `${it.qty}× ` : '';
    return `${prefix}${it.name}`;
  }).join(', ');

  return (
    <div className="order-row card">
      <div className="order-header">
        <span className="order-serial">#{order.serialNumber}</span>
        <span className="badge order-service">{serviceBadge(order.serviceType, lang)}</span>
        {order.tableNo && <span className="order-sub" style={{ fontSize: 'var(--fs-12)', color: 'var(--ink-2)' }}>{t('foh.table', lang)}{order.tableNo}</span>}
        <span className="order-total">{formatTk(order.totalAmount)}</span>
      </div>

      <div className="order-age" style={ageColor ? { color: ageColor, fontWeight: 700 } : undefined}>
        <span>{ageMin < 1 ? t('orders.lessThanMinAgo', lang) : ageMin + t('orders.minAgo', lang)}</span>
        {lateMinutes > 0 && <span className="order-late">+{lateMinutes}{t('orders.minLate', lang)}</span>}
      </div>

      {kotDone && <div className="order-kot">{t('orders.kot', lang)}</div>}

        <div className="order-preview">
          <strong>{totalQty}{t('orders.items', lang)}</strong>
          {previewItems && <span> · {previewItems}{order.items.length > 2 ? '…' : ''}</span>}
        </div>

      <div className="order-actions">
        {isPending && isManager && (
          <>
            <button className="order-reject" title={t('orders.reject', lang)} onClick={onReject}>✕</button>
            <button className="order-btn order-btn-accept" onClick={onAccept}>{t('orders.accept', lang)}</button>
          </>
        )}
        {isAccepted && (
          <>
            <button className="order-btn order-btn-kot" onClick={onKot}>{t('orders.kot', lang)}</button>
            <button className="order-btn order-btn-bill" onClick={onPrintBill}>{t('orders.printBill', lang)}</button>
          </>
        )}
        <button className="order-btn order-btn-open" onClick={onOpen}>{t('orders.open', lang)}</button>
        <button className="order-btn order-btn-reprint" onClick={onReprint}>{t('orders.reprint', lang)}</button>
        {isManager && (
          <button className="order-btn order-btn-void" onClick={onVoid}>{t('orders.void', lang)}</button>
        )}
      </div>
    </div>
  );
}

// ------------------------------------------------------- Completed card --------

function CompletedCard({ lang, order, onReprint }: { lang: Lang; order: OrderWire; onReprint: () => void }) {
  const [expanded, setExpanded] = useState(false);
  const allItems = order.items;
  const rowCap = 8;
  const visibleItems = expanded ? allItems : allItems.slice(0, rowCap);
  const hiddenCount = allItems.length - visibleItems.length;

  const metaParts = [
    order.paymentMethod?.toUpperCase(),
    serviceBadge(order.serviceType, lang),
    order.createdByRole ? t('orders.takenBy', lang) + order.createdByRole : null,
  ].filter(Boolean);

  return (
    <div className="order-row card">
      <div className="order-header">
        <span className="order-serial">#{order.serialNumber}</span>
        <span className="badge" style={{ background: 'var(--success-soft)', color: 'var(--success)' }}>{t('orders.completedBadge', lang)}</span>
        <span className="order-total" style={{ fontSize: 'var(--fs-13)', fontWeight: 500, color: 'var(--muted)' }}>
          {order.createdAt ? timeOfDay(order.createdAt) : ''}
        </span>
      </div>

      <div className="order-items">
        {visibleItems.map((it, i) => (
          <div className="order-item" key={it.id ?? i}>
            <span className="oi-qty">{it.qty}×</span>
            <span className="oi-name">{it.name}</span>
            <span className="oi-total">{formatTk(it.lineTotal)}</span>
          </div>
        ))}
        {!expanded && allItems.length > rowCap && (
          <button className="order-expand" onClick={() => setExpanded(true)}>
            +{hiddenCount}{t('orders.more', lang)} <span style={{ fontSize: 10 }}>▼</span>
          </button>
        )}
        {expanded && allItems.length > rowCap && (
          <button className="order-expand" onClick={() => setExpanded(false)}>
            {t('orders.showLess', lang)} <span style={{ fontSize: 10 }}>▲</span>
          </button>
        )}
      </div>

      <div className="order-divider" />

      {order.discountAmount != null && order.discountAmount > 0 && (
        <div className="order-discount">
          <span className="od-label">{order.discountLabel || t('foh.discountLabel', lang)}</span>
          <span className="od-amount">−{formatTk(order.discountAmount)}</span>
        </div>
      )}

      <div className="order-total-row">
        <span className="ot-label">{t('foh.total', lang)}</span>
        <span className="ot-amount">{formatTk(order.totalAmount)}</span>
      </div>

      {metaParts.length > 0 && (
        <div className="order-meta-line">{metaParts.join(' · ')}</div>
      )}

      <div className="order-actions">
        <button className="order-btn order-btn-reprint" onClick={onReprint}>{t('orders.reprint', lang)}</button>
      </div>
    </div>
  );
}

// ----------------------------------------------------------- Modals -----------

function VoidModal({
  lang, order, onClose, onConfirm,
}: {
  lang: Lang;
  order: OrderWire;
  onClose: () => void;
  onConfirm: (reason: string) => Promise<void>;
}) {
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  const confirm = () => {
    setBusy(true);
    void onConfirm(reason.trim() || t('orders.voidedAtCounter', lang)).finally(() => setBusy(false));
  };

  return (
    <Modal title={t('orders.voidOrder', lang) + ' #' + order.serialNumber} onClose={onClose} width={440}>
      <div className="void-body">
        <p className="void-warn">{t('orders.voidWarn', lang) + formatTk(order.totalAmount) + t('orders.auditEvent', lang)}</p>
        <textarea
          className="input void-reason" placeholder={t('orders.voidReason', lang)}
          value={reason} rows={3} onChange={(e) => setReason(e.target.value)}
        />
        <div className="void-actions">
          <button className="btn btn-outline" onClick={onClose}>{t('cancel', lang)}</button>
          <button className="btn btn-danger-outline" disabled={busy} onClick={confirm}>
            {busy ? t('orders.voiding', lang) : t('orders.voidOrder', lang)}
          </button>
        </div>
      </div>
    </Modal>
  );
}

function AcceptModal({
  lang, order, onClose, onAccept,
}: {
  lang: Lang;
  order: OrderWire;
  onClose: () => void;
  onAccept: (prepMinutes: number, printKot: boolean) => Promise<void>;
}) {
  const [prep, setPrep] = useState(20);
  const [busy, setBusy] = useState(false);

  const run = (printKot: boolean) => {
    setBusy(true);
    void onAccept(prep, printKot).finally(() => setBusy(false));
  };

  return (
    <Modal title={t('tables.acceptOrder', lang) + order.serialNumber} onClose={onClose} width={440}>
      <div className="accept-body">
        <label className="accept-row">
          {t('tables.prepTime', lang)}
          <span className="stepper">
            <button onClick={() => setPrep((v) => Math.max(0, v - 5))}>−</button>
            <input className="input" value={prep} inputMode="numeric"
              onChange={(e) => setPrep(Math.max(0, Number(e.target.value.replace(/\D/g, '')) || 0))} />
            <button onClick={() => setPrep((v) => v + 5)}>+</button>
          </span>
        </label>
        <div className="accept-actions">
          <button className="btn btn-outline" disabled={busy} onClick={() => run(false)}>{t('orders.accept', lang)}</button>
          <button className="btn btn-primary" disabled={busy} onClick={() => run(true)}>{t('tables.acceptPrint', lang)}</button>
        </div>
      </div>
    </Modal>
  );
}

function ConfirmModal({
  lang, title, children, onClose, onConfirm, busy,
}: {
  lang: Lang;
  title: string;
  children: React.ReactNode;
  onClose: () => void;
  onConfirm: () => Promise<void>;
  busy: boolean;
}) {
  return (
    <Modal title={title} onClose={onClose} width={400}>
      <div className="reject-body">
        {children}
        <div className="reject-actions">
          <button className="btn btn-outline" onClick={onClose}>{t('cancel', lang)}</button>
          <button className="btn btn-danger-outline" disabled={busy} onClick={onConfirm}>
            {busy ? t('orders.processing', lang) : t('orders.confirm', lang)}
          </button>
        </div>
      </div>
    </Modal>
  );
}
