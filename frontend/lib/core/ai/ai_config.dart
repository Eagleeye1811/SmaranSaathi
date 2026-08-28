import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// How the AI layer is pointed at a provider.
///
/// Values come from `frontend/.env` (loaded once in `main.dart`, gitignored,
/// nothing hard-coded or committed) so a plain `flutter run` just works with
/// no launch script or manual flag. `--dart-define` still works too and wins
/// if both are set — useful for CI or a release build that shouldn't bundle
/// `.env` at all.
///
/// ```bash
/// # frontend/.env (copy from .env.example):
/// GEMINI_API_KEY=...
///
/// # Production: talk to our own backend, which holds the key.
/// flutter run --dart-define=AI_PROXY_URL=https://api.example.org/ai
/// ```
///
/// **On shipping a key in the app:** an API key bundled into a mobile binary
/// or a web bundle can be extracted by anyone who installs it. Direct mode is
/// for development and the SIH demo. For anything public, set [proxyUrl] and
/// let the FastAPI service hold the key — [usesProxy] then reports which mode
/// a build is in.
@immutable
class AiConfig {
  const AiConfig({
    this.apiKey = '',
    this.proxyUrl = '',
    this.model = 'gemini-3.5-flash-lite',
    this.timeout = const Duration(seconds: 20),
    this.redactPatientIdentity = false,
    this.maxOutputTokens = 800,
  });

  /// Reads the ambient build configuration: `--dart-define` first, falling
  /// back to whatever `main.dart` loaded from `.env`.
  factory AiConfig.fromEnvironment() {
    const String defineKey = String.fromEnvironment('GEMINI_API_KEY');
    const String defineProxy = String.fromEnvironment('AI_PROXY_URL');
    const String defineModel = String.fromEnvironment('GEMINI_MODEL');
    const String defineSeconds = String.fromEnvironment('AI_TIMEOUT_SECONDS');
    const bool defineRedact = bool.fromEnvironment('AI_REDACT_IDENTITY');

    // `dotenv.env` throws until `main.dart`'s `dotenv.load()` has actually
    // run — never, in a plain `flutter test` — so this only reads it once
    // that has genuinely happened.
    String fromDotenv(String dotenvKey) =>
        dotenv.isInitialized ? (dotenv.env[dotenvKey]?.trim() ?? '') : '';

    String envOr(String defineValue, String dotenvKey) =>
        defineValue.isNotEmpty ? defineValue : fromDotenv(dotenvKey);

    final String key = envOr(defineKey, 'GEMINI_API_KEY');
    final String proxy = envOr(defineProxy, 'AI_PROXY_URL');
    final String model = envOr(defineModel, 'GEMINI_MODEL');
    final String secondsRaw = envOr(defineSeconds, 'AI_TIMEOUT_SECONDS');
    final bool redact = defineRedact || fromDotenv('AI_REDACT_IDENTITY').toLowerCase() == 'true';

    return AiConfig(
      apiKey: key,
      proxyUrl: proxy,
      model: model.isEmpty ? 'gemini-3.5-flash-lite' : model,
      timeout: Duration(seconds: int.tryParse(secondsRaw) ?? 20),
      redactPatientIdentity: redact,
    );
  }

  final String apiKey;

  /// When set, requests go here instead of to Google, and no key ships in the
  /// app. The backend is expected to expose the same request shape.
  final String proxyUrl;

  /// Google retires model names outright (a pinned `gemini-2.0-flash` once
  /// started 404ing with "no longer available"), so this needs an occasional
  /// check against `GET /v1beta/models` rather than being trusted forever.
  /// A "thinking" model (e.g. `gemini-3.6-flash`) is deliberately avoided
  /// here: its hidden reasoning tokens count against `maxOutputTokens` and
  /// were observed truncating short replies mid-JSON, and its free-tier
  /// quota (5 requests/minute, observed) is too tight for a live
  /// conversation. A `-lite` model has neither problem and is plenty for a
  /// short, structured companion reply.
  final String model;
  final Duration timeout;

  /// Strips the patient's name and personal details from anything sent to a
  /// model provider. Insights stay useful; they just stop being identifying.
  final bool redactPatientIdentity;

  final int maxOutputTokens;

  bool get usesProxy => proxyUrl.isNotEmpty;

  /// Whether this build can reach a model at all.
  bool get isConfigured => usesProxy || apiKey.isNotEmpty;

  /// The endpoint for a single-turn generation call.
  Uri endpoint() {
    if (usesProxy) return Uri.parse(proxyUrl);
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
  }

  /// Headers for a request. The key travels in a header, never in the URL, so
  /// it cannot leak through logs or proxy access records.
  Map<String, String> headers() => <String, String>{
        'Content-Type': 'application/json',
        if (!usesProxy && apiKey.isNotEmpty) 'x-goog-api-key': apiKey,
      };

  AiConfig copyWith({
    String? apiKey,
    String? proxyUrl,
    String? model,
    Duration? timeout,
    bool? redactPatientIdentity,
  }) =>
      AiConfig(
        apiKey: apiKey ?? this.apiKey,
        proxyUrl: proxyUrl ?? this.proxyUrl,
        model: model ?? this.model,
        timeout: timeout ?? this.timeout,
        redactPatientIdentity: redactPatientIdentity ?? this.redactPatientIdentity,
        maxOutputTokens: maxOutputTokens,
      );

  @override
  String toString() =>
      'AiConfig(model: $model, mode: ${usesProxy ? 'proxy' : 'direct'}, '
      'configured: $isConfigured)';
}
