import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

import '../speech_engines.dart';

/// `flutter_tts` behind the app's [SpeechSynthesizer] interface.
class FlutterTtsSynthesizer implements SpeechSynthesizer {
  FlutterTtsSynthesizer({FlutterTts? engine}) : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;
  bool _available = false;
  bool _initialised = false;
  bool _speaking = false;

  @override
  Future<bool> initialize() async {
    if (_initialised) return _available;
    _initialised = true;
    try {
      // Makes `speak` await the end of the utterance, which is what lets the
      // controller move to `idle` exactly when the audio finishes rather than
      // when it starts.
      await _engine.awaitSpeakCompletion(true);

      if (!kIsWeb && Platform.isIOS) {
        // Do not silence background audio or steal the session permanently —
        // a patient listening to the radio should get it back afterwards.
        await _engine.setSharedInstance(true);
        await _engine.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          <IosTextToSpeechAudioCategoryOptions>[
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
        );
      }

      final List<dynamic> languages = await _engine.getLanguages as List<dynamic>;
      _available = languages.isNotEmpty;
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  @override
  bool get isAvailable => _available;

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<List<String>> supportedLanguages() async {
    if (!await initialize()) return const <String>[];
    final List<dynamic> languages = await _engine.getLanguages as List<dynamic>;
    return languages.map((dynamic l) => l.toString()).toList(growable: false);
  }

  @override
  Future<void> speak(
    String text, {
    required String localeId,
    double rate = 0.45,
    double pitch = 1.0,
  }) async {
    if (!await initialize()) return;
    await _engine.setLanguage(localeId);
    await _engine.setSpeechRate(rate);
    await _engine.setPitch(pitch);
    _speaking = true;
    try {
      // Awaits completion because of `awaitSpeakCompletion(true)` above.
      await _engine.speak(text);
    } finally {
      _speaking = false;
    }
  }

  @override
  Future<void> stop() async {
    _speaking = false;
    await _engine.stop();
  }

  @override
  void dispose() => _engine.stop();
}
