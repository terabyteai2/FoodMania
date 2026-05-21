import { useCallback, useEffect, useState } from "react";
import { apiFetch, Payment } from "../api/client";
import PaymentStatusEditor from "../components/PaymentStatusEditor";

export default function PaymentsPage() {
  const [payments, setPayments] = useState<Payment[]>([]);
  const [gateway, setGateway] = useState("");
  const [error, setError] = useState("");

  const load = useCallback(() => {
    const params = new URLSearchParams({ limit: "100" });
    if (gateway) params.set("gateway", gateway);
    apiFetch<Payment[]>(`/platform/payments?${params}`)
      .then(setPayments)
      .catch((e) => setError(e.message));
  }, [gateway]);

  useEffect(() => {
    load();
  }, [load]);

  function onPaymentUpdated(updated: Payment) {
    setPayments((list) =>
      list.map((p) =>
        p.gateway === updated.gateway && p.paymentId === updated.paymentId ? updated : p
      )
    );
  }

  return (
    <>
      <div className="page-header">
        <h1>Payments</h1>
        <p className="muted" style={{ margin: 0, fontSize: 13 }}>
          Change status to <strong>paid</strong> or <strong>verified</strong> to unlock the admin app
          for that outlet.
        </p>
      </div>

      <div className="search-bar">
        <select value={gateway} onChange={(e) => setGateway(e.target.value)}>
          <option value="">All gateways</option>
          <option value="uddokta">UddoktaPay</option>
          <option value="bkash">bKash (sandbox)</option>
        </select>
      </div>

      {error && <p className="error-msg">{error}</p>}

      <div className="card">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Outlet</th>
                <th>Restaurant</th>
                <th>Gateway</th>
                <th>Amount</th>
                <th>Plan</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {payments.map((p) => (
                <tr key={`${p.gateway}-${p.paymentId}`}>
                  <td style={{ whiteSpace: "nowrap" }}>{new Date(p.createdAt).toLocaleString()}</td>
                  <td>{p.outletName || p.serverId.slice(0, 8)}</td>
                  <td>{p.restaurantName || "—"}</td>
                  <td>{p.gateway}</td>
                  <td>
                    {p.amount} {p.currency}
                  </td>
                  <td>{p.plan || "—"}</td>
                  <td>
                    <PaymentStatusEditor payment={p} onUpdated={onPaymentUpdated} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {payments.length === 0 && !error && <p className="muted">No payments.</p>}
      </div>
    </>
  );
}
