import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Activation, apiFetch } from "../api/client";
import StatusBadge from "../components/StatusBadge";

export default function ActivationsPage() {
  const [rows, setRows] = useState<Activation[]>([]);
  const [error, setError] = useState("");
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(() => {
    apiFetch<Activation[]>("/platform/activations?limit=100")
      .then(setRows)
      .catch((e) => setError(e.message));
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function activate(outletId: string, plan: string) {
    setBusyId(outletId);
    setError("");
    try {
      await apiFetch(`/platform/outlets/${outletId}/subscription`, {
        method: "POST",
        body: JSON.stringify({
          plan: plan === "annual" ? "annual" : "monthly",
          status: "active",
          extendDays: plan === "annual" ? 365 : 30,
        }),
      });
      setRows((list) => list.filter((r) => r.outletId !== outletId));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Activation failed");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <>
      <div className="page-header">
        <h1>Activations</h1>
        <p className="muted" style={{ margin: 0, fontSize: 13 }}>
          New restaurants appear here after they pick a plan in the app. Click{" "}
          <strong>Activate</strong> to unlock login — no payment gateway required.
        </p>
      </div>

      {error && <p className="error-msg">{error}</p>}

      <div className="card">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Signed up</th>
                <th>Restaurant</th>
                <th>Outlet</th>
                <th>Manager phone</th>
                <th>Manager email</th>
                <th>Plan</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.outletId}>
                  <td className="muted" style={{ fontSize: 12, whiteSpace: "nowrap" }}>
                    {new Date(r.createdAt).toLocaleString()}
                  </td>
                  <td>{r.restaurantName}</td>
                  <td>{r.outletName}</td>
                  <td>{r.managerPhone || "—"}</td>
                  <td className="muted" style={{ fontSize: 12 }}>{r.managerEmail || "—"}</td>
                  <td>{r.plan}</td>
                  <td>
                    <StatusBadge status={r.status} />
                  </td>
                  <td style={{ whiteSpace: "nowrap" }}>
                    <button
                      type="button"
                      className="btn"
                      style={{ fontSize: 12, padding: "6px 12px", marginRight: 8 }}
                      disabled={busyId === r.outletId}
                      onClick={() => void activate(r.outletId, r.plan)}
                    >
                      {busyId === r.outletId ? "…" : "Activate"}
                    </button>
                    <Link to={`/outlets/${r.outletId}`}>Details</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {rows.length === 0 && !error && (
          <p className="muted">No restaurants waiting for activation.</p>
        )}
      </div>
    </>
  );
}
