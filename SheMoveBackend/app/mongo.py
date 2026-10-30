from typing import Any

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.config import get_settings
from app.store import store

_client: AsyncIOMotorClient | None = None
_db: AsyncIOMotorDatabase | None = None


async def connect_mongo() -> AsyncIOMotorDatabase | None:
    global _client, _db
    settings = get_settings()
    try:
        _client = AsyncIOMotorClient(settings.mongodb_uri, serverSelectionTimeoutMS=1500)
        await _client.server_info()
        _db = _client[settings.mongodb_db]
        return _db
    except Exception:
        _client = None
        _db = None
        return None


async def close_mongo() -> None:
    global _client, _db
    if _client is not None:
        _client.close()
    _client = None
    _db = None


def mongo_db() -> AsyncIOMotorDatabase | None:
    return _db


def _strip_id(doc: dict) -> dict:
    data = dict(doc)
    data.pop("_id", None)
    return data


async def load_from_mongo() -> bool:
    db = mongo_db()
    if db is None:
        return False
    trips = await db.trips.find().to_list(500)
    users = await db.users.find().to_list(200)
    if not trips and not users:
        return False
    store.trips = {item["id"]: _strip_id(item) for item in trips}
    store.users = {item["id"]: _strip_id(item) for item in users}
    contacts = await db.contacts.find().to_list(500)
    store.contacts = {item["id"]: _strip_id(item) for item in contacts}
    geofences = await db.geofences.find().to_list(200)
    store.geofences = {item["id"]: _strip_id(item) for item in geofences}
    stations = await db.stations.find().to_list(50)
    if stations:
        store.stations = [_strip_id(item) for item in stations]
    officers = await db.officers.find().to_list(50)
    if officers:
        store.officers = [_strip_id(item) for item in officers]
    store.audit = [_strip_id(item) for item in await db.audit.find().sort("at", -1).to_list(200)]
    store.notifications = [_strip_id(item) for item in await db.notifications.find().sort("created_at", -1).to_list(200)]
    return True


async def persist_snapshot() -> None:
    db = mongo_db()
    if db is None:
        return

    async def replace_all(collection_name: str, items: list[dict[str, Any]]) -> None:
        collection = db[collection_name]
        await collection.delete_many({})
        if items:
            docs = [{**item, "_id": item.get("id")} for item in items if item.get("id")]
            if docs:
                await collection.insert_many(docs)

    await replace_all("trips", list(store.trips.values()))
    await replace_all("users", list(store.users.values()))
    await replace_all("contacts", list(store.contacts.values()))
    await replace_all("geofences", list(store.geofences.values()))
    await replace_all("stations", store.stations)
    await replace_all("officers", store.officers)
    await replace_all("audit", store.audit[:200])
    await replace_all("notifications", store.notifications[:200])
