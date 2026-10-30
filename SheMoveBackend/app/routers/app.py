from fastapi import APIRouter, Depends, HTTPException

from app.auth import require_traveller
from app.schemas import ContactCreate, ContactUpdate, GeofenceCreate, PinVerify, ProfileUpdate
from app.store import public_user, store

router = APIRouter(prefix="/api/v1", tags=["traveller"])


@router.get("/me")
def me(principal: dict = Depends(require_traveller)):
    user = store.get_user(principal["sub"])
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"success": True, "user": public_user(user)}


@router.patch("/me")
def update_me(body: ProfileUpdate, principal: dict = Depends(require_traveller)):
    user = store.update_user(principal["sub"], body.model_dump(exclude_none=True))
    return {"success": True, "user": public_user(user)}


@router.post("/me/pins/verify")
def verify_pin(body: PinVerify, principal: dict = Depends(require_traveller)):
    result = store.verify_pin(principal["sub"], body.pin)
    return {"success": result["valid"], **result}


@router.get("/contacts")
def list_contacts(principal: dict = Depends(require_traveller)):
    return {"success": True, "contacts": store.list_contacts(principal["sub"])}


@router.post("/contacts")
def add_contact(body: ContactCreate, principal: dict = Depends(require_traveller)):
    contact = store.add_contact(principal["sub"], body.model_dump())
    return {"success": True, "contact": contact}


@router.patch("/contacts/{contact_id}")
def update_contact(contact_id: str, body: ContactUpdate, principal: dict = Depends(require_traveller)):
    contact = store.update_contact(principal["sub"], contact_id, body.model_dump(exclude_none=True))
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    return {"success": True, "contact": contact}


@router.delete("/contacts/{contact_id}")
def delete_contact(contact_id: str, principal: dict = Depends(require_traveller)):
    if not store.delete_contact(principal["sub"], contact_id):
        raise HTTPException(status_code=404, detail="Contact not found")
    return {"success": True}


@router.get("/geofences")
def list_geofences(principal: dict = Depends(require_traveller)):
    return {"success": True, "geofences": store.list_geofences(principal["sub"])}


@router.post("/geofences")
def add_geofence(body: GeofenceCreate, principal: dict = Depends(require_traveller)):
    fence = store.add_geofence(principal["sub"], body.model_dump())
    return {"success": True, "geofence": fence}


@router.delete("/geofences/{fence_id}")
def delete_geofence(fence_id: str, principal: dict = Depends(require_traveller)):
    if not store.delete_geofence(principal["sub"], fence_id):
        raise HTTPException(status_code=404, detail="Geofence not found")
    return {"success": True}


@router.get("/events")
def events(principal: dict = Depends(require_traveller)):
    return {"success": True, "events": store.user_events(principal["sub"])}


@router.get("/notifications")
def notifications(principal: dict = Depends(require_traveller)):
    trip_ids = {t["id"] for t in store.list_user_trips(principal["sub"])}
    items = [n for n in store.notifications if n.get("trip_id") in trip_ids]
    return {"success": True, "notifications": items}
