#!/usr/bin/env python3
"""Seed menu from xlsx + re-import orders from CSV.

Usage:
  cd backend && python3 migrate_orders.py

Requires DATABASE_URL in .env or as env var.
"""

import asyncio
import csv
import json
import os
import re
import uuid
from collections import defaultdict
from datetime import datetime, timezone

import openpyxl
import asyncpg


OUTLET_ID = "1dd7dfb1-0fd1-411a-8bf7-84f10510ba76"
ACCOUNT_ID = "20ef16a1-9f0d-4341-bffc-6a7d55061563"
ACCOUNT_ROLE = "owner"
BASE_DIR = os.path.dirname(__file__)
XLSX_PATH = os.path.join(BASE_DIR, "..", "orders", "category-dish-export.xlsx")
CSV_PATH = os.path.join(BASE_DIR, "..", "orders", "orders.csv")
PLACEHOLDER_BASE = "https://quickbytes.buzz/uploads/menu_placeholders"

# ── Category -> placeholder icon mapping ──────────────────────────────────────
CATEGORY_PLACEHOLDERS: dict[str, str] = {
    "Meat Box": "beef-1.png",
    "Pizza Offer": "grill.png",
    "Add Ons": None,
    "Iftar Platter": "biryani-1.png",
    "Fusion Seat Meal": "chicken-1.png",
    "Combo Package": "grill.png",
    "Beverage": "beverages.png",
    "Pasta": "pasta.png",
    "Appetizer": "appetizer.png",
    "Gourmet Pizza": "grill.png",
    "Regular Pizza": "grill.png",
}

DISH_PLACEHOLDER_OVERRIDES: dict[str, str] = {
    "Fresh Water": "water.png",
    "Soft Drinks": "soft-drink.png",
    "Chocolate Cold Coffee": "tea_and_coffee.png",
    "Hot Coffee": "tea_and_coffee.png",
    "Mint Lemonade": "juice.png",
    "Chocolate Milk Shake": "juice.png",
    "Vanilla Shake": "juice.png",
    "French Fry": "appetizer.png",
    "French fry+ Lolipop": "appetizer.png",
    "Potato Masala Wedges": "appetizer.png",
    "Chicken Pop": "chicken-2.png",
    "Chicken Lolipop 6pc": "chicken-2.png",
    "Chicken Shawarma": "chicken-2.png",
    "Chicken Wrap": "chicken-2.png",
    "Chicken Nuggets 6pc": "chicken-2.png",
    "Chicken Cheese Finger 6pc": "chicken-2.png",
    "Tender Chicken 6pc": "chicken-2.png",
    "Fried Chicken 4pc": "fried-chicken.png",
    "Crispy Chicken 2pc": "fried-chicken.png",
    "Crispy Chicken Chap": "fried-chicken.png",
    "Chicken Chowmein 1:2": "noodles.png",
    "Cheesy Chicken Nachos": "appetizer.png",
    "French fry with cheese": "appetizer.png",
    "Sautéed Mushroom": "vegetable-1.png",
    "B.B.Q Meat Box": "beef-1.png",
    "Naga Meat Box": "beef-1.png",
    "Classic Meat Box": "beef-1.png",
    "BBQ Rice Bowl": "chicken-1.png",
    "Cheesy Rice Bowl": "chicken-1.png",
    "Lolipop Rice Bowl": "chicken-1.png",
    "Crispy Rice Bowl": "chicken-1.png",
    "Sausage Rice Bowl": "chicken-1.png",
    "Chicken Chili Rice Bowl": "chicken-1.png",
    "Chicken onion Platter": "chicken-4.png",
    "Crispy Chicken Platter": "chicken-4.png",
    "Thai Fried Platter": "chicken-4.png",
    "Garlic Mayonnaise": None,
    "Extra Cheese": None,
    "Black Olives": None,
    "Extra Rice": None,
    "Packaging Charge": None,
    "Chicken Pepperoni": None,
    "Capcicum": None,
    "Sausage": None,
    "Mushroom": None,
}


# ── Size variant prices for pizzas (from CSV analysis) ────────────────────────
PIZZA_SIZE_PRICES: dict[str, dict[str, float]] = {
    "BBQ Chicken": {"Small": 199, "Medium": 299, "Large": 399},
    "Chicken Sausage": {"Small": 189, "Medium": 289, "Large": 389},
    "Pizza Italian": {"Small": 225, "Medium": 325, "Large": 425},
    "Naga Spicy Chicken": {"Small": 200, "Medium": 300},
    "Naga Spicy Beef": {"Small": 200, "Medium": 300, "Large": 400},
    "Mexican Hot": {"Medium": 295, "Large": 395},
    "Delicious Pepperoni": {"Medium": 309, "Large": 409},
    "Two Flavour Mixed": {"Small": 200, "Medium": 300, "Large": 400},
    "All in one Chicken": {"Medium": 355, "Large": 455},
    "Sausage Fantasy": {"Medium": 365, "Large": 465},
    "Corridor Special Pizza": {"Large": 595},
    "Double Cheese Pizza": {"Medium": 325},
    "Onion Star": {"Medium": 335},
    "Pizza Blast": {"12\"": 399},
    "Calzone": {"6 Slice": 470},
    "Classic Meatball Pizza": {"12\"": 665},
    "Prawn Freak": {"Medium": 350, "Large": 450},
    "Richest Cheese Pizza": {"Medium": 350, "Large": 450},
    "Beef Lovers": {"Medium": 350, "Large": 450},
    "Four Season": {"Medium": 350, "Large": 450},
}

# Simple items from CSV with derived prices (for orders, not menu)
SIMPLE_ITEM_PRICES: dict[str, float] = {
    "Fresh Water": 20, "Soft Drinks": 25, "Chocolate Cold Coffee": 80,
    "Hot Coffee": 70, "BBQ Rice Bowl": 120, "Cheesy Rice Bowl": 120,
    "Lolipop Rice Bowl": 100, "Crispy Rice Bowl": 120, "Regular Pasta": 200,
    "Red Chilli Pasta": 180, "Mixed Pasta": 230, "Sausage Pasta": 190,
    "B.B.Q Meat Box": 229, "Garlic Mayonnaise": 15, "Chicken Lolipop 6pc": 170,
    "Chicken Pop": 150, "French Fry": 120, "Extra Cheese": 50,
    "White Sauce Pasta": 200, "Corridor Special Pasta": 250,
    "Chocolate Milk Shake": 130, "Vanilla Shake": 120,
    "Cheesy Chicken Nachos": 190, "Arabian Combo": 260,
    "Chicken Chowmein 1:2": 180, "French fry+ Lolipop": 199,
    "Classic Meat Box": 219, "Mexican Hot": 295, "BBQ Rice Bowl": 120,
    "Potato Masala Wedges": 99, "Chicken Shawarma": 150,
    "Sausage Pasta": 190, "Mixed Pasta": 230,
}

# Items WITH explicit size+price in CSV — used just for order parsing
CSV_SIZE_PRICES: dict[str, dict[str, float]] = {
    "Two Flavour Mixed": {"Small": 200, "Medium": 300, "Large": 400},
    "BBQ Chicken": {"Small": 199, "Medium": 299, "Large": 399},
    "Chicken Sausage": {"Small": 189, "Medium": 289, "Large": 389},
    "Naga Spicy Chicken": {"Small": 200, "Medium": 300},
    "Pizza Italian": {"Small": 225, "Medium": 325, "Large": 425},
    "Mexican Hot": {"Medium": 295, "Large": 395},
    "All in one Chicken": {"Medium": 355, "Large": 455},
    "Delicious Pepperoni": {"Medium": 309, "Large": 409},
    "Sausage Fantasy": {"Medium": 365, "Large": 465},
    "Onion Star": {"Medium": 335},
    "Double Cheese Pizza": {"Medium": 325},
    "Corridor Special Pizza": {"Large": 595},
    "Classic Meatball Pizza": {"12\"": 665},
    "Pizza Blast": {"12\"": 399},
    "Calzone": {"6 Slice": 470},
    "Chicken Shawarma": {"Small": 195},
    "Potato Masala Wedges": {"Large": 399},
    "BBQ &amp; Sausage Combo Offer 12\"": {"Small": 199},
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def get_placeholder(dish_name: str, category: str) -> str | None:
    icon = DISH_PLACEHOLDER_OVERRIDES.get(dish_name)
    if icon is None and dish_name in DISH_PLACEHOLDER_OVERRIDES:
        return None  # explicitly None (e.g. add-ons)
    if icon:
        return f"{PLACEHOLDER_BASE}/{icon}"
    cat_icon = CATEGORY_PLACEHOLDERS.get(category)
    if cat_icon:
        return f"{PLACEHOLDER_BASE}/{cat_icon}"
    return None


def parse_datetime(dt_str: str) -> datetime:
    dt_str = dt_str.strip()
    for fmt in ("%d-%m-%Y %I:%M:%S %p", "%d-%m-%Y %H:%M:%S"):
        try:
            return datetime.strptime(dt_str, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return datetime.now(timezone.utc)


def parse_items(items_str: str) -> list[dict]:
    parts = [p.strip() for p in items_str.split("|")]
    result = []
    for part in parts:
        if not part:
            continue

        m = re.match(
            r'^(.+?)\s*\(qty:\s*(\d+)\)\s*\+\s*(.+?)\s*\([\u09F3\$]?([\d,]+\.?\d*)\)\s*$',
            part,
        )
        if m:
            name = m.group(1).strip()
            qty = int(m.group(2))
            size = m.group(3).strip()
            price = float(m.group(4).replace(",", ""))
            full_name = f"{name} ({size})"
            result.append({
                "name": full_name, "nameEn": full_name, "nameBn": "",
                "qty": qty, "price": price,
                "baseName": name, "size": size,
            })
            continue

        m2 = re.match(r'^(.+?)\s*\(qty:\s*(\d+)\)\s*$', part)
        if m2:
            name = m2.group(1).strip()
            qty = int(m2.group(2))
            m3 = re.search(r'\([\u09F3\$]([\d,]+\.?\d*)\)', part)
            if m3:
                price = float(m3.group(1).replace(",", ""))
                result.append({
                    "name": name, "nameEn": name, "nameBn": "",
                    "qty": qty, "price": price,
                    "baseName": name, "size": None,
                })
                continue

            # Check CSV-derived prices for known items
            price = SIMPLE_ITEM_PRICES.get(name, 0)
            if name in CSV_SIZE_PRICES:
                price = min(CSV_SIZE_PRICES[name].values())
            result.append({
                "name": name, "nameEn": name, "nameBn": "",
                "qty": qty, "price": price,
                "baseName": name, "size": None,
            })
            continue

        m4 = re.match(r'^(.+?)\s*\(qty:\s*(\d+)\)', part)
        if m4:
            name = m4.group(1).strip()
            qty = int(m4.group(2))
            price = SIMPLE_ITEM_PRICES.get(name, 0)
            result.append({
                "name": name, "nameEn": name, "nameBn": "",
                "qty": qty, "price": price,
                "baseName": name, "size": None,
            })

    return result


def normalize_items(items: list[dict], total: float, discount: float) -> list[dict]:
    if not items or not any(it["price"] > 0 for it in items):
        return items
    known_sum = sum(it["price"] * it["qty"] for it in items if it["price"] > 0)
    target = total + discount
    if known_sum <= 0 or abs(known_sum - target) < 0.5:
        for it in items:
            it["lineTotal"] = round(it["price"] * it["qty"], 2)
        return items
    ratio = target / known_sum
    for it in items:
        if it["price"] > 0:
            it["price"] = round(it["price"] * ratio, 2)
    for it in items:
        it["lineTotal"] = round(it["price"] * it["qty"], 2)
    return items


# ── Main migration ───────────────────────────────────────────────────────────

async def migrate():
    dsn = os.environ.get("DATABASE_URL") or _load_dsn()
    if not dsn:
        print("ERROR: No DATABASE_URL found.")
        return

    conn = await asyncpg.connect(dsn)
    try:
        await _verify_outlet(conn)
        await _delete_existing_data(conn)
        menu_item_ids = await _seed_menu_from_xlsx(conn)
        await _import_orders(conn, menu_item_ids)
        await _verify(conn)
    finally:
        await conn.close()
    print("\nMigration complete!")


async def _verify_outlet(conn):
    row = await conn.fetchrow("SELECT id, name FROM outlets WHERE id=$1", OUTLET_ID)
    assert row, f"Outlet {OUTLET_ID} not found!"
    print(f"Outlet: {row['name']}")
    row = await conn.fetchrow("SELECT display_name FROM admin_accounts WHERE id=$1", ACCOUNT_ID)
    assert row, f"Account {ACCOUNT_ID} not found!"
    print(f"Account: {row['display_name']}")


async def _delete_existing_data(conn):
    print("\nClearing existing data...")
    for table in ("pos_audit_events", "pos_settlements", "orders", "menu_items"):
        r = await conn.execute(f"DELETE FROM {table} WHERE outlet_id=$1", OUTLET_ID)
        print(f"  Cleared {table}")
    print("  ✓")


async def _seed_menu_from_xlsx(conn) -> dict[str, str]:
    """Seed menu from xlsx. Returns dict of dish_name -> menu_item_id."""
    wb = openpyxl.load_workbook(XLSX_PATH, read_only=True, data_only=True)
    ws = wb["Worksheet"]

    menu_ids: dict[str, str] = {}
    rows = list(ws.iter_rows(values_only=True))
    header = rows[0]
    data_rows = rows[1:]

    print(f"\nSeeding {len(data_rows)} menu items from xlsx...")

    for row in data_rows:
        cat, name, price_str, cost_str, desc = (
            str(v).strip() if v else "" for v in row
        )
        try:
            price_val = float(price_str) if price_str and float(price_str) > 0 else 0
        except (ValueError, TypeError):
            price_val = 0

        mid = str(uuid.uuid4())

        # Determine price and tags
        if price_val > 0:
            # Flat-price item
            base_price = price_val
            tags: list[str] = []
        elif name in PIZZA_SIZE_PRICES:
            sizes = PIZZA_SIZE_PRICES[name]
            base_price = min(sizes.values())
            tags = []
            for size_label, sp in sorted(sizes.items(), key=lambda x: x[1]):
                delta = round(sp - base_price, 2)
                tags.append(f"option:{size_label}:{delta}")
        else:
            # Unknown pizza item — set base 0 (no orders reference it anyway)
            base_price = 0
            tags = []

        # Placeholder image
        img_url = get_placeholder(name, cat)

        tags_json = json.dumps(tags) if tags else None
        name_en = name
        name_bn = ""
        cat_en = cat
        cat_bn = ""

        await conn.execute(
            """
            INSERT INTO menu_items
                (id, outlet_id, name, name_en, name_bn, price, category,
                 category_en, category_bn, is_available, tags_json, image_url,
                 version, updated_at)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,TRUE,$10,$11,1,NOW())
            """,
            mid, OUTLET_ID, name, name_en, name_bn, base_price,
            cat, cat_en, cat_bn, tags_json, img_url,
        )
        menu_ids[name] = mid

    # Add "BBQ & Sausage Combo Offer 12"" + Small as a separate product
    extra_mid = str(uuid.uuid4())
    await conn.execute(
        """
        INSERT INTO menu_items
            (id, outlet_id, name, name_en, name_bn, price, category,
             category_en, category_bn, is_available, tags_json, image_url,
             version, updated_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,TRUE,$10,$11,1,NOW())
        """,
        extra_mid, OUTLET_ID,
        "BBQ & Sausage Combo Offer 12\" (Small)", "BBQ & Sausage Combo Offer 12\" (Small)", "",
        199, "Pizza Offer", "Pizza Offer", "পিৎজা অফার",
        None, get_placeholder("BBQ & Sausage Combo Offer 12\"", "Pizza Offer"),
    )
    menu_ids["BBQ &amp; Sausage Combo Offer 12\" (Small)"] = extra_mid

    print(f"  Created {len(menu_ids)} menu items ✓")
    wb.close()
    return menu_ids


async def _import_orders(conn, menu_ids: dict[str, str]):
    """Import orders from CSV."""
    with open(CSV_PATH, "r") as f:
        csv_rows = list(csv.DictReader(f))

    existing_max = await conn.fetchval(
        "SELECT COALESCE(MAX(serial_number), 0) FROM orders WHERE outlet_id=$1",
        OUTLET_ID,
    )
    next_serial = existing_max + 1
    created = 0
    audit_events = 0

    print(f"\nImporting {len(csv_rows)} orders...")

    for row in csv_rows:
        order_no = int(row["order_no"])
        status_raw = row["status"].strip()
        dt = parse_datetime(row["datetime"])
        service_type_raw = row["service_type"].strip().lower()
        table_info = row.get("table_info", "").strip()

        discount_type = row.get("discount_type", "").strip() or None
        discount_str = row.get("discount_amount", "").strip().replace(",", "")
        discount_amt = float(discount_str) if discount_str else 0

        total_str = row["total"].strip().replace(",", "").replace('"', "")
        total = float(total_str)

        st_map = {"dine-in": "dine_in", "delivery": "delivery", "takeaway": "parcel"}
        service_type = st_map.get(service_type_raw, service_type_raw)
        status = "rejected" if status_raw == "Deleted" else "completed"

        parsed = parse_items(row["items"])
        parsed = normalize_items(parsed, total, discount_amt)

        items_json = []
        for it in parsed:
            # Try exact match, then try base name
            mid = menu_ids.get(it["baseName"], "")
            if not mid:
                mid = menu_ids.get(it["name"], "")
            if not mid:
                mid = ""
            line_total = it.get("lineTotal", round(it["price"] * it["qty"], 2))

            # Handle BBQ & Sausage Combo 12" + Small separately
            if it["baseName"] == "BBQ &amp; Sausage Combo Offer 12\"" and it.get("size") == "Small":
                mid = menu_ids.get("BBQ &amp; Sausage Combo Offer 12\" (Small)", "")

            items_json.append({
                "id": str(uuid.uuid4()),
                "menuItemId": mid,
                "name": it["name"],
                "nameEn": it["nameEn"],
                "nameBn": it["nameBn"],
                "qty": it["qty"],
                "price": round(it["price"], 2),
                "lineTotal": line_total,
                "costPriceSnapshot": None,
                "note": None,
                "kotBatchId": None,
                "kotSentAt": None,
            })

        subtotal = round(total + discount_amt, 2)
        table_no = None
        if table_info:
            tm = re.match(r"Table\s*(\d+)", table_info, re.I)
            if tm:
                table_no = tm.group(1)

        oid = str(uuid.uuid4())
        await conn.execute(
            """
            INSERT INTO orders
                (id, outlet_id, serial_number, source, status,
                 total_amount, subtotal, service_type, table_no, items,
                 created_by_account_id, created_by_role,
                 discount_label, discount_amount,
                 service_charge_rate_percent, service_charge_amount,
                 billing_snapshot, kot_batches, settled_at, created_at, updated_at)
            VALUES
                ($1,$2,$3,'manual',$4,
                 $5,$6,$7,$8,$9::jsonb,
                 $10,$11,
                 $12,$13,
                 0,0,
                 '{}'::jsonb,'[]'::jsonb,$14,$14,$14)
            """,
            oid, OUTLET_ID, next_serial, status,
            total, subtotal, service_type, table_no,
            json.dumps(items_json),
            ACCOUNT_ID, ACCOUNT_ROLE,
            discount_type, discount_amt,
            dt,
        )
        next_serial += 1
        created += 1

        # Audit event for rejected orders
        if status == "rejected":
            metadata = json.dumps({"source": "csv_migration", "orderNo": order_no})
            await conn.execute(
                """
                INSERT INTO pos_audit_events
                    (id, event_id, outlet_id, order_id, action, reason,
                     metadata_json, created_by_account_id, created_by_role, created_at)
                VALUES ($1,$2,$3,$4,'void',
                        'Order voided/cancelled in legacy system',
                        $5::jsonb,$6,$7,$8)
                """,
                str(uuid.uuid4()), str(uuid.uuid4()),
                OUTLET_ID, oid, metadata, ACCOUNT_ID, ACCOUNT_ROLE, dt,
            )
            audit_events += 1

    print(f"  Created {created} orders ✓")
    if audit_events:
        print(f"  Created {audit_events} audit events ✓")


async def _verify(conn):
    counts = await conn.fetch(
        """
        SELECT 'menu_items' AS tbl, COUNT(*)::int FROM menu_items WHERE outlet_id=$1
        UNION ALL SELECT 'orders', COUNT(*)::int FROM orders WHERE outlet_id=$1
        UNION ALL SELECT 'admin_accounts', COUNT(*)::int FROM admin_accounts WHERE outlet_id=$1
        UNION ALL SELECT 'audit_events', COUNT(*)::int FROM pos_audit_events WHERE outlet_id=$1
        """,
        OUTLET_ID,
    )
    print("\n=== VERIFICATION ===")
    for r in counts:
        print(f"  {r['tbl']}: {r['cnt']}")

    # Check for broken refs
    bad = await conn.fetchval(
        """
        SELECT COUNT(*) FROM orders o
        WHERE o.outlet_id=$1 AND EXISTS (
            SELECT 1 FROM jsonb_array_elements(o.items) AS item
            WHERE item->>'menuItemId' IS NOT NULL AND item->>'menuItemId' != ''
            AND NOT EXISTS (
                SELECT 1 FROM menu_items m WHERE m.id = item->>'menuItemId'
            )
        )
        """,
        OUTLET_ID,
    )
    if bad:
        print(f"  ⚠ {bad} orders have broken menu item references!")
    else:
        print(f"  ✓ All order item references are valid")


def _load_dsn() -> str | None:
    env_path = os.path.join(BASE_DIR, ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("DATABASE_URL="):
                    val = line.split("=", 1)[1].strip().strip("'\"")
                    for prefix in ("postgresql+asyncpg://", "postgresql+psycopg2://"):
                        val = val.replace(prefix, "postgresql://")
                    return val
    return None


if __name__ == "__main__":
    asyncio.run(migrate())
