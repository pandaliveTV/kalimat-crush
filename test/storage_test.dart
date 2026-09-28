import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StorageService> fresh([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final s = StorageService();
    await s.init();
    return s;
  }

  test('defaults and persistence', () async {
    final s = await fresh();
    expect(s.level, 1);
    expect(s.coins, StorageService.startCoins);
    expect(s.firstLaunch, greaterThan(0));
    s.addCoins(50);
    s.setMuted(true);
    s.selectTheme('sea');
    final again = StorageService();
    await again.init();
    expect(again.coins, StorageService.startCoins + 50);
    expect(again.muted, isTrue);
    expect(again.theme, 'sea');
  });

  test('spend fails without enough coins', () async {
    final s = await fresh({'coins': 10});
    expect(s.spend(25), isFalse);
    expect(s.coins, 10);
    expect(s.spend(10), isTrue);
    expect(s.coins, 0);
  });

  test('completing the current level unlocks the next one', () async {
    final s = await fresh();
    s.saveProgress(const LevelProgress(level: 1, found: [0]));
    expect(s.completeLevel(1), isTrue);
    expect(s.level, 2);
    expect(s.bestLevel, 1);
    expect(s.progress, isNull);
    // Replaying an old level does not advance.
    expect(s.completeLevel(1), isFalse);
    expect(s.level, 2);
  });

  test('level progress survives a restart', () async {
    final s = await fresh();
    s.saveProgress(
      const LevelProgress(
        level: 3,
        found: [0, 2],
        revealed: ['1:2'],
        bonus: ['كتب'],
      ),
    );
    final again = StorageService();
    await again.init();
    expect(again.progress!.level, 3);
    expect(again.progress!.found, [0, 2]);
    expect(again.progress!.revealed, ['1:2']);
    expect(again.progress!.bonus, ['كتب']);
  });

  test('daily reward: once per day with a growing streak', () async {
    final s = await fresh();
    final d1 = DateTime(2026, 3, 1, 10);
    expect(s.canClaimDaily(d1), isTrue);
    expect(s.claimDaily(d1), StorageService.dailyAmount(1));
    expect(s.canClaimDaily(d1.add(const Duration(hours: 5))), isFalse);
    expect(s.claimDaily(d1), 0);
    final d2 = DateTime(2026, 3, 2, 9);
    expect(s.claimDaily(d2), StorageService.dailyAmount(2));
    // Skipping a day resets the streak.
    final d4 = DateTime(2026, 3, 4, 9);
    expect(s.claimDaily(d4), StorageService.dailyAmount(1));
  });

  test('daily streak is capped', () async {
    final s = await fresh();
    for (var d = 1; d <= 10; d++) {
      s.claimDaily(DateTime(2026, 5, d));
    }
    expect(s.dailyStreak, StorageService.dailyMaxStreak);
  });
}
