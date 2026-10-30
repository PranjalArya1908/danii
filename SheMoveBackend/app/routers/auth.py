from fastapi import APIRouter, HTTPException

from app.auth import create_token, hash_secret, verify_secret
from app.schemas import PoliceLogin, TravellerLogin, TravellerRegister
from app.store import public_user, store

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/traveller/register")
def register(body: TravellerRegister):
    try:
        user = store.register_user(body.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    token = create_token({"sub": user["id"], "role": "TRAVELLER", "name": user["name"]})
    return {"success": True, "token": token, "user": public_user(user), "expires_in": 86400}


@router.post("/traveller/login")
def traveller_login(body: TravellerLogin):
    user = store.find_user_by_phone(body.phone)
    if not user or not verify_secret(body.password, user.get("password_hash") or hash_secret("")):
        raise HTTPException(status_code=401, detail="Invalid phone or password")
    token = create_token({"sub": user["id"], "role": "TRAVELLER", "name": user["name"]})
    return {"success": True, "token": token, "user": public_user(user), "expires_in": 86400}


@router.post("/police/login")
def police_login(body: PoliceLogin):
    officer = store.find_officer_login(body.email, body.password, body.officerId)
    token = create_token(
        {
            "sub": officer["id"],
            "role": officer.get("role", "POLICE"),
            "station_id": officer.get("stationId"),
            "name": officer["name"],
        }
    )
    return {
        "success": True,
        "token": token,
        "officer": officer,
        "expires_in": 86400,
    }
