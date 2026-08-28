<div align="center">

# MemoryMitra

**A gentle companion for every memory.**

An AI-powered cognitive care platform for elderly people living with dementia —
built for the languages, culture and connectivity of India's North Eastern Region.

![Flutter](https://img.shields.io/badge/Flutter-3.32%2B-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.8%2B-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)
![Offline First](https://img.shields.io/badge/offline--first-yes-2E7D6B)

</div>

---

## Overview

Dementia care is not a software problem you solve with a leaderboard. The people
who need this app are in their seventies and eighties, they speak Assamese or
Khasi or Mizo rather than English, they live where the network drops for hours at
a time, and they are far more likely to engage with a photograph of their own
daughter than with an abstract puzzle.

MemoryMitra is built around that reality. It is a single application serving
three connected audiences:

| Role | What they get |
|---|---|
| **Patient** | A warm daily companion — mood check-ins, personalised memory questions, six adaptive cognitive activities, reminders, and a memory wallet of the people and places that matter to them. |
| **Caregiver** | Profile creation, day-to-day oversight, engagement and adherence analytics, reminder management, and a memory profile that drives every personalised moment in the patient app. |
| **Clinician** | Longitudinal cognitive performance trends across a caseload, per-domain profiles, and an alerts feed that surfaces meaningful change. |

Everything the patient does flows upward: a completed activity moves the
caregiver's dashboard and the clinician's 30-day trend in the same moment.

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
│  Data                                                        │
│  PatientRepository · GameRepository                          │
│  AnalyticsRepository · ReminderRepository                    │
└──────────────────────────────────────────────────────────────┘
```

Screens depend only on repository **interfaces**, never on a concrete
implementation. Swapping the local store for a remote backend is a matter of
writing new implementations and changing the four constructor arguments in
`AppState` — no screen changes.

State is a single `ChangeNotifier` exposed through an `InheritedNotifier`, so
there is no state-management dependency and no hidden global state. Every screen
subscribes to exactly what it reads.

---

## Tech stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter 3.32, Material 3 | One codebase, native performance on low-end Android |
| Language | Dart 3.8 | Sealed switches and records used throughout the domain layer |
| State | `ChangeNotifier` + `InheritedNotifier` | No third-party dependency; predictable rebuild scope |
| Graphics | `CustomPainter` | Every illustration, chart, portrait and pattern is vector-drawn |
| Typography | Nunito (variable) | Warm, high-legibility, one 270 KB file for the whole weight range |
| Dependencies | `cupertino_icons` only | Smaller binary, no supply chain, no plugin breakage on OS updates |

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
cd DementiaApp

flutter pub get
flutter run
```

### Targeting a device

```bash
flutter devices                       # list available devices
flutter run -d "iPhone 17"            # iOS simulator
flutter run -d <android-device-id>    # Android device or emulator
```

### Release builds

```bash
flutter build apk --release           # Android APK
flutter build appbundle --release     # Play Store bundle
flutter build ios --release           # iOS
```

---

## Configuration

Launch directly into a role, skipping role selection — useful for kiosk
deployments and for demonstrating a single surface:

```bash
flutter run --dart-define=MM_START=patient
flutter run --dart-define=MM_START=caregiver
flutter run --dart-define=MM_START=doctor
```

Omit the flag and the app opens on role selection.

---

## Project structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart                        root widget, live accessibility scaling
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
│   └── repositories/                   interfaces + local implementations
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

The suite covers three layers:

- **Domain** — the adaptive engine's decision boundaries, including level clamping
  at both ends of the scale.
- **Layout regression** — every screen of all three roles rendered at four device
  sizes (360 / 393 / 430 px phones and an 834 px tablet), plus all six activities,
  the full onboarding flow, and the patient application at extra-large text with
  high contrast enabled. `flutter_test` treats any layout overflow as a failure,
  so this suite is the guard against a broken screen on an unfamiliar handset.
- **End-to-end journeys** — playing an activity through to its result screen and
  difficulty adjustment, a mood check-in and a reminder propagating to the
  caregiver dashboard, and the offline queue filling and draining.

To render every screen for design review:

```bash
flutter test test_goldens --update-goldens
```

Output lands in `test_goldens/goldens/`.

---

## Roadmap

- Speech input and text-to-speech in all eight supported regional languages
- On-device language model for open-ended story evaluation
- Recorded instrument audio for Melody of the Valleys
- Caregiver photo import to replace the bundled illustration set
- Multi-patient caregiver accounts
- Clinician report export (PDF) for in-person review

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
