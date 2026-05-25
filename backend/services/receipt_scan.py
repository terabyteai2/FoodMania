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


class ReceiptScanError(RuntimeError):
    pass


@dataclass
class ReceiptScanParseResult:
    items: list[ReceiptScanCandidate]
    provider: str
    warnings: list[str]


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
            name="groq",
            api_key=settings.GROQ_API_KEY.strip(),
            model=settings.MENU_SCAN_GROQ_MODEL.strip(),
            url="https://api.groq.com/openai/v1/chat/completions",
            supports_schema=False,
        ),
        _Provider(
            name="xai",
            api_key=settings.XAI_API_KEY.strip(),
            model=settings.MENU_SCAN_XAI_MODEL.strip(),
            url="https://api.x.ai/v1/chat/completions",
            supports_schema=True,
        ),
        _Provider(
            name="deepseek",
            api_key=settings.DEEPSEEK_API_KEY.strip(),
            model=settings.MENU_SCAN_DEEPSEEK_MODEL.strip(),
            url="https://api.deepseek.com/chat/completions",
            supports_schema=False,
        ),
        _Provider(
            name="openai",
            api_key=settings.OPENAI_API_KEY.strip(),
            model=settings.MENU_SCAN_OPENAI_MODEL.strip(),
            url="https://api.openai.com/v1/chat/completions",
            supports_schema=True,
        ),
    ]


def _receipt_scan_schema() -> dict[str, Any]:
    item = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "nameEn": {"type": "string", "description": "Item name in English."},
            "nameBn": {"type": "string", "description": "Item name in Bangla."},
            "qty": {"type": "number", "description": "Quantity bought (positive number)."},
            "unit": {
                "type": "string",
                "description": "Lowercase unit: kg, gm, ltr, ml, pcs, pack, dozen.",
            },
            "unitPriceBdt": {
                "type": "number",
                "description": "Price per unit in BDT, before discounts. 0 if unknown.",
            },
            "totalBdt": {
                "type": "number",
                "description": "Line total paid in BDT.",
            },
        },
        "required": ["nameEn", "nameBn", "qty", "unit", "unitPriceBdt", "totalBdt"],
    }
    return {
        "type": "object",
        "additionalProperties": False,
        "properties": {"items": {"type": "array", "items": item}},
        "required": ["items"],
    }


def _receipt_scan_instructions() -> str:
    return (
        "Return JSON only. Extract inventory line items from a restaurant supplier "
        "receipt or hand-written bill into the provided schema. The input is "
        "OCR.space JSON for receipt page photos. Read OCR text from "
        "ParsedResults[].ParsedText and use OCR JSON as supporting evidence. "
        "Receipts may contain Bangla, English, vendor names, addresses, phone "
        "numbers, dates, headers like INVOICE/BILL/RECEIPT, VAT/tax lines, "
        "discount lines, sub-totals, totals, payment notes, and decorative copy; "
        "ignore anything that is not a purchasable inventory line item with a "
        "quantity and a price. Do not include sub-totals, taxes, discounts, "
        "delivery charges, or grand totals as items. Each line item must have a "
        "positive numeric quantity, a unit, and a positive numeric total in BDT "
        "(no currency symbols). Return English and Bangla names in separate "
        "fields: nameEn, nameBn. nameBn must be Bengali script, not Romanized "
        "Bangla and never a copy of nameEn. If one language is missing, "
        "translate or transliterate the missing side. Normalize the unit to one "
        "of: kg, gm, ltr, ml, pcs, pack, dozen — pick the closest. If "
        "unitPriceBdt is not printed, compute it as totalBdt / qty (round to "
        "2 decimals). Merge duplicate sightings of the same item across pages."
    )


def _prompt(page_texts: list[str]) -> list[dict[str, str]]:
    pages = "\n\n".join(
        f"--- OCR.SPACE RECEIPT PAGE {index + 1} JSON ---\n{text.strip()}"
        for index, text in enumerate(page_texts)
        if text.strip()
    )
    return [
        {"role": "system", "content": _receipt_scan_instructions()},
        {
            "role": "user",
            "content": (
                "Parse these OCR.space JSON receipt pages into JSON with an items "
                "array. Do not invent items that are not visible in the OCR "
                "result. Preserve the page order when practical and merge "
                "duplicate sightings of the same item.\n\n"
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


def _request_payload(provider: _Provider, page_texts: list[str]) -> dict[str, Any]:
    payload = {
        "model": provider.model,
        "temperature": 0,
        "messages": _prompt(page_texts),
        "response_format": _response_format(provider),
    }
    if provider.name == "groq":
        payload.update(
            {
                "reasoning_format": "hidden",
                "reasoning_effort": "low",
            }
        )
    return payload


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


def _validated_items(raw_content: str) -> list[ReceiptScanCandidate]:
    if not raw_content.strip():
        raise ReceiptScanError("The LLM returned an empty response.")
    try:
        decoded = json.loads(raw_content)
    except json.JSONDecodeError as error:
        raise ReceiptScanError("The LLM response was not valid JSON.") from error
    raw_items = decoded.get("items") if isinstance(decoded, dict) else None
    if not isinstance(raw_items, list):
        raise ReceiptScanError("The LLM JSON did not include an items array.")

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
        if qty_f <= 0 or total_f <= 0:
            continue
        try:
            unit_price_f = float(unit_price) if unit_price is not None else 0.0
        except (TypeError, ValueError):
            unit_price_f = 0.0
        if unit_price_f <= 0:
            unit_price_f = round(total_f / qty_f, 2)
        normalized = {
            "nameEn": str(raw.get("nameEn") or "").strip(),
            "nameBn": str(raw.get("nameBn") or "").strip(),
            "qty": qty_f,
            "unit": _normalize_unit(raw.get("unit")),
            "unitPriceBdt": unit_price_f,
            "totalBdt": total_f,
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
        raise ReceiptScanError("The LLM returned no valid priced receipt items.")
    return items


async def parse_receipt_text(page_texts: list[str]) -> ReceiptScanParseResult:
    clean_pages = [text.strip() for text in page_texts if text.strip()]
    if not clean_pages:
        raise ReceiptScanError("OCR did not find readable receipt text.")

    warnings: list[str] = []
    configured = [provider for provider in _providers() if provider.api_key and provider.model]
    if not configured:
        raise ReceiptScanError("Receipt scan AI is not configured on the backend.")

    async with httpx.AsyncClient(timeout=LLM_TIMEOUT_SECONDS) as client:
        for provider in configured:
            try:
                logger.info(
                    "receipt scan llm request provider=%s model=%s pages=%s",
                    provider.name,
                    provider.model,
                    len(clean_pages),
                )
                response = await client.post(
                    provider.url,
                    headers={
                        "Authorization": f"Bearer {provider.api_key}",
                        "Content-Type": "application/json",
                    },
                    json=_request_payload(provider, clean_pages),
                )
                response.raise_for_status()
                decoded = response.json()
                items = _validated_items(_message_content(decoded))
                logger.info(
                    "receipt scan llm parsed provider=%s items=%s",
                    provider.name,
                    len(items),
                )
                return ReceiptScanParseResult(
                    items=items,
                    provider=provider.name,
                    warnings=warnings,
                )
            except httpx.HTTPStatusError as error:
                logger.warning(
                    "receipt scan llm provider rejected provider=%s status=%s detail=%s",
                    provider.name,
                    error.response.status_code,
                    _provider_error_detail(error.response),
                )
                warnings.append(f"{provider.name}: {error}")
            except (httpx.HTTPError, ValueError, ReceiptScanError) as error:
                logger.warning(
                    "receipt scan llm provider failed provider=%s error=%s",
                    provider.name,
                    error,
                )
                warnings.append(f"{provider.name}: {error}")

    raise ReceiptScanError("All configured receipt scan AI providers failed.")


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
        return await asyncio.gather(
            *[
                _extract_page_ocr_json(client, image_bytes, content_type)
                for image_bytes, content_type in pages
            ]
        )
