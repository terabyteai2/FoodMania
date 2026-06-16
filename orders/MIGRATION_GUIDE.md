# Order Migration Guide

## Overview

This system migrates orders from an old POS (restrogreen.quicklyservices.com) into the
QuickBytes backend DB. The pipeline has two stages:

1. **Fetch** — scrape HTML order pages from the old POS into a CSV file.
2. **Migrate** — read the CSV, match each line item to existing `menu_items`, and insert
   into the `orders` table.

---

## Stage 1 — Fetch (`fetch_orders.py`)

**What it does:** Paginates through the old POS order list, parses HTML tables, and writes
`orders.csv`.

### Source API

| Detail | Value |
|---|---|
| Base URL | `https://restrogreen.quicklyservices.com/sales/order?page={}&paymentModeId=0&appUserId=0&orderStatusId=&serviceType=&discountType=&search_text=&startDate=DD%2FMM%2FYYYY&endDate=DD%2FMM%2FYYYY&shiftIds=&terminalIds=&outletId=0&selectedDeliveryService=` |
| Auth | Two session cookies: `XSRF-TOKEN` + `restaurant_session` (from browser devtools after logging into the old POS). |
| Date format | URL-encoded `DD%2FMM%2FYYYY` (e.g. `01%2F01%2F2023` for 1 Jan 2023). |
| Pagination | Loop page=1 upward; stop when a page returns zero orders. |

### Output: `orders.csv`

| Column | Description |
|---|---|
| `order_no` | Serial number (integer) |
| `status` | `Completed` or `Deleted` |
| `datetime` | `DD-MM-YYYY HH:MM:SS AM/PM` |
| `outlet` | Always `"Default Outlet"` |
| `service_type` | `Dine-in`, `Delivery`, or `Takeaway` |
| `service_number` | `# N` (internal POS counter) |
| `table_info` | e.g. `"Table 3"` or empty |
| `items` | Pipe-separated line items. Format:`Name (qty: N) [+ Variant (৳price)]`Example: `BBQ Chicken (qty: 1) + Large (৳399.00) \| Soft Drinks (qty: 3)` |
| `discount_type` | `Staff Discount` or empty |
| `discount_amount` | Numeric string with commas, or empty |
| `total` | Numeric string with commas (e.g. `"1,168.00"`) |

### Usage

```bash
python3 fetch_orders.py
```

- **Cookies expire** after ~30 days. Replace them in `HEADERS["Cookie"]` by copying from
  browser devtools → Network → any request to the old POS → Request Headers → Cookie.
- Change `startDate` / `endDate` in `BASE_URL` to set the date range.

---

## Stage 2 — Migrate (`migrate_orders.py`)

**What it does:** Reads `orders.csv`, matches each line item to a `menu_items` row in the
backend DB by name, and inserts into the `orders` table.

### Target Database

PostgreSQL on the VPS (localhost-only):

| Param | Value |
|---|---|
| Host | `127.0.0.1` |
| Port | `5432` |
| Database | `rastarant` |
| User | `rastarant_user` |
| Password | `O6h51j7Huv5rCEjHAlEOyS8AqEK1Us68` |

### Key Tables

#### `orders`

| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR PK | UUID generated at insert |
| `outlet_id` | VARCHAR FK | Target outlet UUID |
| `serial_number` | INTEGER | From `order_no` in CSV |
| `source` | VARCHAR | Set to `"imported"` for migrated rows |
| `status` | VARCHAR | `completed` or `deleted` (mapped from CSV) |
| `total_amount` | NUMERIC(10,2) | From CSV `total` column |
| `subtotal` | NUMERIC(10,2) | Sum of line-item prices |
| `service_type` | VARCHAR | `dine_in`, `delivery`, `takeaway` |
| `table_no` | VARCHAR | From CSV `table_info` |
| `items` | JSONB | Array of line-item objects (see below) |
| `discount_label` | VARCHAR | e.g. `"Staff Discount"` |
| `discount_amount` | NUMERIC(10,2) | |
| `created_at` | TIMESTAMPTZ | Parsed from CSV `datetime` |
| `updated_at` | TIMESTAMPTZ | Current timestamp at insert time |

#### `items` JSONB structure (per line item)

```json
{
  "menuItemId": "uuid-of-matched-menu-item-or-null",
  "name": "BBQ Chicken",
  "qty": 1,
  "price": 199.00,
  "lineTotal": 199.00,
  "category": "Regular Pizza"
}
```

- If the item name matches a `menu_items.name`, `menuItemId` and `category` are populated
  from the matched row.
- If the item name does NOT match any menu item, `menuItemId` is `null` and `category` is
  `"Others"`.

#### `menu_items` (reference for matching)

| Column | Type | Notes |
|---|---|---|
| `id` | VARCHAR PK | UUID |
| `outlet_id` | VARCHAR FK | Scoped to one outlet |
| `name` | TEXT | Matched case-insensitively against CSV item names |
| `category` | TEXT | e.g. `Regular Pizza`, `Appetizer`, `Beverage`, etc. |
| `price` | NUMERIC(10,2) | Base price |
| `is_available` | BOOLEAN | |
| `deleted_at` | TIMESTAMPTZ | Null means active |

### Name Matching Logic

1. Normalise CSV item name: `html.unescape()` (handles `&amp;` → `&`, `&quot;` → `"`).
2. Strip whitespace, lowercase.
3. Look up in a dict built from `menu_items` (keyed by `name.strip().lower()`).
4. Match → use that `menu_item.id` and `category`.
5. No match → category = `"Others"`, `menuItemId = null`.

**Unmatched items discovered during migration** (25 names):
`BBQ & Sausage Mixed 12"`, `BBQ Chicken 9"`, `BBQ Chicken Offer`, `BBQ Chicken Offer 6"`,
`BBQ Wings 5 Pcs`, `BBQ chicken Platter`, `Chicken Cheesy 6"`, `Chicken Sausage Offer`,
`Chicken Teriyaki Platter`, `Combo Offer`, `Delicious Student Platter`,
`Dhamaka Combo Offer`, `Drinks`, `Four flavour`, `Fried Chicken 6pcs`, `Hot Combo`,
`Meaty Onione`, `Mega Meal`, `Naga Wings Barrel 5Pcs`, `Pizza Pasta Combo Offer`,
`Sausage Carnival`, `Standard Meal`, `Student Meal`, `Two Flavour Offer`, `Winter Combo`

### Deduplication

Before inserting, the script checks `existing_serials` — a set of `serial_number` values
already present for the outlet. Any CSV row whose `order_no` is already in the DB is
skipped.

### Running

```bash
# Copy files to the VPS
scp orders.csv migrate_orders.py root@160.187.130.80:/tmp/

# SSH in and run
ssh root@160.187.130.80
/var/www/rastarant/backend/.venv/bin/python /tmp/migrate_orders.py
```

The script uses the backend's `.venv` Python which has `asyncpg` installed. It connects to
the local PostgreSQL instance and inserts orders one at a time (not batched — 16K orders
takes a few minutes).

### Verified Output (June 2026 run)

```
Total CSV rows:      16768
Inserted:            16616
Skipped (duplicate):  152

Completed: 16680 | Deleted: 74 | Others-category items: 25 unmatched names
```

## Troubleshooting

| Problem | Fix |
|---|---|
| Cookies expired | Open old POS in browser → DevTools → copy fresh Cookie header into `fetch_orders.py` |
| `asyncpg` not found | `pip install asyncpg` or use the `.venv` at `/var/www/rastarant/backend/.venv/bin/python` |
| Orders already exist in DB | The duplicate-skip handles this; re-running is safe |
| Item name not matching | Add the name to the `menu_items` table, or it will land in `"Others"` |
