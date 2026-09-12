import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/core/models/patient.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/core/services/sync_manager.dart';
import 'package:smaran_saathi/data/local/sync_operation.dart';

/// A transport that records what was pushed and serves back what a second
/// device would be given.
class _RecordingTransport implements SyncTransport {
  _RecordingTransport({this.bundle});

  final List<PendingOperation> sent = <PendingOperation>[];
  Map<String, dynamic>? bundle;

  @override
  Future<void> send(PendingOperation operation) async => sent.add(operation);

  @override
  Future<Map<String, dynamic>?> restore(String patientId) async => bundle;

  Map<String, dynamic>? get lastProfilePush {
    for (final PendingOperation op in sent.reversed) {
      if (op.kind == SyncOperationKind.profileUpdate) return op.payload;
    }
    return null;
  }
}

void main() {
  group('the whole profile travels, not just a name', () {
    test('a profile push carries family, memories and preferences', () async {
      final _RecordingTransport transport = _RecordingTransport();
      final AppState state = AppState(transport: transport);
      addTearDown(state.dispose);

      state.saveLifeProfile(
        portraitScene: 'portrait_aama',
        location: 'Jorhat, Assam',
        favouriteMusic: 'Bihu songs',
        favouriteFood: 'Pitha',
        tradition: 'Magh Bihu',
        family: const <FamilyMember>[
          FamilyMember(
            id: 'f1',
            name: 'Priya',
            relation: 'Daughter',
            sceneId: 'portrait_priya',
            livesWithPatient: true,
          ),
        ],
        memories: const <LifeMemory>[
          LifeMemory(id: 'm1', category: 'Wedding', prompt: 'Wedding', answer: 'It rained.'),
        ],
      );
      await state.flush();

      final Map<String, dynamic>? push = transport.lastProfilePush;
      expect(push, isNotNull, reason: 'saving a life profile must reach the outbox');
      // The thing this test exists for: it used to be {patientId, name}, and a
      // second device could never rebuild the person from that.
      expect(push!['location'], 'Jorhat, Assam');
      expect(push['favouriteMusic'], 'Bihu songs');
      expect(push['tradition'], 'Magh Bihu');
      expect((push['family'] as List<dynamic>).single, containsPair('name', 'Priya'));
      expect((push['memories'] as List<dynamic>).single, containsPair('answer', 'It rained.'));
    });
  });

  group('restoring onto a second device', () {
    test('rebuilds the person from what the server holds', () async {
      final _RecordingTransport transport = _RecordingTransport(
        bundle: <String, dynamic>{
          'patientId': 'p_1',
          'patient': <String, dynamic>{
            'id': 'p_1',
            'name': 'Aruna Devi',
            'shortName': 'Aruna',
            'age': 74,
            'location': 'Jorhat, Assam',
            'favouriteMusic': 'Bihu songs',
            'family': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'f1',
                'name': 'Priya',
                'relation': 'Daughter',
                'sceneId': 'portrait_priya',
                'livesWithPatient': true,
              },
            ],
          },
        },
      );
      final AppState state = AppState(transport: transport);
      addTearDown(state.dispose);

      expect(state.hasPatientProfile, isFalse, reason: 'a fresh device knows nobody');

      final bool restored = await state.restoreFromServer(patientId: 'p_1');

      expect(restored, isTrue);
      expect(state.patient.name, 'Aruna Devi');
      expect(state.patient.location, 'Jorhat, Assam');
      expect(state.patient.favouriteMusic, 'Bihu songs');
      expect(state.patient.family.single.name, 'Priya');
      expect(state.hasPatientProfile, isTrue);
    });

    test('a field the server has never seen does not erase the local one', () async {
      // The device is ahead of the server: it knows the music, the server
      // only knows the name. Restoring must not blank what is already here.
      final _RecordingTransport transport = _RecordingTransport(
        bundle: <String, dynamic>{
          'patientId': 'p_1',
          'patient': <String, dynamic>{'id': 'p_1', 'name': 'Aruna Devi'},
        },
      );
      final AppState state = AppState(transport: transport);
      addTearDown(state.dispose);

      state.saveLifeProfile(
        portraitScene: 'portrait_aama',
        location: 'Jorhat, Assam',
        favouriteMusic: 'Bihu songs',
        favouriteFood: 'Pitha',
        tradition: 'Magh Bihu',
        family: const <FamilyMember>[
          FamilyMember(id: 'f1', name: 'Priya', relation: 'Daughter', sceneId: 'portrait_priya'),
        ],
        memories: const <LifeMemory>[],
      );

      await state.restoreFromServer(patientId: 'p_1');

      expect(state.patient.name, 'Aruna Devi', reason: 'the server had a name');
      expect(state.patient.favouriteMusic, 'Bihu songs', reason: 'it did not have this');
      expect(state.patient.family.single.name, 'Priya', reason: 'nor this');
    });

    test('nothing on the server is not an error', () async {
      final AppState state = AppState(transport: _RecordingTransport());
      addTearDown(state.dispose);
      expect(await state.restoreFromServer(patientId: 'p_never_synced'), isFalse);
    });

    test('a transport that cannot restore reports so rather than throwing', () async {
      final AppState state = AppState(transport: const LoopbackTransport());
      addTearDown(state.dispose);
      expect(await state.restoreFromServer(patientId: 'p_1'), isFalse);
    });
  });
}
