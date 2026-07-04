// Orders — ongoing / completed lists with open-to-edit, reprint, and manager void.

import { useMemo, useState } from 'react';
import { useSession } from '../state/session';
import { useCart } from '../state/cart';
import { useNav } from '../state/nav';
import { useOrders, ongoingOrders, completedOrders } from '../state/orders';
import { usePrinters } from '../print/printManager';
import { renderReceipt, type TicketContext } from '../print/ticketRenderer';
import { formatTk } from '../core/money';
import type { OrderWire, ServiceType } from '../api/types';
import { Modal } from '../components/Modal';
import './orders.css';

function serviceBadge(s?: ServiceType | null): string {
  if (s === 'delivery') return 'Delivery';
  if (s === 'takeaway') return 'Pick Up';
  return 'Dine In';
}
function when(iso?: string | null): string {
  if (!iso) return '';
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

type Tab = 'ongoing' | 'completed';

export function Orders() {
  const session = useSession((s) => s.session)!;
  const cart = useCart();
  const orders = useOrders();
  const printers = usePrinters();
  const go = useNav((s) => s.go);

  const [tab, setTab] = useState<Tab>('ongoing');
  const [voiding, setVoiding] = useState<OrderWire | null>(null);
  const [toast, setToast] = useState<string | null>(null);

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
      const canvas = renderReceipt(printers.paperDots('bill'), ticketCtx, order, {
        paid,
        paymentLabel: order.paymentMethod,
      });
      await printers.print('bill', canvas);
      flash(`Reprinted #${order.serialNumber}`);
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e));
    }
  };

  const rows = tab === 'ongoing' ? ongoing : done;

  return (
    <div className="orders-root">
      <div className="orders-tabs">
        <button className={`orders-tab ${tab === 'ongoing' ? 'active' : ''}`} onClick={() => setTab('ongoing')}>
          Ongoing <span className="orders-count">{ongoing.length}</span>
        </button>
        <button className={`orders-tab ${tab === 'completed' ? 'active' : ''}`} onClick={() => setTab('completed')}>
          Completed <span className="orders-count">{done.length}</span>
        </button>
        <div className="orders-tabs-spacer" />
        <button className="tables-refresh" title="Refresh" onClick={() => void orders.refresh(session.outletId)}>⟳</button>
      </div>

      {rows.length === 0 ? (
        <div className="orders-empty card">No {tab} orders.</div>
      ) : (
        <div className="orders-list">
          {rows.map((o) => (
            <div className="order-row card" key={o.id}>
              <div className="order-main">
                <span className="order-serial">#{o.serialNumber}</span>
                <span className="badge order-service">{serviceBadge(o.serviceType)}</span>
                {o.tableNo && <span className="order-sub">Table {o.tableNo}</span>}
                {o.customerName && <span className="order-sub">{o.customerName}</span>}
                <span className="order-sub">{o.items.reduce((n, it) => n + it.qty, 0)} items</span>
              </div>
              <div className="order-meta">
                <span className="order-time">
                  {tab === 'completed'
                    ? `Settled ${when(o.settledAt ?? o.updatedAt)}`
                    : when(o.createdAt)}
                </span>
                {tab === 'completed' && o.paymentMethod && (
                  <span className="order-pay">{o.paymentMethod.toUpperCase()}</span>
                )}
                <span className="order-total">{formatTk(o.totalAmount)}</span>
              </div>
              <div className="order-actions">
                {tab === 'ongoing' && (
                  <button className="btn btn-outline btn-sm" onClick={() => open(o)}>Open</button>
                )}
                <button className="btn btn-outline btn-sm" onClick={() => void reprint(o, tab === 'completed')}>Reprint</button>
                {tab === 'ongoing' && isManager && (
                  <button className="btn btn-danger-outline btn-sm" onClick={() => setVoiding(o)}>Void</button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {voiding && (
        <VoidModal
          order={voiding}
          onClose={() => setVoiding(null)}
          onConfirm={async (reason) => {
            try {
              await orders.voidOrder(session.outletId, voiding, reason);
              flash(`Voided #${voiding.serialNumber}`);
              setVoiding(null);
            } catch (e) {
              flash(e instanceof Error ? e.message : String(e));
            }
          }}
        />
      )}

      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

function VoidModal({
  order, onClose, onConfirm,
}: {
  order: OrderWire;
  onClose: () => void;
  onConfirm: (reason: string) => Promise<void>;
}) {
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  const confirm = () => {
    setBusy(true);
    void onConfirm(reason.trim() || 'Voided at counter').finally(() => setBusy(false));
  };

  return (
    <Modal title={`Void order #${order.serialNumber}`} onClose={onClose} width={440}>
      <div className="void-body">
        <p className="void-warn">This cancels the order ({formatTk(order.totalAmount)}) and records a manager audit event.</p>
        <textarea
          className="input void-reason" placeholder="Reason (e.g. customer left, wrong order)"
          value={reason} rows={3} onChange={(e) => setReason(e.target.value)}
        />
        <div className="void-actions">
          <button className="btn btn-outline" onClick={onClose}>Cancel</button>
          <button className="btn btn-danger-outline" disabled={busy} onClick={confirm}>
            {busy ? 'Voiding…' : 'Void order'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
