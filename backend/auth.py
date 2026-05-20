from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
import bcrypt

from config import settings

ALGORITHM = "HS256"
TOKEN_EXPIRE_DAYS = 365
PLATFORM_TOKEN_EXPIRE_HOURS = 8

bearer_scheme = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    if not plain or not hashed:
        return False
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False


def create_device_token(outlet_id: str, account_id: str | None = None) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=TOKEN_EXPIRE_DAYS)
    payload = {"sub": outlet_id, "exp": expire}
    if account_id:
        payload["account_id"] = account_id
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def decode_device_payload(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        outlet_id: str = payload.get("sub", "")
        if not outlet_id:
            raise ValueError
        return payload
    except (JWTError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")


def decode_device_token(token: str) -> str:
    return str(decode_device_payload(token)["sub"])


def get_current_outlet_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> str:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")
    return decode_device_token(credentials.credentials)


def get_current_device_payload(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, Any]:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")
    return decode_device_payload(credentials.credentials)


def create_platform_token(admin_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=PLATFORM_TOKEN_EXPIRE_HOURS)
    payload = {"sub": admin_id, "type": "platform", "exp": expire}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def decode_platform_payload(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "platform":
            raise ValueError("Not a platform token")
        admin_id: str = payload.get("sub", "")
        if not admin_id:
            raise ValueError
        return payload
    except (JWTError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid platform token")


def get_current_platform_admin_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> str:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")
    return str(decode_platform_payload(credentials.credentials)["sub"])
