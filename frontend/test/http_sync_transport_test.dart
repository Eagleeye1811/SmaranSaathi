import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:smaran_saathi/core/services/http_sync_transport.dart';
import 'package:smaran_saathi/data/local/sync_operation.dart';

PendingOperation _operation({String id = 'op-1'}) => PendingOperation(
      id: id,
      kind: SyncOperationKind.moodCheckIn,
      payload: const <String, dynamic>{'patientId': 'p1', 'mood': 'good', 'at': '9:00 AM'},
      createdAtMillis: 1000,
    );

void main() {
  test('mints a device token then posts the operation with the right shape', () async {
    final List<http.Request> requests = <http.Request>[];

    final MockClient client = MockClient((http.Request request) async {
      requests.add(request);
      if (request.url.path.endsWith('/auth/device')) {
        return http.Response(jsonEncode(<String, dynamic>{
          'deviceId': 'device-1',
          'token': 'test-token',
          'expiresAtMillis': 9999999999999,
        }), 200);
      }
      if (request.url.path.endsWith('/sync/operations')) {
        return http.Response(jsonEncode(<String, dynamic>{
          'operationId': jsonDecode(request.body)['operationId'],
          'status': 'synced',
          'syncedAtMillis': 1234,
        }), 200);
      }
      return http.Response('not found', 404);
    });

    final HttpSyncTransport transport = HttpSyncTransport(baseUrl: 'http://localhost:8000', client: client);
    await transport.send(_operation());

    expect(requests, hasLength(2));
    expect(requests[0].url.path, '/api/v1/auth/device');
    expect(requests[1].url.path, '/api/v1/sync/operations');
    expect(requests[1].headers['Authorization'], 'Bearer test-token');

    final Map<String, dynamic> body = jsonDecode(requests[1].body) as Map<String, dynamic>;
    expect(body['operationId'], 'op-1');
    expect(body['kind'], 'moodCheckIn');
    expect(body['payload'], <String, dynamic>{'patientId': 'p1', 'mood': 'good', 'at': '9:00 AM'});
    expect(body['createdAtMillis'], 1000);
  });

  test('reuses the cached device token across sends', () async {
    int deviceTokenCalls = 0;

    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/auth/device')) {
        deviceTokenCalls += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{'deviceId': 'd1', 'token': 't1', 'expiresAtMillis': 9999999999999}),
          200,
        );
      }
      return http.Response(jsonEncode(<String, dynamic>{'status': 'synced'}), 200);
    });

    final HttpSyncTransport transport = HttpSyncTransport(baseUrl: 'http://localhost:8000', client: client);
    await transport.send(_operation(id: 'op-1'));
    await transport.send(_operation(id: 'op-2'));

    expect(deviceTokenCalls, 1);
  });

  test('a 401 mints a fresh token and retries once', () async {
    int deviceTokenCalls = 0;
    int syncCalls = 0;

    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/auth/device')) {
        deviceTokenCalls += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{'deviceId': 'd1', 'token': 'token-$deviceTokenCalls', 'expiresAtMillis': 9999999999999}),
          200,
        );
      }
      syncCalls += 1;
      if (syncCalls == 1) {
        return http.Response('expired', 401);
      }
      return http.Response(jsonEncode(<String, dynamic>{'status': 'synced'}), 200);
    });

    final HttpSyncTransport transport = HttpSyncTransport(baseUrl: 'http://localhost:8000', client: client);
    await transport.send(_operation());

    expect(deviceTokenCalls, 2, reason: 'first token, then a fresh one after the 401');
    expect(syncCalls, 2);
  });

  test('a server error throws, leaving the operation queued', () async {
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/auth/device')) {
        return http.Response(
          jsonEncode(<String, dynamic>{'deviceId': 'd1', 'token': 't1', 'expiresAtMillis': 9999999999999}),
          200,
        );
      }
      return http.Response('server exploded', 500);
    });

    final HttpSyncTransport transport = HttpSyncTransport(baseUrl: 'http://localhost:8000', client: client);
    await expectLater(transport.send(_operation()), throwsA(isA<StateError>()));
  });

  test('a "duplicate" response from the backend is still treated as success', () async {
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/auth/device')) {
        return http.Response(
          jsonEncode(<String, dynamic>{'deviceId': 'd1', 'token': 't1', 'expiresAtMillis': 9999999999999}),
          200,
        );
      }
      return http.Response(jsonEncode(<String, dynamic>{'status': 'duplicate'}), 200);
    });

    final HttpSyncTransport transport = HttpSyncTransport(baseUrl: 'http://localhost:8000', client: client);
    await transport.send(_operation()); // must not throw
  });
}
