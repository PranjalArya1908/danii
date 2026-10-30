from fastapi import APIRouter, HTTPException

from app.schemas import SimulateIn
from app.store import store

router = APIRouter(prefix="/api/v1/demo", tags=["demo"])


@router.post("/seed")
def seed():
    store.seed()
    return {
        "success": True,
        "message": "Stations, polygons, police operators, and sample trips seeded successfully",
        "stations_count": len(store.get_stations()),
        "trips_count": len(store.get_trips()),
    }


@router.post("/simulate")
def simulate(body: SimulateIn):
    action = body.action
    trip_id = body.tripId
    trips = store.get_trips()

    if action == "sos":
        alert = store.simulate_sos(trip_id)
        return {"success": True, "action": "sos", "alert": alert}
    if action == "missed_checkin":
        alert = store.simulate_missed_checkin(trip_id)
        return {"success": True, "action": "missed_checkin", "alert": alert}
    if action == "kill_heartbeat":
        if not trip_id:
            active = next((t for t in trips if t.get("status") == "ACTIVE"), trips[0] if trips else None)
            trip_id = active["id"] if active else None
        if not trip_id:
            raise HTTPException(status_code=404, detail="No trip available")
        alert = store.simulate_kill_heartbeat(trip_id)
        return {"success": True, "action": "kill_heartbeat", "alert": alert}
    if action == "safe_checkin":
        active = next((t for t in trips if t.get("status") in {"ACTIVE", "CHECKIN_PENDING"}), trips[0] if trips else None)
        target = trip_id or (active["id"] if active else None)
        ok = store.simulate_safe_checkin(target) if target else False
        return {"success": ok, "action": "safe_checkin", "tripId": target}
    if action == "advance_location":
        active = next((t for t in trips if t.get("status") in {"ACTIVE", "ALERT_RAISED"}), trips[0] if trips else None)
        target = trip_id or (active["id"] if active else None)
        ok = store.simulate_advance_location(target) if target else False
        return {"success": ok, "action": "advance_location", "tripId": target}
    if action == "complete_trip":
        active = next((t for t in trips if t.get("status") in {"ACTIVE", "ALERT_RAISED"}), trips[0] if trips else None)
        target = trip_id or (active["id"] if active else None)
        ok = bool(store.simulate_complete_trip(target) if target else False)
        return {"success": ok, "action": "complete_trip", "tripId": target}
    if action == "seed":
        store.seed()
        return {"success": True, "action": "seed", "message": "Demo data re-seeded"}
    raise HTTPException(status_code=400, detail=f"Unknown simulation action: {action}")
