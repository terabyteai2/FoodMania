import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import {
  AdminAccount,
  apiFetch,
  Order,
  Outlet,
  Payment,
  Subscription,
} from "../api/client";
import StatusBadge from "../components/StatusBadge";

type CustomerInfo = {
  outletId: string;
  outletName: string;
  restaurantName: string;
  customerMenuUrl: string;
  menuItemCount: number;
  galleryImageCount: number;
};

const TABS = ["overview", "accounts", "subscription", "payments", "orders"] as const;
type Tab = (typeof TABS)[number];

export default function OutletDetailPage() {
  const { outletId } = useParams<{ outletId: string }>();
  const [tab, setTab] = useState<Tab>("overview");
  const [outlet, setOutlet] = useState<Outlet | null>(null);
  const [accounts, setAccounts] = useState<AdminAccount[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [customerInfo, setCustomerInfo] = useState<CustomerInfo | null>(null);
  const [error, setError] = useState("");
  const [notes, setNotes] = useState("");
  const [status, setStatus] = useState("active");

  const loadOutlet = useCallback(() => {
    if (!outletId) return;
    apiFetch<Outlet>(`/platform/outlets/${outletId}`)
      .then((o) => {
        setOutlet(o);
        setNotes(o.notes || "");
        setStatus(o.status);
      })
      .catch((e) => setError(e.message));
  }, [outletId]);

  useEffect(() => {
    loadOutlet();
  }, [loadOutlet]);

  useEffect(() => {
    if (!outletId) return;
    if (tab === "accounts") {
      apiFetch<AdminAccount[]>(`/platform/outlets/${outletId}/accounts`)
        .then(setAccounts)
        .catch((e) => setError(e.message));
    }
    if (tab === "payments") {
      apiFetch<Payment[]>("/platform/payments?limit=100")
        .then((all) => setPayments(all.filter((p) => p.outletId === outletId || p.serverId === outlet?.serverId)))
        .catch((e) => setError(e.message));
    }
    if (tab === "orders") {
      apiFetch<Order[]>(`/platform/outlets/${outletId}/orders`)
        .then(setOrders)
        .catch((e) => setError(e.message));
    }
    if (tab === "overview") {
      apiFetch<CustomerInfo>(`/platform/outlets/${outletId}/customer-info`)
        .then(setCustomerInfo)
        .catch(() => setCustomerInfo(null));
    }
  }, [tab, outletId, outlet?.serverId]);

  async function saveOutlet() {
    if (!outletId) return;
    try {
      const updated = await apiFetch<Outlet>(`/platform/outlets/${outletId}`, {
        method: "PATCH",
        body: JSON.stringify({ name: outlet?.name, status, notes }),
      });
      setOutlet(updated);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Save failed");
    }
  }

  async function toggleAccount(account: AdminAccount) {
    try {
      await apiFetch(`/platform/accounts/${account.id}`, {
        method: "PATCH",
        body: JSON.stringify({ isActive: !account.isActive }),
      });
      setAccounts((prev) =>
        prev.map((a) => (a.id === account.id ? { ...a, isActive: !a.isActive } : a)),
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "Update failed");
    }
  }

  async function subscriptionAction(body: Record<string, unknown>) {
    if (!outletId) return;
    try {
      const sub = await apiFetch<Subscription>(`/platform/outlets/${outletId}/subscription`, {
        method: "POST",
        body: JSON.stringify(body),
      });
      setOutlet((o) => (o ? { ...o, subscription: sub } : o));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Subscription update failed");
    }
  }

  if (!outlet) {
    return <p className="muted">{error || "Loading…"}</p>;
  }

  const sub = outlet.subscription;

  return (
    <>
      <div className="page-header">
        <h1>{outlet.name}</h1>
        <Link to="/restaurants" className="muted">
          ← Back
        </Link>
      </div>

      {error && <p className="error-msg">{error}</p>}

      <div className="tabs">
        {TABS.map((t) => (
          <button
            key={t}
            type="button"
            className={`tab ${tab === t ? "active" : ""}`}
            onClick={() => setTab(t)}
          >
            {t.charAt(0).toUpperCase() + t.slice(1)}
          </button>
        ))}
      </div>

      {tab === "overview" && (
        <div className="tab-panel card">
          <div className="detail-grid">
            <div className="detail-row">
              <span className="label">Outlet ID</span>
              <code>{outlet.id}</code>
            </div>
            <div className="detail-row">
              <span className="label">Restaurant</span>
              <span>{outlet.restaurantName}</span>
            </div>
            <div className="detail-row">
              <span className="label">Server ID</span>
              <code>{outlet.serverId}</code>
            </div>
            <div className="detail-row">
              <span className="label">Customer menu</span>
              <a href={outlet.customerMenuUrl} target="_blank" rel="noreferrer">
                Open menu
              </a>
            </div>
            {customerInfo && (
              <div className="detail-row">
                <span className="label">Menu items</span>
                <span>{customerInfo.menuItemCount}</span>
              </div>
            )}
          </div>

          <div className="form-group">
            <label>Status</label>
            <select value={status} onChange={(e) => setStatus(e.target.value)}>
              <option value="active">active</option>
              <option value="suspended">suspended</option>
            </select>
          </div>
          <div className="form-group">
            <label>Internal notes</label>
            <textarea rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} style={{ width: "100%" }} />
          </div>
          <button type="button" className="btn" onClick={saveOutlet}>
            Save changes
          </button>
        </div>
      )}

      {tab === "accounts" && (
        <div className="tab-panel card">
          <table>
            <thead>
              <tr>
                <th>Email</th>
                <th>Role</th>
                <th>Active</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {accounts.map((a) => (
                <tr key={a.id}>
                  <td>{a.email}</td>
                  <td>{a.role}</td>
                  <td>{a.isActive ? "Yes" : "No"}</td>
                  <td>
                    <button type="button" className="btn-secondary btn" onClick={() => toggleAccount(a)}>
                      {a.isActive ? "Disable" : "Enable"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {tab === "subscription" && (
        <div className="tab-panel card">
          {sub ? (
            <>
              <p>
                Plan: <strong>{sub.plan}</strong> · <StatusBadge status={sub.status} />
              </p>
              <p className="muted">
                Expires: {sub.expiresAt ? new Date(sub.expiresAt).toLocaleString() : "—"}
              </p>
            </>
          ) : (
            <p className="muted">No subscription record yet.</p>
          )}
          <div className="actions-row">
            <button
              type="button"
              className="btn"
              onClick={() => subscriptionAction({ plan: "monthly", status: "active", extendDays: 30 })}
            >
              Extend 30 days
            </button>
            <button
              type="button"
              className="btn-secondary btn"
              onClick={() => subscriptionAction({ plan: "monthly", status: "trial" })}
            >
              Mark trial
            </button>
            <button
              type="button"
              className="btn-danger btn"
              onClick={() => subscriptionAction({ plan: sub?.plan || "monthly", status: "cancelled" })}
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {tab === "payments" && (
        <div className="tab-panel card">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Gateway</th>
                <th>Amount</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {payments.map((p) => (
                <tr key={p.paymentId}>
                  <td>{new Date(p.createdAt).toLocaleString()}</td>
                  <td>{p.gateway}</td>
                  <td>
                    {p.amount} {p.currency}
                  </td>
                  <td>
                    <StatusBadge status={p.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {payments.length === 0 && <p className="muted">No payments for this outlet.</p>}
        </div>
      )}

      {tab === "orders" && (
        <div className="tab-panel card">
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>Status</th>
                <th>Total</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {orders.map((o) => (
                <tr key={o.id}>
                  <td>{o.serialNumber}</td>
                  <td>
                    <StatusBadge status={o.status} />
                  </td>
                  <td>{o.totalAmount}</td>
                  <td>{new Date(o.createdAt).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {orders.length === 0 && <p className="muted">No orders.</p>}
        </div>
      )}
    </>
  );
}
