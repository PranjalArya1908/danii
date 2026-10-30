# SheMove Backend

FastAPI + MongoDB backend that connects the Flutter **SheMoveApp**, the **trusted-contact** Next.js dashboard, and the **police** Next.js dashboard.

This service owns authentication, journey monitoring, adaptive check-in deadlines, risk signals, incident escalation, notification records, and realtime dashboard updates. The mobile app and both dashboards are left unchanged for now; they can switch from local mock/Next API routes to this service later.

## Stack

- **FastAPI** — REST + Server-Sent Events
- **In-memory store** — hackathon-ready, seeded on start
- **MongoDB (optional)** — persists snapshots when available via Motor
- **Background monitor** — heartbeat timeouts, missed check-ins, overdue journeys

## Quick start

```bash
cd SheMoveBackend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env

# optional MongoDB
docker compose up -d

uvicorn app.main:api --reload --host 0.0.0.0 --port 8000
```

- Health: [http://localhost:8000/health](http://localhost:8000/health)
- OpenAPI docs: [http://localhost:8000/docs](http://localhost:8000/docs)

If MongoDB is down, the API still runs entirely in memory.

## Demo credentials

| Role | Identity | Secret |
|------|----------|--------|
| Traveller (Aanya Rao) | phone `+91 98112 34567` | password `demo1234`, safety PIN `1234`, duress PIN `9999` |
| Police SHO | `police@demo.in` | `demo1234` |
| Police ACP | `radhika@demo.in` | `demo1234` |
| Police Admin | `admin@demo.in` | `demo1234` |

Sample share tokens come from seeded trips (for example Priya Sharma’s SOS trip). After login/journey start, use `trip.share_token` with `/api/v1/public/track/{token}`.

## Product mapping

| Client | Responsibility | Backend surface |
|--------|----------------|-----------------|
| SheMoveApp (Flutter) | Onboarding, PIN/duress, contacts, start journey, heartbeat, gesture check-in, SOS, completion, history | `/api/v1/auth/traveller/*`, `/api/v1/me`, `/api/v1/contacts`, `/api/v1/geofences`, `/api/v1/journeys/*`, `/api/v1/events` |
| Trusted-contact dashboard | Live trip share link, modify time, contact ack, check-in visibility | `/api/v1/public/track/{token}`, SSE `/stream` |
| Police dashboard | Queue, map, ack/resolve, dispatch, stations, demo simulate | `/api/v1/auth/police/login`, `/api/v1/police/*`, `/api/v1/demo/*` |

Route shapes intentionally mirror the existing Next.js `/api/v1/...` mock routes in `SheMoveTrustedContact` so dashboards can point `NEXT_PUBLIC_API_BASE` (or equivalent) at this server later without redesign.

## Core API

### Auth
- `POST /api/v1/auth/traveller/register`
- `POST /api/v1/auth/traveller/login`
- `POST /api/v1/auth/police/login`

### Traveller profile & guardians
- `GET|PATCH /api/v1/me`
- `POST /api/v1/me/pins/verify` — returns `kind: SAFETY | DURESS | INVALID` without revealing duress in UI copy
- `GET|POST /api/v1/contacts`, `PATCH|DELETE /api/v1/contacts/{id}`
- `GET|POST /api/v1/geofences`, `DELETE /api/v1/geofences/{id}`
- `GET /api/v1/events`, `GET /api/v1/notifications`

### Journeys (mobile)
- `POST /api/v1/journeys` — start protected journey
- `GET /api/v1/journeys`, `GET /api/v1/journeys/active`, `GET /api/v1/journeys/{id}`
- `GET /api/v1/journeys/{id}/risk` — transparent rule-based score (not a crime verdict)
- `POST /api/v1/journeys/{id}/heartbeat` / `location`
- `POST /api/v1/journeys/{id}/vehicle`
- `POST /api/v1/journeys/{id}/extend` — duress PIN triggers covert SOS while returning a normal success payload
- `POST /api/v1/journeys/{id}/checkin/due`, `POST /api/v1/journeys/{id}/checkin`
- `POST /api/v1/journeys/{id}/sos`
- `POST /api/v1/journeys/{id}/complete`, `POST /api/v1/journeys/{id}/cancel`
- `POST /api/v1/journeys/{id}/offline-sync` — flush queued heartbeats / SOS / check-ins

### Trusted contacts (public share link)
- `GET /api/v1/public/track/{token}`
- `POST /api/v1/public/track/{token}` — actions: `modify_time`, `checkin_response`, `sos`, `ack`, `simulate`
- `GET /api/v1/public/track/{token}/stream` — SSE

### Police
- `GET /api/v1/police/stations|trips|alerts|stats|audit`
- `GET /api/v1/police/trips/{id}`
- `POST /api/v1/police/alerts/{id}/ack|resolve`
- `POST /api/v1/police/dispatch`
- `GET /api/v1/police/stream` — SSE snapshot/update feed

### Demo / hackathon
- `POST /api/v1/demo/seed`
- `POST /api/v1/demo/simulate` — `sos`, `missed_checkin`, `kill_heartbeat`, `safe_checkin`, `advance_location`, `complete_trip`, `seed`

## Behaviour notes

- **Backend-owned deadlines** — the monitor loop raises `MISSED_CHECKIN`, `PHONE_UNREACHABLE`, `TRIP_OVERDUE`, and `NO_VEHICLE_INFO` even if the phone is closed.
- **Duress PIN** — check-in/extend/SOS with PIN `9999` creates a covert `SOS` alert while responses still look like normal success.
- **Location freshness** — public track payload marks `LIVE` vs `LAST_KNOWN`.
- **Risk engine** — rule-based signals (stale heartbeat, delay, route deviation, battery, pending check-in, night hours). Explicit SOS is never blocked by a low score.
- **Police jurisdiction** — trips/alerts can be filtered by station; HQ/`ADMIN` sees all. `DEMO_OPEN_POLICE=true` allows unauthenticated police reads for local UI prototyping.
- **Notifications** — recorded as simulated push/SMS delivery statuses (no real SMS/WhatsApp gateway in the prototype).

## Environment

See `.env.example`:

| Variable | Default | Meaning |
|----------|---------|---------|
| `SECRET_KEY` | hackathon default | JWT + PIN hash material |
| `MONGODB_URI` | `mongodb://localhost:27017` | optional persistence |
| `MONGODB_DB` | `shemove` | database name |
| `CORS_ORIGINS` | `*` | comma-separated origins or `*` |
| `HEARTBEAT_TIMEOUT_S` | `90` | unreachable threshold |
| `MONITOR_INTERVAL_S` | `5` | monitor tick |
| `DEMO_OPEN_POLICE` | `true` | open police APIs without JWT |
| `SEED_ON_START` | `true` | load demo trips/users when Mongo empty |

## Project layout

```
SheMoveBackend/
  app/
    main.py          # FastAPI entry + lifespan
    config.py
    auth.py          # JWT + PIN hashing
    store.py         # domain operations
    seed.py          # Delhi demo stations/trips/users
    risk.py          # adaptive check-in / anomaly rules
    monitor.py       # escalation worker
    realtime.py      # SSE broker
    mongo.py         # optional Motor persistence
    routers/         # auth, traveller, journeys, public, police, demo
  docker-compose.yml # Mongo only
  requirements.txt
```

## Next integration steps (clients unchanged for now)

1. Point trusted-contact / police fetch URLs at `http://localhost:8000`.
2. Add a Flutter repository that calls journey/auth endpoints instead of local-only state.
3. Replace simulated notification records with SMS / FCM / WhatsApp Business when credentials exist.
4. Keep duress behaviour identical on the client: never show a special “duress accepted” animation.
