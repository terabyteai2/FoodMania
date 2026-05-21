import { useEffect, useState } from "react";
import { PlatformHealth, apiFetch } from "../api/client";

function HealthCard({
  label,
  value,
  ok,
  sub,
}: {
  label: string;
  value: string;
  ok?: boolean;
  sub?: string;
}) {
  return (
    <div className="health-card">
      <div className="health-label">{label}</div>
      <div
        className="health-value"
        style={{
          color:
            ok === undefined
              ? "var(--text)"
              : ok
              ? "var(--success)"
              : "var(--danger)",
        }}
      >
        {value}
      </div>
      {sub && <div className="health-sub">{sub}</div>}
    </div>
  );
}

export default function SystemHealthPage() {
  const [health, setHealth] = useState<PlatformHealth | null>(null);
  const [error, setError] = useState("");
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null);

  function load() {
    apiFetch<PlatformHealth>("/platform/health")
      .then((h) => {
        setHealth(h);
        setLastRefresh(new Date());
        setError("");
      })
      .catch((e) => setError(e.message));
  }

  useEffect(() => {
    load();
    const id = setInterval(load, 30_000);
    return () => clearInterval(id);
  }, []);

  return (
    <>
      <div className="page-header">
        <h1>System Health</h1>
        <div style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" }}>
          {lastRefresh && (
            <span className="muted" style={{ fontSize: 12 }}>
              Last checked: {lastRefresh.toLocaleTimeString()}
            </span>
          )}
          <button type="button" className="btn-secondary btn" onClick={load}>
            Refresh
          </button>
        </div>
      </div>

      {error && <p className="error-msg">{error}</p>}

      {!health && !error && <p className="muted">Checking health…</p>}

      {health && (
        <>
          <div className="health-grid">
            <HealthCard
              label="API Server"
              value={health.api === "ok" ? "Operational" : "Degraded"}
              ok={health.api === "ok"}
            />
            <HealthCard
              label="Database"
              value={health.database === "ok" ? "Connected" : "Error"}
              ok={health.database === "ok"}
            />
            <HealthCard
              label="Storage"
              value={health.storageMode === "r2" ? "Cloudflare R2" : "Local disk"}
              ok
            />
            <HealthCard
              label="Payment Gateway"
              value={health.uddoktaPayConfigured ? "Configured" : "Not configured"}
              ok={health.uddoktaPayConfigured}
            />
          </div>

          <div className="two-col-grid" style={{ gap: 20, marginTop: 20 }}>
            <div className="card">
              <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Live Metrics</h2>
              <div className="detail-grid">
                <div className="detail-row">
                  <span className="label">Restaurants</span>
                  <span>{health.restaurants}</span>
                </div>
                <div className="detail-row">
                  <span className="label">Outlets</span>
                  <span>{health.outlets}</span>
                </div>
                <div className="detail-row">
                  <span className="label">Orders (24h)</span>
                  <span>{health.ordersLast24h}</span>
                </div>
              </div>
            </div>
            <div className="card">
              <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Connection</h2>
              <div className="detail-grid">
                <div className="detail-row">
                  <span className="label">API Base URL</span>
                  <code style={{ fontSize: 12, wordBreak: "break-all" }}>{health.baseUrl}</code>
                </div>
                <div className="detail-row">
                  <span className="label">Last checked</span>
                  <span className="muted">
                    {new Date(health.checkedAt).toLocaleTimeString()}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <p className="muted" style={{ marginTop: 16, fontSize: 12 }}>
            Auto-refreshes every 30 seconds
          </p>
        </>
      )}
    </>
  );
}
