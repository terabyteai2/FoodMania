import { useEffect, useState } from "react";
import { AppUpdateConfig, SystemConfig, apiFetch, uploadAppUpdate } from "../api/client";

const emptyUpdateForm: AppUpdateConfig = {
  enabled: true,
  versionName: "",
  versionCode: 1,
  apkUrl: "",
  releaseNotes: "",
  required: true, // forced by default — published updates block until installed
  publishedAt: null,
};

export default function SystemConfigPage() {
  const [config, setConfig] = useState<SystemConfig | null>(null);
  const [form, setForm] = useState<Partial<SystemConfig>>({});
  const [appUpdate, setAppUpdate] = useState<AppUpdateConfig | null>(null);
  const [updateForm, setUpdateForm] = useState<AppUpdateConfig>(emptyUpdateForm);
  const [saving, setSaving] = useState(false);
  const [publishingUpdate, setPublishingUpdate] = useState(false);
  const [apkFile, setApkFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
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

  async function uploadAndPublish() {
    if (!apkFile) {
      setUpdateError("Choose an APK file first.");
      return;
    }
    setUploading(true);
    setUpdateError("");
    setUpdateSaved("");
    try {
      const updated = await uploadAppUpdate(apkFile, {
        versionName: updateForm.versionName || undefined,
        versionCode: updateForm.versionCode || undefined,
        releaseNotes: updateForm.releaseNotes || undefined,
        required: updateForm.required,
      });
      setAppUpdate(updated);
      setUpdateForm(updated);
      setApkFile(null);
      const detected = updated.autoDetectedVersion ? " (version read from APK)" : "";
      const reach =
        typeof updated.notifiedOutlets === "number"
          ? ` Sent to ${updated.notifiedOutlets} outlet${updated.notifiedOutlets === 1 ? "" : "s"}.`
          : "";
      setUpdateSaved(
        `Published v${updated.versionName} · code ${updated.versionCode}${detected}.${reach}`,
      );
    } catch (e) {
      setUpdateError(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setUploading(false);
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
              Upload the signed release APK — its version is read from the file —
              and every connected POS app on a lower version is prompted to update.
            </p>
          </div>
          <span className={`badge ${appUpdate?.enabled ? "badge-active" : "badge-pending"}`}>
            {appUpdate?.enabled
              ? `active · v${appUpdate.versionName} (code ${appUpdate.versionCode})`
              : "disabled"}
          </span>
        </div>

        <div className="form-group" style={{ marginTop: 18 }}>
          <label>Release APK file (app-release.apk)</label>
          <input
            type="file"
            accept=".apk,application/vnd.android.package-archive"
            onChange={(e) => setApkFile(e.target.files?.[0] ?? null)}
          />
          <span className="muted" style={{ fontSize: 12 }}>
            {apkFile
              ? `Selected: ${apkFile.name} (${(apkFile.size / (1024 * 1024)).toFixed(1)} MB)`
              : "Version name & code are auto-read from the APK; it is stored on the server and served to the apps."}
          </span>
        </div>

        <div className="form-group">
          <label>Update message (release notes)</label>
          <textarea
            rows={4}
            value={updateForm.releaseNotes || ""}
            onChange={(e) => setUpdateForm((f) => ({ ...f, releaseNotes: e.target.value }))}
            placeholder="What changed in this update? (shown in the app)"
          />
        </div>

        <label className="toggle-row" style={{ marginTop: 8 }}>
          <span>Required update (forces install)</span>
          <div
            className={`toggle-switch ${updateForm.required ? "on" : ""}`}
            onClick={() => setUpdateForm((f) => ({ ...f, required: !f.required }))}
          />
        </label>

        <details style={{ marginTop: 12 }}>
          <summary className="muted" style={{ fontSize: 12, cursor: "pointer" }}>
            Advanced — manual version override / publish by URL
          </summary>
          <div className="two-col-grid" style={{ marginTop: 12 }}>
            <div className="form-group">
              <label>Version name (auto · override)</label>
              <input
                type="text"
                value={updateForm.versionName}
                onChange={(e) => setUpdateForm((f) => ({ ...f, versionName: e.target.value }))}
                placeholder="auto-detected"
              />
            </div>
            <div className="form-group">
              <label>Version code (auto · override)</label>
              <input
                type="number"
                min={1}
                step={1}
                value={updateForm.versionCode || 1}
                onChange={(e) => setUpdateForm((f) => ({ ...f, versionCode: Number(e.target.value) }))}
                placeholder="auto-detected"
              />
            </div>
          </div>
          <div className="form-group">
            <label>APK download URL</label>
            <input
              type="url"
              value={updateForm.apkUrl}
              onChange={(e) => setUpdateForm((f) => ({ ...f, apkUrl: e.target.value }))}
              placeholder="https://your-domain.com/app-release.apk"
            />
            <span className="muted" style={{ fontSize: 12 }}>
              Auto-filled after an upload. Or paste a hosted URL and use “Publish by URL”
              (needs version name + code above).
            </span>
          </div>
        </details>

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
            onClick={uploadAndPublish}
            disabled={uploading || publishingUpdate || !apkFile}
          >
            {uploading ? "Uploading…" : "Upload & Publish"}
          </button>
          <button
            type="button"
            className="btn-secondary"
            onClick={publishUpdate}
            disabled={publishingUpdate || uploading || !updateForm.apkUrl}
          >
            {publishingUpdate ? "Publishing…" : "Publish by URL"}
          </button>
          <button
            type="button"
            className="btn-secondary"
            onClick={disableUpdate}
            disabled={publishingUpdate || uploading || !appUpdate?.enabled}
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
