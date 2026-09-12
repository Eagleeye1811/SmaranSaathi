<div align="center">

# MemoryMitra

**From the first memory concern to clinician-ready insight.**

An AI-assisted cognitive health monitoring platform — structured symptom and
functional assessment, six cognitive activities, longitudinal tracking against
a personal baseline, and a summary a doctor can actually use. Built for the
languages, culture and connectivity of India's North Eastern Region.

![Flutter](https://img.shields.io/badge/Flutter-3.32%2B-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.8%2B-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)
![Offline First](https://img.shields.io/badge/offline--first-yes-2E7D6B)

</div>

---

## Overview

People notice cognitive changes long before they know what they mean. Is this
normal ageing? Is it getting worse? What should be tracked? When is it time to
see a doctor? Meanwhile the clinician, when they are finally reached, gets
fifteen minutes and a single snapshot of a person they have never measured
before.

MemoryMitra exists for that gap. It is **not a game app with a chart on top**:
the six cognitive activities are one input among several, and the product is
the **longitudinal cognitive health profile** they feed.

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

**What it will not do.** It does not detect, diagnose or exclude dementia or any
other condition, and it deliberately shows no disease probabilities — a
confident "Alzheimer's 78%" would demo well and be indefensible without a
validated model. It reports *patterns*, always with the inputs that produced
them, and says plainly that a clinician decides what they mean.

| Role | What they get |
|---|---|
| **Patient** | Structured intake, a baseline assessment, six adaptive activities, weekly monitoring against their own baseline, a data-aware companion, and a doctor-ready summary. |
| **Caregiver** | Profile creation, an independent observation record, day-to-day oversight, engagement and adherence analytics, and reminder management. |
| **Clinician** | Longitudinal performance trends across a caseload, per-domain profiles, and an alerts feed that surfaces meaningful change. |

---

## The patient journey

Nineteen screens, one story. Each step writes through to disk as it is
answered, so an intake abandoned half way resumes at the next unanswered
question rather than at the beginning.

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
| 14 | Cognitive profile | Six domains vs baseline, radar, observed patterns |
| 15 | Home dashboard | Status, today's activity, trends, companion, care plan |
| 16 | Progress | Weekly trend, adherence, consistency, functional independence |
| 17 | Companion | Six data-grounded quick actions; refuses to diagnose |
| 18 | Doctor report | The whole record as one shareable summary |
| 19 | Care plan | What happens next, generated from the person's own record |

---

## Core capabilities

### Personalised by construction

Personalisation is not a setting — it is the substrate. During onboarding the
caregiver records who the patient is, who matters to them, what they did for a
living, what they cook, where they have lived, and how their day is shaped.
Every downstream surface consumes that profile:

```
Occupation: Weaver          → weaving motifs and loom procedures in her activities
Daughter: Priya             → the companion asks after Priya by name
Favourite food: Pitha       → cooking steps replace generic tasks
Location: Jorhat, Assam     → dhol, pepa and gogona replace generic tones
Language: Assamese          → content and spoken prompts in her language
```

### Mitra, the companion

A single character present through the whole patient experience, with seven
emotional states — idle, happy, thinking, encouraging, celebrating, listening and
gentle. Mitra breathes, blinks and reacts, and is the voice of every prompt,
every recommendation and every piece of feedback. The patient is never addressed
by an interface; they are addressed by someone.

### Adaptive difficulty

Every session records **accuracy, focus, memory, hint usage, mistakes, pace and
completion**. The adaptive engine consumes those signals and returns one of three
decisions — *increase*, *maintain* or *decrease* — along with the reasoning, which
is shown to the patient in plain language and to the caregiver as an audit trail.

```
accuracy > 85% and ≤ 1 hint          → increase
accuracy 60–85%                      → maintain
accuracy < 60%, or left unfinished   → decrease
```

Pace acts as a secondary signal: an excellent but unusually slow session holds
the level rather than raising it, so difficulty never outruns the person.

### Six cognitive activities

| Activity | Cognitive domain | Progression |
|---|---|---|
| **Procedure Reconstruction** | Procedural | 4 steps → 5 → 6 → reduced visual assistance → a procedure from the patient's own working life |
| **Finish the Story** | Reasoning | Story recall → everyday decision-making → open storytelling about the patient's own photographs |
| **Familiar Place Explorer** | Spatial | 3 objects / 3 rooms / 3 hints → 4 objects / 5 rooms / 1 hint |
| **Melody of the Valleys** | Auditory | 2-note sequences → 5, with tempo increases |
| **Weaves of the Hills** | Attention | Match a motif → complete one → rebuild from a covered pattern → rebuild from a short preview |
| **NER Memory Cards** | Memory | 4 pairs → 6 → 8 → 12 |

Each activity ends on the same encouraging result screen — never framed as an
exam — and feeds the same adaptive engine.

### Three levels of measurement

Session metrics alone are noise. The value is in what they roll up into.

| Level | What it is | Where it lives |
|---|---|---|
| **1 · Session** | Accuracy, focus, recall, hints, mistakes, attempts, correct responses, mean response time, completion | `GamePerformance` |
| **2 · Domain** | Sessions grouped by the function they exercise, averaged over the last four | `CognitiveMonitoringService.domainScores` |
| **3 · Longitudinal** | Deviation from the personal baseline, trend, consistency, adherence, functional change | `MonitoringSnapshot` |

Activities map to domains only where the mapping is defensible — the six were
not built to a standard battery, and the app says so rather than borrowing the
authority of one:

| Activity | Reported as |
|---|---|
| NER Memory Cards | Memory |
| Weaves of the Hills | Attention |
| Procedure Reconstruction | Executive function |
| Finish the Story | Language & reasoning |
| Familiar Place Explorer | Visuospatial |
| Melody of the Valleys | Auditory processing |

### The personal baseline

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

### What the AI actually does

The companion is data-aware and safety-constrained, not a chatbot:

- **Explains results** from this person's own numbers, offline, with no model call
- **Explains a change** — sleep, mood, illness, medication, variability — before
  anyone concludes anything
- **Prepares questions for the doctor**, generated from the actual record
- **Refuses to diagnose**, under any phrasing. The guard runs *before* any model
  is consulted, so it cannot be talked around: `HealthAssistant.diagnosisGuard`

Free-text questions go to Gemini when it is reachable and to the on-device
service when it is not; the quick actions never need a network at all.

### Offline-first

Connectivity across the region is intermittent, so the app assumes it. All game
content, illustrations, audio cues and the patient's memory profile live on the
device. Sessions completed without a connection are written to a local queue and
reconciled when the network returns; a connectivity indicator in every header
shows the current state and the size of the pending queue.

### Accessibility as a product surface

Text size, high contrast, reduced motion and spoken prompts are patient settings
that the **caregiver can change on the patient's behalf**, and they apply live
across the whole application. Patient mode uses 68 px touch targets, 20 px body
text, five permanently-labelled destinations, and requires no typing anywhere.

---

## Repository layout

```
DementiaApp/
├── frontend/          the Flutter application (Android · iOS · web)
├── backend/           the FastAPI sync service (see backend/README.md)
├── README.md
└── .gitignore
```

Every command in this README runs from `frontend/` unless stated otherwise.
The app is offline-first and complete without the backend: it stores everything
locally and queues what would be synced, so a build with no `MM_SYNC_BASE_URL`
loses no functionality.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Presentation                                                │
│  patient · caregiver · clinician  —  three themed shells     │
└───────────────────────────┬──────────────────────────────────┘
                            │  AppScope (InheritedNotifier)
┌───────────────────────────▼──────────────────────────────────┐
│  Domain services                                             │
│  AdaptiveDifficultyService · PersonalizationService          │
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
└──────────────────────────────────────────────────────────────┘
```

Screens depend only on repository **interfaces**, never on a concrete
implementation. No widget imports Hive. Swapping the local store for a remote
backend means writing new implementations and changing the constructor
arguments in `AppState` — no screen changes.

State is a single `ChangeNotifier` exposed through an `InheritedNotifier`, so
there is no state-management dependency and no hidden global state. Every screen
subscribes to exactly what it reads.

---

## Tech stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter 3.32, Material 3 | One codebase across Android, iOS and the web |
| Language | Dart 3.8 | Sealed switches and records used throughout the domain layer |
| State | `ChangeNotifier` + `InheritedNotifier` | No third-party dependency; predictable rebuild scope |
| Graphics | `CustomPainter` | Every illustration, chart, portrait and pattern is vector-drawn |
| Typography | Nunito (variable) | Warm, high-legibility, one 270 KB file for the whole weight range |
| Local storage | `hive_ce` | Offline-first by default; no SQL, no schema migration step, works on web |
| Hive adapters | Hand-written | No `build_runner`; the wire format matches the generator's, without the tool chain |
| Connectivity | `connectivity_plus` | Behind a `ConnectivityService` interface so tests drive it directly |
| Web | CanvasKit via `flutter build web` | No native plugins, so the same code ships as a browser app |

**No binary image assets.** Every portrait, memory photograph, game
illustration, textile tile, card back, floor plan and chart is drawn at runtime.
The result is a small install, crisp rendering at any density, and full control
over the visual language.

---

## Getting started

### Prerequisites

- Flutter SDK 3.32 or newer ([install guide](https://docs.flutter.dev/get-started/install))
- Xcode 15+ for iOS, or Android Studio / SDK 34+ for Android

Verify your toolchain:

```bash
flutter doctor
```

### Install and run

```bash
git clone <repository-url>
cd DementiaApp/frontend

flutter pub get
flutter run
```

The Flutter project root is `frontend/`, not the repository root — `flutter`
commands fail from the top level because there is no `pubspec.yaml` there.

### Targeting a device

```bash
flutter devices                       # list available devices
flutter run -d "iPhone 17"            # iOS simulator
flutter run -d <android-device-id>    # Android device or emulator
flutter run -d chrome                 # web app, in a browser
```

### Release builds

```bash
flutter build apk --release           # Android APK
flutter build appbundle --release     # Play Store bundle
flutter build ios --release           # iOS
flutter build web --release           # web app -> build/web
```

### Running as a web app

The app uses no native plugins, so it runs unchanged in a browser. For local
development:

```bash
flutter run -d chrome
```

To serve a release build from any static host:

```bash
flutter build web --release
cd build/web && python3 -m http.server 8080
```

`build/web` is a plain static bundle — deploy it to GitHub Pages, Netlify,
Firebase Hosting, or any object store. If it is served from a subdirectory
rather than the domain root, pass the path at build time:

```bash
flutter build web --release --base-href /memory-mitra/
```

It is also installable: `frontend/web/manifest.json` declares MemoryMitra as a PWA, so a
caregiver can add it to a phone home screen and open it full-screen. Because a
mouse is the primary pointer on desktop, `_AppScrollBehavior` in
`frontend/lib/app/app.dart` lets mouse drags scroll every list and the onboarding
`PageView`, matching the touch behaviour.

---

## Authentication

Sign-in is a **step in the journey, not a gate in front of it**: splash →
welcome → sign in → role picker → intake. The person sees what the product is
before being asked for an email, and everything they then answer is filed under
their Firebase uid rather than under the device.

```
Welcome ──▶ Sign in ──▶ AppState.signInAccount(uid) ──▶ Role picker ──▶ Intake
   │                          │
   └── no Firebase config ────┴──▶ step skipped, journey unchanged
```

Two methods, both landing on the same path: email/password, and **Continue with
Google**. A dismissed Google account picker is reported as a cancellation, not
a failure.

**What the uid buys.** The intake and the baseline are stored under
`intake:<uid>` / `baseline:<uid>`, so:

- a half-finished questionnaire follows the person, not the handset;
- a second person signing in on a shared device gets a clean record rather than
  inheriting the first person's answers;
- answers given *before* signing in are adopted on first sign-in rather than
  discarded;
- signing out unbinds the account and leaves the record intact — signing out is
  not the same as deleting someone's health record.

The uid is also persisted locally, so a restart reopens the same record before
anyone has re-authenticated. That matters on a device that is offline more often
than not.

### Enabling it

The app runs perfectly well with no auth at all — that is the default, and every
test uses it. To turn sign-in on you need a Firebase project with the platform
registered (`lib/firebase_options.dart`, generated by `flutterfire configure`).

In the Firebase console, under **Authentication → Sign-in method**, enable
**Email/Password** and **Google**. For Google on Android, add the signing
certificate's SHA-1 to the Android app:

```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore \
  -storepass android -keypass android | grep SHA1
```

Then either drop the refreshed `google-services.json` into `android/app/`, or
pass the Web client id at build time:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

On iOS, Google sign-in additionally needs the reversed client id registered as a
URL scheme in `ios/Runner/Info.plist`.

Nothing here is required for the backend: sign-in is pure Firebase. The backend
URL only affects `declareRole` / `fetchMe`, and both already swallow a failed
request.

---

## Configuration

Launch directly into a role, skipping role selection — useful for kiosk
deployments and for demonstrating a single surface:

```bash
flutter run --dart-define=MM_START=patient
flutter run --dart-define=MM_START=caregiver
flutter run --dart-define=MM_START=doctor
```

Omit the flag and the app opens on the splash, then role selection.

Open onto the twelve-week demonstration history instead of an empty profile:

```bash
flutter run --dart-define=MM_DEMO=true
```

The same history can be loaded at any time from **Profile → Load demonstration
history**, and the assessment can be cleared with **Start the assessment over** —
both are there so a demonstration can be reset and repeated. The history is
seeded, so every run produces identical numbers: the figure you rehearse is the
figure on screen.

Point the app at a running backend:

```bash
flutter run --dart-define=MM_SYNC_BASE_URL=http://10.0.2.2:8000   # Android emulator
flutter run --dart-define=MM_SYNC_BASE_URL=http://127.0.0.1:8000  # web / iOS simulator
```

---

## Project structure

```
frontend/lib/
├── main.dart
├── app/
│   ├── app.dart                        root widget, live accessibility scaling
│   ├── bootstrap.dart                  opens local storage, hydrates state
│   ├── routes/app_routes.dart          shared page transitions
│   └── theme/
│       ├── app_colors.dart             palette + verified chart series colours
│       ├── app_text.dart               variable-font typography scale
│       └── app_theme.dart              warm + clinical themes, spacing, motion
├── core/
│   ├── models/
│   │   ├── patient.dart                Patient, FamilyMember, MemoryAsset, LifeMemory
│   │   ├── game.dart                   GameDefinition, GameSession, AdaptiveDecision
│   │   ├── daily.dart                  DailyQuestion, Reminder, JournalEntry
│   │   └── clinical.dart               CognitiveProfile, ClinicPatient, DoctorAlert
│   ├── services/
│   │   ├── app_state.dart              single source of truth
│   │   ├── sync_manager.dart           durable outbox, drains on reconnect
│   │   ├── connectivity_service.dart   real / manual / overridable connectivity
│   │   ├── adaptive_difficulty_service.dart
│   │   └── personalization_service.dart
│   └── widgets/
│       ├── companion.dart              Mitra — seven states, three controllers
│       ├── illustration.dart           24 vector scenes
│       ├── motifs.dart                 woven backgrounds and textile tiles
│       ├── charts.dart                 trend · bar · radar · sparkline · week strip
│       ├── celebration.dart            confetti, success check, attention pulse
│       ├── ui_kit.dart                 cards, buttons, meters, tags, empty states
│       └── app_nav_bar.dart            navigation + connectivity
├── data/
│   ├── mock/                           content catalogue
│   ├── local/                          Hive adapters, boxes, sync queue model
│   └── repositories/                   interfaces + Hive and mock implementations
└── features/
    ├── auth/                           role selection
    ├── patient/
    │   ├── home/  games/  memories/  today/  profile/
    │   └── games/{procedure,story,familiar_place,melody,weaves,memory_cards}
    ├── caregiver/
    │   └── dashboard/  onboarding/  memory_profile/  activity/  reminders/  profile/
    └── doctor/
        └── overview/  patients/  analytics/  alerts/  profile/
```

---

## Offline-first persistence

The app assumes the connection is the exception, not the rule. Everything the
user generates is written to a local Hive box first; reaching a server is a
later, optional step that can fail without losing anything.

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

`AppState` holds an in-memory read model so every getter stays synchronous and
no screen awaits IO. Each mutation updates that model, then writes through to a
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
never silently reinterpret stored rows. Type ids are permanent and documented
in `HiveTypeIds`. The day-scoped boxes roll over on the first read of a new day,
so yesterday's ticked reminders do not read as today's adherence.

**The sync manager.** `SyncManager` drains the outbox whenever connectivity
returns — no one taps anything. A failed send leaves the operation queued with
its attempt count and error, never dropped; a connection lost mid-drain stops
the run and leaves the remainder for the next reconnect. Where the operation is
actually *sent* is a one-method `SyncTransport`. `HttpSyncTransport` implements
it against the FastAPI service in `backend/`, selected by
`--dart-define=MM_SYNC_BASE_URL=...`; without that flag the shipped transport is
a loopback that accepts after a short delay, and the app is unaffected by the
backend existing at all.

The caregiver's "work offline" switch is a genuine offline state, not a mock —
it forces the connectivity layer offline on a device that is online. It can
only force *offline*: no switch conjures a connection that does not exist.

If Hive cannot be opened at all — a locked profile directory, a browser with
site data disabled — the app falls back to an in-memory session and starts
anyway, reporting the fact through `AppState.hydrated`.

---

## Design system

**Two visual languages, one product.** The patient and caregiver surfaces use a
warm palette — off-white grounds, muted teal-greens, turmeric and terracotta
accents drawn from regional textile dyes. The clinician surface uses a cooler,
denser theme so a doctor never confuses their view with the patient's.

**Regional identity lives in the content, not the chrome.** The companion wears
a gamosa. The textile patterns are gamosa, phanek and hill-shawl motifs. The
instruments are dhol, pepa and gogona. The house floor plan is an Assam-type
layout. The memory cards are the one-horned rhino, the japi, the xorai, bamboo,
paddy and the Brahmaputra. The interface itself stays modern — this is technology
adapted to a culture, not a themed skin.

**Data visualisation** follows a strict house style: one value axis per figure,
recessive grid and axis ink, thin marks, direct labels rather than a number on
every point, and a fixed categorical series order verified for lightness band,
chroma floor and colour-vision-deficiency separation. Identity is never carried
by colour alone.

---

## Testing

```bash
flutter test
```

The suite covers five layers:

- **Domain** — the adaptive engine's decision boundaries, including level clamping
  at both ends of the scale.
- **Assessment and monitoring** — `test/assessment_test.dart`: symptom severity
  and functional banding, intake resumption and JSON round-trip, the baseline
  taken from the earliest sessions, the five-point noise floor, weeks with no
  data skipped rather than plotted as zero, the report naming no condition, and
  the assistant's diagnosis guard against six phrasings of the question.
- **The intake journey** — `test/intake_flow_test.dart`: every intake and health
  screen rendered and scrolled at four device sizes, consent gating, the symptom
  questionnaire advancing one group at a time, and the flow resuming at the
  first unanswered step.
- **Layout regression** — every screen of all three roles rendered at four device
  sizes (360 / 393 / 430 px phones and an 834 px tablet), plus all six activities,
  the full onboarding flow, and the patient application at extra-large text with
  high contrast enabled. `flutter_test` treats any layout overflow as a failure,
  so this suite is the guard against a broken screen on an unfamiliar handset.
- **End-to-end journeys** — playing an activity through to its result screen and
  difficulty adjustment, a mood check-in and a reminder propagating to the
  caregiver dashboard, and the offline queue filling and draining.
- **Persistence** — `test/persistence_test.dart` restarts the app for real:
  the state is disposed, Hive is closed, and a second `AppState` is built over
  the same directory. It covers a result surviving a restart, a result saved
  and queued with no connection, both surviving a restart *while still
  offline*, the queue draining by itself when the connection returns, a failed
  send staying retryable, and settings, reminders, profile and cognitive scores
  round-tripping.

---

## Roadmap

- Localising the intake questionnaire — the 23 symptom items and the functional
  scale are English-only today, while the rest of the app is not
- Per-response reaction timing inside the activities; the session currently
  reports a mean pace derived from its own clock, and labels it as such
- Clinician report export as PDF rather than shareable plain text
- Caregiver invitation by link, so their observations arrive from their own
  device rather than being entered alongside the patient
- Speech input and text-to-speech in all eight supported regional languages
- Recorded instrument audio for Melody of the Valleys
- Caregiver photo import to replace the bundled illustration set
- Multi-patient caregiver accounts

---

## Clinical note

MemoryMitra provides cognitive activity and performance insights to support
patients, caregivers and clinicians. **It is not a diagnostic tool and does not
detect, diagnose or treat dementia.** Scores describe in-app activity performance
only and are intended to be read alongside clinical assessment, never in place
of it. No output from this application should be used as the sole basis for a
care decision.

---

## Contributing

1. Branch from `main`.
2. Keep `flutter analyze` clean — the project runs with `flutter_lints` and zero
   suppressions.
3. Add or update tests for any screen you touch; the layout suite must stay green
   at all four device sizes.
4. Follow the existing structure: new UI belongs in `features/`, new shared
   components in `core/widgets/`, and no screen may reach past a repository
   interface.

---

<div align="center">

**MemoryMitra** — because a person is more than their diagnosis.

</div>
