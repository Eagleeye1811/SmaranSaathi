# MemoryMitra (SmaranSaathi) — Complete Project Description

> **From the first memory concern to clinician-ready insight.**
>
> An offline-first, AI-assisted cognitive health monitoring platform built for the
> languages, culture and connectivity of India's North Eastern Region.

| | |
|---|---|
| **Product name** | MemoryMitra — *mitra*, "friend"; also shipped under the name **SmaranSaathi** (repository / Android notification channel) |
| **Repository** | `github.com/Eagleeye1811/SmaranSaathi` |
| **Package name** | `memory_mitra` |
| **Version** | 1.0.0+1 |
| **Client** | Flutter 3.32+ / Dart 3.8+ — Android · iOS · Web (PWA) |
| **Server** | FastAPI (Python 3.12) + Firebase Auth + Firestore, deployable to Render |
| **Scale** | ~49,400 lines of Dart across 134 files · ~7,400 lines of tests · ~3,400 lines of Python |
| **Languages in-app** | English · Hindi (हिन्दी) · Assamese (অসমীয়া) · Marathi (मराठी) — 1,154 localized strings |

---

## 1. The problem

People notice cognitive changes long before they know what those changes mean.
Is this normal ageing? Is it getting worse? What should be tracked? When is it
time to see a doctor?

By the time a clinician is finally reached, they get fifteen minutes and a
single snapshot of a person they have never measured before — no history, no
personal baseline, no structured record of function or symptoms.

In India's North Eastern Region that gap is widened by three further realities:

- **Language.** Assessment instruments and health apps are English-first; the
  patient is not.
- **Connectivity.** The network is intermittent. An app that needs a server to
  work does not work.
- **Cultural distance.** Generic cognitive "brain games" reference objects,
  procedures and music that mean nothing to the person playing them, which
  makes them both less engaging and less valid as a measure.

## 2. What MemoryMitra is

MemoryMitra is **not a game app with a chart on top**. The six cognitive
activities are one input among several; the product is the **longitudinal
cognitive health profile** they feed.

```
        PATIENT
           │
    ┌──────┴──────┐
    │  SYMPTOMS   │  structured, grouped by domain
    │  FUNCTION   │  how independently daily life still works
    │  HISTORY    │  conditions, sleep, mood, medication
    │  CAREGIVER  │  an independent second account
    └──────┬──────┘
           ▼
   SIX COGNITIVE ACTIVITIES  ──▶  accuracy · pace · errors · hints · completion
           │
           ▼
    PERSONAL BASELINE  ──▶  every later result is a deviation from *this*
           │
           ▼
   COGNITIVE PROFILE + TRENDS
           │
    ┌──────┴──────┐
    ▼             ▼
 AI COMPANION   CLINICAL REPORT ──▶ DOCTOR ──▶ CARE PLAN ──▶ CONTINUOUS CARE
```

### What it deliberately will not do

It does not detect, diagnose or exclude dementia or any other condition, and it
shows **no disease probabilities**. A confident "Alzheimer's 78%" would demo
well and would be indefensible without a validated model. The app reports
*patterns*, always alongside the inputs that produced them, and says plainly
that a clinician decides what they mean. The refusal is enforced in code:
`HealthAssistant.diagnosisGuard` runs *before* any model is consulted, so it
cannot be talked around by rephrasing the question.

## 3. Who it is for — three roles, three shells

| Role | What they get |
|---|---|
| **Patient** | Structured intake, a personal baseline assessment, six adaptive activities, weekly monitoring against their own baseline, a data-aware AI companion, voice navigation, a memory wallet, and a doctor-ready summary. |
| **Caregiver** | Patient profile creation, an independent observation record, day-to-day oversight, engagement and adherence analytics, reminder management, and a GPS safe-zone with wandering alerts. |
| **Clinician** | Longitudinal performance trends across a caseload, per-domain cognitive profiles, patient detail views, and an alerts feed that surfaces meaningful change. |

Each role has its own shell (`patient_shell.dart`, `caregiver_shell.dart`,
`doctor_shell.dart`) and its own theme, so a doctor never confuses their view
with the patient's.

## 4. The patient journey — nineteen screens, one story

Each step writes through to disk as it is answered, so an intake abandoned half
way resumes at the next unanswered question rather than at the beginning.

| # | Screen | Why it exists |
|---|---|---|
| 01 | Splash | Two seconds, then out of the way |
| 02 | Welcome | What the product is — and what it is not — before the first tap |
| 03 | Sign in | Firebase Auth, or skipped entirely when Firebase is not configured |
| 04 | Consent | What is collected, what it builds, and that it is not a diagnosis |
| 05 | Profile | Age, language and education, because they change how a score reads |
| 06 | Reason for using the app | Concerns, onset window, and how they have changed |
| 07 | Safety check | Sudden onset or red-flag symptoms route to urgent care, not to monitoring |
| 08 | Symptom assessment | 23 items across memory, attention, language, behaviour, movement |
| 09 | Daily function | Eight activities, independent → needs help → full help |
| 10 | Medical & lifestyle | Conditions, sleep, mood, medications — what else could move a score |
| 11 | Caregiver observations | An independent second account, kept separate in the report |
| 12 | Baseline intro | The framing: this is your starting point, not an exam |
| 13 | Baseline run | Six activities, resumable, progress persisted after each |
| 14 | Cognitive profile | Six domains vs baseline, radar chart, observed patterns |
| 15 | Home dashboard | Status, today's activity, trends, companion, care plan |
| 16 | Progress | Weekly trend, adherence, consistency, functional independence |
| 17 | Companion | Six data-grounded quick actions; refuses to diagnose |
| 18 | Doctor report | The whole record as one shareable summary |
| 19 | Care plan | What happens next, generated from the person's own record |

The intake can also be completed **by voice** (`voice_intake_controller.dart`,
`voice_intake_matcher.dart`) for someone who cannot or will not type.

## 5. Core capabilities

### 5.1 Personalised by construction

Personalisation is the substrate, not a setting. During onboarding the caregiver
records who the patient is, who matters to them, what they did for a living,
what they cook, where they have lived, and how their day is shaped. Every
downstream surface consumes that profile (`PersonalizationService`):

```
Occupation: Weaver          → weaving motifs and loom procedures in her activities
Daughter: Priya             → the companion asks after Priya by name
Favourite food: Pitha       → cooking steps replace generic tasks
Location: Jorhat, Assam     → dhol, pepa and gogona replace generic tones
Language: Assamese          → content and spoken prompts in her language
```

### 5.2 Mitra, the companion

One character present through the whole patient experience, with seven emotional
states — idle, happy, thinking, encouraging, celebrating, listening and gentle.
Mitra breathes, blinks and reacts (`core/widgets/companion.dart`, three
animation controllers), and is the voice of every prompt, recommendation and
piece of feedback. The patient is never addressed by an interface; they are
addressed by someone.

### 5.3 Six cognitive activities

| Activity | Cognitive domain | Progression |
|---|---|---|
| **Procedure Reconstruction** | Procedural / executive | 4 steps → 5 → 6 → reduced visual assistance → a procedure from the patient's own working life |
| **Finish the Story** | Language & reasoning | Story recall → everyday decision-making → open storytelling about the patient's own photographs |
| **Familiar Place Explorer** | Visuospatial | 3 objects / 3 rooms / 3 hints → 4 objects / 5 rooms / 1 hint, on an Assam-type house floor plan |
| **Melody of the Valleys** | Auditory processing | 2-note sequences → 5, with tempo increases, using dhol, pepa and gogona |
| **Weaves of the Hills** | Attention | Match a motif → complete one → rebuild from a covered pattern → rebuild from a short preview |
| **NER Memory Cards** | Memory | 4 pairs → 6 → 8 → 12, using the one-horned rhino, japi, xorai, bamboo, paddy and the Brahmaputra |

Every activity ends on the same encouraging result screen — never framed as an
exam — and feeds the same adaptive engine.

### 5.4 Adaptive difficulty

Each session records **accuracy, focus, memory, hint usage, mistakes, pace and
completion**. `AdaptiveDifficultyService` returns one of three decisions —
*increase*, *maintain*, *decrease* — with its reasoning, shown to the patient in
plain language and to the caregiver as an audit trail.

```
accuracy > 85% and ≤ 1 hint          → increase
accuracy 60–85%                      → maintain
accuracy < 60%, or left unfinished   → decrease
```

Pace is a secondary signal: an excellent but unusually slow session holds the
level rather than raising it, so difficulty never outruns the person.

### 5.5 Three levels of measurement

| Level | What it is | Where it lives |
|---|---|---|
| **1 · Session** | Accuracy, focus, recall, hints, mistakes, attempts, correct responses, mean response time, completion | `GamePerformance` |
| **2 · Domain** | Sessions grouped by the function they exercise, averaged over the last four | `CognitiveMonitoringService.domainScores` |
| **3 · Longitudinal** | Deviation from the personal baseline, trend, consistency, adherence, functional change | `MonitoringSnapshot` |

Activities map to domains only where the mapping is defensible — the six were
not built to a standard battery, and the app says so rather than borrowing the
authority of one.

### 5.6 The personal baseline

The first complete pass through the six activities is frozen as the person's
baseline. Everything afterwards is reported as a deviation from it, never
against a population norm the app does not have.

```
change from baseline < 5 points   → within normal variation
change ≥ 5 points                 → a trend worth reporting
two declining domains, or one
  plus reported functional
  difficulty                      → suggest discussing with a clinician
```

The five-point floor is deliberate: repeated sessions of the same activity vary
by that much for reasons unrelated to cognition, and an app that calls every dip
a decline is an app people stop opening.

### 5.7 The AI layer

The companion is **data-aware and safety-constrained, not a chatbot**. Six quick
actions replace an empty text box, because a blank prompt asks a worried person
to already know what to ask:

`explainResults` · `whyChanged` · `prepareForDoctor` · `whatToMonitor` ·
`aboutDementia` · `howAmIDoing`

Architecture (`lib/core/ai/`):

```
AiController
    │
    ▼
ResilientAiService ──── offline, or no key? ──▶ OnDeviceAiService  (no network, instant)
    │
    └── online ──▶ GeminiAiService ──▶ Gemini (direct key, or via AI_PROXY_URL)
                        │
                        └── any failure ──▶ OnDeviceAiService, reported via lastFailure
```

- Every answer carries its `AiSource`, so nothing on screen can pass a
  locally-computed sentence off as a model's work.
- Configuration comes from `frontend/.env` (gitignored) or `--dart-define`;
  `--dart-define` wins. A missing key is not an error — the on-device service
  answers instead.
- `AI_PROXY_URL` points the app at the backend, which holds the key, because an
  API key bundled into a mobile binary can be extracted by anyone who installs it.
- `AI_REDACT_IDENTITY` strips patient identity from outgoing context.
- `AiContextBuilder` assembles the prompt from the person's own record, so
  answers are grounded in their data rather than generic.

### 5.8 Voice — navigation, assistant and intake

`lib/core/voice/` is a full spoken interface layer, not a read-aloud toggle:

- **`VoiceNavigationController`** — spoken navigation across all three roles.
  One `VoiceDestination` enum covers every destination; each shell declares only
  the ones it can actually reach, so asking the doctor app for the memory wallet
  gets a *spoken* "you cannot get there from here" rather than a silent no-op.
- **`VoiceNavAction`** — `back`, `help` (reads the list of destinations aloud),
  `stop`.
- **`VoiceAssistantController`** — "Ask Mitra", a spoken question answered
  through the same AI layer.
- **`VoiceIntakeController` / `VoiceIntakeMatcher`** — the questionnaire answered
  by speaking.
- **`VoiceLanguage`** — English, Hindi, Assamese, Marathi, each with several
  BCP-47 candidate tags because engines disagree (`en_IN` vs `en-IN` vs `en`).
  Assamese and Marathi degrade to Hindi *before* English, since a speaker of
  either is far more likely to follow Hindi.
- Engines sit behind adapters (`speech_to_text_recognizer.dart`,
  `flutter_tts_synthesizer.dart`) so the controllers are testable with
  `fake_async` and no device.

### 5.9 Safe zone — wandering detection

`SafeZoneMonitor` + `LocationService` + `flutter_map` (OpenStreetMap tiles, no
API key required). A naive `distance > radius → alarm` produces an unusable
product: consumer GPS drifts tens of metres while a phone sits still. Three
guards, in order:

1. **Accuracy buffer** — a fix accurate to ±80 m cannot prove anyone left a
   100 m zone, so a reading must be outside by more than its own stated error.
2. **Confirmation** — one qualifying fix is a suspicion; two consecutive are a fact.
3. **Re-entry hysteresis** — coming back has to be *properly* back, or someone
   standing on the boundary alerts every few seconds.

The domain layer (`core/models/safety.dart`) defines its own `GeoPoint` with
haversine distance and compass bearing rather than depending on `latlong2`, so
every rule is testable without a device or a tile server. The patient sees a
`ReturnHomeBanner` with a bearing — "the way home is behind you" is more use
than a blue line they cannot follow.

### 5.10 Reminders and notifications

`LocalNotificationService` schedules high-importance heads-up banners for
medicine and activity reminders, with a graceful `false` return on any platform
that has no notification channel (widget tests, desktop, a refused permission).
Server-side, `scheduler.py` + `sms_service.py` (APScheduler + Twilio) can send
SMS reminders; all three Twilio settings must be present or sending is skipped
silently.

### 5.11 Offline-first

Connectivity across the region is intermittent, so the app assumes it. All game
content, illustrations, audio cues and the patient's memory profile live on the
device. Sessions completed without a connection are written to a durable local
queue and reconciled when the network returns; a connectivity indicator in every
header shows the current state and the size of the pending queue.

The caregiver's "work offline" switch is a genuine offline state, not a mock —
it forces the connectivity layer offline on a device that is online. It can only
force *offline*: no switch conjures a connection that does not exist.

### 5.12 Accessibility as a product surface

Text size, high contrast, reduced motion and spoken prompts are patient settings
that the **caregiver can change on the patient's behalf**, and they apply live
across the whole application. Patient mode uses 68 px touch targets, 20 px body
text, five permanently-labelled destinations, and requires no typing anywhere.

### 5.13 Localization

`lib/l10n/` — 1,154 keys across `app_en.arb`, `app_hi.arb`, `app_as.arb`,
`app_mr.arb`, with a hand-maintained `app_localizations.g.dart` and a
`LocaleController` for live switching. `content_labels.dart` localizes game
content, and `assessment_l10n.dart` covers the intake.

---

## 6. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Presentation                                                │
│  patient · caregiver · clinician  —  three themed shells     │
└───────────────────────────┬──────────────────────────────────┘
                            │  AppScope (InheritedNotifier)
┌───────────────────────────▼──────────────────────────────────┐
│  Domain services                                             │
│  AdaptiveDifficulty · Personalization · CognitiveMonitoring  │
│  SafeZoneMonitor · SyncManager · AiController · Voice*       │
│  AppState — session, journal, difficulty, sync queue         │
└───────────────────────────┬──────────────────────────────────┘
                            │  repository interfaces
┌───────────────────────────▼──────────────────────────────────┐
│  Data — repository interfaces                                │
│  Patient · Game · Analytics · Reminder                       │
│  Daily · Settings · Sync                                     │
├──────────────────────────────┬───────────────────────────────┤
│  Hive implementations        │  Mock implementations         │
│  (the shipped app)           │  (tests, pure demo)           │
└──────────────┬───────────────┴───────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────────────────┐
│  Local storage — Hive boxes on device / IndexedDB on web     │
│              ──▶ durable outbox ──▶ FastAPI ──▶ Firestore    │
└──────────────────────────────────────────────────────────────┘
```

**Rules the codebase holds to:**

- Screens depend only on repository **interfaces**, never on a concrete
  implementation. No widget imports Hive.
- State is a single `ChangeNotifier` exposed through an `InheritedNotifier` —
  no state-management dependency, no hidden global state, and every screen
  subscribes to exactly what it reads.
- `AppState` holds an in-memory read model, so every getter is synchronous and
  no screen awaits IO.
- Swapping the local store for a remote one means writing new implementations
  and changing constructor arguments in `AppState` — no screen changes.
- Optional dependencies degrade rather than fail: no Firebase → sign-in step is
  skipped; no `.env` → on-device AI; no `MM_SYNC_BASE_URL` → loopback transport;
  Hive unopenable → in-memory session and the app still starts.

---

## 7. Repository layout

```
DementiaApp/
├── frontend/            the Flutter application (Android · iOS · web)
├── backend/             the FastAPI sync service
├── web/ · windows/      additional platform shells
├── render.yaml          Render blueprint for the backend
├── README.md
└── PROJECT_DESCRIPTION.md   (this file)
```

```
frontend/lib/
├── main.dart                           .env load, storage bootstrap, auth restore
├── app/
│   ├── app.dart                        root widget, live accessibility scaling
│   ├── bootstrap.dart                  opens local storage, hydrates state
│   ├── routes/app_routes.dart          shared page transitions
│   └── theme/                          colors · typography · warm + clinical themes
├── core/
│   ├── models/                         patient · game · daily · clinical · assessment
│   │                                   monitoring · report · safety · settings ·
│   │                                   memory_fragment · auth_user
│   ├── services/                       app_state · sync_manager · connectivity ·
│   │                                   adaptive_difficulty · personalization ·
│   │                                   cognitive_monitoring · auth · firebase_auth ·
│   │                                   http_sync_transport · location ·
│   │                                   notification · safe_zone_monitor
│   ├── ai/                             ai_controller · ai_context_builder ·
│   │                                   gemini · on_device · resilient · health_assistant
│   ├── voice/                          navigation · assistant · intake · language ·
│   │                                   speech_engines + adapters
│   └── widgets/                        companion · illustration · motifs · charts ·
│                                       celebration · ui_kit · app_nav_bar ·
│                                       voice_nav_host · brand · account_section
├── l10n/                               en · hi · as · mr, locale controller
├── data/
│   ├── mock/                           content catalogue, 12-week demo journey
│   ├── local/                          Hive adapters, boxes, sync queue model
│   └── repositories/                   interfaces + Hive and mock implementations
└── features/
    ├── auth/                           splash · sign in · role selection
    ├── intake/                         the 19-step journey + voice intake panel
    ├── patient/                        home · today · games ×6 · memories ·
    │                                   memory_home · health · assistant · voice ·
    │                                   safety · settings · profile
    ├── caregiver/                      dashboard · onboarding · memory_profile ·
    │                                   activity · reminders · safety · profile
    └── doctor/                         overview · patients · analytics · alerts · profile
```

---

## 8. Data and persistence

Everything the user generates is written to a local Hive box first; reaching a
server is a later, optional step that can fail without losing anything.

```
        offline                          online
user action                        user action
     │                                  │
     ▼                                  ▼
  Hive box  ──▶ pending sync queue    Hive box ──▶ queue ──▶ SyncManager
  (durable)     (durable)             (durable)              │
                                                             ▼
                                                       mark synced
```

Each mutation updates the in-memory read model, then writes through to a
repository **and** records an outbox entry in the same call — the two can never
disagree after a crash. Writes are chained rather than parallel, so two rapid
taps cannot interleave into one box.

**Boxes**

| Box | Holds |
|---|---|
| `mm_patients` | The personalised profile, with family, life memories, assets and routine |
| `mm_sessions` | Every completed activity: level, accuracy, focus, memory, hints, mistakes, seconds, completion |
| `mm_levels` | Adaptive difficulty level per activity |
| `mm_cognitive_profile` | Per-domain cognitive scores and the overall figure |
| `mm_journal` | Memory-journal entries |
| `mm_daily` | Mood, answered questions, journey progress, engagement, day stamp |
| `mm_reminders` | The day's reminders and their done state |
| `mm_settings` | Text size, contrast, reduced motion, voice prompts, offline override |
| `mm_sync_queue` | The durable outbox |

Enum values are stored by **name**, not index, so reordering a Dart enum can
never silently reinterpret stored rows. Type ids are permanent and documented in
`HiveTypeIds`. Hive adapters are hand-written — the wire format matches the
generator's, without the `build_runner` tool chain. Day-scoped boxes roll over
on the first read of a new day, so yesterday's ticked reminders do not read as
today's adherence.

**The sync manager.** `SyncManager` drains the outbox whenever connectivity
returns — no one taps anything. A failed send leaves the operation queued with
its attempt count and error, never dropped; a connection lost mid-drain stops
the run and leaves the remainder for the next reconnect. Where an operation is
*sent* is a one-method `SyncTransport`; `HttpSyncTransport` implements it against
the FastAPI service.

---

## 9. Backend — the sync service

FastAPI, versioned under `/api/v1`, camelCase JSON matching the Dart field names
via a shared `APIModel` base.

```
backend/app/
├── main.py            FastAPI app, CORS, router mounts, error handlers
├── core/              config · dependencies · errors · security · firebase · device_auth
├── api/v1/            one router per domain
├── models/            internal domain models, mirroring the Dart models field-for-field
├── schemas/           request/response DTOs
├── services/          patient · session · analytics · daily · reminder · caregiver ·
│                      sync · scheduler · sms
└── repositories/
    ├── base.py        interfaces
    ├── memory/        in-memory implementations (the fallback)
    └── firestore/     Firestore implementations (live once .env has Firebase)
```

Which repository set is active is decided in exactly one place,
`app/core/dependencies.py` — Firestore when `.env` supplies
`FIREBASE_PROJECT_ID` and `GOOGLE_APPLICATION_CREDENTIALS`, in-memory dicts
otherwise. No router or service code differs between the two.

**Endpoints**

| Router | Routes |
|---|---|
| health | `GET /health`, `GET /api/v1/health` |
| auth | `GET /api/v1/auth/me`, `POST /api/v1/auth/role`, `POST /api/v1/auth/device` |
| patients | `GET/POST /api/v1/patients`, `GET/PUT /api/v1/patients/{id}` |
| sessions | `POST /api/v1/sessions`, `GET /api/v1/sessions?patientId=` |
| analytics | `GET /api/v1/analytics/{id}/cognitive-profile`, `.../weekly?series=`, `/caseload`, `/alerts` |
| daily | `POST /api/v1/daily/mood`, `POST /api/v1/daily/journal`, `GET /api/v1/daily?patientId=` |
| reminders | `GET/POST /api/v1/reminders`, `PATCH /api/v1/reminders/{id}?patientId=` |
| caregivers | `POST /api/v1/caregivers/links`, `GET /api/v1/caregivers/{id}/patients` |
| doctors | `GET /api/v1/doctors/caseload` |
| alerts | `GET /api/v1/alerts` |
| sync | `POST /api/v1/sync/operations` |
| insights | `GET /api/v1/insights/{id}` — `501 not_implemented` (the AI layer runs on the device) |

**Sync semantics.** `POST /api/v1/sync/operations` takes one queued
`PendingOperation` at a time and applies it **exactly once**: the
Flutter-generated `operationId` is checked against a ledger first, and a retry
returns `status: "duplicate"` without re-applying anything.

| Kind | Effect |
|---|---|
| `gameSession` | Appends a session, keyed by `operationId` so a retry cannot duplicate it |
| `moodCheckIn` · `journalEntry` · `reminderToggle` | Day-scoped writes, naturally idempotent |
| `profileUpdate` | Updates the stored patient name |
| `assessmentUpdate` | One completed intake step; answers pass through as written |
| `baselineCaptured` | The frozen personal baseline — domain scores, capture time, session count |
| `reflection` · `unknown` | Recorded in the ledger only |

An unrecognised kind is a client/server version mismatch and is rejected with
422 rather than silently swallowed.

**Auth.** Device tokens (`POST /api/v1/auth/device`) are minted once and
re-minted on a 401 — they prove "a copy of MemoryMitra is calling", not "this is
a specific person". `Settings` refuses to construct with the local-dev
`DEVICE_JWT_SECRET` placeholder when `APP_ENV=production`, so a deployment
cannot silently ship with every device token forgeable.

---

## 10. Authentication

Sign-in is a **step in the journey, not a gate in front of it**:

```
Welcome ──▶ Sign in ──▶ AppState.signInAccount(uid) ──▶ Role picker ──▶ Intake
   │                          │
   └── no Firebase config ────┴──▶ step skipped, journey unchanged
```

Two methods — email/password and Continue with Google — both landing on the same
path. A dismissed Google account picker is reported as a cancellation, not a
failure.

The intake and baseline are stored under `intake:<uid>` / `baseline:<uid>`, so:

- a half-finished questionnaire follows the person, not the handset;
- a second person signing in on a shared device gets a clean record rather than
  inheriting the first person's answers;
- answers given *before* signing in are adopted on first sign-in, not discarded;
- signing out unbinds the account and leaves the record intact — signing out is
  not deleting someone's health record.

The uid is persisted locally, so a restart reopens the same record before anyone
has re-authenticated. That matters on a device that is offline more often than not.

---

## 11. Design system

**Two visual languages, one product.** Patient and caregiver surfaces use a warm
palette — off-white grounds, muted teal-greens, turmeric and terracotta accents
drawn from regional textile dyes. The clinician surface uses a cooler, denser theme.

**Regional identity lives in the content, not the chrome.** The companion wears a
gamosa. Textile patterns are gamosa, phanek and hill-shawl motifs. Instruments
are dhol, pepa and gogona. The house floor plan is an Assam-type layout. The
memory cards are the one-horned rhino, japi, xorai, bamboo, paddy and the
Brahmaputra. The interface itself stays modern — technology adapted to a culture,
not a themed skin.

**Vector-first.** Every portrait, memory photograph, game illustration, textile
tile, card back, floor plan and chart is drawn at runtime with `CustomPainter`.
The result is a small install, crisp rendering at any density, and full control
over the visual language. Typography is Nunito variable — one 270 KB file for
the whole weight range.

**Data visualisation** follows a strict house style: one value axis per figure,
recessive grid and axis ink, thin marks, direct labels rather than a number on
every point, and a fixed categorical series order verified for lightness band,
chroma floor and colour-vision-deficiency separation. Identity is never carried
by colour alone.

---

## 12. Tech stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter 3.32, Material 3 | One codebase across Android, iOS and the web |
| Language | Dart 3.8 | Sealed switches and records used throughout the domain layer |
| State | `ChangeNotifier` + `InheritedNotifier` | No third-party dependency; predictable rebuild scope |
| Graphics | `CustomPainter` | Every illustration, chart, portrait and pattern is vector-drawn |
| Typography | Nunito (variable) | Warm, high-legibility, one file for the whole weight range |
| Local storage | `hive_ce` | Offline-first by default; no SQL, no migration step, works on web |
| Hive adapters | Hand-written | No `build_runner`; the wire format matches the generator's |
| Connectivity | `connectivity_plus` | Behind a `ConnectivityService` interface so tests drive it directly |
| Auth | `firebase_auth`, `google_sign_in` | Optional — the app runs fully without it |
| Speech | `speech_to_text`, `flutter_tts` | Behind adapter interfaces, testable with `fake_async` |
| Maps | `flutter_map` + OSM tiles, `geolocator` | No API key, so the safe zone works the moment the app runs |
| Notifications | `flutter_local_notifications` | Heads-up reminder banners |
| Media | `audioplayers`, `video_player`, `lottie` | Instrument audio, procedural videos, splash |
| Config | `flutter_dotenv` | Plain `flutter run` picks up keys with no launch script |
| Backend | FastAPI, Pydantic v2, `firebase-admin`, PyJWT | Typed, versioned, Firestore-or-memory |
| Scheduling / SMS | APScheduler, Twilio | Optional reminder dispatch |
| Deployment | Render blueprint (`render.yaml`) | Native Python service, secrets never in the repo |

---

## 13. Running the project

### Flutter app

```bash
cd frontend
flutter pub get
flutter run                        # or: -d chrome, -d <device-id>
```

The Flutter project root is `frontend/`, not the repository root.

**Release builds**

```bash
flutter build apk --release           # Android APK
flutter build appbundle --release     # Play Store bundle
flutter build ios --release           # iOS
flutter build web --release           # static bundle in build/web
```

`build/web` is a plain static bundle — deploy it to GitHub Pages, Netlify,
Firebase Hosting, or any object store. `frontend/web/manifest.json` declares
MemoryMitra as a PWA, so a caregiver can add it to a phone home screen. Use
`--base-href /memory-mitra/` when serving from a subdirectory.

### Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

- `http://127.0.0.1:8000/health` — liveness
- `http://127.0.0.1:8000/api/v1/health` — versioned health, reports whether Firebase is configured
- `http://127.0.0.1:8000/docs` — interactive Swagger UI

### Build-time flags

| Flag | Effect |
|---|---|
| `--dart-define=MM_START=patient\|caregiver\|doctor` | Launch straight into a role, skipping role selection (kiosk / demo) |
| `--dart-define=MM_DEMO=true` | Open onto the seeded twelve-week demonstration history |
| `--dart-define=MM_SYNC_BASE_URL=...` | Point the app at a running backend (`http://10.0.2.2:8000` on the Android emulator) |
| `--dart-define=GEMINI_API_KEY=...` | Direct Gemini access (dev/demo only) |
| `--dart-define=AI_PROXY_URL=...` | Route AI calls through the backend, which holds the key (production) |
| `--dart-define=AI_REDACT_IDENTITY=true` | Strip patient identity from outgoing AI context |
| `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` | Google sign-in on Android without refreshing `google-services.json` |

The demonstration history is seeded, so every run produces identical numbers:
the figure you rehearse is the figure on screen. It can also be loaded from
**Profile → Load demonstration history** and cleared with **Start the assessment
over**.

---

## 14. Testing

```bash
cd frontend && flutter test        # 16 suites
cd backend  && pytest              # health, patients, sync, Firebase integration
```

The Flutter suite covers seven layers:

- **Domain** — the adaptive engine's decision boundaries, including level clamping.
- **Assessment and monitoring** (`assessment_test.dart`) — symptom severity and
  functional banding, intake resumption and JSON round-trip, the baseline taken
  from the earliest sessions, the five-point noise floor, weeks with no data
  skipped rather than plotted as zero, the report naming no condition, and the
  assistant's diagnosis guard against six phrasings of the question.
- **The intake journey** (`intake_flow_test.dart`) — every intake and health
  screen rendered and scrolled at four device sizes, consent gating, the symptom
  questionnaire advancing one group at a time, and resumption at the first
  unanswered step.
- **Layout regression** (`screens_test.dart`) — every screen of all three roles at
  four device sizes (360 / 393 / 430 px phones, 834 px tablet), all six
  activities, the full onboarding flow, and the patient app at extra-large text
  with high contrast. `flutter_test` treats any overflow as a failure.
- **End-to-end journeys** — playing an activity through to its result screen and
  difficulty adjustment, a mood check-in and a reminder propagating to the
  caregiver dashboard, and the offline queue filling and draining.
- **Persistence** (`persistence_test.dart`) — restarts the app for real: state
  disposed, Hive closed, a second `AppState` built over the same directory.
  Covers a result surviving a restart, a result saved and queued with no
  connection, both surviving a restart *while still offline*, the queue draining
  by itself on reconnect, a failed send staying retryable, and settings,
  reminders, profile and cognitive scores round-tripping.
- **Voice, AI, sync, safety, localization** — `voice_navigation_test.dart`,
  `voice_intake_test.dart`, `voice_assistant_test.dart`, `ai_service_test.dart`,
  `http_sync_transport_test.dart`, `live_backend_sync_test.dart`,
  `live_gemini_check_test.dart`, `safe_zone_test.dart`, `localization_test.dart`,
  `auth_gate_test.dart`, `demo_journey_test.dart`.

`flutter analyze` runs clean under `flutter_lints` with zero suppressions.

---

## 15. Deployment

The backend deploys to Render from `render.yaml` as a native Python service —
**New → Blueprint → connect this repo**. Secrets are deliberately not in the
file: `FIREBASE_PROJECT_ID` and `FIREBASE_WEB_API_KEY` are prompted at deploy
time (`sync: false`), `DEVICE_JWT_SECRET` is generated by Render
(`generateValue: true`, which also satisfies the production startup guard), and
the Firebase service-account JSON is added by hand as a Render Secret File at
`/etc/secrets/firebase-service-account.json`.

The Flutter web build is a static bundle and can go to any static host. Android
and iOS builds are standard release artifacts.

---

## 16. Known limitations and roadmap

- The 23 symptom items and the functional scale are English-only today, while
  the rest of the app is localized in four languages.
- Per-response reaction timing inside the activities; the session currently
  reports a mean pace derived from its own clock, and labels it as such.
- Clinician report export as PDF rather than shareable plain text.
- Caregiver invitation by link, so their observations arrive from their own
  device rather than being entered alongside the patient.
- Speech input and text-to-speech in all supported regional languages (four are
  wired today, with graceful degradation when an engine is missing).
- Recorded instrument audio for Melody of the Valleys.
- Caregiver photo import to replace the bundled illustration set.
- Multi-patient caregiver accounts.
- The activities are not a validated clinical battery, and the app states this
  rather than borrowing the authority of one.

---

## 17. Clinical note

MemoryMitra provides cognitive activity and performance insights to support
patients, caregivers and clinicians. **It is not a diagnostic tool and does not
detect, diagnose or treat dementia.** Scores describe in-app activity
performance only and are intended to be read alongside clinical assessment,
never in place of it. No output from this application should be used as the sole
basis for a care decision.

---

## 18. Contributing

1. Branch from `main`.
2. Keep `flutter analyze` clean — `flutter_lints`, zero suppressions.
3. Add or update tests for any screen you touch; the layout suite must stay
   green at all four device sizes.
4. Follow the existing structure: new UI in `features/`, new shared components
   in `core/widgets/`, and no screen may reach past a repository interface.

---

<div align="center">

**MemoryMitra** — because a person is more than their diagnosis.

</div>
