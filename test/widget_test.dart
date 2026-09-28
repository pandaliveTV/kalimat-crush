import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat/game/game_controller.dart';
import 'package:kalimat/game/level.dart';
import 'package:kalimat/widgets/crossword_grid.dart';
import 'package:kalimat/widgets/letter_wheel.dart';

void main() {
  testWidgets('dragging across the wheel builds a word', (tester) async {
    String? word;
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox.square(
              dimension: 300,
              child: LetterWheel(
                letters: const ['ك', 'ت', 'ب'],
                accent: Colors.orange,
                onWord: (w) => word = w,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    final k = tester.getCenter(find.text('ك'));
    final t = tester.getCenter(find.text('ت'));
    final b = tester.getCenter(find.text('ب'));
    final g = await tester.startGesture(k);
    await g.moveTo(t);
    await g.moveTo(b);
    await g.moveTo(t); // back onto the previous letter removes ب
    await g.moveTo(b);
    await g.up();
    await tester.pump();
    expect(word, 'كتب');
    expect(changes, contains('كت'));
    expect(changes.last, '');
  });

  testWidgets('grid shows letters only for found words', (tester) async {
    final level = Level.fromJson({
      'id': 1,
      'letters': ['ك', 'ت', 'ا', 'ب'],
      'rows': 3,
      'cols': 4,
      'words': [
        {'w': 'كتاب', 'r': 0, 'c': 0, 'h': true},
        {'w': 'كتب', 'r': 0, 'c': 0, 'h': false},
      ],
      'bonus': <String>[],
    });
    final game = GameController(level);
    Widget app() => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 240,
          child: CrosswordGrid(game: game, accent: Colors.orange),
        ),
      ),
    );
    await tester.pumpWidget(app());
    expect(find.textContaining('ك'), findsNothing);
    game.submit('كتب');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('ك'), findsOneWidget);
    expect(find.textContaining('ا'), findsNothing);
  });
}
