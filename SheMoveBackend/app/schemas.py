from typing import Any, Literal

from pydantic import BaseModel, Field


class TravellerRegister(BaseModel):
    name: str
    phone: str
    password: str
    safety_pin: str = "1234"
    duress_pin: str = "9999"
    biometric_enabled: bool = False


class TravellerLogin(BaseModel):
    phone: str
    password: str


class PoliceLogin(BaseModel):
    email: str | None = None
    password: str | None = None
    officerId: str | None = None


class ProfileUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    biometric_enabled: bool | None = None
    default_checkin_minutes: int | None = None
    adaptive_frequency_enabled: bool | None = None
    emergency_message: str | None = None
    is_dark_mode: bool | None = None
    is_setup_complete: bool | None = None
    retention_days: int | None = None
    safety_pin: str | None = None
    duress_pin: str | None = None
    password: str | None = None


class PinVerify(BaseModel):
    pin: str


class ContactCreate(BaseModel):
    name: str
    phone: str
    relation: str | None = None
    relationship: str | None = None
    notify_whatsapp: bool = True
    is_primary: bool | None = None


class ContactUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    relation: str | None = None
    notify_whatsapp: bool | None = None
    is_primary: bool | None = None


class GeofenceCreate(BaseModel):
    name: str
    lat: float
    lng: float
    radius_m: float = 150
    notify_on_arrive: bool = True
    notify_on_depart: bool = True


class JourneyStart(BaseModel):
    start_name: str | None = None
    start_address: str | None = None
    destination_name: str | None = None
    destination_address: str | None = None
    start_lat: float | None = None
    start_lng: float | None = None
    lat: float | None = None
    lng: float | None = None
    destination_lat: float | None = None
    destination_lng: float | None = None
    destination: dict[str, float] | None = None
    transport_mode: str = "walking"
    vehicle_number: str | None = None
    estimated_minutes: int = 25
    checkin_interval_minutes: int = 7
    geofence_enabled: bool = True
    contact_ids: list[str] | None = None
    waypoints: list[dict[str, Any]] = Field(default_factory=list)
    battery_pct: int = 80
    accuracy_m: float = 12
    speed_kmh: float = 0
    heading: float = 0
    network: str = "4G"


class HeartbeatIn(BaseModel):
    lat: float
    lng: float
    accuracy_m: float = 10
    speed_kmh: float = 0
    heading: float = 0
    battery_pct: int = 50
    is_charging: bool = False
    network: str = "4G"
    offline_queued: bool = False


class VehicleIn(BaseModel):
    vehicle_number: str
    vehicle_type: str | None = None
    driver_name: str | None = None
    notes: str | None = None


class ExtendIn(BaseModel):
    additional_minutes: int = 15
    pin: str | None = None


class CheckinIn(BaseModel):
    response: Literal["SAFE", "UNSAFE"] = "SAFE"
    pin: str | None = None
    biometric: bool = False


class SosIn(BaseModel):
    reason: str = "Manual SOS"
    pin: str | None = None


class CompleteIn(BaseModel):
    confirmed_safe: bool = True


class OfflineSyncIn(BaseModel):
    events: list[dict[str, Any]]


class TrackActionIn(BaseModel):
    action: str
    pin: str | None = None
    additionalMinutes: int = 15
    response: Literal["SAFE", "UNSAFE"] | None = None
    subAction: str | None = None
    mode: str | None = None
    contact_id: str | None = None


class AlertAckIn(BaseModel):
    officerName: str | None = None


class AlertResolveIn(BaseModel):
    notes: str | None = None
    outcome: str = "RESOLVED_SAFE"
    officerName: str | None = None


class DispatchIn(BaseModel):
    tripId: str
    unitCallsign: str | None = None
    officerInCharge: str | None = None
    etaMinutes: int | None = None
    notes: str | None = None


class SimulateIn(BaseModel):
    action: str
    tripId: str | None = None
