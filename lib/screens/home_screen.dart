import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/level_repository.dart';
import '../data/themes.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import '../widgets/daily_reward_dialog.dart';
import 'game_screen.dart';
import 'levels_screen.dart';
import 'settings_screen.dart';
import 'themes_screen.dart';

class HomeScreen extends StatefulWidget {
  /// True when arriving here after finishing the very last level.
  final bool allDone;
  const HomeScreen({super.key, this.allDone = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _dailyOffered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.allDone) {
        showToast(context, 'مبروك! أكملت جميع المستويات 🎉');
      }
      final storage = context.read<StorageService>();
      if (!_dailyOffered && storage.canClaimDaily()) {
        _dailyOffered = true;
        showDailyReward(context);
      }
    });
  }

  void _open(Widget screen) {
    context.read<AudioService>().tap();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    final total = context.read<LevelRepository>().count;
    final finished = s.level > total;
    final accent = themeById(s.theme).accent;
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'الإعدادات',
                      icon: const Icon(Icons.settings),
                      onPressed: () => _open(const SettingsScreen()),
                    ),
                    const Spacer(),
                    const CoinBadge(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const _Logo(),
                      const SizedBox(height: 36),
                      BigButton(
                        finished ? 'أكملت الكل!' : 'العب: المستوى ${s.level}',
                        icon: Icons.play_arrow,
                        color: accent,
                        onPressed: () => finished
                            ? _open(const LevelsScreen())
                            : _open(GameScreen(levelNumber: s.level)),
                      ),
                      const SizedBox(height: 14),
                      BigButton(
                        'المستويات',
                        icon: Icons.grid_view_rounded,
                        onPressed: () => _open(const LevelsScreen()),
                      ),
                      const SizedBox(height: 14),
                      BigButton(
                        'الخلفيات',
                        icon: Icons.palette,
                        onPressed: () => _open(const ThemesScreen()),
                      ),
                      const SizedBox(height: 14),
                      Badge(
                        isLabelVisible: s.canClaimDaily(),
                        label: const Text('!'),
                        child: BigButton(
                          'المكافأة اليومية',
                          icon: Icons.card_giftcard,
                          onPressed: () => showDailyReward(context),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Stat('أعلى مستوى', '${s.bestLevel}'),
                          const SizedBox(width: 16),
                          _Stat('كلمات إضافية', '${s.bonusWordsTotal}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const BannerSlot(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    const letters = ['ك', 'ل', 'م', 'ا', 'ت'];
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < letters.length; i++)
              Transform.rotate(
                angle: (i.isEven ? 1 : -1) * 0.08,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    letters[i],
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B2250),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'كراش',
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFB84D),
            shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
