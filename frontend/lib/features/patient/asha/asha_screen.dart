import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';

// ── Active D-ID agent configuration ──────────────────────────────────────────
const String _kClientKey = 'ck_0W8bbtkFlj3aeiJ3iQJDi';
const String _kAgentId = 'v2_agt_eJTwq3XQ';

String _buildAshaHtml(String clientKey, String agentId) => '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Asha - SmaranSaathi</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
            width: 100%;
            height: 100%;
            overflow: hidden;
            background: #0d1117;
        }
        body { position: relative; font-family: Arial, sans-serif; }
    </style>
</head>
<body>
    <script type="module"
      src="https://agent.d-id.com/v2/index.js"
      data-mode="fabio"
      data-client-key="$clientKey"
      data-agent-id="$agentId"
      data-name="did-agent"
      data-monitor="true"
      data-orientation="horizontal"
      data-position="right"
      data-open-mode="expanded">
    </script>
</body>
</html>
''';

/// JavaScript and CSS injected into the D-ID page to:
/// 1. Hide the collapsed corner bubble visually from the patient while keeping it clickable.
/// 2. Make the D-ID avatar occupy 100% of the screen width and height from the start.
/// 3. Programmatically invoke D-ID's setWidgetOpen API to expand full screen.
/// 4. Automatically trigger "Start Conversation" so the user talks directly to Asha.
/// 5. Automatically dismiss/allow in-page mic permission prompts.
const String _kFullscreenAndAutoStartScript = r'''
(function () {
  // 1. Inject styling to force full screen and hide the collapsed bubble
  var style = document.createElement('style');
  style.id = 'asha-fullscreen-style';
  style.innerHTML = `
    html, body {
      width: 100% !important;
      height: 100% !important;
      margin: 0 !important;
      padding: 0 !important;
      overflow: hidden !important;
      background: #0d1117 !important;
    }
    /* Hide the floating button visually so it never flashes small, but allow clicks */
    .didagent__fabio > button {
      opacity: 0.001 !important;
      transform: scale(0.01) !important;
      position: fixed !important;
      bottom: -100px !important;
      right: -100px !important;
      pointer-events: auto !important;
    }
    .didagent__fabio__notification {
      display: none !important;
    }
    /* Make the fabio wrapper fill the entire viewport */
    .didagent__fabio {
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      max-width: 100vw !important;
      max-height: 100vh !important;
      z-index: 99999 !important;
    }
    /* Make the container full-bleed */
    .didagent__fabio .didagent__fabio__container,
    .didagent__fabio__container {
      display: flex !important;
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      max-width: 100vw !important;
      max-height: 100vh !important;
      bottom: 0 !important;
      right: 0 !important;
      border-radius: 0 !important;
      z-index: 100000 !important;
      opacity: 1 !important;
      pointer-events: auto !important;
    }
    /* Scale video / image avatar to cover full screen */
    .didagent__embedded__container,
    .didagent__main__wrapper,
    .didagent__main__container,
    .didagent__embedded__video__container,
    .didagent__embedded__video__container video,
    .didagent__embedded__video__container img,
    .didagent__video__skeleton {
      width: 100% !important;
      height: 100% !important;
      max-width: 100vw !important;
      max-height: 100vh !important;
      object-fit: cover !important;
    }
  `;
  document.head.appendChild(style);

  var attempts = 0;
  var maxAttempts = 30; // 30 * 250ms = 7.5s

  var pollTimer = setInterval(function () {
    attempts++;

    // Step A: Programmatically open using official D-ID SDK functions
    try {
      if (window.DID_AGENTS_API && window.DID_AGENTS_API.functions) {
        if (typeof window.DID_AGENTS_API.functions.setWidgetOpen === 'function') {
          window.DID_AGENTS_API.functions.setWidgetOpen(true);
        }
      }
    } catch (e) {}

    // Step B: Synthetic click on Fabio expand button if present
    var fabBtn = document.querySelector('[data-testid="didagent__fabio__button"]')
              || document.querySelector('.didagent__fabio button')
              || document.querySelector('button[aria-label*="video chat"]');
    if (fabBtn) {
      fabBtn.click();
    }

    // Step C: Auto-start conversation so it immediately connects
    var startBtn = document.querySelector('.didagent__start__conversation__button')
                || document.querySelector('[data-testid="send_record"]')
                || document.querySelector('.didagent__intro__button__primary');
    if (startBtn && !startBtn.disabled) {
      startBtn.click();
    }

    // Step D: Auto-allow mic permissions if in-page modal appears
    var vmBtn = document.querySelector('.didagent__vm__permission__button');
    if (vmBtn) {
      vmBtn.click();
    }
    var buttons = document.querySelectorAll('button');
    for (var i = 0; i < buttons.length; i++) {
      var txt = (buttons[i].textContent || '').trim().toLowerCase();
      if (txt === 'understood' || txt === 'turn microphone on' || txt === 'allow microphone') {
        buttons[i].click();
      }
    }

    // Step E: Check if container is expanded and notify Flutter
    var fabContainer = document.querySelector('.didagent__fabio__container');
    if (fabContainer && fabContainer.getAttribute('data-enabled') === 'true') {
      try {
        if (window.AshaChannel) {
          window.AshaChannel.postMessage('ready');
        }
      } catch (e) {}
    }

    if (attempts >= maxAttempts) {
      clearInterval(pollTimer);
    }
  }, 250);
})();
''';

/// The Asha conversational-avatar screen.
///
/// Architecture:
///   Flutter  →  WebView  →  Vercel D-ID page  →  D-ID Asha agent
class AshaScreen extends StatefulWidget {
  const AshaScreen({
    super.key,
    this.embedded = false,
    this.active = true,
  });

  /// True when hosted inside PatientShell's IndexedStack (bottom-nav tab).
  /// The app bar is suppressed so the avatar fills the full screen.
  final bool embedded;

  /// Whether this tab is currently the active selected tab.
  /// When false, the WebRTC stream is paused/unloaded to conserve credits
  /// and avoid battery drain and SurfaceView destruction in the background.
  final bool active;

  @override
  State<AshaScreen> createState() => _AshaScreenState();
}

enum _ViewState {
  idle,
  checkingPermission,
  loading,
  ready,
  error,
  permissionDenied,
  permissionPermanentlyDenied,
}

class _AshaScreenState extends State<AshaScreen> {
  WebViewController? _controller;
  _ViewState _state = _ViewState.idle;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _requestPermissionAndLoad();
    }
  }

  @override
  void didUpdateWidget(AshaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      // Switched to Asha tab: initialize or reload session
      if (_controller == null || _state == _ViewState.idle) {
        _requestPermissionAndLoad();
      } else {
        setState(() => _state = _ViewState.loading);
        _controller?.loadHtmlString(
          _buildAshaHtml(_kClientKey, _kAgentId),
          baseUrl: 'https://agent.d-id.com/',
        );
      }
    } else if (oldWidget.active && !widget.active) {
      // Switched away from Asha tab: gracefully stop WebRTC tracks to prevent Qualcomm HW decoder crash
      _stopStreamAndUnload();
      setState(() => _state = _ViewState.idle);
    }
  }

  // ── Permission ──────────────────────────────────────────────────────────────

  Future<void> _requestPermissionAndLoad() async {
    setState(() => _state = _ViewState.checkingPermission);
    final PermissionStatus mic = await Permission.microphone.request();
    if (!mounted) return;

    if (mic.isPermanentlyDenied) {
      setState(() => _state = _ViewState.permissionPermanentlyDenied);
      return;
    }
    if (mic.isDenied) {
      setState(() => _state = _ViewState.permissionDenied);
      return;
    }

    _buildController();
    setState(() => _state = _ViewState.loading);
  }

  // ── WebView ─────────────────────────────────────────────────────────────────

  void _buildController() {
    final WebViewController c = WebViewController();

    // Android specific: grant WebRTC/microphone permissions to web content
    // and disable user gesture requirement so audio/video streams play automatically.
    if (c.platform is AndroidWebViewController) {
      final AndroidWebViewController androidController =
          c.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnPlatformPermissionRequest(
        (PlatformWebViewPermissionRequest request) => request.grant(),
      );
    }

    c
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; SM-A546E) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'AshaChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'ready' && mounted) {
            setState(() => _state = _ViewState.ready);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            // Expand and auto-start the D-ID agent full screen.
            await c.runJavaScript(_kFullscreenAndAutoStartScript);

            // Safety fallback: reveal avatar after 1s so loading is not stuck
            Future<void>.delayed(const Duration(milliseconds: 1000), () {
              if (mounted && _state == _ViewState.loading) {
                setState(() => _state = _ViewState.ready);
              }
            });
          },
          onWebResourceError: (WebResourceError err) {
            debugPrint('[Asha] WebView error: ${err.description} (isForMainFrame: ${err.isForMainFrame})');
            if (mounted && _state != _ViewState.ready && (err.isForMainFrame ?? true)) {
              setState(() => _state = _ViewState.error);
            }
          },
        ),
      )
      ..loadHtmlString(
        _buildAshaHtml(_kClientKey, _kAgentId),
        baseUrl: 'https://agent.d-id.com/',
      );

    setState(() => _controller = c);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // No app bar when embedded as a nav tab — the PatientShell top bar
      // already provides identity. When pushed as a standalone screen the
      // back-button bar lets the patient navigate back.
      appBar: widget.embedded ? null : _AshaAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      _ViewState.idle => _LoadingBody(),
      _ViewState.checkingPermission => _LoadingBody(),

      // Show the WebView behind the loading overlay so the transition is
      // seamless: as soon as the page fires onPageFinished the overlay
      // disappears and the avatar is already rendered.
      _ViewState.loading => Stack(
          children: <Widget>[
            if (_controller != null) WebViewWidget(controller: _controller!),
            _LoadingBody(),
          ],
        ),

      // Full-screen avatar — nothing else.
      _ViewState.ready => WebViewWidget(controller: _controller!),

      _ViewState.error => _ErrorView(onRetry: _retry),

      _ViewState.permissionDenied => _MicPermissionView(
          permanent: false,
          onRetry: _requestPermissionAndLoad,
        ),

      _ViewState.permissionPermanentlyDenied => _MicPermissionView(
          permanent: true,
          onRetry: () => openAppSettings(),
        ),
    };
  }

  void _retry() {
    setState(() {
      _state = _ViewState.loading;
      _controller = null;
    });
    _buildController();
  }

  Future<void> _stopStreamAndUnload() async {
    if (_controller == null) return;
    try {
      await _controller?.runJavaScript(r'''
        (function() {
          try {
            if (window.DID_AGENTS_API && window.DID_AGENTS_API.functions && typeof window.DID_AGENTS_API.functions.close === 'function') {
              window.DID_AGENTS_API.functions.close();
            }
          } catch(e) {}
          var videos = document.querySelectorAll('video');
          videos.forEach(function(v) {
            v.pause();
            if (v.srcObject && typeof v.srcObject.getTracks === 'function') {
              v.srcObject.getTracks().forEach(function(t) { t.stop(); });
            }
          });
        })();
      ''');
    } catch (_) {}
    await _controller?.loadHtmlString('<!DOCTYPE html><html><body></body></html>');
  }

  @override
  void dispose() {
    // Gracefully stop WebRTC media tracks and unload without tearing down EGL context abruptly
    _stopStreamAndUnload();
    super.dispose();
  }
}

// ── App bar (standalone push only) ───────────────────────────────────────────

class _AshaAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          color: AppColors.ink,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Asha', style: AppText.h2.copyWith(color: AppColors.ink)),
          Text(
            'Your friendly companion',
            style: AppText.caption.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.hairline),
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Asha is getting ready\u2026',
              style: AppText.body.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.inkMuted),
            const SizedBox(height: 24),
            Text(
              "Asha couldn\u2019t connect right now.\nPlease try again.",
              textAlign: TextAlign.center,
              style: AppText.h3.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 32),
            _LargeButton(
              label: 'Try Again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Microphone permission ─────────────────────────────────────────────────────

class _MicPermissionView extends StatelessWidget {
  const _MicPermissionView({required this.permanent, required this.onRetry});
  final bool permanent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.mic_off_rounded, size: 64, color: AppColors.inkMuted),
            const SizedBox(height: 24),
            Text(
              'Asha needs access to your microphone so she can hear you.',
              textAlign: TextAlign.center,
              style: AppText.h3.copyWith(color: AppColors.ink),
            ),
            if (permanent) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'Please open Settings and allow microphone access for SmaranSaathi.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.inkSoft),
              ),
            ],
            const SizedBox(height: 32),
            _LargeButton(
              label: permanent ? 'Open Settings' : 'Allow Microphone',
              icon: permanent ? Icons.settings_rounded : Icons.mic_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Button ────────────────────────────────────────────────────────────────────

class _LargeButton extends StatelessWidget {
  const _LargeButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        icon: Icon(icon, size: 26),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
