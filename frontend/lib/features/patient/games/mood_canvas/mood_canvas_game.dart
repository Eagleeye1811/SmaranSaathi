import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/ai/ai_context_builder.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_service.dart';
import '../../../../core/models/daily.dart';
import '../../../../core/models/game.dart';
import '../../../../core/models/mood_drawing.dart';
import '../../../../core/services/app_state.dart';
import '../../../../core/voice/voice_bootstrap.dart';
import '../../../../core/widgets/companion.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/content_labels.dart';
import '../../assistant/assistant_screen.dart';
import '../game_shell.dart';
import 'mood_canvas_painter.dart';

/// Mood Check-In — a drawing with no prompt and no right answer, followed by
/// a short guided conversation about how the patient is feeling.
///
/// Deliberately not a scored activity: it never builds a [GamePerformance] or
/// calls [AppState.finishGame]. It also isn't a "game" the way the other
/// seven activities are, which is why it lives outside the Game Hub — its
/// entry point is a card on the Assistant screen (see `_MoodCheckInEntry`),
/// because the point of finishing it is to arrive there and keep talking.
/// See [AppState.saveMoodDrawing] for exactly what "done" means here.
class MoodCanvasGame extends StatefulWidget {
  const MoodCanvasGame({super.key});

  @override
  State<MoodCanvasGame> createState() => _MoodCanvasGameState();
}

enum _Phase { instructions, drawing, checkIn, saved }

/// How many of the patient's answers the check-in asks for before it wraps
/// up on its own, even if the AI layer never sets `moodCheckInDone` — a
/// deterministic floor under a model that could otherwise keep the
/// conversation open indefinitely. Matches the pacing both
/// `GeminiAiService`'s prompt and `OnDeviceAiService`'s fallback already aim
/// for (wrap up once the third answer comes in).
const int _maxCheckInAnswers = 4;

class _MoodCanvasGameState extends State<MoodCanvasGame> {
  final GameDefinition _game = MockData.game(GameId.moodCanvas);
  late final AppState _state = AppScope.read(context);
  final GlobalKey _canvasKey = GlobalKey();

  _Phase _phase = _Phase.instructions;

  // ── Drawing phase ─────────────────────────────────────────────────────
  final List<Stroke> _strokes = <Stroke>[];
  Stroke? _current;
  bool _capturing = false;
  Uint8List? _pngBytes;

  static const List<Color> _palette = <Color>[
    AppColors.ink,
    AppColors.terracotta,
    AppColors.accent,
    AppColors.primary,
    AppColors.secondary,
    AppColors.plum,
    AppColors.rose,
  ];
  Color _selectedColor = _palette.first;

  static const List<double> _brushWidths = <double>[4, 10, 20];
  double _selectedWidth = _brushWidths[1];

  bool get _hasDrawing => _strokes.isNotEmpty;

  // ── Check-in phase ────────────────────────────────────────────────────
  AiService? _ai;
  final TextEditingController _answer = TextEditingController();
  final List<MoodCheckInTurn> _transcript = <MoodCheckInTurn>[];
  String _currentQuestion = '';
  bool _thinking = false;

  // ── Saved phase ───────────────────────────────────────────────────────
  String? _closingMessage;

  @override
  void dispose() {
    _answer.dispose();
    _ai?.dispose();
    super.dispose();
  }

  void _startStroke(Offset point) {
    setState(() {
      _current = Stroke(color: _selectedColor, width: _selectedWidth)..points.add(point);
      _strokes.add(_current!);
    });
  }

  void _extendStroke(Offset point) {
    if (_current == null) return;
    setState(() => _current!.points.add(point));
  }

  void _endStroke() => _current = null;

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  Future<void> _confirmClear() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(l.gameMoodCanvasClearConfirmTitle),
            content: Text(l.gameMoodCanvasClearConfirmBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l.actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(l.gameMoodCanvasClear),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) setState(_strokes.clear);
  }

  /// Rasterises the drawing and moves into the check-in conversation. The
  /// drawing itself is not persisted yet — see [_finish] — so leaving this
  /// screen before finishing the conversation loses the drawing too, the
  /// same all-or-nothing behaviour the original save button had.
  Future<void> _advanceToCheckIn() async {
    if (!_hasDrawing || _capturing) return;
    setState(() => _capturing = true);
    try {
      final RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // Capped rather than the raw device pixel ratio (which can be 3-4x on
      // dense phones): these drawings are stored as full PNG bytes in an
      // eagerly-loaded Hive box with no compression, so an uncapped ratio
      // multiplies memory and disk use for no clinically-useful extra detail
      // on what a doctor reviews as a small thumbnail plus a full-screen view.
      final double pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null || !mounted) return;
      setState(() {
        _pngBytes = data.buffer.asUint8List();
        _currentQuestion = AppLocalizations.of(context).gameMoodCanvasCheckInFirstQuestion;
        _phase = _Phase.checkIn;
      });
    } finally {
      // Always clears, even on an exception or the `data == null` early
      // return above — otherwise the button stays permanently disabled for
      // the rest of this session with no way to retry.
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// The check-in transcript rendered as a conversation, oldest first — what
  /// both `aiContext()`'s `recentTurns` and the "talk more with Mitra"
  /// hand-off expect.
  List<ConversationTurn> _conversationTurns() => <ConversationTurn>[
        for (final MoodCheckInTurn t in _transcript) ...<ConversationTurn>[
          ConversationTurn(fromUser: false, text: t.question),
          ConversationTurn(fromUser: true, text: t.answer),
        ],
      ];

  Future<void> _submitAnswer() async {
    final String text = _answer.text.trim();
    if (text.isEmpty || _thinking) return;
    _answer.clear();

    // How many of the patient's answers this check-in has already received,
    // before this one — 0 for the very first. See `PatientAiContext
    // .moodCheckInTurn`'s doc comment for why this is measured before the
    // current turn is appended below.
    final int turnNumber = _transcript.length;
    final String question = _currentQuestion;
    setState(() {
      _transcript.add(MoodCheckInTurn(question: question, answer: text));
      _thinking = true;
    });

    _ai ??= buildPatientAssistant(_state);
    final AiResult<AssistantReply> result = await _ai!.ask(
      text,
      _state.aiContext(
        turns: _conversationTurns(),
        moodCheckInActive: true,
        moodCheckInTurn: turnNumber,
      ),
    );
    if (!mounted) return;
    setState(() => _thinking = false);

    switch (result) {
      case AiSuccess<AssistantReply>(:final AssistantReply value):
        if (value.moodCheckInDone || _transcript.length >= _maxCheckInAnswers) {
          _finish(value.text, value.moodLevel);
        } else {
          setState(() => _currentQuestion = value.text);
        }
      case AiError<AssistantReply>():
        // The on-device tier answers every `ask()` call itself (see
        // `ResilientAiService`), so this is reached only if that also fails
        // outright — treat it the same as a deliberate close rather than
        // stranding the patient mid-conversation with no way forward.
        _finish(AppLocalizations.of(context).gameMoodCanvasSavedBody, null);
    }
  }

  void _finish(String closingMessage, MoodLevel? moodLevel) {
    _state.saveMoodDrawing(_pngBytes!, transcript: _transcript, moodLevel: moodLevel);
    setState(() {
      _closingMessage = closingMessage;
      _phase = _Phase.saved;
    });
  }

  void _talkToMitra() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AssistantScreen(seedTurns: _conversationTurns()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.instructions => _buildInstructions(),
      _Phase.drawing => _buildDrawing(),
      _Phase.checkIn => _buildCheckIn(),
      _Phase.saved => _buildSaved(),
    };
  }

  Widget _buildInstructions() {
    final AppLocalizations l = AppLocalizations.of(context);
    return GameShell(
      game: _game,
      level: null,
      companionMessage: l.gameMoodCanvasInstructions,
      companionState: CompanionState.gentle,
      bottom: BigButton(
        label: l.gameMoodCanvasStart,
        icon: Icons.brush_rounded,
        color: _game.accent,
        onPressed: () => setState(() => _phase = _Phase.drawing),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_game.localizedName(l), style: AppText.h1.sized(24)),
              const SizedBox(height: 8),
              Text(l.gameMoodCanvasDescription, style: AppText.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawing() {
    final AppLocalizations l = AppLocalizations.of(context);
    // A fixed, computed height rather than `Expanded`: `GameShell`'s
    // non-scrollable body wraps `child` in a `Column`, and a `Column`'s
    // non-flex child always receives unbounded height regardless of the
    // Column's own resolved size (standard Flutter flex behaviour) — so an
    // `Expanded` here has no bounded ancestor to expand against and crashes.
    // A concrete height, inside the default scrollable shell, sidesteps that
    // entirely and matches how every other game safely uses `GameShell`.
    final double canvasHeight = MediaQuery.sizeOf(context).height * 0.46;
    return GameShell(
      game: _game,
      level: null,
      bottom: Row(
        children: <Widget>[
          RoundIconButton(
            icon: Icons.undo_rounded,
            tooltip: l.gameMoodCanvasUndo,
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: l.gameMoodCanvasClear,
            onPressed: _strokes.isEmpty ? null : _confirmClear,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BigButton(
              label: l.gameMoodCanvasSave,
              icon: Icons.arrow_forward_rounded,
              color: _game.accent,
              onPressed: _hasDrawing && !_capturing ? _advanceToCheckIn : null,
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: canvasHeight,
              child: ClipRRect(
                borderRadius: Corners.r(Corners.md),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: GestureDetector(
                    onPanStart: (DragStartDetails d) => _startStroke(d.localPosition),
                    onPanUpdate: (DragUpdateDetails d) => _extendStroke(d.localPosition),
                    onPanEnd: (_) => _endStroke(),
                    child: SizedBox.expand(
                      child: CustomPaint(
                        painter: MoodCanvasPainter(strokes: _strokes, background: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Insets.sm),
            _toolbar(l),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(AppLocalizations l) {
    return MmCard(
      padding: const EdgeInsets.all(Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Color color in _palette)
                _ColorSwatch(
                  color: color,
                  selected: color == _selectedColor,
                  onTap: () => setState(() => _selectedColor = color),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              for (final double width in _brushWidths) ...<Widget>[
                _BrushDot(
                  width: width,
                  color: _selectedColor,
                  selected: width == _selectedWidth,
                  onTap: () => setState(() => _selectedWidth = width),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckIn() {
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, 0),
              child: ScreenHeader(title: l.gameMoodCanvasCheckInTitle),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Insets.gutter),
                children: <Widget>[
                  for (final MoodCheckInTurn t in _transcript) ...<Widget>[
                    _CheckInBubble(text: t.question, fromMitra: true),
                    const SizedBox(height: Insets.sm),
                    _CheckInBubble(text: t.answer, fromMitra: false),
                    const SizedBox(height: Insets.md),
                  ],
                  if (_thinking)
                    const Padding(
                      padding: EdgeInsets.only(bottom: Insets.md),
                      child: Companion(state: CompanionState.thinking, size: 40),
                    )
                  else
                    _CheckInBubble(text: _currentQuestion, fromMitra: true),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _answer,
                      enabled: !_thinking,
                      style: AppText.body,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitAnswer(),
                      decoration: InputDecoration(
                        hintText: l.gameMoodCanvasCheckInAnswerHint,
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
                    tooltip: l.gameMoodCanvasCheckInSend,
                    onPressed: _thinking ? null : _submitAnswer,
                    background: AppColors.primary,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaved() {
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Companion(state: CompanionState.celebrating, size: 140),
              const SizedBox(height: Insets.lg),
              CompanionSpeech(
                message: _closingMessage ?? l.gameMoodCanvasSavedBody,
                state: CompanionState.happy,
                compact: true,
              ),
              const SizedBox(height: Insets.lg),
              BigButton(
                label: l.gameMoodCanvasTalkToMitraCta,
                icon: Icons.forum_rounded,
                color: _game.accent,
                onPressed: _talkToMitra,
              ),
              const SizedBox(height: Insets.sm),
              SoftButton(
                label: l.gameMoodCanvasDone,
                icon: Icons.check_rounded,
                color: AppColors.inkSoft,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInBubble extends StatelessWidget {
  const _CheckInBubble({required this.text, required this.fromMitra});

  final String text;
  final bool fromMitra;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromMitra ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 12),
        decoration: BoxDecoration(
          color: fromMitra ? AppColors.surface : AppColors.primary,
          borderRadius: Corners.r(Corners.lg),
          border: fromMitra ? Border.all(color: AppColors.hairline) : null,
        ),
        child: Text(
          text,
          style: AppText.body.copyWith(
            color: fromMitra ? AppColors.ink : Colors.white,
            fontWeight: fromMitra ? FontWeight.w500 : FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.ink : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _BrushDot extends StatelessWidget {
  const _BrushDot({
    required this.width,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceMuted : Colors.transparent,
          borderRadius: Corners.r(Corners.pill),
          border: Border.all(color: selected ? AppColors.ink : AppColors.hairline),
        ),
        alignment: Alignment.center,
        child: Container(
          width: width,
          height: width,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
