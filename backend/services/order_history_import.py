import csv
import io
import re
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation


class OrderHistoryCsvError(ValueError):
    pass


@dataclass(frozen=True)
class LegacyOrderImport:
    id: str
    serial_number: int
    source_order_id: str
    total_amount: float
    items: list[dict]
    notes: str | None
    created_at: datetime


@dataclass(frozen=True)
class LegacyOrderCsvParseResult:
    orders: list[LegacyOrderImport]
    row_count: int
    skipped_rows: int
    errors: list[str]
    columns: list[str]


_ORDER_IMPORT_NAMESPACE = uuid.UUID("24442ebb-8453-40cf-a268-06bdcf86a8fa")
_ORDER_ID_HEADERS = (
    "orderid",
    "orderno",
    "order_no",
    "invoiceno",
    "invoice_no",
    "invoicenumber",
    "invoice_number",
    "billno",
    "bill_no",
    "receiptno",
    "receipt_no",
    "ticketno",
    "ticket_no",
    "transactionid",
    "transaction_id",
    "serialnumber",
    "serial_number",
)
_DATE_HEADERS = (
    "createdat",
    "created_at",
    "orderdate",
    "order_date",
    "datetime",
    "date_time",
    "timestamp",
    "billdate",
    "bill_date",
    "invoicedate",
    "invoice_date",
    "soldat",
    "sold_at",
    "date",
)
_TOTAL_HEADERS = (
    "grandtotal",
    "grand_total",
    "totalamount",
    "total_amount",
    "ordertotal",
    "order_total",
    "nettotal",
    "net_total",
    "payableamount",
    "payable_amount",
    "total",
)
_ITEM_NAME_HEADERS = (
    "itemname",
    "item_name",
    "menuitem",
    "menu_item",
    "menuitemname",
    "menu_item_name",
    "product",
    "productname",
    "product_name",
    "item",
)
_QTY_HEADERS = ("quantity", "itemqty", "item_qty", "qty", "units")
_PRICE_HEADERS = (
    "unitprice",
    "unit_price",
    "itemprice",
    "item_price",
    "rate",
    "price",
)
_LINE_TOTAL_HEADERS = (
    "linetotal",
    "line_total",
    "itemtotal",
    "item_total",
    "subtotal",
    "sub_total",
)
_NOTE_HEADERS = ("note", "notes", "remarks", "comment")


def parse_order_history_csv(
    contents: bytes,
    *,
    outlet_id: str,
) -> LegacyOrderCsvParseResult:
    text = _decode_csv(contents)
    reader = csv.DictReader(io.StringIO(text))
    columns = [str(column or "").strip() for column in reader.fieldnames or []]
    if not columns:
        raise OrderHistoryCsvError("CSV must include a header row.")

    groups: dict[str, list[dict[str, str]]] = {}
    skipped_rows = 0
    errors: list[str] = []
    for row_number, raw in enumerate(reader, start=2):
        row = {_normalize_key(key): str(value or "").strip() for key, value in raw.items()}
        if not any(row.values()):
            skipped_rows += 1
            continue
        order_id = _first_text(row, _ORDER_ID_HEADERS)
        created_at = _parse_datetime(_first_text(row, _DATE_HEADERS))
        if created_at is None:
            skipped_rows += 1
            errors.append(f"Row {row_number}: missing or invalid order date.")
            continue
        group_key = f"{order_id}|{created_at.isoformat()}" if order_id else f"row-{row_number}"
        row["_row_number"] = str(row_number)
        row["_created_at"] = created_at.isoformat()
        row["_source_order_id"] = order_id or group_key
        groups.setdefault(group_key, []).append(row)

    orders = [
        _build_order(group_rows, outlet_id=outlet_id)
        for group_rows in groups.values()
    ]
    return LegacyOrderCsvParseResult(
        orders=orders,
        row_count=sum(len(group) for group in groups.values()) + skipped_rows,
        skipped_rows=skipped_rows,
        errors=errors[:20],
        columns=columns,
    )


def _build_order(rows: list[dict[str, str]], *, outlet_id: str) -> LegacyOrderImport:
    first = rows[0]
    source_order_id = first["_source_order_id"]
    created_at = datetime.fromisoformat(first["_created_at"])
    row_notes = " | ".join(
        dict.fromkeys(
            note
            for row in rows
            if (note := _first_text(row, _NOTE_HEADERS))
        )
    )
    notes = f"Legacy POS order: {source_order_id}"
    if row_notes:
        notes = f"{notes} | {row_notes}"

    items: list[dict] = []
    order_total = Decimal("0")
    item_seed = f"{source_order_id}|{created_at.isoformat()}"
    for index, row in enumerate(rows, start=1):
        total = _parse_money(_first_text(row, _TOTAL_HEADERS))
        if total is not None and total > order_total:
            order_total = total
        item = _item_from_row(row, order_seed=item_seed, index=index)
        if item is not None:
            items.append(item)

    item_total = sum((Decimal(str(item["lineTotal"])) for item in items), Decimal("0"))
    if order_total <= 0:
        order_total = item_total
    if order_total <= 0:
        order_total = Decimal("0")
    if not items:
        items.append(_summary_item(item_seed, order_total))

    stable_id = str(
        uuid.uuid5(
            _ORDER_IMPORT_NAMESPACE,
            f"{outlet_id}|{source_order_id}|{created_at.isoformat()}",
        )
    )
    return LegacyOrderImport(
        id=stable_id,
        serial_number=_serial_number(source_order_id),
        source_order_id=source_order_id,
        total_amount=float(order_total),
        items=items,
        notes=notes,
        created_at=created_at,
    )


def _item_from_row(
    row: dict[str, str],
    *,
    order_seed: str,
    index: int,
) -> dict | None:
    name = _first_text(row, _ITEM_NAME_HEADERS)
    if not name:
        return None
    qty = _parse_quantity(_first_text(row, _QTY_HEADERS))
    price = _parse_money(_first_text(row, _PRICE_HEADERS))
    line_total = _parse_money(_first_text(row, _LINE_TOTAL_HEADERS))
    if line_total is None and price is not None:
        line_total = price * qty
    if price is None and line_total is not None:
        price = line_total / qty
    price = price or Decimal("0")
    line_total = line_total or price * qty
    item_key = f"{order_seed}|{index}|{name}"
    return {
        "id": str(uuid.uuid5(_ORDER_IMPORT_NAMESPACE, f"line|{item_key}")),
        "menuItemId": f"legacy-pos:{uuid.uuid5(_ORDER_IMPORT_NAMESPACE, f'item|{name}')}",
        "name": name,
        "qty": int(qty),
        "price": float(price),
        "lineTotal": float(line_total),
    }


def _summary_item(order_seed: str, total: Decimal) -> dict:
    return {
        "id": str(uuid.uuid5(_ORDER_IMPORT_NAMESPACE, f"summary|{order_seed}")),
        "menuItemId": "legacy-pos:order-total",
        "name": "Legacy order total",
        "qty": 1,
        "price": float(total),
        "lineTotal": float(total),
    }


def _decode_csv(contents: bytes) -> str:
    if not contents:
        raise OrderHistoryCsvError("CSV file is empty.")
    for encoding in ("utf-8-sig", "utf-8", "cp1252"):
        try:
            return contents.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise OrderHistoryCsvError("CSV text must use UTF-8 or Windows CSV encoding.")


def _normalize_key(value: object) -> str:
    return re.sub(r"[^a-z0-9_]", "", str(value or "").strip().lower().replace(" ", "_"))


def _first_text(row: dict[str, str], headers: tuple[str, ...]) -> str:
    for header in headers:
        value = row.get(header, "").strip()
        if value:
            return value
    return ""


def _parse_datetime(value: str) -> datetime | None:
    cleaned = value.strip()
    if not cleaned:
        return None
    candidates = [cleaned, cleaned.replace("Z", "+00:00")]
    for candidate in candidates:
        try:
            parsed = datetime.fromisoformat(candidate)
            return parsed if parsed.tzinfo is not None else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    for pattern in (
        "%Y-%m-%d %I:%M %p",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%d/%m/%Y %I:%M %p",
        "%d/%m/%Y %H:%M:%S",
        "%d/%m/%Y %H:%M",
        "%m/%d/%Y %I:%M %p",
        "%m/%d/%Y %H:%M:%S",
        "%m/%d/%Y %H:%M",
        "%Y-%m-%d",
    ):
        try:
            return datetime.strptime(cleaned, pattern).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def _parse_money(value: str) -> Decimal | None:
    cleaned = re.sub(r"[^0-9.\-]", "", value.replace(",", ""))
    if not cleaned or cleaned in {"-", ".", "-."}:
        return None
    try:
        parsed = Decimal(cleaned)
    except InvalidOperation:
        return None
    return parsed if parsed >= 0 else None


def _parse_quantity(value: str) -> Decimal:
    parsed = _parse_money(value)
    if parsed is None or parsed <= 0:
        return Decimal("1")
    rounded = int(parsed)
    return Decimal(rounded if rounded > 0 else 1)


def _serial_number(source_order_id: str) -> int:
    digits = re.sub(r"\D", "", source_order_id)
    if not digits:
        return 0
    return min(int(digits[-9:]), 999999999)
