import 'package:flutter/material.dart';

/// A room of the patient's "Memory Home" — the theme a shared life-story
/// belongs to. Deliberately broad rather than granular: the point is a small,
/// legible set of rooms to unlock and decorate, not an exhaustive taxonomy.
enum MemoryCategory { family, childhood, work, festivals, food, village }

extension MemoryCategoryX on MemoryCategory {
  String get label => switch (this) {
        MemoryCategory.family => 'Family',
        MemoryCategory.childhood => 'Childhood',
        MemoryCategory.work => 'Work & craft',
        MemoryCategory.festivals => 'Festivals',
        MemoryCategory.food => 'Food',
        MemoryCategory.village => 'Village life',
      };

  /// What the room looks like before any memory has furnished it.
  String get emptyRoomLabel => switch (this) {
        MemoryCategory.family => 'An empty room, waiting for the people you love.',
        MemoryCategory.childhood => 'A quiet room, waiting for a memory of being young.',
        MemoryCategory.work => 'A bare workshop, waiting for what your hands used to do.',
        MemoryCategory.festivals => 'An undecorated hall, waiting for a celebration.',
        MemoryCategory.food => 'An empty kitchen, waiting for a taste you remember.',
        MemoryCategory.village => 'An open yard, waiting for a place you once knew.',
      };

  IconData get icon => switch (this) {
        MemoryCategory.family => Icons.groups_rounded,
        MemoryCategory.childhood => Icons.child_care_rounded,
        MemoryCategory.work => Icons.handyman_rounded,
        MemoryCategory.festivals => Icons.celebration_rounded,
        MemoryCategory.food => Icons.restaurant_rounded,
        MemoryCategory.village => Icons.holiday_village_rounded,
      };
}

/// One real thing a patient told Mitra about their life — the unit of the
/// spaced-repetition memory companion. Saved once, from a genuine personal
/// story (never a quiz answer), then gently reoffered on a later day rather
/// than repeated as a question with a right answer.
///
/// This is also what furnishes the Memory Home: each fragment decorates one
/// room, keyed by [category].
@immutable
class MemoryFragment {
  const MemoryFragment({
    required this.id,
    required this.category,
    required this.summary,
    required this.createdAt,
    this.mentionedName,
    this.lastResurfacedAt,
    this.timesResurfaced = 0,
  });

  final String id;
  final MemoryCategory category;

  /// A short, warm summary of what was shared — written by the model in the
  /// patient's own words as much as possible, e.g. "Walking to school
  /// through a bamboo grove." Never a fact invented by the app.
  final String summary;

  /// A person named in the memory, if any — lets a later resurfacing be
  /// specific ("tell me about Ima again") rather than generic.
  final String? mentionedName;

  final DateTime createdAt;

  /// Null until Mitra has offered this memory back at least once.
  final DateTime? lastResurfacedAt;
  final int timesResurfaced;

  bool wasCreatedOn(DateTime day) => _isSameDay(createdAt, day);

  bool wasTouchedOn(DateTime day) =>
      wasCreatedOn(day) || (lastResurfacedAt != null && _isSameDay(lastResurfacedAt!, day));

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  MemoryFragment copyWith({DateTime? lastResurfacedAt, int? timesResurfaced}) => MemoryFragment(
        id: id,
        category: category,
        summary: summary,
        createdAt: createdAt,
        mentionedName: mentionedName,
        lastResurfacedAt: lastResurfacedAt ?? this.lastResurfacedAt,
        timesResurfaced: timesResurfaced ?? this.timesResurfaced,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'category': category.name,
        'summary': summary,
        'mentionedName': mentionedName,
        'createdAt': createdAt.toIso8601String(),
        'lastResurfacedAt': lastResurfacedAt?.toIso8601String(),
        'timesResurfaced': timesResurfaced,
      };

  static MemoryFragment? fromJson(Map<dynamic, dynamic> json) {
    final String? id = json['id'] as String?;
    final String? summary = json['summary'] as String?;
    final DateTime? createdAt = DateTime.tryParse((json['createdAt'] as String?) ?? '');
    if (id == null || summary == null || createdAt == null) return null;
    return MemoryFragment(
      id: id,
      category: MemoryCategory.values.firstWhere(
        (MemoryCategory c) => c.name == json['category'],
        orElse: () => MemoryCategory.family,
      ),
      summary: summary,
      mentionedName: json['mentionedName'] as String?,
      createdAt: createdAt,
      lastResurfacedAt: DateTime.tryParse((json['lastResurfacedAt'] as String?) ?? ''),
      timesResurfaced: (json['timesResurfaced'] as num?)?.toInt() ?? 0,
    );
  }
}

/// What a single AI turn extracted from the conversation, if the patient
/// shared something worth remembering — the app turns this into a full
/// [MemoryFragment] (assigning an id and timestamp) before persisting it.
@immutable
class SharedMemory {
  const SharedMemory({required this.category, required this.summary, this.mentionedName});

  final MemoryCategory category;
  final String summary;
  final String? mentionedName;
}
