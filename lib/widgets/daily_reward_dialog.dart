import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../services/storage_service.dart';
import 'common.dart';

Future<void> showDailyReward(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const DailyRewardDialog(),
);

/// Daily reward with a 7-day streak (20, 30, ... 80 coins).
class DailyRewardDialog extends StatelessWidget {
  const DailyRewardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    final canClaim = s.canClaimDaily();
    final today = canClaim ? s.nextStreak() : s.dailyStreak;
    return AlertDialog(
      backgroundColor: const Color(0xFF2B2250),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'المكافأة اليومية',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 1; d <= StorageService.dailyMaxStreak; d++)
                _DayTile(
                  day: d,
                  coins: StorageService.dailyAmount(d),
                  done: d < today || (!canClaim && d == today),
                  current: canClaim && d == today,
                ),
            ],
          ),
          const SizedBox(height: 16),
          BigButton(
            canClaim ? 'استلم المكافأة' : 'عد غداً',
            icon: Icons.card_giftcard,
            color: Colors.amber,
            width: 220,
            onPressed: canClaim
                ? () {
                    final got = s.claimDaily();
                    context.read<AudioService>().play(Sfx.coin);
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(context).pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('حصلت على $got عملة!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final int day;
  final int coins;
  final bool done;
  final bool current;

  const _DayTile({
    required this.day,
    required this.coins,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: current
            ? Colors.amber
            : done
            ? Colors.green.withValues(alpha: 0.6)
            : Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'يوم $day',
            style: TextStyle(
              fontSize: 12,
              color: current ? Colors.black87 : Colors.white,
            ),
          ),
          Icon(
            done ? Icons.check_circle : Icons.monetization_on,
            color: current ? Colors.black87 : Colors.amber,
          ),
          Text(
            '$coins',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: current ? Colors.black87 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
