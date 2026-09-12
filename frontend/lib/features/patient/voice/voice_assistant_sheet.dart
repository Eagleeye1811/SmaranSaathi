import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/voice/voice_assistant_controller.dart';
import '../../../core/voice/voice_language.dart';
import '../../../core/voice/voice_models.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../../../l10n/locale_controller.dart';
import '../settings/language_picker_button.dart';

/// "Ask Mitra" — the voice conversation, as a sheet over the patient app.
///
/// Built entirely from the existing design vocabulary: the same [Companion]
/// the home screen uses (it already had `listening` and `thinking` states),
/// the same [CompanionSpeech] bubble, the same [BigButton]. Nothing here is a
/// new visual language; voice simply gives Mitra a new way to be asked.
///
/// One thing on screen at a time, one obvious control, and never a spinner
/// without words — the audience is someone who becomes anxious when a device
/// does something unexplained.
class VoiceAssistantSheet extends StatefulWidget {
  const VoiceAssistantSheet({super.key, required this.controller});

  final VoiceAssistantController controller;

  /// Opens the sheet. Cancels any in-flight turn on the way out, so closing it
  /// always silences the microphone and the speaker.
  static Future<void> show(
    BuildContext context,
    VoiceAssistantController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.ink.withValues(alpha: 0.45),
      builder: (BuildContext context) => VoiceAssistantSheet(controller: controller),
    );
    await controller.cancel();
  }

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> {
  @override
  void initState() {
    super.initState();
    // Resolve engines and languages up front so the first tap is instant and
    // an unsupported language is known before the patient tries to speak.
    widget.controller.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LocaleController? locale = LocaleScope.maybeOf(context);
    if (locale != null && widget.controller.language != locale.voiceLanguage) {
      widget.controller.setLanguage(locale.voiceLanguage);
    }
  }

  VoiceAssistantController get _c => widget.controller;

  CompanionState get _companionState => switch (_c.phase) {
        VoicePhase.listening => CompanionState.listening,
        VoicePhase.thinking => CompanionState.thinking,
        VoicePhase.speaking => CompanionState.happy,
        VoicePhase.error => CompanionState.gentle,
        _ => CompanionState.idle,
      };

  String _statusLine(AppLocalizations l) => switch (_c.phase) {
        VoicePhase.idle =>
          _c.reply == null ? l.voiceTapMicrophone : l.voiceAskAnythingElse,
        VoicePhase.requestingPermission => l.voiceOneMoment,
        VoicePhase.listening => l.voiceListening,
        VoicePhase.thinking => l.voiceThinking,
        VoicePhase.speaking => l.voiceSpeaking,
        VoicePhase.error => l.voiceTryAgain,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.xl)),
          ),
          padding: EdgeInsets.only(
            left: Insets.gutter,
            right: Insets.gutter,
            top: Insets.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + Insets.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _grabHandle(),
                const SizedBox(height: Insets.lg),
                _header(AppLocalizations.of(context)),
                const SizedBox(height: Insets.lg),
                if (_c.resolvedInputLanguage?.isFallback ?? false) ...<Widget>[
                  _languageNotice(),
                  const SizedBox(height: Insets.md),
                ],
                if (_c.resolvedOutputLanguage != null && !_c.resolvedOutputLanguage!.isSupported) ...<Widget>[
                  _ttsUnavailableNotice(AppLocalizations.of(context)),
                  const SizedBox(height: Insets.md),
                ],
                if (_c.resolvedInputLanguage != null && !_c.resolvedInputLanguage!.isSupported) ...<Widget>[
                  _sttUnavailableNotice(AppLocalizations.of(context)),
                  const SizedBox(height: Insets.md),
                ],
                if (_c.recognizedText.isNotEmpty) ...<Widget>[
                  _heardCard(),
                  const SizedBox(height: Insets.md),
                ],
                if (_c.reply != null) ...<Widget>[
                  CompanionSpeech(
                    message: _c.reply!.text,
                    state: _c.isSpeaking ? CompanionState.happy : CompanionState.gentle,
                    companionSize: 64,
                  ),
                  const SizedBox(height: Insets.md),
                  if (_c.reply!.followUps.isNotEmpty) _followUps(),
                ],
                if (_c.error != null) ...<Widget>[
                  _errorCard(),
                  const SizedBox(height: Insets.md),
                ],
                const SizedBox(height: Insets.sm),
                _primaryControl(),
                const SizedBox(height: Insets.sm),
                _secondaryControls(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _grabHandle() => Center(
        child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.hairline,
            borderRadius: Corners.r(Corners.pill),
          ),
        ),
      );

  Widget _header(AppLocalizations l) => Row(
        children: <Widget>[
          Companion(state: _companionState, size: 76),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.voiceAskMitra, style: AppText.h2),
                const SizedBox(height: 2),
                Text(
                  _statusLine(l),
                  style: AppText.body.tint(
                    _c.isListening ? AppColors.plum : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (_c.isListening) const _ListeningPulse(),
          const SizedBox(width: Insets.xs),
          const LanguagePickerButton(),
        ],
      );

  /// Says plainly when the device could not manage the patient's own language,
  /// rather than silently answering in another one.
  Widget _languageNotice() {
    final AppLocalizations l = AppLocalizations.of(context);
    final ResolvedVoiceLanguage r = _c.resolvedInputLanguage!;
    return MmCard(
      color: AppColors.warningTint,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          const SoftIcon(icon: Icons.translate_rounded, color: AppColors.warning),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              l.voiceLanguageFallback(
                _languageName(l, r.requested),
                _languageName(l, r.resolved!),
              ),
              style: AppText.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ttsUnavailableNotice(AppLocalizations l) {
    return MmCard(
      color: AppColors.secondaryTint,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          const SoftIcon(icon: Icons.volume_off_rounded, color: AppColors.secondary),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              l.voiceErrorTtsUnavailable,
              style: AppText.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sttUnavailableNotice(AppLocalizations l) {
    return MmCard(
      color: AppColors.warningTint,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          const SoftIcon(icon: Icons.mic_off_rounded, color: AppColors.warning),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              l.voiceErrorLanguage,
              style: AppText.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// The patient's own words, shown as they arrive. Important reassurance:
  /// you can see the device heard you before it answers.
  Widget _heardCard() => MmCard(
        color: AppColors.plumTint,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SoftIcon(icon: Icons.graphic_eq_rounded, color: AppColors.plum),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                '"${_c.recognizedText}"',
                style: AppText.patientBody.tint(AppColors.ink),
              ),
            ),
          ],
        ),
      );

  Widget _followUps() => Wrap(
        spacing: Insets.sm,
        runSpacing: Insets.sm,
        children: <Widget>[
          for (final String q in _c.reply!.followUps)
            SoftButton(
              label: q,
              color: AppColors.secondary,
              onPressed: _c.isBusy ? null : () => _c.askDirectly(q),
            ),
        ],
      );

  Widget _errorCard() {
    final VoiceError error = _c.error!;
    // A speech-only problem is a notice, not a failure: the answer is already
    // on screen and can simply be read.
    final bool soft = error.kind.isSpeechOnly;
    return MmCard(
      color: soft ? AppColors.secondaryTint : AppColors.dangerTint,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SoftIcon(
            icon: soft ? Icons.volume_off_rounded : Icons.info_outline_rounded,
            color: soft ? AppColors.secondary : AppColors.danger,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
              child: Text(error.localizedMessage(AppLocalizations.of(context)),
                  style: AppText.body)),
        ],
      ),
    );
  }

  /// One big control whose meaning is always the current phase's opposite:
  /// listening → stop, speaking → stop, otherwise → talk.
  /// A language's own name, in the interface language.
  String _languageName(AppLocalizations l, VoiceLanguage v) => switch (v) {
        VoiceLanguage.english => l.languageEnglish,
        VoiceLanguage.hindi => l.languageHindi,
        VoiceLanguage.assamese => l.languageAssamese,
      };

  Widget _primaryControl() {
    final AppLocalizations l = AppLocalizations.of(context);
    if (_c.isListening) {
      return BigButton(
        label: l.voiceIHaveFinished,
        icon: Icons.check_rounded,
        color: AppColors.plum,
        onPressed: _c.stopListening,
      );
    }
    if (_c.isSpeaking) {
      return BigButton(
        label: l.voiceStop,
        icon: Icons.stop_rounded,
        color: AppColors.terracotta,
        onPressed: _c.stopSpeaking,
      );
    }
    if (_c.isThinking) {
      return BigButton(
        label: l.voiceThinkingButton,
        icon: Icons.more_horiz_rounded,
        color: AppColors.secondary,
        onPressed: null,
      );
    }
    if (!_c.canListen) {
      // No microphone on this device — say so once, and keep the sheet useful
      // by leaving the suggested questions tappable.
      return BigButton(
        label: l.voiceUnavailable,
        icon: Icons.mic_off_rounded,
        color: AppColors.inkMuted,
        onPressed: null,
      );
    }
    final bool blocked = _c.error != null && !_c.error!.isRetryable;
    return BigButton(
      label: _c.reply == null ? l.voiceTalkToMitra : l.voiceAskSomethingElse,
      icon: Icons.mic_rounded,
      color: AppColors.primary,
      onPressed: blocked ? null : _c.startListening,
    );
  }

  Widget _secondaryControls() {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<Widget> actions = <Widget>[
      if (_c.reply != null && !_c.isBusy && _c.canSpeak)
        SoftButton(
          label: l.voiceSayItAgain,
          icon: Icons.replay_rounded,
          onPressed: _c.replay,
        ),
      if (_c.phase.isCancellable)
        SoftButton(
          label: l.actionCancel,
          icon: Icons.close_rounded,
          color: AppColors.inkSoft,
          onPressed: _c.cancel,
        ),
      if (!_c.isBusy)
        SoftButton(
          label: l.actionClose,
          icon: Icons.keyboard_arrow_down_rounded,
          color: AppColors.inkSoft,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: actions,
    );
  }
}

/// A soft pulse while the microphone is open, so it is obvious the device is
/// hearing something — the audio equivalent of a cursor.
class _ListeningPulse extends StatefulWidget {
  const _ListeningPulse();

  @override
  State<_ListeningPulse> createState() => _ListeningPulseState();
}

class _ListeningPulseState extends State<_ListeningPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(color: AppColors.plum, shape: BoxShape.circle),
      ),
    );
  }
}
