import '../core/models/clinical.dart';
import '../core/models/daily.dart';
import '../core/models/game.dart';
import '../core/models/memory_fragment.dart';
import '../core/models/settings.dart';
import '../core/voice/voice_models.dart';
import 'app_localizations.dart';

/// Locale-aware text for domain objects whose English wording used to be
/// baked into `core/` as plain fields or `switch` getters.
///
/// Kept out of `core/` on purpose: those layers stay presentation-agnostic,
/// and every screen that shows one of these objects reaches for the same
/// mapping here instead of re-deriving it — the old bug this file fixes was
/// a language switch that left the shell translated but the content (game
/// names, level descriptions, category labels...) frozen in English.
extension CognitiveDomainLabel on CognitiveDomain {
  String localizedLabel(AppLocalizations l) => switch (this) {
        CognitiveDomain.memory => l.activityDomainMemory,
        CognitiveDomain.attention => l.activityDomainAttention,
        CognitiveDomain.reasoning => l.activityDomainReasoning,
        CognitiveDomain.spatial => l.activityDomainSpatial,
        CognitiveDomain.auditory => l.activityDomainAuditory,
        CognitiveDomain.procedural => l.activityDomainProcedural,
      };
}

extension GameDefinitionLabel on GameDefinition {
  String localizedName(AppLocalizations l) => switch (id) {
        GameId.procedure => l.gameProcedureName,
        GameId.story => l.gameStoryName,
        GameId.familiarPlace => l.gameFamiliarPlaceName,
        GameId.melody => l.gameMelodyName,
        GameId.weaves => l.gameWeavesName,
        GameId.memoryCards => l.gameMemoryCardsName,
      };

  String localizedTagline(AppLocalizations l) => switch (id) {
        GameId.procedure => l.gameProcedureTagline,
        GameId.story => l.gameStoryTagline,
        GameId.familiarPlace => l.gameFamiliarPlaceTagline,
        GameId.melody => l.gameMelodyTagline,
        GameId.weaves => l.gameWeavesTagline,
        GameId.memoryCards => l.gameMemoryCardsTagline,
      };
}

extension DifficultyDirectionLabel on DifficultyDirection {
  String localizedMessage(AppLocalizations l) => switch (this) {
        DifficultyDirection.increase => l.difficultyIncreaseMessage,
        DifficultyDirection.maintain => l.difficultyMaintainMessage,
        DifficultyDirection.decrease => l.difficultyDecreaseMessage,
      };
}

/// Mirrors `AdaptiveDifficultyService.levelDescription` — same branching,
/// localized wording. Kept in sync by hand since the English original lives
/// in `core/services` and stays free of the `l10n` import.
String localizedLevelDescription(AppLocalizations l, GameId id, int level) {
  switch (id) {
    case GameId.procedure:
      return switch (level) {
        1 => l.levelDescProcedure1,
        2 => l.levelDescProcedure2,
        3 => l.levelDescProcedure3,
        4 => l.levelDescProcedure4,
        _ => l.levelDescProcedureDefault,
      };
    case GameId.story:
      return switch (level) {
        1 => l.levelDescStory1,
        2 => l.levelDescStory2,
        3 => l.levelDescStory3,
        _ => l.levelDescStoryDefault,
      };
    case GameId.familiarPlace:
      return switch (level) {
        1 => l.levelDescFamiliarPlace1,
        2 => l.levelDescFamiliarPlace2,
        3 => l.levelDescFamiliarPlace3,
        _ => l.levelDescFamiliarPlaceDefault,
      };
    case GameId.melody:
      return switch (level) {
        1 => l.levelDescMelody1,
        2 => l.levelDescMelody2,
        3 => l.levelDescMelody3,
        4 => l.levelDescMelody4,
        _ => l.levelDescMelodyDefault,
      };
    case GameId.weaves:
      return switch (level) {
        1 => l.levelDescWeaves1,
        2 => l.levelDescWeaves2,
        3 => l.levelDescWeaves3,
        _ => l.levelDescWeavesDefault,
      };
    case GameId.memoryCards:
      return switch (level) {
        1 => l.levelDescMemoryCards1,
        2 => l.levelDescMemoryCards2,
        3 => l.levelDescMemoryCards3,
        _ => l.levelDescMemoryCardsDefault,
      };
  }
}

extension MemoryCategoryLabel on MemoryCategory {
  String localizedLabel(AppLocalizations l) => switch (this) {
        MemoryCategory.family => l.memoryCategoryFamilyLabel,
        MemoryCategory.childhood => l.memoryCategoryChildhoodLabel,
        MemoryCategory.work => l.memoryCategoryWorkLabel,
        MemoryCategory.festivals => l.memoryCategoryFestivalsLabel,
        MemoryCategory.food => l.memoryCategoryFoodLabel,
        MemoryCategory.village => l.memoryCategoryVillageLabel,
      };

  String localizedEmptyRoomLabel(AppLocalizations l) => switch (this) {
        MemoryCategory.family => l.memoryCategoryFamilyEmpty,
        MemoryCategory.childhood => l.memoryCategoryChildhoodEmpty,
        MemoryCategory.work => l.memoryCategoryWorkEmpty,
        MemoryCategory.festivals => l.memoryCategoryFestivalsEmpty,
        MemoryCategory.food => l.memoryCategoryFoodEmpty,
        MemoryCategory.village => l.memoryCategoryVillageEmpty,
      };
}

extension TextSizePreferenceLabel on TextSizePreference {
  String localizedLabel(AppLocalizations l) => switch (this) {
        TextSizePreference.normal => l.settingsTextNormal,
        TextSizePreference.large => l.settingsTextLarge,
        TextSizePreference.extraLarge => l.settingsTextExtraLarge,
      };
}

extension VoiceErrorKindLabel on VoiceErrorKind {
  String localizedMessage(AppLocalizations l) => switch (this) {
        VoiceErrorKind.permissionDenied => l.voiceErrorPermissionDenied,
        VoiceErrorKind.permissionPermanentlyDenied => l.voiceErrorPermissionBlocked,
        VoiceErrorKind.speechUnavailable => l.voiceErrorUnavailable,
        VoiceErrorKind.noSpeechDetected => l.voiceErrorNoSpeech,
        VoiceErrorKind.languageUnsupported => l.voiceErrorLanguage,
        VoiceErrorKind.recognitionFailed => l.voiceErrorRecognition,
        VoiceErrorKind.ttsUnavailable => l.voiceErrorTtsUnavailable,
        VoiceErrorKind.ttsFailed => l.voiceErrorTtsFailed,
        VoiceErrorKind.assistantFailed => l.voiceErrorAssistant,
        VoiceErrorKind.unknown => l.voiceErrorUnknown,
      };
}

extension VoiceErrorLabel on VoiceError {
  String localizedMessage(AppLocalizations l) => kind.localizedMessage(l);
}

/// Reuses the same short wording already shown on the doctor alerts KPI
/// card, so a severity reads the same way everywhere it appears instead of
/// the KPI card and the section header underneath it disagreeing.
extension AlertSeverityLabel on AlertSeverity {
  String localizedLabel(AppLocalizations l) => switch (this) {
        AlertSeverity.info => l.doctorAlertsSeverityInformational,
        AlertSeverity.watch => l.doctorAlertsSeverityAttention,
        AlertSeverity.urgent => l.doctorAlertsSeverityAssessment,
      };
}

extension ClinicalStatusLabel on ClinicalStatus {
  String localizedLabel(AppLocalizations l) => switch (this) {
        ClinicalStatus.stable => l.clinicalStatusStable,
        ClinicalStatus.needsAttention => l.clinicalStatusNeedsAttention,
        ClinicalStatus.followUp => l.clinicalStatusFollowUp,
      };
}

/// Reuses the wording already translated for the patients-list trend
/// legend, so "Improving/Stable/Declining" reads identically wherever a
/// trend is shown.
extension TrendDirectionLabel on TrendDirection {
  String localizedLabel(AppLocalizations l) => switch (this) {
        TrendDirection.up => l.doctorPatientsLegendImproving,
        TrendDirection.flat => l.doctorPatientsLegendStable,
        TrendDirection.down => l.doctorPatientsLegendDeclining,
      };
}

extension ReminderKindLabel on ReminderKind {
  String localizedLabel(AppLocalizations l) => switch (this) {
        ReminderKind.medicine => l.reminderKindMedicine,
        ReminderKind.hydration => l.reminderKindHydration,
        ReminderKind.cognitive => l.reminderKindCognitive,
        ReminderKind.appointment => l.reminderKindAppointment,
        ReminderKind.routine => l.reminderKindRoutine,
        ReminderKind.social => l.reminderKindSocial,
      };
}

/// The abbreviated month name for [month] (1 = January), reusing the
/// `caregiverMonth*` ARB set — previously hand-copied as a 12-entry list in
/// three separate screens.
String monthShortLabel(AppLocalizations l, int month) => switch (month) {
      1 => l.caregiverMonthJan,
      2 => l.caregiverMonthFeb,
      3 => l.caregiverMonthMar,
      4 => l.caregiverMonthApr,
      5 => l.caregiverMonthMay,
      6 => l.caregiverMonthJun,
      7 => l.caregiverMonthJul,
      8 => l.caregiverMonthAug,
      9 => l.caregiverMonthSep,
      10 => l.caregiverMonthOct,
      11 => l.caregiverMonthNov,
      12 => l.caregiverMonthDec,
      _ => throw ArgumentError.value(month, 'month', 'must be 1-12'),
    };

/// "5 Jan" — day + abbreviated month. Shared by Memory Home and Memory
/// Wallet, which both date-stamp the same [MemoryFragment] data.
String shortDayMonth(AppLocalizations l, DateTime d) =>
    '${d.day} ${monthShortLabel(l, d.month)}';

/// Short chart-axis label for an activity, on the doctor's screens
/// (patient detail's activity breakdown, analytics' engagement-by-activity
/// chart) — both charted the same six activities and used to each carry
/// their own identical copy of this mapping.
String doctorChartLabel(AppLocalizations l, GameId id) => switch (id) {
      GameId.procedure => l.doctorDetailChartProcedure,
      GameId.story => l.doctorDetailChartStory,
      GameId.familiarPlace => l.doctorDetailChartPlace,
      GameId.melody => l.doctorDetailChartMelody,
      GameId.weaves => l.doctorDetailChartWeaves,
      GameId.memoryCards => l.doctorDetailChartCards,
    };

/// The full month name for [month] (1 = January), reusing the
/// `todayMonth*` ARB set. `today_screen.dart` keeps its own copy for now
/// (queued for a separate design-kit pass) rather than being switched over
/// here.
String monthFullLabel(AppLocalizations l, int month) => switch (month) {
      1 => l.todayMonthJanuary,
      2 => l.todayMonthFebruary,
      3 => l.todayMonthMarch,
      4 => l.todayMonthApril,
      5 => l.todayMonthMay,
      6 => l.todayMonthJune,
      7 => l.todayMonthJuly,
      8 => l.todayMonthAugust,
      9 => l.todayMonthSeptember,
      10 => l.todayMonthOctober,
      11 => l.todayMonthNovember,
      12 => l.todayMonthDecember,
      _ => throw ArgumentError.value(month, 'month', 'must be 1-12'),
    };

/// [LifeMemory.category] is free text seeded from a fixed onboarding
/// catalogue (`MockData.memories`), not an enum — so this matches the known
/// values and falls back to the raw string for anything unexpected, rather
/// than risk hiding a caregiver's own words.
String localizedLifeMemoryCategory(AppLocalizations l, String category) {
  switch (category.toLowerCase()) {
    case 'work':
      return l.lifeMemoryCategoryWork;
    case 'activities':
      return l.lifeMemoryCategoryActivities;
    case 'places':
      return l.lifeMemoryCategoryPlaces;
    case 'stories':
      return l.lifeMemoryCategoryStories;
    case 'food':
      return l.lifeMemoryCategoryFood;
    case 'traditions':
      return l.lifeMemoryCategoryTraditions;
    default:
      return category;
  }
}
