import asyncio
import json
import logging
from dataclasses import dataclass
from typing import Any

import httpx
from pydantic import ValidationError

from config import settings
from schemas import ReceiptScanCandidate


LLM_TIMEOUT_SECONDS = 90.0
OCR_TIMEOUT_SECONDS = 90.0
PROVIDER_ERROR_DETAIL_LIMIT = 800
logger = logging.getLogger(__name__)

_KNOWN_UNITS = {"kg", "gm", "g", "ltr", "l", "ml", "pcs", "pc", "pack", "dozen"}


VALID_CATEGORIES = {"stock_in", "count"}


class ReceiptScanError(RuntimeError):
    pass


@dataclass
class ReceiptScanParseResult:
    items: list[ReceiptScanCandidate]
    provider: str
    warnings: list[str]
    category: str


@dataclass(frozen=True)
class _Provider:
    name: str
    api_key: str
    model: str
    url: str
    supports_schema: bool


def _providers() -> list[_Provider]:
    return [
        _Provider(
            name="deepseek",
            api_key=settings.DEEPSEEK_API_KEY.strip(),
            model=settings.MENU_SCAN_DEEPSEEK_MODEL.strip(),
            url="https://api.deepseek.com/chat/completions",
            supports_schema=False,
        ),
    ]


def _receipt_scan_schema() -> dict[str, Any]:
    item = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "nameEn": {"type": "string", "description": "Item name in English."},
            "nameBn": {"type": "string", "description": "Item name in Bangla."},
            "qty": {"type": "number", "description": "Quantity (positive number)."},
            "unit": {
                "type": "string",
                "description": "Lowercase unit: kg, gm, ltr, ml, pcs, pack, dozen.",
            },
            "unitPriceBdt": {
                "type": "number",
                "description": "Price per unit in BDT, before discounts. 0 if unknown or for a count.",
            },
            "totalBdt": {
                "type": "number",
                "description": "Line total paid in BDT. 0 for a count.",
            },
            "matchedInventoryItemId": {
                "type": ["string", "null"],
                "description": (
                    "For a count, the id of the matching inventory item from the "
                    "provided known-items list, or null if unsure. Always null for stock_in."
                ),
            },
        },
        "required": [
            "nameEn",
            "nameBn",
            "qty",
            "unit",
            "unitPriceBdt",
            "totalBdt",
            "matchedInventoryItemId",
        ],
    }
    return {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "category": {
                "type": "string",
                "enum": ["stock_in", "count"],
                "description": "Document type: stock_in (supplier bill) or count (stock count sheet).",
            },
            "items": {"type": "array", "items": item},
        },
        "required": ["category", "items"],
    }


def _category_instructions(category: str | None) -> str:
    if category == "stock_in":
        return (
            "The document is a supplier receipt / purchase bill. Set "
            '"category" to "stock_in".'
        )
    if category == "count":
        return (
            "The document is a stock-count / end-of-day count sheet. Set "
            '"category" to "count".'
        )
    return (
        "Classify the document yourself and set \"category\" accordingly. Use "
        '"stock_in" when it looks like a supplier receipt or purchase bill — '
        "it has a vendor name, item prices, and a payable total. Use \"count\" "
        "when it looks like a stock-count / end-of-day count sheet — a title "
        "like \"end of day count\", \"stock count\", \"closing stock\", or "
        "\"daily count\", or a bare checklist of item names against counted "
        "quantities with no prices."
    )


def _receipt_scan_instructions(category: str | None) -> str:
    return (
        "Return JSON only. Extract inventory line items from a photographed "
        "restaurant document into the provided schema. The input is OCR.space "
        "JSON for page photos. Read OCR text from ParsedResults[].ParsedText and "
        "use OCR JSON as supporting evidence. "
        f"{_category_instructions(category)} "
        "Pages may contain Bangla, English, vendor names, addresses, phone "
        "numbers, dates, headers like INVOICE/BILL/RECEIPT, VAT/tax lines, "
        "discount lines, sub-totals, totals, payment notes, and decorative copy; "
        "ignore anything that is not an inventory line item. Do not include "
        "sub-totals, taxes, discounts, delivery charges, or grand totals as "
        "items. Return English and Bangla names in separate fields: nameEn, "
        "nameBn. nameBn must be Bengali script, not Romanized Bangla and never a "
        "copy of nameEn. If one language is missing, translate or transliterate "
        "the missing side. Normalize the unit to one of: kg, gm, ltr, ml, pcs, "
        "pack, dozen — pick the closest. "
        "For category stock_in: each line item must have a positive quantity, a "
        "unit, and a positive total in BDT (no currency symbols); if unitPriceBdt "
        "is not printed, compute it as totalBdt / qty (round to 2 decimals); set "
        "matchedInventoryItemId to null. "
        "For category count: each line item has a counted quantity (zero is "
        "allowed) and a unit; set unitPriceBdt and totalBdt to 0; set "
        "matchedInventoryItemId to the id of the best-matching known inventory "
        "item, or null if none matches confidently. "
        "Merge duplicate sightings of the same item across pages."
    )


def _known_items_block(known_items: list[dict[str, Any]] | None) -> str:
    rows = []
    for entry in known_items or []:
        item_id = str(entry.get("id") or "").strip()
        name = str(entry.get("name") or "").strip()
        if not item_id or not name:
            continue
        unit = str(entry.get("unit") or "").strip()
        rows.append(f"{item_id} : {name}" + (f" : {unit}" if unit else ""))
    if not rows:
        return (
            "\n\nKNOWN INVENTORY ITEMS: none provided. Leave "
            "matchedInventoryItemId null for every item."
        )
    listing = "\n".join(rows)
    return (
        "\n\nKNOWN INVENTORY ITEMS (id : name : unit) — match count items to "
        f"these ids only:\n{listing}"
    )


def _prompt(
    page_texts: list[str],
    *,
    category: str | None = None,
    known_items: list[dict[str, Any]] | None = None,
) -> list[dict[str, str]]:
    pages = "\n\n".join(
        f"--- OCR.SPACE PAGE {index + 1} JSON ---\n{text.strip()}"
        for index, text in enumerate(page_texts)
        if text.strip()
    )
    return [
        {"role": "system", "content": _receipt_scan_instructions(category)},
        {
            "role": "user",
            "content": (
                "Parse these OCR.space JSON pages into JSON with a category and an "
                "items array. Do not invent items that are not visible in the OCR "
                "result. Preserve the page order when practical and merge "
                "duplicate sightings of the same item."
                f"{_known_items_block(known_items)}\n\n"
                f"{pages}"
            ),
        },
    ]


def _response_format(provider: _Provider) -> dict[str, Any]:
    if provider.supports_schema:
        return {
            "type": "json_schema",
            "json_schema": {
                "name": "receipt_scan_import",
                "strict": True,
                "schema": _receipt_scan_schema(),
            },
        }
    return {"type": "json_object"}


def _request_payload(
    provider: _Provider,
    page_texts: list[str],
    *,
    category: str | None = None,
    known_items: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return {
        "model": provider.model,
        "temperature": 0,
        "messages": _prompt(page_texts, category=category, known_items=known_items),
        "response_format": _response_format(provider),
    }


def _message_content(payload: dict[str, Any]) -> str:
    choices = payload.get("choices")
    if not isinstance(choices, list) or not choices:
        return ""
    message = choices[0].get("message") if isinstance(choices[0], dict) else None
    content = message.get("content") if isinstance(message, dict) else None
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(
            part.get("text", "")
            for part in content
            if isinstance(part, dict) and isinstance(part.get("text"), str)
        )
    return ""


def _provider_error_detail(response: httpx.Response) -> str:
    try:
        payload = response.json()
    except ValueError:
        raw_detail = response.text
    else:
        raw_detail = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    detail = " ".join(raw_detail.split())
    if len(detail) <= PROVIDER_ERROR_DETAIL_LIMIT:
        return detail
    return f"{detail[:PROVIDER_ERROR_DETAIL_LIMIT]}..."


def _normalize_unit(value: Any) -> str:
    raw = str(value or "").strip().lower()
    if not raw:
        return "pcs"
    aliases = {
        "g": "gm",
        "gram": "gm",
        "grams": "gm",
        "kilogram": "kg",
        "kilograms": "kg",
        "kgs": "kg",
        "l": "ltr",
        "liter": "ltr",
        "liters": "ltr",
        "litre": "ltr",
        "litres": "ltr",
        "milliliter": "ml",
        "milliliters": "ml",
        "pc": "pcs",
        "piece": "pcs",
        "pieces": "pcs",
    }
    normalized = aliases.get(raw, raw)
    if normalized not in _KNOWN_UNITS:
        return "pcs"
    return normalized


def _resolve_category(decoded: Any, requested: str | None) -> str:
    if requested in VALID_CATEGORIES:
        return requested
    llm_category = decoded.get("category") if isinstance(decoded, dict) else None
    if isinstance(llm_category, str) and llm_category.strip() in VALID_CATEGORIES:
        return llm_category.strip()
    return "stock_in"


def _validated_items(
    raw_content: str,
    *,
    category: str | None = None,
    known_ids: set[str] | None = None,
) -> tuple[str, list[ReceiptScanCandidate]]:
    if not raw_content.strip():
        raise ReceiptScanError("The LLM returned an empty response.")
    try:
        decoded = json.loads(raw_content)
    except json.JSONDecodeError as error:
        raise ReceiptScanError("The LLM response was not valid JSON.") from error
    raw_items = decoded.get("items") if isinstance(decoded, dict) else None
    if not isinstance(raw_items, list):
        raise ReceiptScanError("The LLM JSON did not include an items array.")

    resolved = _resolve_category(decoded, category)
    is_count = resolved == "count"
    valid_ids = known_ids or set()

    items: list[ReceiptScanCandidate] = []
    for raw in raw_items:
        if not isinstance(raw, dict):
            continue
        qty = raw.get("qty")
        total = raw.get("totalBdt")
        unit_price = raw.get("unitPriceBdt")
        try:
            qty_f = float(qty) if qty is not None else 0.0
            total_f = float(total) if total is not None else 0.0
        except (TypeError, ValueError):
            continue
        if is_count:
            if qty_f < 0:
                continue
            unit_price_f = 0.0
            total_f = 0.0
        else:
            if qty_f <= 0 or total_f <= 0:
                continue
            try:
                unit_price_f = float(unit_price) if unit_price is not None else 0.0
            except (TypeError, ValueError):
                unit_price_f = 0.0
            if unit_price_f <= 0:
                unit_price_f = round(total_f / qty_f, 2)
        matched_id = raw.get("matchedInventoryItemId")
        matched_id = (
            str(matched_id).strip()
            if is_count and isinstance(matched_id, str) and str(matched_id).strip() in valid_ids
            else None
        )
        normalized = {
            "nameEn": str(raw.get("nameEn") or "").strip(),
            "nameBn": str(raw.get("nameBn") or "").strip(),
            "qty": qty_f,
            "unit": _normalize_unit(raw.get("unit")),
            "unitPriceBdt": unit_price_f,
            "totalBdt": total_f,
            "matchedInventoryItemId": matched_id,
        }
        if not normalized["nameEn"] and not normalized["nameBn"]:
            continue
        if not normalized["nameEn"]:
            normalized["nameEn"] = normalized["nameBn"]
        if not normalized["nameBn"]:
            normalized["nameBn"] = normalized["nameEn"]
        try:
            items.append(ReceiptScanCandidate.model_validate(normalized))
        except ValidationError:
            continue
    if not items:
        raise ReceiptScanError("The LLM returned no valid scan items.")
    return resolved, items


async def parse_receipt_text(
    page_texts: list[str],
    *,
    category: str | None = None,
    known_items: list[dict[str, Any]] | None = None,
) -> ReceiptScanParseResult:
    clean_pages = [text.strip() for text in page_texts if text.strip()]
    if not clean_pages:
        raise ReceiptScanError("OCR did not find readable text.")

    known_ids = {
        str(entry.get("id")).strip()
        for entry in (known_items or [])
        if str(entry.get("id") or "").strip()
    }
    configured = [provider for provider in _providers() if provider.api_key and provider.model]
    if not configured:
        raise ReceiptScanError("Receipt scan AI is not configured on the backend.")

    provider = configured[0]
    async with httpx.AsyncClient(timeout=LLM_TIMEOUT_SECONDS) as client:
        logger.info(
            "receipt scan llm request provider=%s model=%s pages=%s category=%s",
            provider.name,
            provider.model,
            len(clean_pages),
            category or "auto",
        )
        try:
            response = await client.post(
                provider.url,
                headers={
                    "Authorization": f"Bearer {provider.api_key}",
                    "Content-Type": "application/json",
                },
                json=_request_payload(
                    provider,
                    clean_pages,
                    category=category,
                    known_items=known_items,
                ),
            )
            response.raise_for_status()
            decoded = response.json()
            resolved, items = _validated_items(
                _message_content(decoded),
                category=category,
                known_ids=known_ids,
            )
            logger.info(
                "receipt scan llm parsed provider=%s category=%s items=%s",
                provider.name,
                resolved,
                len(items),
            )
            return ReceiptScanParseResult(
                items=items,
                provider=provider.name,
                warnings=[],
                category=resolved,
            )
        except (httpx.HTTPError, ValueError, ReceiptScanError) as error:
            logger.warning(
                "receipt scan llm provider failed provider=%s error=%s",
                provider.name,
                error,
            )
            raise ReceiptScanError(f"{provider.name}: {error}") from error


def _suffix_for_content_type(content_type: str) -> str:
    if "png" in content_type:
        return ".png"
    if "webp" in content_type:
        return ".webp"
    return ".jpg"


def _ocr_space_file_name(content_type: str) -> str:
    return f"receipt-page{_suffix_for_content_type(content_type)}"


def _ocr_space_payload(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise ReceiptScanError("OCR.space returned invalid JSON.")
    if payload.get("IsErroredOnProcessing"):
        details = payload.get("ErrorMessage") or payload.get("ErrorDetails")
        raise ReceiptScanError(
            f"OCR.space could not read a receipt page: {details or 'processing failed'}."
        )
    results = payload.get("ParsedResults")
    if not isinstance(results, list) or not results:
        raise ReceiptScanError("OCR.space returned no receipt page results.")
    if not any(
        isinstance(result, dict)
        and str(result.get("FileParseExitCode")) == "1"
        and isinstance(result.get("ParsedText"), str)
        and result["ParsedText"].strip()
        for result in results
    ):
        details = next(
            (
                result.get("ErrorMessage") or result.get("ErrorDetails")
                for result in results
                if isinstance(result, dict)
                and (result.get("ErrorMessage") or result.get("ErrorDetails"))
            ),
            None,
        )
        raise ReceiptScanError(
            f"OCR.space found no readable receipt text: {details or 'page parse failed'}."
        )
    return payload


async def _extract_page_ocr_json(
    client: httpx.AsyncClient,
    image_bytes: bytes,
    content_type: str,
) -> str:
    api_key = settings.OCR_SPACE_API_KEY.strip()
    if not api_key:
        raise ReceiptScanError("OCR.space API key is not configured on the backend.")
    try:
        response = await client.post(
            settings.OCR_SPACE_API_URL.strip(),
            headers={"apikey": api_key},
            data={
                "language": settings.OCR_SPACE_LANGUAGE.strip() or "auto",
                "OCREngine": settings.OCR_SPACE_ENGINE.strip() or "3",
                "detectOrientation": "true",
                "isTable": "true",
                "scale": "true",
                "isOverlayRequired": "false",
            },
            files={
                "file": (
                    _ocr_space_file_name(content_type),
                    image_bytes,
                    content_type,
                )
            },
        )
        response.raise_for_status()
        payload = _ocr_space_payload(response.json())
    except httpx.HTTPError as error:
        logger.warning(
            "OCR.space receipt request failed content_type=%s error=%s",
            content_type,
            error,
        )
        raise ReceiptScanError("OCR.space request failed while reading a receipt page.") from error
    except ValueError as error:
        raise ReceiptScanError("OCR.space did not return valid JSON.") from error
    return json.dumps(payload, ensure_ascii=False)


async def extract_receipt_page_texts(pages: list[tuple[bytes, str]]) -> list[str]:
    async with httpx.AsyncClient(timeout=OCR_TIMEOUT_SECONDS) as client:
        results = await asyncio.gather(
            *[
                _extract_page_ocr_json(client, image_bytes, content_type)
                for image_bytes, content_type in pages
            ],
            return_exceptions=True,
        )

    # A single unreadable page (a blank back, a blurry shot, a transient OCR
    # error) must not sink the whole multi-image scan. Keep every page that read
    # cleanly and only fail when nothing was readable.
    texts: list[str] = []
    first_error: BaseException | None = None
    for index, result in enumerate(results):
        if isinstance(result, BaseException):
            logger.warning(
                "receipt scan ocr page failed page=%s of=%s error=%s",
                index + 1,
                len(results),
                result,
            )
            if first_error is None:
                first_error = result
            continue
        texts.append(result)

    if not texts:
        if first_error is not None:
            raise first_error
        raise ReceiptScanError("OCR.space found no readable receipt text.")
    return texts
