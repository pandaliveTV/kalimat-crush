import 'dart:math';

import 'arabic.dart';

/// A word placed in the crossword grid.
///
/// Columns are *logical*: column 0 is the right-most column and words that
/// run horizontally are read right-to-left, i.e. letter `i` is at
/// `(row, col + i)`. Vertical words go top-down: letter `i` at `(row + i, col)`.
class Placement {
  final String word;
  final int row;
  final int col;
  final bool horizontal;

  const Placement(this.word, this.row, this.col, this.horizontal);

  int get length => splitLetters(word).length;

  /// Grid cells covered by this word, in reading order.
  List<Cell> get cells => [
    for (var i = 0; i < length; i++)
      horizontal ? Cell(row, col + i) : Cell(row + i, col),
  ];

  Map<String, Object> toJson() => {
    'w': word,
    'r': row,
    'c': col,
    'h': horizontal,
  };

  factory Placement.fromJson(Map<String, dynamic> j) =>
      Placement(j['w'] as String, j['r'] as int, j['c'] as int, j['h'] as bool);
}

class Cell {
  final int row;
  final int col;
  const Cell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => row * 1000 + col;

  @override
  String toString() => '$row:$col';
}

class CrosswordLayout {
  final List<Placement> placements;
  final int rows;
  final int cols;
  const CrosswordLayout(this.placements, this.rows, this.cols);
}

/// Greedy crossword builder used by the level generator.
///
/// Places [words] (first word first) so that every word crosses at least one
/// other word, no two words touch side by side, and the bounding box stays
/// within [maxRows] x [maxCols]. Runs [attempts] randomised passes and keeps
/// the layout with the most words, then the most compact one.
CrosswordLayout buildCrossword(
  List<String> words, {
  required Random rng,
  int maxRows = 8,
  int maxCols = 8,
  int attempts = 30,
}) {
  CrosswordLayout? best;
  double bestScore = -1;
  for (var a = 0; a < attempts; a++) {
    final order = [words.first, ...words.skip(1).toList()..shuffle(rng)];
    final firstHorizontal = a.isEven;
    final b = _Builder(maxRows, maxCols);
    b.place(Placement(order.first, 0, 0, firstHorizontal));
    final pending = order.skip(1).toList();
    var progress = true;
    while (pending.isNotEmpty && progress) {
      progress = false;
      _Candidate? pick;
      for (final w in pending) {
        final c = b.bestFor(w, rng);
        if (c != null && (pick == null || c.score > pick.score)) pick = c;
      }
      if (pick != null) {
        b.place(pick.placement);
        pending.remove(pick.placement.word);
        progress = true;
      }
    }
    final layout = b.normalized();
    final area = layout.rows * layout.cols;
    final squareness =
        min(layout.rows, layout.cols) / max(layout.rows, layout.cols);
    final score = layout.placements.length * 1000 - area * 2 + squareness * 10;
    if (score > bestScore) {
      bestScore = score;
      best = layout;
    }
  }
  return best!;
}

class _Candidate {
  final Placement placement;
  final double score;
  _Candidate(this.placement, this.score);
}

class _Builder {
  final int maxRows;
  final int maxCols;
  final Map<Cell, String> letters = {};
  final Map<Cell, int> dirs = {}; // bit 1 = horizontal, bit 2 = vertical
  final List<Placement> placed = [];
  int minR = 0, maxR = 0, minC = 0, maxC = 0;

  _Builder(this.maxRows, this.maxCols);

  void place(Placement p) {
    final ls = splitLetters(normalizeArabic(p.word));
    final cells = p.cells;
    for (var i = 0; i < cells.length; i++) {
      letters[cells[i]] = ls[i];
      dirs[cells[i]] = (dirs[cells[i]] ?? 0) | (p.horizontal ? 1 : 2);
    }
    if (placed.isEmpty) {
      minR = maxR = p.row;
      minC = maxC = p.col;
    }
    for (final c in cells) {
      minR = min(minR, c.row);
      maxR = max(maxR, c.row);
      minC = min(minC, c.col);
      maxC = max(maxC, c.col);
    }
    placed.add(p);
  }

  _Candidate? bestFor(String word, Random rng) {
    final ls = splitLetters(normalizeArabic(word));
    _Candidate? best;
    for (final e in letters.entries) {
      for (var i = 0; i < ls.length; i++) {
        if (ls[i] != e.value) continue;
        final d = dirs[e.key]!;
        for (final horizontal in [true, false]) {
          // A crossing cell must belong to a word in the other direction.
          if (horizontal && d & 1 != 0) continue;
          if (!horizontal && d & 2 != 0) continue;
          final p = horizontal
              ? Placement(word, e.key.row, e.key.col - i, true)
              : Placement(word, e.key.row - i, e.key.col, false);
          final crossings = _check(p, ls);
          if (crossings <= 0) continue;
          final r0 = min(minR, p.row);
          final c0 = min(minC, p.col);
          final r1 = max(maxR, horizontal ? p.row : p.row + ls.length - 1);
          final c1 = max(maxC, horizontal ? p.col + ls.length - 1 : p.col);
          final area = (r1 - r0 + 1) * (c1 - c0 + 1);
          final score =
              crossings * 50.0 - area + ls.length * 3 + rng.nextDouble();
          if (best == null || score > best.score) {
            best = _Candidate(p, score);
          }
        }
      }
    }
    return best;
  }

  /// Returns number of crossings, or -1 if the placement is illegal.
  int _check(Placement p, List<String> ls) {
    final cells = p.cells;
    final dr = p.horizontal ? 0 : 1;
    final dc = p.horizontal ? 1 : 0;
    // Bounding box limits.
    final r0 = min(minR, p.row);
    final c0 = min(minC, p.col);
    final r1 = max(maxR, cells.last.row);
    final c1 = max(maxC, cells.last.col);
    if (r1 - r0 + 1 > maxRows || c1 - c0 + 1 > maxCols) return -1;
    // Cells just before and after the word must be empty.
    if (letters.containsKey(Cell(p.row - dr, p.col - dc))) return -1;
    if (letters.containsKey(Cell(cells.last.row + dr, cells.last.col + dc))) {
      return -1;
    }
    var crossings = 0;
    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      final existing = letters[c];
      if (existing != null) {
        if (existing != ls[i]) return -1;
        final d = dirs[c]!;
        if (p.horizontal ? d & 1 != 0 : d & 2 != 0) return -1;
        crossings++;
      } else {
        // Perpendicular neighbours must be empty (no side-by-side words).
        final n1 = Cell(c.row + dc, c.col + dr);
        final n2 = Cell(c.row - dc, c.col - dr);
        if (letters.containsKey(n1) || letters.containsKey(n2)) return -1;
      }
    }
    if (crossings == cells.length) return -1; // word already fully present
    return crossings;
  }

  CrosswordLayout normalized() => CrosswordLayout(
    [
      for (final p in placed)
        Placement(p.word, p.row - minR, p.col - minC, p.horizontal),
    ],
    maxR - minR + 1,
    maxC - minC + 1,
  );
}
