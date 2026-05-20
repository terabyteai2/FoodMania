import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { apiFetch, Subscription } from "../api/client";
import StatusBadge from "../components/StatusBadge";

export default function SubscriptionsPage() {
  const [subs, setSubs] = useState<Subscription[]>([]);
  const [statusFilter, setStatusFilter] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    const params = statusFilter ? `?status=${encodeURIComponent(statusFilter)}` : "";
    apiFetch<Subscription[]>(`/platform/subscriptions${params}`)
      .then(setSubs)
      .catch((e) => setError(e.message));
  }, [statusFilter]);

  return (
    <>
      <div className="page-header">
        <h1>Subscriptions</h1>
      </div>

      <div className="search-bar">
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="">All statuses</option>
          <option value="active">active</option>
          <option value="trial">trial</option>
          <option value="expired">expired</option>
          <option value="cancelled">cancelled</option>
        </select>
      </div>

      {error && <p className="error-msg">{error}</p>}

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>Outlet</th>
              <th>Restaurant</th>
              <th>Plan</th>
              <th>Status</th>
              <th>Expires</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {subs.map((s) => (
              <tr key={s.id}>
                <td>{s.outletName || s.outletId}</td>
                <td>{s.restaurantName || "—"}</td>
                <td>{s.plan}</td>
                <td>
                  <StatusBadge status={s.status} />
                </td>
                <td>{s.expiresAt ? new Date(s.expiresAt).toLocaleDateString() : "—"}</td>
                <td>
                  <Link to={`/outlets/${s.outletId}`}>Manage</Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {subs.length === 0 && !error && <p className="muted">No subscriptions.</p>}
      </div>
    </>
  );
}
