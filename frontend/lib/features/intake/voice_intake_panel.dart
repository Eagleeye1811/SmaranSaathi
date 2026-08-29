import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../core/voice/voice_models.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/content_labels.dart';

/// The voice layer over one intake screen.
///
/// Wraps a step's questions so they can be answered out loud: the question is
/// read aloud with its options numbered, the answer is spoken back, and "next"
/// moves on — to the following question, and off the screen when that was the
/// last one. Everything stays tappable throughout; this adds a way in, it does
/// not take one away.
///
/// Renders nothing at all on a device with no speech engine, rather than
/// offering a microphone that cannot work.
class VoiceIntakePanel extends StatefulWidget {
  const VoiceIntakePanel({
    super.key,
    required this.controller,
    required this.questions,
    this.screenKey,
  });

  final VoiceIntakeController controller;

  /// The questions on this screen, in the order they should be asked.
  final List<VoiceIntakeQuestion> questions;

  /// Changes when the screen moves to a different set of questions — a new
  /// symptom group, say — so the flow restarts at the top rather than
  /// carrying an index over to a different list.
  final Object? screenKey;

  @override
  State<VoiceIntakePanel> createState() => _VoiceIntakePanelState();
}

class _VoiceIntakePanelState extends State<VoiceIntakePanel> {
  Object? _lastScreenKey;

  @override
  void initState() {
    super.initState();
    _lastScreenKey = widget.screenKey;
    widget.controller.setQuestions(widget.questions);
    // Ask the device what it can do as soon as a screen wants voice. Waiting
    // until the person taps the card meant the card was never shown: nothing
    // had initialised the engine, so it reported itself unavailable.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.controller.initialize());
  }

  @override
  void didUpdateWidget(VoiceIntakePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool changedScreen = widget.screenKey != _lastScreenKey;
    _lastScreenKey = widget.screenKey;
    widget.controller.setQuestions(widget.questions, reset: changedScreen);
    if (changedScreen && widget.controller.isActive) {
      // The step advanced while voice was on: read the new screen out.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.controller.restart());
    }
  }

  @override
  Widget build(BuildContext context) {
    final VoiceIntakeController voice = widget.controller;
    final AppLocalizations l = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: voice,
      builder: (BuildContext context, _) {
        // Hidden only once the device has been asked and said no.
        if (voice.probed && !voice.canListen) return const SizedBox.shrink();

        if (!voice.isActive) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: MmCard(
              onTap: voice.start,
              padding: const EdgeInsets.all(Insets.md),
              color: voice.error == null ? AppColors.primaryTint : AppColors.warningTint,
              border: Border.all(
                color: (voice.error == null ? AppColors.primary : AppColors.warning)
                    .withValues(alpha: 0.25),
              ),
              child: Row(
                children: <Widget>[
                  SoftIcon(
                    icon: voice.error == null
                        ? Icons.mic_none_rounded
                        : Icons.mic_off_rounded,
                    color: voice.error == null ? AppColors.primary : AppColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          voice.error == null
                              ? l.intakeVoiceAnswerBySpeaking
                              : l.intakeVoiceCouldNotHear,
                          style: AppText.body.wght(700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          voice.error?.localizedMessage(l) ?? l.intakeVoiceInstructions,
                          style: AppText.bodySmall,
                        ),
                        if (voice.error != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(l.intakeVoiceTapToRetry, style: AppText.caption),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: MmCard(
            padding: const EdgeInsets.all(Insets.md),
            color: AppColors.primary.withValues(alpha: 0.06),
            border: Border.all(color: AppColors.primary, width: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _Pulse(listening: voice.isListening),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusFor(voice, l),
                        style: AppText.body.wght(700).tint(AppColors.primaryDeep),
                      ),
                    ),
                    if (voice.questionCount > 1)
                      PillTag(
                        label: '${voice.questionIndex + 1}/${voice.questionCount}',
                        color: AppColors.primary,
                        dense: true,
                      ),
                  ],
                ),
                if (voice.heard.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Text('“${voice.heard}”', style: AppText.bodySmall),
                ],
                if (voice.error != null) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Text(voice.error!.localizedMessage(l), style: AppText.bodySmall),
                ],
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    // "I have finished speaking" — the control a spoken
                    // interface always needs, for a room too noisy for the
                    // engine to notice the silence at the end of a sentence.
                    if (voice.isListening)
                      SoftButton(
                        label: l.intakeVoiceDoneSpeaking,
                        icon: Icons.check_rounded,
                        filled: true,
                        onPressed: voice.stopListening,
                      ),
                    SoftButton(
                      label: l.voiceSayItAgain,
                      icon: Icons.replay_rounded,
                      onPressed: voice.repeat,
                    ),
                    SoftButton(
                      label: l.intakeVoiceTurnOff,
                      icon: Icons.mic_off_rounded,
                      color: AppColors.inkSoft,
                      onPressed: voice.stop,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusFor(VoiceIntakeController voice, AppLocalizations l) => switch (voice.phase) {
        VoicePhase.listening => l.intakeVoicePhaseListening,
        VoicePhase.speaking => l.intakeVoicePhaseAsking,
        VoicePhase.thinking => l.voiceOneMoment,
        VoicePhase.requestingPermission => l.intakeVoicePhaseWaitingMic,
        VoicePhase.error => l.intakeVoicePhaseStopped,
        VoicePhase.idle => l.intakeVoicePhaseReady,
      };
}

/// A dot that breathes while the microphone is open, so it is obvious the
/// phone is waiting for *you* — the commonest confusion in a spoken interface.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.listening});

  final bool listening;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final double t = widget.listening ? _controller.value : 0;
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25 + 0.25 * t),
                blurRadius: 6 + 14 * t,
              ),
            ],
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
        );
      },
    );
  }
}
