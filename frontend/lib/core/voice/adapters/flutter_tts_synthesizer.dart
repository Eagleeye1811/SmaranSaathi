import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_tts/flutter_tts.dart';

import '../assamese_speech_phonetics.dart';
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
    final List<String> list =
        languages.map((dynamic l) => l.toString()).toList(growable: true);
    if (kIsWeb) {
      if (!list.any((String s) => s.toLowerCase().startsWith('en'))) {
        list.add('en-IN');
        list.add('en-US');
      }
      if (!list.any((String s) => s.toLowerCase().startsWith('hi'))) {
        list.add('hi-IN');
      }
      if (!list.any((String s) => s.toLowerCase().startsWith('as'))) {
        list.add('as-IN');
      }
    }
    return list;
  }

  @override
  Future<void> speak(
    String text, {
    required String localeId,
    double rate = 0.45,
    double pitch = 1.0,
  }) async {
    if (!await initialize()) return;

    String targetLocale = localeId;
    String targetText = text;

    if (localeId.toLowerCase().startsWith('as')) {
      final List<dynamic> rawVoices =
          await _engine.getLanguages as List<dynamic>;
      final bool hasNativeAssamese = rawVoices
          .any((dynamic s) => s.toString().toLowerCase().startsWith('as'));
      if (!hasNativeAssamese) {
        targetLocale = 'hi-IN';
        targetText = AssameseSpeechPhonetics.toIndicPhoneticText(text);
      }
    }

    _speaking = true;
    try {
      await _engine.setLanguage(targetLocale);
      await _engine.setSpeechRate(rate);
      await _engine.setPitch(pitch);
      if (kIsWeb) {
        await _engine.speak(targetText).timeout(
              const Duration(seconds: 12),
              onTimeout: () => null,
            );
      } else {
        await _engine.speak(targetText);
      }
    } catch (e) {
      debugPrint('FlutterTtsSynthesizer.speak error: $e');
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
