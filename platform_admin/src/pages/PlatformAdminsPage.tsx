import { useEffect, useState } from "react";
import { PlatformAdmin, apiFetch } from "../api/client";
import StatusBadge from "../components/StatusBadge";

export default function PlatformAdminsPage() {
  const [admins, setAdmins] = useState<PlatformAdmin[]>([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ email: "", password: "", displayName: "" });
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  function loadAdmins() {
    apiFetch<PlatformAdmin[]>("/platform/admins")
      .then(setAdmins)
      .catch((e) => setError(e.message));
  }

  useEffect(() => {
    loadAdmins();
  }, []);

  async function createAdmin() {
    if (!form.email || !form.password) {
      setFormError("Email and password are required");
      return;
    }
    setSubmitting(true);
    setFormError("");
    try {
      const created = await apiFetch<PlatformAdmin>("/platform/admins", {
        method: "POST",
        body: JSON.stringify({
          email: form.email,
          password: form.password,
          displayName: form.displayName || null,
        }),
      });
      setAdmins((prev) => [...prev, created]);
      setForm({ email: "", password: "", displayName: "" });
      setShowForm(false);
    } catch (e) {
      setFormError(e instanceof Error ? e.message : "Create failed");
    } finally {
      setSubmitting(false);
    }
  }

  async function toggleAdmin(admin: PlatformAdmin) {
    try {
      const updated = await apiFetch<PlatformAdmin>(`/platform/admins/${admin.id}`, {
        method: "PATCH",
        body: JSON.stringify({ isActive: !admin.isActive }),
      });
      setAdmins((prev) => prev.map((a) => (a.id === updated.id ? updated : a)));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Update failed");
    }
  }

  return (
    <>
      <div className="page-header">
        <h1>Platform Admins</h1>
        <button type="button" className="btn" onClick={() => setShowForm((v) => !v)}>
          {showForm ? "Cancel" : "+ Add admin"}
        </button>
      </div>

      {error && <p className="error-msg">{error}</p>}

      {showForm && (
        <div className="card" style={{ marginBottom: 20 }}>
          <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>New platform admin</h2>
          {formError && <p className="error-msg">{formError}</p>}
          <div className="three-col-grid">
            <div className="form-group">
              <label>Email *</label>
              <input
                type="email"
                value={form.email}
                onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
                style={{ width: "100%" }}
                placeholder="admin@company.com"
              />
            </div>
            <div className="form-group">
              <label>Password *</label>
              <input
                type="password"
                value={form.password}
                onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))}
                style={{ width: "100%" }}
                placeholder="Strong password"
              />
            </div>
            <div className="form-group">
              <label>Display name</label>
              <input
                type="text"
                value={form.displayName}
                onChange={(e) => setForm((f) => ({ ...f, displayName: e.target.value }))}
                style={{ width: "100%" }}
                placeholder="Jane Doe"
              />
            </div>
          </div>
          <button
            type="button"
            className="btn"
            onClick={createAdmin}
            disabled={submitting}
            style={{ marginTop: 8 }}
          >
            {submitting ? "Creating…" : "Create admin"}
          </button>
        </div>
      )}

      <div className="card">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Email</th>
                <th>Display name</th>
                <th>Role</th>
                <th>Status</th>
                <th>Created</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {admins.map((a) => (
                <tr key={a.id}>
                  <td>{a.email}</td>
                  <td>{a.displayName || <span className="muted">—</span>}</td>
                  <td>
                    <span className="badge badge-pending">{a.role}</span>
                  </td>
                  <td>
                    <StatusBadge status={a.isActive ? "active" : "suspended"} />
                  </td>
                  <td className="muted" style={{ whiteSpace: "nowrap" }}>
                    {a.createdAt ? new Date(a.createdAt).toLocaleDateString() : "—"}
                  </td>
                  <td>
                    <button
                      type="button"
                      className={`btn btn-secondary`}
                      style={{ fontSize: 12, padding: "4px 10px" }}
                      onClick={() => toggleAdmin(a)}
                    >
                      {a.isActive ? "Disable" : "Enable"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {admins.length === 0 && <p className="muted">No admins found.</p>}
      </div>
    </>
  );
}
