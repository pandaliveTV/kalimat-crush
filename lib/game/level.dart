import 'arabic.dart';
import 'crossword.dart';

/// One puzzle loaded from data/levels.json.
class Level {
  final int id;

  /// Wheel letters in their display form.
  final List<String> letters;
  final int rows;
  final int cols;
  final List<Placement> words;

  /// Extra valid words (not in the grid) that reward coins.
  final List<String> bonus;

  /// Normalised word -> index in [words].
  final Map<String, int> _wordIndex;
  final Set<String> _bonusSet;

  /// Letter shown in each grid cell (with its connected shape).
  final Map<Cell, String> cellText;

  Level._({
    required this.id,
    required this.letters,
    required this.rows,
    required this.cols,
    required this.words,
    required this.bonus,
  }) : _wordIndex = {
         for (var i = 0; i < words.length; i++)
           normalizeArabic(words[i].word): i,
       },
       _bonusSet = bonus.map(normalizeArabic).toSet(),
       cellText = _buildCellText(words);

  factory Level.fromJson(Map<String, dynamic> j) => Level._(
    id: j['id'] as int,
    letters: (j['letters'] as List).cast<String>(),
    rows: j['rows'] as int,
    cols: j['cols'] as int,
    words: [
      for (final w in j['words'] as List)
        Placement.fromJson(w as Map<String, dynamic>),
    ],
    bonus: (j['bonus'] as List).cast<String>(),
  );

  /// Index of the grid word matching [word] (after normalisation), or -1.
  int indexOfWord(String word) => _wordIndex[normalizeArabic(word)] ?? -1;

  bool isBonus(String word) => _bonusSet.contains(normalizeArabic(word));

  /// Vertical words are drawn with isolated letters; horizontal words keep
  /// the shape each letter has inside the connected word (RTL).
  static Map<Cell, String> _buildCellText(List<Placement> words) {
    final m = <Cell, String>{};
    for (final p in words.where((p) => !p.horizontal)) {
      final ls = splitLetters(p.word);
      final cells = p.cells;
      for (var i = 0; i < cells.length; i++) {
        m[cells[i]] = ls[i];
      }
    }
    for (final p in words.where((p) => p.horizontal)) {
      final cells = p.cells;
      for (var i = 0; i < cells.length; i++) {
        m[cells[i]] = contextualLetter(p.word, i);
      }
    }
    return m;
  }
}
