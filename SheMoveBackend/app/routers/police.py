from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse

from app.auth import optional_police
from app.realtime import broker
from app.schemas import AlertAckIn, AlertResolveIn, DispatchIn
from app.store import store
from app.timeutil import iso

router = APIRouter(prefix="/api/v1/police", tags=["police"])


def _station_scope(principal: dict) -> str | None:
    station_id = principal.get("station_id")
    if principal.get("role") == "ADMIN" or station_id == "all":
        return None
    return station_id


@router.get("/stations")
def stations(_: dict = Depends(optional_police)):
    return {"success": True, "stations": store.get_stations()}


@router.get("/trips")
def trips(
    station_id: str | None = Query(default=None),
    status: str | None = Query(default=None),
    principal: dict = Depends(optional_police),
):
    scoped = station_id or _station_scope(principal)
    return {
        "success": True,
        "trips": store.get_trips(scoped, status),
        "stats": store.get_stats(scoped),
    }


@router.get("/trips/{trip_id}")
def trip_detail(trip_id: str, _: dict = Depends(optional_police)):
    trip = store.get_trip(trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    return {"success": True, "trip": trip}


@router.get("/alerts")
def alerts(
    station_id: str | None = Query(default=None),
    status: str | None = Query(default=None),
    severity: str | None = Query(default=None),
    principal: dict = Depends(optional_police),
):
    scoped = station_id or _station_scope(principal)
    return {"success": True, "alerts": store.get_alerts(scoped, status, severity)}


@router.get("/stats")
def stats(station_id: str | None = Query(default=None), principal: dict = Depends(optional_police)):
    scoped = station_id or _station_scope(principal)
    return {"success": True, "stats": store.get_stats(scoped)}


@router.get("/audit")
def audit(_: dict = Depends(optional_police)):
    return {"success": True, "audit": store.audit}


@router.post("/alerts/{alert_id}/ack")
def ack_alert(alert_id: str, body: AlertAckIn | None = None, principal: dict = Depends(optional_police)):
    officer_name = (body.officerName if body else None) or principal.get("name") or "Police Operator"
    if not store.acknowledge_alert(alert_id, officer_name):
        raise HTTPException(status_code=404, detail="Alert not found")
    return {"success": True, "message": "Alert acknowledged", "acknowledged_at": iso()}


@router.post("/alerts/{alert_id}/resolve")
def resolve_alert(alert_id: str, body: AlertResolveIn | None = None, principal: dict = Depends(optional_police)):
    notes = (body.notes if body else None) or "Resolved by operator"
    outcome = (body.outcome if body else None) or "RESOLVED_SAFE"
    officer_name = (body.officerName if body else None) or principal.get("name") or "Police Operator"
    if not store.resolve_alert(alert_id, officer_name, notes, outcome):
        raise HTTPException(status_code=404, detail="Alert not found")
    return {"success": True, "message": "Alert resolved", "resolved_at": iso()}


@router.post("/dispatch")
def dispatch(body: DispatchIn, principal: dict = Depends(optional_police)):
    ok = store.dispatch_unit(
        body.tripId,
        body.unitCallsign or "PCR-ECHO-14",
        body.officerInCharge or "Sub-Inspector Kumar",
        body.etaMinutes or 4,
        body.notes or "Dispatched for emergency interception.",
        actor=principal.get("name") or "police",
    )
    if not ok:
        raise HTTPException(status_code=404, detail="Trip not found")
    return {
        "success": True,
        "message": "112 Emergency Patrol unit dispatched successfully",
        "dispatch": {
            "unitCallsign": body.unitCallsign or "PCR-ECHO-14",
            "officerInCharge": body.officerInCharge or "Sub-Inspector Kumar",
            "etaMinutes": body.etaMinutes or 4,
            "dispatched_at": iso(),
        },
    }


@router.get("/stream")
async def stream(_: dict = Depends(optional_police)):
    async def event_gen():
        async for chunk in broker.sse_stream(store.snapshot):
            yield chunk

    return StreamingResponse(
        event_gen(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
