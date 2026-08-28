# backend

The MemoryMitra sync service — FastAPI. The Flutter app is offline-first and
fully functional without it: every user action is written to a local Hive box
and recorded in a durable outbox. This service is the destination for that
outbox once Phase 3 wires up a real `SyncTransport`.

**Status:** Phase 1 complete — a working FastAPI skeleton with in-memory
repositories, no persistence, no Firebase, no auth yet. Phase 2 (Firebase Auth
+ Firestore) and Phase 3 (real sync transport, replacing
`frontend/lib/core/services/sync_manager.dart`'s `LoopbackTransport`) are not
started.

## Layout

```
backend/
├── requirements.txt
├── .env.example              copy to .env, fill in real values (gitignored)
├── .gitignore                credential-specific patterns
└── app/
    ├── main.py                FastAPI app, CORS, router mounts, error handlers
    ├── core/
    │   ├── config.py           env-driven Settings
    │   ├── errors.py           consistent {"error": {...}} JSON shape
    │   └── dependencies.py     which repository implementation is active
    ├── api/v1/                 one router file per domain, versioned under /api/v1
    ├── models/                 internal domain models — mirror the Dart models field-for-field
    ├── schemas/                request/response DTOs
    ├── services/                thin business logic between routers and repositories
    └── repositories/
        ├── base.py              interfaces
        └── memory/               in-memory implementations (today's default)
```

## Run it

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt

uvicorn app.main:app --reload
```

Then:
- http://127.0.0.1:8000/health — unversioned liveness probe
- http://127.0.0.1:8000/api/v1/health — versioned health, also reports whether Firebase is configured
- http://127.0.0.1:8000/docs — interactive Swagger UI for every route below

## Endpoints (Phase 1)

| Router | Routes |
|---|---|
| health | `GET /health`, `GET /api/v1/health` |
| auth | `GET /api/v1/auth/me`, `POST /api/v1/auth/device` — both `501 not_implemented` until Phase 2/3 |
| patients | `GET/POST /api/v1/patients`, `GET/PUT /api/v1/patients/{id}` |
| sessions | `POST /api/v1/sessions`, `GET /api/v1/sessions?patientId=` |
| analytics | `GET /api/v1/analytics/{id}/cognitive-profile`, `GET /api/v1/analytics/{id}/weekly?series=`, `GET /api/v1/analytics/caseload`, `GET /api/v1/analytics/alerts` |
| daily | `POST /api/v1/daily/mood`, `POST /api/v1/daily/journal`, `GET /api/v1/daily?patientId=` |
| reminders | `GET /api/v1/reminders?patientId=`, `POST /api/v1/reminders`, `PATCH /api/v1/reminders/{id}?patientId=` |
| insights | `GET /api/v1/insights/{id}` — `501 not_implemented` (no Gemini, on purpose, this phase) |

All request/response bodies use camelCase JSON (matching the Dart side's field
names) via a shared `APIModel` base — see `app/models/common.py`.

Every domain router is backed by an in-memory dict repository
(`app/repositories/memory/`), so data resets on restart — the same tradeoff
the Flutter app's own `Mock*Repository` set accepts. Swapping in Firestore
(Phase 2) means adding `app/repositories/firestore/*` implementations of the
same interfaces in `app/repositories/base.py` and changing the five functions
in `app/core/dependencies.py` — no router or service code changes.

## Test

```bash
cd backend
.venv\Scripts\activate
pytest
```

## Sync (Phase 3, not built yet)

When it lands, the only Flutter-side change is a new implementation of
`SyncTransport` (`frontend/lib/core/services/sync_manager.dart`) — a single
`send(PendingOperation)` method. Nothing else in the app is aware of the
network. See the "Offline-first persistence" section of the root `README.md`
for the queue's shape and the payloads each operation carries.
