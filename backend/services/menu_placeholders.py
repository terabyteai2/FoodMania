"""Resolve a menu-item placeholder image URL from a category-style icon key.

The LLM picks an iconKey from ``ICON_KEY_VOCAB``; this module maps each key
to one or more 512x512 PNG files shipped under ``uploads/menu_placeholders/``.
When a bucket has multiple files, items are assigned deterministically by
their index in the scan (round-robin) so the same scan yields the same
images across re-runs.
"""
from __future__ import annotations


# Buckets are drawn from the canonical placeholder set in
# ``uploads/menu_placeholders/`` (see menu_items.txt). Keep this list narrow:
# every key MUST have at least one file on disk.
ICON_KEY_TO_FILES: dict[str, list[str]] = {
    "beef": ["beef-1.png", "beef-2.png", "beef-3.png", "beef-4.png"],
    "chicken": [
        "chicken-1.png",
        "chicken-2.png",
        "chicken-4.png",
        "chicken_fry.png",
        "fried-chicken.png",
    ],
    "fish": ["fish-1.png", "fish-2.png", "fish-3.png", "fish-4.png"],
    "mutton": ["mutton-1.png", "mutton-2.png", "mutton-3.png", "mutton-4.png"],
    "biryani": ["biryani-1.png", "biryani-2.png", "biryani-3.png", "biryani-4.png"],
    "burger": ["burger.png"],
    "kebab": ["kebab.png"],
    "fuchka": ["fuchka.png"],
    "noodles": ["noodles.png"],
    "soup": ["soup.png"],
    "vegetable": ["vegetable-1.png"],
    "sweets": ["sweets.png"],
    "tea_coffee": ["tea_and_coffee.png"],
    "beverages": ["beverages.png"],
    "soft_drink": ["soft-drink.png"],
    "water": ["water.png"],
    "general": ["beverages.png"],
}

ICON_KEY_VOCAB: list[str] = list(ICON_KEY_TO_FILES.keys())

_PLACEHOLDER_PREFIX = "menu_placeholders"


def normalize_icon_key(raw: str | None) -> str:
    key = (raw or "").strip().lower().replace("-", "_").replace(" ", "_")
    if key in ICON_KEY_TO_FILES:
        return key
    # Tolerate a few common LLM aliases.
    aliases = {
        "drink": "beverages",
        "drinks": "beverages",
        "juice": "beverages",
        "softdrink": "soft_drink",
        "tea": "tea_coffee",
        "coffee": "tea_coffee",
        "noodle": "noodles",
        "veg": "vegetable",
        "vegetables": "vegetable",
        "dessert": "sweets",
        "desserts": "sweets",
        "snack": "fuchka",
        "snacks": "fuchka",
    }
    return aliases.get(key, "general")


def placeholder_relative_path(icon_key: str, item_index: int) -> str:
    """Return the relative path under ``uploads/`` for the picked placeholder."""
    key = normalize_icon_key(icon_key)
    files = ICON_KEY_TO_FILES[key]
    chosen = files[item_index % len(files)]
    return f"{_PLACEHOLDER_PREFIX}/{chosen}"


def resolve_placeholder_url(icon_key: str, item_index: int, request) -> str:
    """Build a publicly-reachable URL for the placeholder file."""
    rel = placeholder_relative_path(icon_key, item_index)
    base = str(request.base_url).rstrip("/")
    return f"{base}/uploads/{rel}"
