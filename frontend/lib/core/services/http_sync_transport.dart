import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/local/sync_operation.dart';
import 'sync_manager.dart';

/// Sends the outbox to the real SmaranSaathi backend (`backend/app/api/v1/sync.py`).
///
/// Maps a [PendingOperation] 1:1 onto the backend's `SyncOperationRequest`
/// (`operationId`, `kind`, `payload`, `createdAtMillis`) — the payload map is
/// forwarded as-is, since it was already built to match the backend's
/// per-kind schemas when it was enqueued in `AppState`.
///
/// Auth is a lightweight device token (`POST /api/v1/auth/device`), not
/// Firebase Auth — the app has no login UI, so this proves "a copy of
/// SmaranSaathi is calling", not "this is a specific person". The token is
/// minted once, cached in memory, and re-minted on a 401 (e.g. after the
/// token's 30-day expiry). See `backend/app/core/device_auth.py`.
///
/// Per [SyncTransport]'s contract: returns normally on success (including a
/// server-reported "duplicate" — the operation already reached the backend on
/// a previous attempt, which is success from the queue's point of view), and
/// throws on any failure so the operation stays queued and is retried.
class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport({required String baseUrl, http.Client? client})
      : _initialBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client() {
    _activeBaseUrl = _initialBaseUrl;
  }

  final String _initialBaseUrl;
  final http.Client _client;
  late String _activeBaseUrl;
  String? _deviceToken;

  /// Returns the current active base URL used for server sync.
  String get activeBaseUrl => _activeBaseUrl;

  List<String> get _candidateUrls {
    final List<String> list = <String>[];
    if (_activeBaseUrl.isNotEmpty) list.add(_activeBaseUrl);
    if (!list.contains('http://127.0.0.1:8000')) list.add('http://127.0.0.1:8000');
    if (!list.contains('http://localhost:8000')) list.add('http://localhost:8000');
    if (!list.contains('http://10.0.2.2:8000')) list.add('http://10.0.2.2:8000');
    return list;
  }

  Future<String> _fetchDeviceToken() async {
    Object? lastException;
    for (final String url in _candidateUrls) {
      try {
        final http.Response response = await _client.post(
          Uri.parse('$url/api/v1/auth/device'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(const <String, dynamic>{}),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
          _activeBaseUrl = url;
          final String token = body['token'] as String;
          _deviceToken = token;
          return token;
        }
      } catch (e) {
        lastException = e;
      }
    }
    throw StateError('Cannot reach backend server. Error: $lastException');
  }

  Future<http.Response> _postOperation(PendingOperation operation, String token) {
    return _client.post(
      Uri.parse('$_activeBaseUrl/api/v1/sync/operations'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'operationId': operation.id,
        'kind': operation.kind.name,
        'payload': operation.payload,
        'createdAtMillis': operation.createdAtMillis,
      }),
    ).timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> send(PendingOperation operation) async {
    final String token = _deviceToken ?? await _fetchDeviceToken();
    http.Response response;
    try {
      response = await _postOperation(operation, token);
    } catch (_) {
      // Base URL might have changed or failed — re-fetch token with candidate search
      final String freshToken = await _fetchDeviceToken();
      response = await _postOperation(operation, freshToken);
    }

    if (response.statusCode == 401) {
      final String freshToken = await _fetchDeviceToken();
      response = await _postOperation(operation, freshToken);
    }

    if (response.statusCode >= 400) {
      throw StateError('Sync failed (${response.statusCode}) for ${operation.kind.name}: ${response.body}');
    }
  }

  /// Direct trigger for instant test SMS verification
  Future<({bool sent, String reason})> sendTestSms(String phoneNumber) async {
    final String token = _deviceToken ?? await _fetchDeviceToken();
    final Uri uri = Uri.parse('$_activeBaseUrl/api/v1/health/test-sms').replace(
      queryParameters: <String, String>{'to': phoneNumber},
    );
    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        sent: body['sent'] as bool? ?? false,
        reason: body['reason'] as String? ?? '',
      );
    }
    return (sent: false, reason: 'HTTP ${response.statusCode}');
  }
}
