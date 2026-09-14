import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:smaran_saathi/core/models/clinical.dart';
import 'package:smaran_saathi/core/models/doctor.dart';
import 'package:smaran_saathi/core/services/doctor_connection_service.dart';

void main() {
  test('every call carries the Firebase ID token as a bearer header', () async {
    final List<http.Request> requests = <http.Request>[];
    final MockClient client = MockClient((http.Request request) async {
      requests.add(request);
      return http.Response(jsonEncode(<dynamic>[]), 200);
    });

    final DoctorConnectionService service = DoctorConnectionService(
      baseUrl: 'https://backend.test',
      idToken: ({bool forceRefresh = false}) async => 'real-firebase-token',
      client: client,
    );
    await service.directory();

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/v1/doctors/directory');
    expect(requests.single.headers['Authorization'], 'Bearer real-firebase-token');
  });

  test('parses a directory response into DoctorProfile rows', () async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'uid-1',
            'name': 'Ritu Bora',
            'specialization': 'Neurologist',
            'hospital': 'Jorhat Medical College',
            'email': 'ritu@example.com',
            'phone': '',
            'registrationNumber': 'MCI-1',
            'avatarInitials': 'RB',
          },
        ]),
        200,
      );
    });
    final DoctorConnectionService service = DoctorConnectionService(
      baseUrl: 'https://backend.test',
      idToken: ({bool forceRefresh = false}) async => 'token',
      client: client,
    );

    final List<DoctorProfile> directory = await service.directory();
    expect(directory, hasLength(1));
    expect(directory.single.id, 'uid-1');
    expect(directory.single.name, 'Ritu Bora');
    expect(directory.single.specialization, 'Neurologist');
  });

  test('invite sends the right body and surfaces a 409 as DoctorAlreadyConnectedException', () async {
    final List<http.Request> requests = <http.Request>[];
    final MockClient client = MockClient((http.Request request) async {
      requests.add(request);
      if (requests.length == 1) {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'requestId': 'req-1',
            'doctorUid': 'uid-1',
            'caregiverUid': 'uid-caregiver',
            'patientId': 'p_1',
            'patientName': 'Aama Devi',
            'patientAge': 72,
            'district': 'Jorhat',
            'status': 'pending',
            'requestedAtMillis': 1000,
          }),
          201,
        );
      }
      return http.Response('already connected', 409);
    });
    final DoctorConnectionService service = DoctorConnectionService(
      baseUrl: 'https://backend.test',
      idToken: ({bool forceRefresh = false}) async => 'token',
      client: client,
    );

    final ConnectionRequest first = await service.invite(
      doctorUid: 'uid-1',
      patientId: 'p_1',
      patientName: 'Aama Devi',
      patientAge: 72,
      district: 'Jorhat',
    );
    expect(first.id, 'req-1');
    expect(first.doctorId, 'uid-1');
    expect(first.patientName, 'Aama Devi');

    final Map<String, dynamic> body = jsonDecode(requests.first.body) as Map<String, dynamic>;
    expect(body['doctorUid'], 'uid-1');
    expect(body['patientId'], 'p_1');
    expect(body['patientName'], 'Aama Devi');
    expect(body['patientAge'], 72);
    expect(body['district'], 'Jorhat');

    await expectLater(
      service.invite(doctorUid: 'uid-1', patientId: 'p_1'),
      throwsA(isA<DoctorAlreadyConnectedException>()),
    );
  });

  test('caseload parses real ClinicPatient rows, including a nested profile', () async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'p_1',
            'name': 'Aama Devi',
            'age': 72,
            'district': 'Jorhat',
            'score': 68,
            'trend': 'up',
            'status': 'stable',
            'sceneId': 'portrait_aama',
            'language': 'Assamese',
            'lastSession': 'Today',
            'profile': <String, dynamic>{
              'scores': <String, dynamic>{'memory': 70, 'attention': 65},
              'overall': 68,
              'updated': 'Updated just now',
            },
            'thirtyDay': <double>[60, 62, 65, 68],
            'adherence': 80,
            'engagement': 75,
          },
        ]),
        200,
      );
    });
    final DoctorConnectionService service = DoctorConnectionService(
      baseUrl: 'https://backend.test',
      idToken: ({bool forceRefresh = false}) async => 'token',
      client: client,
    );

    final List<ClinicPatient> caseload = await service.caseload();
    expect(caseload, hasLength(1));
    expect(caseload.single.name, 'Aama Devi');
    expect(caseload.single.trend, TrendDirection.up);
    expect(caseload.single.status, ClinicalStatus.stable);
    expect(caseload.single.profile.overall, 68);
    expect(caseload.single.thirtyDay, <double>[60, 62, 65, 68]);
  });

  test('forPatient returns null when nobody is connected', () async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response('null', 200);
    });
    final DoctorConnectionService service = DoctorConnectionService(
      baseUrl: 'https://backend.test',
      idToken: ({bool forceRefresh = false}) async => 'token',
      client: client,
    );

    expect(await service.forPatient('p_1'), isNull);
  });
}
