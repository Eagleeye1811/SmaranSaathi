# Localization

English, Hindi and Assamese. The `app_*.arb` files are the source of truth and
use the standard Flutter ARB format.

## Editing strings

1. Add or change the key in `app_en.arb` (with an `@key` description).
2. Add the same key to `app_hi.arb` and `app_as.arb`.
3. `python3 tool/gen_l10n.py`
4. Add a getter to `AppLocalizations` if the key is new.

`test/localization_test.dart` fails the build if the locales fall out of key
parity, if a placeholder is dropped in translation, if a string is left
identical across all three languages, or if the generated Dart drifts from the
ARB — so a forgotten step 3 is caught, not shipped.

## Why a script instead of `flutter gen-l10n`

The official tool needs three things in `pubspec.yaml`:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

This phase was told not to modify `pubspec.yaml`, so `tool/gen_l10n.py`
compiles the same ARB files into the same call-site shape
(`AppLocalizations.of(context).someKey`). Switching to the official tool later
means adding those lines plus an `l10n.yaml`, deleting the script and the
`_Fallback*` delegates, and changing **no UI code and no strings**.

Two things the stand-in does not do:

- **ICU plurals and gender.** Placeholders are plain `{name}` substitution.
  None of the current strings need more — the counted quantities read
  naturally with a bare number in all three languages — but `intl` is required
  if that changes.
- **Framework strings.** Flutter's own widget text (date picker, text-selection
  menu) stays English in Hindi and Assamese, because those translations live in
  `flutter_localizations`. The `_Fallback*` delegates in
  `app_localizations.dart` keep that from asserting; adding the package
  replaces them with real translations.

## Persisting the choice

The selected language currently resets on restart. `LocaleController` is
deliberately separate from `AppState`, whose settings live in a Hive box this
phase was told not to touch. To persist it:

1. `AppSettings` (`lib/core/models/settings.dart`) gains a `String? localeCode`.
2. `HiveSettingsRepository.load`/`save` read and write that key.
3. `AppState` exposes it, and `MemoryMitraApp` seeds `LocaleController` from it.

## Translation review

**The Hindi and Assamese strings have not been reviewed by a native speaker.**
They are usable for development and demo, but this is a health application for
elderly users: register, politeness level and the wording of anything about
medicines should be checked by someone fluent before it reaches a patient.
Assamese in particular has limited machine-translation quality.
