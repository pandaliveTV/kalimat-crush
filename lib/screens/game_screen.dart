import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/level_repository.dart';
import '../data/themes.dart';
import '../game/arabic.dart';
import '../game/crossword.dart';
import '../game/game_controller.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import '../widgets/crossword_grid.dart';
import '../widgets/letter_wheel.dart';
import 'home_screen.dart';

/// Gameplay. No banner ads on this screen.
class GameScreen extends StatefulWidget {
  final int levelNumber;
  const GameScreen({super.key, required this.levelNumber});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Preview { idle, building, found, bonus, repeat, wrong }

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const hintCost = 25;
  static const bonusCoins = 3;

  late final GameController game;
  late final StorageService storage;
  late final AudioService audio;
  late final AdService ads;
  late final bool firstPlay;

  String _preview = '';
  _Preview _state = _Preview.idle;
  Set<Cell> _highlight = {};
  Timer? _previewTimer;
  Timer? _highlightTimer;
  bool _finished = false;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void initState() {
    super.initState();
    storage = context.read<StorageService>();
    audio = context.read<AudioService>();
    ads = context.read<AdService>();
    final level = context.read<LevelRepository>().byNumber(widget.levelNumber);
    firstPlay = widget.levelNumber >= storage.level;
    final saved = storage.progress;
    if (firstPlay && saved != null && saved.level == widget.levelNumber) {
      game = GameController(
        level,
        found: saved.found,
        revealed: saved.revealed.map((s) {
          final p = s.split(':');
          return Cell(int.parse(p[0]), int.parse(p[1]));
        }),
        bonus: saved.bonus,
      );
    } else {
      game = GameController(level);
    }
    game.addListener(_onGameChanged);
  }

  @override
  void dispose() {
    game.removeListener(_onGameChanged);
    game.dispose();
    _shake.dispose();
    _previewTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _onGameChanged() {
    if (firstPlay && !game.completed) {
      storage.saveProgress(
        LevelProgress(
          level: widget.levelNumber,
          found: game.found.toList(),
          revealed: game.revealed.map((c) => '${c.row}:${c.col}').toList(),
          bonus: game.bonusFound.toList(),
        ),
      );
    }
    setState(() {});
  }

  GameTheme get _theme => themeById(storage.theme);

  // ---------------- Word input ----------------
  void _onWord(String word) {
    final result = game.submit(word);
    switch (result) {
      case WordResult.tooShort:
        return;
      case WordResult.found:
        audio.play(Sfx.correct);
        audio.light();
        _flash(game.level.words[game.lastFound!].cells.toSet());
        _showPreview(word, _Preview.found);
        _checkComplete();
      case WordResult.bonus:
        audio.play(Sfx.bonus);
        audio.light();
        _showPreview(word, _Preview.bonus);
        if (firstPlay) {
          storage.addCoins(bonusCoins);
          storage.countBonusWord();
          showToast(context, 'كلمة إضافية! +$bonusCoins');
        } else {
          showToast(context, 'كلمة إضافية!');
        }
      case WordResult.alreadyFound:
      case WordResult.bonusAgain:
        audio.tap();
        _showPreview(word, _Preview.repeat);
        showToast(context, 'وجدت هذه الكلمة من قبل');
      case WordResult.invalid:
        audio.play(Sfx.wrong);
        audio.medium();
        _showPreview(word, _Preview.wrong);
        _shake.forward(from: 0);
    }
  }

  void _showPreview(String word, _Preview s) {
    _previewTimer?.cancel();
    setState(() {
      _preview = word;
      _state = s;
    });
    _previewTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _state = _Preview.idle);
    });
  }

  void _flash(Set<Cell> cells) {
    _highlightTimer?.cancel();
    setState(() => _highlight = cells);
    _highlightTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _highlight = {});
    });
  }

  // ---------------- Hints ----------------
  void _hintWithCoins() {
    if (game.completed) return;
    if (!storage.spend(hintCost)) {
      showToast(context, 'لا تكفي العملات — شاهد إعلاناً لتلميح مجاني');
      return;
    }
    _reveal();
  }

  Future<void> _hintWithAd() async {
    if (game.completed) return;
    if (!ads.canShowRewarded) {
      showToast(context, 'الإعلان غير متاح الآن، حاول لاحقاً');
      return;
    }
    final earned = await ads.showRewarded();
    if (earned && mounted) _reveal();
  }

  void _reveal() {
    final cell = game.revealHint();
    if (cell == null) return;
    audio.play(Sfx.coin);
    audio.light();
    _flash({cell});
    _checkComplete();
  }

  void _showBonusWords() {
    final words = game.level.bonus
        .where((w) => game.bonusFound.contains(normalizeArabic(w)))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF221A45),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الكلمات الإضافية (${words.length}/${game.level.bonus.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (words.isEmpty)
              const Text(
                'كوّن كلمات صحيحة غير موجودة في الشبكة لتربح عملات!',
                textAlign: TextAlign.center,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final w in words) Chip(label: Text(w))],
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------- Completion ----------------
  void _checkComplete() {
    if (!game.completed || _finished) return;
    _finished = true;
    final isNew = storage.completeLevel(widget.levelNumber);
    final reward = isNew ? 10 + game.level.words.length : 0;
    if (reward > 0) storage.addCoins(reward);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      audio.play(Sfx.win);
      audio.medium();
      _showWinDialog(reward);
    });
  }

  Future<void> _showWinDialog(int reward) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WinDialog(
        level: widget.levelNumber,
        reward: reward,
        accent: _theme.accent,
        onDouble: () async {
          final earned = await ads.showRewarded();
          if (earned) {
            storage.addCoins(reward);
            audio.play(Sfx.coin);
          }
          return earned;
        },
      ),
    );
    if (!mounted) return;
    // Interstitial after every 3 levels (frequency rules in AdService).
    await ads.onLevelCompleted();
    if (!mounted) return;
    final repo = context.read<LevelRepository>();
    final next = widget.levelNumber + 1;
    if (next > repo.count) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen(allDone: true)),
        (_) => false,
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(levelNumber: next)),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                flex: 11,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CrosswordGrid(
                    game: game,
                    accent: theme.accent,
                    highlight: _highlight,
                  ),
                ),
              ),
              _previewBubble(theme.accent),
              _actions(),
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: LetterWheel(
                    letters: game.wheel,
                    accent: theme.accent,
                    onLetter: () {
                      audio.play(Sfx.select);
                      audio.tap();
                    },
                    onChanged: (w) {
                      if (w.isEmpty) return;
                      _previewTimer?.cancel();
                      setState(() {
                        _preview = w;
                        _state = _Preview.building;
                      });
                    },
                    onWord: _onWord,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'المستوى ${widget.levelNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const CoinBadge(),
        ],
      ),
    );
  }

  Widget _previewBubble(Color accent) {
    final visible = _state != _Preview.idle && _preview.isNotEmpty;
    final color = switch (_state) {
      _Preview.found => Colors.green,
      _Preview.bonus => Colors.amber.shade700,
      _Preview.wrong => Colors.redAccent,
      _Preview.repeat => Colors.blueGrey,
      _ => accent,
    };
    return SizedBox(
      height: 52,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = t == 0 || t == 1 ? 0.0 : 10 * (0.5 - (t * 6 % 1)).abs();
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(22),
              ),
              // Plain Text keeps the Arabic letters connected (shaped).
              child: Text(
                _preview,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    final canAd = context.watch<AdService>().canShowRewarded;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundAction(
            icon: Icons.shuffle,
            label: 'خلط',
            onTap: () {
              audio.tap();
              game.shuffle();
            },
          ),
          _RoundAction(
            icon: Icons.star,
            label: '${game.bonusFound.length}',
            onTap: _showBonusWords,
          ),
          _RoundAction(
            icon: Icons.ondemand_video,
            label: 'تلميح مجاني',
            enabled: canAd,
            onTap: _hintWithAd,
          ),
          _RoundAction(
            icon: Icons.lightbulb,
            label: '$hintCost',
            onTap: _hintWithCoins,
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _WinDialog extends StatefulWidget {
  final int level;
  final int reward;
  final Color accent;
  final Future<bool> Function() onDouble;

  const _WinDialog({
    required this.level,
    required this.reward,
    required this.accent,
    required this.onDouble,
  });

  @override
  State<_WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<_WinDialog> {
  bool _doubled = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final canAd = context.watch<AdService>().canShowRewarded;
    final total = widget.reward * (_doubled ? 2 : 1);
    return AlertDialog(
      backgroundColor: const Color(0xFF2B2250),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'أحسنت! 🎉',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('أكملت المستوى ${widget.level}', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (widget.reward > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber),
                const SizedBox(width: 6),
                Text(
                  '+$total',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (widget.reward > 0 && !_doubled)
            BigButton(
              'ضاعف العملات ×2',
              icon: Icons.ondemand_video,
              color: Colors.amber,
              width: 240,
              onPressed: canAd && !_busy
                  ? () async {
                      setState(() => _busy = true);
                      final ok = await widget.onDouble();
                      if (mounted) {
                        setState(() {
                          _busy = false;
                          _doubled = ok;
                        });
                      }
                    }
                  : null,
            ),
          const SizedBox(height: 10),
          BigButton(
            'التالي',
            icon: Icons.arrow_forward,
            color: widget.accent,
            width: 240,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
