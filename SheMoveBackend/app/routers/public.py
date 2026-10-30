from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse, StreamingResponse

from app.auth import hash_secret, verify_secret
from app.realtime import broker
from app.schemas import TrackActionIn
from app.store import sanitize_trip, store
from app.timeutil import iso

router = APIRouter(prefix="/api/v1/public", tags=["trusted-contact"])


@router.get("/track/{token}")
def get_track(token: str):
    trip = store.get_trip_by_token(token)
    if not trip:
        return JSONResponse(
            {"error": "Tracking link expired or not found", "code": "TRIP_NOT_FOUND"},
            status_code=404,
        )
    return {"success": True, "trip": sanitize_trip(trip), "server_time": iso()}


@router.post("/track/{token}")
def track_action(token: str, body: TrackActionIn):
    trip = store.get_trip_by_token(token)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if body.action == "modify_time":
        user = store.get_user(trip["traveller_id"])
        additional = body.additionalMinutes
        if user and body.pin and verify_secret(body.pin, user.get("duress_pin_hash") or hash_secret("")):
            store.trigger_duress_alert(trip["id"])
            return {
                "success": True,
                "duressTriggered": True,
                "message": f"Trip duration extended by {additional} minutes.",
                "newDurationMinutes": round(trip["expected_duration_s"] / 60) + additional,
            }
        pin_ok = not body.pin
        if user and body.pin:
            pin_ok = verify_secret(body.pin, user.get("safety_pin_hash") or "")
        if pin_ok:
            updated = store.extend_trip(trip["id"], additional)
            return {
                "success": True,
                "duressTriggered": False,
                "message": f"Trip duration extended by {additional} minutes.",
                "newDurationMinutes": round((updated or trip)["expected_duration_s"] / 60),
                "ends_at": (updated or trip).get("ends_at"),
            }
        return JSONResponse(
            {"error": "Invalid PIN entered. Please try again.", "code": "INVALID_PIN"},
            status_code=400,
        )

    if body.action == "checkin_response":
        if body.response not in {"SAFE", "UNSAFE"}:
            raise HTTPException(status_code=400, detail="Invalid response value")
        store.respond_to_checkin(trip["id"], body.response)
        updated = store.get_trip(trip["id"]) or trip
        return {"success": True, "response": body.response, "trip": sanitize_trip(updated)}

    if body.action == "sos":
        alert = store.simulate_sos(trip["id"])
        updated = store.get_trip(trip["id"]) or trip
        return {"success": True, "alert": alert, "trip": sanitize_trip(updated)}

    if body.action == "ack":
        store.contact_acknowledge(token, body.contact_id)
        updated = store.get_trip(trip["id"]) or trip
        return {"success": True, "trip": sanitize_trip(updated)}

    if body.action == "simulate":
        sub = body.subAction
        if sub == "set_mode":
            store.set_trip_scenario(trip["id"], body.mode or "live")
        elif sub == "advance_location":
            store.simulate_advance_location(trip["id"])
        elif sub == "kill_heartbeat":
            store.set_trip_scenario(trip["id"], "silent")
        elif sub == "safe_checkin":
            store.set_trip_scenario(trip["id"], "live")
        elif sub == "complete_trip":
            store.set_trip_scenario(trip["id"], "done")
        elif sub == "reset":
            store.seed()
        updated = store.get_trip(trip["id"]) or store.get_trip_by_token(token) or trip
        return {"success": True, "subAction": sub, "trip": sanitize_trip(updated), "server_time": iso()}

    raise HTTPException(status_code=400, detail=f"Unknown action: {body.action}")


@router.get("/track/{token}/stream")
async def track_stream(token: str):
    if not store.get_trip_by_token(token):
        raise HTTPException(status_code=404, detail="Trip not found")

    def snapshot():
        current = store.get_trip_by_token(token)
        return {
            "type": "SNAPSHOT",
            "trip": sanitize_trip(current) if current else None,
            "timestamp": iso(),
        }

    async def event_gen():
        async for chunk in broker.sse_stream(snapshot):
            yield chunk

    return StreamingResponse(
        event_gen(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache, no-transform", "Connection": "keep-alive"},
    )
