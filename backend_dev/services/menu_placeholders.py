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
    "appetizer": ["appetizer.png"],
    "beef": ["beef-1.png", "beef-2.png", "beef-3.png", "beef-4.png"],
    "chicken": [
        "chicken-1.png",
        "chicken-2.png",
        "chicken-4.png",
        "chicken_fry.png",
        "fried-chicken.png",
    ],
    "dal": ["dal-1.png", "dal-2.png"],
    "fish": ["fish-1.png", "fish-2.png", "fish-3.png", "fish-4.png"],
    "mutton": ["mutton-1.png", "mutton-2.png", "mutton-3.png", "mutton-4.png"],
    "biryani": ["biryani-1.png", "biryani-2.png", "biryani-3.png", "biryani-4.png"],
    "burger": ["burger.png"],
    "kebab": ["kebab.png"],
    "grill": ["grill.png"],
    "fuchka": ["fuchka.png"],
    "noodles": ["noodles.png"],
    "pasta": ["pasta.png"],
    "soup": ["soup.png"],
    "vegetable": ["vegetable-1.png"],
    "sweets": ["sweets.png", "Desserts.png"],
    "tea_coffee": ["tea_and_coffee.png"],
    "beverages": ["beverages.png"],
    "juice": ["juice.png"],
    "sandwich": ["sandwitch.png"],
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
        "soda": "soft_drink",
        "sodas": "soft_drink",
        "tea": "tea_coffee",
        "coffee": "tea_coffee",
        "noodle": "noodles",
        "pasta_noodles": "noodles",
        "veg": "vegetable",
        "vegetables": "vegetable",
        "dessert": "sweets",
        "desserts": "sweets",
        "sweet": "sweets",
        "snack": "fuchka",
        "snacks": "fuchka",
        "starter": "appetizer",
        "starters": "appetizer",
        "appetizers": "appetizer",
        "sandwitch": "sandwich",
        "sandwiches": "sandwich",
        "daal": "dal",
        "lentil": "dal",
        "lentils": "dal",
        "grilled": "grill",
    }
    return aliases.get(key, "general")


def infer_icon_key(name: str | None = None, category: str | None = None) -> str:
    """Infer the closest placeholder bucket from item text.

    Manual menu items often have no ``icon:<key>`` metadata because the manager
    typed them in instead of importing from AI scan. Keep this heuristic in the
    backend so public APIs can still return the shipped placeholder pictures.
    """
    text = f"{name or ''} {category or ''}".lower()

    def has(*words: str) -> bool:
        return any(word in text for word in words)

    if has("burger"):
        return "burger"
    if has("sandwich", "sandwitch"):
        return "sandwich"
    if has("biryani", "biriyani", "kacchi", "tehari", "polao", "পোলাও", "বিরিয়ানি"):
        return "biryani"
    if has("rice", "fried rice", "ভাত"):
        return "biryani"
    if has("dal", "daal", "lentil", "ডাল"):
        return "dal"
    if has("grill", "grilled", "bbq", "barbecue"):
        return "grill"
    if has("kebab", "kabab", "কাবাব"):
        return "kebab"
    if has("soup"):
        return "soup"
    if has("salad", "veg", "vegetable", "সবজি"):
        return "vegetable"
    if has("noodle", "chowmein", "chow mein"):
        return "noodles"
    if has("pasta", "spaghetti", "macaroni"):
        return "pasta"
    if has("bread", "naan", "paratha", "roti", "রুটি", "পরোটা"):
        return "appetizer"
    if has("chicken", "চিকেন", "মুরগি"):
        return "chicken"
    if has("fish", "prawn", "shrimp", "rui", "ilish", "মাছ"):
        return "fish"
    if has("mutton", "খাসি"):
        return "mutton"
    if has("beef", "গরু"):
        return "beef"
    if has("snack", "samosa", "roll", "fries", "singara", "সমুচা"):
        return "appetizer"
    if has("fuchka", "ফুচকা"):
        return "fuchka"
    if has("juice"):
        return "juice"
    if has("dessert", "sweet", "cake", "firni", "ice cream", "মিষ্টি"):
        return "sweets"
    if has("water", "পানি"):
        return "water"
    if has("soft drink", "softdrink", "soda", "cola"):
        return "soft_drink"
    if has("drink", "soda", "lassi", "borhani", "beverage", "পানীয়"):
        return "beverages"
    if has("coffee", "tea", "cha", "চা"):
        return "tea_coffee"
    if has("breakfast", "omelet", "omelette"):
        return "appetizer"
    if has("set meal", "set_menu", "combo", "platter", "থালি"):
        return "biryani"
    return "general"


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
