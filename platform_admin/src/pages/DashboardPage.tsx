import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { apiFetch, Stats } from "../api/client";
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

  return (
    <>
      <div className="page-header">
        <h1>Dashboard</h1>
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
          <div className="label">Pending payments</div>
          <div className="value">{stats.pendingPayments}</div>
        </div>
        <div className="stat-card">
          <div className="label">Orders (7 days)</div>
          <div className="value">{stats.ordersLast7Days}</div>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 style={{ marginTop: 0, fontSize: 16 }}>Recent outlets</h2>
        <table>
          <thead>
            <tr>
              <th>Outlet</th>
              <th>Restaurant</th>
              <th>Status</th>
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
                <td>
                  <Link to={`/outlets/${o.id}`}>View</Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2 style={{ marginTop: 0, fontSize: 16 }}>Recent payments</h2>
        <table>
          <thead>
            <tr>
              <th>Outlet</th>
              <th>Amount</th>
              <th>Plan</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {stats.recentPayments.map((p) => (
              <tr key={p.paymentId}>
                <td>{p.outletName || p.serverId}</td>
                <td>
                  {p.amount} {p.currency}
                </td>
                <td>{p.plan || "—"}</td>
                <td>
                  <StatusBadge status={p.status} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
