import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:smaran_saathi/core/services/pairing_service.dart';

/// Builds a client that answers for a set of hosts and 404s everything else,
/// so a test can describe a world — "the deployed backend is up but old, and
/// localhost has the new endpoints" — rather than a sequence of calls.
MockClient _world({
  required Set<String> reachable,
  required Set<String> supportsPairing,
  List<String>? log,
}) {
  return MockClient((http.Request request) async {
    final String host = '${request.url.scheme}://${request.url.authority}';
    log?.add('$host${request.url.path}');
    if (!reachable.contains(host)) {
      throw http.ClientException('no route to host');
    }
    if (request.url.path.endsWith('/auth/device')) {
      return http.Response(jsonEncode(<String, String>{'token': 't-$host'}), 200);
    }
    if (request.url.path.contains('/pairing/')) {
      if (!supportsPairing.contains(host)) return http.Response('not found', 404);
      if (request.url.path.endsWith('/pairing/requests')) {
        return http.Response('[]', 200);
      }
      return http.Response(
        jsonEncode(<String, dynamic>{
          'username': 'aruna',
          'patientId': 'p_1',
          'caregiverUid': 'uid-1',
          'patientName': 'Aruna',
          'alreadyClaimed': false,
        }),
        200,
      );
    }
    return http.Response('not found', 404);
  });
}

const String _deployed = 'https://smaransaathi-backend.onrender.com';
const String _local = 'http://127.0.0.1:8000';

void main() {
  group('finding a backend that can actually pair', () {
    test('skips a reachable server that has no pairing endpoints', () async {
      // Exactly the reported bug: the app was launched with no
      // MM_SYNC_BASE_URL, so it defaulted to the deployed backend — which is
      // healthy and 404s every pairing call.
      final List<String> log = <String>[];
      final PairingService service = PairingService(
        baseUrl: _deployed,
        client: _world(
          reachable: <String>{_deployed, _local},
          supportsPairing: <String>{_local},
          log: log,
        ),
      );

      final PairingClaim claim = await service.claim(
        username: 'aruna',
        patientId: 'p_1',
        caregiverUid: 'uid-1',
      );

      expect(claim.username, 'aruna');
      expect(log.any((String l) => l.startsWith(_local)), isTrue,
          reason: 'it has to fall through to the machine running the backend');
    });

    test('a backend without pairing is reported as such, not as offline',
        () async {
      final PairingService service = PairingService(
        baseUrl: _deployed,
        client: _world(
          reachable: <String>{_deployed},
          supportsPairing: const <String>{},
        ),
      );

      // The distinction that matters: "update the server" sends someone
      // somewhere useful, "check your connection" does not.
      await expectLater(
        service.claim(username: 'aruna', patientId: 'p_1', caregiverUid: 'uid-1'),
        throwsA(isA<PairingUnsupportedException>()),
      );
    });

    test('nothing reachable at all is reported distinctly from "unsupported"', () async {
      final PairingService service = PairingService(
        baseUrl: _deployed,
        client: _world(reachable: const <String>{}, supportsPairing: const <String>{}),
      );
      await expectLater(
        service.claim(username: 'aruna', patientId: 'p_1', caregiverUid: 'uid-1'),
        throwsA(isA<PairingUnreachableException>()),
      );
    });

    test('the configured backend is tried before the dev-loopback fallbacks',
        () async {
      // The reported bug this guards against: the loopback candidates used
      // to be tried first, so a working, correctly-configured backend paid
      // for three doomed attempts (each able to hang for real on a network
      // that drops rather than refuses) before ever being reached.
      final List<String> log = <String>[];
      final PairingService service = PairingService(
        baseUrl: _deployed,
        client: _world(
          reachable: <String>{_deployed},
          supportsPairing: <String>{_deployed},
          log: log,
        ),
      );

      await service.claim(username: 'aruna', patientId: 'p_1', caregiverUid: 'uid-1');

      expect(log, isNotEmpty);
      expect(log.first, startsWith(_deployed),
          reason: 'the configured backend must be the first thing tried');
    });

    test('the working host is remembered, not rediscovered every call', () async {
      final List<String> log = <String>[];
      final PairingService service = PairingService(
        baseUrl: _deployed,
        client: _world(
          reachable: <String>{_deployed, _local},
          supportsPairing: <String>{_local},
          log: log,
        ),
      );

      await service.claim(username: 'a', patientId: 'p', caregiverUid: 'u');
      final int afterFirst = log.length;
      await service.pendingFor('u');

      // One request for the second call: no re-probing the dead host.
      expect(log.length - afterFirst, 1);
    });
  });
}
