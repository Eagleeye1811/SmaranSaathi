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
    this.partLabel,
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

  /// Which half of the onboarding this screen belongs to — "Part A · Knowing
  /// the person". Shown beside the step counter because two named parts read
  /// as a conversation with a shape, while twelve numbered screens read as a
  /// form someone has to survive.
  final String? partLabel;

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
                  if (partLabel != null) ...<Widget>[
                    const SizedBox(height: Insets.xs),
                    Text(
                      partLabel!,
                      style: AppText.caption.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
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

/// A short label over a group of answers. Used wherever one screen carries
/// more than one question — which, after the questionnaire was collapsed from
/// forty questions into twelve screens, is most of them.
class QuestionLabel extends StatelessWidget {
  const QuestionLabel(this.text, {super.key, this.hint, this.number});

  /// For a screen whose *title* already asks the question. Repeating the
  /// wording underneath it reads as a stutter, so only the number and the
  /// "how to answer" hint are shown.
  const QuestionLabel.forTitle({super.key, required int this.number, this.hint})
      : text = '';

  final String text;
  final String? hint;

  /// The question's number in the printed questionnaire, when it has one.
  /// Shown because a caregiver working from the paper form should be able to
  /// see they are on the same question.
  final int? number;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (text.isEmpty)
            Text(
              AppLocalizations.of(context).onbQuestionNumber(number ?? 0),
              style: AppText.overline,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (number != null) ...<Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: Corners.r(Corners.pill),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text('$number',
                        style: AppText.caption.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: Insets.sm),
                ],
                Expanded(
                  child:
                      Text(text, style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: number == null || text.isEmpty ? 0 : 32),
              child: Text(hint!, style: AppText.caption),
            ),
          ],
        ],
      ),
    );
  }
}

/// A pill that toggles. The compact counterpart to [ChoiceTile], for lists
/// long enough that a full-width row per option would turn one question into
/// four screens of scrolling.
class ChipChoice extends StatelessWidget {
  const ChipChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = AppColors.primary,
    this.enabled = true,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  /// A chip that cannot be chosen right now — the fourth pick when only three
  /// are allowed — is dimmed rather than hidden, so the option a person is
  /// looking for never disappears from under them.
  final bool enabled;

  /// A small number on a selected chip, used where the order of picking
  /// carries meaning.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final Color fill = selected ? accent : AppColors.surface;
    final Color ink = selected ? Colors.white : AppColors.inkSoft;
    return Opacity(
      opacity: enabled || selected ? 1 : 0.4,
      child: Pressable(
        onTap: enabled || selected ? onTap : null,
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: Corners.r(Corners.pill),
            border: Border.all(
              color: selected ? accent : AppColors.hairline,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (badge != null) ...<Widget>[
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Text('$badge',
                      style: AppText.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppText.bodySmall
                      .copyWith(color: ink, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled text box. Single-line by default; [lines] above one turns it
/// into the free-text field the story questions use.
class IntakeField extends StatelessWidget {
  const IntakeField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.label,
    this.hint,
    this.keyboardType,
    this.lines = 1,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final int lines;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: Corners.r(Corners.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (label != null) ...<Widget>[
            Text(label!, style: AppText.label),
            const SizedBox(height: Insets.xs),
          ],
          TextField(
            controller: controller,
            keyboardType: lines > 1 ? TextInputType.multiline : keyboardType,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 3,
            style: AppText.bodyLarge,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.body.copyWith(color: AppColors.inkMuted),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 16),
              border: border(AppColors.hairline, 1),
              enabledBorder: border(AppColors.hairline, 1),
              focusedBorder: border(AppColors.primary, 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// The quiet aside that explains why a question is being asked.
///
/// Present on the screens where the reason is not obvious — education, who is
/// answering, onset — because a person who understands why they are being
/// asked something answers it more honestly, and is far less likely to stop
/// halfway through.
class WhyWeAsk extends StatelessWidget {
  const WhyWeAsk(this.message, {super.key, this.icon = Icons.lightbulb_outline_rounded});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: Corners.r(Corners.md),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.inkMuted),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(message, style: AppText.caption.copyWith(height: 1.45)),
            ),
          ],
        ),
      ),
    );
  }
}
