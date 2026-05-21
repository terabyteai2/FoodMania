import asyncio
import json
import logging
import os
import tempfile
import threading
from dataclasses import dataclass
from typing import Any

import httpx
from pydantic import ValidationError

from config import settings
from schemas import MenuScanCandidate


LLM_TIMEOUT_SECONDS = 90.0
_ocr_engine: Any | None = None
_ocr_lock = threading.Lock()
logger = logging.getLogger(__name__)


class MenuScanError(RuntimeError):
    pass


@dataclass
class MenuScanParseResult:
    items: list[MenuScanCandidate]
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


def _menu_scan_schema() -> dict[str, Any]:
    item = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "name": {
                "type": "string",
                "description": "Item name in English and Bangla, formatted as English / Bangla.",
            },
            "description": {
                "type": "string",
                "description": "Short item description in English and Bangla, formatted as English / Bangla.",
            },
            "category": {
                "type": "string",
                "description": "Menu category in English and Bangla, formatted as English / Bangla.",
            },
            "price": {"type": "number", "description": "Positive numeric menu price only."},
            "isAvailable": {"type": "boolean"},
        },
        "required": ["name", "description", "category", "price", "isAvailable"],
    }
    return {
        "type": "object",
        "additionalProperties": False,
        "properties": {"items": {"type": "array", "items": item}},
        "required": ["items"],
    }


def _prompt(page_texts: list[str]) -> list[dict[str, str]]:
    pages = "\n\n".join(
        f"--- MENU PAGE {index + 1} ---\n{text.strip()}"
        for index, text in enumerate(page_texts)
        if text.strip()
    )
    return [
        {
            "role": "system",
            "content": (
                "Return JSON only. Extract restaurant menu items from OCR text "
                "into the provided schema. OCR may contain Bangla, English, "
                "restaurant names, logos, slogans, addresses, phone numbers, "
                "opening hours, social media, Wi-Fi text, VAT, tax, service "
                "charge, delivery notes, table text, and decorative copy; ignore "
                "anything that is not a sellable menu item with a price. Do not "
                "turn the restaurant name or section decorations into items. "
                "Each item must have a positive numeric price without currency "
                "symbols. For name, category, and description, include both "
                "English and Bangla in one string using this exact style: "
                "English / Bangla. If one language is missing from OCR, translate "
                "or transliterate the missing side. If a category is missing, "
                "infer a useful category in both languages; use General / সাধারণ "
                "only when no better category is clear. If an item description is "
                "missing, write a short appetizing description in both languages. "
                "Use isAvailable true."
            ),
        },
        {
            "role": "user",
            "content": (
                "Parse these OCR menu pages into JSON with an items array. "
                "Do not invent items that are not visible in OCR text. Preserve "
                "the page order when practical and merge duplicate sightings of "
                "the same item.\n\n"
                f"{pages}"
            ),
        },
    ]


def _request_payload(provider: _Provider, page_texts: list[str]) -> dict[str, Any]:
    response_format: dict[str, Any]
    if provider.supports_schema:
        response_format = {
            "type": "json_schema",
            "json_schema": {
                "name": "menu_scan_import",
                "strict": True,
                "schema": _menu_scan_schema(),
            },
        }
    else:
        response_format = {"type": "json_object"}
    return {
        "model": provider.model,
        "temperature": 0,
        "messages": _prompt(page_texts),
        "response_format": response_format,
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


def _validated_items(raw_content: str) -> list[MenuScanCandidate]:
    if not raw_content.strip():
        raise MenuScanError("The LLM returned an empty response.")
    try:
        decoded = json.loads(raw_content)
    except json.JSONDecodeError as error:
        raise MenuScanError("The LLM response was not valid JSON.") from error
    raw_items = decoded.get("items") if isinstance(decoded, dict) else None
    if not isinstance(raw_items, list):
        raise MenuScanError("The LLM JSON did not include an items array.")

    items: list[MenuScanCandidate] = []
    for raw in raw_items:
        if not isinstance(raw, dict):
            continue
        normalized = {
            "name": str(raw.get("name") or "").strip(),
            "description": str(raw.get("description") or "").strip(),
            "category": str(raw.get("category") or "General / সাধারণ").strip()
            or "General / সাধারণ",
            "price": raw.get("price"),
            "isAvailable": raw.get("isAvailable", True),
        }
        try:
            items.append(MenuScanCandidate.model_validate(normalized))
        except ValidationError:
            continue
    if not items:
        raise MenuScanError("The LLM returned no valid priced menu items.")
    return items


async def parse_menu_text(page_texts: list[str]) -> MenuScanParseResult:
    clean_pages = [text.strip() for text in page_texts if text.strip()]
    if not clean_pages:
        raise MenuScanError("OCR did not find readable menu text.")

    warnings: list[str] = []
    configured = [provider for provider in _providers() if provider.api_key and provider.model]
    if not configured:
        raise MenuScanError("Menu scan AI is not configured on the backend.")

    async with httpx.AsyncClient(timeout=LLM_TIMEOUT_SECONDS) as client:
        for provider in configured:
            try:
                logger.info(
                    "menu scan llm request provider=%s model=%s pages=%s",
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
                    "menu scan llm parsed provider=%s items=%s",
                    provider.name,
                    len(items),
                )
                return MenuScanParseResult(
                    items=items,
                    provider=provider.name,
                    warnings=warnings,
                )
            except (httpx.HTTPError, ValueError, MenuScanError) as error:
                logger.warning(
                    "menu scan llm provider failed provider=%s error=%s",
                    provider.name,
                    error,
                )
                warnings.append(f"{provider.name}: {error}")

    raise MenuScanError("All configured menu scan AI providers failed.")


def _get_ocr_engine() -> Any:
    global _ocr_engine
    with _ocr_lock:
        if _ocr_engine is not None:
            return _ocr_engine
        try:
            from paddleocr import PaddleOCR
        except ImportError as error:
            logger.exception("PaddleOCR import failed")
            raise MenuScanError("PaddleOCR is unavailable on the backend.") from error
        _ocr_engine = PaddleOCR(
            use_doc_orientation_classify=False,
            use_doc_unwarping=False,
            use_textline_orientation=False,
        )
        return _ocr_engine


def _run_ocr(path: str) -> Any:
    engine = _get_ocr_engine()
    if hasattr(engine, "predict"):
        try:
            return engine.predict(input=path)
        except TypeError:
            return engine.predict(path)
    return engine.ocr(path, cls=False)


def _collect_text(value: Any) -> list[str]:
    if value is None:
        return []
    if hasattr(value, "json"):
        try:
            return _collect_text(value.json)
        except Exception:
            pass
    if isinstance(value, dict):
        for key in ("rec_texts", "texts"):
            raw = value.get(key)
            if isinstance(raw, list):
                return [str(item).strip() for item in raw if str(item).strip()]
        for key in ("rec_text", "text"):
            raw = value.get(key)
            if isinstance(raw, str) and raw.strip():
                return [raw.strip()]
        collected: list[str] = []
        for nested in value.values():
            collected.extend(_collect_text(nested))
        return collected
    if isinstance(value, (list, tuple)):
        if (
            len(value) >= 2
            and isinstance(value[1], (list, tuple))
            and value[1]
            and isinstance(value[1][0], str)
        ):
            return [value[1][0].strip()] if value[1][0].strip() else []
        collected: list[str] = []
        for nested in value:
            collected.extend(_collect_text(nested))
        return collected
    return []


def _suffix_for_content_type(content_type: str) -> str:
    if "png" in content_type:
        return ".png"
    if "webp" in content_type:
        return ".webp"
    return ".jpg"


def _extract_page_text(image_bytes: bytes, content_type: str) -> str:
    handle = tempfile.NamedTemporaryFile(delete=False, suffix=_suffix_for_content_type(content_type))
    try:
        with handle:
            handle.write(image_bytes)
        texts = _collect_text(_run_ocr(handle.name))
        return "\n".join(texts).strip()
    finally:
        try:
            os.unlink(handle.name)
        except FileNotFoundError:
            pass


async def extract_menu_page_texts(pages: list[tuple[bytes, str]]) -> list[str]:
    return await asyncio.gather(
        *[
            asyncio.to_thread(_extract_page_text, image_bytes, content_type)
            for image_bytes, content_type in pages
        ]
    )
