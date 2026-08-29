import 'package:flutter/foundation.dart';

/// What kind of local change is waiting to reach the server.
///
/// The queue is deliberately coarse — one entry per user-meaningful action,
/// not per field write — so a caregiver reading the pending count sees
/// something they can reason about ("3 activities waiting").
enum SyncOperationKind {
  gameSession,
  moodCheckIn,
  journalEntry,
  reminderToggle,
  profileUpdate,
  reflection,
  assessmentUpdate,
  baselineCaptured,
  reminderCreate,
  unknown,
}

extension SyncOperationKindX on SyncOperationKind {
  String get label => switch (this) {
        SyncOperationKind.gameSession => 'Activity result',
        SyncOperationKind.moodCheckIn => 'Mood check-in',
        SyncOperationKind.journalEntry => 'Memory journal entry',
        SyncOperationKind.reminderToggle => 'Reminder update',
        SyncOperationKind.profileUpdate => 'Profile update',
        SyncOperationKind.reflection => 'Evening reflection',
        SyncOperationKind.assessmentUpdate => 'Assessment answers',
        SyncOperationKind.baselineCaptured => 'Cognitive baseline',
        SyncOperationKind.reminderCreate => 'Reminder created',
        SyncOperationKind.unknown => 'Pending change',
      };
}

enum SyncStatus { pending, syncing, synced, failed }

/// One durable entry in the outbox.
///
/// Written to Hive *in the same call* as the change it describes, so a crash
/// between "user acted" and "queued for sync" cannot lose the action.
@immutable
class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAtMillis,
    this.status = SyncStatus.pending,
    this.attempts = 0,
    this.syncedAtMillis,
    this.lastError,
  });

  final String id;
  final SyncOperationKind kind;

  /// Enough detail to replay the change against a real API later. Values are
  /// restricted to Hive-primitive types (String, num, bool, List, Map).
  final Map<String, dynamic> payload;

  final int createdAtMillis;
  final SyncStatus status;
  final int attempts;
  final int? syncedAtMillis;
  final String? lastError;

  bool get isPending => status == SyncStatus.pending || status == SyncStatus.failed;

  PendingOperation copyWith({
    SyncStatus? status,
    int? attempts,
    int? syncedAtMillis,
    String? lastError,
  }) {
    return PendingOperation(
      id: id,
      kind: kind,
      payload: payload,
      createdAtMillis: createdAtMillis,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      syncedAtMillis: syncedAtMillis ?? this.syncedAtMillis,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  String toString() => 'PendingOperation(${kind.name}, $status, attempts: $attempts)';
}
