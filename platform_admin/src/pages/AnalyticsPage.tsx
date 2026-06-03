import { useEffect, useRef, useState } from "react";
import { Analytics, apiFetch } from "../api/client";
import {
  BarController,
  BarElement,
  CategoryScale,
  Chart,
  Filler,
  Legend,
  LinearScale,
  LineController,
  LineElement,
  PointElement,
  Tooltip,
} from "chart.js";

// Controllers must be registered separately from their elements
Chart.register(
  CategoryScale,
  LinearScale,
  BarController,
  BarElement,
  LineController,
  LineElement,
  PointElement,
  Tooltip,
  Legend,
  Filler,
);

function destroyCanvas(canvas: HTMLCanvasElement, ref: React.MutableRefObject<Chart | null>) {
  // Destroy the tracked ref
  ref.current?.destroy();
  ref.current = null;
  // Also destroy any orphaned chart on the same canvas (React Strict Mode double-invoke)
  const orphan = Chart.getChart(canvas);
  if (orphan) orphan.destroy();
}

function BarChart({ data }: { data: { label: string; value: number }[] }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const chartRef = useRef<Chart | null>(null);

  useEffect(() => {
    if (!canvasRef.current) return;
    destroyCanvas(canvasRef.current, chartRef);
    chartRef.current = new Chart(canvasRef.current, {
      type: "bar",
      data: {
        labels: data.map((d) => d.label),
        datasets: [
          {
            label: "Revenue (BDT)",
            data: data.map((d) => d.value),
            backgroundColor: "rgba(59,130,246,0.7)",
            borderColor: "rgba(59,130,246,1)",
            borderWidth: 1,
            borderRadius: 4,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { labels: { color: "#e8edf4" } } },
        scales: {
          x: { ticks: { color: "#8b9cb3" }, grid: { color: "#2d3a4f" } },
          y: { ticks: { color: "#8b9cb3" }, grid: { color: "#2d3a4f" } },
        },
      },
    });
    return () => {
      chartRef.current?.destroy();
      chartRef.current = null;
    };
  }, [data]);

  return <canvas ref={canvasRef} style={{ width: "100%", height: 220 }} />;
}

function OutletGrowthChart({ data }: { data: { label: string; value: number }[] }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const chartRef = useRef<Chart | null>(null);

  useEffect(() => {
    if (!canvasRef.current) return;
    destroyCanvas(canvasRef.current, chartRef);
    chartRef.current = new Chart(canvasRef.current, {
      type: "line",
      data: {
        labels: data.map((d) => d.label),
        datasets: [
          {
            label: "New Outlets",
            data: data.map((d) => d.value),
            borderColor: "rgba(34,197,94,1)",
            backgroundColor: "rgba(34,197,94,0.15)",
            fill: true,
            tension: 0.4,
            pointBackgroundColor: "rgba(34,197,94,1)",
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { labels: { color: "#e8edf4" } } },
        scales: {
          x: { ticks: { color: "#8b9cb3" }, grid: { color: "#2d3a4f" } },
          y: { ticks: { color: "#8b9cb3" }, grid: { color: "#2d3a4f" }, beginAtZero: true },
        },
      },
    });
    return () => {
      chartRef.current?.destroy();
      chartRef.current = null;
    };
  }, [data]);

  return <canvas ref={canvasRef} style={{ width: "100%", height: 220 }} />;
}

function SubBreakdownBars({ breakdown }: { breakdown: Record<string, number> }) {
  const order = ["active", "trial", "expired", "cancelled"];
  const colors: Record<string, string> = {
    active: "var(--success)",
    trial: "var(--warning)",
    expired: "var(--danger)",
    cancelled: "var(--muted)",
  };
  const total = Object.values(breakdown).reduce((s, v) => s + v, 0) || 1;

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      {order.map((key) => {
        const val = breakdown[key] || 0;
        const pct = Math.round((val / total) * 100);
        return (
          <div key={key}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4, fontSize: 13 }}>
              <span style={{ textTransform: "capitalize", color: colors[key] }}>{key}</span>
              <span className="muted">{val} ({pct}%)</span>
            </div>
            <div style={{ background: "var(--surface2)", borderRadius: 4, height: 8, overflow: "hidden" }}>
              <div
                style={{
                  width: `${pct}%`,
                  height: "100%",
                  background: colors[key],
                  borderRadius: 4,
                  transition: "width 0.6s ease",
                }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}

export default function AnalyticsPage() {
  const [data, setData] = useState<Analytics | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    apiFetch<Analytics>("/platform/analytics")
      .then(setData)
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <p className="error-msg">{error}</p>;
  if (!data) return <p className="muted">Loading analytics…</p>;

  const revenueChartData = data.revenueByMonth.map((m) => ({
    label: m.month,
    value: m.revenue,
  }));

  const outletsChartData = data.outletsByMonth.map((m) => ({
    label: m.month,
    value: m.count,
  }));

  function fmt(n: number) {
    return n.toLocaleString("en-BD", { maximumFractionDigits: 0 });
  }

  return (
    <>
      <div className="page-header">
        <h1>Analytics</h1>
        <span className="muted" style={{ fontSize: 13 }}>Revenue &amp; growth overview</span>
      </div>

      <div className="stat-grid">
        <div className="stat-card">
          <div className="label">MRR (30 days)</div>
          <div className="value">৳{fmt(data.mrr)}</div>
        </div>
        <div className="stat-card">
          <div className="label">ARR (projected)</div>
          <div className="value">৳{fmt(data.arr)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Total Revenue</div>
          <div className="value">৳{fmt(data.totalRevenue)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Paying Outlets</div>
          <div className="value">{data.topOutlets.length}</div>
        </div>
      </div>

      <div className="two-col-grid" style={{ gap: 20, marginBottom: 20 }}>
        <div className="card">
          <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Revenue by Month</h2>
          {revenueChartData.length > 0 ? (
            <div style={{ height: 220 }}>
              <BarChart data={revenueChartData} />
            </div>
          ) : (
            <p className="muted">No payment data yet.</p>
          )}
        </div>
        <div className="card">
          <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>New Outlets by Month</h2>
          {outletsChartData.length > 0 ? (
            <div style={{ height: 220 }}>
              <OutletGrowthChart data={outletsChartData} />
            </div>
          ) : (
            <p className="muted">No outlet data yet.</p>
          )}
        </div>
      </div>

      <div className="two-col-grid" style={{ gap: 20, marginBottom: 20 }}>
        <div className="card">
          <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Subscription Breakdown</h2>
          <SubBreakdownBars breakdown={data.subscriptionBreakdown} />
        </div>
        <div className="card">
          <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Top Outlets by Revenue</h2>
          {data.topOutlets.length > 0 ? (
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Outlet</th>
                    <th>Revenue</th>
                    <th>Payments</th>
                  </tr>
                </thead>
                <tbody>
                  {data.topOutlets.map((o, i) => (
                    <tr key={o.outletId}>
                      <td className="muted">{i + 1}</td>
                      <td>
                        <div>{o.outletName}</div>
                        <div className="muted" style={{ fontSize: 12 }}>{o.restaurantName}</div>
                      </td>
                      <td>৳{fmt(o.totalRevenue)}</td>
                      <td>{o.paymentCount}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="muted">No revenue data yet.</p>
          )}
        </div>
      </div>
    </>
  );
}
