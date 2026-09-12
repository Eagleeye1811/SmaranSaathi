import 'package:flutter/foundation.dart';

/// A language the voice assistant can work in.
///
/// The four the product commits to. Assamese is the reason this abstraction
/// exists: it is the patient's own language in the target region and it is the
/// one least likely to be installed, so "what happens when it is missing" has
/// to be a designed behaviour rather than a crash.
enum VoiceLanguage { english, hindi, assamese, marathi }

extension VoiceLanguageX on VoiceLanguage {
  /// Shown in the language picker, in the language itself.
  String get nativeLabel => switch (this) {
        VoiceLanguage.english => 'English',
        VoiceLanguage.hindi => 'हिन्दी',
        VoiceLanguage.assamese => 'অসমীয়া',
        VoiceLanguage.marathi => 'मराठी',
      };

  String get englishLabel => switch (this) {
        VoiceLanguage.english => 'English',
        VoiceLanguage.hindi => 'Hindi',
        VoiceLanguage.assamese => 'Assamese',
        VoiceLanguage.marathi => 'Marathi',
      };

  /// BCP-47-ish candidates, best first.
  ///
  /// Engines are inconsistent about separators and region tags — Android
  /// reports `en_IN`, iOS `en-IN`, some engines only `en` — so matching tries
  /// several forms rather than assuming one.
  List<String> get candidates => switch (this) {
        VoiceLanguage.english => const <String>['en_IN', 'en_US', 'en_GB', 'en'],
        VoiceLanguage.hindi => const <String>['hi_IN', 'hi'],
        VoiceLanguage.assamese => const <String>['as_IN', 'as'],
        VoiceLanguage.marathi => const <String>['mr_IN', 'mr'],
      };

  /// The two-letter code, for a loose match against an engine's list.
  String get languageCode => switch (this) {
        VoiceLanguage.english => 'en',
        VoiceLanguage.hindi => 'hi',
        VoiceLanguage.assamese => 'as',
        VoiceLanguage.marathi => 'mr',
      };

  /// Which language to try when this one is unavailable.
  ///
  /// Assamese and Marathi both degrade to Hindi before English: a speaker of
  /// either is far more likely to follow Hindi than English, so the fallback
  /// chain is ordered by who the user actually is.
  List<VoiceLanguage> get fallbacks => switch (this) {
        VoiceLanguage.assamese => const <VoiceLanguage>[
            VoiceLanguage.hindi,
            VoiceLanguage.english,
          ],
        VoiceLanguage.marathi => const <VoiceLanguage>[
            VoiceLanguage.hindi,
            VoiceLanguage.english,
          ],
        VoiceLanguage.hindi => const <VoiceLanguage>[VoiceLanguage.english],
        VoiceLanguage.english => const <VoiceLanguage>[],
      };

  /// Maps the free-text `Patient.language` field onto a voice language.
  static VoiceLanguage fromPatientLanguage(String raw) {
    final String s = raw.toLowerCase().trim();
    if (s.contains('assam') || s.contains('অসম')) return VoiceLanguage.assamese;
    if (s.contains('marathi') || s.contains('मराठ')) return VoiceLanguage.marathi;
    if (s.contains('hindi') || s.contains('हिन')) return VoiceLanguage.hindi;
    return VoiceLanguage.english;
  }
}

/// The outcome of matching a wanted language against what a device has.
@immutable
class ResolvedVoiceLanguage {
  const ResolvedVoiceLanguage({
    required this.requested,
    required this.resolved,
    required this.localeId,
  });

  /// What the patient's profile asked for.
  final VoiceLanguage requested;

  /// What the device can actually do. Equal to [requested] when supported.
  final VoiceLanguage? resolved;

  /// The exact engine locale id to pass through, e.g. `hi_IN`.
  final String? localeId;

  bool get isExactMatch => resolved == requested;
  bool get isSupported => resolved != null && localeId != null;

  /// True when we had to step down to another language — the UI says so, so
  /// nobody is confused about why Saathi suddenly switched to Hindi.
  bool get isFallback => isSupported && !isExactMatch;

  @override
  String toString() =>
      'ResolvedVoiceLanguage(${requested.name} → ${resolved?.name} [$localeId])';
}

/// Matches wanted languages against an engine's advertised locale list.
///
/// Pure and synchronous, so every branch is testable without a device.
class VoiceLanguageResolver {
  const VoiceLanguageResolver();

  /// Picks the best locale id [wanted] can use from [available].
  ///
  /// Tries exact candidates first, then a loose language-code match (so an
  /// engine advertising only `hi-IN-x-variant` still counts as Hindi), then
  /// walks the fallback chain.
  ResolvedVoiceLanguage resolve(VoiceLanguage wanted, List<String> available) {
    if (available.isEmpty) {
      return ResolvedVoiceLanguage(requested: wanted, resolved: null, localeId: null);
    }

    final List<String> normalised =
        available.map((String s) => s.replaceAll('-', '_')).toList(growable: false);

    for (final VoiceLanguage attempt in <VoiceLanguage>[wanted, ...wanted.fallbacks]) {
      // Exact candidate.
      for (final String candidate in attempt.candidates) {
        final int i = normalised.indexWhere(
            (String a) => a.toLowerCase() == candidate.toLowerCase());
        if (i >= 0) {
          return ResolvedVoiceLanguage(
            requested: wanted,
            resolved: attempt,
            localeId: available[i],
          );
        }
      }
      // Loose match on the language code.
      final int i = normalised.indexWhere((String a) =>
          a.toLowerCase() == attempt.languageCode ||
          a.toLowerCase().startsWith('${attempt.languageCode}_'));
      if (i >= 0) {
        return ResolvedVoiceLanguage(
          requested: wanted,
          resolved: attempt,
          localeId: available[i],
        );
      }
    }

    return ResolvedVoiceLanguage(requested: wanted, resolved: null, localeId: null);
  }
}
