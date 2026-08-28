import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/local/sync_operation.dart';
import 'sync_manager.dart';

/// Sends the outbox to the real MemoryMitra backend (`backend/app/api/v1/sync.py`).
///
/// Maps a [PendingOperation] 1:1 onto the backend's `SyncOperationRequest`
/// (`operationId`, `kind`, `payload`, `createdAtMillis`) — the payload map is
/// forwarded as-is, since it was already built to match the backend's
/// per-kind schemas when it was enqueued in `AppState`.
///
/// Auth is a lightweight device token (`POST /api/v1/auth/device`), not
/// Firebase Auth — the app has no login UI, so this proves "a copy of
/// MemoryMitra is calling", not "this is a specific person". The token is
/// minted once, cached in memory, and re-minted on a 401 (e.g. after the
/// token's 30-day expiry). See `backend/app/core/device_auth.py`.
///
/// Per [SyncTransport]'s contract: returns normally on success (including a
/// server-reported "duplicate" — the operation already reached the backend on
/// a previous attempt, which is success from the queue's point of view), and
/// throws on any failure so the operation stays queued and is retried.
class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  String? _deviceToken;

  Future<String> _fetchDeviceToken() async {
    final http.Response response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/device'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(const <String, dynamic>{}),
    );
    if (response.statusCode != 200) {
      throw StateError('Device token request failed (${response.statusCode}): ${response.body}');
    }
    final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
    final String token = body['token'] as String;
    _deviceToken = token;
    return token;
  }

  Future<http.Response> _postOperation(PendingOperation operation, String token) {
    return _client.post(
      Uri.parse('$_baseUrl/api/v1/sync/operations'),
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
    );
  }

  @override
  Future<void> send(PendingOperation operation) async {
    final String token = _deviceToken ?? await _fetchDeviceToken();
    http.Response response = await _postOperation(operation, token);

    if (response.statusCode == 401) {
      // Token missing/expired server-side — mint a fresh one and retry once
      // within this same call. A second 401 is a real failure, not a token
      // problem, so it falls through to the throw below.
      final String freshToken = await _fetchDeviceToken();
      response = await _postOperation(operation, freshToken);
    }

    if (response.statusCode >= 400) {
      throw StateError('Sync failed (${response.statusCode}) for ${operation.kind.name}: ${response.body}');
    }
    // 200 covers both {"status": "synced"} and {"status": "duplicate"} —
    // both mean the backend now has this operation, which is all the queue
    // cares about.
  }
}
