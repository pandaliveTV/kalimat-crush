import 'dart:math';

import 'package:flutter/material.dart';

/// Circle of letters. The player drags a finger across letters to build a
/// word; dragging back onto the previous letter removes the last one.
class LetterWheel extends StatefulWidget {
  final List<String> letters;
  final Color accent;

  /// Called with the finished word (display letters joined) on release.
  final ValueChanged<String> onWord;

  /// Called whenever the selection changes (empty string when cleared).
  final ValueChanged<String> onChanged;

  /// Called when a letter is added to the selection.
  final VoidCallback? onLetter;

  const LetterWheel({
    super.key,
    required this.letters,
    required this.accent,
    required this.onWord,
    required this.onChanged,
    this.onLetter,
  });

  @override
  State<LetterWheel> createState() => _LetterWheelState();
}

class _LetterWheelState extends State<LetterWheel> {
  final List<int> _selected = [];
  Offset? _finger;
  List<Offset> _centers = const [];
  double _radius = 0;

  @override
  void didUpdateWidget(LetterWheel old) {
    super.didUpdateWidget(old);
    if (old.letters.join() != widget.letters.join()) _selected.clear();
  }

  void _layout(double size) {
    final n = widget.letters.length;
    _radius = size * (n <= 5 ? 0.15 : 0.13);
    final ring = size / 2 - _radius - size * 0.04;
    final c = Offset(size / 2, size / 2);
    _centers = [
      for (var i = 0; i < n; i++)
        c +
            Offset(
              ring * cos(-pi / 2 + 2 * pi * i / n),
              ring * sin(-pi / 2 + 2 * pi * i / n),
            ),
    ];
  }

  int? _hit(Offset p) {
    for (var i = 0; i < _centers.length; i++) {
      if ((_centers[i] - p).distance <= _radius * 1.05) return i;
    }
    return null;
  }

  void _emitChange() =>
      widget.onChanged(_selected.map((i) => widget.letters[i]).join());

  void _track(Offset p) {
    final i = _hit(p);
    var changed = false;
    if (i != null) {
      if (_selected.length >= 2 && _selected[_selected.length - 2] == i) {
        _selected.removeLast();
        changed = true;
      } else if (!_selected.contains(i)) {
        _selected.add(i);
        changed = true;
        widget.onLetter?.call();
      }
    }
    setState(() => _finger = p);
    if (changed) _emitChange();
  }

  void _end() {
    if (_selected.isNotEmpty) {
      final word = _selected.map((i) => widget.letters[i]).join();
      widget.onWord(word);
    }
    setState(() {
      _selected.clear();
      _finger = null;
    });
    _emitChange();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        _layout(size);
        return Center(
          child: SizedBox.square(
            dimension: size,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => _track(d.localPosition),
              onPanUpdate: (d) => _track(d.localPosition),
              onPanEnd: (_) => _end(),
              onPanCancel: _end,
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _WheelPainter(
                          centers: _centers,
                          selected: List.of(_selected),
                          finger: _finger,
                          color: widget.accent,
                          stroke: _radius * 0.32,
                        ),
                      ),
                    ),
                    for (var i = 0; i < widget.letters.length; i++)
                      Positioned(
                        left: _centers[i].dx - _radius,
                        top: _centers[i].dy - _radius,
                        width: _radius * 2,
                        height: _radius * 2,
                        child: _LetterBubble(
                          letter: widget.letters[i],
                          selected: _selected.contains(i),
                          accent: widget.accent,
                          fontSize: _radius * 1.05,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LetterBubble extends StatelessWidget {
  final String letter;
  final bool selected;
  final Color accent;
  final double fontSize;

  const _LetterBubble({
    required this.letter,
    required this.selected,
    required this.accent,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? accent : Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : const Color(0xFF2B2250),
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Offset> centers;
  final List<int> selected;
  final Offset? finger;
  final Color color;
  final double stroke;

  _WheelPainter({
    required this.centers,
    required this.selected,
    required this.finger,
    required this.color,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawCircle(size.center(Offset.zero), size.width / 2, bg);
    if (selected.isEmpty) return;
    final line = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(centers[selected.first].dx, centers[selected.first].dy);
    for (final i in selected.skip(1)) {
      path.lineTo(centers[i].dx, centers[i].dy);
    }
    if (finger != null) path.lineTo(finger!.dx, finger!.dy);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.finger != finger ||
      old.selected.length != selected.length ||
      old.color != color ||
      old.centers != centers;
}
