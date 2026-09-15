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
  String get aiFriend => _s('aiFriend');
  String aiMorning(String name) => _f('aiMorning', <String, Object?>{'name': name});
  String aiRestQuestion(String name) => _f('aiRestQuestion', <String, Object?>{'name': name});
  String get aiRestLabel => _s('aiRestLabel');
  String get aiRestWell => _s('aiRestWell');
  String get aiRestWellReply => _s('aiRestWellReply');
  String get aiRestSoSo => _s('aiRestSoSo');
  String get aiRestSoSoReply => _s('aiRestSoSoReply');
  String get aiRestPoorly => _s('aiRestPoorly');
  String get aiRestPoorlyReply => _s('aiRestPoorlyReply');
  String aiWorkQuestion(String occupation) => _f('aiWorkQuestion', <String, Object?>{'occupation': occupation});
  String get aiWorkLabel => _s('aiWorkLabel');
  String get aiWorkYes => _s('aiWorkYes');
  String get aiWorkYesReply => _s('aiWorkYesReply');
  String get aiWorkSometimes => _s('aiWorkSometimes');
  String get aiWorkSometimesReply => _s('aiWorkSometimesReply');
  String get aiWorkNotLately => _s('aiWorkNotLately');
  String get aiWorkNotLatelyReply => _s('aiWorkNotLatelyReply');
  String aiFamilyQuestion(String name) => _f('aiFamilyQuestion', <String, Object?>{'name': name});
  String get aiFamilyLabel => _s('aiFamilyLabel');
  String get aiFamilyYes => _s('aiFamilyYes');
  String get aiFamilyYesReply => _s('aiFamilyYesReply');
  String get aiFamilyNotYet => _s('aiFamilyNotYet');
  String get aiFamilyNotYetReply => _s('aiFamilyNotYetReply');
  String get aiFamilyRemindMe => _s('aiFamilyRemindMe');
  String aiFamilyRemindMeReply(String name) => _f('aiFamilyRemindMeReply', <String, Object?>{'name': name});
  String aiFunctionQuestion(String function) => _f('aiFunctionQuestion', <String, Object?>{'function': function});
  String get aiFunctionLabel => _s('aiFunctionLabel');
  String get aiFunctionYes => _s('aiFunctionYes');
  String get aiFunctionYesReply => _s('aiFunctionYesReply');
  String get aiFunctionHelp => _s('aiFunctionHelp');
  String get aiFunctionHelpReply => _s('aiFunctionHelpReply');
  String get aiFunctionNotToday => _s('aiFunctionNotToday');
  String get aiFunctionNotTodayReply => _s('aiFunctionNotTodayReply');
  String get authWelcomeTitle => _s('authWelcomeTitle');
  String get authWelcomeSubtitle => _s('authWelcomeSubtitle');
  String get authWhoAreYou => _s('authWhoAreYou');
  String get authRolePatient => _s('authRolePatient');
  String get authRolePatientName => _s('authRolePatientName');
  String get authRolePatientDesc => _s('authRolePatientDesc');
  String get authRoleCaregiver => _s('authRoleCaregiver');
  String get authRoleCaregiverName => _s('authRoleCaregiverName');
  String get authRoleCaregiverDesc => _s('authRoleCaregiverDesc');
  String get authRoleDoctor => _s('authRoleDoctor');
  String get authRoleDoctorName => _s('authRoleDoctorName');
  String get authRoleDoctorDesc => _s('authRoleDoctorDesc');
  String get actionLogOut => _s('actionLogOut');
  String get doctorSettingsSub => _s('doctorSettingsSub');
  String get accountSignedInAs => _s('accountSignedInAs');
  String accountRole(String role) => _f('accountRole', <String, Object?>{'role': role});
  String get safeZoneHomeLabel => _s('safeZoneHomeLabel');
  String get dashboardStartTodaySession => _s('dashboardStartTodaySession');
  String get dashboardStartFirstSession => _s('dashboardStartFirstSession');
  String get dashboardCheckInAndReminders => _s('dashboardCheckInAndReminders');
  String get clinicalStatusStable => _s('clinicalStatusStable');
  String get clinicalStatusNeedsAttention => _s('clinicalStatusNeedsAttention');
  String get clinicalStatusFollowUp => _s('clinicalStatusFollowUp');
  String get mockReminderMorningMedicine => _s('mockReminderMorningMedicine');
  String get shallWeHeadBack => _s('shallWeHeadBack');
  String get myMemories => _s('myMemories');
  String get goBackAndLogOutConfirm => _s('goBackAndLogOutConfirm');
  String get stayHere => _s('stayHere');
  String get goBackAndLogOut => _s('goBackAndLogOut');
  String get removeSafeZoneConfirm => _s('removeSafeZoneConfirm');
  String get keepIt => _s('keepIt');
  String get remove => _s('remove');
  String get safeZone => _s('safeZone');
  String get tapMapToMoveMiddle => _s('tapMapToMoveMiddle');
  String get howFarCanTheyGo => _s('howFarCanTheyGo');
  String get cancel => _s('cancel');
  String get saveSafeZone => _s('saveSafeZone');
  String get retry => _s('retry');
  String get orText => _s('orText');
  String get mockReminderDrinkWater => _s('mockReminderDrinkWater');
  String get mockReminderRestAndRadio => _s('mockReminderRestAndRadio');
  String get mockReminderEveningWalk => _s('mockReminderEveningWalk');
  String get mockReminderCallPriya => _s('mockReminderCallPriya');
  String get mockReminderMemoryClinic => _s('mockReminderMemoryClinic');
  String get mockDetailOneTablet => _s('mockDetailOneTablet');
  String get mockDetailFullGlass => _s('mockDetailFullGlass');
  String get mockDetailWithLunch => _s('mockDetailWithLunch');
  String get mockDetailVividhBharati => _s('mockDetailVividhBharati');
  String get mockDetailParkWithNirmali => _s('mockDetailParkWithNirmali');
  String get mockDetailCheckInDay => _s('mockDetailCheckInDay');
  String get mockDetailBhaskarDrive => _s('mockDetailBhaskarDrive');
  String get mockTimeThursday11 => _s('mockTimeThursday11');
  String aiInsightNoActivity(String name) => _f('aiInsightNoActivity', <String, Object?>{'name': name});
  String aiInsightActivityCount(String name, String sessions, String activityWord, String accuracy) => _f('aiInsightActivityCount', <String, Object?>{'name': name, 'sessions': sessions, 'activityWord': activityWord, 'accuracy': accuracy});
  String get aiActivitySingular => _s('aiActivitySingular');
  String get aiActivityPlural => _s('aiActivityPlural');
  String get aiInsightTrendStronger => _s('aiInsightTrendStronger');
  String get aiInsightTrendWeaker => _s('aiInsightTrendWeaker');
  String get aiInsightTrendSteady => _s('aiInsightTrendSteady');
  String aiInsightMood(String pronoun, String mood) => _f('aiInsightMood', <String, Object?>{'pronoun': pronoun, 'mood': mood});
  String get aiInsightPronounShe => _s('aiInsightPronounShe');
  String get aiInsightPronounHe => _s('aiInsightPronounHe');
  String get aiInsightPronounThey => _s('aiInsightPronounThey');
  String aiInsightStrongestActivity(String activityName, String pronoun, String accuracy, String domain) => _f('aiInsightStrongestActivity', <String, Object?>{'activityName': activityName, 'pronoun': pronoun, 'accuracy': accuracy, 'domain': domain});
  String get aiInsightPronounHer => _s('aiInsightPronounHer');
  String get aiInsightPronounHis => _s('aiInsightPronounHis');
  String get aiInsightPronounTheir => _s('aiInsightPronounTheir');
  String aiInsightUnaidedSessions(String unaided, String total) => _f('aiInsightUnaidedSessions', <String, Object?>{'unaided': unaided, 'total': total});
  String aiInsightReminders(String percent) => _f('aiInsightReminders', <String, Object?>{'percent': percent});
  String aiInsightTopDomain(String domain, String score) => _f('aiInsightTopDomain', <String, Object?>{'domain': domain, 'score': score});
  String aiInsightTopDomainTied(String domain, String score, String otherDomain) => _f('aiInsightTopDomainTied', <String, Object?>{'domain': domain, 'score': score, 'otherDomain': otherDomain});
  String aiInsightTopDomainMultiple(String domain, String score) => _f('aiInsightTopDomainMultiple', <String, Object?>{'domain': domain, 'score': score});
  String aiInsightDecliningDomain(String domain, String trend) => _f('aiInsightDecliningDomain', <String, Object?>{'domain': domain, 'trend': trend});
  String aiInsightGap(String domain) => _f('aiInsightGap', <String, Object?>{'domain': domain});
  String aiInsightLevelDown(String activityName, String level) => _f('aiInsightLevelDown', <String, Object?>{'activityName': activityName, 'level': level});
  String aiInsightLevelUp(String activityName, String level, String pronoun) => _f('aiInsightLevelUp', <String, Object?>{'activityName': activityName, 'level': level, 'pronoun': pronoun});
  String get aiInsightEngaging => _s('aiInsightEngaging');
  String aiInsightLowestActivity(String activityName, String accuracy, String pronoun) => _f('aiInsightLowestActivity', <String, Object?>{'activityName': activityName, 'accuracy': accuracy, 'pronoun': pronoun});
  String get aiInsightAbandonedSingular => _s('aiInsightAbandonedSingular');
  String get aiInsightAbandonedPlural => _s('aiInsightAbandonedPlural');
  String aiInsightAbandoned(String count, String sessionWord) => _f('aiInsightAbandoned', <String, Object?>{'count': count, 'sessionWord': sessionWord});
  String get aiInsightSlowSingular => _s('aiInsightSlowSingular');
  String get aiInsightSlowPlural => _s('aiInsightSlowPlural');
  String aiInsightSlow(String count, String sessionWord) => _f('aiInsightSlow', <String, Object?>{'count': count, 'sessionWord': sessionWord});
  String get aiInsightNotPlayedSingular => _s('aiInsightNotPlayedSingular');
  String get aiInsightNotPlayedPlural => _s('aiInsightNotPlayedPlural');
  String aiInsightNotPlayed(String names, String hasHaveWord) => _f('aiInsightNotPlayed', <String, Object?>{'names': names, 'hasHaveWord': hasHaveWord});
  String get aiInsightDownwardTrend => _s('aiInsightDownwardTrend');
  String get aiInsightNoAttention => _s('aiInsightNoAttention');
  String aiRecommendUntouched(String domain) => _f('aiRecommendUntouched', <String, Object?>{'domain': domain});
  String aiRecommendWeakest(String domain) => _f('aiRecommendWeakest', <String, Object?>{'domain': domain});
  String get aiRecommendGeneral => _s('aiRecommendGeneral');
  String aiEvidence(String count, String sessionWord, String accuracy, String level) => _f('aiEvidence', <String, Object?>{'count': count, 'sessionWord': sessionWord, 'accuracy': accuracy, 'level': level});
  String get aiScheduleAllDone => _s('aiScheduleAllDone');
  String aiScheduleNext(String title, String time) => _f('aiScheduleNext', <String, Object?>{'title': title, 'time': time});
  String get aiScheduleMoreSingular => _s('aiScheduleMoreSingular');
  String get aiScheduleMorePlural => _s('aiScheduleMorePlural');
  String aiScheduleMore(String isAreWord, String count) => _f('aiScheduleMore', <String, Object?>{'isAreWord': isAreWord, 'count': count});
  String get aiScheduleNoActivity => _s('aiScheduleNoActivity');
  String get aiScheduleActivitySingular => _s('aiScheduleActivitySingular');
  String get aiScheduleActivityPlural => _s('aiScheduleActivityPlural');
  String aiScheduleActivities(String count, String activityWord) => _f('aiScheduleActivities', <String, Object?>{'count': count, 'activityWord': activityWord});
  String get aiScheduleFollowUpActivity => _s('aiScheduleFollowUpActivity');
  String get aiScheduleFollowUpReminders => _s('aiScheduleFollowUpReminders');
  String get aiScheduleFollowUpToday => _s('aiScheduleFollowUpToday');
  String get aiScheduleFollowUpLater => _s('aiScheduleFollowUpLater');
  String aiActivityTry(String activityName, String invitation) => _f('aiActivityTry', <String, Object?>{'activityName': activityName, 'invitation': invitation});
  String get aiRemindersNothingToday => _s('aiRemindersNothingToday');
  String get aiRemindersAllDone => _s('aiRemindersAllDone');
  String aiRemindersStillHave(String reminders) => _f('aiRemindersStillHave', <String, Object?>{'reminders': reminders});
  String aiPeopleRelation(String name, String relation) => _f('aiPeopleRelation', <String, Object?>{'name': name, 'relation': relation});
  String aiPeopleFamilyHere(String names) => _f('aiPeopleFamilyHere', <String, Object?>{'names': names});
  String aiOrientationLocation(String location) => _f('aiOrientationLocation', <String, Object?>{'location': location});
  String aiOrientationTime(String time, String partOfDay, String locationText) => _f('aiOrientationTime', <String, Object?>{'time': time, 'partOfDay': partOfDay, 'locationText': locationText});
  String get aiCompanionshipLow => _s('aiCompanionshipLow');
  String get aiCompanionshipOkay => _s('aiCompanionshipOkay');
  String get aiCompanionshipGood => _s('aiCompanionshipGood');
  String aiCompanionshipOffer(String opener) => _f('aiCompanionshipOffer', <String, Object?>{'opener': opener});
  String get aiOutOfScope => _s('aiOutOfScope');
  String aiJoinAnd(String list, String last) => _f('aiJoinAnd', <String, Object?>{'list': list, 'last': last});
  String get aiGameProcedure => _s('aiGameProcedure');
  String get aiGameStory => _s('aiGameStory');
  String get aiGameFamiliarPlace => _s('aiGameFamiliarPlace');
  String get aiGameMelody => _s('aiGameMelody');
  String get aiGameWeaves => _s('aiGameWeaves');
  String get aiGameMemoryCards => _s('aiGameMemoryCards');
  String get aiGameProcedureInvitation => _s('aiGameProcedureInvitation');
  String get aiGameStoryInvitation => _s('aiGameStoryInvitation');
  String get aiGameFamiliarPlaceInvitation => _s('aiGameFamiliarPlaceInvitation');
  String get aiGameMelodyInvitation => _s('aiGameMelodyInvitation');
  String get aiGameWeavesInvitation => _s('aiGameWeavesInvitation');
  String get aiGameMemoryCardsInvitation => _s('aiGameMemoryCardsInvitation');
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
  String get resultWhatSaathiNoticed => _s('resultWhatSaathiNoticed');
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
  String get voiceAskSaathi => _s('voiceAskSaathi');
  String get voiceTalkAboutDay => _s('voiceTalkAboutDay');
  String get voiceTapMicrophone => _s('voiceTapMicrophone');
  String get voiceAskAnythingElse => _s('voiceAskAnythingElse');
  String get voiceOneMoment => _s('voiceOneMoment');
  String get voiceListening => _s('voiceListening');
  String get voiceThinking => _s('voiceThinking');
  String get voiceSpeaking => _s('voiceSpeaking');
  String get voiceTryAgain => _s('voiceTryAgain');
  String get voiceTalkToSaathi => _s('voiceTalkToSaathi');
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
  String offlineBannerBodyPending(int count) =>
      _f('offlineBannerBodyPending', <String, Object?>{'count': count});
  String get offlineBannerBodyAllSynced => _s('offlineBannerBodyAllSynced');


  // ── Doctor — nav ─────────────────────────────────────────────────
  String get doctorTabOverview => _s('doctorTabOverview');
  String get doctorTabPatients => _s('doctorTabPatients');
  String get doctorTabChats => _s('doctorTabChats');
  String get doctorTabAnalytics => _s('doctorTabAnalytics');
  String get doctorTabAlerts => _s('doctorTabAlerts');
  String get doctorTabProfile => _s('doctorTabProfile');

  // ── Doctor — profile ─────────────────────────────────────────────
  String get doctorProfileRoleLine => _s('doctorProfileRoleLine');
  String doctorProfilePatientCount(int count) => _f('doctorProfilePatientCount', <String, Object?>{'count': count});
  String get doctorProfilePracticeHeading => _s('doctorProfilePracticeHeading');
  String get doctorProfileClinicLabel => _s('doctorProfileClinicLabel');
  String get doctorProfileRegionLabel => _s('doctorProfileRegionLabel');
  String get doctorProfileRegionValue => _s('doctorProfileRegionValue');
  String get doctorProfileLanguagesLabel => _s('doctorProfileLanguagesLabel');
  String get doctorProfileLanguagesValue => _s('doctorProfileLanguagesValue');
  String get doctorProfileClinicDaysLabel => _s('doctorProfileClinicDaysLabel');
  String get doctorProfileClinicDaysValue => _s('doctorProfileClinicDaysValue');
  String get doctorProfileFiguresHeading => _s('doctorProfileFiguresHeading');
  String get doctorProfileFiguresBulletActivity => _s('doctorProfileFiguresBulletActivity');
  String get doctorProfileFiguresBulletDomains => _s('doctorProfileFiguresBulletDomains');
  String get doctorProfileFiguresBulletAdaptive => _s('doctorProfileFiguresBulletAdaptive');
  String get doctorProfileFiguresBulletOffline => _s('doctorProfileFiguresBulletOffline');
  String get doctorProfileConnected => _s('doctorProfileConnected');
  String doctorProfileRecordsWaitingSync(int count) => _f('doctorProfileRecordsWaitingSync', <String, Object?>{'count': count});
  String get doctorProfileRecordsUpToDate => _s('doctorProfileRecordsUpToDate');
  String get doctorProfileSwitchRole => _s('doctorProfileSwitchRole');
  String get doctorProfileSignedInAs => _s('doctorProfileSignedInAs');
  String doctorProfileRoleValue(String role) => _f('doctorProfileRoleValue', <String, Object?>{'role': role});
  String get doctorProfileLogOut => _s('doctorProfileLogOut');

  // ── Doctor — patient detail ──────────────────────────────────────
  String get doctorDetailTitle => _s('doctorDetailTitle');
  String get doctorDetailReportCardTitle => _s('doctorDetailReportCardTitle');
  String get doctorDetailReportCardSubtitle => _s('doctorDetailReportCardSubtitle');
  String get doctorDetailOpenReport => _s('doctorDetailOpenReport');
  String doctorDetailAgeDistrict(int age, String district) => _f('doctorDetailAgeDistrict', <String, Object?>{'age': age, 'district': district});
  String doctorDetailLanguageLine(String language) => _f('doctorDetailLanguageLine', <String, Object?>{'language': language});
  String get doctorDetailOverallLabel => _s('doctorDetailOverallLabel');
  String get doctorDetailOverallStat => _s('doctorDetailOverallStat');
  String get doctorDetailEngagementLabel => _s('doctorDetailEngagementLabel');
  String get doctorDetailAdherenceLabel => _s('doctorDetailAdherenceLabel');
  String get doctorDetailLastSessionLabel => _s('doctorDetailLastSessionLabel');
  String get doctorDetailCognitiveProfileTitle => _s('doctorDetailCognitiveProfileTitle');
  String get doctorDetailTrendTitle => _s('doctorDetailTrendTitle');
  String get doctorDetailTrendCaption => _s('doctorDetailTrendCaption');
  String get doctorDetailTrendAgo => _s('doctorDetailTrendAgo');
  String get doctorDetailToday => _s('doctorDetailToday');
  String get doctorDetailYesterday => _s('doctorDetailYesterday');
  String doctorDetailDaysAgo(int days) => _f('doctorDetailDaysAgo', <String, Object?>{'days': days});
  String get doctorDetailActivityBreakdownTitle => _s('doctorDetailActivityBreakdownTitle');
  String get doctorDetailActivityBreakdownCaption => _s('doctorDetailActivityBreakdownCaption');
  String get doctorDetailSessionLogTitle => _s('doctorDetailSessionLogTitle');
  String get doctorDetailAlertsTitle => _s('doctorDetailAlertsTitle');
  String get doctorDetailConsiderationsTitle => _s('doctorDetailConsiderationsTitle');
  String get doctorDetailConsiderationDecreased => _s('doctorDetailConsiderationDecreased');
  String doctorDetailConsiderationLowAdherence(int percent) => _f('doctorDetailConsiderationLowAdherence', <String, Object?>{'percent': percent});
  String get doctorDetailConsiderationLowEngagement => _s('doctorDetailConsiderationLowEngagement');
  String get doctorDetailConsiderationImproving => _s('doctorDetailConsiderationImproving');
  String get doctorDetailConsiderationReviewDue => _s('doctorDetailConsiderationReviewDue');
  String get doctorDetailConsiderationFooter => _s('doctorDetailConsiderationFooter');
  String get doctorDetailChartProcedure => _s('doctorDetailChartProcedure');
  String get doctorDetailChartStory => _s('doctorDetailChartStory');
  String get doctorDetailChartPlace => _s('doctorDetailChartPlace');
  String get doctorDetailChartMelody => _s('doctorDetailChartMelody');
  String get doctorDetailChartWeaves => _s('doctorDetailChartWeaves');
  String get doctorDetailChartCards => _s('doctorDetailChartCards');
  String get doctorDetailChartMarket => _s('doctorDetailChartMarket');
  String get doctorDetailChartMoodCanvas => _s('doctorDetailChartMoodCanvas');
  String get doctorDetailMoodCanvasTitle => _s('doctorDetailMoodCanvasTitle');
  String get doctorDetailMoodCanvasCaption => _s('doctorDetailMoodCanvasCaption');
  String get doctorMoodCanvasDetailTitle => _s('doctorMoodCanvasDetailTitle');
  String get doctorMoodCanvasTranscriptLabel => _s('doctorMoodCanvasTranscriptLabel');
  String get doctorMoodCanvasNoteLabel => _s('doctorMoodCanvasNoteLabel');
  String get doctorMoodCanvasNoteHint => _s('doctorMoodCanvasNoteHint');
  String doctorMoodCanvasNotedByline(String name, String date) =>
      _f('doctorMoodCanvasNotedByline', <String, Object?>{'name': name, 'date': date});
  String get doctorMoodCanvasNoteSaved => _s('doctorMoodCanvasNoteSaved');
  String get doctorMoodCanvasSaveNote => _s('doctorMoodCanvasSaveNote');
  String get caregiverChartLabelMarket => _s('caregiverChartLabelMarket');

  // ── Doctor — patients list ───────────────────────────────────────
  String doctorPatientsSubtitle(int shown, int total) => _f('doctorPatientsSubtitle', <String, Object?>{'shown': shown, 'total': total});
  String get doctorPatientsSearchHint => _s('doctorPatientsSearchHint');
  String get doctorPatientsFilterAll => _s('doctorPatientsFilterAll');
  String get doctorPatientsEmptyTitle => _s('doctorPatientsEmptyTitle');
  String get doctorPatientsEmptyMessage => _s('doctorPatientsEmptyMessage');
  String get doctorPatientsColumnKeyTitle => _s('doctorPatientsColumnKeyTitle');
  String get doctorPatientsColumnKeyBody => _s('doctorPatientsColumnKeyBody');
  String get doctorPatientsLegendImproving => _s('doctorPatientsLegendImproving');
  String get doctorPatientsLegendStable => _s('doctorPatientsLegendStable');
  String get doctorPatientsLegendDeclining => _s('doctorPatientsLegendDeclining');

  // ── Doctor — alerts ──────────────────────────────────────────────
  String doctorAlertsSubtitle(int count) => _f('doctorAlertsSubtitle', <String, Object?>{'count': count});
  String get doctorAlertsSeverityAssessment => _s('doctorAlertsSeverityAssessment');
  String get doctorAlertsSeverityAttention => _s('doctorAlertsSeverityAttention');
  String get doctorAlertsSeverityInformational => _s('doctorAlertsSeverityInformational');
  String get doctorAlertsOpenRecord => _s('doctorAlertsOpenRecord');

  // ── Doctor — analytics ───────────────────────────────────────────
  String get doctorAnalyticsSubtitle => _s('doctorAnalyticsSubtitle');
  String get doctorAnalyticsMeanScoreLabel => _s('doctorAnalyticsMeanScoreLabel');
  String get doctorAnalyticsAcrossCaseload => _s('doctorAnalyticsAcrossCaseload');
  String get doctorAnalyticsMeanAdherenceLabel => _s('doctorAnalyticsMeanAdherenceLabel');
  String get doctorAnalyticsRemindersCompleted => _s('doctorAnalyticsRemindersCompleted');
  String get doctorAnalyticsPatientsTrendingDown => _s('doctorAnalyticsPatientsTrendingDown');
  String get doctorAnalyticsScoreDistTitle => _s('doctorAnalyticsScoreDistTitle');
  String get doctorAnalyticsScoreDistCaption => _s('doctorAnalyticsScoreDistCaption');
  String get doctorAnalyticsDomainTitle => _s('doctorAnalyticsDomainTitle');
  String get doctorAnalyticsDomainCaption => _s('doctorAnalyticsDomainCaption');
  String get doctorAnalyticsEngagementTitle => _s('doctorAnalyticsEngagementTitle');
  String get doctorAnalyticsEngagementCaption => _s('doctorAnalyticsEngagementCaption');
  String get doctorAnalyticsSessionsTitle => _s('doctorAnalyticsSessionsTitle');
  String get doctorAnalyticsSessionsCaption => _s('doctorAnalyticsSessionsCaption');
  String get doctorAnalyticsDistrictTitle => _s('doctorAnalyticsDistrictTitle');
  String get doctorAnalyticsDistrictCaption => _s('doctorAnalyticsDistrictCaption');
  String get doctorAnalyticsDistrictAssam => _s('doctorAnalyticsDistrictAssam');
  String get doctorAnalyticsDistrictManipur => _s('doctorAnalyticsDistrictManipur');
  String get doctorAnalyticsDistrictMeghalaya => _s('doctorAnalyticsDistrictMeghalaya');
  String get doctorAnalyticsDistrictNagaland => _s('doctorAnalyticsDistrictNagaland');
  String get doctorAnalyticsDistrictMizoram => _s('doctorAnalyticsDistrictMizoram');
  String get doctorAnalyticsDistrictTripura => _s('doctorAnalyticsDistrictTripura');

  // ── Doctor — overview ────────────────────────────────────────────
  String get doctorOverviewTitle => _s('doctorOverviewTitle');
  String doctorOverviewGreeting(String name) => _f('doctorOverviewGreeting', <String, Object?>{'name': name});
  String get doctorOverviewActiveCaption => _s('doctorOverviewActiveCaption');
  String get doctorOverviewSessionsWeekLabel => _s('doctorOverviewSessionsWeekLabel');
  String get doctorOverviewSessionsWeekCaption => _s('doctorOverviewSessionsWeekCaption');
  String get doctorOverviewCaseloadStatusLabel => _s('doctorOverviewCaseloadStatusLabel');
  String doctorOverviewLegendStable(int count) => _f('doctorOverviewLegendStable', <String, Object?>{'count': count});
  String doctorOverviewLegendNeedsAttention(int count) => _f('doctorOverviewLegendNeedsAttention', <String, Object?>{'count': count});
  String doctorOverviewLegendFollowUp(int count) => _f('doctorOverviewLegendFollowUp', <String, Object?>{'count': count});
  String get doctorOverviewTrendTitle => _s('doctorOverviewTrendTitle');
  String get doctorOverviewTrendCaption => _s('doctorOverviewTrendCaption');
  String get doctorOverviewNeedsReviewTitle => _s('doctorOverviewNeedsReviewTitle');
  String get doctorOverviewAllPatients => _s('doctorOverviewAllPatients');
  String get doctorOverviewRecentAlertsTitle => _s('doctorOverviewRecentAlertsTitle');
  String get doctorOverviewAllAlerts => _s('doctorOverviewAllAlerts');
  String get doctorOverviewMonthJanuary => _s('doctorOverviewMonthJanuary');
  String get doctorOverviewMonthFebruary => _s('doctorOverviewMonthFebruary');
  String get doctorOverviewMonthMarch => _s('doctorOverviewMonthMarch');
  String get doctorOverviewMonthApril => _s('doctorOverviewMonthApril');
  String get doctorOverviewMonthMay => _s('doctorOverviewMonthMay');
  String get doctorOverviewMonthJune => _s('doctorOverviewMonthJune');
  String get doctorOverviewMonthJuly => _s('doctorOverviewMonthJuly');
  String get doctorOverviewMonthAugust => _s('doctorOverviewMonthAugust');
  String get doctorOverviewMonthSeptember => _s('doctorOverviewMonthSeptember');
  String get doctorOverviewMonthOctober => _s('doctorOverviewMonthOctober');
  String get doctorOverviewMonthNovember => _s('doctorOverviewMonthNovember');
  String get doctorOverviewMonthDecember => _s('doctorOverviewMonthDecember');

  // ── Doctor — appointments & new features ────────────────────────
  String get doctorTabAppointments => _s('doctorTabAppointments');
  String get doctorOverviewTodayAppts => _s('doctorOverviewTodayAppts');
  String doctorOverviewConnectionRequests(int count) => _f('doctorOverviewConnectionRequests', <String, Object?>{'count': count});
  String get doctorOverviewRecentActivity => _s('doctorOverviewRecentActivity');
  String get doctorOverviewNoAppts => _s('doctorOverviewNoAppts');
  String get doctorApptVirtual => _s('doctorApptVirtual');
  String get doctorApptInPerson => _s('doctorApptInPerson');
  String get doctorApptJoin => _s('doctorApptJoin');
  String get doctorApptUpcoming => _s('doctorApptUpcoming');
  String get doctorApptPast => _s('doctorApptPast');
  String get doctorApptTitle => _s('doctorApptTitle');
  String doctorApptSubtitle(int upcoming) => _f('doctorApptSubtitle', <String, Object?>{'upcoming': upcoming});
  String get doctorApptEmptyUpcoming => _s('doctorApptEmptyUpcoming');
  String get doctorApptEmptyUpcomingMsg => _s('doctorApptEmptyUpcomingMsg');
  String get doctorApptEmptyPast => _s('doctorApptEmptyPast');
  String get doctorApptSetAvailability => _s('doctorApptSetAvailability');
  String get doctorApptDetailTitle => _s('doctorApptDetailTitle');
  String get doctorApptDetailAI => _s('doctorApptDetailAI');
  String get doctorApptDetailAIView => _s('doctorApptDetailAIView');
  String get doctorApptDetailJoinVideo => _s('doctorApptDetailJoinVideo');
  String get doctorApptDetailVideoNote => _s('doctorApptDetailVideoNote');
  String get doctorApptDetailNotesTitle => _s('doctorApptDetailNotesTitle');
  String get doctorApptDetailNotesHint => _s('doctorApptDetailNotesHint');
  String get doctorApptDetailSaveNotes => _s('doctorApptDetailSaveNotes');
  String get doctorApptDetailNotesSaved => _s('doctorApptDetailNotesSaved');
  String get doctorApptDetailCareplanTitle => _s('doctorApptDetailCareplanTitle');
  String get doctorApptDetailOpenCareplan => _s('doctorApptDetailOpenCareplan');
  String get doctorApptDetailPatientInfo => _s('doctorApptDetailPatientInfo');
  String get doctorSlotsTitle => _s('doctorSlotsTitle');
  String get doctorSlotsSubtitle => _s('doctorSlotsSubtitle');
  String doctorSlotsBooked(String patient) => _f('doctorSlotsBooked', <String, Object?>{'patient': patient});
  String get doctorSlotsAvailable => _s('doctorSlotsAvailable');
  String get doctorSlotsAddSlot => _s('doctorSlotsAddSlot');
  String get doctorSlotsRemove => _s('doctorSlotsRemove');
  String get doctorAIPreconsultTitle => _s('doctorAIPreconsultTitle');
  String get doctorAIPreconsultSubtitle => _s('doctorAIPreconsultSubtitle');
  String get doctorAIPreconsultDisclaimer => _s('doctorAIPreconsultDisclaimer');
  String get doctorAIPreconsultActivity => _s('doctorAIPreconsultActivity');
  String get doctorAIPreconsultMood => _s('doctorAIPreconsultMood');
  String get doctorAIPreconsultMedication => _s('doctorAIPreconsultMedication');
  String get doctorAIPreconsultCognitive => _s('doctorAIPreconsultCognitive');
  String get doctorAIPreconsultCaregiver => _s('doctorAIPreconsultCaregiver');
  String get doctorAIPreconsultStartConsult => _s('doctorAIPreconsultStartConsult');
  String get doctorReportsTitle => _s('doctorReportsTitle');
  String doctorReportsSubtitle(int count) => _f('doctorReportsSubtitle', <String, Object?>{'count': count});
  String get doctorReportsUpload => _s('doctorReportsUpload');
  String get doctorReportsUploadNote => _s('doctorReportsUploadNote');
  String get doctorReportsAISummary => _s('doctorReportsAISummary');
  String get doctorReportsAISummaryTitle => _s('doctorReportsAISummaryTitle');
  String get doctorReportsAIDisclaimer => _s('doctorReportsAIDisclaimer');
  String get doctorReportsOriginal => _s('doctorReportsOriginal');
  String get doctorReportsOriginalNote => _s('doctorReportsOriginalNote');
  String get doctorReportsStatus => _s('doctorReportsStatus');
  String get doctorReportsUploadedBy => _s('doctorReportsUploadedBy');
  String get doctorReportsNoSummary => _s('doctorReportsNoSummary');
  String get doctorCarePlanTitle => _s('doctorCarePlanTitle');
  String doctorCarePlanSubtitle(String date) => _f('doctorCarePlanSubtitle', <String, Object?>{'date': date});
  String get doctorCarePlanRecommendations => _s('doctorCarePlanRecommendations');
  String get doctorCarePlanActivities => _s('doctorCarePlanActivities');
  String get doctorCarePlanInstructions => _s('doctorCarePlanInstructions');
  String get doctorCarePlanFollowUp => _s('doctorCarePlanFollowUp');
  String get doctorCarePlanEdit => _s('doctorCarePlanEdit');
  String get doctorCarePlanSave => _s('doctorCarePlanSave');
  String get doctorCarePlanShare => _s('doctorCarePlanShare');
  String get doctorCarePlanShared => _s('doctorCarePlanShared');
  String get doctorCarePlanSharedNote => _s('doctorCarePlanSharedNote');
  String get doctorDetailCarePlan => _s('doctorDetailCarePlan');
  String get doctorDetailMedicalReports => _s('doctorDetailMedicalReports');
  String get doctorDetailAIPreconsult => _s('doctorDetailAIPreconsult');
  String get doctorDetailCaregiverObs => _s('doctorDetailCaregiverObs');
  String get doctorDetailMedicationInfo => _s('doctorDetailMedicationInfo');
  String get doctorDetailMoodTrends => _s('doctorDetailMoodTrends');
  String get doctorDetailMoodTrendsCaption => _s('doctorDetailMoodTrendsCaption');
  String get doctorDetailCaregiverNote1 => _s('doctorDetailCaregiverNote1');
  String get doctorDetailCaregiverNote2 => _s('doctorDetailCaregiverNote2');
  String get doctorDetailMedAdherence => _s('doctorDetailMedAdherence');
  String get doctorDetailReminderSchedule => _s('doctorDetailReminderSchedule');
  String get doctorDetailMorning => _s('doctorDetailMorning');
  String get doctorDetailEvening => _s('doctorDetailEvening');
  String get doctorAlertsSectionConnection => _s('doctorAlertsSectionConnection');
  String get doctorAlertsSectionApptReminders => _s('doctorAlertsSectionApptReminders');
  String get doctorAlertsSectionNewReports => _s('doctorAlertsSectionNewReports');
  String get doctorAlertsSectionFollowUp => _s('doctorAlertsSectionFollowUp');
  String get doctorAlertsAccept => _s('doctorAlertsAccept');
  String get doctorAlertsDecline => _s('doctorAlertsDecline');
  String get doctorAlertsAccepted => _s('doctorAlertsAccepted');
  String get doctorAlertsSchedule => _s('doctorAlertsSchedule');
  String doctorAlertsApptIn(String time) => _f('doctorAlertsApptIn', <String, Object?>{'time': time});
  String doctorAlertsNewReport(String patient, String kind) => _f('doctorAlertsNewReport', <String, Object?>{'patient': patient, 'kind': kind});
  String doctorAlertsFollowUpDue(String patient, String date) => _f('doctorAlertsFollowUpDue', <String, Object?>{'patient': patient, 'date': date});
  String get doctorAnalyticsAdherenceTitle => _s('doctorAnalyticsAdherenceTitle');
  String get doctorAnalyticsAdherenceCaption => _s('doctorAnalyticsAdherenceCaption');
  String get doctorAnalyticsWellnessTitle => _s('doctorAnalyticsWellnessTitle');
  String get doctorAnalyticsWellnessCaption => _s('doctorAnalyticsWellnessCaption');
  String get doctorAnalyticsMoodTitle => _s('doctorAnalyticsMoodTitle');
  String get doctorAnalyticsMoodCaption => _s('doctorAnalyticsMoodCaption');
  String get doctorAnalyticsMoodHappy => _s('doctorAnalyticsMoodHappy');
  String get doctorAnalyticsMoodNeutral => _s('doctorAnalyticsMoodNeutral');
  String get doctorAnalyticsMoodAnxious => _s('doctorAnalyticsMoodAnxious');


  // ── Caregiver — nav ──────────────────────────────────────────────
  String get caregiverNavDashboard => _s('caregiverNavDashboard');
  String get caregiverNavPatient => _s('caregiverNavPatient');
  String get caregiverNavActivity => _s('caregiverNavActivity');
  String get caregiverNavReminders => _s('caregiverNavReminders');
  String get caregiverNavProfile => _s('caregiverNavProfile');

  // ── Caregiver — reminders ────────────────────────────────────────
  String get caregiverRemindersTitle => _s('caregiverRemindersTitle');
  String caregiverSubtitleToday(String name) => _f('caregiverSubtitleToday', <String, Object?>{'name': name});
  String get caregiverAdherenceToday => _s('caregiverAdherenceToday');
  String get caregiverAdherenceTitle => _s('caregiverAdherenceTitle');
  String caregiverAdherenceSummary(int done, int total, int medDone, int medTotal) => _f('caregiverAdherenceSummary', <String, Object?>{'done': done, 'total': total, 'medDone': medDone, 'medTotal': medTotal});
  String get caregiverAdherenceWeekLabel => _s('caregiverAdherenceWeekLabel');
  String get caregiverReminderChannelsTitle => _s('caregiverReminderChannelsTitle');
  String caregiverReminderChannelsBody(String language) => _f('caregiverReminderChannelsBody', <String, Object?>{'language': language});

  // ── Caregiver — activity ─────────────────────────────────────────
  String get caregiverActivityTitle => _s('caregiverActivityTitle');
  String caregiverSubtitleLast7Days(String name) => _f('caregiverSubtitleLast7Days', <String, Object?>{'name': name});
  String get caregiverStatEngagement => _s('caregiverStatEngagement');
  String get caregiverStatAccuracy => _s('caregiverStatAccuracy');
  String get caregiverStatActivitiesCompleted => _s('caregiverStatActivitiesCompleted');
  String get caregiverStatReminderAdherence => _s('caregiverStatReminderAdherence');
  String get caregiverChartEngagementTitle => _s('caregiverChartEngagementTitle');
  String get caregiverChartEngagementCaption => _s('caregiverChartEngagementCaption');
  String get caregiverChartActivitiesTitle => _s('caregiverChartActivitiesTitle');
  String get caregiverChartActivitiesCaption => _s('caregiverChartActivitiesCaption');
  String get caregiverChartScoreTitle => _s('caregiverChartScoreTitle');
  String get caregiverChartScoreCaption => _s('caregiverChartScoreCaption');
  String get caregiverChartMemoryTitle => _s('caregiverChartMemoryTitle');
  String get caregiverChartMemoryCaption => _s('caregiverChartMemoryCaption');
  String get caregiverChartAdherenceCaption => _s('caregiverChartAdherenceCaption');
  String get caregiverAdaptiveDifficultyTitle => _s('caregiverAdaptiveDifficultyTitle');
  String get caregiverAdaptiveDifficultySubtitle => _s('caregiverAdaptiveDifficultySubtitle');
  String get caregiverRecentSessionsTitle => _s('caregiverRecentSessionsTitle');
  String get caregiverChartLabelProcedure => _s('caregiverChartLabelProcedure');
  String get caregiverChartLabelStory => _s('caregiverChartLabelStory');
  String get caregiverChartLabelPlace => _s('caregiverChartLabelPlace');
  String get caregiverChartLabelMelody => _s('caregiverChartLabelMelody');
  String get caregiverChartLabelWeaves => _s('caregiverChartLabelWeaves');
  String get caregiverChartLabelCards => _s('caregiverChartLabelCards');
  String get caregiverYesterday => _s('caregiverYesterday');
  String caregiverDaysAgo(int days) => _f('caregiverDaysAgo', <String, Object?>{'days': days});
  String caregiverSessionMeta(String when, String time, String level, String hints) => _f('caregiverSessionMeta', <String, Object?>{'when': when, 'time': time, 'level': level, 'hints': hints});
  String caregiverHintsUsedOne(int count) => _f('caregiverHintsUsedOne', <String, Object?>{'count': count});
  String caregiverHintsUsedMany(int count) => _f('caregiverHintsUsedMany', <String, Object?>{'count': count});
  String caregiverVillageMarketBudgetNote(int n) =>
      _f('caregiverVillageMarketBudgetNote', <String, Object?>{'n': n});

  // ── Caregiver — profile ──────────────────────────────────────────
  String get caregiverRelationLabel => _s('caregiverRelationLabel');
  String caregiverCaringForLabel(String name) => _f('caregiverCaringForLabel', <String, Object?>{'name': name});
  String get caregiverPatientExperienceTitle => _s('caregiverPatientExperienceTitle');
  String get caregiverPatientExperienceSubtitle => _s('caregiverPatientExperienceSubtitle');
  String get caregiverTextSizeLabel => _s('caregiverTextSizeLabel');
  String caregiverVoicePromptsToggle(String language) => _f('caregiverVoicePromptsToggle', <String, Object?>{'language': language});
  String get caregiverOfflineFirstTitle => _s('caregiverOfflineFirstTitle');
  String get caregiverOfflineFirstSubtitle => _s('caregiverOfflineFirstSubtitle');
  String get caregiverSimulateOfflineLabel => _s('caregiverSimulateOfflineLabel');
  String caregiverOfflineAllOnDevice(int count) => _f('caregiverOfflineAllOnDevice', <String, Object?>{'count': count});
  String caregiverActivitiesReadyToSync(int count) => _f('caregiverActivitiesReadyToSync', <String, Object?>{'count': count});
  String get caregiverAllActivitiesSynced => _s('caregiverAllActivitiesSynced');
  String get caregiverSyncing => _s('caregiverSyncing');
  String get caregiverSyncNow => _s('caregiverSyncNow');
  String get caregiverSetupPatientProfileTitle => _s('caregiverSetupPatientProfileTitle');
  String get caregiverSetupPatientProfileSubtitle => _s('caregiverSetupPatientProfileSubtitle');
  String get caregiverSetupPatientProfileDetail => _s('caregiverSetupPatientProfileDetail');
  String get caregiverOpenHerExperienceTitle => _s('caregiverOpenHerExperienceTitle');
  String caregiverOpenHerExperienceSubtitle(String name) => _f('caregiverOpenHerExperienceSubtitle', <String, Object?>{'name': name});
  String get caregiverDoctorAppointmentSubtitle => _s('caregiverDoctorAppointmentSubtitle');
  String get caregiverSwitchRoleButton => _s('caregiverSwitchRoleButton');

  // ── Caregiver — dashboard ────────────────────────────────────────
  String get caregiverRoleLabel => _s('caregiverRoleLabel');
  String get caregiverTodaysOverviewTitle => _s('caregiverTodaysOverviewTitle');
  String get caregiverMedicationRemindersLabel => _s('caregiverMedicationRemindersLabel');
  String get caregiverMoodLabel => _s('caregiverMoodLabel');
  String get caregiverNotRecorded => _s('caregiverNotRecorded');
  String get caregiverLastActiveLabel => _s('caregiverLastActiveLabel');
  String get caregiverCognitiveProgressTitle => _s('caregiverCognitiveProgressTitle');
  String get caregiverDetailsAction => _s('caregiverDetailsAction');
  String get caregiverEngagementThisWeek => _s('caregiverEngagementThisWeek');
  String get caregiverDailyEngagementWeekLabel => _s('caregiverDailyEngagementWeekLabel');
  String get caregiverTodaysActivitiesTitle => _s('caregiverTodaysActivitiesTitle');
  String get caregiverNothingCompletedTitle => _s('caregiverNothingCompletedTitle');
  String get caregiverNothingCompletedBody => _s('caregiverNothingCompletedBody');
  String get caregiverManageAction => _s('caregiverManageAction');
  String get caregiverAdherenceTodayLabel => _s('caregiverAdherenceTodayLabel');
  String caregiverRemindersMarkedDone(int done, int total) => _f('caregiverRemindersMarkedDone', <String, Object?>{'done': done, 'total': total});
  String get caregiverDoneButton => _s('caregiverDoneButton');
  String get caregiverNotesForYouTitle => _s('caregiverNotesForYouTitle');
  String get caregiverAlertProceduralTitle => _s('caregiverAlertProceduralTitle');
  String caregiverAlertProceduralBody(int pct) => _f('caregiverAlertProceduralBody', <String, Object?>{'pct': pct});
  String get caregiverAlertEveningTitle => _s('caregiverAlertEveningTitle');
  String caregiverAlertEveningBody(String name) => _f('caregiverAlertEveningBody', <String, Object?>{'name': name});
  String get caregiverAlertMoodTitle => _s('caregiverAlertMoodTitle');
  String get caregiverAlertMoodBody => _s('caregiverAlertMoodBody');
  String get caregiverPersonalisationTitle => _s('caregiverPersonalisationTitle');
  String get caregiverPersonalisationSubtitle => _s('caregiverPersonalisationSubtitle');
  String get caregiverYourPatientLabel => _s('caregiverYourPatientLabel');
  String caregiverAgeLocation(int age, String location) => _f('caregiverAgeLocation', <String, Object?>{'age': age, 'location': location});
  String caregiverLastActiveInline(String when) => _f('caregiverLastActiveInline', <String, Object?>{'when': when});
  String get caregiverOpenProfileLabel => _s('caregiverOpenProfileLabel');
  String get caregiverEngagedLabel => _s('caregiverEngagedLabel');
  String caregiverSessionLine(String time, String level, String duration) => _f('caregiverSessionLine', <String, Object?>{'time': time, 'level': level, 'duration': duration});
  String get caregiverMonthJan => _s('caregiverMonthJan');
  String get caregiverMonthFeb => _s('caregiverMonthFeb');
  String get caregiverMonthMar => _s('caregiverMonthMar');
  String get caregiverMonthApr => _s('caregiverMonthApr');
  String get caregiverMonthMay => _s('caregiverMonthMay');
  String get caregiverMonthJun => _s('caregiverMonthJun');
  String get caregiverMonthJul => _s('caregiverMonthJul');
  String get caregiverMonthAug => _s('caregiverMonthAug');
  String get caregiverMonthSep => _s('caregiverMonthSep');
  String get caregiverMonthOct => _s('caregiverMonthOct');
  String get caregiverMonthNov => _s('caregiverMonthNov');
  String get caregiverMonthDec => _s('caregiverMonthDec');
  String get caregiverWeekdayMon => _s('caregiverWeekdayMon');
  String get caregiverWeekdayTue => _s('caregiverWeekdayTue');
  String get caregiverWeekdayWed => _s('caregiverWeekdayWed');
  String get caregiverWeekdayThu => _s('caregiverWeekdayThu');
  String get caregiverWeekdayFri => _s('caregiverWeekdayFri');
  String get caregiverWeekdaySat => _s('caregiverWeekdaySat');
  String get caregiverWeekdaySun => _s('caregiverWeekdaySun');

  // ── Caregiver — memory profile ───────────────────────────────────
  String get caregiverTabPeople => _s('caregiverTabPeople');
  String get caregiverTabMemories => _s('caregiverTabMemories');
  String get caregiverTabPhotographs => _s('caregiverTabPhotographs');
  String get caregiverTabRoutine => _s('caregiverTabRoutine');
  String get caregiverMemoryProfileTitle => _s('caregiverMemoryProfileTitle');
  String get caregiverMemoryProfileSubtitle => _s('caregiverMemoryProfileSubtitle');
  String get caregiverRerunOnboardingButton => _s('caregiverRerunOnboardingButton');
  String get caregiverPeopleTitle => _s('caregiverPeopleTitle');
  String get caregiverPeopleSubtitle => _s('caregiverPeopleSubtitle');
  String get caregiverRemoveTooltip => _s('caregiverRemoveTooltip');
  String get caregiverSuggestedToAddLabel => _s('caregiverSuggestedToAddLabel');
  String get caregiverMemoriesTitle => _s('caregiverMemoriesTitle');
  String get caregiverMemoriesSubtitle => _s('caregiverMemoriesSubtitle');
  String get caregiverSaveButton => _s('caregiverSaveButton');
  String get caregiverNoPhotographsTitle => _s('caregiverNoPhotographsTitle');
  String get caregiverNoPhotographsBody => _s('caregiverNoPhotographsBody');
  String get caregiverPhotographsTitle => _s('caregiverPhotographsTitle');
  String caregiverPhotographsSubtitle(int count) => _f('caregiverPhotographsSubtitle', <String, Object?>{'count': count});
  String get caregiverDailyRoutineTitle => _s('caregiverDailyRoutineTitle');
  String get caregiverDailyRoutineSubtitle => _s('caregiverDailyRoutineSubtitle');

  // ── Caregiver — onboarding ───────────────────────────────────────
  String get caregiverLangBodo => _s('caregiverLangBodo');
  String get caregiverLangMeiteilon => _s('caregiverLangMeiteilon');
  String get caregiverLangKhasi => _s('caregiverLangKhasi');
  String get caregiverLangMizo => _s('caregiverLangMizo');
  String get caregiverLangNagamese => _s('caregiverLangNagamese');
  String get caregiverLangBengali => _s('caregiverLangBengali');
  String caregiverStepLabel(int step, int total) => _f('caregiverStepLabel', <String, Object?>{'step': step, 'total': total});
  String get caregiverStepTitleIdentity => _s('caregiverStepTitleIdentity');
  String get caregiverStepTitleFamily => _s('caregiverStepTitleFamily');
  String get caregiverStepTitleRoutine => _s('caregiverStepTitleRoutine');
  String get caregiverStepTitleReady => _s('caregiverStepTitleReady');
  String get caregiverBackButton => _s('caregiverBackButton');
  String get caregiverCreateCompanionButton => _s('caregiverCreateCompanionButton');
  String get caregiverStep1Companion => _s('caregiverStep1Companion');
  String get caregiverStep2Companion => _s('caregiverStep2Companion');
  String get caregiverStep3Companion => _s('caregiverStep3Companion');
  String get caregiverStep4Companion => _s('caregiverStep4Companion');
  String get caregiverStep5Companion => _s('caregiverStep5Companion');
  String get caregiverHerPhotographLabel => _s('caregiverHerPhotographLabel');
  String get caregiverDemoPhotosNote => _s('caregiverDemoPhotosNote');
  String get caregiverFieldFullName => _s('caregiverFieldFullName');
  String get caregiverFieldShortName => _s('caregiverFieldShortName');
  String get caregiverFieldPhone => _s('caregiverFieldPhone');
  String get caregiverFieldLocation => _s('caregiverFieldLocation');
  String get caregiverAgeLabel => _s('caregiverAgeLabel');
  String caregiverAgeYears(int age) => _f('caregiverAgeYears', <String, Object?>{'age': age});
  String get caregiverPreferredLanguageLabel => _s('caregiverPreferredLanguageLabel');
  String get caregiverAddedLabel => _s('caregiverAddedLabel');
  String get caregiverTapToAddLabel => _s('caregiverTapToAddLabel');
  String get caregiverEveryoneAddedMessage => _s('caregiverEveryoneAddedMessage');
  String get caregiverAddEveryoneButton => _s('caregiverAddEveryoneButton');
  String get caregiverFillSuggestedButton => _s('caregiverFillSuggestedButton');
  String caregiverAssetsSelectedCount(int selected, int total) => _f('caregiverAssetsSelectedCount', <String, Object?>{'selected': selected, 'total': total});
  String get caregiverClearAllButton => _s('caregiverClearAllButton');
  String get caregiverSelectAllButton => _s('caregiverSelectAllButton');
  String get caregiverRestoreRoutineButton => _s('caregiverRestoreRoutineButton');
  String caregiverReviewSummary(int age, String location, String language) => _f('caregiverReviewSummary', <String, Object?>{'age': age, 'location': location, 'language': language});
  String get caregiverWhatThisChangesTitle => _s('caregiverWhatThisChangesTitle');
  String get caregiverWhatThisChangesSubtitle => _s('caregiverWhatThisChangesSubtitle');
  String caregiverReviewLineFamily(String name, String familyName) => _f('caregiverReviewLineFamily', <String, Object?>{'name': name, 'familyName': familyName});
  String get caregiverReviewLineWeaving => _s('caregiverReviewLineWeaving');
  String get caregiverReviewLineCooking => _s('caregiverReviewLineCooking');
  String get caregiverReviewLineInstruments => _s('caregiverReviewLineInstruments');
  String caregiverReviewLineLanguage(String language) => _f('caregiverReviewLineLanguage', <String, Object?>{'language': language});
  String get caregiverSheFallback => _s('caregiverSheFallback');
  String caregiverCompanionReadyTitle(String name) => _f('caregiverCompanionReadyTitle', <String, Object?>{'name': name});
  String get caregiverCompanionReadyBody => _s('caregiverCompanionReadyBody');
  String get caregiverBackToDashboardButton => _s('caregiverBackToDashboardButton');
  String get caregiverProfileCreatedToday => _s('caregiverProfileCreatedToday');


  // ── Intake — welcome ─────────────────────────────────────────────
  String get intakeWelcomeHeadline => _s('intakeWelcomeHeadline');
  String get intakeWelcomeSubtitle => _s('intakeWelcomeSubtitle');
  String get intakePillarUnderstandTitle => _s('intakePillarUnderstandTitle');
  String get intakePillarUnderstandDetail => _s('intakePillarUnderstandDetail');
  String get intakePillarTrackTitle => _s('intakePillarTrackTitle');
  String get intakePillarTrackDetail => _s('intakePillarTrackDetail');
  String get intakePillarSupportTitle => _s('intakePillarSupportTitle');
  String get intakePillarSupportDetail => _s('intakePillarSupportDetail');
  String get intakeWelcomeDisclaimer => _s('intakeWelcomeDisclaimer');
  String get intakeGetStarted => _s('intakeGetStarted');
  String get intakeAlreadyHaveAccount => _s('intakeAlreadyHaveAccount');

  // ── Intake — kit ─────────────────────────────────────────────────
  String get intakeBack => _s('intakeBack');
  String intakeStepProgress(int index, int count) => _f('intakeStepProgress', <String, Object?>{'index': index, 'count': count});
  String get intakeDiagnosisDisclaimerStandard => _s('intakeDiagnosisDisclaimerStandard');

  // ── Intake — consent/profile ─────────────────────────────────────
  String get intakeConsentSymptomsLabel => _s('intakeConsentSymptomsLabel');
  String get intakeConsentSymptomsDetail => _s('intakeConsentSymptomsDetail');
  String get intakeConsentDailyActivitiesLabel => _s('intakeConsentDailyActivitiesLabel');
  String get intakeConsentDailyActivitiesDetail => _s('intakeConsentDailyActivitiesDetail');
  String get intakeConsentActivityPerformanceLabel => _s('intakeConsentActivityPerformanceLabel');
  String get intakeConsentActivityPerformanceDetail => _s('intakeConsentActivityPerformanceDetail');
  String get intakeConsentHealthHistoryLabel => _s('intakeConsentHealthHistoryLabel');
  String get intakeConsentHealthHistoryDetail => _s('intakeConsentHealthHistoryDetail');
  String get intakeConsentVoicePrompt => _s('intakeConsentVoicePrompt');
  String get intakeYes => _s('intakeYes');
  String get intakeNo => _s('intakeNo');
  String get intakeConsentTitle => _s('intakeConsentTitle');
  String get intakeConsentSubtitle => _s('intakeConsentSubtitle');
  String get intakeConsentFootnote => _s('intakeConsentFootnote');
  String get intakeConsentUsageTitle => _s('intakeConsentUsageTitle');
  String get intakeConsentUsageBody => _s('intakeConsentUsageBody');
  String get intakeConsentDiagnosisAck => _s('intakeConsentDiagnosisAck');
  String get intakeConsentDiagnosisAckDetail => _s('intakeConsentDiagnosisAckDetail');
  String get intakeProfileNamePrompt => _s('intakeProfileNamePrompt');
  String get intakeProfileAgePrompt => _s('intakeProfileAgePrompt');
  String get intakeProfileLanguagePrompt => _s('intakeProfileLanguagePrompt');
  String get intakeProfileProfessionPrompt => _s('intakeProfileProfessionPrompt');
  String get intakeProfileCompletedByPrompt => _s('intakeProfileCompletedByPrompt');
  String get intakeProfileTitle => _s('intakeProfileTitle');
  String get intakeProfileSubtitle => _s('intakeProfileSubtitle');
  String get intakeProfileNameLabel => _s('intakeProfileNameLabel');
  String get intakeProfileAgeLabel => _s('intakeProfileAgeLabel');
  String get intakeProfileLanguageLabel => _s('intakeProfileLanguageLabel');
  String get intakeProfileProfessionLabel => _s('intakeProfileProfessionLabel');
  String get intakeProfileProfessionHint => _s('intakeProfileProfessionHint');
  String get intakeProfileCompletedByLabel => _s('intakeProfileCompletedByLabel');

  // ── Intake — medical/caregiver ───────────────────────────────────
  String get intakeMedicalSleepPrompt => _s('intakeMedicalSleepPrompt');
  String get intakeMedicalMoodPrompt => _s('intakeMedicalMoodPrompt');
  String get intakeMedicalTitle => _s('intakeMedicalTitle');
  String get intakeMedicalSubtitle => _s('intakeMedicalSubtitle');
  String get intakeMedicalFootnote => _s('intakeMedicalFootnote');
  String get intakeMedicalConditionsLabel => _s('intakeMedicalConditionsLabel');
  String get intakeMedicalSleepSectionTitle => _s('intakeMedicalSleepSectionTitle');
  String get intakeMedicalSleepHoursLabel => _s('intakeMedicalSleepHoursLabel');
  String get intakeMedicalSleepQualityLabel => _s('intakeMedicalSleepQualityLabel');
  String get intakeMedicalMoodSectionTitle => _s('intakeMedicalMoodSectionTitle');
  String get intakeMedicalMedicationSectionTitle => _s('intakeMedicalMedicationSectionTitle');
  String get intakeMedicalRemoveMedication => _s('intakeMedicalRemoveMedication');
  String get intakeMedicalAddMedicationHint => _s('intakeMedicalAddMedicationHint');
  String get intakeCaregiverDefaultName => _s('intakeCaregiverDefaultName');
  String get intakeCaregiverInviteTitle => _s('intakeCaregiverInviteTitle');
  String get intakeCaregiverInviteSubtitle => _s('intakeCaregiverInviteSubtitle');
  String get intakeCaregiverAddObservations => _s('intakeCaregiverAddObservations');
  String get intakeCaregiverSkip => _s('intakeCaregiverSkip');
  String get intakeCaregiverWhyHelpsTitle => _s('intakeCaregiverWhyHelpsTitle');
  String get intakeCaregiverWhyHelpsBody => _s('intakeCaregiverWhyHelpsBody');
  String get intakeCaregiverObservationsTitle => _s('intakeCaregiverObservationsTitle');
  String get intakeCaregiverObservationsSubtitle => _s('intakeCaregiverObservationsSubtitle');
  String get intakeCaregiverObservationsFootnote => _s('intakeCaregiverObservationsFootnote');
  String get intakeCaregiverNameLabel => _s('intakeCaregiverNameLabel');
  String get intakeCaregiverRelationLabel => _s('intakeCaregiverRelationLabel');
  String get intakeCaregiverNoteLabel => _s('intakeCaregiverNoteLabel');
  String get intakeMedicalAddMedicationPrompt => _s('intakeMedicalAddMedicationPrompt');
  String get intakeCaregiverNamePrompt => _s('intakeCaregiverNamePrompt');
  String get intakeCaregiverRelationPrompt => _s('intakeCaregiverRelationPrompt');
  String get intakeCaregiverNotePrompt => _s('intakeCaregiverNotePrompt');

  // ── Intake — reason/safety ───────────────────────────────────────
  String get intakeReasonTitle => _s('intakeReasonTitle');
  String get intakeReasonSubtitle => _s('intakeReasonSubtitle');
  String get intakeReasonFootnote => _s('intakeReasonFootnote');
  String get intakeReasonOnsetLabel => _s('intakeReasonOnsetLabel');
  String get intakeReasonProgressionLabel => _s('intakeReasonProgressionLabel');
  String get intakeSafetyQuestionSuddenOnset => _s('intakeSafetyQuestionSuddenOnset');
  String get intakeSafetyQuestionAlertness => _s('intakeSafetyQuestionAlertness');
  String get intakeSafetyQuestionAlertnessDetailed => _s('intakeSafetyQuestionAlertnessDetailed');
  String get intakeSafetyQuestionNeuroRedFlag => _s('intakeSafetyQuestionNeuroRedFlag');
  String get intakeSafetyTitle => _s('intakeSafetyTitle');
  String get intakeSafetySubtitle => _s('intakeSafetySubtitle');
  String get intakeSafetyFootnote => _s('intakeSafetyFootnote');
  String get intakeSafetyUrgentTitle => _s('intakeSafetyUrgentTitle');
  String get intakeSafetyUrgentBody => _s('intakeSafetyUrgentBody');
  String get intakeSafetyConsultDoctor => _s('intakeSafetyConsultDoctor');
  String get intakeSafetyDialogTitle => _s('intakeSafetyDialogTitle');
  String get intakeSafetyDialogBody1 => _s('intakeSafetyDialogBody1');
  String get intakeSafetyDialogBody2 => _s('intakeSafetyDialogBody2');
  String get intakeSafetyDialogDisclaimer => _s('intakeSafetyDialogDisclaimer');

  // ── Intake — symptoms/function ───────────────────────────────────
  String get intakeSymptomFrequencyQuestion => _s('intakeSymptomFrequencyQuestion');
  String get intakeSymptomsFinish => _s('intakeSymptomsFinish');
  String get intakeSymptomsNextGroup => _s('intakeSymptomsNextGroup');
  String get intakeSymptomsFootnote => _s('intakeSymptomsFootnote');
  String get intakeSymptomsDetailIntro => _s('intakeSymptomsDetailIntro');
  String intakeSymptomsNothingToReport(int count) => _f('intakeSymptomsNothingToReport', <String, Object?>{'count': count});
  String get intakeSymptomsAnswerIndividually => _s('intakeSymptomsAnswerIndividually');
  String get intakeSymptomsDisclaimer => _s('intakeSymptomsDisclaimer');
  String get intakeFunctionHelpPrompt => _s('intakeFunctionHelpPrompt');
  String get intakeFunctionByMyself => _s('intakeFunctionByMyself');
  String get intakeFunctionLittleHelp => _s('intakeFunctionLittleHelp');
  String get intakeFunctionLotHelp => _s('intakeFunctionLotHelp');
  String get intakeFunctionTitle => _s('intakeFunctionTitle');
  String get intakeFunctionSubtitle => _s('intakeFunctionSubtitle');
  String get intakeFunctionAllTickedFootnote => _s('intakeFunctionAllTickedFootnote');
  String get intakeFunctionTapToChange => _s('intakeFunctionTapToChange');
  String get intakeFunctionLegendTicked => _s('intakeFunctionLegendTicked');
  String get intakeFunctionLegendUnticked => _s('intakeFunctionLegendUnticked');
  String get intakeFunctionStartTickedNote => _s('intakeFunctionStartTickedNote');
  String get intakeFunctionDoingByYourselfLabel => _s('intakeFunctionDoingByYourselfLabel');
  String get intakeFunctionDisclaimer => _s('intakeFunctionDisclaimer');
  String get intakeFunctionWithHelp => _s('intakeFunctionWithHelp');
  String intakeFunctionHowMuchHelp(String activity) => _f('intakeFunctionHowMuchHelp', <String, Object?>{'activity': activity});
  String get intakeFunctionALittle => _s('intakeFunctionALittle');
  String get intakeFunctionALot => _s('intakeFunctionALot');

  // ── Intake — baseline ────────────────────────────────────────────
  String get intakeBaselineFriendFallback => _s('intakeBaselineFriendFallback');
  String get intakeBaselineChartDailyLiving => _s('intakeBaselineChartDailyLiving');
  String get intakeBaselineChartSteadyDays => _s('intakeBaselineChartSteadyDays');
  String get intakeBaselineChartSupport => _s('intakeBaselineChartSupport');
  String get intakeBaselineChartHealthBasics => _s('intakeBaselineChartHealthBasics');
  String get intakeBaselineEyebrow => _s('intakeBaselineEyebrow');
  String get intakeBaselineTitle => _s('intakeBaselineTitle');
  String intakeBaselineSubtitle(String name) => _f('intakeBaselineSubtitle', <String, Object?>{'name': name});
  String get intakeBaselineStartJourney => _s('intakeBaselineStartJourney');
  String get intakeBaselineFootnote => _s('intakeBaselineFootnote');
  String intakeBaselineCompanionThanks(String name) => _f('intakeBaselineCompanionThanks', <String, Object?>{'name': name});
  String get intakeBaselineStrengthsTitle => _s('intakeBaselineStrengthsTitle');
  String get intakeBaselineStrengthsSubtitle => _s('intakeBaselineStrengthsSubtitle');
  String get intakeBaselineBenefitsTitle => _s('intakeBaselineBenefitsTitle');
  String get intakeBaselineBenefit1 => _s('intakeBaselineBenefit1');
  String get intakeBaselineBenefit2 => _s('intakeBaselineBenefit2');
  String get intakeBaselineBenefit3 => _s('intakeBaselineBenefit3');
  String get intakeBaselinePlanTitle => _s('intakeBaselinePlanTitle');
  String get intakeBaselinePlanSubtitle => _s('intakeBaselinePlanSubtitle');
  String intakeBaselineDayN(int day) => _f('intakeBaselineDayN', <String, Object?>{'day': day});
  String get intakeBaselineTwoActivities => _s('intakeBaselineTwoActivities');
  String get intakeBaselineDisclaimer => _s('intakeBaselineDisclaimer');
  String get intakeBaselineCaptureError => _s('intakeBaselineCaptureError');
  String intakeBaselineDayOfTotal(int day, int total) => _f('intakeBaselineDayOfTotal', <String, Object?>{'day': day, 'total': total});
  String get intakeBaselineAllSixDone => _s('intakeBaselineAllSixDone');
  String get intakeBaselineTodaysSession => _s('intakeBaselineTodaysSession');
  String get intakeBaselineBuildingProfile => _s('intakeBaselineBuildingProfile');
  String get intakeBaselineTodaySubtitle => _s('intakeBaselineTodaySubtitle');
  String get intakeBaselineSeeProfile => _s('intakeBaselineSeeProfile');
  String get intakeBaselineDoneForToday => _s('intakeBaselineDoneForToday');
  String intakeBaselineStartGame(String game) => _f('intakeBaselineStartGame', <String, Object?>{'game': game});
  String get intakeBaselineCompanionAllDone => _s('intakeBaselineCompanionAllDone');
  String get intakeBaselineCompanionStart => _s('intakeBaselineCompanionStart');
  String get intakeBaselineCompanionOneToGo => _s('intakeBaselineCompanionOneToGo');
  String intakeBaselineTotalProgress(int done, int total, int days) => _f('intakeBaselineTotalProgress', <String, Object?>{'done': done, 'total': total, 'days': days});
  String intakeBaselineSessionComplete(int day) => _f('intakeBaselineSessionComplete', <String, Object?>{'day': day});
  String intakeBaselineActivityMinutes(String domain, int minutes) => _f('intakeBaselineActivityMinutes', <String, Object?>{'domain': domain, 'minutes': minutes});
  String get intakeBaselineDone => _s('intakeBaselineDone');

  // ── Intake — voice panel ─────────────────────────────────────────
  String get intakeVoiceAnswerBySpeaking => _s('intakeVoiceAnswerBySpeaking');
  String get intakeVoiceCouldNotHear => _s('intakeVoiceCouldNotHear');
  String get intakeVoiceInstructions => _s('intakeVoiceInstructions');
  String get intakeVoiceTapToRetry => _s('intakeVoiceTapToRetry');
  String get intakeVoiceDoneSpeaking => _s('intakeVoiceDoneSpeaking');
  String get intakeVoiceTurnOff => _s('intakeVoiceTurnOff');
  String get intakeVoicePhaseListening => _s('intakeVoicePhaseListening');
  String get intakeVoicePhaseAsking => _s('intakeVoicePhaseAsking');
  String get intakeVoicePhaseWaitingMic => _s('intakeVoicePhaseWaitingMic');
  String get intakeVoicePhaseStopped => _s('intakeVoicePhaseStopped');
  String get intakeVoicePhaseReady => _s('intakeVoicePhaseReady');


  // ── Patient — common ─────────────────────────────────────────────
  String get actionBack => _s('actionBack');
  String get actionEdit => _s('actionEdit');
  String statusPillDay(int day, int total) => _f('statusPillDay', <String, Object?>{'day': day, 'total': total});
  String statusPillCountToday(int count) => _f('statusPillCountToday', <String, Object?>{'count': count});

  // ── Patient — memory home ────────────────────────────────────────
  String get memoryHomeEyebrow => _s('memoryHomeEyebrow');
  String get memoryHomeTitle => _s('memoryHomeTitle');
  String get memoryHomeSubtitleEmpty => _s('memoryHomeSubtitleEmpty');
  String memoryHomeSubtitleProgress(int furnished, int total) => _f('memoryHomeSubtitleProgress', <String, Object?>{'furnished': furnished, 'total': total});
  String get memoryHomeTapToLookInside => _s('memoryHomeTapToLookInside');
  String get memoryHomeNotFurnishedYet => _s('memoryHomeNotFurnishedYet');
  String memoryHomeSharedOn(String date) => _f('memoryHomeSharedOn', <String, Object?>{'date': date});
  String memoryHomeRevisitedCount(int count) => _f('memoryHomeRevisitedCount', <String, Object?>{'count': count});
  String get memoryHomeEntryTitle => _s('memoryHomeEntryTitle');
  String get memoryHomeEntryEmpty => _s('memoryHomeEntryEmpty');
  String memoryHomeEntryProgress(int furnished, int total) => _f('memoryHomeEntryProgress', <String, Object?>{'furnished': furnished, 'total': total});

  // ── Patient — assistant screen ───────────────────────────────────
  String get assistantErrorFallback => _s('assistantErrorFallback');
  String get assistantEyebrow => _s('assistantEyebrow');
  String get assistantScreenTitle => _s('assistantScreenTitle');
  String get assistantScreenSubtitle => _s('assistantScreenSubtitle');
  String assistantIntroGreeting(String name) => _f('assistantIntroGreeting', <String, Object?>{'name': name});
  String get assistantIntroDisclaimer => _s('assistantIntroDisclaimer');
  String get assistantMemorySavedChip => _s('assistantMemorySavedChip');
  String get assistantGeneralInfoNote => _s('assistantGeneralInfoNote');
  String get assistantOpenSummary => _s('assistantOpenSummary');
  String get assistantAskQuestionHint => _s('assistantAskQuestionHint');

  // ── Patient — memory wallet ──────────────────────────────────────
  String get walletTabFamily => _s('walletTabFamily');
  String get walletTabPlaces => _s('walletTabPlaces');
  String get walletTabStories => _s('walletTabStories');
  String get walletTabFavourites => _s('walletTabFavourites');
  String get walletTabAll => _s('walletTabAll');
  String get walletTitle => _s('walletTitle');
  String get walletSubtitle => _s('walletSubtitle');
  String get walletFavouriteActivity => _s('walletFavouriteActivity');
  String get walletFavouriteFood => _s('walletFavouriteFood');
  String get walletFavouriteTradition => _s('walletFavouriteTradition');
  String get walletHerWork => _s('walletHerWork');
  String get walletTellMeAboutThis => _s('walletTellMeAboutThis');
  String get walletNoFamilyTitle => _s('walletNoFamilyTitle');
  String get walletNoFamilyMessage => _s('walletNoFamilyMessage');
  String get walletNoStoriesTitle => _s('walletNoStoriesTitle');
  String get walletNoStoriesMessage => _s('walletNoStoriesMessage');
  String get walletNothingHereTitle => _s('walletNothingHereTitle');
  String get walletNothingHereMessage => _s('walletNothingHereMessage');
  String get walletNoFavouritesTitle => _s('walletNoFavouritesTitle');
  String get walletNoFavouritesMessage => _s('walletNoFavouritesMessage');

  // ── Patient — care plan ──────────────────────────────────────────
  String get carePlanEyebrow => _s('carePlanEyebrow');
  String get carePlanTitle => _s('carePlanTitle');
  String get carePlanSubtitle => _s('carePlanSubtitle');
  String get carePlanWeeklyAssessmentTitle => _s('carePlanWeeklyAssessmentTitle');
  String carePlanWeeklyAssessmentDetail(int completed, int expected) => _f('carePlanWeeklyAssessmentDetail', <String, Object?>{'completed': completed, 'expected': expected});
  String get carePlanDailyActivityTitle => _s('carePlanDailyActivityTitle');
  String get carePlanDailyActivityDetail => _s('carePlanDailyActivityDetail');
  String get carePlanMedicationTitle => _s('carePlanMedicationTitle');
  String carePlanMedicationDetail(int done, int total) => _f('carePlanMedicationDetail', <String, Object?>{'done': done, 'total': total});
  String get carePlanCaregiverCheckInTitle => _s('carePlanCaregiverCheckInTitle');
  String carePlanCaregiverCheckInDetail(String name) => _f('carePlanCaregiverCheckInDetail', <String, Object?>{'name': name});
  String get carePlanDiscussWithDoctor => _s('carePlanDiscussWithDoctor');
  String get carePlanKeepSummaryReady => _s('carePlanKeepSummaryReady');
  String get carePlanDiscussDetail => _s('carePlanDiscussDetail');
  String get carePlanKeepReadyDetail => _s('carePlanKeepReadyDetail');
  String get carePlanNextReview => _s('carePlanNextReview');
  String get carePlanDisclaimer => _s('carePlanDisclaimer');


  // ── Patient — health widgets ─────────────────────────────────────
  String get healthNotYetAssessed => _s('healthNotYetAssessed');
  String get healthCognitiveHealthLabel => _s('healthCognitiveHealthLabel');
  String get healthFirstResult => _s('healthFirstResult');
  String healthVsBaseline(int score) => _f('healthVsBaseline', <String, Object?>{'score': score});
  String get healthViewCognitiveProfile => _s('healthViewCognitiveProfile');

  // ── Patient — report ─────────────────────────────────────────────
  String get reportEyebrow => _s('reportEyebrow');
  String get reportTitle => _s('reportTitle');
  String get reportObservedPatternsTitle => _s('reportObservedPatternsTitle');
  String get reportObservedPatternsSubtitle => _s('reportObservedPatternsSubtitle');
  String get reportSuggestsDiscussion => _s('reportSuggestsDiscussion');
  String reportAgeYears(int age) => _f('reportAgeYears', <String, Object?>{'age': age});
  String reportCompletedBy(String who) => _f('reportCompletedBy', <String, Object?>{'who': who});
  String get reportCopySummaryButton => _s('reportCopySummaryButton');
  String get reportCopiedSnackbar => _s('reportCopiedSnackbar');
  String get reportPlainTextNote => _s('reportPlainTextNote');

  // ── Patient — cognitive profile ──────────────────────────────────
  String get cognitiveDomainMemory => _s('cognitiveDomainMemory');
  String get cognitiveDomainAttention => _s('cognitiveDomainAttention');
  String get cognitiveDomainLanguage => _s('cognitiveDomainLanguage');
  String get cognitiveDomainSpatial => _s('cognitiveDomainSpatial');
  String get cognitiveDomainAuditory => _s('cognitiveDomainAuditory');
  String get cognitiveDomainExecutive => _s('cognitiveDomainExecutive');
  String get cognitiveByDomainTitle => _s('cognitiveByDomainTitle');
  String get cognitiveBaselineCompleteEyebrow => _s('cognitiveBaselineCompleteEyebrow');
  String get cognitiveProfileEyebrow => _s('cognitiveProfileEyebrow');
  String get cognitiveStartingPointTitle => _s('cognitiveStartingPointTitle');
  String get cognitiveStartingPointSubtitle => _s('cognitiveStartingPointSubtitle');
  String get cognitiveProfileTitle => _s('cognitiveProfileTitle');
  String get cognitiveProfileSubtitle => _s('cognitiveProfileSubtitle');
  String get cognitiveWellDone => _s('cognitiveWellDone');
  String get cognitiveAcrossSixDomains => _s('cognitiveAcrossSixDomains');
  String get cognitiveChartNow => _s('cognitiveChartNow');
  String get cognitiveChartBaseline => _s('cognitiveChartBaseline');
  String get cognitiveFirstMeasurement => _s('cognitiveFirstMeasurement');
  String get cognitiveCurrentScoreChange => _s('cognitiveCurrentScoreChange');
  String get cognitivePatternsObservedTitle => _s('cognitivePatternsObservedTitle');
  String get cognitivePatternsObservedSubtitle => _s('cognitivePatternsObservedSubtitle');
  String get cognitivePatternsDisclaimer => _s('cognitivePatternsDisclaimer');
  String get cognitiveGoToDashboard => _s('cognitiveGoToDashboard');
  String get cognitivePrepareSummary => _s('cognitivePrepareSummary');
  String get cognitiveKeyObservation => _s('cognitiveKeyObservation');
  String get cognitiveFirstSessionReference => _s('cognitiveFirstSessionReference');
  String get cognitiveChangeMultipleAreas => _s('cognitiveChangeMultipleAreas');

  // ── Patient — result ─────────────────────────────────────────────
  String get resultCognitivePerformance => _s('resultCognitivePerformance');

  // ── Patient — games ──────────────────────────────────────────────
  String get gamesTodaysCognitiveJourney => _s('gamesTodaysCognitiveJourney');


  // ── Patient — dashboard ──────────────────────────────────────────
  String get dashboardBackToTop => _s('dashboardBackToTop');
  String get dashboardAskCompanion => _s('dashboardAskCompanion');
  String get dashboardExplainResults => _s('dashboardExplainResults');
  String get dashboardDoctorSummary => _s('dashboardDoctorSummary');
  String get dashboardReadyToShare => _s('dashboardReadyToShare');
  String get dashboardCarePlan => _s('dashboardCarePlan');
  String get dashboardDoctorConversationSuggested => _s('dashboardDoctorConversationSuggested');
  String get dashboardWeeklyAndDaily => _s('dashboardWeeklyAndDaily');
  String get dashboardMemoryWallet => _s('dashboardMemoryWallet');
  String get dashboardPeopleAndPlaces => _s('dashboardPeopleAndPlaces');
  String get dashboardCheckInReminders => _s('dashboardCheckInReminders');
  String get dashboardCognitiveHealthOnePlace => _s('dashboardCognitiveHealthOnePlace');
  String get dashboardBuildStartingPoint => _s('dashboardBuildStartingPoint');
  String get dashboardRestingToday => _s('dashboardRestingToday');
  String get dashboardJourneyStart => _s('dashboardJourneyStart');
  String dashboardJourneyWelcomeBack(int day) => _f('dashboardJourneyWelcomeBack', <String, Object?>{'day': day});
  String dashboardDayOf(int day, int total) => _f('dashboardDayOf', <String, Object?>{'day': day, 'total': total});
  String dashboardActivitiesDone(int done, int total) => _f('dashboardActivitiesDone', <String, Object?>{'done': done, 'total': total});
  String get dashboardGapBetweenSessions => _s('dashboardGapBetweenSessions');
  String get dashboardIHaveTimeContinue => _s('dashboardIHaveTimeContinue');
  String get dashboardYourProgress => _s('dashboardYourProgress');
  String get dashboardNothingToShowYet => _s('dashboardNothingToShowYet');
  String get dashboardFirstActivityStarts => _s('dashboardFirstActivityStarts');
  String get dashboardWeeklyAveragesBaseline => _s('dashboardWeeklyAveragesBaseline');
  String get dashboardBuildingTowardsBaseline => _s('dashboardBuildingTowardsBaseline');
  String get dashboardOverallActivityScore => _s('dashboardOverallActivityScore');
  String dashboardBaselineScore(int score) => _f('dashboardBaselineScore', <String, Object?>{'score': score});
  String get dashboardAdherence => _s('dashboardAdherence');
  String get dashboardConsistency => _s('dashboardConsistency');
  String get dashboardReportedIndependence => _s('dashboardReportedIndependence');
  String get dashboardMoreAboutProgress => _s('dashboardMoreAboutProgress');
  String dashboardSeeAllAreas(int count) => _f('dashboardSeeAllAreas', <String, Object?>{'count': count});
  String dashboardWeeksAssessed(int completed, int expected) => _f('dashboardWeeksAssessed', <String, Object?>{'completed': completed, 'expected': expected});
  String get dashboardWhyScoreChanged => _s('dashboardWhyScoreChanged');
  String get dashboardWhyScoreChangedDetail => _s('dashboardWhyScoreChangedDetail');
  String get dashboardExplainMyChange => _s('dashboardExplainMyChange');
  String get dashboardShowLess => _s('dashboardShowLess');
  String get dashboardThinkingOfQuestion => _s('dashboardThinkingOfQuestion');
  String get dashboardJustAMoment => _s('dashboardJustAMoment');
  String get dashboardQuestionForYou => _s('dashboardQuestionForYou');
  String get dashboardAskedBecauseOfWhatYouTold => _s('dashboardAskedBecauseOfWhatYouTold');
  String get dashboardTodaysReminders => _s('dashboardTodaysReminders');
  String dashboardRemindersDone(int done, int total) => _f('dashboardRemindersDone', <String, Object?>{'done': done, 'total': total});


  // ── Patient — profile ────────────────────────────────────────────
  String get settingsVoicePromptsLabel => _s('settingsVoicePromptsLabel');
  String get profileSheLoves => _s('profileSheLoves');
  String get profileFamily => _s('profileFamily');
  String profileFamilyCount(int count) => _f('profileFamilyCount', <String, Object?>{'count': count});
  String get profilePhoneNumber => _s('profilePhoneNumber');
  String get profileChangesApplyRightAway => _s('profileChangesApplyRightAway');
  String get profileAssessment => _s('profileAssessment');
  String profileBaselineCaptured(int sessions) => _f('profileBaselineCaptured', <String, Object?>{'sessions': sessions});
  String get profileNotCompletedYet => _s('profileNotCompletedYet');
  String get profileDoctorSummarySubtitle => _s('profileDoctorSummarySubtitle');
  String get profileLoadDemoHistory => _s('profileLoadDemoHistory');
  String get profileLoadDemoHistorySubtitle => _s('profileLoadDemoHistorySubtitle');
  String get profileDemoHistoryLoaded => _s('profileDemoHistoryLoaded');
  String get profileStartAssessmentOver => _s('profileStartAssessmentOver');
  String get profileStartAssessmentOverSubtitle => _s('profileStartAssessmentOverSubtitle');
  String get profileCareTeam => _s('profileCareTeam');
  String get profileCaregiverCallsEvening => _s('profileCaregiverCallsEvening');
  String get profileMemoryClinicSchedule => _s('profileMemoryClinicSchedule');
  String get profileLogOutQuestion => _s('profileLogOutQuestion');
  String get profileLogOutBody => _s('profileLogOutBody');
  String get profileStaySignedIn => _s('profileStaySignedIn');
  String get profileLogOut => _s('profileLogOut');
  String get profileAccount => _s('profileAccount');
  String get profileAnswersFiledUnderAccount => _s('profileAnswersFiledUnderAccount');
  String get profileNotSignedIn => _s('profileNotSignedIn');
  String get profileSignedIn => _s('profileSignedIn');
  String get profileNoAccount => _s('profileNoAccount');
  String get profileSignInToKeepRecord => _s('profileSignInToKeepRecord');
  String get profileSignIn => _s('profileSignIn');
  String get profileSmsAlertsMobileNumber => _s('profileSmsAlertsMobileNumber');
  String get profileSmsAlertsSubtitle => _s('profileSmsAlertsSubtitle');
  String get profilePhoneHint => _s('profilePhoneHint');
  String get profilePhoneLabel => _s('profilePhoneLabel');
  String get profileSaveNumber => _s('profileSaveNumber');
  String get profileNoMobileNumberYet => _s('profileNoMobileNumberYet');
  String get profilePhoneNumberRemoved => _s('profilePhoneNumberRemoved');
  String get profilePhoneNumberUpdated => _s('profilePhoneNumberUpdated');


  // ── Patient — today screen ───────────────────────────────────────
  String get todayTipDoingGreat => _s('todayTipDoingGreat');
  String get todayTipDrinkWater => _s('todayTipDrinkWater');
  String get todayTipMitraHere => _s('todayTipMitraHere');
  String get todayTipTakeMeds => _s('todayTipTakeMeds');
  String get todayStatusLabel => _s('todayStatusLabel');
  String todayCompletedCount(int done, int total) => _f('todayCompletedCount', <String, Object?>{'done': done, 'total': total});
  String get todayRemindersTitle => _s('todayRemindersTitle');
  String todayDoneCount(int done, int total) => _f('todayDoneCount', <String, Object?>{'done': done, 'total': total});
  String get todayCreateReminderButton => _s('todayCreateReminderButton');
  String get todayAllClear => _s('todayAllClear');
  String get todayNoRemindersEnjoy => _s('todayNoRemindersEnjoy');
  String get todayReminderNameRequired => _s('todayReminderNameRequired');
  String get todayCreateNewReminderTitle => _s('todayCreateNewReminderTitle');
  String get todayReminderNameLabel => _s('todayReminderNameLabel');
  String get todayReminderNameHint => _s('todayReminderNameHint');
  String get todayCategoryLabel => _s('todayCategoryLabel');
  String get todayCategoryMedicines => _s('todayCategoryMedicines');
  String get todayCategoryHydration => _s('todayCategoryHydration');
  String get todayCategoryDailyActivity => _s('todayCategoryDailyActivity');
  String get todayCategoryAppointment => _s('todayCategoryAppointment');
  String get todayCategoryDailyRoutine => _s('todayCategoryDailyRoutine');
  String get todayCategorySocialActivity => _s('todayCategorySocialActivity');
  String get todaySetTimeLabel => _s('todaySetTimeLabel');
  String get todayTapToChangeTime => _s('todayTapToChangeTime');
  String get todayPreset8am => _s('todayPreset8am');
  String get todayPreset1230pm => _s('todayPreset1230pm');
  String get todayPreset5pm => _s('todayPreset5pm');
  String get todayPreset9pm => _s('todayPreset9pm');
  String get todayNotesLabel => _s('todayNotesLabel');
  String get todayNotesHint => _s('todayNotesHint');
  String get todaySmsAlertLabel => _s('todaySmsAlertLabel');
  String get todaySmsAlertNote => _s('todaySmsAlertNote');
  String get todaySaveReminderButton => _s('todaySaveReminderButton');
  String get todayTimeOfDayMorning => _s('todayTimeOfDayMorning');
  String get todayTimeOfDayAfternoon => _s('todayTimeOfDayAfternoon');
  String get todayTimeOfDayEvening => _s('todayTimeOfDayEvening');
  String todayReactionMedicine(String timeOfDay) => _f('todayReactionMedicine', <String, Object?>{'timeOfDay': timeOfDay});
  String todayReactionHydration(String timeOfDay) => _f('todayReactionHydration', <String, Object?>{'timeOfDay': timeOfDay});
  String todayReactionCognitive(String timeOfDay) => _f('todayReactionCognitive', <String, Object?>{'timeOfDay': timeOfDay});
  String todayReactionAppointment(String timeOfDay) => _f('todayReactionAppointment', <String, Object?>{'timeOfDay': timeOfDay});
  String todayReactionRoutine(String timeOfDay) => _f('todayReactionRoutine', <String, Object?>{'timeOfDay': timeOfDay});
  String todayReactionSocial(String timeOfDay) => _f('todayReactionSocial', <String, Object?>{'timeOfDay': timeOfDay});
  String get todayMonthJanuary => _s('todayMonthJanuary');
  String get todayMonthFebruary => _s('todayMonthFebruary');
  String get todayMonthMarch => _s('todayMonthMarch');
  String get todayMonthApril => _s('todayMonthApril');
  String get todayMonthMay => _s('todayMonthMay');
  String get todayMonthJune => _s('todayMonthJune');
  String get todayMonthJuly => _s('todayMonthJuly');
  String get todayMonthAugust => _s('todayMonthAugust');
  String get todayMonthSeptember => _s('todayMonthSeptember');
  String get todayMonthOctober => _s('todayMonthOctober');
  String get todayMonthNovember => _s('todayMonthNovember');
  String get todayMonthDecember => _s('todayMonthDecember');
  String get todayWeekdayMonday => _s('todayWeekdayMonday');
  String get todayWeekdayTuesday => _s('todayWeekdayTuesday');
  String get todayWeekdayWednesday => _s('todayWeekdayWednesday');
  String get todayWeekdayThursday => _s('todayWeekdayThursday');
  String get todayWeekdayFriday => _s('todayWeekdayFriday');
  String get todayWeekdaySaturday => _s('todayWeekdaySaturday');
  String get todayWeekdaySunday => _s('todayWeekdaySunday');


  // ── Games — shared ───────────────────────────────────────────────
  String get gameLevelEasy => _s('gameLevelEasy');
  String get gameLevelMedium => _s('gameLevelMedium');
  String get gameLevelHard => _s('gameLevelHard');
  String get gameLevelExpert => _s('gameLevelExpert');
  String get gameLevelMastery => _s('gameLevelMastery');
  String get gameLevelLocked => _s('gameLevelLocked');
  String get gameMemoryCardsChooseLevel => _s('gameMemoryCardsChooseLevel');
  String get gameStartGame => _s('gameStartGame');
  String get gameWeavesFinish => _s('gameWeavesFinish');

  // ── Games — memory cards ─────────────────────────────────────────
  String get gameMemoryCardsPairsFound => _s('gameMemoryCardsPairsFound');
  String get gameMemoryCardsTries => _s('gameMemoryCardsTries');
  String get gameMemoryCardsWrongTurns => _s('gameMemoryCardsWrongTurns');
  String gameMemoryCardsStepLabel(int found, int pairs) => _f('gameMemoryCardsStepLabel', <String, Object?>{'found': found, 'pairs': pairs});
  String gameMemoryCardsAllFound(String name) => _f('gameMemoryCardsAllFound', <String, Object?>{'name': name});
  String gameMemoryCardsFoundMatch(String name) => _f('gameMemoryCardsFoundMatch', <String, Object?>{'name': name});
  String get gameMemoryCardsTurnOverTwo => _s('gameMemoryCardsTurnOverTwo');
  String get gameMemoryCardsIntroMessage => _s('gameMemoryCardsIntroMessage');
  String gameMemoryCardsPairsCount(int n) => _f('gameMemoryCardsPairsCount', <String, Object?>{'n': n});
  String get gameMemoryCardsCategoryLabel => _s('gameMemoryCardsCategoryLabel');
  String get gameMemoryCardsTitle => _s('gameMemoryCardsTitle');
  String get gameMemoryCardsInstructions => _s('gameMemoryCardsInstructions');


  // ── Games — weaves ───────────────────────────────────────────────
  String get gameWeavesFeedbackCorrect => _s('gameWeavesFeedbackCorrect');
  String get gameWeavesFeedbackWrong => _s('gameWeavesFeedbackWrong');
  String get gameWeavesPatternsRebuilt => _s('gameWeavesPatternsRebuilt');
  String get gameWeavesPiecesPlaced => _s('gameWeavesPiecesPlaced');
  String get gameWeavesSecondLooks => _s('gameWeavesSecondLooks');
  String get gameWeavesLookCarefully => _s('gameWeavesLookCarefully');
  String get gameWeavesNowRebuild => _s('gameWeavesNowRebuild');
  String get gameWeavesWhichPiece => _s('gameWeavesWhichPiece');
  String get gameWeavesBeautiful => _s('gameWeavesBeautiful');
  String gameWeavesPatternOfTotal(int r, int t) => _f('gameWeavesPatternOfTotal', <String, Object?>{'r': r, 't': t});
  String get gameWeavesNextPattern => _s('gameWeavesNextPattern');
  String gameWeavesHidingIn(int seconds) => _f('gameWeavesHidingIn', <String, Object?>{'seconds': seconds});
  String gameWeavesMemorise(int seconds) => _f('gameWeavesMemorise', <String, Object?>{'seconds': seconds});
  String gameWeavesPlacedCount(int filled, int total) => _f('gameWeavesPlacedCount', <String, Object?>{'filled': filled, 'total': total});
  String get gameWeavesCoveredHint => _s('gameWeavesCoveredHint');
  String get gameWeavesChooseMissingPiece => _s('gameWeavesChooseMissingPiece');
  String get gameWeavesIntroMessage => _s('gameWeavesIntroMessage');
  String get gameWeavesStartPattern => _s('gameWeavesStartPattern');
  String get gameWeavesSubtitle1Blank => _s('gameWeavesSubtitle1Blank');
  String get gameWeavesSubtitleHiddenWeave => _s('gameWeavesSubtitleHiddenWeave');
  String get gameWeavesSubtitle2Blanks => _s('gameWeavesSubtitle2Blanks');
  String get gameWeavesSubtitleFastWeave => _s('gameWeavesSubtitleFastWeave');
  String get gameWeavesSubtitle4x4Grid => _s('gameWeavesSubtitle4x4Grid');
  String get gameWeavesCategoryLabel => _s('gameWeavesCategoryLabel');
  String get gameWeavesTitle => _s('gameWeavesTitle');
  String get gameWeavesInstructions => _s('gameWeavesInstructions');


  // ── Games — melody ───────────────────────────────────────────────
  String get gameMelodyTunesPlayed => _s('gameMelodyTunesPlayed');
  String get gameMelodyNotesInTune => _s('gameMelodyNotesInTune');
  String get gameMelodyReplaysUsed => _s('gameMelodyReplaysUsed');
  String get gameMelodyIntroMessage => _s('gameMelodyIntroMessage');
  String get gameMelodyListening => _s('gameMelodyListening');
  String get gameMelodyNowYou => _s('gameMelodyNowYou');
  String get gameMelodyExactlyRight => _s('gameMelodyExactlyRight');
  String get gameMelodyClose => _s('gameMelodyClose');
  String gameMelodyTuneOfTotal(int r, int t) => _f('gameMelodyTuneOfTotal', <String, Object?>{'r': r, 't': t});
  String get gameMelodySubtitle2Notes => _s('gameMelodySubtitle2Notes');
  String get gameMelodySubtitle3Notes => _s('gameMelodySubtitle3Notes');
  String get gameMelodySubtitle4Notes => _s('gameMelodySubtitle4Notes');
  String get gameMelodySubtitle4NotesFast => _s('gameMelodySubtitle4NotesFast');
  String get gameMelodySubtitle5NotesFast => _s('gameMelodySubtitle5NotesFast');
  String get gameMelodyYourTune => _s('gameMelodyYourTune');
  String get gameMelodyTheTune => _s('gameMelodyTheTune');
  String gameMelodyNoteCount(int n) => _f('gameMelodyNoteCount', <String, Object?>{'n': n});
  String get gameMelodyPrototypeNote => _s('gameMelodyPrototypeNote');
  String get gameMelodyPlayTheTune => _s('gameMelodyPlayTheTune');
  String get gameMelodyListeningButton => _s('gameMelodyListeningButton');
  String get gameMelodyPlayItAgain => _s('gameMelodyPlayItAgain');
  String get gameMelodyNextTune => _s('gameMelodyNextTune');


  // ── Games — procedure ────────────────────────────────────────────
  String get gameProcedureCompleteSequence => _s('gameProcedureCompleteSequence');
  String gameProcedureCorrectNext(String s) => _f('gameProcedureCorrectNext', <String, Object?>{'s': s});
  String gameProcedureNotQuite(String s) => _f('gameProcedureNotQuite', <String, Object?>{'s': s});
  String get gameProcedureVeryBeginning => _s('gameProcedureVeryBeginning');
  String gameProcedureHintNextStep(String s) => _f('gameProcedureHintNextStep', <String, Object?>{'s': s});
  String get gameProcedureShowSteps => _s('gameProcedureShowSteps');
  String get gameProcedureSelectedLabel => _s('gameProcedureSelectedLabel');
  String gameProcedureStepsCount(int n) => _f('gameProcedureStepsCount', <String, Object?>{'n': n});
  String get gameProcedureVideoAvailable => _s('gameProcedureVideoAvailable');
  String get gameProcedureWatchVideoLabel => _s('gameProcedureWatchVideoLabel');
  String get gameProcedureStudyStepsLabel => _s('gameProcedureStudyStepsLabel');
  String get gameProcedureWatchVideoMessage => _s('gameProcedureWatchVideoMessage');
  String gameProcedureReadThroughSteps(String t) => _f('gameProcedureReadThroughSteps', <String, Object?>{'t': t});
  String get gameProcedureReadyToBuild => _s('gameProcedureReadyToBuild');
  String gameProcedurePlacedOfTotal(int p, int t) => _f('gameProcedurePlacedOfTotal', <String, Object?>{'p': p, 't': t});
  String gameProcedureWholeSequence(String name) => _f('gameProcedureWholeSequence', <String, Object?>{'name': name});
  String get gameProcedureWhatComesFirst => _s('gameProcedureWhatComesFirst');
  String gameProcedureWhatComesAfter(String s) => _f('gameProcedureWhatComesAfter', <String, Object?>{'s': s});
  String get gameProcedureSequenceSoFar => _s('gameProcedureSequenceSoFar');
  String get gameProcedureTapNextStep => _s('gameProcedureTapNextStep');
  String get gameProcedureChooseStepBelow => _s('gameProcedureChooseStepBelow');
  String get gameProcedureVideoLoadError => _s('gameProcedureVideoLoadError');
  String get gameProcedureReplayVideo => _s('gameProcedureReplayVideo');


  // ── Games — familiar place ───────────────────────────────────────
  String gameFamiliarPlaceExcellentFound(String name) => _f('gameFamiliarPlaceExcellentFound', <String, Object?>{'name': name});
  String get gameFamiliarPlaceNotWhatWeAreLookingFor => _s('gameFamiliarPlaceNotWhatWeAreLookingFor');
  String get gameFamiliarPlaceObjectsToFind => _s('gameFamiliarPlaceObjectsToFind');
  String get gameFamiliarPlaceObjectsFound => _s('gameFamiliarPlaceObjectsFound');
  String get gameFamiliarPlaceRoomsVisited => _s('gameFamiliarPlaceRoomsVisited');
  String get gameFamiliarPlaceHintsUsed => _s('gameFamiliarPlaceHintsUsed');
  String get gameFamiliarPlaceIntroMessage => _s('gameFamiliarPlaceIntroMessage');
  String get gameFamiliarPlaceStartExploring => _s('gameFamiliarPlaceStartExploring');
  String gameFamiliarPlaceRoomsCount(int n) => _f('gameFamiliarPlaceRoomsCount', <String, Object?>{'n': n});
  String get gameFamiliarPlaceSubtitle5RoomsOneHint => _s('gameFamiliarPlaceSubtitle5RoomsOneHint');
  String get gameFamiliarPlaceSubtitle5RoomsFast => _s('gameFamiliarPlaceSubtitle5RoomsFast');
  String get gameFamiliarPlaceCategoryLabel => _s('gameFamiliarPlaceCategoryLabel');
  String get gameFamiliarPlaceTitle => _s('gameFamiliarPlaceTitle');
  String get gameFamiliarPlaceInstructions => _s('gameFamiliarPlaceInstructions');
  String gameFamiliarPlaceRememberThese(int n) => _f('gameFamiliarPlaceRememberThese', <String, Object?>{'n': n});
  String get gameFamiliarPlaceIWillRemember => _s('gameFamiliarPlaceIWillRemember');
  String get gameFamiliarPlaceRememberTheseLabel => _s('gameFamiliarPlaceRememberTheseLabel');
  String gameFamiliarPlaceWalkThroughRooms(int n) => _f('gameFamiliarPlaceWalkThroughRooms', <String, Object?>{'n': n});
  String gameFamiliarPlaceFoundOfTotal(int f, int t) => _f('gameFamiliarPlaceFoundOfTotal', <String, Object?>{'f': f, 't': t});
  String get gameFamiliarPlaceNextRoom => _s('gameFamiliarPlaceNextRoom');
  String get gameFamiliarPlaceYouAreIn => _s('gameFamiliarPlaceYouAreIn');
  String gameFamiliarPlaceRoomOfTotal(int i, int t) => _f('gameFamiliarPlaceRoomOfTotal', <String, Object?>{'i': i, 't': t});
  String gameFamiliarPlaceHintsLeft(int n) => _f('gameFamiliarPlaceHintsLeft', <String, Object?>{'n': n});
  String get gameFamiliarPlaceTapLightbulb => _s('gameFamiliarPlaceTapLightbulb');
  String get gameFamiliarPlaceThingsInRoom => _s('gameFamiliarPlaceThingsInRoom');
  String get gameFamiliarPlaceTapOneIfYouThink => _s('gameFamiliarPlaceTapOneIfYouThink');


  // ── Games — story ────────────────────────────────────────────────
  String get gameStoryIntroMessage => _s('gameStoryIntroMessage');
  String get gameStoryStartButton => _s('gameStoryStartButton');
  String get gameStoryLevelSimple => _s('gameStoryLevelSimple');
  String get gameStorySubtitleStoryRecall => _s('gameStorySubtitleStoryRecall');
  String get gameStoryLevelGuided => _s('gameStoryLevelGuided');
  String get gameStoryLevelAdvanced => _s('gameStoryLevelAdvanced');
  String get gameStorySubtitleOpenStory => _s('gameStorySubtitleOpenStory');
  String get gameStoryLevelOpen => _s('gameStoryLevelOpen');
  String get gameStorySubtitleFreeMemory => _s('gameStorySubtitleFreeMemory');
  String get gameStoryLevelDeepMemory => _s('gameStoryLevelDeepMemory');
  String get gameStorySubtitleFullRecall => _s('gameStorySubtitleFullRecall');
  String get gameStoryCategoryLabel => _s('gameStoryCategoryLabel');
  String get gameStoryTitle => _s('gameStoryTitle');
  String get gameStoryInstructions => _s('gameStoryInstructions');
  String gameStoryPartOfTotal(int p, int t) => _f('gameStoryPartOfTotal', <String, Object?>{'p': p, 't': t});
  String get gameStoryThinkingAboutAnswer => _s('gameStoryThinkingAboutAnswer');
  String get gameStoryOneLastThing => _s('gameStoryOneLastThing');
  String get gameStoryNextStory => _s('gameStoryNextStory');
  String get gameStoryChooseWhatHappensNext => _s('gameStoryChooseWhatHappensNext');
  String get gameStoryDefaultPhotoTitle => _s('gameStoryDefaultPhotoTitle');
  String get gameStoryThankYouKeepSafe => _s('gameStoryThankYouKeepSafe');
  String get gameStoryLovelyStoryListening => _s('gameStoryLovelyStoryListening');
  String get gameStoryTellSmallStory => _s('gameStoryTellSmallStory');
  String get gameStoryFinish => _s('gameStoryFinish');
  String get gameStoryTapFewPartsFirst => _s('gameStoryTapFewPartsFirst');
  String get gameStoryThatIsMyStory => _s('gameStoryThatIsMyStory');
  String gameStoryFromYourMemories(String year) => _f('gameStoryFromYourMemories', <String, Object?>{'year': year});
  String get gameStoryTapWhatYouRemember => _s('gameStoryTapWhatYouRemember');
  String get gameStoryYourStory => _s('gameStoryYourStory');
  String get gameStoryMitraListening => _s('gameStoryMitraListening');
  String get gameStoryYourAnswer => _s('gameStoryYourAnswer');
  String get gameStoryHowMitraReadIt => _s('gameStoryHowMitraReadIt');
  String get gameStoryHowMitraReadYourStory => _s('gameStoryHowMitraReadYourStory');
  String get gameStoryCoherence => _s('gameStoryCoherence');
  String get gameStoryRelevantDetails => _s('gameStoryRelevantDetails');
  String get gameStoryMemoryAssociation => _s('gameStoryMemoryAssociation');
  String get gameStorySimulatedCaption => _s('gameStorySimulatedCaption');


  // ── Assessment — presenting concern ──────────────────────────────
  String get assessmentConcernMemoryProblems => _s('assessmentConcernMemoryProblems');
  String get assessmentConcernConcentration => _s('assessmentConcernConcentration');
  String get assessmentConcernAppointments => _s('assessmentConcernAppointments');
  String get assessmentConcernWordFinding => _s('assessmentConcernWordFinding');
  String get assessmentConcernConfusion => _s('assessmentConcernConfusion');
  String get assessmentConcernDailyTasks => _s('assessmentConcernDailyTasks');
  String get assessmentConcernFamilyNoticed => _s('assessmentConcernFamilyNoticed');
  String get assessmentConcernSelfMonitoring => _s('assessmentConcernSelfMonitoring');
  String get assessmentConcernDoctorRecommended => _s('assessmentConcernDoctorRecommended');

  // ── Assessment — onset window ────────────────────────────────────
  String get assessmentOnsetRecent => _s('assessmentOnsetRecent');
  String get assessmentOnset1to6Months => _s('assessmentOnset1to6Months');
  String get assessmentOnset6to12Months => _s('assessmentOnset6to12Months');
  String get assessmentOnset1to2Years => _s('assessmentOnset1to2Years');
  String get assessmentOnsetOver2Years => _s('assessmentOnsetOver2Years');
  String get assessmentOnsetUnsure => _s('assessmentOnsetUnsure');

  // ── Assessment — progression ─────────────────────────────────────
  String get assessmentProgressionNoChange => _s('assessmentProgressionNoChange');
  String get assessmentProgressionSlightlyWorse => _s('assessmentProgressionSlightlyWorse');
  String get assessmentProgressionGraduallyWorse => _s('assessmentProgressionGraduallyWorse');
  String get assessmentProgressionRapidlyWorse => _s('assessmentProgressionRapidlyWorse');
  String get assessmentProgressionFluctuating => _s('assessmentProgressionFluctuating');

  // ── Assessment — frequency ───────────────────────────────────────
  String get assessmentFrequencyNever => _s('assessmentFrequencyNever');
  String get assessmentFrequencySometimes => _s('assessmentFrequencySometimes');
  String get assessmentFrequencyOften => _s('assessmentFrequencyOften');
  String get assessmentFrequencyVeryOften => _s('assessmentFrequencyVeryOften');

  // ── Assessment — symptom domain ──────────────────────────────────
  String get assessmentDomainMemory => _s('assessmentDomainMemory');
  String get assessmentDomainAttentionThinking => _s('assessmentDomainAttentionThinking');
  String get assessmentDomainLanguage => _s('assessmentDomainLanguage');
  String get assessmentDomainBehaviour => _s('assessmentDomainBehaviour');
  String get assessmentDomainMovementPerception => _s('assessmentDomainMovementPerception');
  String get assessmentDomainPromptMemory => _s('assessmentDomainPromptMemory');
  String get assessmentDomainPromptAttentionThinking => _s('assessmentDomainPromptAttentionThinking');
  String get assessmentDomainPromptLanguage => _s('assessmentDomainPromptLanguage');
  String get assessmentDomainPromptBehaviour => _s('assessmentDomainPromptBehaviour');
  String get assessmentDomainPromptMovementPerception => _s('assessmentDomainPromptMovementPerception');

  // ── Assessment — symptom items ───────────────────────────────────
  String get assessmentSymptomMemRepeat => _s('assessmentSymptomMemRepeat');
  String get assessmentSymptomMemConv => _s('assessmentSymptomMemConv');
  String get assessmentSymptomMemAppt => _s('assessmentSymptomMemAppt');
  String get assessmentSymptomMemMisplace => _s('assessmentSymptomMemMisplace');
  String get assessmentSymptomMemNew => _s('assessmentSymptomMemNew');
  String get assessmentSymptomAttConcentrate => _s('assessmentSymptomAttConcentrate');
  String get assessmentSymptomAttFollow => _s('assessmentSymptomAttFollow');
  String get assessmentSymptomAttPlan => _s('assessmentSymptomAttPlan');
  String get assessmentSymptomAttMoney => _s('assessmentSymptomAttMoney');
  String get assessmentSymptomAttSolve => _s('assessmentSymptomAttSolve');
  String get assessmentSymptomLangWords => _s('assessmentSymptomLangWords');
  String get assessmentSymptomLangNaming => _s('assessmentSymptomLangNaming');
  String get assessmentSymptomLangUnderstand => _s('assessmentSymptomLangUnderstand');
  String get assessmentSymptomBehInterest => _s('assessmentSymptomBehInterest');
  String get assessmentSymptomBehImpulsive => _s('assessmentSymptomBehImpulsive');
  String get assessmentSymptomBehSocial => _s('assessmentSymptomBehSocial');
  String get assessmentSymptomBehEating => _s('assessmentSymptomBehEating');
  String get assessmentSymptomMovTremor => _s('assessmentSymptomMovTremor');
  String get assessmentSymptomMovStiff => _s('assessmentSymptomMovStiff');
  String get assessmentSymptomMovBalance => _s('assessmentSymptomMovBalance');
  String get assessmentSymptomMovHalluc => _s('assessmentSymptomMovHalluc');
  String get assessmentSymptomMovAlert => _s('assessmentSymptomMovAlert');
  String get assessmentSymptomMovDreams => _s('assessmentSymptomMovDreams');

  // ── Assessment — functional items ────────────────────────────────
  String get assessmentFunctionMoney => _s('assessmentFunctionMoney');
  String get assessmentFunctionMeds => _s('assessmentFunctionMeds');
  String get assessmentFunctionCooking => _s('assessmentFunctionCooking');
  String get assessmentFunctionShopping => _s('assessmentFunctionShopping');
  String get assessmentFunctionPhone => _s('assessmentFunctionPhone');
  String get assessmentFunctionTransport => _s('assessmentFunctionTransport');
  String get assessmentFunctionAppointments => _s('assessmentFunctionAppointments');
  String get assessmentFunctionBathing => _s('assessmentFunctionBathing');

  // ── Assessment — medical condition ───────────────────────────────
  String get assessmentConditionHypertension => _s('assessmentConditionHypertension');
  String get assessmentConditionDiabetes => _s('assessmentConditionDiabetes');
  String get assessmentConditionHighCholesterol => _s('assessmentConditionHighCholesterol');
  String get assessmentConditionStrokeOrTia => _s('assessmentConditionStrokeOrTia');
  String get assessmentConditionParkinsons => _s('assessmentConditionParkinsons');
  String get assessmentConditionThyroid => _s('assessmentConditionThyroid');
  String get assessmentConditionHeadInjury => _s('assessmentConditionHeadInjury');
  String get assessmentConditionOtherNeurological => _s('assessmentConditionOtherNeurological');

  // ── Assessment — sleep ───────────────────────────────────────────
  String get assessmentSleepGood => _s('assessmentSleepGood');
  String get assessmentSleepFair => _s('assessmentSleepFair');
  String get assessmentSleepPoor => _s('assessmentSleepPoor');

  // ── Assessment — completed by ────────────────────────────────────
  String get assessmentCompletedByPatient => _s('assessmentCompletedByPatient');
  String get assessmentCompletedByCaregiver => _s('assessmentCompletedByCaregiver');
  String get assessmentCompletedByFamilyMember => _s('assessmentCompletedByFamilyMember');
  String get assessmentCompletedByClinician => _s('assessmentCompletedByClinician');

  // ── Assessment — caregiver observation ───────────────────────────
  String get assessmentCaregiverObsRepeat => _s('assessmentCaregiverObsRepeat');
  String get assessmentCaregiverObsAppointments => _s('assessmentCaregiverObsAppointments');
  String get assessmentCaregiverObsBills => _s('assessmentCaregiverObsBills');
  String get assessmentCaregiverObsWords => _s('assessmentCaregiverObsWords');
  String get assessmentCaregiverObsLost => _s('assessmentCaregiverObsLost');
  String get assessmentCaregiverObsPersonality => _s('assessmentCaregiverObsPersonality');
  String get assessmentCaregiverObsHalluc => _s('assessmentCaregiverObsHalluc');
  String get assessmentCaregiverObsWithdrawn => _s('assessmentCaregiverObsWithdrawn');

  // ── Language names ─────────────────────────────────────────────────────
  String get languageEnglish => _s('languageEnglish');
  String get languageHindi => _s('languageHindi');
  String get languageAssamese => _s('languageAssamese');
  String get languageMarathi => _s('languageMarathi');

  // ── Activity domains (short, patient-facing — see cognitiveDomain* above
  // for the longer clinical wording used on the profile screen) ───────────
  String get activityDomainMemory => _s('activityDomainMemory');
  String get activityDomainAttention => _s('activityDomainAttention');
  String get activityDomainReasoning => _s('activityDomainReasoning');
  String get activityDomainSpatial => _s('activityDomainSpatial');
  String get activityDomainAuditory => _s('activityDomainAuditory');
  String get activityDomainProcedural => _s('activityDomainProcedural');

  // ── Activity content (names, taglines, level descriptions) ──────────────
  String get gameProcedureName => _s('gameProcedureName');
  String get gameProcedureTagline => _s('gameProcedureTagline');
  String get gameStoryName => _s('gameStoryName');
  String get gameStoryTagline => _s('gameStoryTagline');
  String get gameFamiliarPlaceName => _s('gameFamiliarPlaceName');
  String get gameFamiliarPlaceTagline => _s('gameFamiliarPlaceTagline');
  String get gameMelodyName => _s('gameMelodyName');
  String get gameMelodyTagline => _s('gameMelodyTagline');
  String get gameWeavesName => _s('gameWeavesName');
  String get gameWeavesTagline => _s('gameWeavesTagline');
  String get gameMemoryCardsName => _s('gameMemoryCardsName');
  String get gameMemoryCardsTagline => _s('gameMemoryCardsTagline');
  String get gameVillageMarketName => _s('gameVillageMarketName');
  String get gameVillageMarketTagline => _s('gameVillageMarketTagline');
  String gamesMinutesShort(int minutes) =>
      _f('gamesMinutesShort', <String, Object?>{'minutes': minutes});

  // ── Games — village market ──────────────────────────────────────
  String get gameVillageMarketIntroMessage => _s('gameVillageMarketIntroMessage');
  String get gameVillageMarketStartWalking => _s('gameVillageMarketStartWalking');
  String get gameVillageMarketCategoryLabel => _s('gameVillageMarketCategoryLabel');
  String get gameVillageMarketInstructions => _s('gameVillageMarketInstructions');
  String gameVillageMarketListMention(String listGiver) =>
      _f('gameVillageMarketListMention', <String, Object?>{'listGiver': listGiver});
  String gameVillageMarketListMentionWithBudget(String listGiver, int amount) => _f(
      'gameVillageMarketListMentionWithBudget',
      <String, Object?>{'listGiver': listGiver, 'amount': amount});
  String get gameVillageMarketListMentionContinue => _s('gameVillageMarketListMentionContinue');
  String get gameVillageMarketYouAreAt => _s('gameVillageMarketYouAreAt');
  String get gameVillageMarketTapAnything => _s('gameVillageMarketTapAnything');
  String gameVillageMarketPickedUp(String item) =>
      _f('gameVillageMarketPickedUp', <String, Object?>{'item': item});
  String get gameVillageMarketAlreadyHaveIt => _s('gameVillageMarketAlreadyHaveIt');
  String get gameVillageMarketInterestingOne => _s('gameVillageMarketInterestingOne');
  String gameVillageMarketNudgeAuto(String listGiver) =>
      _f('gameVillageMarketNudgeAuto', <String, Object?>{'listGiver': listGiver});
  String get gameVillageMarketNudgeCategory => _s('gameVillageMarketNudgeCategory');
  String gameVillageMarketNudgeItem(String item) =>
      _f('gameVillageMarketNudgeItem', <String, Object?>{'item': item});
  String get gameVillageMarketRainMessage => _s('gameVillageMarketRainMessage');
  String get gameVillageMarketBudgetMessage => _s('gameVillageMarketBudgetMessage');
  String get gameVillageMarketOverfullMessage => _s('gameVillageMarketOverfullMessage');
  String get gameVillageMarketHeadHome => _s('gameVillageMarketHeadHome');
  String get gameVillageMarketTripComplete => _s('gameVillageMarketTripComplete');
  String get gameVillageMarketBasketLabel => _s('gameVillageMarketBasketLabel');
  String gameVillageMarketBudgetRemaining(int amount) =>
      _f('gameVillageMarketBudgetRemaining', <String, Object?>{'amount': amount});
  String gameVillageMarketHintsLeft(int n) =>
      _f('gameVillageMarketHintsLeft', <String, Object?>{'n': n});
  String get gameVillageMarketTapLightbulb => _s('gameVillageMarketTapLightbulb');
  String get gameVillageMarketStallsVisited => _s('gameVillageMarketStallsVisited');
  String get gameVillageMarketThingsBroughtHome => _s('gameVillageMarketThingsBroughtHome');
  String get gameVillageMarketNudgesFromMitra => _s('gameVillageMarketNudgesFromMitra');
  String get gameVillageMarketTapAStall => _s('gameVillageMarketTapAStall');
  String gameVillageMarketStallsOpen(int n) =>
      _f('gameVillageMarketStallsOpen', <String, Object?>{'n': n});
  String gameVillageMarketPriceTag(int price) =>
      _f('gameVillageMarketPriceTag', <String, Object?>{'price': price});
  String get gameVillageMarketListLabel => _s('gameVillageMarketListLabel');
  String gameVillageMarketListProgress(int found, int total) => _f(
      'gameVillageMarketListProgress', <String, Object?>{'found': found, 'total': total});
  String get gameVillageMarketNotEnoughMoney => _s('gameVillageMarketNotEnoughMoney');
  String get gameVillageMarketListComplete => _s('gameVillageMarketListComplete');
  String get gameVillageMarketFundsLow => _s('gameVillageMarketFundsLow');

  // ── Games — mood canvas ─────────────────────────────────────────
  String get gameMoodCanvasName => _s('gameMoodCanvasName');
  String get gameMoodCanvasTagline => _s('gameMoodCanvasTagline');
  String get gameMoodCanvasInstructions => _s('gameMoodCanvasInstructions');
  String get gameMoodCanvasStart => _s('gameMoodCanvasStart');
  String get gameMoodCanvasDescription => _s('gameMoodCanvasDescription');
  String get gameMoodCanvasUndo => _s('gameMoodCanvasUndo');
  String get gameMoodCanvasClear => _s('gameMoodCanvasClear');
  String get gameMoodCanvasClearConfirmTitle => _s('gameMoodCanvasClearConfirmTitle');
  String get gameMoodCanvasClearConfirmBody => _s('gameMoodCanvasClearConfirmBody');
  String get gameMoodCanvasSave => _s('gameMoodCanvasSave');
  String get gameMoodCanvasSavedBody => _s('gameMoodCanvasSavedBody');
  String get gameMoodCanvasDone => _s('gameMoodCanvasDone');
  String get gameMoodCanvasCheckInTitle => _s('gameMoodCanvasCheckInTitle');
  String get gameMoodCanvasCheckInFirstQuestion => _s('gameMoodCanvasCheckInFirstQuestion');
  String get gameMoodCanvasCheckInAnswerHint => _s('gameMoodCanvasCheckInAnswerHint');
  String get gameMoodCanvasCheckInSend => _s('gameMoodCanvasCheckInSend');
  String get gameMoodCanvasTalkToMitraCta => _s('gameMoodCanvasTalkToMitraCta');
  String get gameMoodCanvasEntryTitle => _s('gameMoodCanvasEntryTitle');
  String get gameMoodCanvasEntrySubtitle => _s('gameMoodCanvasEntrySubtitle');

  String get difficultyIncreaseMessage => _s('difficultyIncreaseMessage');
  String get difficultyMaintainMessage => _s('difficultyMaintainMessage');
  String get difficultyDecreaseMessage => _s('difficultyDecreaseMessage');

  String get levelDescProcedure1 => _s('levelDescProcedure1');
  String get levelDescProcedure2 => _s('levelDescProcedure2');
  String get levelDescProcedure3 => _s('levelDescProcedure3');
  String get levelDescProcedure4 => _s('levelDescProcedure4');
  String get levelDescProcedureDefault => _s('levelDescProcedureDefault');
  String get levelDescStory1 => _s('levelDescStory1');
  String get levelDescStory2 => _s('levelDescStory2');
  String get levelDescStory3 => _s('levelDescStory3');
  String get levelDescStoryDefault => _s('levelDescStoryDefault');
  String get levelDescFamiliarPlace1 => _s('levelDescFamiliarPlace1');
  String get levelDescFamiliarPlace2 => _s('levelDescFamiliarPlace2');
  String get levelDescFamiliarPlace3 => _s('levelDescFamiliarPlace3');
  String get levelDescFamiliarPlaceDefault => _s('levelDescFamiliarPlaceDefault');
  String get levelDescMelody1 => _s('levelDescMelody1');
  String get levelDescMelody2 => _s('levelDescMelody2');
  String get levelDescMelody3 => _s('levelDescMelody3');
  String get levelDescMelody4 => _s('levelDescMelody4');
  String get levelDescMelodyDefault => _s('levelDescMelodyDefault');
  String get levelDescWeaves1 => _s('levelDescWeaves1');
  String get levelDescWeaves2 => _s('levelDescWeaves2');
  String get levelDescWeaves3 => _s('levelDescWeaves3');
  String get levelDescWeavesDefault => _s('levelDescWeavesDefault');
  String get levelDescMemoryCards1 => _s('levelDescMemoryCards1');
  String get levelDescMemoryCards2 => _s('levelDescMemoryCards2');
  String get levelDescMemoryCards3 => _s('levelDescMemoryCards3');
  String get levelDescMemoryCardsDefault => _s('levelDescMemoryCardsDefault');
  String get levelDescVillageMarket1 => _s('levelDescVillageMarket1');
  String get levelDescVillageMarket2 => _s('levelDescVillageMarket2');
  String get levelDescVillageMarket3 => _s('levelDescVillageMarket3');
  String get levelDescVillageMarket4 => _s('levelDescVillageMarket4');
  String get levelDescVillageMarketDefault => _s('levelDescVillageMarketDefault');
  String get gameMoodCanvasFreeDrawingLabel => _s('gameMoodCanvasFreeDrawingLabel');

  // ── Memory Home ───────────────────────────────────────────────────────
  String get memoryCategoryFamilyLabel => _s('memoryCategoryFamilyLabel');
  String get memoryCategoryChildhoodLabel => _s('memoryCategoryChildhoodLabel');
  String get memoryCategoryWorkLabel => _s('memoryCategoryWorkLabel');
  String get memoryCategoryFestivalsLabel => _s('memoryCategoryFestivalsLabel');
  String get memoryCategoryFoodLabel => _s('memoryCategoryFoodLabel');
  String get memoryCategoryVillageLabel => _s('memoryCategoryVillageLabel');
  String get memoryCategoryFamilyEmpty => _s('memoryCategoryFamilyEmpty');
  String get memoryCategoryChildhoodEmpty => _s('memoryCategoryChildhoodEmpty');
  String get memoryCategoryWorkEmpty => _s('memoryCategoryWorkEmpty');
  String get memoryCategoryFestivalsEmpty => _s('memoryCategoryFestivalsEmpty');
  String get memoryCategoryFoodEmpty => _s('memoryCategoryFoodEmpty');
  String get memoryCategoryVillageEmpty => _s('memoryCategoryVillageEmpty');

  // ── Health dashboard ──────────────────────────────────────────────────
  String get healthTodaysActivity => _s('healthTodaysActivity');
  String get healthAnotherActivity => _s('healthAnotherActivity');

  // ── Patient navigation ────────────────────────────────────────────────
  String get patientNavHome => _s('patientNavHome');
  String get patientNavToday => _s('patientNavToday');
  String get patientNavActivities => _s('patientNavActivities');
  String get patientNavWellness => _s('patientNavWellness');
  String get patientNavCompanion => _s('patientNavCompanion');
  String get patientNavProfile => _s('patientNavProfile');

  // ── Connectivity & Sync chip ──────────────────────────────────────────
  String get syncChipOffline => _s('syncChipOffline');
  String syncChipOfflineCount(int count) => _f('syncChipOfflineCount', <String, Object?>{'count': count});
  String get syncChipSyncing => _s('syncChipSyncing');
  String syncChipPending(int count) => _f('syncChipPending', <String, Object?>{'count': count});
  String get syncChipOnline => _s('syncChipOnline');
  String get syncChipTooltipOffline => _s('syncChipTooltipOffline');
  String get syncChipTooltipOnline => _s('syncChipTooltipOnline');

  // ── Mock reminders ───────────────────────────────────────────────────
  String get mockReminderCognitiveActivity => _s('mockReminderCognitiveActivity');
  String get mockDetailMitraReady => _s('mockDetailMitraReady');
  String get mockReminderEveningMedicine => _s('mockReminderEveningMedicine');
  String get mockDetailTwoTablets => _s('mockDetailTwoTablets');
  String get mockDetailAfternoonBihu => _s('mockDetailAfternoonBihu');

  // ── Health assistant quick actions ────────────────────────────────────
  String get actionExplainResults => _s('actionExplainResults');
  String get actionWhyChanged => _s('actionWhyChanged');
  String get actionPrepareForDoctor => _s('actionPrepareForDoctor');
  String get actionWhatToMonitor => _s('actionWhatToMonitor');
  String get actionAboutDementia => _s('actionAboutDementia');
  String get actionHowAmIDoing => _s('actionHowAmIDoing');

  // ── Caregiver safe zone card ──────────────────────────────────────────
  String get caregiverSetSafeZone => _s('caregiverSetSafeZone');
  String get caregiverSafeZoneWanderDetail => _s('caregiverSafeZoneWanderDetail');
  String caregiverSafeZoneLeft(String name, String zone) => _f('caregiverSafeZoneLeft', <String, Object?>{'name': name, 'zone': zone});
  String caregiverSafeZoneOutsideDetail(int meters) => _f('caregiverSafeZoneOutsideDetail', <String, Object?>{'meters': meters});
  String caregiverSafeZoneRadiusDetail(int meters, String zone) => _f('caregiverSafeZoneRadiusDetail', <String, Object?>{'meters': meters, 'zone': zone});
  String caregiverSafeZoneLabel(String zone) => _f('caregiverSafeZoneLabel', <String, Object?>{'zone': zone});

  // ── Family relations & notes ──────────────────────────────────────────
  String get relationDaughter => _s('relationDaughter');
  String get relationGrandson => _s('relationGrandson');
  String get relationSonInLaw => _s('relationSonInLaw');
  String get relationNeighbourFriend => _s('relationNeighbourFriend');
  String get familyNotePriya => _s('familyNotePriya');
  String get familyNoteAarav => _s('familyNoteAarav');
  String get familyNoteBhaskar => _s('familyNoteBhaskar');
  String get familyNoteNirmali => _s('familyNoteNirmali');

  // ── Clinical status, trend & alert severity ───────────────────────────
  String get clinicalTrendImproving => _s('clinicalTrendImproving');
  String get clinicalTrendStable => _s('clinicalTrendStable');
  String get clinicalTrendDeclining => _s('clinicalTrendDeclining');
  String get alertSeverityInfo => _s('alertSeverityInfo');
  String get alertSeverityWatch => _s('alertSeverityWatch');
  String get alertSeverityUrgent => _s('alertSeverityUrgent');
  String get clinicGuwahati => _s('clinicGuwahati');
  String get clinicJorhat => _s('clinicJorhat');

  // ── The person's life profile ────────────────────────────────────────
  String get lifeTitle => _s('lifeTitle');
  String get lifeSubtitle => _s('lifeSubtitle');
  String get lifePhotoLabel => _s('lifePhotoLabel');
  String get lifePhotoHint => _s('lifePhotoHint');
  String get lifeWhereLabel => _s('lifeWhereLabel');
  String get lifeWhereHint => _s('lifeWhereHint');
  String get lifeFamilyLabel => _s('lifeFamilyLabel');
  String get lifeFamilyHint => _s('lifeFamilyHint');
  String get lifeAddPerson => _s('lifeAddPerson');
  String get lifePersonName => _s('lifePersonName');
  String get lifePersonRelation => _s('lifePersonRelation');
  String get lifePersonRelationHint => _s('lifePersonRelationHint');
  String get lifeLivesWith => _s('lifeLivesWith');
  String get lifeMemoriesLabel => _s('lifeMemoriesLabel');
  String get lifeMemoriesHint => _s('lifeMemoriesHint');
  String get lifeAddMemory => _s('lifeAddMemory');
  String get lifeMemoryAnswer => _s('lifeMemoryAnswer');
  String get lifeMusicLabel => _s('lifeMusicLabel');
  String get lifeMusicHint => _s('lifeMusicHint');
  String get lifeFoodLabel => _s('lifeFoodLabel');
  String get lifeFoodHint => _s('lifeFoodHint');
  String get lifeFestivalLabel => _s('lifeFestivalLabel');
  String get lifeFestivalHint => _s('lifeFestivalHint');
  String get lifeSave => _s('lifeSave');
  String get lifeSaved => _s('lifeSaved');
  String get lifeWhyItMatters => _s('lifeWhyItMatters');
  String get lifeNothingYet => _s('lifeNothingYet');
  String get lifeOpenAction => _s('lifeOpenAction');

  // ── Pairing a patient's device ───────────────────────────────────────
  String get pairUnsupported => _s('pairUnsupported');
  String get authRequiredTitle => _s('authRequiredTitle');
  String get authRequiredBody => _s('authRequiredBody');
  String get authUnavailableHere => _s('authUnavailableHere');
  String get authPatientEntry => _s('authPatientEntry');
  String get authPatientEntryBody => _s('authPatientEntryBody');
  String get pairUsernameLabel => _s('pairUsernameLabel');
  String get pairChooseTitle => _s('pairChooseTitle');
  String get pairChooseBody => _s('pairChooseBody');
  String get pairChooseAction => _s('pairChooseAction');
  String get pairTaken => _s('pairTaken');
  String get pairUnknown => _s('pairUnknown');
  String get pairOffline => _s('pairOffline');
  String get pairSlowStart => _s('pairSlowStart');
  String get pairAskAction => _s('pairAskAction');
  String get pairWaitingTitle => _s('pairWaitingTitle');
  String get pairWaitingBody => _s('pairWaitingBody');
  String get pairDeclined => _s('pairDeclined');
  String get pairExpired => _s('pairExpired');
  String pairIncomingTitle(Object device, Object name) => _f('pairIncomingTitle', <String, Object?>{'device': device, 'name': name});
  String get pairIncomingBody => _s('pairIncomingBody');
  String get pairApprove => _s('pairApprove');
  String get pairDecline => _s('pairDecline');
  String get pairApproved => _s('pairApproved');
  String pairSignedInAsPatient(Object name) => _f('pairSignedInAsPatient', <String, Object?>{'name': name});
  String pairPatientUsernameIs(Object username) => _f('pairPatientUsernameIs', <String, Object?>{'username': username});

  // ── Authentication & role ────────────────────────────────────────────
  String get authChooseRoleFirst => _s('authChooseRoleFirst');
  String authContinueAs(Object role) => _f('authContinueAs', <String, Object?>{'role': role});
  String get authSigningIn => _s('authSigningIn');
  String get authNoAccountNeeded => _s('authNoAccountNeeded');
  String get onbCaregiverNameLabel => _s('onbCaregiverNameLabel');
  String get onbCaregiverNameHint => _s('onbCaregiverNameHint');
  String get onbCaregiverNamePrompt => _s('onbCaregiverNamePrompt');
  String caregiverViewPatientTitle(Object name) => _f('caregiverViewPatientTitle', <String, Object?>{'name': name});
  String get caregiverViewPatientBody => _s('caregiverViewPatientBody');
  String get caregiverViewPatientAction => _s('caregiverViewPatientAction');
  String get caregiverBackToCaregiver => _s('caregiverBackToCaregiver');
  String get caregiverViewingAsPatient => _s('caregiverViewingAsPatient');
  String get caregiverProfileNotSetUp => _s('caregiverProfileNotSetUp');
  String get authTitle => _s('authTitle');
  String get authSubtitle => _s('authSubtitle');
  String get authContinueWithoutAccount => _s('authContinueWithoutAccount');
  String get authDeviceOnlyNote => _s('authDeviceOnlyNote');
  String get authSignOut => _s('authSignOut');
  String authSignedInAs(Object email) => _f('authSignedInAs', <String, Object?>{'email': email});
  String get authRolePatientWho => _s('authRolePatientWho');
  String get authRolePatientDetail => _s('authRolePatientDetail');
  String get authRoleCaregiverWho => _s('authRoleCaregiverWho');
  String get authRoleCaregiverDetail => _s('authRoleCaregiverDetail');
  String get authRoleDoctorWho => _s('authRoleDoctorWho');
  String get authRoleDoctorDetail => _s('authRoleDoctorDetail');
  String get authCaregiverSetsUp => _s('authCaregiverSetsUp');
  String get authStartHere => _s('authStartHere');
  // ── Onboarding ───────────────────────────────────────────────────────
  String get onbPartKnowPerson => _s('onbPartKnowPerson');
  String get onbPartKnowLife => _s('onbPartKnowLife');
  String get onbSelectAll => _s('onbSelectAll');
  String get onbChooseUpToThree => _s('onbChooseUpToThree');
  String get onbOptional => _s('onbOptional');
  String get onbNotSure => _s('onbNotSure');
  String get onbOptionOther => _s('onbOptionOther');
  String get onbFreqOccasionally => _s('onbFreqOccasionally');
  String get onbProbeHowOften => _s('onbProbeHowOften');
  String get onbAnswered => _s('onbAnswered');
  String onbQuestionNumber(Object number) => _f('onbQuestionNumber', <String, Object?>{'number': number});
  String get onbPersonTitle => _s('onbPersonTitle');
  String get onbPersonSubtitle => _s('onbPersonSubtitle');
  String get onbEducationLabel => _s('onbEducationLabel');
  String get onbEducationWhy => _s('onbEducationWhy');
  String get onbEducationNone => _s('onbEducationNone');
  String get onbEducationPrimary => _s('onbEducationPrimary');
  String get onbEducationMiddle => _s('onbEducationMiddle');
  String get onbEducationSecondary => _s('onbEducationSecondary');
  String get onbEducationHigherSecondary => _s('onbEducationHigherSecondary');
  String get onbEducationGraduate => _s('onbEducationGraduate');
  String get onbEducationPostgraduate => _s('onbEducationPostgraduate');
  String get onbPreferNotToSay => _s('onbPreferNotToSay');
  String get onbHelperLabel => _s('onbHelperLabel');
  String get onbHelperWhy => _s('onbHelperWhy');
  String get onbHelperMyself => _s('onbHelperMyself');
  String get onbHelperSpouse => _s('onbHelperSpouse');
  String get onbHelperChild => _s('onbHelperChild');
  String get onbHelperOtherFamily => _s('onbHelperOtherFamily');
  String get onbHelperProfessional => _s('onbHelperProfessional');
  String get onbHealthTitle => _s('onbHealthTitle');
  String get onbHealthSubtitle => _s('onbHealthSubtitle');
  String get onbDiagnosisQuestion => _s('onbDiagnosisQuestion');
  String get onbConditionQuestion => _s('onbConditionQuestion');
  String get onbConditionAlzheimers => _s('onbConditionAlzheimers');
  String get onbConditionVascular => _s('onbConditionVascular');
  String get onbConditionLewy => _s('onbConditionLewy');
  String get onbConditionFrontotemporal => _s('onbConditionFrontotemporal');
  String get onbConditionMixedOther => _s('onbConditionMixedOther');
  String get onbConditionDontKnow => _s('onbConditionDontKnow');
  String get onbProfessionalsQuestion => _s('onbProfessionalsQuestion');
  String get onbProfNeurologist => _s('onbProfNeurologist');
  String get onbProfPsychiatrist => _s('onbProfPsychiatrist');
  String get onbProfPsychologist => _s('onbProfPsychologist');
  String get onbProfPhysician => _s('onbProfPhysician');
  String get onbProfOtherSpecialist => _s('onbProfOtherSpecialist');
  String get onbProfFamilyCaregiver => _s('onbProfFamilyCaregiver');
  String get onbProfNoRegular => _s('onbProfNoRegular');
  String get onbTreatmentQuestion => _s('onbTreatmentQuestion');
  String get onbMedicinesLabel => _s('onbMedicinesLabel');
  String get onbMedicinesHint => _s('onbMedicinesHint');
  String get onbSedatingQuestion => _s('onbSedatingQuestion');
  String get onbSedatingSleepAnxiety => _s('onbSedatingSleepAnxiety');
  String get onbSedatingAllergyCold => _s('onbSedatingAllergyCold');
  String get onbSedatingBladder => _s('onbSedatingBladder');
  String get onbSedatingOlderAntidepressants => _s('onbSedatingOlderAntidepressants');
  String get onbSedatingNauseaVertigo => _s('onbSedatingNauseaVertigo');
  String get onbSedatingNoneOfThese => _s('onbSedatingNoneOfThese');
  String get onbSedatingNote => _s('onbSedatingNote');
  String get onbHealthConditionsLabel => _s('onbHealthConditionsLabel');
  String get onbEverydayTitle => _s('onbEverydayTitle');
  String get onbEverydaySubtitle => _s('onbEverydaySubtitle');
  String get onbDiffRecentConversations => _s('onbDiffRecentConversations');
  String get onbDiffRepeatingQuestions => _s('onbDiffRepeatingQuestions');
  String get onbDiffAppointments => _s('onbDiffAppointments');
  String get onbDiffMisplacingThings => _s('onbDiffMisplacingThings');
  String get onbDiffTimeOrPlace => _s('onbDiffTimeOrPlace');
  String get onbDiffGettingLost => _s('onbDiffGettingLost');
  String get onbDiffFindingWords => _s('onbDiffFindingWords');
  String get onbDiffFollowingConversations => _s('onbDiffFollowingConversations');
  String get onbDiffDecisionsProblems => _s('onbDiffDecisionsProblems');
  String get onbDiffFamiliarTasks => _s('onbDiffFamiliarTasks');
  String get onbDiffManagingMedicines => _s('onbDiffManagingMedicines');
  String get onbDiffManagingMoney => _s('onbDiffManagingMoney');
  String get onbDiffMoodOrBehaviour => _s('onbDiffMoodOrBehaviour');
  String get onbDiffLostInterest => _s('onbDiffLostInterest');
  String get onbDiffSleepChanges => _s('onbDiffSleepChanges');
  String get onbDiffNothingNoticed => _s('onbDiffNothingNoticed');
  String get onbTopQuestion => _s('onbTopQuestion');
  String get onbTopHint => _s('onbTopHint');
  String onbTopChosenCount(Object count) => _f('onbTopChosenCount', <String, Object?>{'count': count});
  String get onbOnsetQuestion => _s('onbOnsetQuestion');
  String get onbCourseQuestion => _s('onbCourseQuestion');
  String get onbOnsetWhy => _s('onbOnsetWhy');
  String get onbProbesTitle => _s('onbProbesTitle');
  String get onbProbesSubtitle => _s('onbProbesSubtitle');
  String get onbProbeMemorySpan => _s('onbProbeMemorySpan');
  String get onbProbeSpanWithinMinutes => _s('onbProbeSpanWithinMinutes');
  String get onbProbeSpanLaterSameDay => _s('onbProbeSpanLaterSameDay');
  String get onbProbeSpanAfterFewDays => _s('onbProbeSpanAfterFewDays');
  String get onbProbeSpanVaries => _s('onbProbeSpanVaries');
  String get onbProbeMemoryAwareness => _s('onbProbeMemoryAwareness');
  String get onbProbeAwareOfIt => _s('onbProbeAwareOfIt');
  String get onbProbeAwarePartly => _s('onbProbeAwarePartly');
  String get onbProbeAwareNot => _s('onbProbeAwareNot');
  String get onbProbeAwareUpset => _s('onbProbeAwareUpset');
  String get onbProbeMisplaceWhat => _s('onbProbeMisplaceWhat');
  String get onbProbeItemKeys => _s('onbProbeItemKeys');
  String get onbProbeItemPhone => _s('onbProbeItemPhone');
  String get onbProbeItemWallet => _s('onbProbeItemWallet');
  String get onbProbeItemGlasses => _s('onbProbeItemGlasses');
  String get onbProbeItemMedicines => _s('onbProbeItemMedicines');
  String get onbProbeItemDocuments => _s('onbProbeItemDocuments');
  String get onbProbeMisplaceAfter => _s('onbProbeMisplaceAfter');
  String get onbProbeAfterFindsThemselves => _s('onbProbeAfterFindsThemselves');
  String get onbProbeAfterSomeoneHelps => _s('onbProbeAfterSomeoneHelps');
  String get onbProbeAfterBecomesWorried => _s('onbProbeAfterBecomesWorried');
  String get onbProbeAfterAccusesSomeone => _s('onbProbeAfterAccusesSomeone');
  String get onbProbeLostWhere => _s('onbProbeLostWhere');
  String get onbProbeLostFamiliarRoutes => _s('onbProbeLostFamiliarRoutes');
  String get onbProbeLostUnfamiliarPlaces => _s('onbProbeLostUnfamiliarPlaces');
  String get onbProbeLostNearHome => _s('onbProbeLostNearHome');
  String get onbProbeLostInsideTheHouse => _s('onbProbeLostInsideTheHouse');
  String get onbProbeLostCompany => _s('onbProbeLostCompany');
  String get onbProbeLostGoesAlone => _s('onbProbeLostGoesAlone');
  String get onbProbeLostNeedsSomeone => _s('onbProbeLostNeedsSomeone');
  String get onbProbeLostNoLongerGoesOut => _s('onbProbeLostNoLongerGoesOut');
  String get onbProbeMedsWhat => _s('onbProbeMedsWhat');
  String get onbProbeMedsForgets => _s('onbProbeMedsForgets');
  String get onbProbeMedsWrongTime => _s('onbProbeMedsWrongTime');
  String get onbProbeMedsTakesTwice => _s('onbProbeMedsTakesTwice');
  String get onbProbeMedsRefuses => _s('onbProbeMedsRefuses');
  String get onbProbeMedsSomeoneManages => _s('onbProbeMedsSomeoneManages');
  String get onbProbeMoodWhen => _s('onbProbeMoodWhen');
  String get onbProbeMoodLateAfternoon => _s('onbProbeMoodLateAfternoon');
  String get onbProbeMoodMorning => _s('onbProbeMoodMorning');
  String get onbProbeMoodTiredOrCrowded => _s('onbProbeMoodTiredOrCrowded');
  String get onbProbeMoodNoPattern => _s('onbProbeMoodNoPattern');
  String get onbProbeTasksWhich => _s('onbProbeTasksWhich');
  String get onbProbeTaskCooking => _s('onbProbeTaskCooking');
  String get onbProbeTaskAppliances => _s('onbProbeTaskAppliances');
  String get onbProbeTaskDressing => _s('onbProbeTaskDressing');
  String get onbProbeTaskPhone => _s('onbProbeTaskPhone');
  String get onbProbeTaskPersonalCare => _s('onbProbeTaskPersonalCare');
  String get onbProbeTasksStage => _s('onbProbeTasksStage');
  String get onbProbeStageCannotStart => _s('onbProbeStageCannotStart');
  String get onbProbeStageStartsThenStops => _s('onbProbeStageStartsThenStops');
  String get onbProbeStageOutOfOrder => _s('onbProbeStageOutOfOrder');
  String get onbProbeStageNeedsPrompting => _s('onbProbeStageNeedsPrompting');
  String get onbExampleTitle => _s('onbExampleTitle');
  String get onbExampleSubtitle => _s('onbExampleSubtitle');
  String get onbExampleLabel => _s('onbExampleLabel');
  String get onbExampleHint => _s('onbExampleHint');
  String get onbExampleWhy => _s('onbExampleWhy');
  String get onbExampleSkip => _s('onbExampleSkip');
  String get onbIndependenceTitle => _s('onbIndependenceTitle');
  String get onbIndependenceSubtitle => _s('onbIndependenceSubtitle');
  String get onbActivityEating => _s('onbActivityEating');
  String get onbActivityDressing => _s('onbActivityDressing');
  String get onbActivityBathing => _s('onbActivityBathing');
  String get onbActivityToilet => _s('onbActivityToilet');
  String get onbActivityMedicines => _s('onbActivityMedicines');
  String get onbActivityHousehold => _s('onbActivityHousehold');
  String get onbActivityMoney => _s('onbActivityMoney');
  String get onbActivityGoingOut => _s('onbActivityGoingOut');
  String get onbSupportIndependent => _s('onbSupportIndependent');
  String get onbSupportNeedsReminders => _s('onbSupportNeedsReminders');
  String get onbSupportNeedsSomeHelp => _s('onbSupportNeedsSomeHelp');
  String get onbSupportNeedsFullHelp => _s('onbSupportNeedsFullHelp');
  String get onbSupportRemindersNote => _s('onbSupportRemindersNote');
  String onbIndependenceProgress(Object done, Object total) => _f('onbIndependenceProgress', <String, Object?>{'done': done, 'total': total});
  String get onbBehaviourTitle => _s('onbBehaviourTitle');
  String get onbBehaviourSubtitle => _s('onbBehaviourSubtitle');
  String get onbBehaviourMoreIrritable => _s('onbBehaviourMoreIrritable');
  String get onbBehaviourMoreWithdrawn => _s('onbBehaviourMoreWithdrawn');
  String get onbBehaviourLessInterested => _s('onbBehaviourLessInterested');
  String get onbBehaviourRestlessAgitated => _s('onbBehaviourRestlessAgitated');
  String get onbBehaviourSuspicious => _s('onbBehaviourSuspicious');
  String get onbBehaviourRepetitive => _s('onbBehaviourRepetitive');
  String get onbBehaviourSleepChanges => _s('onbBehaviourSleepChanges');
  String get onbBehaviourEatingChanges => _s('onbBehaviourEatingChanges');
  String get onbBehaviourSeeingOrHearingThings => _s('onbBehaviourSeeingOrHearingThings');
  String get onbBehaviourNoMajorChanges => _s('onbBehaviourNoMajorChanges');
  String get onbLewyPerceptualNote => _s('onbLewyPerceptualNote');
  String get onbSafetyTitle => _s('onbSafetyTitle');
  String get onbSafetySubtitle => _s('onbSafetySubtitle');
  String get onbSafetyGettingLostOutside => _s('onbSafetyGettingLostOutside');
  String get onbSafetyLeavingHome => _s('onbSafetyLeavingHome');
  String get onbSafetyFallsOrBalance => _s('onbSafetyFallsOrBalance');
  String get onbSafetyForgettingMedicines => _s('onbSafetyForgettingMedicines');
  String get onbSafetyStoveOrAppliances => _s('onbSafetyStoveOrAppliances');
  String get onbSafetyHandlingMoney => _s('onbSafetyHandlingMoney');
  String get onbSafetyTravellingAlone => _s('onbSafetyTravellingAlone');
  String get onbSafetyNoMajorConcerns => _s('onbSafetyNoMajorConcerns');
  String get onbWanderingQuestion => _s('onbWanderingQuestion');
  String get onbWanderingNever => _s('onbWanderingNever');
  String get onbWanderingOnce => _s('onbWanderingOnce');
  String get onbWanderingMoreThanOnce => _s('onbWanderingMoreThanOnce');
  String get onbWanderingRegularly => _s('onbWanderingRegularly');
  String get onbSafetyLocationNote => _s('onbSafetyLocationNote');
  String get onbStrengthsTitle => _s('onbStrengthsTitle');
  String get onbStrengthsSubtitle => _s('onbStrengthsSubtitle');
  String get onbEnjoyMusic => _s('onbEnjoyMusic');
  String get onbEnjoyTalkingWithFamily => _s('onbEnjoyTalkingWithFamily');
  String get onbEnjoyWalking => _s('onbEnjoyWalking');
  String get onbEnjoyCooking => _s('onbEnjoyCooking');
  String get onbEnjoyGardening => _s('onbEnjoyGardening');
  String get onbEnjoyReligious => _s('onbEnjoyReligious');
  String get onbEnjoyTelevision => _s('onbEnjoyTelevision');
  String get onbEnjoyReading => _s('onbEnjoyReading');
  String get onbEnjoyPuzzles => _s('onbEnjoyPuzzles');
  String get onbEnjoyMeetingFriends => _s('onbEnjoyMeetingFriends');
  String get onbEnjoyHouseholdWork => _s('onbEnjoyHouseholdWork');
  String get onbStillDoesWellLabel => _s('onbStillDoesWellLabel');
  String get onbStillDoesWellHint => _s('onbStillDoesWellHint');
  String get onbStrengthsWhy => _s('onbStrengthsWhy');
  String get onbGoalsTitle => _s('onbGoalsTitle');
  String get onbGoalsSubtitle => _s('onbGoalsSubtitle');
  String get onbGoalRememberingThings => _s('onbGoalRememberingThings');
  String get onbGoalDailyRoutines => _s('onbGoalDailyRoutines');
  String get onbGoalStayingMentallyActive => _s('onbGoalStayingMentallyActive');
  String get onbGoalEverydayDifficulties => _s('onbGoalEverydayDifficulties');
  String get onbGoalConfidenceIndependence => _s('onbGoalConfidenceIndependence');
  String get onbGoalCaregiverUnderstanding => _s('onbGoalCaregiverUnderstanding');
  String get onbGoalTrackingProgress => _s('onbGoalTrackingProgress');
  String get onbGoalSharingWithDoctor => _s('onbGoalSharingWithDoctor');
  String get onbGoalSafety => _s('onbGoalSafety');
  String get onbAnythingElseLabel => _s('onbAnythingElseLabel');
  String get onbAnythingElseHint => _s('onbAnythingElseHint');
  String get onbSummaryTitle => _s('onbSummaryTitle');
  String get onbSummarySubtitle => _s('onbSummarySubtitle');
  String get onbSummaryHeardTitle => _s('onbSummaryHeardTitle');
  String get onbSummaryFocusTitle => _s('onbSummaryFocusTitle');
  String get onbSummaryStrengthsTitle => _s('onbSummaryStrengthsTitle');
  String get onbSummaryNoDifficulty => _s('onbSummaryNoDifficulty');
  String get onbSummaryNoStrengths => _s('onbSummaryNoStrengths');
  String get onbSummaryNextTitle => _s('onbSummaryNextTitle');
  String get onbSummaryNextBody => _s('onbSummaryNextBody');
  String get onbSummaryAnswersSafe => _s('onbSummaryAnswersSafe');
  String get onbSummaryFinish => _s('onbSummaryFinish');
  String onbSummaryAnsweredBy(Object relation) => _f('onbSummaryAnsweredBy', <String, Object?>{'relation': relation});
  String get onbSummaryHelpWith => _s('onbSummaryHelpWith');
  // ── Profile — connectivity / phone (added during a cleanliness pass) ────
  String profileActivitiesSavedOnDevice(int count) =>
      _f('profileActivitiesSavedOnDevice', <String, Object?>{'count': count});
  String get profileSyncing => _s('profileSyncing');
  String profileSyncActivities(int count) =>
      _f('profileSyncActivities', <String, Object?>{'count': count});
  String get profileChangeNumber => _s('profileChangeNumber');
  String get profileAddNumber => _s('profileAddNumber');
  String get dashboardStartTodaysSession => _s('dashboardStartTodaysSession');

  // ── Clinical status / reminder kind / life-memory category labels ───────
  String get reminderKindMedicine => _s('reminderKindMedicine');
  String get reminderKindHydration => _s('reminderKindHydration');
  String get reminderKindCognitive => _s('reminderKindCognitive');
  String get reminderKindAppointment => _s('reminderKindAppointment');
  String get reminderKindRoutine => _s('reminderKindRoutine');
  String get reminderKindSocial => _s('reminderKindSocial');
  String get lifeMemoryCategoryWork => _s('lifeMemoryCategoryWork');
  String get lifeMemoryCategoryActivities => _s('lifeMemoryCategoryActivities');
  String get lifeMemoryCategoryPlaces => _s('lifeMemoryCategoryPlaces');
  String get lifeMemoryCategoryStories => _s('lifeMemoryCategoryStories');
  String get lifeMemoryCategoryFood => _s('lifeMemoryCategoryFood');
  String get lifeMemoryCategoryTraditions => _s('lifeMemoryCategoryTraditions');
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
