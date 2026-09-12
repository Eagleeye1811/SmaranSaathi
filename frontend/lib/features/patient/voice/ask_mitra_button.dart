import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/voice/speech_engines.dart';
import '../../../core/voice/voice_assistant_controller.dart';
import '../../../core/voice/voice_bootstrap.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/locale_controller.dart';
import 'voice_assistant_sheet.dart';

/// The way into the voice assistant from the patient home screen.
///
/// A card rather than a floating button: the home screen's whole premise is
/// "one screen, four decisions, no menus", and a hovering control would be a
/// fifth thing competing for attention. This reads as one more thing Mitra
/// offers, in the same visual language as everything around it.
///
/// It owns the [VoiceAssistantController] for the session so the conversation
/// survives the sheet being closed and reopened.
class AskMitraButton extends StatefulWidget {
  const AskMitraButton({
    super.key,
    this.recognizer,
    this.synthesizer,
  });

  /// Injected by tests. In the app these are null, and the controller falls
  /// back to the unavailable engines until the speech plugins are added.
  final SpeechRecognizer? recognizer;
  final SpeechSynthesizer? synthesizer;

  @override
  State<AskMitraButton> createState() => _AskMitraButtonState();
}

class _AskMitraButtonState extends State<AskMitraButton> {
  VoiceAssistantController? _controller;

  VoiceAssistantController _ensureController() {
    // Null outside a LocaleScope; the controller then falls back to the
    // patient's profile language.
    final LocaleController? locale = LocaleScope.maybeRead(context);
    return _controller ??= buildVoiceController(
      AppScope.read(context),
      recognizer: widget.recognizer,
      synthesizer: widget.synthesizer,
      language: locale?.voiceLanguage,
      replyLanguage: locale?.locale.languageCode,
    );
  }

  /// The interface language can change while this widget is alive. Rebuilding
  /// the controller keeps speech recognition, text-to-speech and the
  /// assistant's replies all following the picker.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final VoiceAssistantController? existing = _controller;
    final LocaleController? locale = LocaleScope.maybeOf(context);
    if (existing == null || locale == null) return;
    if (existing.language != locale.voiceLanguage) {
      existing.setLanguage(locale.voiceLanguage);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final VoiceAssistantController controller = _ensureController();
    await controller.initialize();
    if (!mounted) return;
    await VoiceAssistantSheet.show(context, controller);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return MmCard(
      onTap: _open,
      color: AppColors.plumTint,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          const Companion(state: CompanionState.listening, size: 54),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.voiceAskMitra, style: AppText.h3),
                const SizedBox(height: 2),
                Text(l.voiceTalkAboutDay, style: AppText.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.plum,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}
