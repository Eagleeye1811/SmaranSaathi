/// Maps Assamese text into phonetic Indic script so available Indian TTS engines
/// (e.g. `hi-IN` / `Google हिन्दी`) can articulate Assamese words accurately when
/// an operating system lacks a dedicated Assamese TTS voice pack.
class AssameseSpeechPhonetics {
  const AssameseSpeechPhonetics._();

  /// Converts Assamese/Bengali Unicode text (U+0980 - U+09FF) into
  /// phonetic Devanagari script (U+0900 - U+097F).
  static String toIndicPhoneticText(String text) {
    final StringBuffer buffer = StringBuffer();
    final List<int> runes = text.runes.toList(growable: false);

    for (int i = 0; i < runes.length; i++) {
      final int rune = runes[i];

      // Assamese-specific letters
      if (rune == 0x09F0) {
        // Assamese Ra (ৰ) -> Devanagari Ra (र)
        buffer.writeCharCode(0x0930);
      } else if (rune == 0x09F1) {
        // Assamese Wa/Va (ৱ) -> Devanagari Va (व)
        buffer.writeCharCode(0x0935);
      } else if (rune == 0x09CE) {
        // Khanda Ta (ৎ) -> त्
        buffer.write('त्');
      } else if (rune == 0x09DC) {
        // Rra (ড়) -> ड़
        buffer.writeCharCode(0x095C);
      } else if (rune == 0x09DD) {
        // Rrha (ঢ়) -> ढ़
        buffer.writeCharCode(0x095D);
      } else if (rune == 0x09DF) {
        // Yya (য়) -> य
        buffer.writeCharCode(0x092F);
      } else if (rune >= 0x0981 && rune <= 0x09EF) {
        // Standard parallel Bengali/Assamese to Devanagari Unicode block offset (0x80)
        final int devanagariRune = rune - 0x0080;
        buffer.writeCharCode(devanagariRune);
      } else {
        buffer.writeCharCode(rune);
      }
    }

    return buffer.toString();
  }
}
