import { useEffect, useState } from "react";
import { AppUpdateConfig, SystemConfig, apiFetch } from "../api/client";

const emptyUpdateForm: AppUpdateConfig = {
  enabled: true,
  versionName: "",
  versionCode: 1,
  apkUrl: "",
  releaseNotes: "",
  required: false,
  publishedAt: null,
};

export default function SystemConfigPage() {
  const [config, setConfig] = useState<SystemConfig | null>(null);
  const [form, setForm] = useState<Partial<SystemConfig>>({});
  const [appUpdate, setAppUpdate] = useState<AppUpdateConfig | null>(null);
  const [updateForm, setUpdateForm] = useState<AppUpdateConfig>(emptyUpdateForm);
  const [saving, setSaving] = useState(false);
  const [publishingUpdate, setPublishingUpdate] = useState(false);
  const [saved, setSaved] = useState(false);
  const [updateSaved, setUpdateSaved] = useState("");
  const [error, setError] = useState("");
  const [updateError, setUpdateError] = useState("");

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
    apiFetch<AppUpdateConfig>("/platform/app-update")
      .then((u) => {
        setAppUpdate(u);
        setUpdateForm(u.enabled ? u : emptyUpdateForm);
      })
      .catch((e) => setUpdateError(e.message));
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

  async function publishUpdate() {
    setPublishingUpdate(true);
    setUpdateError("");
    setUpdateSaved("");
    try {
      const updated = await apiFetch<AppUpdateConfig>("/platform/app-update", {
        method: "POST",
        body: JSON.stringify({
          enabled: true,
          versionName: updateForm.versionName,
          versionCode: Number(updateForm.versionCode),
          apkUrl: updateForm.apkUrl,
          releaseNotes: updateForm.releaseNotes,
          required: updateForm.required,
        }),
      });
      setAppUpdate(updated);
      setUpdateForm(updated);
      setUpdateSaved(
        `Update published${typeof updated.notifiedOutlets === "number" ? ` to ${updated.notifiedOutlets} outlet${updated.notifiedOutlets === 1 ? "" : "s"}` : ""}.`,
      );
    } catch (e) {
      setUpdateError(e instanceof Error ? e.message : "Update publish failed");
    } finally {
      setPublishingUpdate(false);
    }
  }

  async function disableUpdate() {
    setPublishingUpdate(true);
    setUpdateError("");
    setUpdateSaved("");
    try {
      const updated = await apiFetch<AppUpdateConfig>("/platform/app-update", {
        method: "DELETE",
      });
      setAppUpdate(updated);
      setUpdateForm(emptyUpdateForm);
      setUpdateSaved("App update prompt disabled.");
    } catch (e) {
      setUpdateError(e instanceof Error ? e.message : "Disable failed");
    } finally {
      setPublishingUpdate(false);
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
              placeholder="https://quickbytes.buzz"
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

      <div className="card" style={{ marginBottom: 20 }}>
        <div style={{ display: "flex", justifyContent: "space-between", gap: 16, alignItems: "flex-start" }}>
          <div>
            <h2 style={{ margin: "0 0 6px", fontSize: 15 }}>Admin app APK update</h2>
            <p className="muted" style={{ margin: 0, fontSize: 13 }}>
              Publish a signed APK URL and all connected POS apps will prompt users to update.
            </p>
          </div>
          <span className={`badge ${appUpdate?.enabled ? "badge-active" : "badge-pending"}`}>
            {appUpdate?.enabled ? "active" : "disabled"}
          </span>
        </div>

        <div className="two-col-grid" style={{ marginTop: 18 }}>
          <div className="form-group">
            <label>Version name</label>
            <input
              type="text"
              value={updateForm.versionName}
              onChange={(e) => setUpdateForm((f) => ({ ...f, versionName: e.target.value }))}
              placeholder="1.3.2"
            />
          </div>
          <div className="form-group">
            <label>Version code</label>
            <input
              type="number"
              min={1}
              step={1}
              value={updateForm.versionCode || 1}
              onChange={(e) => setUpdateForm((f) => ({ ...f, versionCode: Number(e.target.value) }))}
              placeholder="3"
            />
          </div>
        </div>

        <div className="form-group">
          <label>APK download URL</label>
          <input
            type="url"
            value={updateForm.apkUrl}
            onChange={(e) => setUpdateForm((f) => ({ ...f, apkUrl: e.target.value }))}
            placeholder="https://your-domain.com/downloads/quickbites-admin-1.3.2.apk"
          />
          <span className="muted" style={{ fontSize: 12 }}>
            Use the final signed release APK. Android will still show the system installer confirmation.
          </span>
        </div>

        <div className="form-group">
          <label>Release notes</label>
          <textarea
            rows={4}
            value={updateForm.releaseNotes || ""}
            onChange={(e) => setUpdateForm((f) => ({ ...f, releaseNotes: e.target.value }))}
            placeholder="What changed in this update?"
          />
        </div>

        <label className="toggle-row" style={{ marginTop: 8 }}>
          <span>Required update</span>
          <div
            className={`toggle-switch ${updateForm.required ? "on" : ""}`}
            onClick={() => setUpdateForm((f) => ({ ...f, required: !f.required }))}
          />
        </label>

        {appUpdate?.publishedAt && (
          <p className="muted" style={{ fontSize: 12 }}>
            Last published {new Date(appUpdate.publishedAt).toLocaleString()}
          </p>
        )}
        {updateError && <p className="error-msg">{updateError}</p>}
        {updateSaved && <p style={{ color: "var(--success)", fontSize: 13 }}>{updateSaved}</p>}

        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", marginTop: 16 }}>
          <button
            type="button"
            className="btn"
            onClick={publishUpdate}
            disabled={publishingUpdate}
          >
            {publishingUpdate ? "Publishing…" : "Publish update call"}
          </button>
          <button
            type="button"
            className="btn-secondary"
            onClick={disableUpdate}
            disabled={publishingUpdate || !appUpdate?.enabled}
          >
            Disable prompt
          </button>
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
