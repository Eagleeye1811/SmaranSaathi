import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';

part 'app_localizations.g.dart';

/// The app's translated strings.
///
/// The ARB files in this directory are the source of truth and are written in
/// the standard Flutter format. `tool/gen_l10n.py` compiles them into
/// `app_localizations.g.dart`, standing in for `flutter gen-l10n` — which
/// needs `intl`, `flutter_localizations` and `generate: true` in
/// `pubspec.yaml`, and this phase was told not to modify that file.
///
/// Call sites use the same `AppLocalizations.of(context).someKey` shape the
/// official generator produces, so switching to it later changes no UI code.
///
/// A missing translation falls back to English rather than rendering blank —
/// an untranslated label is a small problem, an empty button is a large one.
@immutable
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('as'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// The delegates a `MaterialApp` needs.
  ///
  /// The `_Fallback*` delegates supply Flutter's *own* widget strings (the
  /// date picker, the text-selection menu) in English for every locale. Real
  /// translations for those come from `flutter_localizations`, which is a
  /// one-line pubspec addition — see `lib/l10n/README.md`. Without them
  /// Flutter both asserts at the first Material widget and logs a locale
  /// warning, because its defaults only claim English.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    _FallbackMaterialLocalizationsDelegate(),
    _FallbackWidgetsLocalizationsDelegate(),
    _FallbackCupertinoLocalizationsDelegate(),
  ];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  /// Looks a key up, falling back to English and finally to the key itself.
  String _s(String key) =>
      _byLocale[locale.languageCode]?[key] ?? _byLocale['en']![key] ?? key;

  /// Substitutes `{name}`-style placeholders.
  ///
  /// Deliberately simple: no ICU plurals or gender. The strings that would
  /// need them are counted quantities, and every one of the three languages
  /// here reads naturally with a plain number, so the complexity would buy
  /// nothing. `intl` handles the general case if that changes.
  String _f(String key, Map<String, Object?> values) {
    String out = _s(key);
    values.forEach((String k, Object? v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }

  /// Every key, for tests and the language picker preview.
  @visibleForTesting
  static Map<String, Map<String, String>> get allStrings => _byLocale;

  // ── Common actions ─────────────────────────────────────────────────────
  String get appName => _s('appName');
  String get actionStart => _s('actionStart');
  String get actionPlay => _s('actionPlay');
  String get actionPlayAgain => _s('actionPlayAgain');
  String get actionContinue => _s('actionContinue');
  String get actionCancel => _s('actionCancel');
  String get actionClose => _s('actionClose');
  String get actionSwitchRole => _s('actionSwitchRole');

  // ── Home ───────────────────────────────────────────────────────────────
  String get greetingMorning => _s('greetingMorning');
  String get greetingAfternoon => _s('greetingAfternoon');
  String get greetingEvening => _s('greetingEvening');
  String get homeMoodQuestion => _s('homeMoodQuestion');
  String get homeRecommendsLabel => _s('homeRecommendsLabel');
  String get homeComingUp => _s('homeComingUp');
  String get homeSmallQuestion => _s('homeSmallQuestion');
  String get homeThankYouForTalking => _s('homeThankYouForTalking');
  String get homeAllQuestionsAnswered => _s('homeAllQuestionsAnswered');
  String get homeTodaysJourney => _s('homeTodaysJourney');

  // ── Mood ───────────────────────────────────────────────────────────────
  String get moodGood => _s('moodGood');
  String get moodOkay => _s('moodOkay');
  String get moodLow => _s('moodLow');
  String get moodReplyGood => _s('moodReplyGood');
  String get moodReplyOkay => _s('moodReplyOkay');
  String get moodReplyLow => _s('moodReplyLow');

  // ── Today ──────────────────────────────────────────────────────────────
  String get todayTitle => _s('todayTitle');
  String get todaySubtitle => _s('todaySubtitle');
  String get todayRemindersHeading => _s('todayRemindersHeading');
  String get todayRemindersHint => _s('todayRemindersHint');
  String todayMedicineTaken(int done, int total) =>
      _f('todayMedicineTaken', <String, Object?>{'done': done, 'total': total});
  String get todayTalkedAbout => _s('todayTalkedAbout');
  String get todayNothingWritten => _s('todayNothingWritten');
  String get todayAnswerHint => _s('todayAnswerHint');
  String get todayUsualDay => _s('todayUsualDay');
  String get todayFinishTheDay => _s('todayFinishTheDay');
  String get todayCloseTheDay => _s('todayCloseTheDay');
  String get todayReflectionComplete => _s('todayReflectionComplete');
  String todayThankYou(String name) =>
      _f('todayThankYou', <String, Object?>{'name': name});

  // ── Activities ─────────────────────────────────────────────────────────
  String get gamesChosenForYou => _s('gamesChosenForYou');
  String get gamesIntro => _s('gamesIntro');
  String get gamesDifficultyNote => _s('gamesDifficultyNote');
  String get gamesDoneToday => _s('gamesDoneToday');
  String get gamesNothingDoneYet => _s('gamesNothingDoneYet');
  String get gamesGoodStart => _s('gamesGoodStart');
  String get gamesVeryGoodDay => _s('gamesVeryGoodDay');
  String gamesLevel(int level) => _f('gamesLevel', <String, Object?>{'level': level});
  String gamesLastTime(int accuracy) =>
      _f('gamesLastTime', <String, Object?>{'accuracy': accuracy});
  String get gamesLeaveActivity => _s('gamesLeaveActivity');

  // ── Result ─────────────────────────────────────────────────────────────
  String get resultAccuracy => _s('resultAccuracy');
  String get resultFocus => _s('resultFocus');
  String get resultMemory => _s('resultMemory');
  String get resultHints => _s('resultHints');
  String get resultRetries => _s('resultRetries');
  String get resultTime => _s('resultTime');
  String get resultThisSession => _s('resultThisSession');
  String get resultNextSession => _s('resultNextSession');
  String get resultWhatMitraNoticed => _s('resultWhatMitraNoticed');
  String get resultAdjusted => _s('resultAdjusted');
  String get resultWonderful => _s('resultWonderful');
  String get resultVeryWellDone => _s('resultVeryWellDone');
  String get resultNicelyDone => _s('resultNicelyDone');
  String get resultThankYouForTrying => _s('resultThankYouForTrying');
  String get resultPraiseHigh => _s('resultPraiseHigh');
  String get resultPraiseMid => _s('resultPraiseMid');
  String get resultPraiseSteady => _s('resultPraiseSteady');
  String get resultPraiseIncomplete => _s('resultPraiseIncomplete');
  String resultCompleted(String activity) =>
      _f('resultCompleted', <String, Object?>{'activity': activity});

  // ── Settings and accessibility ─────────────────────────────────────────
  String get settingsEasier => _s('settingsEasier');
  String get settingsTextSize => _s('settingsTextSize');
  String get settingsTextNormal => _s('settingsTextNormal');
  String get settingsTextLarge => _s('settingsTextLarge');
  String get settingsTextExtraLarge => _s('settingsTextExtraLarge');
  String get settingsHighContrast => _s('settingsHighContrast');
  String get settingsHighContrastNote => _s('settingsHighContrastNote');
  String get settingsReduceMotion => _s('settingsReduceMotion');
  String get settingsReduceMotionNote => _s('settingsReduceMotionNote');
  String settingsVoicePrompts(String language) =>
      _f('settingsVoicePrompts', <String, Object?>{'language': language});
  String get settingsLanguage => _s('settingsLanguage');
  String get settingsLanguageNote => _s('settingsLanguageNote');
  String get settingsConnection => _s('settingsConnection');
  String get settingsOfflineMode => _s('settingsOfflineMode');
  String get settingsOfflineNote => _s('settingsOfflineNote');
  String get settingsConnected => _s('settingsConnected');
  String get settingsAllSynced => _s('settingsAllSynced');

  // ── Voice assistant ────────────────────────────────────────────────────
  String get voiceNavButton => _s('voiceNavButton');
  String get voiceNavTitle => _s('voiceNavTitle');
  String get voiceNavHint => _s('voiceNavHint');
  String get voiceNavSpeakNow => _s('voiceNavSpeakNow');
  String get voiceAskMitra => _s('voiceAskMitra');
  String get voiceTalkAboutDay => _s('voiceTalkAboutDay');
  String get voiceTapMicrophone => _s('voiceTapMicrophone');
  String get voiceAskAnythingElse => _s('voiceAskAnythingElse');
  String get voiceOneMoment => _s('voiceOneMoment');
  String get voiceListening => _s('voiceListening');
  String get voiceThinking => _s('voiceThinking');
  String get voiceSpeaking => _s('voiceSpeaking');
  String get voiceTryAgain => _s('voiceTryAgain');
  String get voiceTalkToMitra => _s('voiceTalkToMitra');
  String get voiceAskSomethingElse => _s('voiceAskSomethingElse');
  String get voiceIHaveFinished => _s('voiceIHaveFinished');
  String get voiceStop => _s('voiceStop');
  String get voiceThinkingButton => _s('voiceThinkingButton');
  String get voiceUnavailable => _s('voiceUnavailable');
  String get voiceSayItAgain => _s('voiceSayItAgain');
  String voiceLanguageFallback(String requested, String fallback) => _f(
      'voiceLanguageFallback',
      <String, Object?>{'requested': requested, 'fallback': fallback});

  String get voiceErrorPermissionDenied => _s('voiceErrorPermissionDenied');
  String get voiceErrorPermissionBlocked => _s('voiceErrorPermissionBlocked');
  String get voiceErrorUnavailable => _s('voiceErrorUnavailable');
  String get voiceErrorNoSpeech => _s('voiceErrorNoSpeech');
  String get voiceErrorLanguage => _s('voiceErrorLanguage');
  String get voiceErrorRecognition => _s('voiceErrorRecognition');
  String get voiceErrorTtsUnavailable => _s('voiceErrorTtsUnavailable');
  String get voiceErrorTtsFailed => _s('voiceErrorTtsFailed');
  String get voiceErrorAssistant => _s('voiceErrorAssistant');
  String get voiceErrorUnknown => _s('voiceErrorUnknown');

  // ── Assistant ──────────────────────────────────────────────────────────
  String get assistantOutOfScope => _s('assistantOutOfScope');
  String get assistantAskToday => _s('assistantAskToday');
  String get assistantAskReminders => _s('assistantAskReminders');
  String get assistantAskActivity => _s('assistantAskActivity');
  String get assistantMaybeLater => _s('assistantMaybeLater');
  String get assistantNothingToday => _s('assistantNothingToday');
  String get assistantAllDone => _s('assistantAllDone');

  // ── Connectivity ───────────────────────────────────────────────────────
  String get offlineBannerTitle => _s('offlineBannerTitle');
  String offlineBannerPending(int count) =>
      _f('offlineBannerPending', <String, Object?>{'count': count});

  // ── Language names ─────────────────────────────────────────────────────
  String get languageEnglish => _s('languageEnglish');
  String get languageHindi => _s('languageHindi');
  String get languageAssamese => _s('languageAssamese');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _byLocale.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Supplies Flutter's built-in widget strings for locales the framework does
/// not itself support.
///
/// Without this, a `MaterialApp` set to `hi` or `as` asserts at the first
/// widget that needs `MaterialLocalizations`, because `DefaultMaterialLocalizations`
/// only claims English. Adding `flutter_localizations` replaces this with real
/// translations for those framework strings; until then they stay English
/// while every string the app itself owns is translated.
class _FallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _FallbackWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      DefaultWidgetsLocalizations.load(locale);

  @override
  bool shouldReload(_FallbackWidgetsLocalizationsDelegate old) => false;
}

class _FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);

  @override
  bool shouldReload(_FallbackCupertinoLocalizationsDelegate old) => false;
}

class _FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(locale);

  @override
  bool shouldReload(_FallbackMaterialLocalizationsDelegate old) => false;
}
