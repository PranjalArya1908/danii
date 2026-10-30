from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from app.config import get_settings
from app.mongo import close_mongo, connect_mongo, load_from_mongo, persist_snapshot
from app.monitor import monitor
from app.routers import app as app_router
from app.routers import auth, demo, journeys, police, public
from app.store import store


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    db = await connect_mongo()
    loaded = False
    if db is not None:
        loaded = await load_from_mongo()
    if settings.seed_on_start and not loaded:
        store.seed()
        await persist_snapshot()
    await monitor.start()
    yield
    await monitor.stop()
    await persist_snapshot()
    await close_mongo()


settings = get_settings()
api = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="FastAPI backend for the SheMove mobile app, trusted-contact dashboard, and police dashboard.",
    lifespan=lifespan,
)

api.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=False if settings.cors_origin_list == ["*"] else True,
    allow_methods=["*"],
    allow_headers=["*"],
)

api.include_router(auth.router)
api.include_router(app_router.router)
api.include_router(journeys.router)
api.include_router(public.router)
api.include_router(police.router)
api.include_router(demo.router)


@api.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")


@api.get("/health")
def health():
    from app.mongo import mongo_db

    return {
        "ok": True,
        "service": settings.app_name,
        "mongo": mongo_db() is not None,
        "trips": len(store.trips),
        "users": len(store.users),
    }
