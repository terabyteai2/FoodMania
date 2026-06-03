import { useEffect, useRef, useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { Alert, apiFetch, clearToken } from "../api/client";

const nav = [
  { to: "/", label: "Dashboard", end: true, icon: "⊞" },
  { to: "/restaurants", label: "Restaurants", icon: "🏪" },
  { to: "/subscriptions", label: "Subscriptions", icon: "📋" },
  { to: "/activations", label: "Activations", icon: "✓" },
  { to: "/analytics", label: "Analytics", icon: "📊" },
  { to: "/health", label: "System Health", icon: "❤" },
  { to: "/config", label: "System Config", icon: "⚙" },
  { to: "/admins", label: "Admins", icon: "👤" },
];

const SEV_COLOR: Record<string, string> = {
  critical: "var(--danger)",
  warning: "var(--warning)",
  success: "var(--success)",
  info: "var(--accent)",
};

export default function AdminLayout() {
  const navigate = useNavigate();
  const location = useLocation();

  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [alertsOpen, setAlertsOpen] = useState(false);
  const [seenCount, setSeenCount] = useState(0);
  const [dropdownPos, setDropdownPos] = useState({ top: 0, left: 0 });

  const bellRef = useRef<HTMLButtonElement>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close sidebar on navigation (mobile)
  useEffect(() => {
    setSidebarOpen(false);
  }, [location.pathname]);

  // Poll alerts every 60s
  useEffect(() => {
    function load() {
      apiFetch<Alert[]>("/platform/alerts")
        .then(setAlerts)
        .catch(() => {});
    }
    load();
    const id = setInterval(load, 60_000);
    return () => clearInterval(id);
  }, []);

  // Close alerts dropdown on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(e.target as Node) &&
        bellRef.current &&
        !bellRef.current.contains(e.target as Node)
      ) {
        setAlertsOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  const unseenCount = Math.max(0, alerts.length - seenCount);

  function openAlerts() {
    if (!alertsOpen && bellRef.current) {
      const rect = bellRef.current.getBoundingClientRect();
      setDropdownPos({
        top: rect.bottom + 8,
        left: rect.left - 280 + rect.width, // align right edge of dropdown to bell
      });
    }
    setAlertsOpen((o) => !o);
    setSeenCount(alerts.length);
  }

  function logout() {
    clearToken();
    navigate("/login");
  }

  return (
    <div className="admin-layout">

      {/* ── Mobile top bar ───────────────────────────────────── */}
      <div className="mobile-topbar">
        <button
          type="button"
          className="hamburger-btn"
          onClick={() => setSidebarOpen((v) => !v)}
          aria-label="Toggle menu"
        >
          {sidebarOpen ? "✕" : "☰"}
        </button>
        <span className="mobile-brand">Rastarant Platform</span>
        <button
          ref={bellRef}
          type="button"
          className="alert-bell-btn"
          onClick={openAlerts}
          title="Alerts"
        >
          🔔
          {unseenCount > 0 && (
            <span className="alert-badge">{unseenCount > 9 ? "9+" : unseenCount}</span>
          )}
        </button>
      </div>

      {/* ── Sidebar overlay (mobile) ────────────────────────── */}
      {sidebarOpen && (
        <div
          className="sidebar-overlay"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* ── Sidebar ─────────────────────────────────────────── */}
      <aside className={`sidebar${sidebarOpen ? " sidebar-open" : ""}`}>
        <div className="brand">
          <span className="brand-text">Rastarant Platform</span>
          <button
            ref={bellRef}
            type="button"
            className="alert-bell-btn"
            onClick={openAlerts}
            title="Alerts"
          >
            🔔
            {unseenCount > 0 && (
              <span className="alert-badge">{unseenCount > 9 ? "9+" : unseenCount}</span>
            )}
          </button>
        </div>

        <nav>
          {nav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => (isActive ? "active" : "")}
            >
              <span className="nav-icon">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-footer">
          <button
            type="button"
            className="btn-secondary btn"
            onClick={logout}
            style={{ width: "100%" }}
          >
            Log out
          </button>
        </div>
      </aside>

      {/* ── Main content ────────────────────────────────────── */}
      <main className="main-content">
        <Outlet />
      </main>

      {/* ── Alerts dropdown — fixed portal, escapes sidebar ── */}
      {alertsOpen && (
        <div
          ref={dropdownRef}
          className="alerts-dropdown"
          style={{ top: dropdownPos.top, left: Math.max(8, dropdownPos.left) }}
        >
          <div className="alerts-header">
            <strong>Alerts</strong>
            <span className="muted" style={{ fontSize: 12 }}>
              {alerts.length} total
            </span>
          </div>
          {alerts.length === 0 ? (
            <p className="muted" style={{ padding: "12px 16px", margin: 0 }}>
              No alerts right now
            </p>
          ) : (
            <div className="alerts-list">
              {alerts.map((a, i) => (
                <div key={i} className="alert-item">
                  <div
                    className="alert-dot"
                    style={{ background: SEV_COLOR[a.severity] || "var(--muted)" }}
                  />
                  <div style={{ minWidth: 0 }}>
                    <div className="alert-title">{a.title}</div>
                    <div className="alert-msg">{a.message}</div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
