# Receipt Print — Data Model

Everything that prints on a `Customer Copy` receipt. Layout follows the Petpooja-style spec in `admin_app/docs/new_layout_receipt.txt` (48-char boundary thermal receipt).

## Differences between normal and delivery

| Section | Normal (dine-in/takeaway) | Delivery |
|---|---|---|
| Service type heading | "DINE IN" / "TAKEAWAY" | "DELIVERY" |
| Summary rows | Subtotal, Discount, Service charge, Total, VAT | Subtotal, Discount, **Delivery fee**, Total, VAT |
| `deliveryAddress`, `mobileNumber` | hidden | shown after payment line |
| Customer footer | NAME, TABLE | NAME, ADDRESS (multiline wrap), PHONE |
| QR caption | "Scan to track / rate us" | "Track your delivery" |
| `footerText` | "Thank you for dining!" | null (hidden) |

## Data classes involved

| Class | Fields | Role |
|---|---|---|
| `TicketCopyData` | 25 fields | Full receipt payload passed to the bitmap renderer |
| `TicketLineItem` | `index`, `name`, `qtyText`, `lineTotalText` | Each order item row (index rendered as 3-digit 001/002...) |
| `TicketSummaryRow` | `label`, `value`, `emphasis` | Subtotal / Discount(+label) / Fee / VAT rows |
| `TicketBitmapRenderer.render(TicketCopyData)` | — | Paints everything to a PNG bitmap, sent as ESC/POS raster to the printer |

### `TicketCopyData` fields

| Field | Type | Source |
|---|---|---|
| `orderNumberDisplay` | `String` | `order.displaySequence` — bare "#123" (renderer prepends "Order: ") |
| `orderTypeLabel` | `String` | `_orderTypeLabel(order, labels)` — "Dine in" / "Takeaway" / "Delivery" (renderer uppercases as heading) |
| `copyLabel` | `String` | `isManagerCopy ? "Manager Copy" : "Customer Copy"` (unused in layout) |
| `dateLine` | `String` | `labels.formatDate(order.createdAt)` (renderer prepends "Date: ") |
| `tableLine` | `String` | `labels.tableLabel(tableRaw)` — empty for delivery |
| `sourceLine` | `String` | `labels.sourceLabel(order.source)` (renderer prepends "Source: ") |
| `items` | `List<TicketLineItem>` | Built from `order.items` |
| `totalLabel` | `String` | `"Total (VAT included)"` |
| `totalAmount` | `String` | `labels.money(_orderTotalFor(order))` |
| `summaryRows` | `List<TicketSummaryRow>` | `_receiptSummaryRows(order, labels)` — discount row includes `(10% OFF)` label when available |
| `paymentLine` | `String?` | `_paymentLine(order, labels)` |
| `customerName` | `String?` | `order.customerName` |
| `customerNameLabel` | `String` | `"Name"` (localized) |
| `deliveryAddress` | `String?` | `order.deliveryAddress` |
| `deliveryAddressLabel` | `String` | `"Address"` (localized) |
| `mobileNumber` | `String?` | `order.mobileNumber` |
| `mobileNumberLabel` | `String` | `"Phone"` (localized) |
| `note` | `String?` | `order.note` (manager copy only) |
| `noteLabel` | `String` | `"Note"` (localized) |
| `orderDetailsUrl` | `String?` | `_orderDetailsUrl(order)` — QR content |
| `qrCaption` | `String?` | `"Track your delivery"` or `"Scan to track / rate us"` |
| `footerText` | `String?` | `"Thank you for dining!"` or `null` |
| `serverRole` | `String?` | `serverRole` parameter |
| `isManagerCopy` | `bool` | Controls note |
| `restaurantSubtitle` | `String?` | Always null (no longer shown on receipts) |
| `outletName` | `String?` | Unused (always null) |
| `totalNote` | `String` | Unused (empty) |

## Receipt layout (bitmap renderer order)

1. `===` double-line top border
2. Restaurant name (48px w800, centered, truncated ≤24 chars)
3. Service type heading (24px w700, centered, uppercase)
4. "Order: #N" (22px w700, centered)
5. "Date: ..." (22px w500, centered)
6. "Source: ..." (22px w500, centered)
7. `---` single divider
8. Column header row: INDEX QTY DESCRIPTION PRICE
9. Item rows (3-digit index, qty, desc wrap ≤2 lines, price right)
10. `---` single divider
11. Summary rows (subtotal, discount+label, service/delivery, total bold, VAT)
12. `---` single divider + payment line
13. Customer info (NAME, ADDRESS multiline, PHONE for delivery; NAME, TABLE for dine-in)
14. QR code (~280px centered)
15. QR caption (20px centered)
16. Footer text (if present)
17. `===` double-line bottom border
