import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { apiFetch, Restaurant } from "../api/client";
import StatusBadge from "../components/StatusBadge";

export default function RestaurantsPage() {
  const [restaurants, setRestaurants] = useState<Restaurant[]>([]);
  const [q, setQ] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    const params = q ? `?q=${encodeURIComponent(q)}` : "";
    apiFetch<Restaurant[]>(`/platform/restaurants${params}`)
      .then(setRestaurants)
      .catch((e) => setError(e.message));
  }, [q]);

  return (
    <>
      <div className="page-header">
        <h1>Restaurants & outlets</h1>
      </div>

      <div className="search-bar">
        <input
          type="search"
          placeholder="Search restaurants or outlets…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
      </div>

      {error && <p className="error-msg">{error}</p>}

      {restaurants.map((r) => (
        <div key={r.id} className="card" style={{ marginBottom: 16 }}>
          <h2 style={{ margin: "0 0 12px", fontSize: 18 }}>{r.name}</h2>
          <p className="muted" style={{ margin: "0 0 12px" }}>
            Created {new Date(r.createdAt).toLocaleDateString()} · {r.outlets.length} outlet
            {r.outlets.length !== 1 ? "s" : ""}
          </p>
          {r.outlets.length > 0 ? (
            <table>
              <thead>
                <tr>
                  <th>Outlet</th>
                  <th>Server ID</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {r.outlets.map((o) => (
                  <tr key={o.id}>
                    <td>{o.name}</td>
                    <td>
                      <code style={{ fontSize: 12 }}>{o.serverId}</code>
                    </td>
                    <td>
                      <StatusBadge status={o.status} />
                    </td>
                    <td>
                      <Link to={`/outlets/${o.id}`}>Manage</Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="muted">No outlets</p>
          )}
        </div>
      ))}

      {!error && restaurants.length === 0 && <p className="muted">No restaurants found.</p>}
    </>
  );
}
