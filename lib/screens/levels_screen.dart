import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/level_repository.dart';
import '../data/themes.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import 'game_screen.dart';

/// Level map. Completed levels can be replayed; banner shown at the bottom.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  static const perRow = 5;
  static const rowHeight = 72.0;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final current = context.read<StorageService>().level;
    final row = ((current - 1) ~/ perRow) - 2;
    _scroll = ScrollController(
      initialScrollOffset: row > 0 ? row * rowHeight : 0,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    final total = context.read<LevelRepository>().count;
    final accent = themeById(s.theme).accent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المستويات'),
        backgroundColor: Colors.transparent,
        actions: const [
          Padding(padding: EdgeInsets.all(8), child: CoinBadge()),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GridView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: perRow,
                    mainAxisExtent: rowHeight - 12,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: total,
                  itemBuilder: (context, i) {
                    final n = i + 1;
                    final done = n < s.level;
                    final current = n == s.level;
                    final locked = n > s.level;
                    return Material(
                      color: current
                          ? accent
                          : done
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: locked
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GameScreen(levelNumber: n),
                                ),
                              ),
                        child: Center(
                          child: locked
                              ? const Icon(Icons.lock, color: Colors.white38)
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$n',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: current
                                            ? Colors.black87
                                            : const Color(0xFF2B2250),
                                      ),
                                    ),
                                    if (done)
                                      const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
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
