// Generates data/levels.json from the Arabic word list in data/arabic_words.txt.
//
// Usage:
//   dart run tool/generate_levels.dart [--levels 300] [--seed 7]
//
// Every level has a wheel of 4–7 letters taken from a "base" word, a crossword
// of words that can be spelled from those letters, and a list of extra valid
// words (bonus words) that are not in the grid.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kalimat/game/arabic.dart';
import 'package:kalimat/game/crossword.dart';

/// Difficulty tiers: fraction of the levels, wheel size, grid words range.
class Tier {
  final double share;
  final int letters;
  final int minWords;
  final int maxWords;
  const Tier(this.share, this.letters, this.minWords, this.maxWords);
}

const tiers = [
  Tier(0.10, 4, 3, 4),
  Tier(0.25, 5, 3, 5),
  Tier(0.35, 6, 4, 6),
  Tier(0.30, 7, 5, 7),
];

const minWordLength = 3;

/// Regular verb conjugations: valid, but ranked lower for the grid.
final _secondary = <String>{};

/// Common letters that may be added to a shorter base word.
const extraLetters = [
  'ا',
  'ل',
  'م',
  'ن',
  'ت',
  'ي',
  'و',
  'ر',
  'ه',
  'ب',
  'س',
  'د',
];

void main(List<String> args) {
  var total = 300;
  var seed = 7;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--levels') total = int.parse(args[i + 1]);
    if (args[i] == '--seed') seed = int.parse(args[i + 1]);
  }
  final rng = Random(seed);

  // Load dictionary: normalised form -> display form (first spelling wins).
  final dict = <String, String>{};
  var inSecondary = false;
  for (final line in File('data/arabic_words.txt').readAsLinesSync()) {
    final w = line.trim();
    if (w.startsWith('# @secondary')) inSecondary = true;
    if (w.isEmpty || w.startsWith('#')) continue;
    final n = normalizeArabic(w);
    if (splitLetters(n).length < minWordLength) continue;
    if (dict.containsKey(n)) continue;
    dict[n] = w;
    if (inSecondary) _secondary.add(n);
  }
  stdout.writeln('Dictionary: ${dict.length} words');

  final usage = <String, int>{}; // how often a word was used in a grid
  final usedSets = <String>{};
  final levels = <Map<String, Object>>[];

  var remaining = total;
  for (var t = 0; t < tiers.length; t++) {
    final tier = tiers[t];
    final want = t == tiers.length - 1
        ? remaining
        : (total * tier.share).round();
    remaining -= want;
    final made = _makeTier(tier, want, dict, usage, usedSets, rng);
    stdout.writeln('Tier ${tier.letters} letters: ${made.length}/$want levels');
    levels.addAll(made);
    if (made.length < want) remaining += want - made.length;
  }

  for (var i = 0; i < levels.length; i++) {
    levels[i]['id'] = i + 1;
  }
  final json = const JsonEncoder.withIndent(null)
      .convert({'version': 1, 'count': levels.length, 'levels': levels});
  File('data/levels.json').writeAsStringSync(json);
  stdout.writeln('Wrote ${levels.length} levels to data/levels.json');
  if (levels.length < total) exitCode = 1;
}

List<Map<String, Object>> _makeTier(
  Tier tier,
  int want,
  Map<String, String> dict,
  Map<String, int> usage,
  Set<String> usedSets,
  Random rng,
) {
  final all = dict.keys.toList();
  final bases =
      all.where((w) => splitLetters(w).length == tier.letters).toList()
        ..shuffle(rng);

  final candidates = <_Candidate>[];
  for (final base in bases) {
    final key = (splitLetters(base)..sort()).join();
    if (usedSets.contains(key)) continue;
    final pool = letterCounts(splitLetters(base));
    final subs = all.where((w) => w != base && canFormWord(w, pool)).toList();
    if (subs.length + 1 < tier.minWords) continue;
    candidates.add(_Candidate(base, key, subs));
  }
  // Not enough real words of this length: use a shorter word plus one extra
  // common letter that unlocks at least two more words.
  if (candidates.length < want * 2) {
    final shorter =
        all.where((w) => splitLetters(w).length == tier.letters - 1).toList()
          ..shuffle(rng);
    for (final base in shorter) {
      _Candidate? best;
      final basePool = letterCounts(splitLetters(base));
      for (final extra in extraLetters) {
        final letters = [...splitLetters(base), extra];
        final key = ([...letters]..sort()).join();
        if (usedSets.contains(key)) continue;
        final pool = letterCounts(letters);
        final subs = all
            .where((w) => w != base && canFormWord(w, pool))
            .toList();
        final unlocked = subs.where((w) => !canFormWord(w, basePool)).length;
        if (unlocked < 2 || subs.length + 1 < tier.minWords) continue;
        if (best == null || subs.length > best.subs.length) {
          best = _Candidate(base, key, subs, extra: extra);
        }
      }
      if (best != null) candidates.add(best);
    }
  }
  // Richer letter sets first, easier ones (fewer words) first inside a tier.
  candidates.sort((a, b) => b.subs.length.compareTo(a.subs.length));

  final out = <Map<String, Object>>[];
  for (final c in candidates) {
    if (out.length >= want) break;
    if (usedSets.contains(c.key)) continue;
    final level = _makeLevel(tier, c, dict, usage, rng);
    if (level == null) continue;
    usedSets.add(c.key);
    out.add(level);
  }
  // Progressive difficulty inside the tier: fewer grid words first.
  out.sort(
    (a, b) =>
        (a['words'] as List).length.compareTo((b['words'] as List).length),
  );
  return out;
}

class _Candidate {
  final String base;
  final String key;
  final List<String> subs;
  final String? extra;
  _Candidate(this.base, this.key, this.subs, {this.extra});
}

int _rank(String w, Map<String, int> usage) =>
    splitLetters(w).length * 3 -
    (usage[w] ?? 0) * 2 +
    (_secondary.contains(w) ? 0 : 5);

Map<String, Object>? _makeLevel(
  Tier tier,
  _Candidate c,
  Map<String, String> dict,
  Map<String, int> usage,
  Random rng,
) {
  // Prefer longer and less-used words for the grid.
  final ranked = [...c.subs]
    ..sort((a, b) {
      return _rank(b, usage).compareTo(_rank(a, usage));
    });
  final target = tier.minWords + rng.nextInt(tier.maxWords - tier.minWords + 1);
  final pick = [c.base, ...ranked.take(target + 2)];
  final layout = buildCrossword(
    pick,
    rng: rng,
    maxRows: tier.letters >= 6 ? 9 : 7,
    maxCols: 8,
  );
  final placements = layout.placements;
  if (placements.length < tier.minWords) return null;
  if (placements.length > target) {
    // Rebuild with exactly the words that fit, capped at target.
    final keep = placements.take(target).map((p) => p.word).toList();
    final again = buildCrossword(
      keep,
      rng: rng,
      maxRows: tier.letters >= 6 ? 9 : 7,
      maxCols: 8,
    );
    if (again.placements.length != keep.length) return null;
    return _encode(c, again, dict, usage, rng);
  }
  return _encode(c, layout, dict, usage, rng);
}

Map<String, Object> _encode(
  _Candidate c,
  CrosswordLayout layout,
  Map<String, String> dict,
  Map<String, int> usage,
  Random rng,
) {
  final gridWords = layout.placements.map((p) => p.word).toSet();
  for (final w in gridWords) {
    usage[w] = (usage[w] ?? 0) + 1;
  }
  final bonus = [
    c.base,
    ...c.subs,
  ].where((w) => !gridWords.contains(w)).map((w) => dict[w]!).toList();

  // Wheel letters: shown in their most natural written form. If every grid
  // occurrence of a normalised letter is written the same special way
  // (e.g. ة or أ) the wheel shows that form.
  final forms = <String, Set<String>>{};
  for (final p in layout.placements) {
    final display = splitLetters(dict[p.word]!);
    for (final ch in display) {
      forms.putIfAbsent(normalizeArabic(ch), () => {}).add(ch);
    }
  }
  final wheel = [...splitLetters(c.base), ?c.extra]..shuffle(rng);
  final letters = wheel.map((l) {
    final f = forms[l];
    return f != null && f.length == 1 ? f.first : l;
  }).toList();

  return {
    'id': 0,
    'letters': letters,
    'rows': layout.rows,
    'cols': layout.cols,
    'words': [
      for (final p in layout.placements)
        Placement(dict[p.word]!, p.row, p.col, p.horizontal).toJson(),
    ],
    'bonus': bonus,
  };
}
