/// Arabic text helpers shared by the game and the level generator.
///
/// Pure Dart (no Flutter imports) so `tool/generate_levels.dart` can use it.
library;

/// Zero-width joiner: forces a letter to render in its connected form.
const zwj = '‍';

const _alefForms = {'أ', 'إ', 'آ', 'ٱ'};

/// Normalises a word for comparison:
/// * strips tashkeel (harakat) and tatweel
/// * أ إ آ ٱ → ا
/// * ة → ه (taa marbuta)
/// * ى → ي (alef maqsura)
String normalizeArabic(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    // Tashkeel U+064B..U+065F, superscript alef U+0670, tatweel U+0640.
    if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) continue;
    if (r == 0x200C || r == 0x200D || r == 0x20) continue;
    final ch = String.fromCharCode(r);
    if (_alefForms.contains(ch)) {
      b.write('ا');
    } else if (ch == 'ة') {
      b.write('ه');
    } else if (ch == 'ى') {
      b.write('ي');
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

/// Splits a word into its letters (one string per letter).
List<String> splitLetters(String word) =>
    word.runes.map(String.fromCharCode).toList();

/// Counts each normalised letter of [letters].
Map<String, int> letterCounts(Iterable<String> letters) {
  final m = <String, int>{};
  for (final l in letters) {
    final n = normalizeArabic(l);
    for (final ch in splitLetters(n)) {
      m[ch] = (m[ch] ?? 0) + 1;
    }
  }
  return m;
}

/// True when [word] can be spelled using the letters in [pool]
/// (each letter used at most as many times as it appears).
bool canFormWord(String word, Map<String, int> pool) {
  final need = letterCounts(splitLetters(word));
  for (final e in need.entries) {
    if ((pool[e.key] ?? 0) < e.value) return false;
  }
  return true;
}

/// Letters that never connect to the letter after them.
const _noJoinNext = {
  'ا', 'أ', 'إ', 'آ', 'ٱ', 'د', 'ذ', 'ر', 'ز', 'و', 'ؤ', 'ة', 'ء', //
};

bool _joinsNext(String ch) => !_noJoinNext.contains(ch);
bool _joinsPrev(String ch) => ch != 'ء';

/// Returns letter [i] of [word] wrapped in zero-width joiners so it renders
/// with the same shape (initial / medial / final / isolated) it has inside
/// the full connected word.
String contextualLetter(String word, int i) {
  final ls = splitLetters(word);
  final ch = ls[i];
  final prev = i > 0 && _joinsNext(ls[i - 1]) && _joinsPrev(ch);
  final next = i < ls.length - 1 && _joinsNext(ch) && _joinsPrev(ls[i + 1]);
  return '${prev ? zwj : ''}$ch${next ? zwj : ''}';
}
