import { useEffect, useRef, useState } from "react";
import { AccountSearchResult, apiFetch } from "../api/client";

type BlockingNoticePayload = {
  title: string;
  message: string;
  imageUrl: string;
  inputField: boolean;
  inputLabel: string;
  outletIds: string[] | null;
};

const emptyForm = {
  imageUrl: "",
  title: "",
  message: "",
  inputField: false,
  inputLabel: "",
};

export default function MessagesPage() {
  const [form, setForm] = useState(emptyForm);
  const [target, setTarget] = useState<"all" | "specific">("all");
  const [searchQ, setSearchQ] = useState("");
  const [searchResults, setSearchResults] = useState<AccountSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; msg: string } | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => {
    if (target !== "specific" || searchQ.trim().length < 2) {
      setSearchResults([]);
      return;
    }
    setSearching(true);
    debounceRef.current = setTimeout(() => {
      apiFetch<AccountSearchResult[]>(
        `/platform/accounts/search?q=${encodeURIComponent(searchQ.trim())}`,
      )
        .then(setSearchResults)
        .catch(() => setSearchResults([]))
        .finally(() => setSearching(false));
    }, 300);
    return () => clearTimeout(debounceRef.current);
  }, [searchQ, target]);

  function toggleAccount(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function send() {
    if (!form.message.trim()) {
      setResult({ ok: false, msg: "Message text is required." });
      return;
    }
    if (target === "specific" && selected.size === 0) {
      setResult({ ok: false, msg: "Select at least one outlet or switch to 'All outlets'." });
      return;
    }
    setSending(true);
    setResult(null);
    try {
      const payload: BlockingNoticePayload = {
        title: form.title.trim(),
        message: form.message.trim(),
        imageUrl: form.imageUrl.trim(),
        inputField: form.inputField,
        inputLabel: form.inputLabel.trim(),
        outletIds: target === "specific" ? Array.from(selected) : null,
      };
      const res = await apiFetch<{ notifiedOutlets: number }>("/platform/blocking-notice", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      const targetLabel = target === "all" ? "all outlets" : `${res.notifiedOutlets} outlet${res.notifiedOutlets === 1 ? "" : "s"}`;
      setResult({ ok: true, msg: `Message sent to ${targetLabel}.` });
      setForm(emptyForm);
      setSelected(new Set());
    } catch (e) {
      setResult({ ok: false, msg: e instanceof Error ? e.message : "Send failed." });
    } finally {
      setSending(false);
    }
  }

  return (
    <>
      <div className="page-header">
        <h1>Send Admin Message</h1>
        <span className="muted" style={{ fontSize: 13 }}>
          Publish a blocking notice to restaurant POS apps.
        </span>
      </div>

      {result && (
        <p style={{ color: result.ok ? "var(--success)" : "var(--danger)", fontSize: 13, marginBottom: 12 }}>
          {result.msg}
        </p>
      )}

      <div className="card" style={{ marginBottom: 20 }}>
        <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Message content</h2>

        <div className="form-group">
          <label>Hero image URL</label>
          <input
            type="url"
            value={form.imageUrl}
            onChange={(e) => setForm((f) => ({ ...f, imageUrl: e.target.value }))}
            placeholder="https://example.com/banner.png"
            style={{ width: "100%" }}
          />
          <span className="muted" style={{ fontSize: 12 }}>
            Optional. Shown as a hero image above the message.
          </span>
        </div>

        <div className="form-group">
          <label>Title *</label>
          <input
            type="text"
            value={form.title}
            onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
            placeholder="Important notice"
            style={{ width: "100%" }}
          />
          <span className="muted" style={{ fontSize: 12 }}>
            Defaults to "Notice from Terafoods" if left empty.
          </span>
        </div>

        <div className="form-group">
          <label>Message text *</label>
          <textarea
            rows={4}
            value={form.message}
            onChange={(e) => setForm((f) => ({ ...f, message: e.target.value }))}
            placeholder="Describe the reason for this notice…"
            style={{ width: "100%" }}
          />
        </div>

        <div className="form-group">
          <label className="toggle-row">
            <span>Show input field (for contact info / reply)</span>
            <div
              className={`toggle-switch ${form.inputField ? "on" : ""}`}
              onClick={() => setForm((f) => ({ ...f, inputField: !f.inputField }))}
            />
          </label>
        </div>

        {form.inputField && (
          <div className="form-group">
            <label>Input label / placeholder</label>
            <input
              type="text"
              value={form.inputLabel}
              onChange={(e) => setForm((f) => ({ ...f, inputLabel: e.target.value }))}
              placeholder="Your contact email"
              style={{ width: "100%" }}
            />
          </div>
        )}
      </div>

      <div className="card" style={{ marginBottom: 20 }}>
        <h2 style={{ margin: "0 0 16px", fontSize: 15 }}>Target</h2>

        <div className="form-group">
          <label style={{ display: "flex", gap: 20, alignItems: "center" }}>
            <label style={{ display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
              <input
                type="radio"
                name="target"
                checked={target === "all"}
                onChange={() => setTarget("all")}
              />
              All outlets
            </label>
            <label style={{ display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
              <input
                type="radio"
                name="target"
                checked={target === "specific"}
                onChange={() => setTarget("specific")}
              />
              Specific outlets
            </label>
          </label>
        </div>

        {target === "specific" && (
          <>
            <div className="search-bar" style={{ marginBottom: 12 }}>
              <input
                type="search"
                placeholder="Search by mobile number…"
                value={searchQ}
                onChange={(e) => setSearchQ(e.target.value)}
                style={{ width: "100%" }}
              />
              {searching && <span className="muted" style={{ fontSize: 12, marginLeft: 8 }}>Searching…</span>}
            </div>

            {selected.size > 0 && (
              <p style={{ fontSize: 13, margin: "0 0 8px", color: "var(--accent)" }}>
                {selected.size} outlet{selected.size === 1 ? "" : "s"} selected
              </p>
            )}

            {searchResults.length > 0 ? (
              <div className="table-scroll">
                <table>
                  <thead>
                    <tr>
                      <th style={{ width: 40 }} />
                      <th>Phone</th>
                      <th>Name</th>
                      <th>Outlet</th>
                      <th>Restaurant</th>
                    </tr>
                  </thead>
                  <tbody>
                    {searchResults.map((a) => (
                      <tr
                        key={a.id}
                        style={{ cursor: "pointer", opacity: selected.has(a.id) ? 1 : 0.7 }}
                        onClick={() => toggleAccount(a.id)}
                      >
                        <td>
                          <input
                            type="checkbox"
                            checked={selected.has(a.id)}
                            onChange={() => toggleAccount(a.id)}
                          />
                        </td>
                        <td>{a.phone}</td>
                        <td>{a.displayName || "—"}</td>
                        <td>{a.outletName}</td>
                        <td>{a.restaurantName}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : searchQ.trim().length >= 2 && !searching ? (
              <p className="muted" style={{ fontSize: 13 }}>No accounts match "{searchQ}".</p>
            ) : null}
          </>
        )}
      </div>

      <div style={{ display: "flex", gap: 10 }}>
        <button
          type="button"
          className="btn"
          onClick={send}
          disabled={sending || (target === "specific" && selected.size === 0)}
          style={{ minWidth: 160 }}
        >
          {sending ? "Sending…" : "Send Message"}
        </button>
        <button
          type="button"
          className="btn-secondary btn"
          onClick={() => {
            setForm(emptyForm);
            setSelected(new Set());
            setResult(null);
          }}
        >
          Discard
        </button>
      </div>
    </>
  );
}
