import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ai_models.dart';
import '../ai_transport.dart';

/// `dart:io` transport — Android, iOS, macOS, Windows, Linux.
///
/// Uses the SDK's own client so the AI layer adds no package dependency.
AiTransport createTransport() => IoAiTransport();

class IoAiTransport implements AiTransport {
  IoAiTransport({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<AiResult<String>> postJson(
    Uri url, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  }) async {
    _client.connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await _client.postUrl(url).timeout(timeout);
      headers.forEach(request.headers.set);
      request.add(utf8.encode(body));

      final HttpClientResponse response = await request.close().timeout(timeout);
      final String payload =
          await response.transform(utf8.decoder).join().timeout(timeout);

      return switch (response.statusCode) {
        >= 200 && < 300 => payload.trim().isEmpty
            ? AiError<String>.of(AiErrorKind.empty, detail: 'empty 2xx body')
            : AiSuccess<String>(payload),
        401 || 403 => AiError<String>.of(AiErrorKind.unauthorized,
            detail: 'HTTP ${response.statusCode}'),
        429 => AiError<String>.of(AiErrorKind.rateLimited, detail: 'HTTP 429'),
        >= 500 => AiError<String>.of(AiErrorKind.server,
            detail: 'HTTP ${response.statusCode}'),
        _ => AiError<String>.of(AiErrorKind.server,
            detail: 'HTTP ${response.statusCode}: ${_snippet(payload)}'),
      };
    } on TimeoutException {
      return AiError<String>.of(AiErrorKind.timeout,
          detail: 'no response within ${timeout.inSeconds}s');
    } on SocketException catch (e) {
      // DNS failure or no route — the device is effectively offline.
      return AiError<String>.of(AiErrorKind.offline, detail: e.message);
    } on HandshakeException catch (e) {
      return AiError<String>.of(AiErrorKind.server, detail: 'TLS: ${e.message}');
    } on HttpException catch (e) {
      return AiError<String>.of(AiErrorKind.server, detail: e.message);
    } catch (e) {
      return AiError<String>.of(AiErrorKind.unknown, detail: e.toString());
    }
  }

  /// Keeps provider error bodies out of logs at full length.
  static String _snippet(String s) => s.length <= 200 ? s : '${s.substring(0, 200)}…';

  @override
  void close() => _client.close(force: true);
}
