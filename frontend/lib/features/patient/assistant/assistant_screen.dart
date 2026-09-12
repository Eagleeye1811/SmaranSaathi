import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/ai/ai_context_builder.dart';
import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/ai/health_assistant.dart';
import '../../../core/models/game.dart';
import '../../../core/models/memory_fragment.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/services/app_state.dart';
import '../../../core/voice/voice_bootstrap.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/content_labels.dart';
import '../../../l10n/locale_controller.dart';
import '../../intake/intake_kit.dart';
import '../games/game_launcher.dart';
import '../health/report_screen.dart';
import '../memory_home/memory_home_screen.dart';

/// The cognitive companion.
///
/// Not a general chatbot. It knows this person's own record and answers from
/// it; it leads with buttons rather than a blank prompt, because someone
/// worried about their memory should not have to work out what to ask; and it
/// refuses to diagnose no matter how the question is phrased — that check runs
/// before any model is consulted, so it cannot be talked around.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    this.initialAction,
    this.embedded = false,
    this.seedTurns,
  });

  /// Opens with one quick action already answered — used by the "Why did my
  /// score change?" link on the progress screen.
  final HealthQuickAction? initialAction;

  /// True when hosted inside the patient shell rather than pushed.
  final bool embedded;

  /// A conversation already had elsewhere — used by the Mood Check-In's
  /// "talk more with Mitra" hand-off, so the chat opens already showing that
  /// exchange instead of resetting to a blank screen. Rendered once at
  /// startup; `_turns` (built from `_messages`) then carries it into every
  /// `ask()` call from here on, exactly as if it had happened in this screen.
  final List<ConversationTurn>? seedTurns;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const HealthAssistant _assistant = HealthAssistant();

  final List<_Message> _messages = <_Message>[];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  AiService? _ai;
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    if (widget.seedTurns != null) {
      for (final ConversationTurn t in widget.seedTurns!) {
        _messages.add(t.fromUser ? _Message.user(t.text) : _Message.assistant(HealthAnswer(text: t.text)));
      }
    }
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(widget.initialAction!));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _ai?.dispose();
    super.dispose();
  }

  AppState get _state => AppScope.read(context);

  void _append(_Message message) {
    setState(() => _messages.add(message));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: Motion.normal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _run(HealthQuickAction action) {
    final AppState state = _state;
    _append(_Message.user(action.label));
    final HealthAnswer answer = _assistant.answer(
      action,
      patient: state.patient,
      intake: state.intake,
      snapshot: state.monitoring,
    );
    _append(_Message.assistant(answer));
  }

  /// The transcript so far, oldest first — exactly what `aiContext()` expects.
  List<ConversationTurn> get _turns => <ConversationTurn>[
        for (final _Message m in _messages)
          ConversationTurn(fromUser: m.fromUser, text: m.fromUser ? m.text : m.answer!.text),
      ];

  Future<void> _ask(String question) async {
    final String text = question.trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    _append(_Message.user(text));

    final AppState state = _state;
    final MonitoringSnapshot snapshot = state.monitoring;

    // The diagnosis guard runs first, before any model sees the question.
    final HealthAnswer? guarded = _assistant.diagnosisGuard(text, snapshot: snapshot);
    if (guarded != null) {
      _append(_Message.assistant(guarded));
      return;
    }

    setState(() => _thinking = true);
    _ai ??= buildPatientAssistant(state);

    // Falls back to the patient's profile language when this screen is
    // mounted outside a LocaleScope (some tests do that deliberately) —
    // matches the voice assistant's own precedent in ask_Saathi_button.dart.
    final LocaleController? locale = LocaleScope.maybeRead(context);
    final Stopwatch watch = Stopwatch()..start();
    final AiResult<AssistantReply> result = await _ai!.ask(
      text,
      state.aiContext(turns: _turns, replyLanguage: locale?.locale.languageCode),
    );
    // The on-device fallback answers in under a millisecond, which reads as
    // suspiciously instant for something meant to feel like a companion
    // thinking it over. A short floor keeps the pacing steady no matter which
    // path actually answered.
    final int remaining = 500 - watch.elapsedMilliseconds;
    if (remaining > 0) {
      await Future<void>.delayed(Duration(milliseconds: remaining));
    }
    if (!mounted) return;
    setState(() => _thinking = false);

    switch (result) {
      case AiSuccess<AssistantReply>(:final AssistantReply value):
        bool captured = false;
        if (value.sharedMemory != null) {
          await state.saveSharedMemory(value.sharedMemory!);
          captured = true;
        }
        if (value.resurfacedFragmentId != null) {
          await state.markMemoryResurfaced(value.resurfacedFragmentId!);
        }
        _append(_Message.assistant(
          // Both the Gemini and on-device paths are grounded by design —
          // each answers only from PatientAiContext and refuses to invent
          // facts (see gemini_ai_service.dart's system prompt). `grounded:
          // false` is reserved for HealthAssistant's general-education
          // replies (e.g. "what is dementia"), not for which AI backend
          // happened to answer.
          HealthAnswer(text: value.text),
          memoryCaptured: captured,
        ));
      case AiError<AssistantReply>():
        _append(_Message.assistant(HealthAnswer(
          text: AppLocalizations.of(context).assistantErrorFallback,
          grounded: true,
        )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    // A `CustomScrollView` carries the header cluster and the message list
    // (or the empty-state intro) as one scrollable region, rather than a
    // fixed `Column` with an `Expanded` message list: at large accessibility
    // text sizes the header, memory-home card and quick actions alone can
    // grow taller than a small phone's viewport, which a fixed `Column`
    // cannot absorb and reports as a `RenderFlex` overflow. Scrolling the
    // whole cluster together can never overflow, at any text scale. Only the
    // composer stays pinned outside it, which is also the correct chat UX.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.gutter, Insets.md, Insets.gutter, Insets.sm),
                      child: ScreenHeader(
                        eyebrow: l.assistantEyebrow,
                        title: l.assistantScreenTitle,
                        subtitle: l.assistantScreenSubtitle,
                        leading: widget.embedded
                            ? null
                            : RoundIconButton(
                                icon: Icons.arrow_back_rounded,
                                onPressed: () => Navigator.of(context).maybePop(),
                              ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.sm),
                      child: _MemoryHomeEntry(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const MemoryHomeScreen()),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.sm),
                      child: _MoodCheckInEntry(
                        onTap: () => GameLauncher.open(context, GameId.moodCanvas),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _QuickActions(onSelected: _run)),
                  if (_messages.isEmpty)
                    SliverToBoxAdapter(child: _Intro(name: state.patient.shortName))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
                      sliver: SliverList.builder(
                        itemCount: _messages.length + (_thinking ? 1 : 0),
                        itemBuilder: (BuildContext context, int i) {
                          if (i >= _messages.length) return const _Thinking();
                          return _Bubble(
                            message: _messages[i],
                            onFollowUp: _run,
                            onOpenReport: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ReportScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            _Composer(controller: _input, enabled: !_thinking, onSubmit: _ask),
          ],
        ),
      ),
    );
  }
}

class _Message {
  const _Message.user(this.text)
      : fromUser = true,
        answer = null,
        memoryCaptured = false;
  const _Message.assistant(HealthAnswer this.answer, {this.memoryCaptured = false})
      : fromUser = false,
        text = '';

  final bool fromUser;
  final String text;
  final HealthAnswer? answer;

  /// True when this reply is the one that captured a shared story into the
  /// patient's Memory Home — surfaced as a small chip on the bubble.
  final bool memoryCaptured;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onSelected});

  final ValueChanged<HealthQuickAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        children: <Widget>[
          for (final HealthQuickAction a in HealthQuickAction.values)
            Padding(
              padding: const EdgeInsets.only(right: Insets.xs),
              child: Pressable(
                onTap: () => onSelected(a),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: Corners.r(Corners.pill),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(a.icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(a.localizedLabel(l),
                          style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A card that opens the Memory Home — the room-by-room reward for sharing a
/// life story with Mitra. Shows how many rooms have at least one memory in
/// them, out of the six [MemoryCategory] values, so the invitation is
/// concrete rather than abstract.
class _MemoryHomeEntry extends StatelessWidget {
  const _MemoryHomeEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final Map<MemoryCategory, int> byCategory = state.memoriesByCategory;
    final int furnished = byCategory.values.where((int n) => n > 0).length;
    final int total = MemoryCategory.values.length;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accentTint,
          borderRadius: Corners.r(Corners.lg),
          border: Border.all(color: AppColors.accentSoft),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.home_rounded, size: 22, color: AppColors.accent),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.memoryHomeEntryTitle,
                      style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    furnished == 0
                        ? l.memoryHomeEntryEmpty
                        : l.memoryHomeEntryProgress(furnished, total),
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// A card that opens the Mood Check-In — a drawing, then a short guided
/// conversation about how the patient is feeling, ending with an invitation
/// to keep talking with Mitra. Placed here rather than in the activity hub:
/// this isn't a scored game, and the point of finishing it is to arrive at
/// exactly this screen.
class _MoodCheckInEntry extends StatelessWidget {
  const _MoodCheckInEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: Corners.r(Corners.lg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.self_improvement_rounded, size: 22, color: AppColors.primaryDeep),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.gameMoodCanvasEntryTitle,
                      style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  Text(l.gameMoodCanvasEntrySubtitle, style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.primaryDeep),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({this.name = ''});

  final String name;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.lg, Insets.gutter, Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CompanionSpeech(
            message: l.assistantIntroGreeting(name),
            state: CompanionState.happy,
          ),
          const SizedBox(height: Insets.lg),
          NotADiagnosisNote(
            message: l.assistantIntroDisclaimer,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.onFollowUp,
    required this.onOpenReport,
  });

  final _Message message;
  final ValueChanged<HealthQuickAction> onFollowUp;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: Insets.sm, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: Corners.r(Corners.lg),
          ),
          child: Text(message.text,
              style: AppText.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
    }

    final HealthAnswer answer = message.answer!;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 4, right: 8),
            child: Companion(state: CompanionState.happy, size: 38),
          ),
          Expanded(
            child: MmCard(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(answer.text, style: AppText.body.copyWith(height: 1.5)),
                  if (message.memoryCaptured) ...<Widget>[
                    const SizedBox(height: Insets.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.auto_awesome_rounded,
                            size: 15, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(l.assistantMemorySavedChip,
                            style: AppText.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ],
                  if (answer.bullets.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Insets.md),
                    for (final String b in answer.bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.only(top: 5, right: 8),
                              child: Icon(Icons.chevron_right_rounded,
                                  size: 16, color: AppColors.primary),
                            ),
                            Expanded(
                              child: Text(b,
                                  style: AppText.bodySmall.copyWith(height: 1.45)),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (!answer.grounded) ...<Widget>[
                    const SizedBox(height: Insets.sm),
                    Text(l.assistantGeneralInfoNote, style: AppText.caption),
                  ],
                  if (answer.followUps.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Insets.md),
                    Wrap(
                      spacing: Insets.xs,
                      runSpacing: Insets.xs,
                      children: <Widget>[
                        for (final HealthQuickAction f in answer.followUps)
                          Pressable(
                            onTap: () => onFollowUp(f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                borderRadius: Corners.r(Corners.pill),
                              ),
                              child: Text(f.localizedLabel(l),
                                  style: AppText.bodySmall.copyWith(
                                    color: AppColors.primaryDeep,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ),
                        Pressable(
                          onTap: onOpenReport,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.accentTint,
                              borderRadius: Corners.r(Corners.pill),
                            ),
                            child: Text(l.assistantOpenSummary,
                                style: AppText.bodySmall.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        children: <Widget>[
          const Companion(state: CompanionState.thinking, size: 46),
          const SizedBox(width: Insets.sm),
          Text(AppLocalizations.of(context).voiceThinkingButton),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: AppText.body,
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmit,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).assistantAskQuestionHint,
                filled: true,
                fillColor: AppColors.surfaceMuted,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: Corners.r(Corners.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          RoundIconButton(
            icon: Icons.send_rounded,
            onPressed: enabled ? () => onSubmit(controller.text) : null,
            background: AppColors.primary,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}
