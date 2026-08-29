import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/voice/voice_intake_controller.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import 'voice_intake_panel.dart';

/// Shared chrome for every step of the intake.
///
/// One layout for the whole questionnaire is deliberate: a person answering
/// forty questions about their own memory should never have to relearn where
/// the "continue" button is. The header states where they are, the body holds
/// only the questions, and the action bar never moves.
/// Publishes the intake's voice controller to every step under it.
///
/// An inherited scope rather than a constructor argument on nine screens: the
/// controller has to outlive a single step — it is what moves the flow on when
/// someone says "next" — and threading it through every step's constructor
/// would put voice plumbing in files that have nothing else to do with it.
class VoiceIntakeScope extends InheritedNotifier<VoiceIntakeController> {
  const VoiceIntakeScope({
    super.key,
    required VoiceIntakeController controller,
    required super.child,
  }) : super(notifier: controller);

  static VoiceIntakeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceIntakeScope>()?.notifier;
}

class IntakeScaffold extends StatelessWidget {
  const IntakeScaffold({
    super.key,
    required this.title,
    required this.children,
    this.voiceQuestions,
    this.voiceKey,
    this.subtitle,
    this.eyebrow,
    this.stepIndex,
    this.stepCount,
    this.onContinue,
    this.continueLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.onBack,
    this.footnote,
    this.accent = AppColors.primary,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final List<Widget> children;

  /// The questions on this screen, in the order they should be read aloud.
  /// Null or empty means the screen is tap-only and no microphone is offered.
  final List<VoiceIntakeQuestion>? voiceQuestions;

  /// Changes when the screen moves to a different set of questions, so the
  /// spoken flow restarts rather than carrying its position across.
  final Object? voiceKey;

  /// 1-based position in the intake, shown as "Step 4 of 8" plus a progress
  /// line. People abandon questionnaires that do not say how long they are.
  final int? stepIndex;
  final int? stepCount;

  final VoidCallback? onContinue;
  final String? continueLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onBack;
  final String? footnote;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool hasProgress = stepIndex != null && stepCount != null;
    final VoiceIntakeController? voice = VoiceIntakeScope.maybeOf(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (onBack != null)
                        Padding(
                          padding: const EdgeInsets.only(right: Insets.sm),
                          child: RoundIconButton(
                            icon: Icons.arrow_back_rounded,
                            onPressed: onBack,
                            tooltip: l.intakeBack,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          hasProgress
                              ? l.intakeStepProgress(stepIndex!, stepCount!)
                              : (eyebrow ?? ''),
                          style: AppText.overline.copyWith(color: accent),
                        ),
                      ),
                    ],
                  ),
                  if (hasProgress) ...<Widget>[
                    const SizedBox(height: Insets.sm),
                    MeterBar(value: stepIndex! / stepCount!, color: accent, height: 6),
                  ],
                  const SizedBox(height: Insets.lg),
                  Text(title, style: AppText.h1),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: Insets.sm),
                    Text(subtitle!, style: AppText.bodyLarge.copyWith(color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, Insets.xl),
                children: <Widget>[
                  if (voice != null && (voiceQuestions?.isNotEmpty ?? false))
                    VoiceIntakePanel(
                      controller: voice,
                      questions: voiceQuestions!,
                      screenKey: voiceKey,
                    ),
                  ...children,
                ],
              ),
            ),
            _ActionBar(
              onContinue: onContinue,
              continueLabel: continueLabel ?? l.actionContinue,
              secondaryLabel: secondaryLabel,
              onSecondary: onSecondary,
              footnote: footnote,
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onContinue,
    required this.continueLabel,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.footnote,
    required this.accent,
  });

  final VoidCallback? onContinue;
  final String continueLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? footnote;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, Insets.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (footnote != null) ...<Widget>[
            Text(footnote!, style: AppText.caption, textAlign: TextAlign.center),
            const SizedBox(height: Insets.sm),
          ],
          BigButton(label: continueLabel, onPressed: onContinue, color: accent, height: 60),
          if (secondaryLabel != null) ...<Widget>[
            const SizedBox(height: Insets.xs),
            TextButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!,
                  style: AppText.body.copyWith(color: AppColors.inkSoft)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A selectable row — the only answer control the questionnaire uses for
/// single and multiple choice alike, so a tap always means the same thing.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
    this.multiple = false,
    this.accent = AppColors.primary,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  /// Checkboxes for "select all that apply", circles for "choose one".
  final bool multiple;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: MmCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 14),
        color: selected ? accent.withValues(alpha: 0.08) : AppColors.surface,
        border: Border.all(
          color: selected ? accent : AppColors.hairline,
          width: selected ? 2 : 1,
        ),
        child: Row(
          children: <Widget>[
            _Indicator(selected: selected, multiple: multiple, accent: accent),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label,
                      style: AppText.body.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      )),
                  if (description != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(description!, style: AppText.caption),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.selected, required this.multiple, required this.accent});

  final bool selected;
  final bool multiple;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.quick,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? accent : Colors.transparent,
        border: Border.all(color: selected ? accent : AppColors.inkMuted, width: 2),
        borderRadius: Corners.r(multiple ? 8 : 999),
      ),
      child: selected
          ? Icon(multiple ? Icons.check_rounded : Icons.circle, size: multiple ? 17 : 10, color: Colors.white)
          : null,
    );
  }
}

/// A question with a small fixed scale beside it — the shape the symptom and
/// function screens both use. Options wrap rather than scroll horizontally so
/// nothing is hidden off the edge on a narrow phone.
class ScaleQuestion extends StatelessWidget {
  const ScaleQuestion({
    super.key,
    required this.question,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
    this.accent = AppColors.primary,
  });

  final String question;
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: MmCard(
        padding: const EdgeInsets.all(Insets.md),
        border: Border.all(
          color: selectedIndex == null ? AppColors.hairline : accent.withValues(alpha: 0.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(question, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (int i = 0; i < options.length; i++)
                  _ScaleChip(
                    label: options[i],
                    selected: selectedIndex == i,
                    onTap: () => onSelect(i),
                    accent: accent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaleChip extends StatelessWidget {
  const _ScaleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : AppColors.surfaceMuted,
          borderRadius: Corners.r(Corners.pill),
          border: Border.all(color: selected ? accent : AppColors.hairline),
        ),
        child: Text(
          label,
          style: AppText.bodySmall.copyWith(
            color: selected ? Colors.white : AppColors.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The line that appears under anything resembling a result. Repeated on
/// purpose: the boundary between "monitoring" and "diagnosis" has to be
/// restated wherever a number appears, not once in a terms screen.
class NotADiagnosisNote extends StatelessWidget {
  const NotADiagnosisNote({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? Insets.sm : Insets.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: Corners.r(Corners.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(message ?? l.intakeDiagnosisDisclaimerStandard,
                style: AppText.caption.copyWith(height: 1.45)),
          ),
        ],
      ),
    );
  }
}
