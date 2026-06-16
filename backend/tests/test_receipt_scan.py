import json

import pytest

from services import receipt_scan


def test_receipt_scan_validation_normalizes_unit_and_computes_unit_price():
    category, items = receipt_scan._validated_items(
        json.dumps(
            {
                "category": "stock_in",
                "items": [
                    {
                        "nameEn": "Chicken",
                        "nameBn": "চিকেন",
                        "qty": 15,
                        "unit": "Kg",
                        "unitPriceBdt": 420,
                        "totalBdt": 6300,
                    },
                    {
                        "nameEn": "Onion",
                        "nameBn": "পেঁয়াজ",
                        "qty": 25,
                        "unit": "kg",
                        "unitPriceBdt": 0,
                        "totalBdt": 1500,
                    },
                    {
                        "nameEn": "Free Bag",
                        "nameBn": "ফ্রি ব্যাগ",
                        "qty": 1,
                        "unit": "pcs",
                        "unitPriceBdt": 0,
                        "totalBdt": 0,
                    },
                ],
            }
        )
    )

    assert category == "stock_in"
    names = [item.nameEn for item in items]
    assert names == ["Chicken", "Onion"]
    onion = items[1]
    assert onion.unit == "kg"
    assert onion.unitPriceBdt == pytest.approx(60.0)


def test_receipt_scan_count_zeroes_prices_keeps_zero_qty_and_matches_known_id():
    category, items = receipt_scan._validated_items(
        json.dumps(
            {
                "category": "count",
                "items": [
                    {
                        "nameEn": "Rice",
                        "nameBn": "চাল",
                        "qty": 12,
                        "unit": "kg",
                        "unitPriceBdt": 90,
                        "totalBdt": 1080,
                        "matchedInventoryItemId": "item-rice",
                    },
                    {
                        "nameEn": "Oil",
                        "nameBn": "তেল",
                        "qty": 0,
                        "unit": "ltr",
                        "unitPriceBdt": 0,
                        "totalBdt": 0,
                        "matchedInventoryItemId": "ghost-id",
                    },
                ],
            }
        ),
        known_ids={"item-rice", "item-oil"},
    )

    assert category == "count"
    assert [item.nameEn for item in items] == ["Rice", "Oil"]
    rice, oil = items
    # Count rows never carry prices, even if the model emitted them.
    assert rice.unitPriceBdt == 0
    assert rice.totalBdt == 0
    assert rice.matchedInventoryItemId == "item-rice"
    # Zero quantity is valid for a count; a hallucinated id is dropped.
    assert oil.qty == 0
    assert oil.matchedInventoryItemId is None


def test_receipt_scan_explicit_category_overrides_llm():
    category, items = receipt_scan._validated_items(
        json.dumps(
            {
                "category": "stock_in",
                "items": [
                    {
                        "nameEn": "Sugar",
                        "nameBn": "চিনি",
                        "qty": 5,
                        "unit": "kg",
                        "unitPriceBdt": 0,
                        "totalBdt": 0,
                    }
                ],
            }
        ),
        category="count",
    )

    assert category == "count"
    assert items[0].totalBdt == 0


def test_receipt_scan_prompt_excludes_subtotals_and_keeps_bilingual_fields():
    messages = receipt_scan._prompt(
        [
            "Razzak Vai\nDhaka\nChicken 15kg 6300\nOnion 25kg 1500\nVAT 50\nTotal 7850",
            "ফ্রি ডেলিভারি",
        ]
    )
    joined = "\n".join(message["content"] for message in messages)

    assert "Return JSON only" in joined
    assert "nameEn, nameBn" in joined
    assert "nameBn must be Bengali script" in joined
    assert "sub-totals, taxes, discounts" in joined
    assert "kg, gm, ltr, ml, pcs, pack, dozen" in joined


def test_receipt_scan_prompt_describes_three_way_category_when_auto():
    auto = "\n".join(m["content"] for m in receipt_scan._prompt(["Chicken 15kg 6300"]))
    assert "Classify the document yourself" in auto
    assert '"stock_in"' in auto
    assert '"count"' in auto

    forced = "\n".join(
        m["content"]
        for m in receipt_scan._prompt(["Rice 12 kg"], category="count")
    )
    assert "stock-count / end-of-day count sheet" in forced


def test_receipt_scan_prompt_lists_known_items_for_matching():
    messages = receipt_scan._prompt(
        ["Rice 12"],
        category="count",
        known_items=[{"id": "item-rice", "name": "Rice", "unit": "kg"}],
    )
    joined = "\n".join(message["content"] for message in messages)
    assert "KNOWN INVENTORY ITEMS" in joined
    assert "item-rice : Rice : kg" in joined


def test_receipt_scan_normalize_unit_accepts_aliases():
    assert receipt_scan._normalize_unit("Kg") == "kg"
    assert receipt_scan._normalize_unit("grams") == "gm"
    assert receipt_scan._normalize_unit("Litre") == "ltr"
    assert receipt_scan._normalize_unit("pcs") == "pcs"
    assert receipt_scan._normalize_unit("packet") == "pcs"  # not in alias map → pcs default
    assert receipt_scan._normalize_unit("pack") == "pack"
    assert receipt_scan._normalize_unit("") == "pcs"


def test_receipt_scan_uses_json_object_mode_for_groq():
    groq = next(provider for provider in receipt_scan._providers() if provider.name == "groq")

    payload = receipt_scan._request_payload(groq, ["Chicken 15kg 6300"])

    assert payload["response_format"] == {"type": "json_object"}
    assert payload["reasoning_format"] == "hidden"
    assert payload["reasoning_effort"] == "low"
