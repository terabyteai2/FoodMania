import pytest

from fastapi import HTTPException

from schemas import PlatformAppUpdateRequest
from services.app_update import app_update_from_json, disabled_app_update, _payload_from_request


def test_app_update_from_json_requires_complete_enabled_payload():
    assert app_update_from_json("") == disabled_app_update()
    assert app_update_from_json('{"enabled": true}') == disabled_app_update()

    parsed = app_update_from_json(
        '{"enabled":true,"versionName":"1.3.2","versionCode":3,'
        '"apkUrl":"https://example.com/app.apk","required":true}'
    )

    assert parsed["enabled"] is True
    assert parsed["versionName"] == "1.3.2"
    assert parsed["versionCode"] == 3
    assert parsed["apkUrl"] == "https://example.com/app.apk"
    assert parsed["required"] is True


def test_app_update_request_validates_http_url():
    body = PlatformAppUpdateRequest(
        versionName="1.3.2",
        versionCode=3,
        apkUrl="file:///tmp/app.apk",
    )

    with pytest.raises(HTTPException):
        _payload_from_request(body)
