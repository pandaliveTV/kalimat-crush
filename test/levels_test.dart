import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat/data/level_repository.dart';
import 'package:kalimat/game/arabic.dart';
import 'package:kalimat/game/crossword.dart';
import 'package:kalimat/game/level.dart';

void main() {
  final levels = LevelRepository.parse(
    File('data/levels.json').readAsStringSync(),
  );

  test('at least 300 levels with sequential ids', () {
    expect(levels.length, greaterThanOrEqualTo(300));
    for (var i = 0; i < levels.length; i++) {
      expect(levels[i].id, i + 1);
    }
  });

  test('every wheel has 4 to 7 letters and letter sets are unique', () {
    final seen = <String>{};
    for (final l in levels) {
      expect(l.letters.length, inInclusiveRange(4, 7), reason: 'level ${l.id}');
      final key = (l.letters.map(normalizeArabic).toList()..sort()).join();
      expect(seen.add(key), isTrue, reason: 'duplicate set in ${l.id}');
    }
  });

  test('difficulty never decreases in wheel size', () {
    for (var i = 1; i < levels.length; i++) {
      expect(
        levels[i].letters.length,
        greaterThanOrEqualTo(levels[i - 1].letters.length),
      );
    }
  });

  test('all grid and bonus words can be spelled from the wheel', () {
    for (final l in levels) {
      final pool = letterCounts(l.letters);
      expect(l.words.length, greaterThanOrEqualTo(3), reason: 'level ${l.id}');
      for (final w in [...l.words.map((p) => p.word), ...l.bonus]) {
        expect(canFormWord(w, pool), isTrue, reason: '$w in level ${l.id}');
        expect(
          splitLetters(normalizeArabic(w)).length,
          greaterThanOrEqualTo(3),
        );
      }
      final grid = l.words.map((p) => normalizeArabic(p.word)).toSet();
      expect(grid.length, l.words.length, reason: 'dup word in ${l.id}');
      for (final b in l.bonus) {
        expect(grid.contains(normalizeArabic(b)), isFalse);
      }
    }
  });

  test('crossword layouts are consistent, connected and fit the board', () {
    for (final l in levels) {
      _checkLayout(l);
    }
  });
}

void _checkLayout(Level l) {
  final letters = <Cell, String>{};
  final horiz = <Cell>{};
  final vert = <Cell>{};
  for (final p in l.words) {
    final ls = splitLetters(normalizeArabic(p.word));
    final cells = p.cells;
    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      expect(c.row, inInclusiveRange(0, l.rows - 1), reason: 'level ${l.id}');
      expect(c.col, inInclusiveRange(0, l.cols - 1), reason: 'level ${l.id}');
      final prev = letters[c];
      if (prev != null) {
        expect(prev, ls[i], reason: 'crossing mismatch in level ${l.id}');
      }
      letters[c] = ls[i];
      (p.horizontal ? horiz : vert).add(c);
    }
  }
  // No two words run in the same direction through one cell, and every
  // pair of neighbouring letters belongs to a common word (no accidental
  // side-by-side letters).
  for (final c in letters.keys) {
    final right = Cell(c.row, c.col + 1);
    if (letters.containsKey(right)) {
      expect(
        horiz.contains(c) && horiz.contains(right),
        isTrue,
        reason: 'stray horizontal neighbour at $c in level ${l.id}',
      );
    }
    final down = Cell(c.row + 1, c.col);
    if (letters.containsKey(down)) {
      expect(
        vert.contains(c) && vert.contains(down),
        isTrue,
        reason: 'stray vertical neighbour at $c in level ${l.id}',
      );
    }
  }
  // Connected: flood fill from the first cell reaches every letter.
  final start = letters.keys.first;
  final seen = {start};
  final queue = [start];
  while (queue.isNotEmpty) {
    final c = queue.removeLast();
    for (final n in [
      Cell(c.row + 1, c.col),
      Cell(c.row - 1, c.col),
      Cell(c.row, c.col + 1),
      Cell(c.row, c.col - 1),
    ]) {
      if (letters.containsKey(n) && seen.add(n)) queue.add(n);
    }
  }
  expect(seen.length, letters.length, reason: 'level ${l.id} not connected');
}
