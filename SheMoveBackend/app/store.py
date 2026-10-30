from __future__ import annotations

import copy
import math
import random
import re
import secrets
from typing import Any, Callable

from app.config import get_settings
from app.geo import assign_station, haversine_m
from app.risk import assess_journey
from app.seed import (
    DEMO_OFFICERS,
    POLICE_STATIONS,
    create_initial_trips,
    demo_contacts,
    demo_geofences,
    demo_users,
)
from app.timeutil import add_minutes, iso, parse_iso, sub_minutes, utcnow


Listener = Callable[[], None]


def _mask_phone(phone: str) -> str:
    return re.sub(r"(\+\d{2}\s\d{2})\d{4}(\d{4})", r"\1****\2", phone)


def sanitize_trip(trip: dict) -> dict:
    alerts = trip.get("alerts") or []
    contacts = trip.get("contacts") or []
    return {
        "id": trip["id"],
        "share_token": trip["share_token"],
        "traveller_name": trip["traveller_name"],
        "traveller_first_name": trip["traveller_name"].split(" ")[0],
        "traveller_full_name": trip["traveller_name"],
        "traveller_phone": trip["traveller_phone"],
        "traveller_phone_masked": _mask_phone(trip["traveller_phone"]),
        "status": trip["status"],
        "started_at": trip["started_at"],
        "expected_duration_s": trip["expected_duration_s"],
        "ends_at": trip["ends_at"],
        "destination_name": trip.get("destination_name") or "Destination",
        "destination": trip.get("destination"),
        "completed_at": trip.get("completed_at"),
        "vehicle_number": trip.get("vehicle_number"),
        "vehicle_entered_at": trip.get("vehicle_entered_at"),
        "next_checkin_due_at": trip.get("next_checkin_due_at"),
        "checkin_deadline_at": trip.get("checkin_deadline_at"),
        "last_heartbeat_at": trip.get("last_heartbeat_at"),
        "last_location": trip.get("last_location"),
        "last_accuracy_m": trip.get("last_accuracy_m"),
        "last_battery_pct": trip.get("last_battery_pct"),
        "current_station_name": trip.get("current_station_name"),
        "location_history": (trip.get("location_history") or [])[-30:],
        "checkins": (trip.get("checkins") or [])[:5],
        "alerts": alerts,
        "active_alert": next((a for a in alerts if a.get("status") in {"OPEN", "ACKNOWLEDGED"}), None),
        "contacts": contacts,
        "contacts_count": len(contacts),
        "dispatch_info": trip.get("dispatchInfo"),
        "location_freshness": "LIVE" if _heartbeat_fresh(trip) else "LAST_KNOWN",
    }


def _heartbeat_fresh(trip: dict) -> bool:
    last = parse_iso(trip.get("last_heartbeat_at"))
    if not last:
        return False
    return (utcnow() - last).total_seconds() < get_settings().heartbeat_timeout_s


def public_user(user: dict) -> dict:
    return {
        "id": user["id"],
        "name": user["name"],
        "phone": user["phone"],
        "role": user.get("role", "TRAVELLER"),
        "biometric_enabled": user.get("biometric_enabled", False),
        "default_checkin_minutes": user.get("default_checkin_minutes", 10),
        "adaptive_frequency_enabled": user.get("adaptive_frequency_enabled", True),
        "emergency_message": user.get("emergency_message"),
        "is_dark_mode": user.get("is_dark_mode", True),
        "is_setup_complete": user.get("is_setup_complete", False),
        "retention_days": user.get("retention_days", 30),
        "has_safety_pin": bool(user.get("safety_pin_hash")),
        "has_duress_pin": bool(user.get("duress_pin_hash")),
    }


class SheMoveStore:
    def __init__(self) -> None:
        self.trips: dict[str, dict] = {}
        self.users: dict[str, dict] = {}
        self.contacts: dict[str, dict] = {}
        self.geofences: dict[str, dict] = {}
        self.stations: list[dict] = []
        self.officers: list[dict] = []
        self.audit: list[dict] = []
        self.notifications: list[dict] = []
        self._listeners: list[Listener] = []
        self.seed()

    def subscribe(self, listener: Listener) -> Callable[[], None]:
        self._listeners.append(listener)

        def unsubscribe() -> None:
            if listener in self._listeners:
                self._listeners.remove(listener)

        return unsubscribe

    def notify(self) -> None:
        for listener in list(self._listeners):
            try:
                listener()
            except Exception:
                continue

    def seed(self) -> None:
        self.trips.clear()
        self.users.clear()
        self.contacts.clear()
        self.geofences.clear()
        self.audit.clear()
        self.notifications.clear()
        self.stations = copy.deepcopy(POLICE_STATIONS)
        self.officers = copy.deepcopy(DEMO_OFFICERS)
        for user in demo_users():
            self.users[user["id"]] = user
        for contact in demo_contacts():
            self.contacts[contact["id"]] = contact
        for fence in demo_geofences():
            self.geofences[fence["id"]] = fence
        for trip in create_initial_trips():
            self.trips[trip["id"]] = trip
            for contact in trip.get("contacts") or []:
                # Prefer dedicated demo_contacts entries when IDs collide.
                if contact["id"] not in self.contacts:
                    self.contacts[contact["id"]] = {
                        **contact,
                        "user_id": trip["traveller_id"],
                    }
        self._audit("system", "SEED", "Demo dataset loaded")
        self.notify()

    def snapshot(self) -> dict:
        return {
            "type": "SNAPSHOT",
            "trips": self.get_trips(),
            "alerts": self.get_alerts(),
            "stats": self.get_stats(),
            "timestamp": iso(),
        }

    def update_snapshot(self) -> dict:
        data = self.snapshot()
        data["type"] = "UPDATE"
        return data

    def _audit(self, actor: str, action: str, detail: str, extra: dict | None = None) -> None:
        entry = {
            "id": f"aud-{secrets.token_hex(4)}",
            "actor": actor,
            "action": action,
            "detail": detail,
            "at": iso(),
            **(extra or {}),
        }
        self.audit.insert(0, entry)
        self.audit = self.audit[:500]

    def _notify_contacts(self, trip: dict, channel: str, message: str, kind: str) -> None:
        for contact in trip.get("contacts") or []:
            record = {
                "id": f"ntf-{secrets.token_hex(4)}",
                "trip_id": trip["id"],
                "contact_id": contact.get("id"),
                "contact_name": contact.get("name"),
                "channel": channel,
                "kind": kind,
                "message": message,
                "status": "SENT",
                "acknowledged": False,
                "created_at": iso(),
            }
            self.notifications.insert(0, record)
            contact["smsStatus"] = "SENT"
        self._audit("system", "NOTIFY", message, {"trip_id": trip["id"], "kind": kind})

    def get_stations(self) -> list[dict]:
        return self.stations

    def get_station(self, station_id: str) -> dict | None:
        return next((s for s in self.stations if s["id"] == station_id), None)

    def get_officers(self) -> list[dict]:
        return [{k: v for k, v in o.items() if k != "password_hash"} for o in self.officers]

    def get_officer(self, officer_id: str) -> dict | None:
        return next((o for o in self.officers if o["id"] == officer_id), None)

    def _public_officer(self, officer: dict) -> dict:
        return {k: v for k, v in officer.items() if k != "password_hash"}

    def find_officer_login(self, email: str | None, password: str | None, officer_id: str | None) -> dict:
        from app.auth import verify_secret

        def password_ok(officer: dict) -> bool:
            # Hackathon UX: blank password still allowed; if provided, accept demo keys or hash match.
            if not password:
                return True
            if password in {"demo1234", "123456"}:
                return True
            hashed = officer.get("password_hash")
            return bool(hashed) and verify_secret(password, hashed)

        if officer_id:
            officer = self.get_officer(officer_id)
            if officer and password_ok(officer):
                return self._public_officer(officer)
        if email:
            lowered = email.lower()
            match = next((o for o in self.officers if o.get("email", "").lower() == lowered), None)
            if match and password_ok(match):
                return self._public_officer(match)
            if "radhika" in lowered:
                return self.get_officers()[1]
            if "admin" in lowered or "hq" in lowered:
                return self.get_officers()[2]
            if lowered == "police@demo.in":
                return self.get_officers()[0]
        return self.get_officers()[0]

    def get_user(self, user_id: str) -> dict | None:
        return self.users.get(user_id)

    def find_user_by_phone(self, phone: str) -> dict | None:
        compact = re.sub(r"\s+", "", phone)
        for user in self.users.values():
            if re.sub(r"\s+", "", user["phone"]) == compact:
                return user
        return None

    def register_user(self, payload: dict) -> dict:
        from app.auth import hash_secret

        existing = self.find_user_by_phone(payload["phone"])
        if existing:
            raise ValueError("An account already exists for this phone number")
        user_id = f"user-{secrets.token_hex(4)}"
        user = {
            "id": user_id,
            "name": payload["name"],
            "phone": payload["phone"],
            "role": "TRAVELLER",
            "password_hash": hash_secret(payload["password"]),
            "safety_pin_hash": hash_secret(payload.get("safety_pin") or "1234"),
            "duress_pin_hash": hash_secret(payload.get("duress_pin") or "9999"),
            "biometric_enabled": payload.get("biometric_enabled", False),
            "default_checkin_minutes": payload.get("default_checkin_minutes", 10),
            "adaptive_frequency_enabled": True,
            "emergency_message": payload.get("emergency_message")
            or "SheMove Alert: I have not completed my safety check-in.",
            "is_dark_mode": True,
            "is_setup_complete": True,
            "retention_days": 30,
            "created_at": iso(),
        }
        self.users[user_id] = user
        self._audit(user_id, "REGISTER", "Traveller account created")
        self.notify()
        return user

    def update_user(self, user_id: str, patch: dict) -> dict:
        from app.auth import hash_secret

        user = self.users[user_id]
        for key in [
            "name",
            "phone",
            "biometric_enabled",
            "default_checkin_minutes",
            "adaptive_frequency_enabled",
            "emergency_message",
            "is_dark_mode",
            "is_setup_complete",
            "retention_days",
        ]:
            if key in patch and patch[key] is not None:
                user[key] = patch[key]
        if patch.get("safety_pin"):
            user["safety_pin_hash"] = hash_secret(patch["safety_pin"])
        if patch.get("duress_pin"):
            user["duress_pin_hash"] = hash_secret(patch["duress_pin"])
        if patch.get("password"):
            user["password_hash"] = hash_secret(patch["password"])
        self.notify()
        return user

    def verify_pin(self, user_id: str, pin: str) -> dict:
        from app.auth import verify_secret

        user = self.users[user_id]
        if verify_secret(pin, user.get("duress_pin_hash", "")):
            return {"valid": True, "duress": True, "kind": "DURESS"}
        if verify_secret(pin, user.get("safety_pin_hash", "")):
            return {"valid": True, "duress": False, "kind": "SAFETY"}
        return {"valid": False, "duress": False, "kind": "INVALID"}

    def list_contacts(self, user_id: str) -> list[dict]:
        return [c for c in self.contacts.values() if c.get("user_id") == user_id]

    def add_contact(self, user_id: str, payload: dict) -> dict:
        contact = {
            "id": f"c-{secrets.token_hex(4)}",
            "user_id": user_id,
            "name": payload["name"],
            "phone": payload["phone"],
            "relation": payload.get("relation") or payload.get("relationship") or "Family",
            "notify_whatsapp": payload.get("notify_whatsapp", True),
            "smsStatus": "DELIVERED",
            "is_primary": payload.get("is_primary", not self.list_contacts(user_id)),
            "is_verified": payload.get("is_verified", True),
        }
        self.contacts[contact["id"]] = contact
        self._audit(user_id, "CONTACT_ADD", f"Added trusted contact {contact['name']}")
        self.notify()
        return contact

    def update_contact(self, user_id: str, contact_id: str, patch: dict) -> dict | None:
        contact = self.contacts.get(contact_id)
        if not contact or contact.get("user_id") != user_id:
            return None
        contact.update({k: v for k, v in patch.items() if v is not None})
        self.notify()
        return contact

    def delete_contact(self, user_id: str, contact_id: str) -> bool:
        contact = self.contacts.get(contact_id)
        if not contact or contact.get("user_id") != user_id:
            return False
        del self.contacts[contact_id]
        self.notify()
        return True

    def list_geofences(self, user_id: str) -> list[dict]:
        return [g for g in self.geofences.values() if g.get("user_id") == user_id]

    def add_geofence(self, user_id: str, payload: dict) -> dict:
        fence = {
            "id": f"geo-{secrets.token_hex(4)}",
            "user_id": user_id,
            "name": payload["name"],
            "lat": payload["lat"],
            "lng": payload["lng"],
            "radius_m": payload.get("radius_m", 150),
            "notify_on_arrive": payload.get("notify_on_arrive", True),
            "notify_on_depart": payload.get("notify_on_depart", True),
        }
        self.geofences[fence["id"]] = fence
        self.notify()
        return fence

    def delete_geofence(self, user_id: str, fence_id: str) -> bool:
        fence = self.geofences.get(fence_id)
        if not fence or fence.get("user_id") != user_id:
            return False
        del self.geofences[fence_id]
        self.notify()
        return True

    def get_trips(self, station_id: str | None = None, status_filter: str | None = None) -> list[dict]:
        items = list(self.trips.values())
        if station_id and station_id != "all":
            items = [t for t in items if t.get("current_station_id") == station_id]
        if status_filter and status_filter != "ALL":
            if status_filter == "ALERT":
                items = [t for t in items if t.get("status") == "ALERT_RAISED"]
            elif status_filter == "ACTIVE":
                items = [t for t in items if t.get("status") in {"ACTIVE", "CHECKIN_PENDING", "AWAITING_VEHICLE"}]
            else:
                items = [t for t in items if t.get("status") == status_filter]
        return items

    def get_trip(self, trip_id: str) -> dict | None:
        return self.trips.get(trip_id)

    def get_trip_by_token(self, token: str) -> dict | None:
        for trip in self.trips.values():
            if trip.get("share_token") == token or trip.get("id") == token:
                return trip
        return None

    def list_user_trips(self, user_id: str) -> list[dict]:
        return sorted(
            [t for t in self.trips.values() if t.get("traveller_id") == user_id],
            key=lambda t: t.get("started_at") or "",
            reverse=True,
        )

    def active_trip_for_user(self, user_id: str) -> dict | None:
        active_states = {"DRAFT", "AWAITING_VEHICLE", "ACTIVE", "CHECKIN_PENDING", "ALERT_RAISED"}
        return next((t for t in self.list_user_trips(user_id) if t.get("status") in active_states), None)

    def get_alerts(
        self,
        station_id: str | None = None,
        status_filter: str | None = None,
        severity_filter: str | None = None,
    ) -> list[dict]:
        alerts: list[dict] = []
        for trip in self.trips.values():
            for alert in trip.get("alerts") or []:
                if station_id and station_id != "all" and alert.get("station_id") != station_id:
                    continue
                if status_filter and status_filter != "ALL" and alert.get("status") != status_filter:
                    continue
                if severity_filter and severity_filter != "ALL" and alert.get("severity") != severity_filter:
                    continue
                alerts.append(alert)

        def severity_score(value: str) -> int:
            return {"CRITICAL": 3, "HIGH": 2, "MEDIUM": 1}.get(value, 0)

        alerts.sort(key=lambda a: (severity_score(a.get("severity", "")), a.get("raised_at", "")), reverse=True)
        return alerts

    def get_stats(self, station_id: str | None = None) -> dict:
        trips = self.get_trips(station_id)
        active = [t for t in trips if t.get("status") in {"ACTIVE", "ALERT_RAISED", "CHECKIN_PENDING", "AWAITING_VEHICLE"}]
        alerts = self.get_alerts(station_id)
        open_alerts = [a for a in alerts if a.get("status") in {"OPEN", "ACKNOWLEDGED"}]
        return {
            "activeTripsCount": len(active),
            "openAlertsCount": len(open_alerts),
            "criticalAlertsCount": len([a for a in open_alerts if a.get("severity") == "CRITICAL"]),
            "highAlertsCount": len([a for a in open_alerts if a.get("severity") == "HIGH"]),
            "mediumAlertsCount": len([a for a in open_alerts if a.get("severity") == "MEDIUM"]),
            "acknowledgedTodayCount": len([a for a in alerts if a.get("status") == "ACKNOWLEDGED"]),
            "resolvedTodayCount": len([a for a in alerts if a.get("status") in {"RESOLVED", "FALSE_ALARM"}]),
            "avgAckTimeSeconds": 74,
            "activeStationsCount": len(self.stations),
        }

    def _trip_snapshot(self, trip: dict) -> dict:
        return {
            "traveller_name": trip["traveller_name"],
            "traveller_phone": trip["traveller_phone"],
            "vehicle_number": trip.get("vehicle_number") or "UNKNOWN",
            "battery_pct": trip.get("last_battery_pct") or 0,
            "accuracy_m": trip.get("last_accuracy_m") or 0,
            "speed_kmh": 0,
        }

    def _raise_alert(
        self,
        trip: dict,
        alert_type: str,
        severity: str,
        covert: bool = False,
        reason: str | None = None,
    ) -> dict:
        existing = next(
            (
                a
                for a in trip.get("alerts") or []
                if a.get("type") == alert_type and a.get("status") in {"OPEN", "ACKNOWLEDGED"}
            ),
            None,
        )
        if existing and alert_type != "SOS":
            return existing
        alert = {
            "id": f"alt-{alert_type.lower()}-{secrets.token_hex(3)}",
            "trip_id": trip["id"],
            "type": alert_type,
            "severity": severity,
            "status": "OPEN",
            "raised_at": iso(),
            "location": dict(trip.get("last_location") or {}),
            "station_id": trip.get("current_station_id"),
            "station_name": trip.get("current_station_name"),
            "covert": covert,
            "reason": reason,
            "snapshot": self._trip_snapshot(trip),
        }
        trip.setdefault("alerts", []).insert(0, alert)
        trip["status"] = "ALERT_RAISED"
        channel = "push"
        self._notify_contacts(
            trip,
            channel,
            reason or f"{alert_type} raised for {trip['traveller_name']}",
            alert_type,
        )
        self._audit("system", "ALERT", f"{alert_type} for trip {trip['id']}", {"alert_id": alert["id"]})
        self.notify()
        return alert

    def start_journey(self, user: dict, payload: dict) -> dict:
        existing = self.active_trip_for_user(user["id"])
        if existing:
            raise ValueError("An active protected journey already exists")
        now = iso()
        duration_min = int(payload.get("estimated_minutes") or payload.get("expected_duration_s", 1500) / 60)
        interval = int(payload.get("checkin_interval_minutes") or user.get("default_checkin_minutes") or 7)
        lat = payload.get("lat") or payload.get("start_lat") or 28.6139
        lng = payload.get("lng") or payload.get("start_lng") or 77.2090
        station = assign_station(lat, lng, self.stations)
        selected_ids = payload.get("contact_ids")
        user_contacts = self.list_contacts(user["id"])
        if selected_ids:
            chosen = [c for c in user_contacts if c["id"] in selected_ids]
        else:
            chosen = user_contacts
        trip_contacts = [
            {
                "id": c["id"],
                "name": c["name"],
                "phone": c["phone"],
                "relation": c.get("relation") or c.get("relationship") or "Family",
                "notify_whatsapp": c.get("notify_whatsapp", True),
                "smsStatus": "SENT",
                "is_primary": c.get("is_primary", False),
                "is_verified": c.get("is_verified", True),
            }
            for c in chosen
        ]
        destination = payload.get("destination")
        if not destination and payload.get("destination_lat"):
            destination = {"lat": payload["destination_lat"], "lng": payload["destination_lng"]}
        transport = payload.get("transport_mode") or "walking"
        vehicle = payload.get("vehicle_number")
        status = "AWAITING_VEHICLE" if transport in {"cab", "auto"} and not vehicle else "ACTIVE"
        trip = {
            "id": f"trip-{secrets.token_hex(4)}",
            "traveller_id": user["id"],
            "traveller_name": user["name"],
            "traveller_phone": user["phone"],
            "status": status,
            "started_at": now,
            "expected_duration_s": duration_min * 60,
            "ends_at": add_minutes(duration_min),
            "start_name": payload.get("start_name") or payload.get("start_address") or "Current location",
            "destination_name": payload.get("destination_name") or payload.get("destination_address") or "Destination",
            "destination": destination,
            "transport_mode": transport,
            "vehicle_number": vehicle,
            "vehicle_entered_at": now if vehicle else None,
            "vehicle_deadline_at": add_minutes(5),
            "checkin_interval_minutes": interval,
            "geofence_enabled": payload.get("geofence_enabled", True),
            "next_checkin_due_at": add_minutes(interval),
            "checkin_deadline_at": add_minutes(interval + 1),
            "last_heartbeat_at": now,
            "last_location": {"lat": lat, "lng": lng},
            "last_accuracy_m": payload.get("accuracy_m", 12),
            "last_battery_pct": payload.get("battery_pct", 80),
            "current_station_id": (station or {}).get("id"),
            "current_station_name": (station or {}).get("name"),
            "share_token": f"tok-{user['name'].lower().replace(' ', '-')}-{secrets.token_hex(3)}",
            "contacts": trip_contacts,
            "location_history": [
                {
                    "id": f"lp-{secrets.token_hex(3)}",
                    "lat": lat,
                    "lng": lng,
                    "accuracy_m": payload.get("accuracy_m", 12),
                    "speed_kmh": payload.get("speed_kmh", 0),
                    "heading": payload.get("heading", 0),
                    "battery_pct": payload.get("battery_pct", 80),
                    "is_charging": payload.get("is_charging", False),
                    "network": payload.get("network", "4G"),
                    "recorded_at": now,
                }
            ],
            "checkins": [],
            "alerts": [],
            "events": [
                {
                    "id": f"ev-{secrets.token_hex(3)}",
                    "timestamp": now,
                    "title": "Protected Journey Started",
                    "description": f"Mode: {transport}. {len(trip_contacts)} guardian(s) notified.",
                    "severity": "info",
                }
            ],
            "notifications": [],
            "waypoints": payload.get("waypoints") or [],
        }
        self.trips[trip["id"]] = trip
        self._notify_contacts(trip, "sms", f"{user['name']} started a protected journey.", "JOURNEY_STARTED")
        self._audit(user["id"], "JOURNEY_START", f"Started trip {trip['id']}")
        self.notify()
        return trip

    def record_heartbeat(self, trip_id: str, payload: dict) -> dict | None:
        trip = self.trips.get(trip_id)
        if not trip:
            return None
        now = iso()
        lat = payload.get("lat", trip["last_location"]["lat"])
        lng = payload.get("lng", trip["last_location"]["lng"])
        station = assign_station(lat, lng, self.stations)
        self._maybe_geofence(trip, lat, lng)
        trip["last_location"] = {"lat": lat, "lng": lng}
        trip["last_heartbeat_at"] = now
        trip["last_accuracy_m"] = payload.get("accuracy_m", trip.get("last_accuracy_m", 10))
        trip["last_battery_pct"] = payload.get("battery_pct", trip.get("last_battery_pct", 50))
        if station:
            trip["current_station_id"] = station["id"]
            trip["current_station_name"] = station["name"]
        point = {
            "id": f"lp-{secrets.token_hex(3)}",
            "lat": lat,
            "lng": lng,
            "accuracy_m": trip["last_accuracy_m"],
            "speed_kmh": payload.get("speed_kmh", 0),
            "heading": payload.get("heading", 0),
            "battery_pct": trip["last_battery_pct"],
            "is_charging": payload.get("is_charging", False),
            "network": payload.get("network", "4G"),
            "recorded_at": now,
        }
        trip.setdefault("location_history", []).append(point)
        trip["location_history"] = trip["location_history"][-200:]
        if trip.get("last_battery_pct", 100) <= 8:
            self._raise_alert(trip, "LOW_BATTERY_LAST_LOCATION", "MEDIUM", reason="Device battery is critically low")
        risk = assess_journey(trip)
        if any(s["code"] == "ROUTE_DEVIATION" for s in risk["signals"]):
            self._raise_alert(trip, "ROUTE_DEVIATION", "HIGH", reason="Significant route deviation detected")
        if payload.get("offline_queued"):
            trip.setdefault("events", []).append(
                {
                    "id": f"ev-{secrets.token_hex(3)}",
                    "timestamp": now,
                    "title": "Offline events synchronized",
                    "description": "Queued device events were applied after connectivity returned.",
                    "severity": "info",
                }
            )
        self.notify()
        return trip

    def _maybe_geofence(self, trip: dict, lat: float, lng: float) -> None:
        if not trip.get("geofence_enabled"):
            return
        for fence in self.list_geofences(trip["traveller_id"]):
            dist = haversine_m(lat, lng, fence["lat"], fence["lng"])
            key = f"inside_{fence['id']}"
            inside = dist <= fence["radius_m"]
            was_inside = trip.get(key, False)
            if inside and not was_inside and fence.get("notify_on_arrive"):
                self._notify_contacts(trip, "push", f"Geofence arrival near {fence['name']}", "GEOFENCE_ARRIVE")
            if was_inside and not inside and fence.get("notify_on_depart"):
                self._notify_contacts(trip, "push", f"Geofence departure from {fence['name']}", "GEOFENCE_DEPART")
            trip[key] = inside

    def set_vehicle(self, trip_id: str, vehicle_number: str, extra: dict | None = None) -> dict | None:
        trip = self.trips.get(trip_id)
        if not trip:
            return None
        trip["vehicle_number"] = vehicle_number
        trip["vehicle_entered_at"] = iso()
        if extra:
            trip["vehicle_details"] = extra
        if trip.get("status") == "AWAITING_VEHICLE":
            trip["status"] = "ACTIVE"
        self.notify()
        return trip

    def extend_trip(self, token_or_id: str, additional_minutes: int) -> dict | None:
        trip = self.get_trip_by_token(token_or_id) or self.get_trip(token_or_id)
        if not trip:
            return None
        trip["expected_duration_s"] = int(trip.get("expected_duration_s") or 0) + additional_minutes * 60
        ends = parse_iso(trip["ends_at"]) or utcnow()
        trip["ends_at"] = add_minutes(additional_minutes, ends)
        self.notify()
        return trip

    def complete_trip(self, trip_id: str, confirmed_safe: bool = True) -> dict | None:
        trip = self.trips.get(trip_id)
        if not trip:
            return None
        now = iso()
        if trip.get("destination"):
            trip["last_location"] = dict(trip["destination"])
        trip["status"] = "COMPLETED"
        trip["completed_at"] = now
        for alert in trip.get("alerts") or []:
            if alert.get("status") in {"OPEN", "ACKNOWLEDGED"}:
                alert["status"] = "RESOLVED"
                alert["resolved_at"] = now
                alert["resolution_outcome"] = "RESOLVED_SAFE" if confirmed_safe else "CLOSED"
                alert["resolution_notes"] = (
                    "Trip concluded with explicit safe-arrival confirmation."
                    if confirmed_safe
                    else "Journey closed. Location arrival is not treated as proof of safety."
                )
        if confirmed_safe:
            self._notify_contacts(trip, "push", f"{trip['traveller_name']} confirmed safe arrival.", "SAFE_ARRIVAL")
        self.notify()
        return trip

    def cancel_trip(self, trip_id: str) -> dict | None:
        trip = self.trips.get(trip_id)
        if not trip:
            return None
        trip["status"] = "CANCELLED"
        trip["completed_at"] = iso()
        self.notify()
        return trip

    def schedule_checkin(self, trip_id: str) -> dict | None:
        trip = self.trips.get(trip_id)
        if not trip or trip.get("status") in {"COMPLETED", "CANCELLED"}:
            return None
        now = iso()
        checkin = {
            "id": f"chk-{secrets.token_hex(3)}",
            "sequence": len(trip.get("checkins") or []) + 1,
            "asked_at": now,
            "deadline_at": add_minutes(1),
            "outcome": "PENDING",
        }
        trip.setdefault("checkins", []).insert(0, checkin)
        trip["status"] = "CHECKIN_PENDING"
        trip["next_checkin_due_at"] = now
        trip["checkin_deadline_at"] = checkin["deadline_at"]
        self.notify()
        return checkin

    def respond_to_checkin(self, token_or_id: str, response: str, duress: bool = False) -> bool:
        trip = self.get_trip_by_token(token_or_id) or self.get_trip(token_or_id)
        if not trip:
            return False
        now = iso()
        pending = next((c for c in trip.get("checkins") or [] if c.get("outcome") == "PENDING"), None)
        if response == "SAFE" and not duress:
            record = pending or {
                "id": f"chk-{secrets.token_hex(3)}",
                "sequence": len(trip.get("checkins") or []) + 1,
                "asked_at": sub_minutes(0.5),
                "deadline_at": add_minutes(0.5),
            }
            record.update({"responded_at": now, "response": "SAFE", "outcome": "OK"})
            if not pending:
                trip.setdefault("checkins", []).insert(0, record)
            interval = trip.get("checkin_interval_minutes") or 7
            risk = assess_journey(trip)
            interval = risk["recommended_checkin_minutes"] if trip.get("adaptive") is not False else interval
            trip["next_checkin_due_at"] = add_minutes(interval)
            trip["checkin_deadline_at"] = add_minutes(interval + 1)
            if trip.get("status") == "CHECKIN_PENDING":
                trip["status"] = "ACTIVE"
            self.notify()
            return True
        if duress:
            if pending:
                pending.update({"responded_at": now, "response": "SAFE", "outcome": "OK", "duress": True})
            self.trigger_duress_alert(trip["id"])
            return True
        trip["status"] = "ALERT_RAISED"
        unsafe = pending or {
            "id": f"chk-unsafe-{secrets.token_hex(3)}",
            "sequence": len(trip.get("checkins") or []) + 1,
            "asked_at": now,
            "deadline_at": now,
        }
        unsafe.update({"responded_at": now, "response": "UNSAFE", "outcome": "ALERTED_UNSAFE"})
        if not pending:
            trip.setdefault("checkins", []).insert(0, unsafe)
        self._raise_alert(trip, "USER_REPORTED_UNSAFE", "CRITICAL", reason="Traveller reported feeling unsafe")
        return True

    def trigger_sos(self, trip_id: str, reason: str = "Manual SOS") -> dict | None:
        trip = self.trips.get(trip_id)
        if not trip:
            return None
        return self._raise_alert(trip, "SOS", "CRITICAL", reason=reason)

    def trigger_duress_alert(self, token_or_id: str) -> dict | None:
        trip = self.get_trip_by_token(token_or_id) or self.get_trip(token_or_id)
        if not trip:
            return None
        return self._raise_alert(
            trip,
            "SOS",
            "CRITICAL",
            covert=True,
            reason="Duress PIN entered. UI should continue to look like a normal success.",
        )

    def acknowledge_alert(self, alert_id: str, officer_name: str) -> bool:
        for trip in self.trips.values():
            alert = next((a for a in trip.get("alerts") or [] if a["id"] == alert_id), None)
            if not alert:
                continue
            alert["status"] = "ACKNOWLEDGED"
            alert["acknowledged_by"] = officer_name
            alert["acknowledged_at"] = iso()
            self._audit(officer_name, "ALERT_ACK", f"Acknowledged {alert_id}")
            self.notify()
            return True
        return False

    def contact_acknowledge(self, token: str, contact_id: str | None = None) -> bool:
        trip = self.get_trip_by_token(token)
        if not trip:
            return False
        for contact in trip.get("contacts") or []:
            if contact_id and contact.get("id") != contact_id:
                continue
            contact["smsStatus"] = "LINK_OPENED"
            contact["acknowledged_at"] = iso()
        open_alert = next((a for a in trip.get("alerts") or [] if a.get("status") == "OPEN"), None)
        if open_alert:
            open_alert["contact_acknowledged_at"] = iso()
        self._audit("contact", "ALERT_ACK", f"Trusted contact opened tracking link {token}")
        self.notify()
        return True

    def resolve_alert(self, alert_id: str, officer_name: str, notes: str, outcome: str) -> bool:
        for trip in self.trips.values():
            alert = next((a for a in trip.get("alerts") or [] if a["id"] == alert_id), None)
            if not alert:
                continue
            alert["status"] = "FALSE_ALARM" if outcome == "FALSE_ALARM" else "RESOLVED"
            alert["resolved_at"] = iso()
            alert["resolution_notes"] = notes
            alert["resolution_outcome"] = outcome
            if not alert.get("acknowledged_by"):
                alert["acknowledged_by"] = officer_name
                alert["acknowledged_at"] = iso()
            has_open = any(a.get("status") in {"OPEN", "ACKNOWLEDGED"} for a in trip.get("alerts") or [])
            if not has_open and trip.get("status") == "ALERT_RAISED":
                trip["status"] = "ACTIVE"
            self._audit(officer_name, "ALERT_RESOLVE", notes, {"alert_id": alert_id, "outcome": outcome})
            self.notify()
            return True
        return False

    def dispatch_unit(
        self,
        trip_id: str,
        unit_callsign: str,
        officer_in_charge: str,
        eta_minutes: int,
        notes: str,
        actor: str = "police",
    ) -> bool:
        trip = self.trips.get(trip_id)
        if not trip:
            return False
        trip["dispatchInfo"] = {
            "dispatched_at": iso(),
            "unit_callsign": unit_callsign,
            "officer_in_charge": officer_in_charge,
            "eta_minutes": eta_minutes,
            "notes": notes,
        }
        for alert in trip.get("alerts") or []:
            if alert.get("status") == "OPEN":
                alert["status"] = "ACKNOWLEDGED"
                alert["acknowledged_by"] = f"DISPATCH ({unit_callsign})"
                alert["acknowledged_at"] = iso()
        self._audit(actor, "DISPATCH", f"{unit_callsign} assigned to {trip_id}")
        self.notify()
        return True

    def simulate_sos(self, target_trip_id: str | None = None) -> dict | None:
        trip = self.trips.get(target_trip_id) if target_trip_id else next(
            (t for t in self.trips.values() if t.get("status") == "ACTIVE"), None
        )
        if not trip:
            return None
        return self._raise_alert(trip, "SOS", "CRITICAL", reason="Simulated SOS")

    def simulate_missed_checkin(self, target_trip_id: str | None = None) -> dict | None:
        trip = self.trips.get(target_trip_id) if target_trip_id else next(
            (t for t in self.trips.values() if t.get("status") == "ACTIVE"), None
        )
        if not trip:
            return None
        checkin = {
            "id": f"chk-missed-{secrets.token_hex(3)}",
            "sequence": len(trip.get("checkins") or []) + 1,
            "asked_at": sub_minutes(1.1),
            "deadline_at": sub_minutes(0.1),
            "outcome": "ALERTED_MISSED",
        }
        trip.setdefault("checkins", []).insert(0, checkin)
        return self._raise_alert(trip, "MISSED_CHECKIN", "HIGH", reason="Simulated missed check-in")

    def simulate_kill_heartbeat(self, trip_id: str) -> dict | None:
        trip = self.trips.get(trip_id)
        if not trip:
            return None
        trip["last_heartbeat_at"] = sub_minutes(2.5)
        trip["last_battery_pct"] = 2
        return self._raise_alert(trip, "PHONE_UNREACHABLE", "HIGH", reason="Heartbeat timeout / device silent")

    def simulate_safe_checkin(self, trip_id: str) -> bool:
        return self.respond_to_checkin(trip_id, "SAFE")

    def simulate_complete_trip(self, trip_id: str) -> bool:
        return bool(self.complete_trip(trip_id, True))

    def simulate_advance_location(self, trip_id: str) -> bool:
        trip = self.trips.get(trip_id)
        if not trip or trip.get("status") in {"COMPLETED", "CANCELLED"}:
            return False
        unreachable = any(
            a.get("type") == "PHONE_UNREACHABLE" and a.get("status") in {"OPEN", "ACKNOWLEDGED"}
            for a in trip.get("alerts") or []
        )
        if unreachable:
            return False
        dest = trip.get("destination")
        last = trip.get("last_location") or {"lat": 28.61, "lng": 77.20}
        if dest:
            remaining_lat = dest["lat"] - last["lat"]
            remaining_lng = dest["lng"] - last["lng"]
            dist = math.hypot(remaining_lat, remaining_lng)
            if dist < 0.0004 and trip.get("status") == "ACTIVE":
                return bool(self.set_trip_scenario(trip_id, "done"))
            step = min(0.04, max(0.01, 0.0003 / max(dist, 0.0001)))
            new_lat = last["lat"] + remaining_lat * step + (random.random() - 0.5) * 0.0001
            new_lng = last["lng"] + remaining_lng * step + (random.random() - 0.5) * 0.0001
        else:
            new_lat = last["lat"] + (random.random() - 0.5) * 0.0005
            new_lng = last["lng"] + (random.random() - 0.5) * 0.0005
        self.record_heartbeat(
            trip_id,
            {
                "lat": new_lat,
                "lng": new_lng,
                "accuracy_m": 5.5 + random.random() * 3,
                "speed_kmh": 22 + random.randint(0, 20),
                "heading": random.randint(0, 359),
                "battery_pct": max(1, (trip.get("last_battery_pct") or 50) - 1),
            },
        )
        return True

    def set_trip_scenario(self, trip_id: str, mode: str) -> bool:
        trip = self.trips.get(trip_id)
        if not trip:
            return False
        now = iso()
        if mode == "live":
            trip["status"] = "ACTIVE"
            trip["last_heartbeat_at"] = now
            trip["last_battery_pct"] = max(trip.get("last_battery_pct") or 0, 76)
            trip["completed_at"] = None
            for alert in trip.get("alerts") or []:
                if alert.get("status") in {"OPEN", "ACKNOWLEDGED"}:
                    alert["status"] = "RESOLVED"
                    alert["resolved_at"] = now
                    alert["resolution_notes"] = "Normal journey resumed."
                    alert["resolution_outcome"] = "RESOLVED_SAFE"
        elif mode == "alert":
            self.trigger_sos(trip_id, "Demo SOS scenario")
        elif mode == "silent":
            self.simulate_kill_heartbeat(trip_id)
        elif mode == "done":
            self.complete_trip(trip_id, True)
        else:
            return False
        self.notify()
        return True

    def run_monitor_pass(self) -> None:
        timeout = get_settings().heartbeat_timeout_s
        now = utcnow()
        changed = False
        for trip in list(self.trips.values()):
            if trip.get("status") in {"COMPLETED", "CANCELLED", "DRAFT"}:
                continue
            last = parse_iso(trip.get("last_heartbeat_at"))
            if last and (now - last).total_seconds() > timeout:
                before = len(trip.get("alerts") or [])
                self._raise_alert(
                    trip,
                    "PHONE_UNREACHABLE",
                    "HIGH",
                    reason="Backend-owned heartbeat timeout. Last known location is shown, not live GPS.",
                )
                changed = changed or len(trip.get("alerts") or []) != before
            deadline = parse_iso(trip.get("checkin_deadline_at"))
            if trip.get("status") in {"CHECKIN_PENDING", "ACTIVE"} and deadline and now > deadline:
                pending = next((c for c in trip.get("checkins") or [] if c.get("outcome") == "PENDING"), None)
                if pending:
                    pending["outcome"] = "ALERTED_MISSED"
                self._raise_alert(trip, "MISSED_CHECKIN", "HIGH", reason="Missed safety check-in deadline")
                changed = True
            due = parse_iso(trip.get("next_checkin_due_at"))
            if trip.get("status") == "ACTIVE" and due and now > due:
                self.schedule_checkin(trip["id"])
                changed = True
            ends = parse_iso(trip.get("ends_at"))
            if ends and now > ends:
                self._raise_alert(
                    trip,
                    "TRIP_OVERDUE",
                    "MEDIUM",
                    reason="Expected arrival passed without safe-arrival confirmation",
                )
                changed = True
            if trip.get("status") == "AWAITING_VEHICLE":
                vehicle_deadline = parse_iso(trip.get("vehicle_deadline_at"))
                if vehicle_deadline and now > vehicle_deadline and not trip.get("vehicle_number"):
                    self._raise_alert(trip, "NO_VEHICLE_INFO", "MEDIUM", reason="Vehicle details were not entered in time")
                    changed = True
        if changed:
            self.notify()

    def sync_offline_events(self, trip_id: str, events: list[dict]) -> dict | None:
        trip = self.trips.get(trip_id)
        if not trip:
            return None
        for event in events:
            kind = event.get("type") or event.get("kind")
            if kind in {"heartbeat", "location"}:
                self.record_heartbeat(trip_id, {**event, "offline_queued": True})
            elif kind == "checkin":
                self.respond_to_checkin(trip_id, event.get("response", "SAFE"), duress=event.get("duress", False))
            elif kind == "sos":
                self.trigger_sos(trip_id, event.get("reason") or "Offline SOS queued")
            elif kind == "complete":
                self.complete_trip(trip_id, event.get("confirmed_safe", True))
        return trip

    def user_events(self, user_id: str) -> list[dict]:
        events: list[dict] = []
        for trip in self.list_user_trips(user_id):
            events.extend(trip.get("events") or [])
        events.sort(key=lambda e: e.get("timestamp") or "", reverse=True)
        return events[:100]


store = SheMoveStore()
