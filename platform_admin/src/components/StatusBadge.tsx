export default function StatusBadge({ status }: { status: string }) {
  const normalized = status.toLowerCase();
  const cls =
    normalized === "active" || normalized === "paid" || normalized === "verified"
      ? "badge-active"
      : normalized === "trial" || normalized === "pending"
        ? "badge-pending"
        : normalized === "expired" || normalized === "cancelled" || normalized === "suspended"
          ? "badge-expired"
          : "badge-trial";
  return <span className={`badge ${cls}`}>{status}</span>;
}
