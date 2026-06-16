# Order Migration Guide

## Overview

This system migrates orders from an old POS (restrogreen.quicklyservices.com) into the
QuickBytes backend DB. The pipeline has two stages:

1. **Fetch** — scrape HTML order pages from the old POS into a CSV file.
2. **Migrate** — read the CSV, match each line item to existing `menu_items`, and insert
   into the `orders` table.

> **Important:** Serial numbers now **reset daily** per outlet. Each day's orders
> start at `#1`. See [Daily Serial Reset](#daily-serial-reset) below.

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

## Daily Serial Reset

Serial numbers are **per-outlet, per-day**. Each day's first order gets `serial_number = 1`,
the second gets `2`, and so on. This is enforced in three places:

| Layer | How it works |
|---|---|
| **Backend `POST /outlets/{id}/orders`** | Computes `MAX(serial_number) + 1 WHERE outlet_id=? AND order_date=today` server-side |
| **Backend `POST /customer/{id}/orders`** | Same server-side daily `MAX + 1` logic |
| **Admin app (offline POS)** | `_nextOrderSequence()` queries `MAX(sequenceNo) + 1 WHERE orderDate = today` from local SQLite |
| **Migration script** | Groups CSV rows by date and assigns `#1, #2, #3...` per day |

The `order_date` column (DATE) scopes the sequence. Existing rows backfilled via
`UPDATE orders SET order_date = created_at::date WHERE order_date IS NULL`.

### Collision safety

- Backend is **authoritative** — even if the admin app sends a client-computed serial,
  the backend recalculates and returns the correct daily value during sync.
- UUID `id` remains the globally unique tracking key.

---

#### `orders`
|---|---|---|
| `id` | VARCHAR PK | UUID generated at insert |
| `outlet_id` | VARCHAR FK | Target outlet UUID |
| `serial_number` | INTEGER | Per-day serial (resets to 1 each day) |
| `order_date` | DATE | Date scoping the serial (e.g. `2026-06-15`), derived from `created_at` |
| `source` | VARCHAR | Set to `"manual"` for migrated rows |
| `status` | VARCHAR | `completed` or `rejected` (mapped from CSV) |
| `total_amount` | NUMERIC(10,2) | From CSV `total` column |
| `subtotal` | NUMERIC(10,2) | Sum of line-item prices |
| `service_type` | VARCHAR | `dine_in`, `delivery`, `parcel` |
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

Before inserting, the script clears all existing orders for the outlet
(`DELETE FROM orders WHERE outlet_id = ?`), so each run is a clean re-import.
Serial numbers are assigned sequentially per-day starting from `1`.

If you need to **append** without clearing, the script pre-seeds `day_serials` from
existing rows via `SELECT order_date, MAX(serial_number) FROM orders GROUP BY order_date`,
so new orders continue from the last serial of each day.

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

### Verified Output (June 2026 run — with daily serial reset)

```
Total CSV rows:      16768
Inserted:            16616 (daily serials #1..N per order_date)
Skipped (duplicate):  152

Completed: 16680 | Rejected: 74 (mapped from CSV "Deleted")
Others-category items: 25 unmatched names
```

## Troubleshooting

| Problem | Fix |
|---|---|
| Cookies expired | Open old POS in browser → DevTools → copy fresh Cookie header into `fetch_orders.py` |
| `asyncpg` not found | `pip install asyncpg` or use the `.venv` at `/var/www/rastarant/backend/.venv/bin/python` |
| Orders already exist in DB | The duplicate-skip handles this; re-running is safe |
| Item name not matching | Add the name to the `menu_items` table, or it will land in `"Others"` |
