"""UddoktaPay HTTP client (sandbox + live). API key stays server-side only."""

from __future__ import annotations

from typing import Any

import httpx

from config import resolved_uddokta_base_url, settings


class UddoktaPayError(Exception):
    pass


def uddokta_configured() -> bool:
    return bool(settings.UDDOKTAPAY_API_KEY.strip())


def normalized_base_url() -> str:
    """Gateway origin only — checkout paths are appended by this client."""
    base = resolved_uddokta_base_url().rstrip("/")
    for suffix in ("/api/checkout-v2", "/api/verify-payment"):
        if base.endswith(suffix):
            base = base[: -len(suffix)]
    # e.g. https://brand.paymently.io/api → https://brand.paymently.io
    if base.endswith("/api"):
        base = base[: -len("/api")]
    return base.rstrip("/")


async def create_checkout(
    *,
    full_name: str,
    email: str,
    amount: str,
    metadata: dict[str, Any],
    redirect_url: str,
    cancel_url: str,
    webhook_url: str | None = None,
    return_type: str = "GET",
) -> dict[str, Any]:
    base = normalized_base_url()
    payload: dict[str, Any] = {
        "full_name": full_name,
        "email": email,
        "amount": amount,
        "metadata": metadata,
        "redirect_url": redirect_url,
        "cancel_url": cancel_url,
        "return_type": return_type,
    }
    if webhook_url:
        payload["webhook_url"] = webhook_url

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{base}/api/checkout-v2",
            json=payload,
            headers=_headers(),
        )

    try:
        data = response.json()
    except Exception:
        snippet = (response.text or "")[:200]
        raise UddoktaPayError(
            f"UddoktaPay returned HTTP {response.status_code} (not JSON). {snippet}"
        ) from None
    if not isinstance(data, dict):
        raise UddoktaPayError("UddoktaPay returned an unexpected response.")
    if response.status_code >= 400 or not data.get("status"):
        message = data.get("message") or response.text or "Checkout failed."
        raise UddoktaPayError(message)
    payment_url = data.get("payment_url")
    if not payment_url:
        raise UddoktaPayError("UddoktaPay did not return a payment_url.")
    return data


async def verify_payment(invoice_id: str) -> dict[str, Any]:
    base = normalized_base_url()
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{base}/api/verify-payment",
            json={"invoice_id": invoice_id},
            headers=_headers(),
        )

    try:
        data = response.json()
    except Exception:
        snippet = (response.text or "")[:200]
        raise UddoktaPayError(
            f"Verify returned HTTP {response.status_code} (not JSON). {snippet}"
        ) from None
    if response.status_code >= 400:
        message = data.get("message") if isinstance(data, dict) else response.text
        raise UddoktaPayError(message or "Verify payment failed.")
    return data if isinstance(data, dict) else {}


def is_payment_completed(verify_payload: dict[str, Any]) -> bool:
    status = str(verify_payload.get("status", "")).upper()
    return status == "COMPLETED"


def _headers() -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "RT-UDDOKTAPAY-API-KEY": settings.UDDOKTAPAY_API_KEY.strip(),
    }
