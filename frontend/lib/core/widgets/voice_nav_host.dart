import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/locale_controller.dart';
import '../voice/speech_engines.dart';
import '../voice/voice_language.dart';
import '../voice/voice_bootstrap.dart';
import '../voice/voice_models.dart';
import '../voice/voice_nav_intent.dart';
import '../voice/voice_navigation_controller.dart';

/// Wraps a shell's body with spoken navigation: a microphone button, and the
/// panel that opens when it is pressed.
///
/// An in-tree overlay rather than a modal route, and that is load-bearing:
/// several destinations are *pushed* pages (the report, the care plan), so a
/// sheet sitting on the navigator would have to be popped in the right order
/// around every push. A `Stack` inside the body has no route of its own, so
/// the handler can navigate however it likes.
///
/// Placed as the Scaffold's `body`, it sits above the content and below the
/// bottom navigation — the bar the patient already knows stays visible and
/// reachable while Mitra is listening.
class VoiceNavHost extends StatefulWidget {
  const VoiceNavHost({
    super.key,
    required this.destinations,
    required this.onNavigate,
    required this.child,
    this.accent = AppColors.plum,
    this.recognizer,
    this.synthesizer,
    this.bottomInset = 10,
    this.showFloatingMic = true,
  });

  /// Whether to render the floating resting mic button inside this host.
  /// Set to false when a host is paired with a bottom navigation bar that
  /// embeds its own center bulged mic button.
  final bool showFloatingMic;

  /// What this shell can reach. Anything outside the set is answered aloud
  /// with "I cannot open that from here" rather than ignored.
  final Set<VoiceDestination> destinations;

  /// Carries out a destination. Return false if it could not be done.
  final VoiceNavHandler onNavigate;

  final Widget child;
  final Color accent;

  /// Injected by tests. Null in the app, where the plugin-backed engines are
  /// built by `buildVoiceNavController`.
  final SpeechRecognizer? recognizer;
  final SpeechSynthesizer? synthesizer;

  /// Gap between the microphone button and the bottom of the body — that is,
  /// above the bottom navigation bar the shell draws underneath.
  final double bottomInset;

  /// Diameter of the resting microphone button.
  static const double micDiameter = 66;

  /// How much of the bottom of the body the microphone reserves.
  ///
  /// Screens inside a [VoiceNavHost] that float their own button — Today's
  /// "Create reminder", say — must clear this, because a Scaffold's FAB and
  /// this overlay know nothing about each other and will happily draw on top
  /// of one another. Published as a constant rather than repeated as a magic
  /// number, so moving the microphone moves everything that avoids it.
  static const double micLaneHeight = micDiameter + 10 + 8;

  @override
  State<VoiceNavHost> createState() => VoiceNavHostState();
}

/// Allows descendant navigation bars to trigger voice panel listening.
class VoiceNavScope extends InheritedWidget {
  const VoiceNavScope({
    super.key,
    required this.state,
    required super.child,
  });

  final VoiceNavHostState state;

  static VoiceNavHostState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VoiceNavScope>()?.state;
  }

  @override
  bool updateShouldNotify(VoiceNavScope oldWidget) => state != oldWidget.state;
}

class VoiceNavHostState extends State<VoiceNavHost> {
  VoiceNavigationController? _controller;
  bool _open = false;

  /// Starts voice listening and opens the voice panel.
  Future<void> openPanel() => _openPanel();

  /// Closes the voice panel.
  Future<void> closePanel() => _closePanel();

  /// Whether the voice panel overlay is currently visible.
  bool get isOpen => _open;

  VoiceNavigationController _ensureController() {
    final VoiceNavigationController? existing = _controller;
    if (existing != null) return existing;

    // Null outside a LocaleScope — bare widget-test harnesses build their own
    // MaterialApp — and English is then the right default.
    final LocaleController? locale = LocaleScope.maybeRead(context);
    final VoiceNavigationController created = buildVoiceNavController(
      onNavigate: widget.onNavigate,
      onBack: _goBack,
      destinations: widget.destinations,
      recognizer: widget.recognizer,
      synthesizer: widget.synthesizer,
      language: locale?.voiceLanguage,
    );
    created.addListener(_onControllerChanged);
    return _controller = created;
  }

  bool _goBack() {
    final NavigatorState navigator = Navigator.of(context);
    if (!navigator.canPop()) return false;
    navigator.pop();
    return true;
  }

  /// Closes the panel the moment a destination actually opens — the screen
  /// behind it has already changed, and leaving the panel up would hide it.
  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller?.takeNavigated() != null && _open) {
      setState(() => _open = false);
    }
  }

  /// The interface language can change while this widget is alive; rebuilding
  /// the controller keeps recognition and speech following the picker.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final VoiceNavigationController? existing = _controller;
    final LocaleController? locale = LocaleScope.maybeOf(context);
    if (existing == null || locale == null) return;
    if (existing.language != locale.voiceLanguage) {
      existing.setLanguage(locale.voiceLanguage);
    }
  }

  @override
  void didUpdateWidget(VoiceNavHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!setEquals(oldWidget.destinations, widget.destinations)) {
      _controller?.setDestinations(widget.destinations);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openPanel() async {
    final VoiceNavigationController controller = _ensureController();
    setState(() => _open = true);
    if (!mounted || !_open) return;
    // Straight into listening: the button press *is* the intent to speak, and
    // an extra "now tap to start" step is one more thing to remember.
    //
    // `start` does the setup itself, in the one order that works: microphone
    // permission first, engines second. Calling `initialize` here as well put
    // the engine probe back in front of the prompt, which is the bug this
    // ordering exists to avoid.
    await controller.start();
  }

  Future<void> _closePanel() async {
    await _controller?.cancel();
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final VoiceNavigationController? controller = _controller;
    return VoiceNavScope(
      state: this,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: widget.child),
          if (_open && controller != null)
            Positioned.fill(
              child: _VoicePanel(
                controller: controller,
                accent: widget.accent,
                onClose: _closePanel,
              ),
            ),
          // Centred and low, so it reads as part of the bottom bar rather than
          // as a fifth thing floating over the content — and so it stays clear
          // of the bottom-right corner, which the Today and dashboard screens
          // already use for their own buttons.
          if (!_open && widget.showFloatingMic)
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.bottomInset,
              child: Center(
                child: VoiceMicButton(accent: widget.accent, onTap: _openPanel),
              ),
            ),
        ],
      ),
    );
  }
}

/// The resting microphone button.
class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton({
    super.key,
    required this.accent,
    required this.onTap,
    this.diameter = VoiceNavHost.micDiameter,
    this.iconSize = 32,
    this.elevation = 6,
    this.borderWidth = 0,
    this.borderColor = Colors.white,
  });

  final Color accent;
  final VoidCallback onTap;
  final double diameter;
  final double iconSize;
  final double elevation;
  final double borderWidth;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.voiceNavButton,
      child: Tooltip(
        message: l.voiceNavButton,
        child: Material(
          color: accent,
          shape: CircleBorder(
            side: borderWidth > 0
                ? BorderSide(color: borderColor, width: borderWidth)
                : BorderSide.none,
          ),
          elevation: elevation,
          shadowColor: accent.withValues(alpha: 0.45),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            // comfortably above the 48 px minimum, because a hand that
            // has lost fine control is the design case here.
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Icon(Icons.mic_rounded, color: Colors.white, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// The listening panel: a scrim, the question, and the live transcript.
///
/// Deliberately one thing at a time. A list of destinations here would turn a
/// spoken request into a reading task, which is the opposite of the point —
/// the person is meant to answer the question, not scan a menu. Anyone who
/// would rather tap still has the bottom navigation bar, visible below the
/// panel the whole time.
class _VoicePanel extends StatelessWidget {
  const _VoicePanel({
    required this.controller,
    required this.accent,
    required this.onClose,
  });

  final VoiceNavigationController controller;
  final Color accent;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final VoicePhase phase = controller.phase;
        final String heard = controller.recognizedText.trim();
        final String status = controller.status.trim();

        // The question stays put while Mitra asks it, while she listens, and
        // while she thinks — it is the thing being answered, so it should not
        // slide away the moment the person opens their mouth. Only an outcome
        // or a failure replaces it.
        final String headline = switch (phase) {
          VoicePhase.error => controller.error?.message ?? l.voiceErrorUnknown,
          VoicePhase.idle => status.isEmpty ? l.voiceNavTitle : status,
          _ => l.voiceNavTitle,
        };

        // Underneath, what is happening right now: the words as they arrive,
        // or the state when there are none yet.
        final String subline = heard.isNotEmpty
            ? '"$heard"'
            : switch (phase) {
                VoicePhase.requestingPermission => l.voiceOneMoment,
                VoicePhase.speaking => l.voiceSpeaking,
                VoicePhase.listening => l.voiceListening,
                VoicePhase.thinking => l.voiceThinking,
                _ => l.voiceNavHint,
              };

        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
              ),
            ),
            Positioned(
              left: Insets.md,
              right: Insets.md,
              bottom: Insets.md,
              child: Material(
                color: Colors.white,
                elevation: 12,
                borderRadius: Corners.r(Corners.lg),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _PulsingMic(active: phase == VoicePhase.listening, accent: accent),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(headline, style: AppText.h3),
                                const SizedBox(height: 2),
                                Text(
                                  subline,
                                  style: AppText.bodySmall.tint(
                                    heard.isEmpty ? AppColors.inkMuted : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            iconSize: 28,
                            tooltip: l.actionClose,
                            icon: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                      // The language actually being spoken differs from the one
                      // asked for often enough — Assamese is rarely installed —
                      // that saying so is the difference between "broken" and
                      // "doing its best".
                      if (controller.resolvedInputLanguage?.isFallback ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: Insets.sm),
                          child: Text(
                            l.voiceLanguageFallback(
                              _languageName(l, controller.resolvedInputLanguage!.requested),
                              _languageName(l, controller.resolvedInputLanguage!.resolved!),
                            ),
                            style: AppText.caption.tint(AppColors.warning),
                          ),
                        ),
                      const SizedBox(height: Insets.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: Insets.md),
                          ),
                          // Listening ends the turn early — it is no longer
                          // required, since a pause ends it by itself, but
                          // someone who wants to be done *now* should be able
                          // to say so. Speaking cuts Mitra off rather than
                          // being dead, because a companion you cannot
                          // interrupt stops feeling like one.
                          onPressed: switch (phase) {
                            VoicePhase.listening => controller.stopListening,
                            VoicePhase.speaking => controller.interrupt,
                            VoicePhase.thinking ||
                            VoicePhase.requestingPermission =>
                              null,
                            _ => controller.start,
                          },
                          icon: Icon(phase == VoicePhase.listening
                              ? Icons.stop_rounded
                              : Icons.mic_rounded),
                          label: Text(
                            switch (phase) {
                              VoicePhase.listening => l.voiceIHaveFinished,
                              VoicePhase.speaking => l.voiceNavSpeakNow,
                              _ => l.voiceSayItAgain,
                            },
                            style: AppText.body.wght(700).tint(Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _languageName(AppLocalizations l, VoiceLanguage v) => switch (v) {
        VoiceLanguage.english => l.languageEnglish,
        VoiceLanguage.hindi => l.languageHindi,
        VoiceLanguage.assamese => l.languageAssamese,
      };
}

/// A microphone that breathes while the device is listening — the one signal
/// that says "I am still hearing you" without any words to read.
class _PulsingMic extends StatefulWidget {
  const _PulsingMic({required this.active, required this.accent});

  final bool active;
  final Color accent;

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingMic old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        final double t = _pulse.value;
        return Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.12 + 0.10 * t),
            shape: BoxShape.circle,
            boxShadow: widget.active
                ? <BoxShadow>[
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.28 * (1 - t)),
                      blurRadius: 4 + 14 * t,
                      spreadRadius: 2 + 6 * t,
                    ),
                  ]
                : null,
          ),
          child: Icon(Icons.mic_rounded, color: widget.accent, size: 28),
        );
      },
    );
  }
}
