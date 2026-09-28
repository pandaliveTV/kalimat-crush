import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat/game/crossword.dart';
import 'package:kalimat/game/game_controller.dart';
import 'package:kalimat/game/level.dart';

Level sampleLevel() => Level.fromJson({
  'id': 1,
  'letters': ['ك', 'ت', 'ا', 'ب'],
  'rows': 3,
  'cols': 4,
  // كتاب across the top, كتب down from its first letter, تاب ... placed
  // down from the last letter.
  'words': [
    {'w': 'كتاب', 'r': 0, 'c': 0, 'h': true},
    {'w': 'كتب', 'r': 0, 'c': 0, 'h': false},
    {'w': 'باك', 'r': 0, 'c': 3, 'h': false},
  ],
  'bonus': ['بات', 'تاب'],
});

void main() {
  test('finding grid words, bonus words and invalid words', () {
    final g = GameController(sampleLevel(), rng: Random(1));
    expect(g.submit('كت'), WordResult.tooShort);
    expect(g.submit('كتب'), WordResult.found);
    expect(g.submit('كتب'), WordResult.alreadyFound);
    expect(g.submit('بات'), WordResult.bonus);
    expect(g.submit('بات'), WordResult.bonusAgain);
    expect(g.submit('تكب'), WordResult.invalid);
    expect(g.completed, isFalse);
    expect(g.submit('كتاب'), WordResult.found);
    expect(g.submit('باك'), WordResult.found);
    expect(g.completed, isTrue);
  });

  test('comparison normalises hamza and taa marbuta', () {
    final level = Level.fromJson({
      'id': 2,
      'letters': ['ا', 'م', 'ل'],
      'rows': 1,
      'cols': 3,
      'words': [
        {'w': 'أمل', 'r': 0, 'c': 0, 'h': true},
      ],
      'bonus': ['ألم'],
    });
    final g = GameController(level);
    expect(g.submit('امل'), WordResult.found);
    expect(g.submit('الم'), WordResult.bonus);
  });

  test('visible cells follow found words', () {
    final g = GameController(sampleLevel());
    expect(g.isCellVisible(const Cell(0, 0)), isFalse);
    g.submit('كتب');
    expect(g.isCellVisible(const Cell(0, 0)), isTrue);
    expect(g.isCellVisible(const Cell(2, 0)), isTrue);
    expect(g.isCellVisible(const Cell(0, 1)), isFalse);
  });

  test('hints reveal letters and complete fully revealed words', () {
    final g = GameController(sampleLevel(), rng: Random(3));
    var guard = 0;
    while (!g.completed && guard++ < 50) {
      expect(g.revealHint(), isNotNull);
    }
    expect(g.completed, isTrue);
    expect(g.revealHint(), isNull);
  });

  test('shuffle keeps the same letters', () {
    final g = GameController(sampleLevel(), rng: Random(5));
    final before = [...g.wheel]..sort();
    g.shuffle();
    expect([...g.wheel]..sort(), before);
  });

  test('restores saved progress', () {
    final g = GameController(
      sampleLevel(),
      found: [0],
      revealed: [const Cell(2, 0)],
      bonus: ['تاب'],
    );
    expect(g.found, {0});
    expect(g.isCellVisible(const Cell(2, 0)), isTrue);
    expect(g.submit('تاب'), WordResult.bonusAgain);
  });

  test('horizontal cells keep connected letter shapes', () {
    final l = sampleLevel();
    // ك at the start of كتاب is drawn in its initial form.
    expect(l.cellText[const Cell(0, 0)], 'ك‍');
    // ب at the end of كتاب follows ا (non-joining) so it is isolated.
    expect(l.cellText[const Cell(0, 3)], 'ب');
  });
}
