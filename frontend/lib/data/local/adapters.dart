import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import '../../core/models/clinical.dart';
import '../../core/models/daily.dart';
import '../../core/models/game.dart';
import '../../core/models/mood_drawing.dart';
import '../../core/models/patient.dart';
import 'sync_operation.dart';

/// Hand-written Hive adapters.
///
/// The project deliberately avoids code generation — `build_runner` would pull
/// a large tool chain in for types we can serialise in a few lines each. The
/// wire format matches what `hive_generator` emits (a field count, then
/// `(index, value)` pairs), so unknown fields read back as `null` and a model
/// can gain a field later without invalidating a box written by an older build.
///
/// Type ids are permanent. Never reuse or renumber one.
class HiveTypeIds {
  const HiveTypeIds._();

  static const int familyMember = 1;
  static const int memoryAsset = 2;
  static const int lifeMemory = 3;
  static const int routineItem = 4;
  static const int patient = 5;
  static const int gamePerformance = 6;
  static const int gameSession = 7;
  static const int journalEntry = 8;
  static const int reminder = 9;
  static const int cognitiveProfile = 10;
  static const int pendingOperation = 11;
  static const int moodDrawing = 12;
  static const int moodCheckInTurn = 13;

  static const int memoryAssetKind = 20;
  static const int routineKind = 21;
  static const int gameId = 22;
  static const int cognitiveDomain = 23;
  static const int moodLevel = 24;
  static const int reminderKind = 25;
  static const int syncOperationKind = 26;
  static const int syncStatus = 27;
}

/// Reads the `(index, value)` pairs an adapter wrote into a plain map.
Map<int, dynamic> _fields(BinaryReader reader) {
  final int count = reader.readByte();
  return <int, dynamic>{
    for (int i = 0; i < count; i++) reader.readByte(): reader.read(),
  };
}

/// Enums are stored by `name`, not by index, so reordering a Dart enum can
/// never silently reinterpret existing rows. An unknown name falls back rather
/// than throwing — a box written by a newer build must still open.
class EnumAdapter<T extends Enum> extends TypeAdapter<T> {
  const EnumAdapter(this.typeId, this.values, this.fallback);

  @override
  final int typeId;

  final List<T> values;
  final T fallback;

  @override
  T read(BinaryReader reader) {
    final String name = reader.readString();
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  @override
  void write(BinaryWriter writer, T obj) => writer.writeString(obj.name);
}

// ─────────────────────────────────────────────────────────────────────────
// Patient profile
// ─────────────────────────────────────────────────────────────────────────

class FamilyMemberAdapter extends TypeAdapter<FamilyMember> {
  @override
  final int typeId = HiveTypeIds.familyMember;

  @override
  FamilyMember read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return FamilyMember(
      id: f[0] as String,
      name: f[1] as String,
      relation: f[2] as String,
      sceneId: f[3] as String,
      note: f[4] as String? ?? '',
      livesWithPatient: f[5] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, FamilyMember obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.relation)
      ..writeByte(3)
      ..write(obj.sceneId)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.livesWithPatient);
  }
}

class MemoryAssetAdapter extends TypeAdapter<MemoryAsset> {
  @override
  final int typeId = HiveTypeIds.memoryAsset;

  @override
  MemoryAsset read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return MemoryAsset(
      id: f[0] as String,
      title: f[1] as String,
      sceneId: f[2] as String,
      kind: f[3] as MemoryAssetKind? ?? MemoryAssetKind.object,
      caption: f[4] as String? ?? '',
      year: f[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MemoryAsset obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.sceneId)
      ..writeByte(3)
      ..write(obj.kind)
      ..writeByte(4)
      ..write(obj.caption)
      ..writeByte(5)
      ..write(obj.year);
  }
}

class LifeMemoryAdapter extends TypeAdapter<LifeMemory> {
  @override
  final int typeId = HiveTypeIds.lifeMemory;

  @override
  LifeMemory read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return LifeMemory(
      id: f[0] as String,
      category: f[1] as String,
      prompt: f[2] as String,
      answer: f[3] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, LifeMemory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.prompt)
      ..writeByte(3)
      ..write(obj.answer);
  }
}

class RoutineItemAdapter extends TypeAdapter<RoutineItem> {
  @override
  final int typeId = HiveTypeIds.routineItem;

  @override
  RoutineItem read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return RoutineItem(
      time: f[0] as String,
      title: f[1] as String,
      kind: f[2] as RoutineKind? ?? RoutineKind.activity,
      detail: f[3] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, RoutineItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.time)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.detail);
  }
}

class PatientAdapter extends TypeAdapter<Patient> {
  @override
  final int typeId = HiveTypeIds.patient;

  @override
  Patient read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return Patient(
      id: f[0] as String,
      name: f[1] as String,
      shortName: f[2] as String,
      age: f[3] as int,
      location: f[4] as String,
      language: f[5] as String,
      occupation: f[6] as String,
      favouriteActivity: f[7] as String,
      favouriteFood: f[8] as String,
      tradition: f[9] as String,
      portraitScene: f[10] as String,
      family: (f[11] as List<dynamic>?)?.cast<FamilyMember>() ?? const <FamilyMember>[],
      memories: (f[12] as List<dynamic>?)?.cast<LifeMemory>() ?? const <LifeMemory>[],
      assets: (f[13] as List<dynamic>?)?.cast<MemoryAsset>() ?? const <MemoryAsset>[],
      routine: (f[14] as List<dynamic>?)?.cast<RoutineItem>() ?? const <RoutineItem>[],
      stageNote: f[15] as String? ?? 'Early-stage memory changes',
      joinedOn: f[16] as String? ?? 'Profile created today',
      phoneNumber: f[17] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Patient obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.shortName)
      ..writeByte(3)
      ..write(obj.age)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.language)
      ..writeByte(6)
      ..write(obj.occupation)
      ..writeByte(7)
      ..write(obj.favouriteActivity)
      ..writeByte(8)
      ..write(obj.favouriteFood)
      ..writeByte(9)
      ..write(obj.tradition)
      ..writeByte(10)
      ..write(obj.portraitScene)
      ..writeByte(11)
      ..write(obj.family)
      ..writeByte(12)
      ..write(obj.memories)
      ..writeByte(13)
      ..write(obj.assets)
      ..writeByte(14)
      ..write(obj.routine)
      ..writeByte(15)
      ..write(obj.stageNote)
      ..writeByte(16)
      ..write(obj.joinedOn)
      ..writeByte(17)
      ..write(obj.phoneNumber);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Activity results
// ─────────────────────────────────────────────────────────────────────────

class GamePerformanceAdapter extends TypeAdapter<GamePerformance> {
  @override
  final int typeId = HiveTypeIds.gamePerformance;

  @override
  GamePerformance read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return GamePerformance(
      accuracy: (f[0] as num).toDouble(),
      focus: (f[1] as num).toDouble(),
      memory: (f[2] as num).toDouble(),
      hintsUsed: f[3] as int? ?? 0,
      mistakes: f[4] as int? ?? 0,
      seconds: f[5] as int? ?? 0,
      completed: f[6] as bool? ?? false,
      // Added after the first release: a box written by an older build has no
      // field 7–9, which reads back as null and falls through to zero.
      attempts: f[7] as int? ?? 0,
      correct: f[8] as int? ?? 0,
      responseMillis: f[9] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, GamePerformance obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.accuracy)
      ..writeByte(1)
      ..write(obj.focus)
      ..writeByte(2)
      ..write(obj.memory)
      ..writeByte(3)
      ..write(obj.hintsUsed)
      ..writeByte(4)
      ..write(obj.mistakes)
      ..writeByte(5)
      ..write(obj.seconds)
      ..writeByte(6)
      ..write(obj.completed)
      ..writeByte(7)
      ..write(obj.attempts)
      ..writeByte(8)
      ..write(obj.correct)
      ..writeByte(9)
      ..write(obj.responseMillis);
  }
}

class GameSessionAdapter extends TypeAdapter<GameSession> {
  @override
  final int typeId = HiveTypeIds.gameSession;

  @override
  GameSession read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return GameSession(
      gameId: f[0] as GameId? ?? GameId.procedure,
      dayOffset: f[1] as int? ?? 0,
      level: f[2] as int? ?? 1,
      performance: f[3] as GamePerformance,
      timeLabel: f[4] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, GameSession obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.gameId)
      ..writeByte(1)
      ..write(obj.dayOffset)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.performance)
      ..writeByte(4)
      ..write(obj.timeLabel);
  }
}

class CognitiveProfileAdapter extends TypeAdapter<CognitiveProfile> {
  @override
  final int typeId = HiveTypeIds.cognitiveProfile;

  @override
  CognitiveProfile read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    // Scores are keyed by domain *name* so the map survives an enum reorder.
    final Map<dynamic, dynamic> raw =
        (f[0] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    final Map<CognitiveDomain, int> scores = <CognitiveDomain, int>{};
    for (final MapEntry<dynamic, dynamic> e in raw.entries) {
      for (final CognitiveDomain d in CognitiveDomain.values) {
        if (d.name == e.key) scores[d] = (e.value as num).toInt();
      }
    }
    return CognitiveProfile(
      scores: scores,
      overall: f[1] as int? ?? 0,
      updated: f[2] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, CognitiveProfile obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(<String, int>{
        for (final MapEntry<CognitiveDomain, int> e in obj.scores.entries) e.key.name: e.value,
      })
      ..writeByte(1)
      ..write(obj.overall)
      ..writeByte(2)
      ..write(obj.updated);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Daily conversation and reminders
// ─────────────────────────────────────────────────────────────────────────

class JournalEntryAdapter extends TypeAdapter<JournalEntry> {
  @override
  final int typeId = HiveTypeIds.journalEntry;

  @override
  JournalEntry read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return JournalEntry(
      questionId: f[0] as String,
      label: f[1] as String,
      answer: f[2] as String,
      positive: f[3] as bool? ?? true,
      time: f[4] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, JournalEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.questionId)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.answer)
      ..writeByte(3)
      ..write(obj.positive)
      ..writeByte(4)
      ..write(obj.time);
  }
}

class ReminderAdapter extends TypeAdapter<Reminder> {
  @override
  final int typeId = HiveTypeIds.reminder;

  @override
  Reminder read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return Reminder(
      id: f[0] as String,
      time: f[1] as String,
      minutesFromMidnight: f[2] as int? ?? 0,
      title: f[3] as String,
      kind: f[4] as ReminderKind? ?? ReminderKind.routine,
      detail: f[5] as String? ?? '',
      done: f[6] as bool? ?? false,
      smsEnabled: f[7] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Reminder obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.time)
      ..writeByte(2)
      ..write(obj.minutesFromMidnight)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.kind)
      ..writeByte(5)
      ..write(obj.detail)
      ..writeByte(6)
      ..write(obj.done)
      ..writeByte(7)
      ..write(obj.smsEnabled);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Mood Check-In
// ─────────────────────────────────────────────────────────────────────────

class MoodCheckInTurnAdapter extends TypeAdapter<MoodCheckInTurn> {
  @override
  final int typeId = HiveTypeIds.moodCheckInTurn;

  @override
  MoodCheckInTurn read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return MoodCheckInTurn(
      question: f[0] as String? ?? '',
      answer: f[1] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, MoodCheckInTurn obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.question)
      ..writeByte(1)
      ..write(obj.answer);
  }
}

class MoodDrawingAdapter extends TypeAdapter<MoodDrawing> {
  @override
  final int typeId = HiveTypeIds.moodDrawing;

  @override
  MoodDrawing read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return MoodDrawing(
      id: f[0] as String,
      dayOffset: f[1] as int? ?? 0,
      timeLabel: f[2] as String? ?? '',
      pngBytes: f[3] as Uint8List,
      doctorNote: f[4] as String?,
      notedAtIso: f[5] as String?,
      notedBy: f[6] as String?,
      // Added after the first release: a box written by an older build has
      // no fields 7-8, which read back as null/empty rather than crashing.
      transcript:
          (f[7] as List<dynamic>?)?.cast<MoodCheckInTurn>() ?? const <MoodCheckInTurn>[],
      moodLevel: f[8] as MoodLevel?,
    );
  }

  @override
  void write(BinaryWriter writer, MoodDrawing obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dayOffset)
      ..writeByte(2)
      ..write(obj.timeLabel)
      ..writeByte(3)
      ..write(obj.pngBytes)
      ..writeByte(4)
      ..write(obj.doctorNote)
      ..writeByte(5)
      ..write(obj.notedAtIso)
      ..writeByte(6)
      ..write(obj.notedBy)
      ..writeByte(7)
      ..write(obj.transcript)
      ..writeByte(8)
      ..write(obj.moodLevel);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Sync queue
// ─────────────────────────────────────────────────────────────────────────

class PendingOperationAdapter extends TypeAdapter<PendingOperation> {
  @override
  final int typeId = HiveTypeIds.pendingOperation;

  @override
  PendingOperation read(BinaryReader reader) {
    final Map<int, dynamic> f = _fields(reader);
    return PendingOperation(
      id: f[0] as String,
      kind: f[1] as SyncOperationKind? ?? SyncOperationKind.unknown,
      payload: ((f[2] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{})
          .map((dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v)),
      createdAtMillis: f[3] as int? ?? 0,
      status: f[4] as SyncStatus? ?? SyncStatus.pending,
      attempts: f[5] as int? ?? 0,
      syncedAtMillis: f[6] as int?,
      lastError: f[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingOperation obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.kind)
      ..writeByte(2)
      ..write(obj.payload)
      ..writeByte(3)
      ..write(obj.createdAtMillis)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.attempts)
      ..writeByte(6)
      ..write(obj.syncedAtMillis)
      ..writeByte(7)
      ..write(obj.lastError);
  }
}
