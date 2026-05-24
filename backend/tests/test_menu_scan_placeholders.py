from types import SimpleNamespace

from services.menu_placeholders import (
    ICON_KEY_TO_FILES,
    normalize_icon_key,
    placeholder_relative_path,
    resolve_placeholder_url,
)


class _FakeRequest:
    def __init__(self, base: str) -> None:
        self.base_url = base


def test_known_icon_key_maps_to_first_file_for_index_zero():
    assert placeholder_relative_path("chicken", 0) == "menu_placeholders/chicken-1.png"
    assert placeholder_relative_path("beef", 0) == "menu_placeholders/beef-1.png"


def test_round_robin_within_bucket():
    files = ICON_KEY_TO_FILES["beef"]
    for i in range(len(files) * 2):
        assert placeholder_relative_path("beef", i).endswith(files[i % len(files)])


def test_unknown_icon_key_falls_back_to_general():
    assert placeholder_relative_path("nonsense", 0).startswith("menu_placeholders/")
    assert placeholder_relative_path("nonsense", 0) == placeholder_relative_path(
        "general", 0
    )


def test_alias_mapping():
    assert normalize_icon_key("drink") == "beverages"
    assert normalize_icon_key("Tea") == "tea_coffee"
    assert normalize_icon_key("dessert") == "sweets"
    assert normalize_icon_key("snack") == "fuchka"


def test_resolve_url_builds_against_request_base():
    request = _FakeRequest("https://api.example.com/")
    url = resolve_placeholder_url("fish", 2, request)
    assert url == "https://api.example.com/uploads/menu_placeholders/fish-3.png"
