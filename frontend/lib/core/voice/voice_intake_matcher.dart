/// Turning what someone said into an answer.
///
/// Kept pure and separate from the microphone: matching spoken words to
/// options is where nearly all the difficulty lives, and it is exactly the
/// part that must be testable without a device. Nothing here touches a
/// plugin, a controller or a widget.
library;

/// A spoken instruction that is not an answer to the question.
enum VoiceIntakeCommand {
  /// Move on — the next question, or the next screen when this was the last.
  next,

  /// Go back a question or a screen.
  back,

  /// Read the question out again.
  repeat,

  /// Leave voice mode.
  stop,
}

/// What a piece of speech turned out to mean.
class VoiceIntakeMatch {
  const VoiceIntakeMatch.option(this.optionIndex) : command = null;
  const VoiceIntakeMatch.instruction(this.command) : optionIndex = null;
  const VoiceIntakeMatch.none()
      : optionIndex = null,
        command = null;

  final int? optionIndex;
  final VoiceIntakeCommand? command;

  bool get isOption => optionIndex != null;
  bool get isCommand => command != null;
  bool get isNothing => optionIndex == null && command == null;
}

/// Matches a transcript against the options on screen.
///
/// Deliberately generous. Someone answering a health questionnaire out loud
/// says "yes it happens sometimes", not "sometimes" — and an engine that only
/// accepts the exact label would make voice slower than tapping. So an answer
/// is accepted when the option's words appear anywhere in the sentence, and
/// the position of the option in the list can be spoken instead ("number
/// two", "the first one").
///
/// It refuses rather than guesses when two options match equally well: a
/// wrong answer silently recorded in a clinical questionnaire is worse than
/// being asked again.
class VoiceIntakeMatcher {
  const VoiceIntakeMatcher();

  static const Map<String, VoiceIntakeCommand> _commands =
      <String, VoiceIntakeCommand>{
    'next': VoiceIntakeCommand.next,
    'continue': VoiceIntakeCommand.next,
    'go on': VoiceIntakeCommand.next,
    'go ahead': VoiceIntakeCommand.next,
    'carry on': VoiceIntakeCommand.next,
    'done': VoiceIntakeCommand.next,
    'aage': VoiceIntakeCommand.next,
    'agla': VoiceIntakeCommand.next,
    'আগবাঢ়ক': VoiceIntakeCommand.next,
    'পৰৱৰ্তী': VoiceIntakeCommand.next,
    'পিছৰ': VoiceIntakeCommand.next,
    'আগলৈ': VoiceIntakeCommand.next,
    'अगला': VoiceIntakeCommand.next,
    'आगे': VoiceIntakeCommand.next,
    'back': VoiceIntakeCommand.back,
    'go back': VoiceIntakeCommand.back,
    'previous': VoiceIntakeCommand.back,
    'peeche': VoiceIntakeCommand.back,
    'উভতি': VoiceIntakeCommand.back,
    'পিছলৈ': VoiceIntakeCommand.back,
    'पीछे': VoiceIntakeCommand.back,
    'वापस': VoiceIntakeCommand.back,
    'repeat': VoiceIntakeCommand.repeat,
    'again': VoiceIntakeCommand.repeat,
    'say again': VoiceIntakeCommand.repeat,
    'pardon': VoiceIntakeCommand.repeat,
    'what': VoiceIntakeCommand.repeat,
    'phir se': VoiceIntakeCommand.repeat,
    'আকৌ': VoiceIntakeCommand.repeat,
    'দোহাৰক': VoiceIntakeCommand.repeat,
    'दोबारा': VoiceIntakeCommand.repeat,
    'फिर से': VoiceIntakeCommand.repeat,
    'stop': VoiceIntakeCommand.stop,
    'cancel': VoiceIntakeCommand.stop,
    'quit': VoiceIntakeCommand.stop,
    'exit': VoiceIntakeCommand.stop,
    'bas': VoiceIntakeCommand.stop,
    'বন্ধ': VoiceIntakeCommand.stop,
    'ৰখক': VoiceIntakeCommand.stop,
    'रुको': VoiceIntakeCommand.stop,
    'बंद': VoiceIntakeCommand.stop,
  };

  /// Spoken positions, 1-based. Longest forms first so "twenty" never eats
  /// the "two" inside it.
  static const List<List<String>> _positions = <List<String>>[
    <String>['first', 'one', '1', 'number one', 'pehla', 'पहला', '১', 'প্ৰথম', 'এক'],
    <String>['second', 'two', '2', 'number two', 'dusra', 'दूसरा', '২', 'দ্বিতীয়', 'দুই'],
    <String>['third', 'three', '3', 'number three', 'teesra', 'तीसरा', '৩', 'তৃতীয়', 'তিনি'],
    <String>['fourth', 'four', '4', 'number four', 'chautha', 'चौथा', '৪', 'চতুৰ্থ', 'চাৰি'],
    <String>['fifth', 'five', '5', 'number five', 'पांचवां', '৫', 'পঞ্চম', 'পাঁচ'],
    <String>['sixth', 'six', '6', 'number six', 'छठा', '৬', 'ষষ্ঠ', 'ছয়'],
  ];

  /// Words that mean the same as a Yes or a No option.
  static const Map<String, List<String>> _synonyms = <String, List<String>>{
    'yes': <String>['yeah', 'yep', 'yes please', 'correct', 'right', 'true', 'haan', 'ha', 'ji', 'हाँ', 'हो', 'হয়', 'হয়', 'ঠিক'],
    'no': <String>['nope', 'not really', 'never', 'wrong', 'false', 'nahi', 'nahin', 'नहीं', 'ना', 'নহয়', 'ভুল'],
    'never': <String>['not at all', 'none', 'nothing', 'no', 'kabhi nahi', 'कभी नहीं', 'কেতিয়াও নহয়'],
    'rarely': <String>['seldom', 'hardly', 'once in a while', 'kabhi kabhi', 'कभी कभी', 'কেতিয়াবা কেতিয়াবা'],
    'sometimes': <String>['occasionally', 'now and then', 'somewhat', 'केতিয়াবা'],
    'often': <String>['frequently', 'a lot', 'many times', 'always', 'all the time', 'হামেশা', 'সঘনাই', 'প্ৰায়েই'],
  };

  /// `\p{M}` is easy to miss and expensive to get wrong: Devanagari matras
  /// and the Assamese virama are marks, not letters, so a `[^\p{L}\p{N}]`
  /// filter alone silently turns "हाँ" into "ह" and "नहीं" into "नह" —
  /// every Hindi and Assamese phrase with a vowel sign stops matching, which
  /// is most of them.
  String _normalise(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\p{M}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// What [transcript] means, given the [options] currently on screen.
  VoiceIntakeMatch match(String transcript, List<String> options) {
    final String said = _normalise(transcript);
    if (said.isEmpty) return const VoiceIntakeMatch.none();

    // An instruction wins over an answer: "next" is never one of the options,
    // and someone saying it wants to move on rather than to be matched.
    for (final MapEntry<String, VoiceIntakeCommand> e in _commands.entries) {
      if (_containsPhrase(said, e.key)) {
        return VoiceIntakeMatch.instruction(e.value);
      }
    }
    if (options.isEmpty) return const VoiceIntakeMatch.none();

    final List<int> hits = <int>[];
    for (int i = 0; i < options.length; i++) {
      if (_matchesOption(said, options[i])) hits.add(i);
    }
    // Exactly one option matched by its words: that is the answer.
    if (hits.length == 1) return VoiceIntakeMatch.option(hits.first);

    // Otherwise fall back to the spoken position, which is unambiguous.
    for (int i = 0; i < options.length && i < _positions.length; i++) {
      for (final String form in _positions[i]) {
        if (_containsPhrase(said, form)) return VoiceIntakeMatch.option(i);
      }
    }

    // Two options matched and no position was given — ask again rather than
    // record a guess.
    return const VoiceIntakeMatch.none();
  }

  /// Every option whose words appear in [transcript] — for a "select
  /// everything that applies" question, where "music gardening reading"
  /// should pick three options at once rather than being refused as an
  /// ambiguous single answer, which is what [match] does on purpose for a
  /// single-choice question.
  List<int> matchAll(String transcript, List<String> options) {
    final String said = _normalise(transcript);
    if (said.isEmpty) return const <int>[];
    final List<int> hits = <int>[];
    for (int i = 0; i < options.length; i++) {
      if (_matchesOption(said, options[i])) hits.add(i);
    }
    return hits;
  }

  static const List<String> _affirmative = <String>[
    'yes', 'yeah', 'yep', 'yup', 'correct', 'right', 'sure', 'ok', 'okay',
    'haan', 'ha', 'ji', 'हाँ', 'हो', 'हां', 'ठीक',
    'হয়', 'ঠিক', 'হয়ঁ',
  ];

  static const List<String> _negative = <String>[
    'no', 'nope', 'not yet', 'wait',
    'nahi', 'nahin', 'नहीं', 'ना',
    'নহয়', 'নাই',
  ];

  /// Whether [transcript] answers "shall I move on?" with a yes — used only
  /// while the flow is waiting for that confirmation, never against the
  /// intake questions themselves, so it cannot be confused with an option
  /// that happens to be named "Yes".
  bool isAffirmative(String transcript) {
    final String said = _normalise(transcript);
    return _affirmative.any((String w) => _containsPhrase(said, w));
  }

  /// The "no" counterpart to [isAffirmative].
  bool isNegative(String transcript) {
    final String said = _normalise(transcript);
    return _negative.any((String w) => _containsPhrase(said, w));
  }

  bool _matchesOption(String said, String option) {
    final String label = _normalise(option);
    if (label.isEmpty) return false;
    if (_containsPhrase(said, label)) return true;

    for (final MapEntry<String, List<String>> e in _synonyms.entries) {
      if (label != e.key) continue;
      for (final String synonym in e.value) {
        if (_containsPhrase(said, synonym)) return true;
      }
    }

    // A multi-word label counts when every significant word of it was said,
    // in any order: "help with money" answers "Managing money".
    final List<String> words =
        label.split(' ').where((String w) => w.length > 3).toList(growable: false);
    if (words.length > 1 && words.every((String w) => _containsPhrase(said, w))) {
      return true;
    }
    return false;
  }

  /// A number said out loud, or null when there is not one.
  ///
  /// Ages arrive as "sixty eight", "68", or "I am sixty-eight years old", and
  /// all three have to work — a spoken questionnaire that only accepts digits
  /// is a keyboard with extra steps.
  int? spokenNumber(String transcript) {
    final String said = _normalise(transcript);
    if (said.isEmpty) return null;

    // Digits win when they are there: they are unambiguous.
    final RegExpMatch? digits = RegExp(r'\b(\d{1,3})\b').firstMatch(said);
    if (digits != null) {
      final int value = int.parse(digits.group(1)!);
      if (value > 0 && value < 130) return value;
    }

    int total = 0;
    bool found = false;
    for (final String word in said.split(' ')) {
      final int? unit = _units[word];
      if (unit != null) {
        total += unit;
        found = true;
        continue;
      }
      // "hundred" multiplies what came before it, so "nine hundred" is 900
      // and gets rejected as an age rather than becoming 109.
      if (word == 'hundred') {
        total = (total == 0 ? 1 : total) * 100;
        found = true;
        continue;
      }
      final int? ten = _tens[word];
      if (ten != null) {
        total += ten;
        found = true;
      }
    }
    if (!found || total <= 0 || total >= 130) return null;
    return total;
  }

  static const Map<String, int> _units = <String, int>{
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
    'thirteen': 13, 'fourteen': 14, 'fifteen': 15, 'sixteen': 16,
    'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  };

  static const Map<String, int> _tens = <String, int>{
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fourty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  };

  /// The dictated value, with the filler a person puts around it removed.
  ///
  /// "my name is Anita Das" is a name, not a sentence to store verbatim.
  String cleanDictation(String transcript) {
    String said = transcript.trim();
    for (final RegExp lead in <RegExp>[
      RegExp(r'^(my name is|i am|i m|im|this is|it is|its|it s)\s+', caseSensitive: false),
      RegExp(r'^(he is|she is|they are|his name is|her name is)\s+', caseSensitive: false),
      RegExp(r'^(i was a|i was an|i worked as a|i worked as an|i am a|i am an)\s+',
          caseSensitive: false),
    ]) {
      said = said.replaceFirst(lead, '');
    }
    said = said.replaceAll(RegExp(r'\s+(years old|saal|year old)$', caseSensitive: false), '');
    said = said.replaceAll(RegExp(r'[.,!?]+$'), '').trim();
    if (said.isEmpty) return '';
    // Spoken words arrive lowercase from most engines; a name written in
    // lowercase on a medical record looks like a mistake.
    return said
        .split(RegExp(r'\s+'))
        .map((String w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Whole-word containment, so "no" does not match inside "not really" and
  /// "one" does not match inside "money".
  bool _containsPhrase(String haystack, String needle) {
    if (needle.isEmpty) return false;
    final RegExp pattern = RegExp('(^| )${RegExp.escape(needle)}( |\$)');
    return pattern.hasMatch(haystack);
  }
}
