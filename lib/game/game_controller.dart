import 'dart:math';

import 'package:flutter/foundation.dart';

import 'arabic.dart';
import 'crossword.dart';
import 'level.dart';

enum WordResult { tooShort, found, alreadyFound, bonus, bonusAgain, invalid }

/// Game state for one level: found words, revealed cells, bonus words and
/// the order of letters on the wheel. Pure logic, UI-agnostic.
class GameController extends ChangeNotifier {
  static const minWordLength = 3;

  final Level level;
  final Random _rng;

  /// Wheel letters (display form) in their current on-screen order.
  late List<String> wheel;

  /// Indices of found grid words.
  final Set<int> found = {};

  /// Cells uncovered by hints.
  final Set<Cell> revealed = {};

  /// Bonus words found in this level (normalised).
  final Set<String> bonusFound = {};

  /// Index of the most recently found word (for highlight animation).
  int? lastFound;

  GameController(
    this.level, {
    Random? rng,
    Iterable<int> found = const [],
    Iterable<Cell> revealed = const [],
    Iterable<String> bonus = const [],
  }) : _rng = rng ?? Random() {
    wheel = [...level.letters]..shuffle(_rng);
    this.found.addAll(found.where((i) => i >= 0 && i < level.words.length));
    this.revealed.addAll(revealed);
    bonusFound.addAll(bonus.map(normalizeArabic));
  }

  bool get completed => found.length == level.words.length;

  /// Every cell of the grid (each shared cell once).
  Set<Cell> get allCells => level.cellText.keys.toSet();

  bool isCellVisible(Cell c) =>
      revealed.contains(c) ||
      found.any((i) => level.words[i].cells.contains(c));

  WordResult submit(String raw) {
    final word = normalizeArabic(raw);
    if (splitLetters(word).length < minWordLength) return WordResult.tooShort;
    final idx = level.indexOfWord(word);
    if (idx >= 0) {
      if (found.contains(idx)) return WordResult.alreadyFound;
      found.add(idx);
      lastFound = idx;
      notifyListeners();
      return WordResult.found;
    }
    if (level.isBonus(word)) {
      if (!bonusFound.add(word)) return WordResult.bonusAgain;
      notifyListeners();
      return WordResult.bonus;
    }
    return WordResult.invalid;
  }

  /// Reveals one hidden letter, preferring the first letter of an unsolved
  /// word, then any hidden letter. Returns the cell, or null if none left.
  Cell? revealHint() {
    final hidden = allCells.where((c) => !isCellVisible(c)).toList();
    if (hidden.isEmpty) return null;
    Cell? pick;
    for (var i = 0; i < level.words.length && pick == null; i++) {
      if (found.contains(i)) continue;
      for (final c in level.words[i].cells) {
        if (!isCellVisible(c)) {
          pick = c;
          break;
        }
      }
    }
    pick ??= hidden[_rng.nextInt(hidden.length)];
    revealed.add(pick);
    _autoCompleteRevealedWords();
    notifyListeners();
    return pick;
  }

  /// A word whose letters were all uncovered by hints counts as found.
  void _autoCompleteRevealedWords() {
    for (var i = 0; i < level.words.length; i++) {
      if (found.contains(i)) continue;
      if (level.words[i].cells.every(isCellVisible)) {
        found.add(i);
        lastFound = i;
      }
    }
  }

  void shuffle() {
    if (wheel.length < 2) return;
    final before = wheel.join();
    for (var tries = 0; tries < 5; tries++) {
      wheel.shuffle(_rng);
      if (wheel.join() != before) break;
    }
    notifyListeners();
  }
}
