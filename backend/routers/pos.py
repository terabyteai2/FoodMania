from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_device_payload
from database import get_db
from models import AdminAccount, Order, Outlet, PosAuditEvent, PosSettlement, PosShift
from routers.ws import manager
from schemas import (
    PosAuditPayload,
    PosKotPayload,
    PosSettingsPatchPayload,
    PosSettlementPayload,
    PosShiftClosePayload,
    PosShiftOpenPayload,
    ok,
)
from services.customer_orders import order_to_dict

router = APIRouter()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _money(value: object) -> float:
    return round(float(value or 0), 2)


def _fallback_floor(table_count: int) -> list[dict]:
    return [
        {
            "id": "main",
            "name": "Main",
            "sortOrder": 0,
            "tables": [
                {"id": f"table-{index}", "label": str(index), "seats": 4, "sortOrder": index - 1}
                for index in range(1, max(0, table_count) + 1)
            ],
        }
    ]


def _settings_dict(outlet: Outlet) -> dict:
    floor = list(outlet.pos_floor_layout or [])
    if not floor:
        floor = _fallback_floor(
            int(outlet.table_count if outlet.table_count is not None else 10)
        )
    return {
        "floorLayout": floor,
        "vatRatePercent": _money(outlet.pos_vat_rate_percent),
        "serviceChargePercent": _money(outlet.pos_service_charge_percent),
        "discountPresets": list(outlet.pos_discount_presets or []),
        "tableCount": int(outlet.table_count if outlet.table_count is not None else 10),
        # NULL when unconfigured — clients fall back to their own default.
        "dailySalesTarget": (
            _money(outlet.pos_daily_sales_target)
            if outlet.pos_daily_sales_target is not None
            else None
        ),
    }


def _shift_dict(shift: PosShift | None) -> dict | None:
    if shift is None:
        return None
    return {
        "id": shift.id,
        "outletId": shift.outlet_id,
        "status": shift.status,
        "openingCash": _money(shift.opening_cash),
        "expectedCash": _money(shift.expected_cash),
        "countedCash": _money(shift.counted_cash),
        "varianceCash": _money(shift.variance_cash),
        "openingDenominations": shift.opening_denominations or {},
        "closingDenominations": shift.closing_denominations or {},
        "openedByAccountId": shift.opened_by_account_id,
        "closedByAccountId": shift.closed_by_account_id,
        "openedAt": shift.opened_at.isoformat(),
        "closedAt": shift.closed_at.isoformat() if shift.closed_at else None,
        "updatedAt": shift.updated_at.isoformat(),
    }


async def _account(
    outlet_id: str,
    payload: dict,
    db: AsyncSession,
    *,
    manager_only: bool = False,
) -> AdminAccount:
    if str(payload.get("sub") or "") != outlet_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Outlet token mismatch.")
    account_id = str(payload.get("account_id") or "")
    if not account_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account token required.")
    account = (
        await db.execute(
            select(AdminAccount).where(
                AdminAccount.id == account_id,
                AdminAccount.outlet_id == outlet_id,
                AdminAccount.is_active.is_(True),
            )
        )
    ).scalar_one_or_none()
    if account is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Active account required.")
    if manager_only and account.role not in ("owner", "manager"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Manager account required.")
    return account


async def _outlet(outlet_id: str, db: AsyncSession) -> Outlet:
    outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found.")
    return outlet


async def _open_shift(outlet_id: str, db: AsyncSession) -> PosShift | None:
    return (
        await db.execute(
            select(PosShift)
            .where(PosShift.outlet_id == outlet_id, PosShift.status == "open")
            .order_by(PosShift.opened_at.desc())
        )
    ).scalars().first()


async def _shift_cash_sales(shift_id: str, db: AsyncSession) -> float:
    settlements = (
        await db.execute(
            select(PosSettlement).where(
                PosSettlement.shift_id == shift_id,
                PosSettlement.payment_method == "cash",
            )
        )
    ).scalars().all()
    return _money(sum(float(entry.amount) for entry in settlements))


@router.get("/outlets/{outlet_id}/pos/settings")
async def get_pos_settings(
    outlet_id: str,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    await _account(outlet_id, payload, db)
    return ok(_settings_dict(await _outlet(outlet_id, db)))


@router.patch("/outlets/{outlet_id}/pos/settings")
async def patch_pos_settings(
    outlet_id: str,
    body: PosSettingsPatchPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    await _account(outlet_id, payload, db, manager_only=True)
    outlet = await _outlet(outlet_id, db)
    if body.floorLayout is not None:
        floor = [zone.model_dump() for zone in body.floorLayout]
        table_count = sum(len(zone["tables"]) for zone in floor)
        if table_count < 0 or table_count > 200:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Floor layout must contain between 0 and 200 tables.",
            )
        outlet.pos_floor_layout = floor
        outlet.table_count = table_count
    if body.vatRatePercent is not None:
        outlet.pos_vat_rate_percent = body.vatRatePercent
    if body.serviceChargePercent is not None:
        outlet.pos_service_charge_percent = body.serviceChargePercent
    if body.dailySalesTarget is not None:
        outlet.pos_daily_sales_target = body.dailySalesTarget
    if body.discountPresets is not None:
        presets = [preset.model_dump() for preset in body.discountPresets]
        for preset in presets:
            if preset["kind"] not in {"percent", "fixed"}:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Discount preset kind must be percent or fixed.",
                )
            if preset["kind"] == "percent" and preset["value"] > 100:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Percentage discount presets cannot exceed 100.",
                )
        outlet.pos_discount_presets = presets
    await db.commit()
    await db.refresh(outlet)
    return ok(_settings_dict(outlet))


@router.get("/outlets/{outlet_id}/pos/shifts/current")
async def current_shift(
    outlet_id: str,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    await _account(outlet_id, payload, db)
    shift = await _open_shift(outlet_id, db)
    data = _shift_dict(shift)
    if data is not None:
        cash_sales = await _shift_cash_sales(shift.id, db)
        data["cashSales"] = cash_sales
        data["expectedCash"] = _money(float(shift.opening_cash) + cash_sales)
    return ok(data)


@router.post("/outlets/{outlet_id}/pos/shifts/open")
async def open_shift(
    outlet_id: str,
    body: PosShiftOpenPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _account(outlet_id, payload, db)
    existing_by_id = (
        await db.execute(select(PosShift).where(PosShift.id == body.id))
    ).scalar_one_or_none()
    if existing_by_id is not None:
        if existing_by_id.outlet_id != outlet_id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Shift ID conflict.")
        return ok(_shift_dict(existing_by_id))
    active = await _open_shift(outlet_id, db)
    if active is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Another outlet register shift is already open.",
        )
    now = _now()
    shift = PosShift(
        id=body.id,
        outlet_id=outlet_id,
        opening_cash=body.openingCash,
        opening_denominations=body.denominations,
        opened_by_account_id=account.id,
        opened_at=now,
        updated_at=now,
    )
    db.add(shift)
    await db.commit()
    await db.refresh(shift)
    await manager.broadcast(outlet_id, {"type": "pos_shift_opened", "data": _shift_dict(shift)})
    return ok(_shift_dict(shift))


@router.post("/outlets/{outlet_id}/pos/shifts/{shift_id}/close")
async def close_shift(
    outlet_id: str,
    shift_id: str,
    body: PosShiftClosePayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _account(outlet_id, payload, db, manager_only=True)
    shift = (
        await db.execute(
            select(PosShift).where(PosShift.id == shift_id, PosShift.outlet_id == outlet_id)
        )
    ).scalar_one_or_none()
    if shift is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shift not found.")
    if shift.status == "closed":
        return ok(_shift_dict(shift))
    cash_sales = await _shift_cash_sales(shift.id, db)
    expected = _money(float(shift.opening_cash) + cash_sales)
    counted = _money(body.countedCash)
    shift.status = "closed"
    shift.expected_cash = expected
    shift.counted_cash = counted
    shift.variance_cash = _money(counted - expected)
    shift.closing_denominations = body.denominations
    shift.closed_by_account_id = account.id
    shift.closed_at = _now()
    shift.updated_at = shift.closed_at
    await db.commit()
    await db.refresh(shift)
    await manager.broadcast(outlet_id, {"type": "pos_shift_closed", "data": _shift_dict(shift)})
    return ok(_shift_dict(shift))


@router.post("/outlets/{outlet_id}/pos/orders/{order_id}/kot")
async def send_kot(
    outlet_id: str,
    order_id: str,
    body: PosKotPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    await _account(outlet_id, payload, db)
    order = (
        await db.execute(select(Order).where(Order.id == order_id, Order.outlet_id == outlet_id))
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")
    for existing in list(order.kot_batches or []):
        if existing.get("id") == body.batchId:
            return ok(order_to_dict(order))
    sent_at = _now().isoformat()
    ids = set(body.itemIds)
    normalized_items = []
    for raw_item in list(order.items or []):
        item = dict(raw_item)
        if str(item.get("id") or "") in ids:
            item["kotBatchId"] = body.batchId
            item["kotSentAt"] = sent_at
        normalized_items.append(item)
    batches = list(order.kot_batches or [])
    batches.append({"id": body.batchId, "itemIds": body.itemIds, "note": body.note, "sentAt": sent_at})
    order.items = normalized_items
    order.kot_batches = batches
    order.updated_at = _now()
    await db.commit()
    await db.refresh(order)
    await manager.broadcast(outlet_id, {"type": "order_updated", "data": order_to_dict(order)})
    return ok(order_to_dict(order))


@router.post("/outlets/{outlet_id}/pos/orders/{order_id}/settle")
async def settle_order(
    outlet_id: str,
    order_id: str,
    body: PosSettlementPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _account(outlet_id, payload, db)
    order = (
        await db.execute(select(Order).where(Order.id == order_id, Order.outlet_id == outlet_id))
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")
    shift = await _open_shift(outlet_id, db)
    if shift is None or shift.id != body.shiftId:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An open outlet shift is required.")

    settlement_total = _money(sum(line.amount for line in body.settlements))
    if any(line.amount <= 0 for line in body.settlements) or abs(settlement_total - body.totalAmount) > 0.01:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Split payments must equal the bill total.")

    outlet = await _outlet(outlet_id, db)
    presets = list(outlet.pos_discount_presets or [])
    preset = next((entry for entry in presets if entry.get("id") == body.discountPresetId), None)
    if body.discountAmount > 0 and account.role not in ("owner", "manager") and preset is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff may only apply configured discount presets.")
    if body.discountAmount > 0 and account.role not in ("owner", "manager") and preset is not None:
        preset_value = float(preset.get("value") or 0)
        allowed_discount = (
            _money(float(order.subtotal or 0) * preset_value / 100)
            if preset.get("kind") == "percent"
            else _money(preset_value)
        )
        if abs(allowed_discount - body.discountAmount) > 0.01:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Staff discount amount must match the configured preset.",
            )
    if body.customDiscountLabel and account.role not in ("owner", "manager"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Custom discounts require a manager account.")

    expected_total = _money(
        float(order.subtotal or 0)
        + float(order.vat_amount or 0)
        + float(order.delivery_charge or 0)
        + body.serviceChargeAmount
        - body.discountAmount
    )
    if abs(expected_total - body.totalAmount) > 0.01:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Bill total does not match its adjustments.")

    for line in body.settlements:
        existing = (
            await db.execute(select(PosSettlement).where(PosSettlement.event_id == line.eventId))
        ).scalar_one_or_none()
        if existing is None:
            db.add(
                PosSettlement(
                    event_id=line.eventId,
                    outlet_id=outlet_id,
                    order_id=order.id,
                    shift_id=shift.id,
                    payment_method=line.paymentMethod.strip().lower(),
                    amount=line.amount,
                    payer_label=(line.payerLabel or "").strip() or None,
                    created_by_account_id=account.id,
                )
            )
    order.shift_id = shift.id
    order.discount_label = (
        (preset or {}).get("label") or (body.customDiscountLabel or "").strip() or None
    )
    order.discount_amount = body.discountAmount
    order.service_charge_rate_percent = body.serviceChargeRatePercent
    order.service_charge_amount = body.serviceChargeAmount
    order.total_amount = body.totalAmount
    order.payment_method = (
        body.settlements[0].paymentMethod if len(body.settlements) == 1 else "split"
    )
    snapshot = {
        "subtotal": _money(order.subtotal),
        "vatRatePercent": _money(order.vat_rate_percent),
        "vatAmount": _money(order.vat_amount),
        "deliveryCharge": _money(order.delivery_charge),
        "discountLabel": order.discount_label,
        "discountAmount": _money(order.discount_amount),
        "serviceChargeRatePercent": _money(order.service_charge_rate_percent),
        "serviceChargeAmount": _money(order.service_charge_amount),
        "totalAmount": _money(order.total_amount),
    }
    # Persist the split breakdown so a split bill is reprintable / auditable
    # from the order alone. Derived from the settlement lines the client already
    # sends — single-payment settles are unaffected.
    if len(body.settlements) > 1:
        snapshot["isSplit"] = True
        snapshot["payers"] = [
            {
                "label": line.payerLabel or f"Payer {index + 1}",
                "paymentMethod": line.paymentMethod.strip().lower(),
                "amount": _money(line.amount),
            }
            for index, line in enumerate(body.settlements)
        ]
    order.billing_snapshot = snapshot
    order.settled_at = _now()
    if order.status not in {"cancelled", "served"}:
        order.status = "served"
    order.updated_at = _now()
    await db.commit()
    await db.refresh(order)
    await manager.broadcast(outlet_id, {"type": "order_updated", "data": order_to_dict(order)})
    return ok(order_to_dict(order))


@router.post("/outlets/{outlet_id}/pos/orders/{order_id}/audit")
async def audit_order(
    outlet_id: str,
    order_id: str,
    body: PosAuditPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _account(outlet_id, payload, db, manager_only=True)
    order = (
        await db.execute(select(Order).where(Order.id == order_id, Order.outlet_id == outlet_id))
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")
    existing = (
        await db.execute(select(PosAuditEvent).where(PosAuditEvent.event_id == body.eventId))
    ).scalar_one_or_none()
    if existing is not None:
        return ok({"eventId": existing.event_id, "action": existing.action})
    action = body.action.strip().lower()
    if action not in {"void", "refund", "comp", "override_discount"}:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Unknown audit action.")
    event = PosAuditEvent(
        event_id=body.eventId,
        outlet_id=outlet_id,
        order_id=order.id,
        shift_id=body.shiftId,
        action=action,
        reason=(body.reason or "").strip() or None,
        metadata_json=body.metadata,
        created_by_account_id=account.id,
        created_by_role=account.role,
    )
    db.add(event)
    if action == "refund":
        amount = _money(body.amount)
        if amount <= 0 or not body.paymentMethod:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Refund amount and payment method are required.")
        db.add(
            PosSettlement(
                event_id=f"refund:{body.eventId}",
                outlet_id=outlet_id,
                order_id=order.id,
                shift_id=body.shiftId,
                kind="refund",
                payment_method=body.paymentMethod.strip().lower(),
                amount=-amount,
                created_by_account_id=account.id,
            )
        )
    order.updated_at = _now()
    await db.commit()
    return ok({"eventId": body.eventId, "action": action})


@router.get("/outlets/{outlet_id}/pos/audit")
async def list_audit(
    outlet_id: str,
    days: int = 30,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    # Owner/manager only — every void / refund / comp / discount override.
    await _account(outlet_id, payload, db, manager_only=True)
    since = _now() - timedelta(days=max(1, min(days, 365)))
    events = (
        await db.execute(
            select(PosAuditEvent)
            .where(
                PosAuditEvent.outlet_id == outlet_id,
                PosAuditEvent.created_at >= since,
            )
            .order_by(PosAuditEvent.created_at.desc())
            .limit(200)
        )
    ).scalars().all()

    order_ids = {e.order_id for e in events if e.order_id}
    orders: dict[str, Order] = {}
    if order_ids:
        rows = (
            await db.execute(select(Order).where(Order.id.in_(order_ids)))
        ).scalars().all()
        orders = {o.id: o for o in rows}

    account_ids = {e.created_by_account_id for e in events if e.created_by_account_id}
    accounts: dict[str, AdminAccount] = {}
    if account_ids:
        rows = (
            await db.execute(select(AdminAccount).where(AdminAccount.id.in_(account_ids)))
        ).scalars().all()
        accounts = {a.id: a for a in rows}

    def _entry(e: PosAuditEvent) -> dict:
        order = orders.get(e.order_id) if e.order_id else None
        account = accounts.get(e.created_by_account_id) if e.created_by_account_id else None
        meta = e.metadata_json or {}
        raw_amount = meta.get("amount")
        return {
            "id": e.id,
            "eventId": e.event_id,
            "action": e.action,
            "reason": e.reason,
            "amount": _money(raw_amount) if raw_amount is not None else None,
            "orderId": e.order_id,
            "orderSerial": (order.serial_number if order is not None else None),
            "who": (
                (account.display_name or account.username or account.email)
                if account is not None
                else None
            ),
            "role": e.created_by_role,
            "createdAt": e.created_at.isoformat(),
        }

    return ok({"events": [_entry(e) for e in events]})


@router.get("/outlets/{outlet_id}/pos/reports")
async def pos_reports(
    outlet_id: str,
    days: int = 7,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    await _account(outlet_id, payload, db)
    now = _now()
    since = now - timedelta(days=max(1, min(days, 90)))
    orders = (
        await db.execute(
            select(Order).where(
                Order.outlet_id == outlet_id,
                Order.created_at >= since,
                Order.status.in_(("served", "completed")),
            )
        )
    ).scalars().all()
    history_orders = (
        await db.execute(
            select(Order).where(
                Order.outlet_id == outlet_id,
                Order.created_at >= now - timedelta(days=35),
                Order.status.in_(("served", "completed")),
            )
        )
    ).scalars().all()
    settlements = (
        await db.execute(
            select(PosSettlement).where(
                PosSettlement.outlet_id == outlet_id,
                PosSettlement.created_at >= since,
            )
        )
    ).scalars().all()
    audits = (
        await db.execute(
            select(PosAuditEvent).where(
                PosAuditEvent.outlet_id == outlet_id,
                PosAuditEvent.created_at >= since,
            )
        )
    ).scalars().all()
    hourly = Counter()
    items: dict[str, dict] = {}
    staff = defaultdict(lambda: {"orders": 0, "sales": 0.0})
    covers_by_hour = Counter()
    prior_same_weekday_hourly = Counter()
    prior_same_weekdays = set()
    for order in orders:
        hourly[str(order.created_at.astimezone(timezone.utc).hour)] += _money(order.total_amount)
        covers_by_hour[str(order.created_at.astimezone(timezone.utc).hour)] += int(order.covers or 0)
        actor = order.created_by_account_id or order.created_by_role or "unknown"
        staff[actor]["orders"] += 1
        staff[actor]["sales"] = _money(staff[actor]["sales"] + float(order.total_amount or 0))
        for raw in list(order.items or []):
            key = str(raw.get("menuItemId") or raw.get("name") or "item")
            row = items.setdefault(key, {"menuItemId": key, "name": raw.get("name") or "Item", "qty": 0, "sales": 0.0, "margin": 0.0})
            qty = int(raw.get("qty") or 0)
            sales = _money(raw.get("lineTotal"))
            cost = _money(raw.get("costPriceSnapshot")) * qty
            row["qty"] += qty
            row["sales"] = _money(row["sales"] + sales)
            row["margin"] = _money(row["margin"] + sales - cost)
    for order in history_orders:
        created = order.created_at.astimezone(timezone.utc)
        if created.weekday() != now.weekday() or created.date() == now.date():
            continue
        prior_same_weekdays.add(created.date())
        prior_same_weekday_hourly[str(created.hour)] += _money(order.total_amount)
    if prior_same_weekdays:
        prior_same_weekday_hourly = Counter(
            {
                hour: _money(total / len(prior_same_weekdays))
                for hour, total in prior_same_weekday_hourly.items()
            }
        )
    payment_split = Counter()
    for settlement in settlements:
        payment_split[settlement.payment_method] += _money(settlement.amount)
    return ok(
        {
            "days": days,
            "sales": _money(sum(float(order.total_amount or 0) for order in orders)),
            "orders": len(orders),
            "covers": sum(int(order.covers or 0) for order in orders),
            "hourlySales": dict(hourly),
            "priorSameWeekdayHourlyAverage": dict(prior_same_weekday_hourly),
            "coversByHour": dict(covers_by_hour),
            "paymentSplit": {key: _money(value) for key, value in payment_split.items()},
            "items": sorted(items.values(), key=lambda item: item["qty"], reverse=True),
            "staff": [{"accountId": key, **value} for key, value in staff.items()],
            "auditCounts": dict(Counter(event.action for event in audits)),
        }
    )
