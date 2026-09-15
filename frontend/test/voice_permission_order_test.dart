import 'package:flutter_test/flutter_test.dart';
import 'package:smaran_saathi/core/voice/speech_engines.dart';
import 'package:smaran_saathi/core/voice/voice_language.dart';
import 'package:smaran_saathi/core/voice/voice_models.dart';
import 'package:smaran_saathi/core/voice/voice_nav_intent.dart';
import 'package:smaran_saathi/core/voice/voice_navigation_controller.dart';

/// A recogniser shaped like the real Android plugin: it is the *permission*
/// that makes it work, and `initialize` fails until permission is granted.
/// That is what made the old ordering fail on a real device while every test
/// with an always-available fake passed.
class PermissionGatedRecognizer extends FakeSpeechRecognizer {
  PermissionGatedRecognizer() : super(alreadyGranted: false);

  bool granted = false;
  final List<String> calls = <String>[];

  @override
  Future<bool> initialize() async {
    calls.add('initialize');
    return granted;
  }

  @override
  Future<bool> hasPermission() async {
    calls.add('hasPermission');
    return granted;
  }

  @override
  Future<SpeechPermissionOutcome> requestPermission() async {
    calls.add('requestPermission');
    // Only a grant makes the engine work, exactly as on the device.
    if (permission == SpeechPermissionOutcome.granted) granted = true;
    return permission;
  }

  @override
  Future<List<String>> supportedLocales() async => <String>['en_IN'];
}

VoiceNavigationController build(PermissionGatedRecognizer rec) =>
    VoiceNavigationController(
      recognizer: rec,
      synthesizer: FakeSpeechSynthesizer(),
      destinations: VoiceDestination.values.toSet(),
      onNavigate: (VoiceDestination d) => true,
      onBack: () => false,
      language: VoiceLanguage.english,
    );

void main() {
  test('permission is asked before the engines are probed', () async {
    final PermissionGatedRecognizer rec = PermissionGatedRecognizer();
    final VoiceNavigationController c = build(rec);

    await c.start();

    final int askedAt = rec.calls.indexOf('requestPermission');
    final int probedAt = rec.calls.indexOf('initialize');
    expect(askedAt, isNonNegative, reason: 'permission was never requested');
    expect(probedAt, isNonNegative, reason: 'engines were never initialised');
    expect(askedAt, lessThan(probedAt),
        reason: 'probing the engines first raises the OS prompt and reads the '
            'answer before the person has given one');
    c.dispose();
  });

  test('the first turn reaches listening rather than failing', () async {
    final PermissionGatedRecognizer rec = PermissionGatedRecognizer();
    final VoiceNavigationController c = build(rec);

    await c.start();

    expect(c.error, isNull,
        reason: 'granting permission should not leave the turn in an error');
    expect(rec.listenCount, 1, reason: 'the microphone never opened');
    c.dispose();
  });

  test('a failed setup is not cached forever', () async {
    final PermissionGatedRecognizer rec = PermissionGatedRecognizer();
    final VoiceNavigationController c = build(rec);

    // First attempt: the person declines, so nothing comes up.
    rec.permission = SpeechPermissionOutcome.denied;
    await c.start();
    expect(c.error, isNotNull);
    expect(rec.listenCount, 0);

    // They change their mind. The old code had already latched "unavailable"
    // and never asked the engine again, so voice stayed dead until restart.
    rec.permission = SpeechPermissionOutcome.granted;
    await c.start();
    expect(c.error, isNull, reason: 'a later grant must revive voice');
    expect(rec.listenCount, 1);
    c.dispose();
  });
}
