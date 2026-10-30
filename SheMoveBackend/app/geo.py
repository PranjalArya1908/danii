from math import asin, cos, radians, sin, sqrt


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371000.0
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return 2 * r * asin(sqrt(a))


def point_in_polygon(lat: float, lng: float, polygon: list[list[float]]) -> bool:
    if len(polygon) < 3:
        return False
    inside = False
    j = len(polygon) - 1
    for i, (yi, xi) in enumerate(polygon):
        yj, xj = polygon[j]
        intersects = ((xi > lng) != (xj > lng)) and (
            lat < (yj - yi) * (lng - xi) / ((xj - xi) or 1e-12) + yi
        )
        if intersects:
            inside = not inside
        j = i
    return inside


def assign_station(lat: float, lng: float, stations: list[dict]) -> dict | None:
    for station in stations:
        polygon = station.get("jurisdictionPolygon") or []
        if point_in_polygon(lat, lng, polygon):
            return station
    nearest = None
    best = float("inf")
    for station in stations:
        loc = station.get("location") or {}
        dist = haversine_m(lat, lng, loc.get("lat", 0), loc.get("lng", 0))
        if dist < best:
            best = dist
            nearest = station
    return nearest
