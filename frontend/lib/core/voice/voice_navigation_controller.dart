import 'dart:async';

import 'package:flutter/foundation.dart';

import 'speech_engines.dart';
import 'voice_language.dart';
import 'voice_models.dart';
import 'voice_nav_intent.dart';

/// Carries out a navigation the voice layer has decided on.
///
/// Returns false when this shell cannot reach [destination] — the controller
/// then says so aloud instead of leaving the person staring at an unchanged
/// screen wondering whether they were heard.
typedef VoiceNavHandler = bool Function(VoiceDestination destination);

/// Pops the current screen. Returns false when there is nothing to pop.
typedef VoiceNavBack = bool Function();

/// Drives spoken navigation:
///
/// ```
/// tap → permission → listen → match → navigate → confirm aloud
/// ```
///
/// It reuses the app's existing [SpeechRecognizer] and [SpeechSynthesizer], so
/// there is still exactly one speech stack — and it holds no AI call at all.
/// Navigation is a closed vocabulary; sending "go home" to a language model
/// would cost a round trip, fail offline, and be less accurate than the table
/// in [VoiceNavMatcher].
class VoiceNavigationController extends ChangeNotifier {
  VoiceNavigationController({
    required SpeechRecognizer recognizer,
    required SpeechSynthesizer synthesizer,
    required this.onNavigate,
    this.onBack,
    VoiceLanguage language = VoiceLanguage.english,
    Set<VoiceDestination> destinations = const <VoiceDestination>{},
    this.matcher = const VoiceNavMatcher(),
    this.speakAloud = true,
  })  : _recognizer = recognizer,
        _synthesizer = synthesizer,
        _language = language,
        _destinations = destinations;

  final SpeechRecognizer _recognizer;
  final SpeechSynthesizer _synthesizer;
  final VoiceNavMatcher matcher;

  /// Where a matched destination is actually carried out.
  final VoiceNavHandler onNavigate;

  /// How "go back" is carried out. Null means back is not offered here.
  final VoiceNavBack? onBack;

  /// Whether Mitra uses her voice at all: the opening question, and the
  /// confirmation as a screen opens. A caregiver can turn this off in a quiet
  /// room — a ward, a waiting area — without losing voice *input*.
  final bool speakAloud;

  VoiceLanguage _language;
  Set<VoiceDestination> _destinations;

  VoicePhase _phase = VoicePhase.idle;
  VoiceError? _error;
  String _heard = '';
  VoiceNavIntent? _intent;
  String _status = '';
  ResolvedVoiceLanguage? _resolvedInput;
  ResolvedVoiceLanguage? _resolvedOutput;
  bool _initialised = false;
  bool _disposed = false;

  /// Set the moment a destination is actually opened, so the host can dismiss
  /// its panel. Read-and-cleared by [takeNavigated].
  VoiceDestination? _navigated;

  /// Guards a stale turn finishing after the person has started another.
  int _turn = 0;

  /// Set while a turn is being acted on, so an engine that delivers its
  /// ending twice — a final result *and* a done status — navigates once.
  bool _resolving = false;

  /// Ends the turn when the words stop arriving.
  ///
  /// The recogniser's own `pauseFor` is the primary mechanism and is faster;
  /// this is the guarantee behind it. Some Android builds never end a turn on
  /// their own, and without this the person is left talking to a microphone
  /// that has stopped caring — which is exactly the "I have to press finished
  /// every time" complaint.
  Timer? _silence;

  /// Deliberately longer than the recogniser's own two-second pause, so the
  /// engine always gets first refusal and this only fires when it has failed
  /// to.
  static const Duration _settleAfterSpeech = Duration(milliseconds: 3500);

  /// A far more patient window before anything has been said: someone
  /// deciding what they want should not be cut off for thinking.
  static const Duration _settleBeforeSpeech = Duration(seconds: 7);

  // ── What the UI reads ──────────────────────────────────────────────────

  VoicePhase get phase => _phase;
  VoiceError? get error => _error;

  /// Updates live while the person is speaking — the feedback that tells an
  /// uncertain user the device is hearing them.
  String get recognizedText => _heard;

  /// The last thing understood, or null before the first turn.
  VoiceNavIntent? get intent => _intent;

  /// A short line for the panel: the confirmation, or why nothing happened.
  String get status => _status;

  VoiceLanguage get language => _language;
  Set<VoiceDestination> get destinations => _destinations;

  bool get isListening => _phase == VoicePhase.listening;
  bool get isBusy => _phase.isBusy;
  bool get canListen => _recognizer.isAvailable;

  /// Set when the device lacks the chosen language and we stepped down; the
  /// panel says so plainly rather than silently switching languages.
  ResolvedVoiceLanguage? get resolvedInputLanguage => _resolvedInput;
  ResolvedVoiceLanguage? get resolvedOutputLanguage => _resolvedOutput;

  /// The language actually being spoken, which is the fallback when the
  /// requested one is missing. Everything spoken uses this.
  VoiceLanguage get spokenLanguage =>
      _resolvedOutput?.resolved ?? _resolvedInput?.resolved ?? _language;

  /// The destinations available here, in the order they are offered, with
  /// their names in the spoken language — the panel's chips and the spoken
  /// help list both come from this.
  List<({VoiceDestination destination, String label})> get options =>
      VoiceDestination.values
          .where(_destinations.contains)
          .map((VoiceDestination d) => (
                destination: d,
                label: voiceDestinationLabel(d, spokenLanguage),
              ))
          .toList(growable: false);

  /// Consumes the "we just navigated" signal.
  VoiceDestination? takeNavigated() {
    final VoiceDestination? d = _navigated;
    _navigated = null;
    return d;
  }

  // ── Setup ──────────────────────────────────────────────────────────────

  /// Prepares both engines and resolves the language against the device.
  /// Safe to call more than once.
  Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;

    const VoiceLanguageResolver resolver = VoiceLanguageResolver();

    _resolvedInput = await _recognizer.initialize()
        ? resolver.resolve(_language, await _recognizer.supportedLocales())
        : ResolvedVoiceLanguage(requested: _language, resolved: null, localeId: null);

    _resolvedOutput = await _synthesizer.initialize()
        ? resolver.resolve(_language, await _synthesizer.supportedLanguages())
        : ResolvedVoiceLanguage(requested: _language, resolved: null, localeId: null);

    _notify();
  }

  /// The host tells us which destinations this shell can reach. Called on
  /// every build, so it must be cheap and must not notify on a no-op.
  void setDestinations(Set<VoiceDestination> value) {
    if (setEquals(_destinations, value)) return;
    _destinations = value;
    _notify();
  }

  /// Switches language and re-resolves against the device.
  Future<void> setLanguage(VoiceLanguage value) async {
    if (_language == value) return;
    await cancel();
    _language = value;
    _initialised = false;
    await initialize();
  }

  // ── The flow ───────────────────────────────────────────────────────────

  /// Starts a turn: the question, then listening for an answer.
  ///
  /// [ask] is false when the person has just interrupted — they already know
  /// what they want, and asking again would talk over them.
  Future<void> start({bool ask = true}) async {
    if (isBusy) return;
    await initialize();

    final int turn = ++_turn;
    _error = null;
    _heard = '';
    _intent = null;
    _status = '';
    _resolving = false;

    if (!await _recognizer.hasPermission()) {
      _set(VoicePhase.requestingPermission);
      final SpeechPermissionOutcome outcome = await _recognizer.requestPermission();
      if (_stale(turn)) return;
      switch (outcome) {
        case SpeechPermissionOutcome.granted:
          break;
        case SpeechPermissionOutcome.denied:
          return _fail(VoiceErrorKind.permissionDenied);
        case SpeechPermissionOutcome.permanentlyDenied:
          return _fail(VoiceErrorKind.permissionPermanentlyDenied);
        case SpeechPermissionOutcome.unavailable:
          return _fail(VoiceErrorKind.speechUnavailable);
      }
    }

    final ResolvedVoiceLanguage? input = _resolvedInput;
    if (input == null || !input.isSupported) {
      return _fail(VoiceErrorKind.languageUnsupported,
          detail: 'no recognizer locale for ${_language.name}');
    }

    // Ask first, then listen. The question is what turns a microphone icon
    // into something a person knows how to answer, and it has to finish
    // before the microphone opens or Mitra transcribes her own voice —
    // `FlutterTtsSynthesizer` awaits completion, so this ordering is enough.
    if (ask) {
      _status = VoiceNavSpeech.prompt(spokenLanguage);
      await _utter(_status, turn);
      if (_stale(turn)) return;
    }

    _set(VoicePhase.listening);
    _armSilence(turn);
    try {
      await _recognizer.listen(
        localeId: input.localeId!,
        // A place name is one or two words, so a short pause ends the turn:
        // waiting four seconds after "home" makes voice feel broken.
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 2),
        onResult: (SpeechResult result) {
          if (_stale(turn) || _phase != VoicePhase.listening) return;
          _heard = result.text;
          _notify();
          if (result.isFinal) {
            unawaited(_resolve(turn));
          } else {
            // Every word heard pushes the deadline back, so the net only ever
            // catches a genuine silence.
            _armSilence(turn);
          }
        },
        onError: (VoiceError error) {
          if (_stale(turn)) return;
          _fail(error.kind, detail: error.detail);
        },
      );
    } catch (e) {
      if (_stale(turn)) return;
      _fail(VoiceErrorKind.recognitionFailed, detail: e.toString());
    }
  }

  /// Ends listening and acts on whatever was heard.
  ///
  /// Reached three ways: the person taps "I have finished", the recogniser
  /// detects their pause, or [_silence] fires because it did not.
  Future<void> stopListening() async {
    if (_phase != VoicePhase.listening) return;
    final int turn = _turn;
    _silence?.cancel();
    await _recognizer.stop();
    if (_stale(turn)) return;
    await _resolve(turn);
  }

  /// Cuts Mitra off mid-sentence and listens straight away.
  ///
  /// Someone who already knows what they want should not have to sit through
  /// the question, and a companion that cannot be interrupted stops feeling
  /// like one.
  Future<void> interrupt() async {
    if (_phase == VoicePhase.speaking) {
      _turn++; // orphan the utterance so its completion changes nothing
      await _synthesizer.stop();
      _set(VoicePhase.idle);
    }
    await start(ask: false);
  }

  /// (Re)starts the deadline that ends a turn nobody is speaking into.
  void _armSilence(int turn) {
    _silence?.cancel();
    _silence = Timer(
      _heard.trim().isEmpty ? _settleBeforeSpeech : _settleAfterSpeech,
      () {
        if (_stale(turn) || _phase != VoicePhase.listening) return;
        unawaited(stopListening());
      },
    );
  }

  /// Carries out a destination the person tapped instead of said.
  ///
  /// The panel's chips use this, so someone who cannot be heard — a noisy
  /// room, a missing language model — still reaches every destination the
  /// voice route offers.
  Future<void> go(VoiceDestination destination) async {
    if (isBusy) await cancel();
    final int turn = ++_turn;
    _resolving = true;
    _intent = VoiceNavIntent.destination(destination, '');
    await _navigate(destination, turn);
  }

  Future<void> _resolve(int turn) async {
    if (_stale(turn) || _resolving) return;
    _resolving = true;
    _silence?.cancel();

    if (_heard.trim().isEmpty) return _fail(VoiceErrorKind.noSpeechDetected);

    _set(VoicePhase.thinking);
    final VoiceNavIntent intent = matcher.match(_heard, allowed: _destinations);
    _intent = intent;

    if (intent.isAction) {
      switch (intent.action!) {
        case VoiceNavAction.back:
          final bool popped = onBack?.call() ?? false;
          _status = popped
              ? VoiceNavSpeech.goingBack(spokenLanguage)
              : VoiceNavSpeech.notUnderstood(spokenLanguage);
          _set(VoicePhase.idle);
          if (popped) await _say(VoiceNavSpeech.goingBack(spokenLanguage), turn);
        case VoiceNavAction.help:
          final String text = VoiceNavSpeech.help(
            spokenLanguage,
            options.map((({VoiceDestination destination, String label}) o) => o.label)
                .toList(growable: false),
          );
          _status = text;
          _set(VoicePhase.idle);
          await _say(text, turn);
        case VoiceNavAction.stop:
          await cancel();
      }
      return;
    }

    if (intent.isNothing) {
      _status = VoiceNavSpeech.notUnderstood(spokenLanguage);
      _set(VoicePhase.idle);
      await _say(_status, turn);
      return;
    }

    await _navigate(intent.destination!, turn);
  }

  Future<void> _navigate(VoiceDestination destination, int turn) async {
    final String label = voiceDestinationLabel(destination, spokenLanguage);
    final bool handled = _destinations.contains(destination) && onNavigate(destination);

    if (!handled) {
      _status = VoiceNavSpeech.unavailable(spokenLanguage, label);
      _set(VoicePhase.idle);
      await _say(_status, turn);
      return;
    }

    _navigated = destination;
    _status = VoiceNavSpeech.opening(spokenLanguage, label);
    _set(VoicePhase.idle);
    await _say(_status, turn);
  }

  /// Speaks [text] when a voice is available, and leaves the phase alone.
  ///
  /// Never fails the turn: by the time anything is said the screen has either
  /// changed or is about to, so silence is a missing courtesy rather than an
  /// error.
  Future<void> _utter(String text, int turn) async {
    if (!speakAloud) return;
    final ResolvedVoiceLanguage? output = _resolvedOutput;
    if (output == null || !output.isSupported) return;

    _set(VoicePhase.speaking);
    try {
      await _synthesizer.speak(text, localeId: output.localeId!);
    } catch (_) {
      // Deliberately swallowed — see above.
    }
  }

  /// Speaks [text] and returns to rest.
  Future<void> _say(String text, int turn) async {
    await _utter(text, turn);
    if (_stale(turn)) return;
    _set(VoicePhase.idle);
  }

  /// Abandons the turn and returns to rest.
  Future<void> cancel() async {
    _turn++;
    _resolving = false;
    _silence?.cancel();
    if (_recognizer.isListening) await _recognizer.cancel();
    if (_synthesizer.isSpeaking) await _synthesizer.stop();
    _heard = '';
    _error = null;
    _status = '';
    _set(VoicePhase.idle);
  }

  void dismissError() {
    if (_error == null) return;
    _error = null;
    if (_phase == VoicePhase.error) _phase = VoicePhase.idle;
    _notify();
  }

  // ── Internals ──────────────────────────────────────────────────────────

  bool _stale(int turn) => _disposed || turn != _turn;

  void _set(VoicePhase phase) {
    _phase = phase;
    _notify();
  }

  void _fail(VoiceErrorKind kind, {String? detail}) {
    _error = VoiceError(kind, detail: detail);
    _status = kind.message;
    _phase = VoicePhase.error;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _silence?.cancel();
    _recognizer.dispose();
    _synthesizer.dispose();
    super.dispose();
  }
}
