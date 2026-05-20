import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { clearToken } from "../api/client";

const nav = [
  { to: "/", label: "Dashboard", end: true },
  { to: "/restaurants", label: "Restaurants" },
  { to: "/subscriptions", label: "Subscriptions" },
  { to: "/payments", label: "Payments" },
];

export default function AdminLayout() {
  const navigate = useNavigate();

  function logout() {
    clearToken();
    navigate("/login");
  }

  return (
    <div className="admin-layout">
      <aside className="sidebar">
        <div className="brand">Rastarant Platform</div>
        <nav>
          {nav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => (isActive ? "active" : "")}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div style={{ padding: "20px" }}>
          <button type="button" className="btn-secondary btn" onClick={logout}>
            Log out
          </button>
        </div>
      </aside>
      <main className="main-content">
        <Outlet />
      </main>
    </div>
  );
}
