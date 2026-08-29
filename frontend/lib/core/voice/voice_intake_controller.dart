import 'dart:async';

import 'package:flutter/foundation.dart';

import 'speech_engines.dart';
import 'voice_intake_matcher.dart';
import 'voice_language.dart';
import 'voice_models.dart';

/// One question the intake can ask out loud.
///
/// [onSelect] is what actually records the answer, so the voice layer never
/// holds intake state of its own — the screen owns it exactly as it does when
/// the same option is tapped.
@immutable
class VoiceIntakeQuestion {
  /// A question answered by choosing one of [options].
  const VoiceIntakeQuestion({
    required this.prompt,
    required this.options,
    required this.onSelect,
    this.answeredIndex,
  })  : onDictate = null,
        onNumber = null,
        answeredText = null;

  /// A question answered in the person's own words — a name, an occupation.
  const VoiceIntakeQuestion.dictated({
    required this.prompt,
    required ValueChanged<String> onSpeak,
    String? answered,
  })  : options = const <String>[],
        onSelect = _ignore,
        onDictate = onSpeak,
        onNumber = null,
        answeredIndex = null,
        answeredText = answered;

  /// A question answered with a number said out loud — an age.
  const VoiceIntakeQuestion.number({
    required this.prompt,
    required ValueChanged<int> onSpeak,
    String? answered,
  })  : options = const <String>[],
        onSelect = _ignore,
        onDictate = null,
        onNumber = onSpeak,
        answeredIndex = null,
        answeredText = answered;

  static void _ignore(int _) {}

  final String prompt;
  final List<String> options;
  final ValueChanged<int> onSelect;

  /// Set on a dictated question: receives the cleaned-up words.
  final ValueChanged<String>? onDictate;

  /// Set on a numeric question: receives the number that was said.
  final ValueChanged<int>? onNumber;

  /// Already answered, so a re-run of the screen can skip it.
  final int? answeredIndex;
  final String? answeredText;

  bool get isDictated => onDictate != null || onNumber != null;

  /// Whether this question already has an answer, whichever kind it is.
  bool get isAnswered => answeredIndex != null ||
      (answeredText != null && answeredText!.trim().isNotEmpty);
}

/// Reading a screen's questions aloud and taking the answers by voice.
///
/// The loop is deliberately the same one a person would use with another
/// person: ask, listen, confirm what was heard, move on. Saying "next" moves
/// to the following question, and on the last one it leaves the screen — which
/// is the whole point, because a questionnaire you can answer without looking
/// at the phone is usable by someone who cannot read the phone.
///
/// Nothing here is required: every question stays tappable while voice is
/// running, and an answer given by tapping is not overwritten.
class VoiceIntakeController extends ChangeNotifier {
  VoiceIntakeController({
    required SpeechRecognizer recognizer,
    required SpeechSynthesizer synthesizer,
    required VoidCallback onAdvance,
    VoidCallback? onGoBack,
    VoiceLanguage language = VoiceLanguage.english,
    VoiceIntakeMatcher matcher = const VoiceIntakeMatcher(),
  })  : _recognizer = recognizer,
        _synthesizer = synthesizer,
        _onAdvance = onAdvance,
        _onGoBack = onGoBack,
        _language = language,
        _matcher = matcher;

  final SpeechRecognizer _recognizer;
  final SpeechSynthesizer _synthesizer;
  final VoiceIntakeMatcher _matcher;

  /// Called when the person says "next" on the last question of the screen.
  final VoidCallback _onAdvance;
  final VoidCallback? _onGoBack;

  final VoiceLanguage _language;

  List<VoiceIntakeQuestion> _questions = const <VoiceIntakeQuestion>[];
  int _index = 0;

  VoicePhase _phase = VoicePhase.idle;
  VoiceError? _error;
  String _heard = '';
  String _spoken = '';
  bool _active = false;
  bool _initialised = false;

  /// Whether the engines have actually been asked what they can do.
  ///
  /// Until they have, [canListen] is false simply because nothing has looked —
  /// which is not the same as "this device cannot listen", and treating the
  /// two the same is what hid the microphone on every screen.
  bool _probed = false;
  bool _disposed = false;
  ResolvedVoiceLanguage? _input;
  ResolvedVoiceLanguage? _output;

  /// Guards a turn that finishes after the person has moved on.
  int _turn = 0;

  /// Consecutive things said that were neither an answer nor an instruction.
  ///
  /// Capped, because "I did not catch that" repeated forever is a trap: a
  /// person whose accent or room the engine cannot handle would never get out
  /// of the question, and the screen is fully usable by tapping.
  int _misses = 0;
  static const int _maxMisses = 2;

  // ── What the UI reads ──────────────────────────────────────────────────

  VoicePhase get phase => _phase;
  VoiceError? get error => _error;

  /// Whether voice mode is on. The mic button toggles this.
  bool get isActive => _active;

  /// The words heard so far, updating live while the person speaks.
  String get heard => _heard;

  /// The last thing said aloud, shown as a caption for anyone who cannot hear
  /// it — a noisy room, a hard-of-hearing user, a muted phone.
  String get spoken => _spoken;

  VoiceIntakeQuestion? get current =>
      _index < _questions.length ? _questions[_index] : null;

  int get questionIndex => _index;
  int get questionCount => _questions.length;

  bool get isListening => _phase == VoicePhase.listening;
  bool get isSpeaking => _phase == VoicePhase.speaking;
  bool get isBusy => _phase.isBusy;

  /// False hides the whole feature rather than offering something that cannot
  /// work — a device with no speech engine, or a build without the plugins.
  bool get canListen => _recognizer.isAvailable;

  /// True once the device has been asked. Only then does [canListen] being
  /// false mean anything.
  bool get probed => _probed;

  // ── Setup ──────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;
    const VoiceLanguageResolver resolver = VoiceLanguageResolver();

    if (await _recognizer.initialize()) {
      _input = resolver.resolve(_language, await _recognizer.supportedLocales());
    }
    if (await _synthesizer.initialize()) {
      _output = resolver.resolve(_language, await _synthesizer.supportedLanguages());
    }
    _probed = true;
    _notify();
  }

  /// The questions on the screen right now. Called on every rebuild, so the
  /// list stays in step with what is on screen; the position is kept unless
  /// the screen itself changed.
  void setQuestions(List<VoiceIntakeQuestion> questions, {bool reset = false}) {
    _questions = questions;
    if (reset || _index >= questions.length) _index = 0;
  }

  // ── The loop ───────────────────────────────────────────────────────────

  /// Turns voice mode on and asks the first unanswered question.
  Future<void> start() async {
    if (_active) return;
    await initialize();
    if (!canListen) {
      _fail(VoiceErrorKind.speechUnavailable);
      return;
    }

    if (!await _ensurePermission()) return;

    _active = true;
    _error = null;
    // Start where there is still something to answer, so turning voice on
    // half way through a screen does not re-ask what is already answered.
    final int firstOpen =
        _questions.indexWhere((VoiceIntakeQuestion q) => !q.isAnswered);
    _index = firstOpen < 0 ? 0 : firstOpen;
    _notify();
    await _ask();
  }

  /// Turns voice mode off. The screen keeps every answer already given.
  Future<void> stop() async {
    _active = false;
    _turn++;
    await _recognizer.cancel();
    await _synthesizer.stop();
    _heard = '';
    _set(VoicePhase.idle);
  }

  Future<void> toggle() => _active ? stop() : start();

  /// Reads the current question and its options, then opens the microphone.
  Future<void> _ask() async {
    final VoiceIntakeQuestion? question = current;
    if (question == null || !_active) return;

    final int turn = ++_turn;
    _heard = '';

    _misses = 0;
    final StringBuffer script = StringBuffer(question.prompt);
    for (int i = 0; i < question.options.length; i++) {
      script.write('. ${i + 1}. ${question.options[i]}');
    }
    if (question.onNumber != null) {
      script.write('. Say the number.');
    } else if (question.onDictate != null) {
      script.write('. Say it after the beep, then I will read it back.');
    } else if (question.options.isEmpty) {
      script.write('. Say next when you are ready.');
    } else {
      script.write('. Say your answer, or say the number.');
    }

    await _say(script.toString(), turn: turn);
    if (_stale(turn) || !_active) return;
    await _listen(turn);
  }

  /// Says the question again — the "pardon?" of a spoken interface.
  Future<void> repeat() async {
    if (!_active) return;
    await _recognizer.cancel();
    await _ask();
  }

  Future<void> _say(String text, {required int turn}) async {
    final ResolvedVoiceLanguage? out = _output;
    _spoken = text;
    _set(VoicePhase.speaking);
    if (out == null || !out.isSupported) return;
    try {
      await _synthesizer.speak(text, localeId: out.localeId!);
    } catch (error) {
      // A failed utterance must not stop the flow: the question is on screen
      // as well, and listening is still worth doing.
      debugPrint('VoiceIntakeController: speaking failed ($error)');
    }
  }

  Future<void> _listen(int turn) async {
    final ResolvedVoiceLanguage? input = _input;
    if (input == null || !input.isSupported) {
      _fail(VoiceErrorKind.languageUnsupported);
      return;
    }

    _set(VoicePhase.listening);
    try {
      await _recognizer.listen(
        localeId: input.localeId!,
        onResult: (SpeechResult result) {
          if (_stale(turn) || _phase != VoicePhase.listening) return;
          _heard = result.text;
          _notify();
          if (result.isFinal) unawaited(_handle(result.text, turn));
        },
        onError: (VoiceError error) {
          if (_stale(turn)) return;
          // Silence is not a failure worth stopping for — ask again.
          if (error.kind == VoiceErrorKind.noSpeechDetected) {
            unawaited(_nudge(turn));
            return;
          }
          _fail(error.kind, detail: error.detail);
        },
      );
    } catch (error) {
      if (_stale(turn)) return;
      _fail(VoiceErrorKind.recognitionFailed, detail: error.toString());
    }
  }

  /// Ends the turn early and uses whatever was heard.
  Future<void> stopListening() async {
    if (_phase != VoicePhase.listening) return;
    final int turn = _turn;
    await _recognizer.stop();
    if (_stale(turn)) return;
    await _handle(_heard, turn);
  }

  Future<void> _nudge(int turn) async {
    if (_stale(turn) || !_active) return;
    _misses++;
    if (_misses > _maxMisses) {
      await _say(
        'I am having trouble hearing you. You can tap your answer on the '
        'screen instead.',
        turn: turn,
      );
      // Reported, not just switched off. Silently reverting to the "answer by
      // speaking" card looks like the button did nothing, which is exactly
      // what a person with a muted microphone would conclude.
      _active = false;
      _turn++;
      await _recognizer.cancel();
      await _synthesizer.stop();
      _heard = '';
      _error = const VoiceError(VoiceErrorKind.noSpeechDetected);
      _set(VoicePhase.error);
      return;
    }
    await _say('I did not catch that. Please say it again.', turn: turn);
    if (_stale(turn) || !_active) return;
    await _listen(turn);
  }

  /// Applies what was said: an answer, an instruction, or neither.
  Future<void> _handle(String transcript, int turn) async {
    if (_stale(turn) || !_active) return;
    final VoiceIntakeQuestion? question = current;
    if (question == null) return;

    _set(VoicePhase.thinking);
    final VoiceIntakeMatch result = _matcher.match(transcript, question.options);

    if (result.isCommand) {
      _misses = 0;
      switch (result.command!) {
        case VoiceIntakeCommand.next:
          await _advance();
        case VoiceIntakeCommand.back:
          await _goBack();
        case VoiceIntakeCommand.repeat:
          await repeat();
        case VoiceIntakeCommand.stop:
          await _say('Voice off. You can still tap your answers.', turn: turn);
          await stop();
      }
      return;
    }

    // A dictated question takes the words themselves, once they are not an
    // instruction — otherwise "next" would be recorded as somebody's name.
    if (question.isDictated && !result.isCommand) {
      final String cleaned = _matcher.cleanDictation(transcript);
      if (question.onNumber != null) {
        final int? number = _matcher.spokenNumber(transcript);
        if (number == null) {
          await _nudge(turn);
          return;
        }
        _misses = 0;
        question.onNumber!(number);
        await _say('$number.', turn: turn);
      } else {
        if (cleaned.isEmpty) {
          await _nudge(turn);
          return;
        }
        _misses = 0;
        question.onDictate!(cleaned);
        await _say('$cleaned.', turn: turn);
      }
      if (_stale(turn) || !_active) return;
      await _advance();
      return;
    }

    if (result.isOption) {
      _misses = 0;
      final int choice = result.optionIndex!;
      question.onSelect(choice);
      await _say('${question.options[choice]}.', turn: turn);
      if (_stale(turn) || !_active) return;
      await _advance();
      return;
    }

    await _nudge(turn);
  }

  /// The next question, or the next screen when this was the last one.
  Future<void> _advance() async {
    if (!_active) return;
    if (_index < _questions.length - 1) {
      _index++;
      _notify();
      await _ask();
      return;
    }
    final int turn = ++_turn;
    await _recognizer.cancel();
    await _say('Moving on.', turn: turn);
    if (!_active) return;
    _index = 0;
    _onAdvance();
    _set(VoicePhase.idle);
  }

  Future<void> _goBack() async {
    if (_index > 0) {
      _index--;
      _notify();
      await _ask();
      return;
    }
    await _recognizer.cancel();
    _onGoBack?.call();
    _set(VoicePhase.idle);
  }

  /// Asks the current question again after the screen changed under us.
  Future<void> restart() async {
    if (!_active) return;
    _index = 0;
    await _recognizer.cancel();
    await _ask();
  }

  Future<bool> _ensurePermission() async {
    if (await _recognizer.hasPermission()) return true;
    _set(VoicePhase.requestingPermission);
    final SpeechPermissionOutcome outcome = await _recognizer.requestPermission();
    switch (outcome) {
      case SpeechPermissionOutcome.granted:
        return true;
      case SpeechPermissionOutcome.denied:
        _fail(VoiceErrorKind.permissionDenied);
        return false;
      case SpeechPermissionOutcome.permanentlyDenied:
        _fail(VoiceErrorKind.permissionPermanentlyDenied);
        return false;
      case SpeechPermissionOutcome.unavailable:
        _fail(VoiceErrorKind.speechUnavailable);
        return false;
    }
  }

  // ── Plumbing ───────────────────────────────────────────────────────────

  bool _stale(int turn) => _disposed || turn != _turn;

  void _set(VoicePhase phase) {
    _phase = phase;
    _notify();
  }

  void _fail(VoiceErrorKind kind, {String? detail}) {
    _active = false;
    _error = VoiceError(kind, detail: detail);
    _set(VoicePhase.error);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _recognizer.dispose();
    _synthesizer.dispose();
    super.dispose();
  }
}
