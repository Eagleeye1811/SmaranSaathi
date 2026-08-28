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
  });

  final String id;
  final String name;
  final String relation;

  /// Key for the procedurally drawn portrait (see `Illustrations`).
  final String sceneId;
  final String note;
  final bool livesWithPatient;

  FamilyMember copyWith({String? name, String? relation, String? sceneId, String? note}) {
    return FamilyMember(
      id: id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      sceneId: sceneId ?? this.sceneId,
      note: note ?? this.note,
      livesWithPatient: livesWithPatient,
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
  });

  final String id;
  final String title;
  final String sceneId;
  final MemoryAssetKind kind;
  final String caption;
  final String? year;
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
    required this.tradition,
    required this.portraitScene,
    required this.family,
    required this.memories,
    required this.assets,
    required this.routine,
    this.stageNote = 'Early-stage memory changes',
    this.joinedOn = 'Profile created today',
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
  final String tradition;
  final String portraitScene;

  final List<FamilyMember> family;
  final List<LifeMemory> memories;
  final List<MemoryAsset> assets;
  final List<RoutineItem> routine;

  final String stageNote;
  final String joinedOn;

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
    String? name,
    String? shortName,
    int? age,
    String? location,
    String? language,
    String? occupation,
    String? favouriteActivity,
    String? favouriteFood,
    String? tradition,
    String? portraitScene,
    List<FamilyMember>? family,
    List<LifeMemory>? memories,
    List<MemoryAsset>? assets,
    List<RoutineItem>? routine,
  }) {
    return Patient(
      id: id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      age: age ?? this.age,
      location: location ?? this.location,
      language: language ?? this.language,
      occupation: occupation ?? this.occupation,
      favouriteActivity: favouriteActivity ?? this.favouriteActivity,
      favouriteFood: favouriteFood ?? this.favouriteFood,
      tradition: tradition ?? this.tradition,
      portraitScene: portraitScene ?? this.portraitScene,
      family: family ?? this.family,
      memories: memories ?? this.memories,
      assets: assets ?? this.assets,
      routine: routine ?? this.routine,
      stageNote: stageNote,
      joinedOn: joinedOn,
    );
  }
}
