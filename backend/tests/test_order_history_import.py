from services.order_history_import import parse_order_history_csv


def test_order_history_csv_groups_line_items_and_preserves_source_date():
    parsed = parse_order_history_csv(
        b"Invoice No,Order Date,Item Name,Qty,Unit Price,Grand Total,Notes\n"
        b"INV-204,2024-01-02 10:45 PM,Chicken Burger,2,175,430,Late table\n"
        b"INV-204,2024-01-02 10:45 PM,Tea,2,40,430,Late table\n",
        outlet_id="outlet-1",
    )

    assert parsed.row_count == 2
    assert parsed.skipped_rows == 0
    assert len(parsed.orders) == 1
    order = parsed.orders[0]
    assert order.serial_number == 204
    assert order.created_at.isoformat() == "2024-01-02T22:45:00+00:00"
    assert order.total_amount == 430
    assert [item["name"] for item in order.items] == ["Chicken Burger", "Tea"]
    assert [item["lineTotal"] for item in order.items] == [350, 80]


def test_order_history_csv_accepts_summary_rows_and_skips_rows_without_date():
    parsed = parse_order_history_csv(
        b"Bill No,Date,Total\n"
        b"B-7,2023-11-03,1200\n"
        b"B-8,,900\n",
        outlet_id="outlet-1",
    )

    assert len(parsed.orders) == 1
    assert parsed.skipped_rows == 1
    assert parsed.errors == ["Row 3: missing or invalid order date."]
    assert parsed.orders[0].items[0]["name"] == "Legacy order total"
    assert parsed.orders[0].items[0]["lineTotal"] == 1200


def test_order_history_csv_ids_are_stable_for_reimport():
    first = parse_order_history_csv(
        b"Order ID,Created At,Total\nold-99,2022-09-01T11:00:00Z,99\n",
        outlet_id="outlet-1",
    )
    second = parse_order_history_csv(
        b"Order ID,Created At,Total\nold-99,2022-09-01T11:00:00Z,99\n",
        outlet_id="outlet-1",
    )

    assert first.orders[0].id == second.orders[0].id
