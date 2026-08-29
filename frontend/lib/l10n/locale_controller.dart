import 'package:flutter/material.dart';

import '../core/voice/voice_language.dart';

/// The app's current language.
///
/// A `ChangeNotifier` above `MaterialApp`, matching the app's existing state
/// pattern. Changing it rebuilds the whole tree with a new `Localizations`
/// scope, so the UI switches language in place — no restart, and the patient
/// stays on whatever screen they were reading.
///
/// Kept separate from `AppState` on purpose: `AppState` owns persisted domain
/// state and its settings box, and this phase was told not to touch the Hive
/// layer. See `lib/l10n/README.md` for the three-line change that would make
/// the choice survive a restart.
class LocaleController extends ChangeNotifier {
  LocaleController({Locale? initial}) : _locale = initial ?? const Locale('en');

  Locale _locale;
  Locale get locale => _locale;

  /// The current language as the voice layer understands it, so speech
  /// recognition and text-to-speech follow the interface language.
  VoiceLanguage get voiceLanguage => switch (_locale.languageCode) {
        'hi' => VoiceLanguage.hindi,
        'as' => VoiceLanguage.assamese,
        'mr' => VoiceLanguage.marathi,
        _ => VoiceLanguage.english,
      };

  void setLocale(Locale value) {
    if (_locale.languageCode == value.languageCode) return;
    _locale = value;
    notifyListeners();
  }

  void setVoiceLanguage(VoiceLanguage language) => setLocale(Locale(switch (language) {
        VoiceLanguage.hindi => 'hi',
        VoiceLanguage.assamese => 'as',
        VoiceLanguage.marathi => 'mr',
        VoiceLanguage.english => 'en',
      }));

  /// Picks a starting locale from the patient's profile language, so a
  /// caregiver who filled in "Assamese" during onboarding does not also have
  /// to find the language setting.
  static Locale fromPatientLanguage(String raw) =>
      Locale(switch (VoiceLanguageX.fromPatientLanguage(raw)) {
        VoiceLanguage.hindi => 'hi',
        VoiceLanguage.assamese => 'as',
        VoiceLanguage.marathi => 'mr',
        VoiceLanguage.english => 'en',
      });
}

/// Makes the [LocaleController] reachable from any widget.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final LocaleController? controller = maybeOf(context);
    assert(controller != null, 'LocaleScope not found in the widget tree');
    return controller!;
  }

  /// The controller, or null when there is no [LocaleScope] above.
  ///
  /// Widgets that merely *prefer* the selected language use this so they can
  /// still be mounted in a bare harness — several existing screen tests build
  /// their own `MaterialApp` — and fall back to the patient's profile
  /// language instead of asserting.
  static LocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;

  /// Reads without subscribing.
  static LocaleController read(BuildContext context) {
    final LocaleController? controller = maybeRead(context);
    assert(controller != null, 'LocaleScope not found in the widget tree');
    return controller!;
  }

  /// Reads without subscribing, or null when there is no [LocaleScope].
  static LocaleController? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LocaleScope>()?.notifier;
}
