import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { apiFetch, Outlet, Restaurant } from "../api/client";
import StatusBadge from "../components/StatusBadge";

type NewOutletForm = {
  restaurantId: string;
  restaurantName: string;
  outletName: string;
  serverId: string;
};

type ActivateModal = {
  outletId: string;
  outletName: string;
  currentPlan?: string;
};

export default function RestaurantsPage() {
  const [restaurants, setRestaurants] = useState<Restaurant[]>([]);
  const [q, setQ] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [error, setError] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<NewOutletForm>({
    restaurantId: "",
    restaurantName: "",
    outletName: "",
    serverId: "",
  });
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  // Inline quick-action state
  const [patchingId, setPatchingId] = useState<string | null>(null);
  const [activateModal, setActivateModal] = useState<ActivateModal | null>(null);
  const [activatePlan, setActivatePlan] = useState("monthly");
  const [activateExpiry, setActivateExpiry] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() + 30);
    return d.toISOString().slice(0, 10);
  });
  const [activating, setActivating] = useState(false);
  const [activateError, setActivateError] = useState("");

  function load(search: string) {
    const params = search ? `?q=${encodeURIComponent(search)}` : "";
    apiFetch<Restaurant[]>(`/platform/restaurants${params}`)
      .then(setRestaurants)
      .catch((e) => setError(e.message));
  }

  useEffect(() => {
    load(q);
  }, [q]);

  async function createOutlet() {
    if (!form.restaurantName || !form.outletName || !form.serverId) {
      setFormError("Restaurant name, outlet name and server ID are required");
      return;
    }
    setSubmitting(true);
    setFormError("");
    try {
      await apiFetch<Outlet>("/platform/outlets", {
        method: "POST",
        body: JSON.stringify({
          restaurantId: form.restaurantId || null,
          restaurantName: form.restaurantName,
          outletName: form.outletName,
          serverId: form.serverId,
        }),
      });
      setShowModal(false);
      setForm({ restaurantId: "", restaurantName: "", outletName: "", serverId: "" });
      load(q);
    } catch (e) {
      setFormError(e instanceof Error ? e.message : "Create failed");
    } finally {
      setSubmitting(false);
    }
  }

  async function patchOutletStatus(outletId: string, newStatus: "active" | "suspended") {
    setPatchingId(outletId);
    try {
      await apiFetch(`/platform/outlets/${outletId}`, {
        method: "PATCH",
        body: JSON.stringify({ status: newStatus }),
      });
      load(q);
    } catch (e) {
      alert(e instanceof Error ? e.message : "Update failed");
    } finally {
      setPatchingId(null);
    }
  }

  function openActivateModal(o: Outlet) {
    setActivateModal({ outletId: o.id, outletName: o.name, currentPlan: undefined });
    setActivatePlan("monthly");
    const d = new Date();
    d.setDate(d.getDate() + 30);
    setActivateExpiry(d.toISOString().slice(0, 10));
    setActivateError("");
  }

  async function submitActivation() {
    if (!activateModal) return;
    setActivating(true);
    setActivateError("");
    try {
      await apiFetch(`/platform/outlets/${activateModal.outletId}/subscription`, {
        method: "POST",
        body: JSON.stringify({
          plan: activatePlan,
          status: "active",
          expiresAt: new Date(activateExpiry).toISOString(),
        }),
      });
      setActivateModal(null);
      load(q);
    } catch (e) {
      setActivateError(e instanceof Error ? e.message : "Activation failed");
    } finally {
      setActivating(false);
    }
  }

  const filtered = restaurants.map((r) => ({
    ...r,
    outlets:
      statusFilter === "all"
        ? r.outlets
        : r.outlets.filter((o) => o.status === statusFilter),
  })).filter((r) => statusFilter === "all" || r.outlets.length > 0);

  return (
    <>
      <div className="page-header">
        <h1>Restaurants &amp; outlets</h1>
        <button type="button" className="btn" onClick={() => setShowModal(true)}>
          + New outlet
        </button>
      </div>

      <div className="toolbar-row">
        <div className="search-bar" style={{ marginBottom: 0, flex: 1, minWidth: 200 }}>
          <input
            type="search"
            placeholder="Search restaurants or outlets…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            style={{ width: "100%", maxWidth: "none" }}
          />
        </div>
        <div className="filter-group">
          {["all", "active", "suspended", "pending"].map((s) => (
            <button
              key={s}
              type="button"
              className={`btn btn-secondary ${statusFilter === s ? "filter-active" : ""}`}
              style={{ fontSize: 13, padding: "6px 14px" }}
              onClick={() => setStatusFilter(s)}
            >
              {s.charAt(0).toUpperCase() + s.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {/* New outlet modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <h2 style={{ margin: "0 0 16px", fontSize: 16 }}>Register new outlet</h2>
            {formError && <p className="error-msg">{formError}</p>}

            <div className="form-group">
              <label>Restaurant name *</label>
              <input
                type="text"
                value={form.restaurantName}
                onChange={(e) => setForm((f) => ({ ...f, restaurantName: e.target.value }))}
                style={{ width: "100%" }}
                placeholder="e.g. Terafoods"
              />
            </div>
            <div className="form-group">
              <label>Add to existing restaurant (ID, optional)</label>
              <select
                value={form.restaurantId}
                onChange={(e) =>
                  setForm((f) => {
                    const r = restaurants.find((r) => r.id === e.target.value);
                    return {
                      ...f,
                      restaurantId: e.target.value,
                      restaurantName: r ? r.name : f.restaurantName,
                    };
                  })
                }
                style={{ width: "100%" }}
              >
                <option value="">— Create new restaurant —</option>
                {restaurants.map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label>Outlet name *</label>
              <input
                type="text"
                value={form.outletName}
                onChange={(e) => setForm((f) => ({ ...f, outletName: e.target.value }))}
                style={{ width: "100%" }}
                placeholder="e.g. Gulshan Branch"
              />
            </div>
            <div className="form-group">
              <label>Server ID *</label>
              <input
                type="text"
                value={form.serverId}
                onChange={(e) => setForm((f) => ({ ...f, serverId: e.target.value }))}
                style={{ width: "100%" }}
                placeholder="Unique device/server identifier"
              />
            </div>
            <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
              <button type="button" className="btn" onClick={createOutlet} disabled={submitting}>
                {submitting ? "Creating…" : "Create outlet"}
              </button>
              <button
                type="button"
                className="btn-secondary btn"
                onClick={() => setShowModal(false)}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Activate with custom expiry modal */}
      {activateModal && (
        <div className="modal-overlay" onClick={() => setActivateModal(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <h2 style={{ margin: "0 0 4px", fontSize: 16 }}>Activate — {activateModal.outletName}</h2>
            <p className="muted" style={{ margin: "0 0 16px", fontSize: 13 }}>
              Set the subscription plan and expiry date.
            </p>
            {activateError && <p className="error-msg">{activateError}</p>}

            <div className="form-group">
              <label>Plan</label>
              <select
                value={activatePlan}
                onChange={(e) => {
                  setActivatePlan(e.target.value);
                  const days = e.target.value === "annual" ? 365 : 30;
                  const d = new Date();
                  d.setDate(d.getDate() + days);
                  setActivateExpiry(d.toISOString().slice(0, 10));
                }}
                style={{ width: "100%" }}
              >
                <option value="monthly">Monthly (30 days)</option>
                <option value="annual">Annual (365 days)</option>
              </select>
            </div>
            <div className="form-group">
              <label>Expires on *</label>
              <input
                type="date"
                value={activateExpiry}
                min={new Date().toISOString().slice(0, 10)}
                onChange={(e) => setActivateExpiry(e.target.value)}
                style={{ width: "100%" }}
              />
            </div>
            <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
              <button
                type="button"
                className="btn"
                onClick={submitActivation}
                disabled={activating || !activateExpiry}
              >
                {activating ? "Activating…" : "Activate"}
              </button>
              <button
                type="button"
                className="btn-secondary btn"
                onClick={() => setActivateModal(null)}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {error && <p className="error-msg">{error}</p>}

      {filtered.map((r) => (
        <div key={r.id} className="card" style={{ marginBottom: 16 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12, gap: 8, flexWrap: "wrap" }}>
            <div style={{ minWidth: 0 }}>
              <h2 style={{ margin: 0, fontSize: 18, wordBreak: "break-word" }}>{r.name}</h2>
              <p className="muted" style={{ margin: "4px 0 0", fontSize: 13 }}>
                Created {new Date(r.createdAt).toLocaleDateString()} ·{" "}
                {r.outlets.length} outlet{r.outlets.length !== 1 ? "s" : ""}
              </p>
            </div>
            <button
              type="button"
              className="btn-secondary btn"
              style={{ fontSize: 12 }}
              onClick={() => {
                setForm((f) => ({ ...f, restaurantId: r.id, restaurantName: r.name }));
                setShowModal(true);
              }}
            >
              + Add outlet
            </button>
          </div>
          {r.outlets.length > 0 ? (
            <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Outlet</th>
                  <th>Server ID</th>
                  <th>Status</th>
                  <th style={{ minWidth: 260 }}>Quick actions</th>
                </tr>
              </thead>
              <tbody>
                {r.outlets.map((o) => {
                  const busy = patchingId === o.id;
                  return (
                    <tr key={o.id}>
                      <td>{o.name}</td>
                      <td>
                        <code style={{ fontSize: 12 }}>{o.serverId}</code>
                      </td>
                      <td>
                        <StatusBadge status={o.status} />
                      </td>
                      <td>
                        <div style={{ display: "flex", gap: 6, flexWrap: "wrap", alignItems: "center" }}>
                          {o.status !== "active" && (
                            <button
                              type="button"
                              className="btn"
                              style={{ fontSize: 12, padding: "4px 10px", background: "var(--color-success, #16a34a)", borderColor: "var(--color-success, #16a34a)" }}
                              disabled={busy}
                              onClick={() => openActivateModal(o)}
                            >
                              {busy ? "…" : "Activate"}
                            </button>
                          )}
                          {o.status === "active" && (
                            <button
                              type="button"
                              className="btn btn-secondary"
                              style={{ fontSize: 12, padding: "4px 10px", color: "var(--color-danger, #dc2626)", borderColor: "var(--color-danger, #dc2626)" }}
                              disabled={busy}
                              onClick={() => patchOutletStatus(o.id, "suspended")}
                            >
                              {busy ? "…" : "Suspend"}
                            </button>
                          )}
                          {o.status === "suspended" && (
                            <button
                              type="button"
                              className="btn btn-secondary"
                              style={{ fontSize: 12, padding: "4px 10px" }}
                              disabled={busy}
                              onClick={() => patchOutletStatus(o.id, "active")}
                            >
                              {busy ? "…" : "Unsuspend"}
                            </button>
                          )}
                          <Link
                            to={`/outlets/${o.id}`}
                            style={{ fontSize: 12, color: "var(--color-muted)" }}
                          >
                            Details
                          </Link>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            </div>
          ) : (
            <p className="muted">No outlets{statusFilter !== "all" ? ` with status "${statusFilter}"` : ""}</p>
          )}
        </div>
      ))}

      {!error && filtered.length === 0 && <p className="muted">No restaurants found.</p>}
    </>
  );
}
