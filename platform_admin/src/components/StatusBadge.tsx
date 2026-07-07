export default function StatusBadge({ status }: { status: string }) {
  const normalized = status.toLowerCase();
  const cls =
    normalized === "active" || normalized === "paid" || normalized === "verified"
      ? "badge-active"
      : normalized === "trial"
        ? "badge-trial"
        : normalized === "on_hold" || normalized === "pending" || normalized === "expired"
          ? "badge-on-hold"
          : normalized === "paused"
            ? "badge-paused"
            : normalized === "cancelled" || normalized === "suspended"
              ? "badge-cancelled"
              : "badge-trial";
  return <span className={`badge ${cls}`}>{status}</span>;
}
