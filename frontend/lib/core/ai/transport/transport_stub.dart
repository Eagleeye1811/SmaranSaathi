import '../ai_models.dart';
import '../ai_transport.dart';

/// Platforms with no `dart:io` — the web.
///
/// See the note on [createAiTransport]: a web build should reach the model
/// through the backend proxy rather than carrying a key, so failing clearly
/// here is deliberate. Callers fall back to the on-device service.
AiTransport createTransport() => const _UnsupportedTransport();

class _UnsupportedTransport implements AiTransport {
  const _UnsupportedTransport();

  @override
  Future<AiResult<String>> postJson(
    Uri url, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  }) async =>
      AiError<String>.of(
        AiErrorKind.unsupportedPlatform,
        detail: 'No dart:io on this platform; configure AI_PROXY_URL and a web transport.',
      );

  @override
  void close() {}
}
