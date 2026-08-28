import 'package:flutter/foundation.dart';

import 'ai_models.dart';
import 'transport/transport_stub.dart'
    if (dart.library.io) 'transport/transport_io.dart' as impl;

/// One HTTP POST, abstracted so the AI layer has no platform dependency and
/// tests can answer without a network.
abstract class AiTransport {
  /// Returns the response body on 2xx, or an [AiFailure] for anything else.
  Future<AiResult<String>> postJson(
    Uri url, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  });

  void close();
}

/// The transport for the current platform.
///
/// The project carries no HTTP package — adding one would mean touching
/// `pubspec.yaml` — so this uses `dart:io`'s own client, which covers Android,
/// iOS, macOS, Windows and Linux with no dependency at all.
///
/// On the web there is no `dart:io`, and the stub reports
/// [AiErrorKind.unsupportedPlatform]. That is the correct behaviour rather
/// than a gap: a web build must not carry an API key in its bundle, so a web
/// deployment should set `AI_PROXY_URL` and reach the model through the
/// backend. Until that exists, web falls back to the on-device service.
AiTransport createAiTransport() => impl.createTransport();

/// A transport that answers from a script. Used by tests.
@visibleForTesting
class FakeAiTransport implements AiTransport {
  FakeAiTransport(this.responder);

  /// Called with the request body; returns whatever the model would have.
  final Future<AiResult<String>> Function(String body) responder;

  final List<String> requests = <String>[];
  bool closed = false;

  @override
  Future<AiResult<String>> postJson(
    Uri url, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  }) async {
    requests.add(body);
    return responder(body);
  }

  @override
  void close() => closed = true;
}
