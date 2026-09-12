import '../core/ai/health_assistant.dart';
import '../core/models/clinical.dart';
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

extension HealthQuickActionLabel on HealthQuickAction {
  String localizedLabel(AppLocalizations l) => switch (this) {
        HealthQuickAction.explainResults => l.actionExplainResults,
        HealthQuickAction.whyChanged => l.actionWhyChanged,
        HealthQuickAction.prepareForDoctor => l.actionPrepareForDoctor,
        HealthQuickAction.whatToMonitor => l.actionWhatToMonitor,
        HealthQuickAction.aboutDementia => l.actionAboutDementia,
        HealthQuickAction.howAmIDoing => l.actionHowAmIDoing,
      };
}

extension ClinicalStatusLabel on ClinicalStatus {
  String localizedLabel(AppLocalizations l) => switch (this) {
        ClinicalStatus.stable => l.clinicalStatusStable,
        ClinicalStatus.needsAttention => l.clinicalStatusNeedsAttention,
        ClinicalStatus.followUp => l.clinicalStatusFollowUp,
      };
}

extension TrendDirectionLabel on TrendDirection {
  String localizedLabel(AppLocalizations l) => switch (this) {
        TrendDirection.up => l.clinicalTrendImproving,
        TrendDirection.flat => l.clinicalTrendStable,
        TrendDirection.down => l.clinicalTrendDeclining,
      };
}

extension AlertSeverityLabel on AlertSeverity {
  String localizedLabel(AppLocalizations l) => switch (this) {
        AlertSeverity.info => l.alertSeverityInfo,
        AlertSeverity.watch => l.alertSeverityWatch,
        AlertSeverity.urgent => l.alertSeverityUrgent,
      };
}
