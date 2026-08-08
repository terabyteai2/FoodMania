import uuid
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from database import get_db
from models import BkashSession, UddoktaPaySession
from subscription_service import activate_subscription_from_payment, resolve_outlet_by_server_id
from schemas import BkashCreateRequest, UddoktaPayCreateRequest, UddoktaPayVerifyRequest, ok
from payment_urls import is_local_or_private_url, payment_callback_base, uddokta_redirect_warning
from payment_result_pages import render_payment_result_page, resolve_return_variant
from uddoktapay_client import (
    UddoktaPayError,
    create_checkout,
    is_payment_completed,
    normalized_base_url,
    uddokta_configured,
    verify_payment,
)

router = APIRouter()


def _bkash_session_dict(s: BkashSession) -> dict:
    return {
        "paymentId": s.id,
        "serverId": s.server_id,
        "amount": float(s.amount),
        "currency": s.currency,
        "purpose": s.purpose,
        "status": s.status,
        "checkoutUrl": "",
        "createdAt": s.created_at.isoformat(),
    }


def _uddokta_session_dict(s: UddoktaPaySession, *, checkout_url: str | None = None) -> dict:
    url = checkout_url or s.payment_url or ""
    paid = s.status in {"paid", "verified"}
    return {
        "paymentId": s.id,
        "serverId": s.server_id,
        "amount": float(s.amount),
        "currency": s.currency,
        "purpose": s.purpose,
        "plan": s.plan,
        "status": "paid" if paid else s.status,
        "checkoutUrl": url,
        "invoiceId": s.invoice_id,
        "transactionId": s.transaction_id,
        "createdAt": s.created_at.isoformat(),
    }


def _public_base() -> str:
    return payment_callback_base()


@router.get("/payments/config")
async def payment_config():
    callback_base = _public_base()
    return ok(
        {
            "uddoktaPayEnabled": uddokta_configured(),
            "uddoktaPaySandbox": settings.UDDOKTAPAY_SANDBOX,
            "uddoktaPayBaseUrl": normalized_base_url(),
            "callbackBaseUrl": callback_base,
            "redirectUrlWarning": uddokta_redirect_warning(),
        }
    )


# ── Legacy bKash sandbox (local stub) ─────────────────────────────────────────

@router.post("/payments/bkash/create")
async def create_bkash_payment(body: BkashCreateRequest, db: AsyncSession = Depends(get_db)):
    session = BkashSession(
        id=str(uuid.uuid4()),
        server_id=body.serverId,
        amount=body.amount,
        currency=body.currency,
        purpose=body.purpose,
        status="pending",
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    data = _bkash_session_dict(session)
    data["checkoutUrl"] = f"{_public_base()}/payments/bkash/mock-checkout?paymentId={session.id}"
    return ok(data)


@router.post("/payments/bkash/{payment_id}/verify")
async def verify_bkash_payment(payment_id: str, db: AsyncSession = Depends(get_db)):
    session = (await db.execute(select(BkashSession).where(BkashSession.id == payment_id))).scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found.")
    session.status = "verified"
    await db.commit()
    await db.refresh(session)
    data = _bkash_session_dict(session)
    data["status"] = "paid"
    data["transactionId"] = f"mock_{payment_id[:8]}"
    return ok(data)


@router.get("/payments/bkash/{payment_id}/status")
async def bkash_payment_status(payment_id: str, db: AsyncSession = Depends(get_db)):
    session = (await db.execute(select(BkashSession).where(BkashSession.id == payment_id))).scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found.")
    return ok(_bkash_session_dict(session))


# ── UddoktaPay (sandbox / live) ─────────────────────────────────────────────

@router.post("/payments/uddokta/create")
async def create_uddokta_payment(
    body: UddoktaPayCreateRequest,
    db: AsyncSession = Depends(get_db),
):
    if not uddokta_configured():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="UddoktaPay is not configured. Set UDDOKTAPAY_API_KEY in backend/.env",
        )

    redirect_warning = uddokta_redirect_warning()
    if redirect_warning:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=redirect_warning,
        )

    session_id = str(uuid.uuid4())
    base = _public_base()
    redirect_url = f"{base}/payments/uddokta/return?payment_id={session_id}"
    cancel_url = f"{base}/payments/uddokta/cancel?payment_id={session_id}"
    webhook_url = (
        None
        if is_local_or_private_url(base)
        else f"{base}/payments/uddokta/webhook"
    )

    metadata = {
        "payment_id": session_id,
        "server_id": body.serverId,
        "purpose": body.purpose,
        "plan": body.plan,
    }

    try:
        checkout = await create_checkout(
            full_name=body.fullName.strip() or "Restaurant Manager",
            email=body.email.strip() or "manager@example.com",
            amount=f"{body.amount:.0f}",
            metadata=metadata,
            redirect_url=redirect_url,
            cancel_url=cancel_url,
            webhook_url=webhook_url,
            return_type="GET",
        )
    except UddoktaPayError as error:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(error)) from error

    payment_url = str(checkout.get("payment_url", ""))
    invoice_id = str(
        checkout.get("invoice_id") or checkout.get("invoiceId") or ""
    ).strip()
    outlet = await resolve_outlet_by_server_id(db, body.serverId)
    session = UddoktaPaySession(
        id=session_id,
        outlet_id=outlet.id if outlet else None,
        server_id=body.serverId,
        amount=body.amount,
        currency=body.currency,
        purpose=body.purpose,
        plan=body.plan,
        status="pending",
        payment_url=payment_url,
        invoice_id=invoice_id or None,
        customer_name=body.fullName,
        customer_email=body.email,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return ok(_uddokta_session_dict(session, checkout_url=payment_url))


@router.post("/payments/uddokta/{payment_id}/verify")
async def verify_uddokta_payment(
    payment_id: str,
    body: UddoktaPayVerifyRequest | None = None,
    db: AsyncSession = Depends(get_db),
):
    if not uddokta_configured():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="UddoktaPay is not configured.",
        )

    session = (
        await db.execute(select(UddoktaPaySession).where(UddoktaPaySession.id == payment_id))
    ).scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found.")

    if session.status in {"paid", "verified"}:
        await activate_subscription_from_payment(db, session)
        await db.commit()
        await db.refresh(session)
        return ok(_uddokta_session_dict(session))

    invoice_id = (body.invoiceId if body else None) or session.invoice_id
    if not invoice_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="invoiceId is required to verify payment.",
        )

    try:
        result = await verify_payment(invoice_id)
    except UddoktaPayError as error:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(error)) from error

    if not is_payment_completed(result):
        session.status = "pending"
        await db.commit()
        data = _uddokta_session_dict(session)
        data["lastError"] = f"Payment status: {result.get('status', 'PENDING')}"
        return ok(data)

    session.status = "paid"
    session.invoice_id = invoice_id
    session.transaction_id = str(result.get("transaction_id") or result.get("trx_id") or "")
    await activate_subscription_from_payment(db, session)
    await db.commit()
    await db.refresh(session)
    return ok(_uddokta_session_dict(session))


@router.get("/payments/uddokta/{payment_id}/status")
async def uddokta_payment_status(payment_id: str, db: AsyncSession = Depends(get_db)):
    session = (
        await db.execute(select(UddoktaPaySession).where(UddoktaPaySession.id == payment_id))
    ).scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found.")
    return ok(_uddokta_session_dict(session))


@router.get("/payments/uddokta/return", response_class=HTMLResponse)
async def uddokta_return(
    request: Request,
    payment_id: str | None = Query(None),
    invoice_id: str | None = Query(None),
    status: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    """Browser redirect after checkout. WebView detects status=success on this URL."""
    pid = payment_id or request.query_params.get("payment_id")
    inv = invoice_id or request.query_params.get("invoice_id")
    status_value = status or request.query_params.get("status")
    variant = resolve_return_variant(status_value)

    if variant == "success" and pid and inv:
        session = (
            await db.execute(select(UddoktaPaySession).where(UddoktaPaySession.id == pid))
        ).scalar_one_or_none()
        if session is not None and session.invoice_id != inv:
            session.invoice_id = inv
            await db.commit()
        if session is not None and session.status == "pending":
            session.status = "paid"
            session.invoice_id = inv
            await activate_subscription_from_payment(db, session)
            await db.commit()

    html = render_payment_result_page(
        variant,
        payment_id=pid,
        invoice_id=inv,
    )
    return HTMLResponse(
        content=html,
        headers={"Cache-Control": "no-store"},
    )


@router.get("/payments/uddokta/fail", response_class=HTMLResponse)
async def uddokta_fail(
    request: Request,
    payment_id: str | None = Query(None),
    invoice_id: str | None = Query(None),
):
    pid = payment_id or request.query_params.get("payment_id")
    inv = invoice_id or request.query_params.get("invoice_id")
    html = render_payment_result_page(
        "fail",
        payment_id=pid,
        invoice_id=inv,
    )
    return HTMLResponse(content=html, headers={"Cache-Control": "no-store"})


@router.get("/payments/uddokta/cancel", response_class=HTMLResponse)
async def uddokta_cancel(
    request: Request,
    payment_id: str | None = Query(None),
    invoice_id: str | None = Query(None),
):
    pid = payment_id or request.query_params.get("payment_id")
    inv = invoice_id or request.query_params.get("invoice_id")
    html = render_payment_result_page(
        "cancel",
        payment_id=pid,
        invoice_id=inv,
    )
    return HTMLResponse(content=html, headers={"Cache-Control": "no-store"})


@router.post("/payments/uddokta/webhook")
async def uddokta_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    """Optional IPN from UddoktaPay dashboard / gateway."""
    try:
        payload = await request.json()
    except Exception:
        payload = {}

    invoice_id = str(payload.get("invoice_id") or payload.get("invoiceId") or "").strip()
    payment_id = str(
        (payload.get("metadata") or {}).get("payment_id")
        if isinstance(payload.get("metadata"), dict)
        else payload.get("payment_id")
        or ""
    ).strip()

    if not payment_id and invoice_id:
        session = (
            await db.execute(
                select(UddoktaPaySession).where(UddoktaPaySession.invoice_id == invoice_id)
            )
        ).scalar_one_or_none()
    else:
        session = (
            await db.execute(select(UddoktaPaySession).where(UddoktaPaySession.id == payment_id))
        ).scalar_one_or_none() if payment_id else None

    if session is None:
        return ok({"received": True, "matched": False})

    if invoice_id:
        session.invoice_id = invoice_id
    status_value = str(payload.get("status", "")).upper()
    if status_value == "COMPLETED":
        session.status = "paid"
        session.transaction_id = str(payload.get("transaction_id") or "")
        await activate_subscription_from_payment(db, session)
    await db.commit()
    return ok({"received": True, "matched": True, "paymentId": session.id})
