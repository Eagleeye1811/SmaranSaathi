# backend

The MemoryMitra sync service — FastAPI. The Flutter app is offline-first and
fully functional without it: every user action is written to a local Hive box
and recorded in a durable outbox. This service is where that outbox drains to.

**Status:** all three phases are in. Phase 1 (routers, schemas, in-memory
repositories), Phase 2 (Firebase Auth + Firestore repositories, selected
automatically when `.env` configures Firebase) and Phase 3 (device-token auth
and the real sync endpoint, with `HttpSyncTransport` on the Flutter side) are
complete.

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
        ├── memory/               in-memory implementations (the fallback)
        └── firestore/            Firestore implementations (used once .env has Firebase)
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

## Endpoints

| Router | Routes |
|---|---|
| health | `GET /health`, `GET /api/v1/health` |
| auth | `GET /api/v1/auth/me`, `POST /api/v1/auth/role`, `POST /api/v1/auth/device` |
| patients | `GET/POST /api/v1/patients`, `GET/PUT /api/v1/patients/{id}` |
| sessions | `POST /api/v1/sessions`, `GET /api/v1/sessions?patientId=` |
| analytics | `GET /api/v1/analytics/{id}/cognitive-profile`, `GET /api/v1/analytics/{id}/weekly?series=`, `GET /api/v1/analytics/caseload`, `GET /api/v1/analytics/alerts` |
| daily | `POST /api/v1/daily/mood`, `POST /api/v1/daily/journal`, `GET /api/v1/daily?patientId=` |
| reminders | `GET /api/v1/reminders?patientId=`, `POST /api/v1/reminders`, `PATCH /api/v1/reminders/{id}?patientId=` |
| caregivers | `POST /api/v1/caregivers/links`, `GET /api/v1/caregivers/{id}/patients` |
| doctors | `GET /api/v1/doctors/caseload` |
| alerts | `GET /api/v1/alerts` |
| sync | `POST /api/v1/sync/operations` |
| insights | `GET /api/v1/insights/{id}` — `501 not_implemented` (the AI layer runs on the device) |

All request/response bodies use camelCase JSON (matching the Dart side's field
names) via a shared `APIModel` base — see `app/models/common.py`.

Which repository set is live is decided in one place, `app/core/dependencies.py`:
Firestore when `.env` supplies `FIREBASE_PROJECT_ID` and
`GOOGLE_APPLICATION_CREDENTIALS`, and the in-memory dicts otherwise. No router
or service code differs between the two.

## Test

```bash
cd backend
.venv\Scripts\activate
pytest
```

## Sync

`POST /api/v1/sync/operations` takes one queued `PendingOperation` at a time and
applies it exactly once. `operationId` (the Flutter-generated id) is checked
against the ledger first; a retry returns `status: "duplicate"` without
re-applying anything.

Operation kinds, each with its own payload schema in `app/schemas/sync.py`:

| Kind | Effect |
|---|---|
| `gameSession` | Appends a session, keyed by `operationId` so a retry cannot duplicate it |
| `moodCheckIn` · `journalEntry` · `reminderToggle` | Day-scoped writes, naturally idempotent |
| `profileUpdate` | Updates the stored patient name |
| `assessmentUpdate` | One completed intake step; answers pass through as written, since the questionnaire keeps changing shape |
| `baselineCaptured` | The frozen personal baseline — domain scores, capture time, session count |
| `reflection` · `unknown` | Recorded in the ledger only |

An unrecognised kind is a client/server version mismatch and is rejected with
422 rather than silently swallowed.

On the Flutter side this is `HttpSyncTransport`, selected with
`--dart-define=MM_SYNC_BASE_URL=...`. Auth is a device token
(`POST /api/v1/auth/device`), minted once and re-minted on a 401 — it proves "a
copy of MemoryMitra is calling", not "this is a specific person".
