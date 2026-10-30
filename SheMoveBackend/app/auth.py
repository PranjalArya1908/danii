from datetime import timedelta
from hashlib import pbkdf2_hmac
from typing import Any

import jwt
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import get_settings
from app.timeutil import utcnow

bearer = HTTPBearer(auto_error=False)


def hash_secret(value: str, salt: str | None = None) -> str:
    settings = get_settings()
    material = (salt or settings.secret_key).encode()
    return pbkdf2_hmac("sha256", value.encode(), material, 120_000).hex()


def verify_secret(value: str, hashed: str, salt: str | None = None) -> bool:
    return hash_secret(value, salt) == hashed


def create_token(payload: dict[str, Any], minutes: int | None = None) -> str:
    settings = get_settings()
    expire = utcnow() + timedelta(minutes=minutes or settings.access_token_expire_minutes)
    data = {**payload, "exp": expire}
    return jwt.encode(data, settings.secret_key, algorithm="HS256")


def decode_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    try:
        return jwt.decode(token, settings.secret_key, algorithms=["HS256"])
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc


def current_principal(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    x_share_token: str | None = Header(default=None, alias="X-Share-Token"),
) -> dict[str, Any] | None:
    if credentials and credentials.credentials:
        return decode_token(credentials.credentials)
    if x_share_token:
        return {"role": "CONTACT", "share_token": x_share_token}
    return None


def require_traveller(principal: dict[str, Any] | None = Depends(current_principal)) -> dict[str, Any]:
    if not principal or principal.get("role") != "TRAVELLER":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Traveller authentication required")
    return principal


def optional_police(principal: dict[str, Any] | None = Depends(current_principal)) -> dict[str, Any] | None:
    settings = get_settings()
    if principal and principal.get("role") in {"POLICE", "ADMIN"}:
        return principal
    if settings.demo_open_police:
        return {"role": "POLICE", "station_id": "all", "officer_id": "off-01", "name": "Demo Operator"}
    if not principal:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Police authentication required")
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Police role required")
