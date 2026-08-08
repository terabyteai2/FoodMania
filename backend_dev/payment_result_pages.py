"""Branded HTML pages for UddoktaPay return / cancel / fail (matches admin onboarding UI)."""

from __future__ import annotations

from html import escape
from typing import Literal

PaymentResultVariant = Literal["success", "fail", "cancel"]


def _page_config(variant: PaymentResultVariant) -> dict[str, str]:
    if variant == "success":
        return {
            "title": "Payment successful",
            "heading": "You're all set!",
            "body": "Thanks for your payment. Close this window and return to the FoodMania app to continue setup.",
            "status_token": "success",
            "icon_bg": "#F2C744",
            "icon_symbol": "✓",
            "icon_color": "#14110E",
            "badge": "Payment complete",
            "badge_bg": "#FFF7DA",
            "badge_border": "#F2C744",
        }
    if variant == "fail":
        return {
            "title": "Payment failed",
            "heading": "Payment didn't go through",
            "body": "Something went wrong with this payment. Go back to the app and try checkout again.",
            "status_token": "failed",
            "icon_bg": "#FDECEA",
            "icon_symbol": "!",
            "icon_color": "#8A2A1F",
            "badge": "Try again",
            "badge_bg": "#FDECEA",
            "badge_border": "#E5B4B0",
        }
    return {
        "title": "Payment canceled",
        "heading": "Checkout canceled",
        "body": "You left checkout before paying. Return to the app when you're ready to complete activation.",
        "status_token": "canceled",
        "icon_bg": "#EFEAD8",
        "icon_symbol": "×",
        "icon_color": "#5A5450",
        "badge": "No charge",
        "badge_bg": "#FFFFFF",
        "badge_border": "#E5E0D0",
    }


def render_payment_result_page(
    variant: PaymentResultVariant,
    *,
    payment_id: str | None = None,
    invoice_id: str | None = None,
) -> str:
    """Onboarding-aligned cream/yellow page; keeps status= in DOM for WebView detection."""
    cfg = _page_config(variant)
    pid = escape(payment_id or "")
    inv = escape(invoice_id or "")
    status = escape(cfg["status_token"])
    title = escape(cfg["title"])
    heading = escape(cfg["heading"])
    body = escape(cfg["body"])
    badge = escape(cfg["badge"])
    icon_symbol = escape(cfg["icon_symbol"])

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>{title}</title>
  <style>
    *, *::before, *::after {{ box-sizing: border-box; }}
    html, body {{
      margin: 0;
      min-height: 100%;
      background: #FFFDF5;
      color: #14110E;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      -webkit-font-smoothing: antialiased;
    }}
    .page {{
      min-height: 100vh;
      min-height: 100dvh;
      display: flex;
      flex-direction: column;
      padding: max(20px, env(safe-area-inset-top)) 24px max(28px, env(safe-area-inset-bottom));
    }}
    .brand {{
      width: 52px;
      height: 52px;
      border-radius: 14px;
      background: linear-gradient(135deg, #F2C744 0%, #E0B030 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 26px;
      line-height: 1;
      box-shadow: 0 10px 22px rgba(242, 199, 68, 0.36);
      margin-bottom: 28px;
    }}
    .badge {{
      display: inline-block;
      padding: 8px 12px;
      border-radius: 999px;
      font-size: 12.5px;
      font-weight: 700;
      background: {cfg["badge_bg"]};
      border: 1px solid {cfg["badge_border"]};
      color: #14110E;
      margin-bottom: 18px;
    }}
    h1 {{
      margin: 0 0 10px;
      font-size: 28px;
      font-weight: 900;
      line-height: 1.15;
      letter-spacing: -0.02em;
      color: #14110E;
    }}
    .lead {{
      margin: 0;
      font-size: 13.5px;
      line-height: 1.5;
      color: #5A5450;
      max-width: 340px;
    }}
    .card {{
      margin-top: 32px;
      padding: 22px 20px;
      background: #FFFFFF;
      border: 1px solid #E5E0D0;
      border-radius: 16px;
      text-align: center;
      box-shadow: 0 2px 0 rgba(20, 17, 14, 0.04);
    }}
    .icon {{
      width: 64px;
      height: 64px;
      margin: 0 auto 14px;
      border-radius: 50%;
      background: {cfg["icon_bg"]};
      color: {cfg["icon_color"]};
      font-size: 32px;
      font-weight: 900;
      line-height: 64px;
    }}
    .hint {{
      margin: 24px 0 0;
      font-size: 11.5px;
      color: #9A9388;
      line-height: 1.45;
    }}
    .meta {{
      margin-top: auto;
      padding-top: 24px;
      font-size: 10px;
      color: #C4BDB2;
      word-break: break-all;
    }}
    .spacer {{ flex: 1 1 auto; min-height: 24px; }}
  </style>
</head>
<body>
  <div class="page">
    <div class="brand" aria-hidden="true">🔥</div>
    <span class="badge">{badge}</span>
    <h1>{heading}</h1>
    <p class="lead">{body}</p>
    <div class="spacer"></div>
    <div class="card">
      <div class="icon" aria-hidden="true">{icon_symbol}</div>
      <p class="lead" style="margin:0 auto; text-align:center;">{title}</p>
    </div>
    <p class="hint">You can close this tab — the app will pick up from here.</p>
    <p class="meta" id="payment-meta">status={status} payment_id={pid} invoice_id={inv}</p>
  </div>
</body>
</html>"""


def resolve_return_variant(status: str | None) -> PaymentResultVariant:
    """Map gateway query status to a result page variant."""
    raw = (status or "").strip().lower()
    if raw in {"failed", "failure", "error", "declined", "cancelled", "canceled"}:
        if raw in {"cancelled", "canceled"}:
            return "cancel"
        return "fail"
    return "success"
