"""OpenCage reverse-geocoding for delivery orders.

Failures (network, malformed response, missing results) collapse to ``None``
so the order-create path can always succeed and the rider will still see the
raw coordinates on the printed receipt.
"""

from __future__ import annotations

import httpx

from config import settings


async def reverse_geocode(lat: float, lng: float) -> str | None:
    api_key = settings.OPENCAGE_API_KEY.strip()
    if not api_key:
        return None
    params = {
        "q": f"{lat}+{lng}",
        "key": api_key,
        "no_annotations": "1",
        "limit": "1",
    }
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(settings.OPENCAGE_BASE_URL, params=params)
        response.raise_for_status()
        data = response.json()
        results = data.get("results") or []
        formatted = results[0].get("formatted") if results else None
        if isinstance(formatted, str) and formatted.strip():
            return formatted.strip()
        return None
    except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError):
        return None
