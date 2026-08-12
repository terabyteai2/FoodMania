import asyncio
import json
import logging
from dataclasses import dataclass
from typing import Any

import httpx
from pydantic import ValidationError

from config import settings
from schemas import MenuAddOnCandidate, MenuScanCandidate, MenuSizeVariant, MenuSubItem
from services.menu_placeholders import ICON_KEY_VOCAB, normalize_icon_key


LLM_TIMEOUT_SECONDS = 90.0
OCR_TIMEOUT_SECONDS = 90.0
PROVIDER_ERROR_DETAIL_LIMIT = 800
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
            name="deepseek",
            api_key=settings.DEEPSEEK_API_KEY.strip(),
            model=settings.MENU_SCAN_DEEPSEEK_MODEL.strip(),
            url="https://api.deepseek.com/v1/chat/completions",
            supports_schema=False,
        ),
    ]


def _menu_scan_schema() -> dict[str, Any]:
    item = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "nameEn": {
                "type": "string",
                "description": "Item name in English.",
            },
            "nameBn": {
                "type": "string",
                "description": "Item name in Bangla.",
            },
            "descriptionEn": {
                "type": "string",
                "description": "Appetizing item description in English, about 40 words.",
            },
            "descriptionBn": {
                "type": "string",
                "description": "Appetizing item description in Bangla, about 40 words.",
            },
            "categoryEn": {
                "type": "string",
                "description": "Menu category in English.",
            },
            "categoryBn": {
                "type": "string",
                "description": "Menu category in Bangla.",
            },
            "price": {"type": "number", "description": "Positive numeric menu price only."},
            "isAvailable": {"type": "boolean"},
            "iconKey": {
                "type": "string",
                "enum": ICON_KEY_VOCAB,
                "description": (
                    "Single visual category key for a placeholder icon when no photo "
                    "is uploaded. Pick the closest match from the enum based on the "
                    "item name and category. Use 'general' if nothing fits."
                ),
            },
            "subItems": {
                "type": "array",
                "description": (
                    "Items included in a combo / set / platter (e.g. 'served with rice "
                    "and salad'). Empty when the item has no included extras."
                ),
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "nameEn": {"type": "string"},
                        "nameBn": {"type": "string"},
                    },
                    "required": ["nameEn", "nameBn"],
                },
            },
            "addOns": {
                "type": "array",
                "description": (
                    "Optional priced extras (e.g. 'add cheese +50', 'extra naan ৳20'). "
                    "Each add-on must have a positive numeric price. Empty when none."
                ),
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "nameEn": {"type": "string"},
                        "nameBn": {"type": "string"},
                        "price": {"type": "number", "exclusiveMinimum": 0},
                    },
                    "required": ["nameEn", "nameBn", "price"],
                },
            },
            "sizeVariants": {
                "type": "array",
                "description": (
                    "Pricing tiers when the same item is sold at multiple sizes or "
                    "portions with different prices (e.g. 'Half ৳180 / Full ৳350', "
                    "'Small / Large'). Each entry is one size with its own absolute "
                    "price. When sizeVariants is non-empty, set the item price to the "
                    "lowest variant price. Leave empty when the item has one standard "
                    "price."
                ),
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "nameEn": {"type": "string"},
                        "nameBn": {"type": "string"},
                        "price": {"type": "number", "exclusiveMinimum": 0},
                    },
                    "required": ["nameEn", "nameBn", "price"],
                },
            },
        },
        "required": [
            "nameEn",
            "nameBn",
            "descriptionEn",
            "descriptionBn",
            "categoryEn",
            "categoryBn",
            "price",
            "isAvailable",
            "iconKey",
            "subItems",
            "addOns",
            "sizeVariants",
        ],
    }
    return {
        "type": "object",
        "additionalProperties": False,
        "properties": {"items": {"type": "array", "items": item}},
        "required": ["items"],
    }


def _menu_scan_instructions() -> str:
    vocab = ", ".join(ICON_KEY_VOCAB)
    return (
        "Return JSON only. Extract restaurant menu items into the provided schema. "
        "The input contains OCR.space JSON for menu page photos. Read OCR text from "
        "ParsedResults[].ParsedText and use OCR JSON details only as supporting "
        "evidence. Menu pages may contain Bangla, English, restaurant names, logos, "
        "slogans, "
        "addresses, phone numbers, opening hours, social media, Wi-Fi text, VAT, "
        "tax, service charge, delivery notes, table text, and decorative copy; "
        "ignore anything that is not a sellable menu item with a price. Do not turn "
        "the restaurant name or section decorations into items. Each item must have "
        "a positive numeric price without currency symbols. Return English and "
        "Bangla in separate fields: nameEn, nameBn, descriptionEn, descriptionBn, "
        "categoryEn, and categoryBn. If one language is missing from the menu, "
        "translate or transliterate the missing side. If a category is missing, "
        "infer a useful category in both languages; use General and সাধারণ only "
        "when no better category is clear. If an item description is missing, "
        "write a polished, restaurant-salesy description in both languages, around "
        "40 words per language, based on the visible item name/category/price. "
        "Use isAvailable true. "
        "Also pick exactly one iconKey from this fixed enum so the backend can "
        f"assign a default placeholder photo when no real image is available: {vocab}. "
        "Pick the key that best matches the item's main ingredient or category "
        "(e.g. 'beef' for steaks, 'chicken' for grilled/fried chicken, 'fish' for "
        "seafood, 'biryani' for rice platters, 'sweets' for desserts, "
        "'tea_coffee' for hot drinks, 'juice' for fruit juices, 'beverages' for lassi, "
        "'soft_drink' for sodas, 'dal' for lentils, 'grill' for grilled platters, "
        "'pasta' for pasta, 'sandwich' for sandwiches, 'appetizer' for starters, "
        "'water' for bottled water). Use 'general' only "
        "as a last resort. "
        "For combo platters that 'come with' or 'are served with' other items, "
        "fill subItems with each included item ({nameEn, nameBn}); otherwise "
        "leave subItems empty. "
        "For optional priced extras printed near the item (e.g. 'add cheese +50', "
        "'extra naan ৳20'), fill addOns ({nameEn, nameBn, price}); otherwise "
        "leave addOns empty. Do not duplicate the main item inside subItems or addOns. "
        "If an item is listed at multiple sizes or portions with different prices "
        "(e.g. 'Half ৳180 / Full ৳350', 'Small/Large'), set price to the lowest "
        "variant price and fill sizeVariants with each size and its absolute price; "
        "otherwise leave sizeVariants empty."
    )


KNOWN_ITEMS_PROMPT_LIMIT = 300


def _prompt(
    page_texts: list[str], known_items: list[str] | None = None
) -> list[dict[str, str]]:
    pages = "\n\n".join(
        f"--- OCR.SPACE MENU PAGE {index + 1} JSON ---\n{text.strip()}"
        for index, text in enumerate(page_texts)
        if text.strip()
    )
    user_content = (
        "Parse these OCR.space JSON menu pages into JSON with an items array. "
        "Do not invent items that are not visible in the OCR result. Preserve "
        "the page order when practical and merge duplicate sightings of "
        "the same item.\n\n"
        f"{pages}"
    )
    known = _dedup_names(known_items or [])[:KNOWN_ITEMS_PROMPT_LIMIT]
    if known:
        user_content += (
            "\n\nThe following items have ALREADY been extracted from this "
            "menu in a previous pass and are already in the restaurant's menu:\n"
            + "\n".join(known)
            + "\nDo NOT include any of these already-known items in your items "
              "array, even if you see them again in the OCR text. Only output "
              "items that are NOT in the list above."
        )
    return [
        {
            "role": "system",
            "content": _menu_scan_instructions(),
        },
        {
            "role": "user",
            "content": user_content,
        },
    ]


def _response_format(provider: _Provider) -> dict[str, Any]:
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
    return response_format


def _request_payload(
    provider: _Provider, page_texts: list[str], known_item_names: list[str] | None = None
) -> dict[str, Any]:
    payload = {
        "model": provider.model,
        "temperature": 0,
        "messages": _prompt(page_texts, known_item_names),
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
        legacy_name_en, legacy_name_bn = _split_bilingual(raw.get("name"))
        legacy_description_en, legacy_description_bn = _split_bilingual(
            raw.get("description")
        )
        legacy_category_en, legacy_category_bn = _split_bilingual(raw.get("category"))
        icon_key = normalize_icon_key(raw.get("iconKey"))
        normalized = {
            "nameEn": str(raw.get("nameEn") or legacy_name_en).strip(),
            "nameBn": str(raw.get("nameBn") or legacy_name_bn).strip(),
            "descriptionEn": str(
                raw.get("descriptionEn") or legacy_description_en
            ).strip(),
            "descriptionBn": str(
                raw.get("descriptionBn") or legacy_description_bn
            ).strip(),
            "categoryEn": str(
                raw.get("categoryEn") or legacy_category_en or "General"
            ).strip()
            or "General",
            "categoryBn": str(
                raw.get("categoryBn") or legacy_category_bn or "সাধারণ"
            ).strip()
            or "সাধারণ",
            "price": raw.get("price"),
            "isAvailable": raw.get("isAvailable", True),
            "iconKey": icon_key,
            "subItems": _normalize_sub_items(raw.get("subItems")),
            "addOns": _normalize_add_ons(raw.get("addOns")),
            "sizeVariants": _normalize_size_variants(raw.get("sizeVariants")),
        }
        try:
            items.append(MenuScanCandidate.model_validate(normalized))
        except ValidationError:
            continue
    if not items:
        raise MenuScanError("The LLM returned no valid priced menu items.")
    return items


def _dedup_items(items: list[MenuScanCandidate]) -> list[MenuScanCandidate]:
    seen: set[str] = set()
    result: list[MenuScanCandidate] = []
    for item in items:
        key = item.nameEn.strip().lower()
        if key and key not in seen:
            seen.add(key)
            result.append(item)
    return result


def _dedup_names(names: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for name in names:
        key = name.strip().lower()
        if key and key not in seen:
            seen.add(key)
            result.append(name.strip())
    return result


def _split_bilingual(value: Any) -> tuple[str, str]:
    text = str(value or "").strip()
    if not text:
        return "", ""
    if "/" not in text:
        return text, ""
    left, right = text.split("/", 1)
    return left.strip(), right.strip()


def _normalize_sub_items(raw: Any) -> list[dict[str, str]]:
    if not isinstance(raw, list):
        return []
    out: list[dict[str, str]] = []
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        name_en = str(entry.get("nameEn") or "").strip()
        if not name_en:
            continue
        out.append(
            {
                "nameEn": name_en,
                "nameBn": str(entry.get("nameBn") or "").strip(),
            }
        )
    return out


def _normalize_add_ons(raw: Any) -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        return []
    out: list[dict[str, Any]] = []
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        name_en = str(entry.get("nameEn") or "").strip()
        if not name_en:
            continue
        try:
            price = float(entry.get("price") or 0)
        except (TypeError, ValueError):
            continue
        if price <= 0:
            continue
        out.append(
            {
                "nameEn": name_en,
                "nameBn": str(entry.get("nameBn") or "").strip(),
                "price": price,
            }
        )
    return out


def _normalize_size_variants(raw: Any) -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        return []
    out: list[dict[str, Any]] = []
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        name_en = str(entry.get("nameEn") or "").strip()
        if not name_en:
            continue
        try:
            price = float(entry.get("price") or 0)
        except (TypeError, ValueError):
            continue
        if price <= 0:
            continue
        out.append(
            {
                "nameEn": name_en,
                "nameBn": str(entry.get("nameBn") or "").strip(),
                "price": price,
            }
        )
    return out


async def parse_menu_text(
    page_texts: list[str], known_item_names: list[str] | None = None
) -> MenuScanParseResult:
    clean_pages = [text.strip() for text in page_texts if text.strip()]
    if not clean_pages:
        raise MenuScanError("OCR did not find readable menu text.")

    warnings: list[str] = []
    configured = [provider for provider in _providers() if provider.api_key and provider.model]
    if not configured:
        raise MenuScanError("Menu scan AI is not configured on the backend.")

    known_item_names = (
        _dedup_names(known_item_names)[:KNOWN_ITEMS_PROMPT_LIMIT] if known_item_names else []
    )

    async with httpx.AsyncClient(timeout=LLM_TIMEOUT_SECONDS) as client:
        for provider in configured:
            try:
                logger.info(
                    "menu scan llm request provider=%s model=%s url=%s pages=%s chars=%s",
                    provider.name,
                    provider.model,
                    provider.url,
                    len(clean_pages),
                    sum(len(p) for p in clean_pages),
                )
                response = await client.post(
                    provider.url,
                    headers={
                        "Authorization": f"Bearer {provider.api_key}",
                        "Content-Type": "application/json",
                    },
                    json=_request_payload(provider, clean_pages, known_item_names),
                )
                logger.info(
                    "menu scan llm response provider=%s status=%s",
                    provider.name,
                    response.status_code,
                )
                response.raise_for_status()
                decoded = response.json()
                raw_content = _message_content(decoded)
                logger.info(
                    "menu scan llm raw provider=%s content_chars=%s preview=%r",
                    provider.name,
                    len(raw_content),
                    raw_content[:300],
                )
                items = _validated_items(raw_content)
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
            except httpx.HTTPStatusError as error:
                logger.warning(
                    "menu scan llm provider rejected provider=%s status=%s detail=%s",
                    provider.name,
                    error.response.status_code,
                    _provider_error_detail(error.response),
                )
                logger.warning(
                    "menu scan llm provider failed provider=%s error=%s",
                    provider.name,
                    error,
                )
                warnings.append(f"{provider.name}: {error}")
            except (httpx.HTTPError, ValueError, MenuScanError) as error:
                logger.warning(
                    "menu scan llm provider failed provider=%s error=%s",
                    provider.name,
                    error,
                )
                warnings.append(f"{provider.name}: {error}")

    combined_detail = "; ".join(warnings) if warnings else "no providers tried"
    raise MenuScanError(f"All configured menu scan AI providers failed: {combined_detail}")


async def scan_image_once(
    image_bytes: bytes,
    content_type: str,
    known_item_names: list[str] | None = None,
) -> MenuScanParseResult:
    """Single OCR→LLM trip on one image. Results are returned immediately
    so the caller can broadcast them to the client as soon as each trip
    finishes. known_item_names lists items already extracted so later trips
    only hunt for items the previous passes missed."""
    page_texts = await extract_menu_page_texts([(image_bytes, content_type)])
    return await parse_menu_text(page_texts, known_item_names)


async def scan_single_image_with_dedup(
    image_bytes: bytes, content_type: str
) -> MenuScanParseResult:
    """Run 2 OCR→LLM trips on one image; trip 2 lists trip 1's items as
    already-known and only looks for misses, then defensive dedup runs."""
    page_texts_1 = await extract_menu_page_texts([(image_bytes, content_type)])
    result_1 = await parse_menu_text(page_texts_1)

    page_texts_2 = await extract_menu_page_texts([(image_bytes, content_type)])
    result_2 = await parse_menu_text(
        page_texts_2,
        [item.nameEn for item in result_1.items] or None,
    )

    combined = result_1.items + result_2.items
    deduped = _dedup_items(combined)

    warnings = list(result_1.warnings) + list(result_2.warnings)
    removed = len(combined) - len(deduped)
    if removed:
        warnings.append(
            f"Deduplication removed {removed} duplicate item(s) "
            f"across 2 scan passes."
        )

    return MenuScanParseResult(
        items=deduped,
        provider=result_1.provider,
        warnings=warnings,
    )


def _suffix_for_content_type(content_type: str) -> str:
    if "png" in content_type:
        return ".png"
    if "webp" in content_type:
        return ".webp"
    return ".jpg"


def _ocr_space_file_name(content_type: str) -> str:
    return f"menu-page{_suffix_for_content_type(content_type)}"


def _ocr_space_payload(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise MenuScanError("OCR.space returned invalid JSON.")
    if payload.get("IsErroredOnProcessing"):
        details = payload.get("ErrorMessage") or payload.get("ErrorDetails")
        raise MenuScanError(
            f"OCR.space could not read a menu page: {details or 'processing failed'}."
        )
    results = payload.get("ParsedResults")
    if not isinstance(results, list) or not results:
        raise MenuScanError("OCR.space returned no menu page results.")
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
        raise MenuScanError(
            f"OCR.space found no readable menu text: {details or 'page parse failed'}."
        )
    return payload


async def _extract_page_ocr_json(
    client: httpx.AsyncClient,
    image_bytes: bytes,
    content_type: str,
) -> str:
    api_key = settings.OCR_SPACE_API_KEY.strip()
    if not api_key:
        raise MenuScanError("OCR.space API key is not configured on the backend.")
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
        logger.info(
            "menu scan ocr ok content_type=%s status=%s chars=%s",
            content_type,
            response.status_code,
            len(json.dumps(payload, ensure_ascii=False)),
        )
    except httpx.HTTPStatusError as error:
        logger.warning(
            "OCR.space rejected content_type=%s status=%s detail=%s",
            content_type,
            error.response.status_code,
            _provider_error_detail(error.response),
        )
        raise MenuScanError("OCR.space request failed while reading a menu page.") from error
    except httpx.HTTPError as error:
        logger.warning(
            "OCR.space request failed content_type=%s error=%s",
            content_type,
            error,
        )
        raise MenuScanError("OCR.space request failed while reading a menu page.") from error
    except ValueError as error:
        raise MenuScanError("OCR.space did not return valid JSON.") from error
    return json.dumps(payload, ensure_ascii=False)


async def extract_menu_page_texts(pages: list[tuple[bytes, str]]) -> list[str]:
    async with httpx.AsyncClient(timeout=OCR_TIMEOUT_SECONDS) as client:
        results = await asyncio.gather(
            *[
                _extract_page_ocr_json(client, image_bytes, content_type)
                for image_bytes, content_type in pages
            ],
            return_exceptions=True,
        )

    # A single unreadable page (a cover photo, a blurry shot, a transient OCR
    # error) must not sink the whole multi-image scan. Keep every page that read
    # cleanly and only fail when nothing was readable.
    texts: list[str] = []
    first_error: BaseException | None = None
    for index, result in enumerate(results):
        if isinstance(result, BaseException):
            logger.warning(
                "menu scan ocr page failed page=%s of=%s error=%s",
                index + 1,
                len(results),
                result,
            )
            if first_error is None:
                first_error = result
            continue
        texts.append(result)

    logger.info(
        "menu scan ocr done pages=%s ok=%s of=%s",
        len(pages),
        len(texts),
        len(results),
    )
    if not texts:
        if first_error is not None:
            raise first_error
        raise MenuScanError("OCR.space found no readable menu text.")
    return texts
