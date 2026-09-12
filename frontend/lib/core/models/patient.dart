import 'package:flutter/foundation.dart';

/// A person who matters to the patient. Used to personalise questions,
/// stories and memory prompts.
@immutable
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.sceneId,
    this.note = '',
    this.livesWithPatient = false,
    this.photoPath,
  });

  final String id;
  final String name;
  final String relation;

  /// Key for the procedurally drawn portrait (see `Illustrations`).
  final String sceneId;
  final String note;
  final bool livesWithPatient;

  /// A real photograph of this person, copied into the app's documents
  /// directory. Null when they are drawn. Recognising an actual face is the
  /// point of showing family at all, so this matters more here than anywhere
  /// else in the app.
  final String? photoPath;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  FamilyMember copyWith({
    String? name,
    String? relation,
    String? sceneId,
    String? note,
    String? photoPath,
  }) {
    return FamilyMember(
      id: id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      sceneId: sceneId ?? this.sceneId,
      note: note ?? this.note,
      livesWithPatient: livesWithPatient,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}

enum MemoryAssetKind { person, place, object, event, hobby }

extension MemoryAssetKindX on MemoryAssetKind {
  String get label => switch (this) {
        MemoryAssetKind.person => 'People',
        MemoryAssetKind.place => 'Places',
        MemoryAssetKind.object => 'Objects',
        MemoryAssetKind.event => 'Events',
        MemoryAssetKind.hobby => 'Hobbies',
      };
}

/// A photo-like memory the caregiver attached to the profile. In the prototype
/// these are procedurally drawn scenes rather than uploaded files.
@immutable
class MemoryAsset {
  const MemoryAsset({
    required this.id,
    required this.title,
    required this.sceneId,
    required this.kind,
    this.caption = '',
    this.year,
    this.photoPath,
  });

  final String id;
  final String title;

  /// The drawing to fall back on. Always set, so a picture still has
  /// something to show if the photo file is ever gone — a restored backup, a
  /// cleared cache, a phone the record synced to but the file did not.
  final String sceneId;

  final MemoryAssetKind kind;
  final String caption;
  final String? year;

  /// Absolute path to a real photograph the caregiver added, copied into the
  /// app's own documents directory. Null when this is a drawing.
  ///
  /// A path rather than the bytes: family photographs run to several
  /// megabytes each, and a Hive box holding a dozen of them would be loaded
  /// into memory in full every time the profile is read.
  final String? photoPath;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  MemoryAsset copyWith({String? photoPath, bool clearPhoto = false}) => MemoryAsset(
        id: id,
        title: title,
        sceneId: sceneId,
        kind: kind,
        caption: caption,
        year: year,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      );
}

/// A life story / biographical fact captured during onboarding.
@immutable
class LifeMemory {
  const LifeMemory({
    required this.id,
    required this.category,
    required this.prompt,
    required this.answer,
  });

  final String id;
  final String category;
  final String prompt;
  final String answer;

  LifeMemory copyWith({String? answer}) =>
      LifeMemory(id: id, category: category, prompt: prompt, answer: answer ?? this.answer);
}

enum RoutineKind { meal, activity, rest, cognitive, medicine, social }

@immutable
class RoutineItem {
  const RoutineItem({
    required this.time,
    required this.title,
    required this.kind,
    this.detail = '',
  });

  final String time;
  final String title;
  final RoutineKind kind;
  final String detail;
}

/// The complete personalised profile that drives the whole experience.
@immutable
class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.shortName,
    required this.age,
    required this.location,
    required this.language,
    required this.occupation,
    required this.favouriteActivity,
    required this.favouriteFood,
    this.favouriteMusic = '',
    required this.tradition,
    required this.portraitScene,
    required this.family,
    required this.memories,
    required this.assets,
    required this.routine,
    this.stageNote = 'Early-stage memory changes',
    this.joinedOn = 'Profile created today',
    this.phoneNumber = '',
  });

  final String id;
  final String name;
  final String shortName;
  final int age;
  final String location;
  final String language;
  final String occupation;
  final String favouriteActivity;
  final String favouriteFood;

  /// What they like to listen to. Feeds the companion's prompts and the
  /// melody activity, and is one of the last preferences to fade.
  final String favouriteMusic;
  final String tradition;
  final String portraitScene;

  final List<FamilyMember> family;
  final List<LifeMemory> memories;
  final List<MemoryAsset> assets;
  final List<RoutineItem> routine;

  final String stageNote;
  final String joinedOn;
  final String phoneNumber;

  FamilyMember? get primaryRelative => family.isEmpty ? null : family.first;

  String memoryFor(String category) {
    for (final LifeMemory m in memories) {
      if (m.category.toLowerCase() == category.toLowerCase() && m.answer.trim().isNotEmpty) {
        return m.answer;
      }
    }
    return '';
  }

  List<MemoryAsset> assetsOf(MemoryAssetKind kind) =>
      assets.where((MemoryAsset a) => a.kind == kind).toList(growable: false);

  Patient copyWith({
    String? id,
    String? name,
    String? shortName,
    int? age,
    String? location,
    String? language,
    String? occupation,
    String? favouriteActivity,
    String? favouriteFood,
    String? favouriteMusic,
    String? tradition,
    String? portraitScene,
    List<FamilyMember>? family,
    List<LifeMemory>? memories,
    List<MemoryAsset>? assets,
    List<RoutineItem>? routine,
    String? stageNote,
    String? joinedOn,
    String? phoneNumber,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      age: age ?? this.age,
      location: location ?? this.location,
      language: language ?? this.language,
      occupation: occupation ?? this.occupation,
      favouriteActivity: favouriteActivity ?? this.favouriteActivity,
      favouriteFood: favouriteFood ?? this.favouriteFood,
      favouriteMusic: favouriteMusic ?? this.favouriteMusic,
      tradition: tradition ?? this.tradition,
      portraitScene: portraitScene ?? this.portraitScene,
      family: family ?? this.family,
      memories: memories ?? this.memories,
      assets: assets ?? this.assets,
      routine: routine ?? this.routine,
      stageNote: stageNote ?? this.stageNote,
      joinedOn: joinedOn ?? this.joinedOn,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

/// JSON for the sync contract.
///
/// Field names match `backend/app/models/patient.py` exactly — camelCase both
/// ways — so a profile pushed from one device reconstructs byte-for-byte on
/// another. Kept here rather than in a mapper because the day these two drift
/// is the day a family's memories stop arriving on the second phone.
extension PatientJson on Patient {
  Map<String, dynamic> toSyncJson() => <String, dynamic>{
        'patientId': id,
        'name': name,
        'shortName': shortName,
        'age': age,
        'location': location,
        'language': language,
        'occupation': occupation,
        'favouriteActivity': favouriteActivity,
        'favouriteFood': favouriteFood,
        'favouriteMusic': favouriteMusic,
        'tradition': tradition,
        'portraitScene': portraitScene,
        'stageNote': stageNote,
        'joinedOn': joinedOn,
        'phoneNumber': phoneNumber,
        'family': <Map<String, dynamic>>[
          for (final FamilyMember f in family)
            <String, dynamic>{
              'id': f.id,
              'name': f.name,
              'relation': f.relation,
              'sceneId': f.sceneId,
              'note': f.note,
              'livesWithPatient': f.livesWithPatient,
            },
        ],
        'memories': <Map<String, dynamic>>[
          for (final LifeMemory m in memories)
            <String, dynamic>{
              'id': m.id,
              'category': m.category,
              'prompt': m.prompt,
              'answer': m.answer,
            },
        ],
        'assets': <Map<String, dynamic>>[
          for (final MemoryAsset a in assets)
            <String, dynamic>{
              'id': a.id,
              'title': a.title,
              'sceneId': a.sceneId,
              'kind': a.kind.name == 'object_' ? 'object' : a.kind.name,
              'caption': a.caption,
              if (a.year != null) 'year': a.year,
            },
        ],
        'routine': <Map<String, dynamic>>[
          for (final RoutineItem r in routine)
            <String, dynamic>{
              'time': r.time,
              'title': r.title,
              'kind': r.kind.name,
              'detail': r.detail,
            },
        ],
      };
}

/// Rebuilds a profile that came back from the server.
///
/// Every field falls back to [fallback]'s value rather than to a literal, so a
/// server that has only ever seen a partial profile cannot blank what this
/// device already knows.
Patient patientFromSyncJson(Map<String, dynamic> j, {required Patient fallback}) {
  T? enumByName<T extends Enum>(String? name, List<T> values) {
    if (name == null) return null;
    for (final T v in values) {
      if (v.name == name || (v.name == 'object_' && name == 'object')) return v;
    }
    return null;
  }

  List<Map<String, dynamic>> listOf(Object? raw) => <Map<String, dynamic>>[
        for (final Object? item in (raw as List<dynamic>?) ?? const <dynamic>[])
          item! as Map<String, dynamic>,
      ];

  final List<Map<String, dynamic>> family = listOf(j['family']);
  final List<Map<String, dynamic>> memories = listOf(j['memories']);
  final List<Map<String, dynamic>> assets = listOf(j['assets']);
  final List<Map<String, dynamic>> routine = listOf(j['routine']);

  return Patient(
    id: j['id'] as String? ?? fallback.id,
    name: j['name'] as String? ?? fallback.name,
    shortName: j['shortName'] as String? ?? fallback.shortName,
    age: (j['age'] as num?)?.toInt() ?? fallback.age,
    location: j['location'] as String? ?? fallback.location,
    language: j['language'] as String? ?? fallback.language,
    occupation: j['occupation'] as String? ?? fallback.occupation,
    favouriteActivity: j['favouriteActivity'] as String? ?? fallback.favouriteActivity,
    favouriteFood: j['favouriteFood'] as String? ?? fallback.favouriteFood,
    favouriteMusic: j['favouriteMusic'] as String? ?? fallback.favouriteMusic,
    tradition: j['tradition'] as String? ?? fallback.tradition,
    portraitScene: j['portraitScene'] as String? ?? fallback.portraitScene,
    stageNote: j['stageNote'] as String? ?? fallback.stageNote,
    joinedOn: j['joinedOn'] as String? ?? fallback.joinedOn,
    phoneNumber: j['phoneNumber'] as String? ?? fallback.phoneNumber,
    family: family.isEmpty
        ? fallback.family
        : <FamilyMember>[
            for (final Map<String, dynamic> f in family)
              FamilyMember(
                id: f['id'] as String? ?? '',
                name: f['name'] as String? ?? '',
                relation: f['relation'] as String? ?? '',
                sceneId: f['sceneId'] as String? ?? 'portrait_priya',
                note: f['note'] as String? ?? '',
                livesWithPatient: f['livesWithPatient'] as bool? ?? false,
              ),
          ],
    memories: memories.isEmpty
        ? fallback.memories
        : <LifeMemory>[
            for (final Map<String, dynamic> m in memories)
              LifeMemory(
                id: m['id'] as String? ?? '',
                category: m['category'] as String? ?? '',
                prompt: m['prompt'] as String? ?? '',
                answer: m['answer'] as String? ?? '',
              ),
          ],
    assets: assets.isEmpty
        ? fallback.assets
        : <MemoryAsset>[
            for (final Map<String, dynamic> a in assets)
              MemoryAsset(
                id: a['id'] as String? ?? '',
                title: a['title'] as String? ?? '',
                sceneId: a['sceneId'] as String? ?? '',
                kind: enumByName(a['kind'] as String?, MemoryAssetKind.values) ??
                    MemoryAssetKind.person,
                caption: a['caption'] as String? ?? '',
                year: a['year'] as String?,
              ),
          ],
    routine: routine.isEmpty
        ? fallback.routine
        : <RoutineItem>[
            for (final Map<String, dynamic> r in routine)
              RoutineItem(
                time: r['time'] as String? ?? '',
                title: r['title'] as String? ?? '',
                kind: enumByName(r['kind'] as String?, RoutineKind.values) ??
                    RoutineKind.activity,
                detail: r['detail'] as String? ?? '',
              ),
          ],
  );
}
