import { useState } from "react";
import { apiFetch, Payment } from "../api/client";
import StatusBadge from "./StatusBadge";

const STATUS_OPTIONS = [
  { value: "pending", label: "Pending" },
  { value: "paid", label: "Paid" },
  { value: "verified", label: "Verified" },
  { value: "failed", label: "Failed" },
  { value: "cancelled", label: "Cancelled" },
];

type Props = {
  payment: Payment;
  onUpdated: (payment: Payment) => void;
};

export default function PaymentStatusEditor({ payment, onUpdated }: Props) {
  const [status, setStatus] = useState(payment.status);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function save() {
    if (status === payment.status) return;
    setBusy(true);
    setError("");
    try {
      const updated = await apiFetch<Payment>(
        `/platform/payments/${payment.gateway}/${payment.paymentId}`,
        {
          method: "PATCH",
          body: JSON.stringify({ status, activateSubscription: true }),
        }
      );
      onUpdated(updated);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Update failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 6, minWidth: 140 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
        <StatusBadge status={payment.status} />
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          disabled={busy}
          style={{ fontSize: 12, padding: "4px 8px", borderRadius: 8 }}
          aria-label="Payment status"
        >
          {STATUS_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
        <button
          type="button"
          className="btn"
          style={{ padding: "4px 10px", fontSize: 12 }}
          disabled={busy || status === payment.status}
          onClick={() => void save()}
        >
          {busy ? "…" : "Save"}
        </button>
      </div>
      {status === "paid" || status === "verified" ? (
        <span className="muted" style={{ fontSize: 11 }}>
          Saving as paid activates the outlet subscription (app unlocks on next open).
        </span>
      ) : null}
      {error ? (
        <span className="error-msg" style={{ fontSize: 11 }}>
          {error}
        </span>
      ) : null}
    </div>
  );
}
