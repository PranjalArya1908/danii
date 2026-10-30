from datetime import datetime

from app.geo import haversine_m
from app.timeutil import parse_iso, utcnow


def _minutes_since(iso_value: str | None) -> float | None:
    parsed = parse_iso(iso_value)
    if not parsed:
        return None
    return (utcnow() - parsed).total_seconds() / 60.0


def assess_journey(trip: dict, now: datetime | None = None) -> dict:
    """Transparent rule-based risk score. Does not claim a crime is occurring."""
    now = now or utcnow()
    signals: list[dict] = []
    score = 0
    recommend_checkin_minutes = trip.get("checkin_interval_minutes") or 7

    last_heartbeat_min = _minutes_since(trip.get("last_heartbeat_at"))
    if last_heartbeat_min is not None and last_heartbeat_min > 1.5:
        severity = "HIGH" if last_heartbeat_min > 3 else "MEDIUM"
        score += 35 if severity == "HIGH" else 20
        signals.append(
            {
                "code": "STALE_HEARTBEAT",
                "severity": severity,
                "detail": f"Last heartbeat {last_heartbeat_min:.1f} minutes ago. Location may be last-known, not live.",
            }
        )

    ends_at = parse_iso(trip.get("ends_at"))
    if ends_at and now > ends_at and trip.get("status") not in {"COMPLETED", "CANCELLED"}:
        score += 25
        signals.append(
            {
                "code": "TRIP_OVERDUE",
                "severity": "HIGH",
                "detail": "Expected arrival time has passed without a safe-arrival confirmation.",
            }
        )

    destination = trip.get("destination")
    last_location = trip.get("last_location") or {}
    if destination and last_location:
        remaining_m = haversine_m(
            last_location.get("lat", 0),
            last_location.get("lng", 0),
            destination.get("lat", 0),
            destination.get("lng", 0),
        )
        started = parse_iso(trip.get("started_at"))
        expected_s = trip.get("expected_duration_s") or 1
        elapsed_s = (now - started).total_seconds() if started else 0
        expected_progress = min(1.0, max(0.0, elapsed_s / expected_s))
        history = trip.get("location_history") or []
        if history:
            start = history[0]
            total_m = haversine_m(start["lat"], start["lng"], destination["lat"], destination["lng"]) or 1
            travelled = max(0.0, total_m - remaining_m)
            actual_progress = travelled / total_m
            if expected_progress - actual_progress > 0.35:
                score += 15
                signals.append(
                    {
                        "code": "UNEXPECTED_DELAY",
                        "severity": "MEDIUM",
                        "detail": "Journey progress is lagging the estimated timeline.",
                    }
                )

        waypoints = trip.get("waypoints") or []
        if len(waypoints) >= 2:
            nearest = min(
                haversine_m(last_location["lat"], last_location["lng"], wp["lat"], wp["lng"])
                for wp in waypoints
            )
            if nearest > 400:
                score += 20
                signals.append(
                    {
                        "code": "ROUTE_DEVIATION",
                        "severity": "HIGH",
                        "detail": f"Current location is about {int(nearest)}m from the planned route.",
                    }
                )

    battery = trip.get("last_battery_pct") or 100
    if battery <= 8:
        score += 10
        signals.append(
            {
                "code": "LOW_BATTERY",
                "severity": "MEDIUM",
                "detail": f"Device battery reported at {battery}%.",
            }
        )

    pending = [c for c in trip.get("checkins") or [] if c.get("outcome") == "PENDING"]
    if pending or trip.get("status") == "CHECKIN_PENDING":
        score += 18
        signals.append(
            {
                "code": "CHECKIN_PENDING",
                "severity": "MEDIUM",
                "detail": "A safety check-in is awaiting a response.",
            }
        )
        recommend_checkin_minutes = min(recommend_checkin_minutes, 3)

    if trip.get("status") == "ALERT_RAISED":
        score += 30
        signals.append(
            {
                "code": "OPEN_ALERT",
                "severity": "CRITICAL",
                "detail": "An incident is already open for this journey.",
            }
        )

    hour = now.hour
    if hour >= 22 or hour < 6:
        recommend_checkin_minutes = max(3, int(recommend_checkin_minutes * 0.8))
        signals.append(
            {
                "code": "NIGHT_HOURS",
                "severity": "INFO",
                "detail": "Night-time travel uses a shorter prototype check-in interval.",
            }
        )

    score = min(100, score)
    if score >= 70:
        band = "HIGH"
        recommend_checkin_minutes = min(recommend_checkin_minutes, 3)
    elif score >= 40:
        band = "ELEVATED"
        recommend_checkin_minutes = min(recommend_checkin_minutes, 5)
    else:
        band = "NORMAL"

    return {
        "score": score,
        "band": band,
        "signals": signals,
        "recommended_checkin_minutes": recommend_checkin_minutes,
        "disclaimer": "This is a transparent prototype risk score. It does not determine whether a crime is occurring.",
    }
