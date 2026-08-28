import 'package:flutter/foundation.dart';

/// How the AI layer is pointed at a provider.
///
/// Values come from `--dart-define`, matching the convention the app already
/// uses for `MM_START`. Nothing is hard-coded and no key is committed.
///
/// ```bash
/// # Development: talk to Gemini directly from the device.
/// flutter run --dart-define=GEMINI_API_KEY=...
///
/// # Production: talk to our own backend, which holds the key.
/// flutter run --dart-define=AI_PROXY_URL=https://api.example.org/ai
/// ```
///
/// **On shipping a key in the app:** an API key compiled into a mobile binary
/// or a web bundle can be extracted by anyone who installs it. Direct mode is
/// for development and the SIH demo. For anything public, set [proxyUrl] and
/// let the FastAPI service hold the key — [usesProxy] then reports which mode
/// a build is in.
@immutable
class AiConfig {
  const AiConfig({
    this.apiKey = '',
    this.proxyUrl = '',
    this.model = 'gemini-2.0-flash',
    this.timeout = const Duration(seconds: 20),
    this.redactPatientIdentity = false,
    this.maxOutputTokens = 800,
  });

  /// Reads the ambient build configuration.
  factory AiConfig.fromEnvironment() {
    const String key = String.fromEnvironment('GEMINI_API_KEY');
    const String proxy = String.fromEnvironment('AI_PROXY_URL');
    const String model =
        String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-2.0-flash');
    const int seconds = int.fromEnvironment('AI_TIMEOUT_SECONDS', defaultValue: 20);
    const bool redact = bool.fromEnvironment('AI_REDACT_IDENTITY');
    return AiConfig(
      apiKey: key,
      proxyUrl: proxy,
      model: model,
      timeout: Duration(seconds: seconds),
      redactPatientIdentity: redact,
    );
  }

  final String apiKey;

  /// When set, requests go here instead of to Google, and no key ships in the
  /// app. The backend is expected to expose the same request shape.
  final String proxyUrl;

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
