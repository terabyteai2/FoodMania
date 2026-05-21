import { useEffect, useState } from "react";
import { SystemConfig, apiFetch } from "../api/client";

export default function SystemConfigPage() {
  const [config, setConfig] = useState<SystemConfig | null>(null);
  const [form, setForm] = useState<Partial<SystemConfig>>({});
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    apiFetch<SystemConfig>("/platform/system/config")
      .then((c) => {
        setConfig(c);
        setForm({
          baseUrl: c.baseUrl,
          bkashEnabled: c.bkashEnabled,
          maintenanceMode: c.maintenanceMode,
          supportEmail: c.supportEmail,
        });
      })
      .catch((e) => setError(e.message));
  }, []);

  async function save() {
    setSaving(true);
    setError("");
    try {
      const updated = await apiFetch<SystemConfig>("/platform/system/config", {
        method: "PATCH",
        body: JSON.stringify({
          baseUrl: form.baseUrl,
          bkashEnabled: form.bkashEnabled,
          maintenanceMode: form.maintenanceMode,
          supportEmail: form.supportEmail,
        }),
      });
      setConfig(updated);
      setForm({
        baseUrl: updated.baseUrl,
        bkashEnabled: updated.bkashEnabled,
        maintenanceMode: updated.maintenanceMode,
        supportEmail: updated.supportEmail,
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Save failed");
    } finally {
      setSaving(false);
    }
  }

  if (!config) return <p className="muted">{error || "Loading…"}</p>;

  return (
    <>
      <div className="page-header">
        <h1>System Config</h1>
        <span className="muted" style={{ fontSize: 13 }}>Platform-wide settings</span>
      </div>

      {error && <p className="error-msg">{error}</p>}
      {saved && <p style={{ color: "var(--success)", fontSize: 13 }}>Settings saved successfully.</p>}

      <div className="two-col-grid" style={{ gap: 20, marginBottom: 20 }}>
        {/* Read-only env vars */}
        <div className="card">
          <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Environment (read-only)</h2>
          <div className="detail-grid">
            <div className="detail-row">
              <span className="label">UddoktaPay</span>
              <span style={{ color: config.uddoktaPayEnabled ? "var(--success)" : "var(--danger)" }}>
                {config.uddoktaPayEnabled ? "✔ Configured" : "✘ Not configured"}
              </span>
            </div>
            <div className="detail-row">
              <span className="label">Sandbox mode</span>
              <span>{config.uddoktaPaySandbox ? "Yes (sandbox)" : "No (live)"}</span>
            </div>
          </div>
        </div>

        {/* Toggles */}
        <div className="card">
          <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Feature flags</h2>
          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <label className="toggle-row">
              <span>bKash payments</span>
              <div
                className={`toggle-switch ${form.bkashEnabled ? "on" : ""}`}
                onClick={() => setForm((f) => ({ ...f, bkashEnabled: !f.bkashEnabled }))}
              />
            </label>
            <label className="toggle-row">
              <span>
                Maintenance mode
                {form.maintenanceMode && (
                  <span className="badge badge-suspended" style={{ marginLeft: 8 }}>ACTIVE</span>
                )}
              </span>
              <div
                className={`toggle-switch ${form.maintenanceMode ? "on" : ""}`}
                onClick={() => setForm((f) => ({ ...f, maintenanceMode: !f.maintenanceMode }))}
              />
            </label>
          </div>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 20 }}>
        <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Connection settings</h2>
        <div className="two-col-grid">
          <div className="form-group">
            <label>Base URL (API server)</label>
            <input
              type="url"
              value={form.baseUrl || ""}
              onChange={(e) => setForm((f) => ({ ...f, baseUrl: e.target.value }))}
              style={{ width: "100%" }}
              placeholder="http://160.187.130.80"
            />
            <span className="muted" style={{ fontSize: 12 }}>
              Used for customer menu links and QR codes.
            </span>
          </div>
          <div className="form-group">
            <label>Support email</label>
            <input
              type="email"
              value={form.supportEmail || ""}
              onChange={(e) => setForm((f) => ({ ...f, supportEmail: e.target.value }))}
              style={{ width: "100%" }}
              placeholder="support@yourdomain.com"
            />
          </div>
        </div>
      </div>

      <button
        type="button"
        className="btn"
        onClick={save}
        disabled={saving}
        style={{ minWidth: 140 }}
      >
        {saving ? "Saving…" : "Save changes"}
      </button>
    </>
  );
}
