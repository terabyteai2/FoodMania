"""Bangladesh phone normalization and synthetic account identifiers."""

import re

BD_PHONE_PATTERN = re.compile(r"^\+8801[3-9]\d{8}$")
PHONE_EMAIL_DOMAIN = "phone.rastarant.local"

INVITE_PENDING = "pending"
INVITE_ACCEPTED = "accepted"
INVITE_DECLINED = "declined"


def normalize_bd_phone(raw: str) -> str:
    """Normalize to E.164 +8801XXXXXXXXX. Raises ValueError if invalid."""
    digits = re.sub(r"\D", "", (raw or "").strip())
    if digits.startswith("880"):
        digits = digits[3:]
    elif digits.startswith("0"):
        digits = digits[1:]
    if len(digits) != 10 or not digits.startswith("1"):
        raise ValueError("Enter a valid Bangladesh mobile number (01XXXXXXXXX).")
    normalized = f"+880{digits}"
    if not BD_PHONE_PATTERN.match(normalized):
        raise ValueError("Enter a valid Bangladesh mobile number (01XXXXXXXXX).")
    return normalized


def phone_to_synthetic_email(phone: str) -> str:
    """Stable unique email/username for phone-only accounts."""
    return f"{normalize_bd_phone(phone)}@{PHONE_EMAIL_DOMAIN}"


def display_phone(phone: str | None) -> str | None:
    if not phone:
        return None
    try:
        p = normalize_bd_phone(phone)
    except ValueError:
        return phone
    return f"0{p[4:]}"  # +8801… → 01…
