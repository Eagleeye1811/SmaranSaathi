import 'package:flutter/foundation.dart';

/// How large the patient's type is rendered.
///
/// This is a *product* setting rather than an OS one: the caregiver enlarges
/// the type on the patient's behalf, so it has to persist with the profile and
/// not with the device's accessibility settings.
enum TextSizePreference { normal, large, extraLarge }

extension TextSizePreferenceX on TextSizePreference {
  String get label => switch (this) {
        TextSizePreference.normal => 'Normal',
        TextSizePreference.large => 'Large',
        TextSizePreference.extraLarge => 'Extra large',
      };

  double get scale => switch (this) {
        TextSizePreference.normal => 1.0,
        TextSizePreference.large => 1.14,
        TextSizePreference.extraLarge => 1.3,
      };
}

/// Everything under Settings that has to survive a restart.
@immutable
class AppSettings {
  const AppSettings({
    this.textSize = TextSizePreference.large,
    this.highContrast = false,
    this.reduceMotion = false,
    this.voicePrompts = true,
    this.offlineOverride = false,
    this.lastRole,
    this.lastAccountId,
    this.safeZoneJson,
    this.localeCode,
  });

  final TextSizePreference textSize;
  final bool highContrast;
  final bool reduceMotion;
  final bool voicePrompts;

  /// The interface language, as an `en`/`hi`/`as`/`mr` code — whatever was
  /// last picked in `LanguageSelector`. Null means it has never been changed
  /// from the default (English), not that a choice was lost.
  final String? localeCode;

  /// The caregiver's manual "work offline" switch, distinct from the device
  /// actually having no connection.
  final bool offlineOverride;

  /// Which role the app was last used as, so a returning caregiver is not sent
  /// back through the role picker.
  final String? lastRole;

  /// The Firebase uid whose assessment this device last worked on.
  ///
  /// Persisted so a restart reopens the same person's intake *before* anyone
  /// has signed in again — the app is offline-first, and losing a
  /// half-finished questionnaire because the network was down at launch would
  /// defeat the point of storing it locally at all.
  final String? lastAccountId;

  /// The patient's safe zone, encoded by [SafeZone.encode].
  ///
  /// Stored as a string rather than as its own Hive type because it is one
  /// small record with one owner — a type adapter, a type id and a box would
  /// be three more things to migrate for no gain.
  final String? safeZoneJson;

  AppSettings copyWith({
    TextSizePreference? textSize,
    bool? highContrast,
    bool? reduceMotion,
    bool? voicePrompts,
    bool? offlineOverride,
    String? lastRole,
    String? lastAccountId,
    String? safeZoneJson,
    bool clearSafeZone = false,
    String? localeCode,
  }) {
    return AppSettings(
      textSize: textSize ?? this.textSize,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      voicePrompts: voicePrompts ?? this.voicePrompts,
      offlineOverride: offlineOverride ?? this.offlineOverride,
      lastRole: lastRole ?? this.lastRole,
      lastAccountId: lastAccountId ?? this.lastAccountId,
      safeZoneJson:
          clearSafeZone ? null : (safeZoneJson ?? this.safeZoneJson),
      localeCode: localeCode ?? this.localeCode,
    );
  }
}
