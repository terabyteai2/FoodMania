import sys
import re
import csv
import urllib.request
import ssl

SSL_CTX = ssl.create_default_context()

BASE_URL = ("https://restrogreen.quicklyservices.com/sales/order?page={}&paymentModeId=0&appUserId=0"
            "&orderStatusId=&serviceType=&discountType=&search_text="
            "&startDate=16%2F06%2F2026&endDate=16%2F06%2F2026"
            "&shiftIds=&terminalIds=&outletId=0&selectedDeliveryService=")

HEADERS = {
    "Host": "restrogreen.quicklyservices.com",
    "User-Agent": "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:151.0) Gecko/20100101 Firefox/151.0",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://restrogreen.quicklyservices.com/sales/order",
    "Cookie": "XSRF-TOKEN=eyJpdiI6ImVNV1JSWmR6djZiMUZBcEtUaW4rQVE9PSIsInZhbHVlIjoiQ0xTRk02eTN2V3daNnRjdXhCNXdXNlNvTC8rdmYrMjN5WTRVTjNJTkd1QXpjajRXMU91eEZnaU9uN25sRkRnUGQ4YXh1bUtpcnljYjdTVjBLUTVZVEhqdWtWVDZLd3FIT2tHS1QrdUdIclp0SWFNUHFRZG9Od1pzNFYrM01sOTgiLCJtYWMiOiI1ZTM5OGMwNmNlODcyY2UyYmFmN2JiOTMyODFiYzRhYTY4YzU5OWRlODk5OTRhMTgxOTg4MjcxMDJjZjUwZmRlIiwidGFnIjoiIn0%3D; restaurant_session=eyJpdiI6InIvSHZqNWJEZ3c2MzdkRFV5b1pHd3c9PSIsInZhbHVlIjoiaDE5Ym1ZRGhtVVZqcHdnQlNraXVPdFBuaWVaU3YwWHQwM0FKak16VDhGUWVDYkdTOWUxMVQrdTlaUXNncnFxV2VNd05JSkdHVW81emZscTZybkJ0eHhFNGd6ODZUdEtVMzJOVUowTHRjVzNsVmp4NllJbzRUam5MUk44Tjh1SkwiLCJtYWMiOiJmNjI0YmMxYmJiY2ZhMDA1OWQxYzRmN2NiMzU0MzQwNWZmNGQ0YTFkMGQ3MDMwNmE2YzRiYWViZTAzNGUzNzZlIiwidGFnIjoiIn0%3D",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Fetch-User": "?1",
    "Priority": "u=0, i",
}


def fetch_page(page: int) -> str:
    url = BASE_URL.format(page)
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, context=SSL_CTX, timeout=30) as resp:
        return resp.read().decode("utf-8")


def clean(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def parse_orders(html: str) -> list[dict]:
    orders = []
    tbody_match = re.search(r"<tbody>(.*?)</tbody>", html, re.DOTALL)
    if not tbody_match:
        return orders
    tbody = tbody_match.group(1)

    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", tbody, re.DOTALL)
    for row in rows:
        tds = re.findall(r"<td[^>]*>(.*?)</td>", row, re.DOTALL)
        if len(tds) < 2:
            continue

        td0 = tds[0]
        td1 = tds[1]

        # --- Parse TD 0 (info) ---
        # Order number
        order_no_m = re.search(r"view_orders[^>]*>\s*(\d+)", td0)
        order_no = order_no_m.group(1) if order_no_m else ""

        # Status
        status_m = re.search(r'badge[^>]*>\s*(\w+)', td0)
        status = status_m.group(1) if status_m else ""

        # Date/time
        datetime_m = re.search(r"<small class=\"text-secondary\">(\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2} [AP]M)</small>", td0)
        datetime_str = datetime_m.group(1) if datetime_m else ""

        # Outlet
        outlet_m = re.search(r"theme-color[^>]*>\s*([^<]+)", td0)
        outlet = outlet_m.group(1).strip() if outlet_m else ""

        # Service type
        service_type_m = re.search(r"Dine-in|Delivery|Takeaway", td0)
        service_type = service_type_m.group(0) if service_type_m else ""

        # Service number
        service_no_m = re.search(r"#\s*(\d+)", td0)
        service_number = f"# {service_no_m.group(1)}" if service_no_m else ""

        # Sale date
        sale_date_m = re.search(r"Sale Date</small>\s*<small[^>]*>(\d{2}-\d{2}-\d{4})", td0)
        sale_date = sale_date_m.group(1) if sale_date_m else ""

        # Shift & Terminal
        shift_m = re.search(r"Default Shift", td0)
        shift = shift_m.group(0) if shift_m else ""
        terminal_m = re.search(r"Default Terminal", td0)
        terminal = terminal_m.group(0) if terminal_m else ""

        # Placed by / Closed by
        placed_m = re.search(r"Placed by\s+(\w+)", td0)
        placed_by = placed_m.group(1) if placed_m else ""
        closed_m = re.search(r"Closed by\s+(\w+)", td0)
        closed_by = closed_m.group(1) if closed_m else ""

        # Table info
        table_m = re.search(r"Table\s*\d+", td0)
        table_info = table_m.group(0) if table_m else ""

        # --- Parse TD 1 (items) ---
        # Extract individual items: item name + quantity
        items_parsed = []
        item_divs = re.findall(
            r'<h6[^>]*class="[^"]*dish-title[^"]*"[^>]*>\s*([^(]+)\((\d+)\)',
            td1
        )
        item_lines = []
        for name, qty in item_divs:
            item_lines.append(f"{name.strip()} (qty: {qty})")

        # Variants (e.g., + Medium (৳300.00))
        variants = re.findall(r'<small class="text-secondary">\s*([+][^<]+)</small>', td1)
        variant_lines = [v.strip() for v in variants]

        # Prices per item
        prices = re.findall(r'<div class="text-end card-text-font">\s*([\d,]+\.\d{2})', td1)
        price_lines = [f"৳{p}" for p in prices]

        # Combine items and variants
        item_details = []
        for i in range(len(item_lines)):
            name = item_lines[i]
            var = variant_lines[i] if i < len(variant_lines) else ""
            prc = price_lines[i] if i < len(price_lines) else ""
            item_details.append(f"{name} {var} {prc}".strip())

        items_str = " | ".join(item_details)

        # Discounts
        discount_type = ""
        discount_amount = ""
        disc_m = re.search(
            r"Discounts</h6>.*?<p[^>]*>\s*([^:]+?)\s*:\s*[^\d]*([\d,]+\.\d{2})",
            td1, re.DOTALL
        )
        if disc_m:
            discount_type = disc_m.group(1).strip()
            discount_amount = disc_m.group(2)

        # Total
        total_m = re.search(r"Total</h6>.*?([\d,]+\.\d{2})", td1, re.DOTALL)
        total = total_m.group(1) if total_m else ""

        orders.append({
            "order_no": order_no,
            "status": status,
            "datetime": datetime_str,
            "outlet": outlet,
            "service_type": service_type,
            "service_number": service_number,
            "sale_date": sale_date,
            "shift": shift,
            "terminal": terminal,
            "placed_by": placed_by,
            "closed_by": closed_by,
            "table_info": table_info,
            "items": items_str,
            "discount_type": discount_type,
            "discount_amount": discount_amount,
            "total": total,
        })
    return orders


def main():
    all_orders = []
    page = 1

    while True:
        print(f"Fetching page {page}...", file=sys.stderr)
        html = fetch_page(page)
        orders = parse_orders(html)
        if not orders:
            break
        print(f"  Found {len(orders)} orders", file=sys.stderr)
        all_orders.extend(orders)
        page += 1

    csv_path = "/home/dev/Documents/GitHub/FoodMania/orders/orders_june16.csv"
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "order_no", "status", "datetime", "outlet", "service_type",
            "service_number", "sale_date", "shift", "terminal",
            "placed_by", "closed_by", "table_info", "items",
            "discount_type", "discount_amount", "total",
        ])
        writer.writeheader()
        writer.writerows(all_orders)

    print(f"\nDone! {len(all_orders)} orders written to {csv_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
