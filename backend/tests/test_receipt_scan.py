import json

import pytest

from services import receipt_scan


def test_receipt_scan_validation_normalizes_unit_and_computes_unit_price():
    items = receipt_scan._validated_items(
        json.dumps(
            {
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
                ]
            }
        )
    )

    names = [item.nameEn for item in items]
    assert names == ["Chicken", "Onion"]
    onion = items[1]
    assert onion.unit == "kg"
    assert onion.unitPriceBdt == pytest.approx(60.0)


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
    assert "sub-totals, taxes, discounts" in joined
    assert "kg, gm, ltr, ml, pcs, pack, dozen" in joined


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
