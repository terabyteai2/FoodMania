import pytest

from services import support_proactive as sp


class _FakeItem:
    def __init__(self, name, quantity, min_threshold, unit="kg"):
        self.name = name
        self.quantity = quantity
        self.min_threshold = min_threshold
        self.unit = unit


class _Scalars:
    def __init__(self, rows):
        self._rows = rows

    def all(self):
        return self._rows

    def first(self):
        return self._rows[0] if self._rows else None


class _Result:
    def __init__(self, rows):
        self._rows = rows

    def scalars(self):
        return _Scalars(self._rows)

    def scalar_one_or_none(self):
        return self._rows[0] if self._rows else None


class _FakeSession:
    def __init__(self, rows):
        self._rows = rows

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def execute(self, stmt):
        return _Result(self._rows)


@pytest.mark.asyncio
async def test_low_stock_alert_fires_and_respects_cooldown(monkeypatch):
    delivered = []

    async def fake_proactive(outlet_id, trigger, context=""):
        delivered.append((outlet_id, trigger, context))

    monkeypatch.setattr(sp, "support_llm_proactive_message", fake_proactive)
    monkeypatch.setattr(sp.settings, "SUPPORT_PROACTIVE_LOW_STOCK_COOLDOWN_HOURS", 12)

    rows = [_FakeItem("Sugar", 2.0, 5.0), _FakeItem("Rice", 0.0, 3.0)]
    monkeypatch.setattr(sp, "AsyncSessionLocal", lambda: _FakeSession(rows))

    sp._last_low_stock_at.clear()
    await sp._maybe_low_stock("outlet-1")
    assert len(delivered) == 1
    assert delivered[0][0] == "outlet-1"
    assert delivered[0][1] == "low_stock"
    assert "Sugar" in delivered[0][2]

    # Second call inside the cooldown window must not deliver again.
    await sp._maybe_low_stock("outlet-1")
    assert len(delivered) == 1

    # No low-stock items -> nothing fires.
    sp._last_low_stock_at.clear()
    monkeypatch.setattr(sp, "AsyncSessionLocal", lambda: _FakeSession([]))
    await sp._maybe_low_stock("outlet-1")
    assert len(delivered) == 1


@pytest.mark.asyncio
async def test_eod_summary_fires_once_per_day(monkeypatch):
    delivered = []

    async def fake_proactive(outlet_id, trigger, context=""):
        delivered.append((outlet_id, trigger, context))

    monkeypatch.setattr(sp, "support_llm_proactive_message", fake_proactive)
    monkeypatch.setattr(sp.settings, "SUPPORT_PROACTIVE_EOD_HOUR", 0)

    monkeypatch.setattr(sp, "AsyncSessionLocal", lambda: _FakeSession([5]))
    sp._last_eod_date.clear()
    await sp._maybe_eod_summary("outlet-1")
    assert len(delivered) == 1
    assert delivered[0][1] == "eod_summary"

    # Same BDT day -> only one summary.
    await sp._maybe_eod_summary("outlet-1")
    assert len(delivered) == 1

    # No orders today -> nothing fires.
    sp._last_eod_date.clear()
    monkeypatch.setattr(sp, "AsyncSessionLocal", lambda: _FakeSession([0]))
    await sp._maybe_eod_summary("outlet-1")
    assert len(delivered) == 1