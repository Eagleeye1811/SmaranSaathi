import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/ai/ai_context_builder.dart';
import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/ai/health_assistant.dart';
import '../../../core/models/monitoring.dart';
import '../../../core/services/app_state.dart';
import '../../../core/voice/voice_bootstrap.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../intake/intake_kit.dart';
import '../health/report_screen.dart';

/// The cognitive companion.
///
/// Not a general chatbot. It knows this person's own record and answers from
/// it; it leads with buttons rather than a blank prompt, because someone
/// worried about their memory should not have to work out what to ask; and it
/// refuses to diagnose no matter how the question is phrased — that check runs
/// before any model is consulted, so it cannot be talked around.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.initialAction, this.embedded = false});

  /// Opens with one quick action already answered — used by the "Why did my
  /// score change?" link on the progress screen.
  final HealthQuickAction? initialAction;

  /// True when hosted inside the patient shell rather than pushed.
  final bool embedded;

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
    final AiResult<AssistantReply> result = await _ai!.ask(text, state.aiContext());
    if (!mounted) return;
    setState(() => _thinking = false);

    switch (result) {
      case AiSuccess<AssistantReply>(:final AssistantReply value):
        _append(_Message.assistant(HealthAnswer(
          text: value.text,
          grounded: value.source == AiSource.onDevice,
        )));
      case AiError<AssistantReply>():
        _append(_Message.assistant(const HealthAnswer(
          text: 'I could not work that one out just now. The buttons above always '
              'work, even with no connection — they read straight from your own '
              'record.',
          grounded: true,
        )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.gutter, Insets.md, Insets.gutter, Insets.sm),
              child: ScreenHeader(
                eyebrow: 'Cognitive companion',
                title: 'Ask about your health',
                subtitle: 'Answers come from your own record.',
                leading: widget.embedded
                    ? null
                    : RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
              ),
            ),
            _QuickActions(onSelected: _run),
            Expanded(
              child: _messages.isEmpty
                  ? _Intro(name: state.patient.shortName)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                          Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
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
        answer = null;
  const _Message.assistant(HealthAnswer this.answer)
      : fromUser = false,
        text = '';

  final bool fromUser;
  final String text;
  final HealthAnswer? answer;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onSelected});

  final ValueChanged<HealthQuickAction> onSelected;

  @override
  Widget build(BuildContext context) {
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
                      Text(a.label,
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

class _Intro extends StatelessWidget {
  const _Intro({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.lg, Insets.gutter, Insets.md),
      children: <Widget>[
        CompanionSpeech(
          message: 'Hello $name. Ask me about your results, or tap one of the '
              'buttons above.',
          state: CompanionState.happy,
        ),
        const SizedBox(height: Insets.lg),
        const NotADiagnosisNote(
          message:
              'I can explain what your own results show and help you prepare for '
              'an appointment. I cannot diagnose any condition — only a clinician '
              'can do that.',
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: Insets.md, right: 24),
      child: MmCard(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(answer.text, style: AppText.body.copyWith(height: 1.5)),
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
                        child: Text(b, style: AppText.bodySmall.copyWith(height: 1.45)),
                      ),
                    ],
                  ),
                ),
            ],
            if (!answer.grounded) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text('General information — not based on your own record.',
                  style: AppText.caption),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: Corners.r(Corners.pill),
                        ),
                        child: Text(f.label,
                            style: AppText.bodySmall.copyWith(
                              color: AppColors.primaryDeep,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  Pressable(
                    onTap: onOpenReport,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.accentTint,
                        borderRadius: Corners.r(Corners.pill),
                      ),
                      child: Text('Open my summary',
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
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: Insets.md),
      child: Row(
        children: <Widget>[
          Companion(state: CompanionState.thinking, size: 46),
          SizedBox(width: Insets.sm),
          Text('Thinking…'),
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
                hintText: 'Ask a question…',
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
