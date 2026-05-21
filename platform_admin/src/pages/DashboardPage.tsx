import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { apiFetch, Activation, Stats } from "../api/client";
import StatusBadge from "../components/StatusBadge";

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    apiFetch<Stats>("/platform/stats")
      .then(setStats)
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <p className="error-msg">{error}</p>;
  if (!stats) return <p className="muted">Loading…</p>;

  const mrr = stats.mrr ?? 0;
  const expiringSoon = stats.expiringSoon ?? 0;

  function fmt(n: number) {
    return (n ?? 0).toLocaleString("en-BD", { maximumFractionDigits: 0 });
  }

  return (
    <>
      <div className="page-header">
        <h1>Dashboard</h1>
        <span className="muted" style={{ fontSize: 13 }}>Company overview</span>
      </div>

      <div className="stat-grid">
        <div className="stat-card">
          <div className="label">Restaurants</div>
          <div className="value">{stats.restaurants}</div>
        </div>
        <div className="stat-card">
          <div className="label">Outlets</div>
          <div className="value">{stats.outlets}</div>
        </div>
        <div className="stat-card">
          <div className="label">Active subscriptions</div>
          <div className="value">{stats.activeSubscriptions}</div>
        </div>
        <div className="stat-card">
          <div className="label">MRR (30 days)</div>
          <div className="value" style={{ color: "var(--success)" }}>৳{fmt(mrr)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Awaiting activation</div>
          <div
            className="value"
            style={{
              color: (stats.pendingActivations ?? stats.pendingPayments ?? 0) > 0
                ? "var(--warning)"
                : undefined,
            }}
          >
            {stats.pendingActivations ?? stats.pendingPayments ?? 0}
          </div>
          {(stats.pendingActivations ?? stats.pendingPayments ?? 0) > 0 && (
            <Link to="/activations" style={{ fontSize: 12 }}>
              Activate →
            </Link>
          )}
        </div>
        <div className="stat-card">
          <div className="label">Orders (7 days)</div>
          <div className="value">{stats.ordersLast7Days}</div>
        </div>
        {expiringSoon > 0 && (
          <div className="stat-card" style={{ border: "1px solid var(--warning)" }}>
            <div className="label" style={{ color: "var(--warning)" }}>Expiring soon</div>
            <div className="value" style={{ color: "var(--warning)" }}>{expiringSoon}</div>
            <Link to="/subscriptions?status=active" style={{ fontSize: 12 }}>
              View →
            </Link>
          </div>
        )}
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 style={{ marginTop: 0, fontSize: 16 }}>Recent outlets</h2>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Outlet</th>
                <th>Restaurant</th>
                <th>Status</th>
                <th>Joined</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {stats.recentOutlets.map((o) => (
                <tr key={o.id}>
                  <td>{o.name}</td>
                  <td>{o.restaurantName}</td>
                  <td>
                    <StatusBadge status={o.status} />
                  </td>
                  <td className="muted" style={{ fontSize: 12 }}>
                    {new Date(o.createdAt).toLocaleDateString()}
                  </td>
                  <td>
                    <Link to={`/outlets/${o.id}`}>View</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="card">
        <h2 style={{ marginTop: 0, fontSize: 16 }}>Awaiting activation</h2>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Restaurant</th>
                <th>Outlet</th>
                <th>Manager</th>
                <th>Plan</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {(stats.pendingActivationsList ?? []).map((r: Activation) => (
                <tr key={r.outletId}>
                  <td>{r.restaurantName}</td>
                  <td>{r.outletName}</td>
                  <td className="muted" style={{ fontSize: 12 }}>{r.managerEmail || "—"}</td>
                  <td>{r.plan}</td>
                  <td>
                    <Link to={`/outlets/${r.outletId}`}>Manage</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {(stats.pendingActivationsList ?? []).length === 0 && (
          <p className="muted">No restaurants waiting for activation.</p>
        )}
        {(stats.pendingActivations ?? 0) > 0 && (
          <p style={{ marginTop: 12 }}>
            <Link to="/activations">View all {stats.pendingActivations} →</Link>
          </p>
        )}
      </div>
    </>
  );
}
