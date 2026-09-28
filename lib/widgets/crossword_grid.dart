import 'dart:math';

import 'package:flutter/material.dart';

import '../game/crossword.dart';
import '../game/game_controller.dart';

/// The crossword board. Logical column 0 is drawn on the right (RTL).
class CrosswordGrid extends StatelessWidget {
  final GameController game;
  final Color accent;

  /// Cells to flash (the word just found / the letter just revealed).
  final Set<Cell> highlight;

  const CrosswordGrid({
    super.key,
    required this.game,
    required this.accent,
    this.highlight = const {},
  });

  @override
  Widget build(BuildContext context) {
    final level = game.level;
    return LayoutBuilder(
      builder: (context, c) {
        final cell = min(
          min(c.maxWidth / level.cols, c.maxHeight / level.rows),
          64.0,
        );
        final gap = cell * 0.06;
        return Center(
          child: SizedBox(
            width: cell * level.cols,
            height: cell * level.rows,
            child: Stack(
              children: [
                for (final e in level.cellText.entries)
                  Positioned(
                    left: (level.cols - 1 - e.key.col) * cell + gap / 2,
                    top: e.key.row * cell + gap / 2,
                    width: cell - gap,
                    height: cell - gap,
                    child: _GridCell(
                      text: e.value,
                      visible: game.isCellVisible(e.key),
                      highlight: highlight.contains(e.key),
                      accent: accent,
                      size: cell - gap,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridCell extends StatelessWidget {
  final String text;
  final bool visible;
  final bool highlight;
  final Color accent;
  final double size;

  const _GridCell({
    required this.text,
    required this.visible,
    required this.highlight,
    required this.accent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.18);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: child,
      ),
      child: visible
          ? AnimatedContainer(
              key: const ValueKey('on'),
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: highlight ? accent : Colors.white,
                borderRadius: radius,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                text,
                textDirection: TextDirection.rtl,
                maxLines: 1,
                style: TextStyle(
                  fontSize: size * 0.58,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: highlight ? Colors.white : const Color(0xFF2B2250),
                ),
              ),
            )
          : Container(
              key: const ValueKey('off'),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: radius,
              ),
            ),
    );
  }
}
