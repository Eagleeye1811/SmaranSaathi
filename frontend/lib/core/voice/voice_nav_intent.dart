import 'package:flutter/foundation.dart';

import 'voice_language.dart';

/// A place in the app the voice assistant can take someone to.
///
/// One enum for all three roles rather than one per shell: the matcher stays a
/// single pure table, and each shell declares only the destinations it can
/// actually reach ([VoiceNavHandler]). Asking the doctor app for the memory
/// wallet is then a *spoken* answer — "you cannot get there from here" — not a
/// silent no-op, which is the difference between a voice interface people
/// trust and one they stop using.
enum VoiceDestination {
  // ── Patient ──────────────────────────────────────────────────────────
  home,
  today,
  activities,
  companion,
  profile,
  memories,
  memoryLane,
  carePlan,
  report,
  progress,
  settings,

  // ── Caregiver ────────────────────────────────────────────────────────
  dashboard,
  patient,
  activityLog,
  reminders,
  safeZone,

  // ── Doctor ───────────────────────────────────────────────────────────
  overview,
  patients,
  analytics,
  alerts,
}

/// A spoken instruction that moves nothing but the flow itself.
enum VoiceNavAction {
  /// Close the current screen — "go back", "पीछे", "উভতি যাওক".
  back,

  /// Say what can be said. The list of destinations, read aloud.
  help,

  /// Leave voice navigation.
  stop,
}

/// What a piece of speech turned out to mean.
@immutable
class VoiceNavIntent {
  const VoiceNavIntent.destination(VoiceDestination this.destination, this.transcript)
      : action = null;
  const VoiceNavIntent.action(VoiceNavAction this.action, this.transcript)
      : destination = null;
  const VoiceNavIntent.none(this.transcript)
      : destination = null,
        action = null;

  final VoiceDestination? destination;
  final VoiceNavAction? action;

  /// What was actually heard, kept so the panel can show it back.
  final String transcript;

  bool get isDestination => destination != null;
  bool get isAction => action != null;
  bool get isNothing => destination == null && action == null;

  @override
  String toString() =>
      'VoiceNavIntent(${destination?.name ?? action?.name ?? 'none'}, "$transcript")';
}

/// Turns a transcript into a navigation intent.
///
/// Pure and synchronous — every branch is testable without a microphone.
///
/// The phrase table merges all three languages into one list per destination
/// instead of keying by language, and that is deliberate. Code-switching is
/// the norm in the North East: someone with the app in Assamese will still say
/// "home" or "game", and a Hindi speaker will say "report". Splitting the
/// tables by language would reject exactly the sentences real users produce.
/// Scripts do not collide, so merging costs nothing.
class VoiceNavMatcher {
  const VoiceNavMatcher();

  /// Phrases per destination. Order inside a list does not matter; the matcher
  /// prefers the *longest* matching phrase across the whole table, so
  /// "care plan" wins over the bare "plan" and "memory profile" over "memory".
  static const Map<VoiceDestination, List<String>> phrases =
      <VoiceDestination, List<String>>{
    VoiceDestination.home: <String>[
      'home', 'home screen', 'main screen', 'go home', 'front page', 'start screen',
      'ghar', 'mukhya', 'होम', 'घर', 'मुख्य पृष्ठ', 'मुख्य',
      'ঘৰ', 'হোম', 'মূল পৰ্দা', 'মূল',
    ],
    VoiceDestination.today: <String>[
      'today', 'todays', 'my day', 'schedule', 'medicine', 'medicines', 'tablet',
      'aaj', 'aaj ka din', 'dawa', 'davai',
      'आज', 'आज का दिन', 'दवा', 'दवाई', 'गोली',
      'আজি', 'ঔষধ', 'আজিৰ দিন',
    ],
    VoiceDestination.activities: <String>[
      'activities', 'activity', 'games', 'game', 'play', 'puzzle', 'exercise',
      'khel', 'khelo',
      'खेल', 'गेम', 'खेलना', 'गतिविधि',
      'খেল', 'খেলা', 'ধেমালি',
    ],
    VoiceDestination.companion: <String>[
      'companion', 'assistant', 'mitra', 'talk', 'chat', 'ask mitra', 'talk to mitra',
      'baat', 'baat karo', 'saathi',
      'साथी', 'मित्रा', 'बात', 'बात करो', 'बातचीत',
      'সংগী', 'কথা', 'কথা পাতো', 'মিত্ৰা',
    ],
    VoiceDestination.profile: <String>[
      'profile', 'my profile', 'about me', 'my details', 'account',
      'meri jankari', 'prophile',
      'प्रोफाइल', 'प्रोफ़ाइल', 'मेरी जानकारी', 'खाता',
      'প্ৰফাইল', 'মোৰ তথ্য',
    ],
    VoiceDestination.memories: <String>[
      'memories', 'memory wallet', 'my memories', 'photos', 'photo', 'album', 'pictures',
      'yaadein', 'yaad', 'tasveer',
      'यादें', 'याद', 'तस्वीर', 'फोटो', 'यादों का बटुआ',
      'স্মৃতি', 'ফটো', 'ছবি', 'মোৰ স্মৃতি',
    ],
    VoiceDestination.memoryLane: <String>[
      'memory lane', 'memory home', 'my people', 'family', 'my family',
      'parivar', 'ghar wale',
      'परिवार', 'मेरा परिवार', 'अपने लोग',
      'পৰিয়াল', 'মোৰ পৰিয়াল',
    ],
    VoiceDestination.carePlan: <String>[
      'care plan', 'my plan', 'plan', 'daily plan',
      'yojana', 'dekhbhal',
      'देखभाल', 'देखभाल योजना', 'योजना',
      'যত্ন', 'যত্নৰ পৰিকল্পনা', 'পৰিকল্পনা',
    ],
    VoiceDestination.report: <String>[
      'report', 'my report', 'health report', 'summary', 'doctor report',
      'riport',
      'रिपोर्ट', 'मेरी रिपोर्ट', 'सारांश',
      'ৰিপৰ্ট', 'প্ৰতিবেদন', 'মোৰ ৰিপৰ্ট',
    ],
    VoiceDestination.progress: <String>[
      'progress', 'my progress', 'cognitive profile', 'score', 'scores', 'how am i doing',
      'pragati',
      'प्रगति', 'मेरी प्रगति', 'स्कोर',
      'অগ্ৰগতি', 'মোৰ অগ্ৰগতি', 'নম্বৰ',
    ],
    VoiceDestination.settings: <String>[
      'settings', 'setting', 'language', 'change language', 'text size',
      'bhasha', 'setting badlo',
      'सेटिंग', 'सेटिंग्स', 'भाषा', 'भाषा बदलो',
      'ছেটিং', 'ভাষা', 'ভাষা সলনি',
    ],
    VoiceDestination.dashboard: <String>[
      'dashboard', 'overview screen',
      'डैशबोर्ड', 'मुख्य पट',
      'ডেশ্ববৰ্ড',
    ],
    VoiceDestination.patient: <String>[
      'patient', 'patient profile', 'memory profile', 'their profile',
      'mareez', 'rogi',
      'मरीज', 'मरीज़', 'रोगी', 'रोगी की जानकारी',
      'ৰোগী', 'ৰোগীৰ তথ্য',
    ],
    VoiceDestination.activityLog: <String>[
      // "activity" is deliberately shared with `activities`. The reachable set
      // is searched first, so the patient shell hears its games and the
      // caregiver shell hears its log — one word, the right meaning in each.
      'activity', 'activities', 'activity log', 'insights', 'their activity', 'history',
      'गतिविधि', 'इतिहास',
      'কাৰ্যকলাপ', 'ইতিহাস',
    ],
    VoiceDestination.reminders: <String>[
      'reminders', 'reminder', 'alarms', 'alarm',
      'yaad dilana', 'reminder lagao',
      'रिमाइंडर', 'याद दिलाना', 'अलार्म',
      'মনত পেলোৱা', 'এলাৰ্ম',
    ],
    VoiceDestination.safeZone: <String>[
      'safe zone', 'safezone', 'map', 'location', 'where are they', 'track',
      'surakshit', 'jagah',
      'सुरक्षित क्षेत्र', 'नक्शा', 'जगह', 'कहाँ है',
      'সুৰক্ষিত অঞ্চল', 'মানচিত্ৰ', 'ক\'ত আছে',
    ],
    VoiceDestination.overview: <String>[
      'overview', 'clinic overview',
      'अवलोकन', 'सारांश पट',
      'সাধাৰণ দৃশ্য', 'অৱলোকন',
    ],
    VoiceDestination.patients: <String>[
      'patients', 'my patients', 'patient list',
      'mareezon', 'sabhi rogi',
      'मरीजों', 'रोगियों', 'मरीज सूची',
      'ৰোগীসকল', 'ৰোগীৰ তালিকা',
    ],
    VoiceDestination.analytics: <String>[
      'analytics', 'statistics', 'stats', 'charts', 'trends',
      'vishleshan',
      'विश्लेषण', 'आंकड़े',
      'বিশ্লেষণ', 'পৰিসংখ্যা',
    ],
    VoiceDestination.alerts: <String>[
      'alerts', 'alert', 'warnings', 'notifications',
      'chetavani',
      'अलर्ट', 'चेतावनी', 'सूचना',
      'সতৰ্কবাণী', 'জাননী',
    ],
  };

  static const Map<VoiceNavAction, List<String>> actionPhrases =
      <VoiceNavAction, List<String>>{
    VoiceNavAction.back: <String>[
      'back', 'go back', 'previous', 'return', 'close this',
      'peeche', 'wapas', 'peeche jao',
      'पीछे', 'वापस', 'वापिस', 'पिछला',
      'উভতি', 'উভতি যাওক', 'পিছলৈ',
    ],
    VoiceNavAction.help: <String>[
      'help', 'what can i say', 'what can you do', 'options', 'commands',
      'madad', 'kya bol sakta hun',
      'मदद', 'सहायता', 'क्या बोलूं',
      'সহায়', 'সহায়ক', 'কি ক\'ব পাৰোঁ',
    ],
    VoiceNavAction.stop: <String>[
      'stop', 'cancel', 'quit', 'exit', 'never mind', 'nothing',
      'bas', 'ruko', 'band karo',
      'रुको', 'बंद करो', 'रहने दो',
      'বন্ধ', 'বন্ধ কৰক', 'এৰি দিয়ক',
    ],
  };

  /// Filler that surrounds a real instruction and must not defeat matching:
  /// "please take me to the report page" has to reach `report`.
  static final RegExp _filler = RegExp(
    r'\b(please|kindly|can you|could you|i want to|i would like to|take me to|'
    r'go to|open|show me|show|navigate to|move to|switch to|let us|lets|'
    r'the|a|an|page|screen|section|tab|now|mitra)\b',
  );

  /// Lowercases and strips punctuation while keeping every Unicode letter and
  /// every combining mark.
  ///
  /// `\p{M}` is the part that is easy to miss and expensive to get wrong:
  /// Devanagari matras and the Assamese virama are marks, not letters, so a
  /// `[^\p{L}\p{N}]` filter silently turns `ৰিপৰ্ট` into `ৰপৰট` and
  /// `पीछे` into `पछ` — every non-Latin phrase stops matching, and only the
  /// two languages we exist to serve are affected.
  static String normalise(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\p{M}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// What [transcript] means.
  ///
  /// [allowed] *biases* matching towards the destinations the current shell
  /// can reach, so the caregiver app hearing "activity" resolves to its
  /// activity log rather than the patient's games. It does not filter: a place
  /// this shell cannot open still resolves, so the controller can say
  /// "I cannot open that from here" instead of appearing not to have heard —
  /// which is the difference between a limit and a fault.
  VoiceNavIntent match(String transcript, {Set<VoiceDestination>? allowed}) {
    final String said = normalise(transcript);
    if (said.isEmpty) return VoiceNavIntent.none(transcript);

    // Strip the polite scaffolding, then keep both forms: "open the report"
    // becomes "report", but "go back" must survive, so the stripped form is
    // only used when it still has words in it.
    final String stripped =
        said.replaceAll(_filler, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final List<String> haystacks =
        stripped.isEmpty ? <String>[said] : <String>[stripped, said];

    // An action wins over a destination: "go back" contains no place name, and
    // "stop" must always be obeyable even mid-flow.
    for (final MapEntry<VoiceNavAction, List<String>> e in actionPhrases.entries) {
      for (final String phrase in e.value) {
        if (haystacks.any((String h) => _contains(h, phrase))) {
          return VoiceNavIntent.action(e.key, transcript);
        }
      }
    }

    // Reachable destinations are searched first; only if none match do we
    // look at the rest.
    final VoiceDestination? here = _best(haystacks, allowed);
    if (here != null) return VoiceNavIntent.destination(here, transcript);

    if (allowed != null && allowed.isNotEmpty) {
      final VoiceDestination? elsewhere = _best(haystacks, null);
      if (elsewhere != null) return VoiceNavIntent.destination(elsewhere, transcript);
    }

    // ── Nothing matched cleanly. Try again, tolerating misheard words. ──
    //
    // This is the branch that decides whether the feature survives a real
    // room. A fan, a television or a hard-of-hearing speaker turns "activities"
    // into "activity is", "a p titties", "activitis" — all of which are one or
    // two edits away from a phrase we know, and none of which contain it. The
    // exact passes above stay first because they are cheap and certain; this
    // runs only when they have already failed.
    for (final String haystack in haystacks) {
      final VoiceNavAction? action = _closestAction(haystack);
      if (action != null) return VoiceNavIntent.action(action, transcript);

      final VoiceDestination? near =
          _closest(haystack, allowed) ?? (allowed == null ? null : _closest(haystack, null));
      if (near != null) return VoiceNavIntent.destination(near, transcript);
    }
    return VoiceNavIntent.none(transcript);
  }

  /// Shortest phrase worth correcting at all.
  ///
  /// Below this, near-misses are indistinguishable from ordinary speech: at
  /// four letters "what" is one edit from "chat", so a passing remark about
  /// the weather would open the companion. Short phrases still match exactly,
  /// which is all they ever needed.
  static const int _minFuzzyLength = 5;

  /// How many single-character mistakes a phrase may absorb — roughly a
  /// quarter of it, never more than three.
  ///
  /// Proportional rather than flat, because one wrong letter in "today" is a
  /// different word while two wrong letters in "activities" is obviously
  /// still "activities".
  static int _budget(String phrase) => (phrase.length ~/ 4).clamp(1, 3);

  /// The destination nearest to [said], or null when nothing is near enough.
  ///
  /// Compares each phrase against every same-length *window* of words in the
  /// transcript, so a place name buried in a noisy sentence is still found.
  VoiceDestination? _closest(String said, Set<VoiceDestination>? within) {
    final List<String> words =
        said.split(' ').where((String w) => w.isNotEmpty).toList(growable: false);
    if (words.isEmpty) return null;

    final List<({VoiceDestination destination, int edits, int length})> hits =
        <({VoiceDestination destination, int edits, int length})>[];

    for (final MapEntry<VoiceDestination, List<String>> e in phrases.entries) {
      if (within != null && !within.contains(e.key)) continue;
      final ({int edits, int length})? hit = _nearestPhrase(words, e.value);
      if (hit != null) {
        hits.add((destination: e.key, edits: hit.edits, length: hit.length));
      }
    }
    if (hits.isEmpty) return null;

    // Fewest mistakes wins; between equals, the longer phrase is the more
    // specific evidence.
    hits.sort((({VoiceDestination destination, int edits, int length}) a,
            ({VoiceDestination destination, int edits, int length}) b) =>
        a.edits != b.edits ? a.edits.compareTo(b.edits) : b.length.compareTo(a.length));

    // Two destinations equally close is not a near miss, it is a coin toss.
    // Opening the wrong screen for someone with memory difficulty costs more
    // than asking them to say it again, so we refuse.
    if (hits.length > 1 &&
        hits[1].edits == hits[0].edits &&
        hits[1].length == hits[0].length) {
      return null;
    }
    return hits.first.destination;
  }

  VoiceNavAction? _closestAction(String said) {
    final List<String> words =
        said.split(' ').where((String w) => w.isNotEmpty).toList(growable: false);
    if (words.isEmpty) return null;

    VoiceNavAction? best;
    int bestEdits = 1 << 30;
    int bestLength = 0;
    bool tied = false;

    for (final MapEntry<VoiceNavAction, List<String>> e in actionPhrases.entries) {
      final ({int edits, int length})? hit = _nearestPhrase(words, e.value);
      if (hit == null) continue;
      if (hit.edits < bestEdits || (hit.edits == bestEdits && hit.length > bestLength)) {
        best = e.key;
        bestEdits = hit.edits;
        bestLength = hit.length;
        tied = false;
      } else if (hit.edits == bestEdits && hit.length == bestLength) {
        tied = true;
      }
    }
    return tied ? null : best;
  }

  /// The best any phrase in [candidates] does against a window of [words].
  ({int edits, int length})? _nearestPhrase(List<String> words, List<String> candidates) {
    int bestEdits = 1 << 30;
    int bestLength = 0;

    for (final String phrase in candidates) {
      if (phrase.length < _minFuzzyLength) continue;
      final int budget = _budget(phrase);
      final int span = phrase.split(' ').length;
      if (span > words.length) continue;

      for (int i = 0; i + span <= words.length; i++) {
        final String window = words.sublist(i, i + span).join(' ');
        final int edits = _distance(window, phrase, budget);
        if (edits > budget) continue;
        if (edits < bestEdits || (edits == bestEdits && phrase.length > bestLength)) {
          bestEdits = edits;
          bestLength = phrase.length;
        }
      }
    }
    return bestLength == 0 ? null : (edits: bestEdits, length: bestLength);
  }

  /// Levenshtein distance, abandoned as soon as it passes [max].
  ///
  /// The early exit is what keeps this affordable: most phrase/window pairs
  /// are wildly different and bail out after one row.
  static int _distance(String a, String b, int max) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > max) return max + 1;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> prev = List<int>.generate(b.length + 1, (int i) => i);
    List<int> curr = List<int>.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      int rowMin = i;
      for (int j = 1; j <= b.length; j++) {
        final int cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        int value = prev[j - 1] + cost;
        final int deletion = prev[j] + 1;
        final int insertion = curr[j - 1] + 1;
        if (deletion < value) value = deletion;
        if (insertion < value) value = insertion;
        curr[j] = value;
        if (value < rowMin) rowMin = value;
      }
      if (rowMin > max) return max + 1;
      final List<int> swap = prev;
      prev = curr;
      curr = swap;
    }
    return prev[b.length];
  }

  /// The destination whose *longest* phrase appears in one of [haystacks], so
  /// a specific place beats a generic one it contains ("care plan" over
  /// "plan", "memory lane" over "memories").
  VoiceDestination? _best(List<String> haystacks, Set<VoiceDestination>? within) {
    VoiceDestination? best;
    int bestLength = 0;
    for (final MapEntry<VoiceDestination, List<String>> e in phrases.entries) {
      if (within != null && !within.contains(e.key)) continue;
      for (final String phrase in e.value) {
        if (phrase.length <= bestLength) continue;
        if (haystacks.any((String h) => _contains(h, phrase))) {
          best = e.key;
          bestLength = phrase.length;
        }
      }
    }
    return best;
  }

  /// Whole-word containment. Works for Devanagari and Assamese too, because
  /// both are written with spaces between words and the guard is a space or a
  /// string boundary rather than `\b`, which is ASCII-only in Dart.
  static bool _contains(String haystack, String needle) {
    if (needle.isEmpty) return false;
    return RegExp('(^| )${RegExp.escape(needle)}( |\$)').hasMatch(haystack);
  }
}

/// The name of a destination, in the language being spoken.
///
/// Separate from the ARB strings on purpose: these are *spoken* back through
/// text-to-speech in the voice language, which is not always the interface
/// language — a device with no Assamese TTS falls back to Hindi, and the
/// confirmation has to be in the language actually being spoken.
String voiceDestinationLabel(VoiceDestination d, VoiceLanguage language) =>
    switch (language) {
      VoiceLanguage.english => _labelsEn[d]!,
      VoiceLanguage.hindi => _labelsHi[d]!,
      VoiceLanguage.assamese => _labelsAs[d]!,
    };

const Map<VoiceDestination, String> _labelsEn = <VoiceDestination, String>{
  VoiceDestination.home: 'Home',
  VoiceDestination.today: 'Today',
  VoiceDestination.activities: 'Activities',
  VoiceDestination.companion: 'Companion',
  VoiceDestination.profile: 'Profile',
  VoiceDestination.memories: 'Memories',
  VoiceDestination.memoryLane: 'Memory lane',
  VoiceDestination.carePlan: 'Care plan',
  VoiceDestination.report: 'Report',
  VoiceDestination.progress: 'Progress',
  VoiceDestination.settings: 'Settings',
  VoiceDestination.dashboard: 'Dashboard',
  VoiceDestination.patient: 'Patient',
  VoiceDestination.activityLog: 'Activity',
  VoiceDestination.reminders: 'Reminders',
  VoiceDestination.safeZone: 'Safe zone',
  VoiceDestination.overview: 'Overview',
  VoiceDestination.patients: 'Patients',
  VoiceDestination.analytics: 'Analytics',
  VoiceDestination.alerts: 'Alerts',
};

const Map<VoiceDestination, String> _labelsHi = <VoiceDestination, String>{
  VoiceDestination.home: 'होम',
  VoiceDestination.today: 'आज',
  VoiceDestination.activities: 'गतिविधियाँ',
  VoiceDestination.companion: 'साथी',
  VoiceDestination.profile: 'प्रोफ़ाइल',
  VoiceDestination.memories: 'यादें',
  VoiceDestination.memoryLane: 'परिवार',
  VoiceDestination.carePlan: 'देखभाल योजना',
  VoiceDestination.report: 'रिपोर्ट',
  VoiceDestination.progress: 'प्रगति',
  VoiceDestination.settings: 'सेटिंग',
  VoiceDestination.dashboard: 'डैशबोर्ड',
  VoiceDestination.patient: 'रोगी',
  VoiceDestination.activityLog: 'गतिविधि',
  VoiceDestination.reminders: 'रिमाइंडर',
  VoiceDestination.safeZone: 'सुरक्षित क्षेत्र',
  VoiceDestination.overview: 'अवलोकन',
  VoiceDestination.patients: 'रोगी सूची',
  VoiceDestination.analytics: 'विश्लेषण',
  VoiceDestination.alerts: 'चेतावनी',
};

const Map<VoiceDestination, String> _labelsAs = <VoiceDestination, String>{
  VoiceDestination.home: 'ঘৰ',
  VoiceDestination.today: 'আজি',
  VoiceDestination.activities: 'কাম',
  VoiceDestination.companion: 'সংগী',
  VoiceDestination.profile: 'প্ৰফাইল',
  VoiceDestination.memories: 'স্মৃতি',
  VoiceDestination.memoryLane: 'পৰিয়াল',
  VoiceDestination.carePlan: 'যত্নৰ পৰিকল্পনা',
  VoiceDestination.report: 'ৰিপৰ্ট',
  VoiceDestination.progress: 'অগ্ৰগতি',
  VoiceDestination.settings: 'ছেটিং',
  VoiceDestination.dashboard: 'ডেশ্ববৰ্ড',
  VoiceDestination.patient: 'ৰোগী',
  VoiceDestination.activityLog: 'কাৰ্যকলাপ',
  VoiceDestination.reminders: 'মনত পেলোৱা',
  VoiceDestination.safeZone: 'সুৰক্ষিত অঞ্চল',
  VoiceDestination.overview: 'অৱলোকন',
  VoiceDestination.patients: 'ৰোগীসকল',
  VoiceDestination.analytics: 'বিশ্লেষণ',
  VoiceDestination.alerts: 'সতৰ্কবাণী',
};

/// Everything the assistant says while navigating, in all three languages.
///
/// Short sentences by design: a confirmation that takes four seconds to read
/// is slower than the tap it replaced.
class VoiceNavSpeech {
  const VoiceNavSpeech._();

  /// The question asked aloud the moment the microphone opens.
  static String prompt(VoiceLanguage l) => switch (l) {
        VoiceLanguage.english => 'What should I do for you?',
        VoiceLanguage.hindi => 'मैं आपके लिए क्या करूँ?',
        VoiceLanguage.assamese => 'মই আপোনাৰ বাবে কি কৰিম?',
      };

  /// Spoken as the screen changes.
  static String opening(VoiceLanguage l, String place) => switch (l) {
        VoiceLanguage.english => 'Opening $place.',
        VoiceLanguage.hindi => '$place खोल रहे हैं।',
        VoiceLanguage.assamese => '$place খুলি আছোঁ।',
      };

  /// The words were understood, but this shell cannot reach that place.
  static String unavailable(VoiceLanguage l, String place) => switch (l) {
        VoiceLanguage.english => 'I cannot open $place from here.',
        VoiceLanguage.hindi => 'यहाँ से मैं $place नहीं खोल सकती।',
        VoiceLanguage.assamese => 'ইয়াৰ পৰা মই $place খুলিব নোৱাৰোঁ।',
      };

  static String notUnderstood(VoiceLanguage l) => switch (l) {
        VoiceLanguage.english => 'I did not catch a place name. Say help to hear the list.',
        VoiceLanguage.hindi => 'मुझे जगह समझ नहीं आई। सूची सुनने के लिए मदद कहिए।',
        VoiceLanguage.assamese => 'ঠাইৰ নাম বুজি নাপালোঁ। তালিকা শুনিবলৈ সহায় বুলি কওক।',
      };

  static String goingBack(VoiceLanguage l) => switch (l) {
        VoiceLanguage.english => 'Going back.',
        VoiceLanguage.hindi => 'वापस जा रहे हैं।',
        VoiceLanguage.assamese => 'উভতি যাওঁ।',
      };

  /// Read when someone asks what they can say. [places] is already localised.
  static String help(VoiceLanguage l, List<String> places) {
    final String list = places.join(', ');
    return switch (l) {
      VoiceLanguage.english => 'You can say: $list. Or say back, or stop.',
      VoiceLanguage.hindi => 'आप कह सकते हैं: $list। या पीछे, या रुको।',
      VoiceLanguage.assamese => 'আপুনি ক\'ব পাৰে: $list। বা উভতি, বা বন্ধ।',
    };
  }
}
