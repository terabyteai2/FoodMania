import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import {
  AdminAccount,
  apiFetch,
  Order,
  Outlet,
  OutletActivity,
  Subscription,
} from "../api/client";
import StatusBadge from "../components/StatusBadge";

const PACKAGES = ["standard", "pro", "premium"] as const;

type CustomerInfo = {
  outletId: string;
  outletName: string;
  restaurantName: string;
  customerMenuUrl: string;
  menuItemCount: number;
  galleryImageCount: number;
};

type NewAccountForm = {
  email: string;
  username: string;
  password: string;
  displayName: string;
  role: string;
};

const TABS = ["overview", "accounts", "subscription", "orders", "activity"] as const;
type Tab = (typeof TABS)[number];

export default function OutletDetailPage() {
  const { outletId } = useParams<{ outletId: string }>();
  const [tab, setTab] = useState<Tab>("overview");
  const [outlet, setOutlet] = useState<Outlet | null>(null);
  const [accounts, setAccounts] = useState<AdminAccount[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [customerInfo, setCustomerInfo] = useState<CustomerInfo | null>(null);
  const [activity, setActivity] = useState<OutletActivity | null>(null);
  const [error, setError] = useState("");
  const [notes, setNotes] = useState("");
  const [outletName, setOutletName] = useState("");
  const [outletStatus, setOutletStatus] = useState("active");

  // Create account form state
  const [showAccountForm, setShowAccountForm] = useState(false);
  const [accountForm, setAccountForm] = useState<NewAccountForm>({
    email: "",
    username: "",
    password: "",
    displayName: "",
    role: "manager",
  });
  const [accountFormError, setAccountFormError] = useState("");
  const [accountSubmitting, setAccountSubmitting] = useState(false);

  const loadOutlet = useCallback(() => {
    if (!outletId) return;
    apiFetch<Outlet>(`/platform/outlets/${outletId}`)
      .then((o) => {
        setOutlet(o);
        setNotes(o.notes || "");
        setOutletStatus(o.status);
        setOutletName(o.name);
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
    if (tab === "activity") {
      apiFetch<OutletActivity>(`/platform/outlets/${outletId}/activity`)
        .then(setActivity)
        .catch((e) => setError(e.message));
    }
  }, [tab, outletId, outlet?.serverId]);

  async function saveOutlet() {
    if (!outletId) return;
    try {
      const updated = await apiFetch<Outlet>(`/platform/outlets/${outletId}`, {
        method: "PATCH",
        body: JSON.stringify({ name: outletName, status: outletStatus, notes }),
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
        prev.map((a) => (a.id === account.id ? { ...a, isActive: !a.isActive } : a))
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "Update failed");
    }
  }

  async function createAccount() {
    if (!outletId) return;
    if (!accountForm.email || !accountForm.username || !accountForm.password) {
      setAccountFormError("Email, username and password are required");
      return;
    }
    setAccountSubmitting(true);
    setAccountFormError("");
    try {
      const created = await apiFetch<AdminAccount>(`/platform/outlets/${outletId}/accounts`, {
        method: "POST",
        body: JSON.stringify({
          email: accountForm.email,
          username: accountForm.username,
          password: accountForm.password,
          displayName: accountForm.displayName || null,
          role: accountForm.role,
        }),
      });
      setAccounts((prev) => [...prev, created]);
      setAccountForm({ email: "", username: "", password: "", displayName: "", role: "manager" });
      setShowAccountForm(false);
    } catch (e) {
      setAccountFormError(e instanceof Error ? e.message : "Create failed");
    } finally {
      setAccountSubmitting(false);
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

  function fmt(n: number) {
    return n.toLocaleString("en-BD", { maximumFractionDigits: 0 });
  }

  return (
    <>
      <div className="page-header">
        <h1 style={{ wordBreak: "break-word", minWidth: 0 }}>{outlet.name}</h1>
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
                Open menu ↗
              </a>
            </div>
            {customerInfo && (
              <>
                <div className="detail-row">
                  <span className="label">Menu items</span>
                  <span>{customerInfo.menuItemCount}</span>
                </div>
                {customerInfo.galleryImageCount > 0 && (
                  <div className="detail-row">
                    <span className="label">Gallery images</span>
                    <span>{customerInfo.galleryImageCount}</span>
                  </div>
                )}
              </>
            )}
          </div>

          <div className="two-col-grid" style={{ marginTop: 16 }}>
            <div className="form-group">
              <label>Outlet name</label>
              <input
                type="text"
                value={outletName}
                onChange={(e) => setOutletName(e.target.value)}
                style={{ width: "100%" }}
              />
            </div>
            <div className="form-group">
              <label>Status</label>
              <select
                value={outletStatus}
                onChange={(e) => setOutletStatus(e.target.value)}
                style={{ width: "100%" }}
              >
                <option value="active">active</option>
                <option value="suspended">suspended</option>
              </select>
            </div>
          </div>
          <div className="form-group">
            <label>Internal notes</label>
            <textarea
              rows={3}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              style={{ width: "100%" }}
            />
          </div>
          <button type="button" className="btn" onClick={saveOutlet}>
            Save changes
          </button>
        </div>
      )}

      {tab === "accounts" && (
        <div className="tab-panel card">
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16, gap: 8, flexWrap: "wrap" }}>
            <h3 style={{ margin: 0, fontSize: 15 }}>Admin accounts</h3>
            <button
              type="button"
              className="btn"
              style={{ fontSize: 13 }}
              onClick={() => setShowAccountForm((v) => !v)}
            >
              {showAccountForm ? "Cancel" : "+ Create account"}
            </button>
          </div>

          {showAccountForm && (
            <div style={{ background: "var(--surface2)", borderRadius: 8, padding: 16, marginBottom: 16 }}>
              <h4 style={{ margin: "0 0 12px", fontSize: 14 }}>New account</h4>
              {accountFormError && <p className="error-msg">{accountFormError}</p>}
              <div className="two-col-grid">
                <div className="form-group">
                  <label>Email *</label>
                  <input
                    type="email"
                    value={accountForm.email}
                    onChange={(e) => setAccountForm((f) => ({ ...f, email: e.target.value }))}
                    style={{ width: "100%" }}
                  />
                </div>
                <div className="form-group">
                  <label>Username *</label>
                  <input
                    type="text"
                    value={accountForm.username}
                    onChange={(e) => setAccountForm((f) => ({ ...f, username: e.target.value }))}
                    style={{ width: "100%" }}
                  />
                </div>
                <div className="form-group">
                  <label>Password *</label>
                  <input
                    type="password"
                    value={accountForm.password}
                    onChange={(e) => setAccountForm((f) => ({ ...f, password: e.target.value }))}
                    style={{ width: "100%" }}
                  />
                </div>
                <div className="form-group">
                  <label>Display name</label>
                  <input
                    type="text"
                    value={accountForm.displayName}
                    onChange={(e) => setAccountForm((f) => ({ ...f, displayName: e.target.value }))}
                    style={{ width: "100%" }}
                  />
                </div>
                <div className="form-group">
                  <label>Role</label>
                  <select
                    value={accountForm.role}
                    onChange={(e) => setAccountForm((f) => ({ ...f, role: e.target.value }))}
                    style={{ width: "100%" }}
                  >
                    <option value="manager">manager</option>
                    <option value="staff">staff</option>
                  </select>
                </div>
              </div>
              <button
                type="button"
                className="btn"
                onClick={createAccount}
                disabled={accountSubmitting}
                style={{ marginTop: 8 }}
              >
                {accountSubmitting ? "Creating…" : "Create account"}
              </button>
            </div>
          )}

          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Phone</th>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Status</th>
                  <th>Auth</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {accounts.map((a) => (
                  <tr key={a.id}>
                    <td>{a.phone || "—"}</td>
                    <td className="muted" style={{ fontSize: 12 }}>{a.email}</td>
                    <td>
                      <span className="badge badge-pending">{a.role}</span>
                    </td>
                    <td>
                      {a.inviteStatus === "pending" ? (
                        <span className="badge badge-pending">pending invite</span>
                      ) : a.inviteStatus === "declined" ? (
                        <span className="badge badge-suspended">declined</span>
                      ) : (
                        <StatusBadge status={a.isActive ? "active" : "suspended"} />
                      )}
                    </td>
                    <td className="muted" style={{ fontSize: 12 }}>{a.authProvider}</td>
                    <td>
                      <button
                        type="button"
                        className="btn-secondary btn"
                        style={{ fontSize: 12, padding: "4px 10px" }}
                        onClick={() => toggleAccount(a)}
                      >
                        {a.isActive ? "Disable" : "Enable"}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {accounts.length === 0 && <p className="muted">No accounts yet.</p>}
        </div>
      )}

      {tab === "subscription" && (
        <div className="tab-panel card">
          <p className="muted" style={{ fontSize: 13, marginTop: 0 }}>
            Manual monthly billing — no payment gateway required.
          </p>
          {sub ? (
            <>
              <div className="detail-grid" style={{ marginBottom: 16 }}>
                <div className="detail-row">
                  <span className="label">Package</span>
                  <strong>{sub.package || (sub.plan === "trial" ? "—" : sub.plan)}</strong>
                </div>
                <div className="detail-row">
                  <span className="label">Status</span>
                  <StatusBadge status={sub.status} />
                </div>
                <div className="detail-row">
                  <span className="label">Started</span>
                  <span>{new Date(sub.startsAt).toLocaleDateString()}</span>
                </div>
                <div className="detail-row">
                  <span className="label">Expires</span>
                  <span className={sub.expiresAt && new Date(sub.expiresAt) < new Date() ? "danger-text" : ""}>
                    {sub.expiresAt ? new Date(sub.expiresAt).toLocaleString() : "—"}
                  </span>
                </div>
              </div>

              <div className="detail-grid" style={{ marginBottom: 16, padding: 12, background: "var(--surface2)", borderRadius: 8 }}>
                <div className="detail-row">
                  <span className="label">Change package</span>
                  <select
                    defaultValue={sub.package || "standard"}
                    onChange={(e) =>
                      subscriptionAction({
                        package: e.target.value,
                        status: sub.status,
                        plan: sub.plan,
                      })
                    }
                    style={{ padding: "4px 8px", borderRadius: 4, border: "1px solid var(--border)" }}
                  >
                    {PACKAGES.map((p) => (
                      <option key={p} value={p}>{p}</option>
                    ))}
                  </select>
                </div>
              </div>
            </>
          ) : (
            <p className="muted">No subscription record yet.</p>
          )}
          <div className="actions-row">
            {sub?.status !== "cancelled" && (
              <button
                type="button"
                className="btn"
                onClick={() =>
                  subscriptionAction({
                    plan: sub?.plan || "monthly",
                    package: sub?.package || "standard",
                    status: "active",
                    extendDays: 30,
                  })
                }
                disabled={sub?.status === "trial" || sub?.status === "on_hold"}
              >
                Extend 30 days & set active
              </button>
            )}
            {(!sub || sub.status === "trial") && (
              <button
                type="button"
                className="btn"
                onClick={() =>
                  subscriptionAction({
                    package: sub?.package || "standard",
                    status: "on_hold",
                    plan: sub?.plan || "monthly",
                  })
                }
              >
                End trial (on hold)
              </button>
            )}
            {sub && sub.status !== "cancelled" && sub.status !== "paused" && (
              <button
                type="button"
                className="btn"
                onClick={() =>
                  subscriptionAction({
                    plan: sub.plan,
                    package: sub.package,
                    status: "paused",
                  })
                }
              >
                Pause
              </button>
            )}
            {(sub?.status === "paused" || sub?.status === "on_hold") && (
              <button
                type="button"
                className="btn"
                onClick={() =>
                  subscriptionAction({
                    plan: sub?.plan || "monthly",
                    package: sub?.package || "standard",
                    status: "active",
                    extendDays: sub?.expiresAt
                      ? Math.max(1, Math.ceil((new Date(sub.expiresAt).getTime() - Date.now()) / 86400000))
                      : 30,
                  })
                }
              >
                Resume (active)
              </button>
            )}
            {sub && !["cancelled", "paused"].includes(sub.status) && (
              <button
                type="button"
                className="btn-danger btn"
                onClick={() =>
                  subscriptionAction({ plan: sub.plan, package: sub.package, status: "cancelled" })
                }
              >
                Cancel
              </button>
            )}
          </div>
        </div>
      )}

      {tab === "orders" && (
        <div className="tab-panel card">
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>#</th>
                  <th>Source</th>
                  <th>Status</th>
                  <th>Total</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {orders.map((o) => (
                  <tr key={o.id}>
                    <td>{o.serialNumber}</td>
                    <td className="muted" style={{ fontSize: 12 }}>{o.source}</td>
                    <td>
                      <StatusBadge status={o.status} />
                    </td>
                    <td>৳{o.totalAmount}</td>
                    <td className="muted" style={{ fontSize: 12, whiteSpace: "nowrap" }}>
                      {new Date(o.createdAt).toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {orders.length === 0 && <p className="muted">No orders.</p>}
        </div>
      )}

      {tab === "activity" && (
        <div className="tab-panel">
          {!activity ? (
            <p className="muted">Loading activity…</p>
          ) : (
            <div className="two-col-grid" style={{ gap: 20 }}>
              <div className="card">
                <h3 style={{ margin: "0 0 16px", fontSize: 15 }}>Orders</h3>
                <div className="detail-grid">
                  <div className="detail-row">
                    <span className="label">Total orders</span>
                    <strong>{activity.totalOrders}</strong>
                  </div>
                  <div className="detail-row">
                    <span className="label">Last 30 days</span>
                    <strong>{activity.ordersLast30Days}</strong>
                  </div>
                  <div className="detail-row">
                    <span className="label">Last order</span>
                    <span>
                      {activity.lastOrderAt
                        ? new Date(activity.lastOrderAt).toLocaleString()
                        : "Never"}
                    </span>
                  </div>
                </div>
              </div>
              <div className="card">
                <h3 style={{ margin: "0 0 16px", fontSize: 15 }}>Setup</h3>
                <div className="detail-grid">
                  <div className="detail-row">
                    <span className="label">Admin accounts</span>
                    <strong>{activity.accountCount}</strong>
                  </div>
                  <div className="detail-row">
                    <span className="label">Devices registered</span>
                    <strong>{activity.deviceCount}</strong>
                  </div>
                  <div className="detail-row">
                    <span className="label">Total revenue</span>
                    <strong style={{ color: "var(--success)" }}>৳{fmt(activity.totalRevenue)}</strong>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </>
  );
}
