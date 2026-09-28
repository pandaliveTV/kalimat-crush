import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved state of the level currently being played, so leaving the game
/// never loses found words or purchased hints.
class LevelProgress {
  final int level;
  final List<int> found;
  final List<String> revealed;
  final List<String> bonus;

  const LevelProgress({
    required this.level,
    this.found = const [],
    this.revealed = const [],
    this.bonus = const [],
  });

  Map<String, Object> toJson() => {
    'level': level,
    'found': found,
    'revealed': revealed,
    'bonus': bonus,
  };

  factory LevelProgress.fromJson(Map<String, dynamic> j) => LevelProgress(
    level: j['level'] as int,
    found: (j['found'] as List).cast<int>(),
    revealed: (j['revealed'] as List).cast<String>(),
    bonus: (j['bonus'] as List).cast<String>(),
  );
}

/// Persists progress (level, coins, settings, best level, unlocks) locally.
class StorageService extends ChangeNotifier {
  static const startCoins = 100;
  static const dailyBase = 20;
  static const dailyStep = 10;
  static const dailyMaxStreak = 7;

  late SharedPreferences _p;

  /// Next level to play (1-based). Levels below it are completed.
  int level = 1;
  int coins = startCoins;

  /// Highest level ever completed (the game's "high score").
  int bestLevel = 0;
  int bonusWordsTotal = 0;
  bool muted = false;
  bool vibration = true;
  bool adsRemoved = false;
  String theme = 'night';
  String? lastDailyClaim;
  int dailyStreak = 0;
  LevelProgress? progress;

  /// Milliseconds since epoch of the very first launch.
  int firstLaunch = 0;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    level = _p.getInt('level') ?? 1;
    coins = _p.getInt('coins') ?? startCoins;
    bestLevel = _p.getInt('bestLevel') ?? 0;
    bonusWordsTotal = _p.getInt('bonusWordsTotal') ?? 0;
    muted = _p.getBool('muted') ?? false;
    vibration = _p.getBool('vibration') ?? true;
    adsRemoved = _p.getBool('adsRemoved') ?? false;
    theme = _p.getString('theme') ?? 'night';
    lastDailyClaim = _p.getString('lastDailyClaim');
    dailyStreak = _p.getInt('dailyStreak') ?? 0;
    final raw = _p.getString('progress');
    if (raw != null) {
      try {
        progress = LevelProgress.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        progress = null;
      }
    }
    firstLaunch = _p.getInt('firstLaunch') ?? 0;
    if (firstLaunch == 0) {
      firstLaunch = DateTime.now().millisecondsSinceEpoch;
      await _p.setInt('firstLaunch', firstLaunch);
    }
  }

  // ---------------- Coins ----------------
  void addCoins(int n) {
    coins += n;
    _p.setInt('coins', coins);
    notifyListeners();
  }

  bool spend(int n) {
    if (coins < n) return false;
    addCoins(-n);
    return true;
  }

  // ---------------- Levels ----------------
  /// Marks [n] as completed. Returns true when it was the current level
  /// (first completion), which is the only case that unlocks the next one.
  bool completeLevel(int n) {
    if (n > bestLevel) {
      bestLevel = n;
      _p.setInt('bestLevel', bestLevel);
    }
    if (progress?.level == n) clearProgress();
    if (n != level) {
      notifyListeners();
      return false;
    }
    level = n + 1;
    _p.setInt('level', level);
    notifyListeners();
    return true;
  }

  void saveProgress(LevelProgress p) {
    progress = p;
    _p.setString('progress', jsonEncode(p.toJson()));
  }

  void clearProgress() {
    progress = null;
    _p.remove('progress');
  }

  void countBonusWord() {
    bonusWordsTotal++;
    _p.setInt('bonusWordsTotal', bonusWordsTotal);
  }

  // ---------------- Daily reward ----------------
  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool canClaimDaily([DateTime? now]) =>
      lastDailyClaim != _day(now ?? DateTime.now());

  /// Streak the player would have if they claimed now.
  int nextStreak([DateTime? now]) {
    final today = now ?? DateTime.now();
    final yesterday = _day(DateTime(today.year, today.month, today.day - 1));
    if (lastDailyClaim == yesterday) {
      return dailyStreak >= dailyMaxStreak ? dailyMaxStreak : dailyStreak + 1;
    }
    return 1;
  }

  static int dailyAmount(int streak) => dailyBase + (streak - 1) * dailyStep;

  /// Claims today's reward. Returns the coins granted (0 if already claimed).
  int claimDaily([DateTime? now]) {
    final today = now ?? DateTime.now();
    if (!canClaimDaily(today)) return 0;
    dailyStreak = nextStreak(today);
    lastDailyClaim = _day(today);
    _p.setInt('dailyStreak', dailyStreak);
    _p.setString('lastDailyClaim', lastDailyClaim!);
    final amount = dailyAmount(dailyStreak);
    addCoins(amount);
    return amount;
  }

  // ---------------- Settings ----------------
  void setMuted(bool v) {
    muted = v;
    _p.setBool('muted', v);
    notifyListeners();
  }

  void setVibration(bool v) {
    vibration = v;
    _p.setBool('vibration', v);
    notifyListeners();
  }

  void setAdsRemoved(bool v) {
    adsRemoved = v;
    _p.setBool('adsRemoved', v);
    notifyListeners();
  }

  void selectTheme(String id) {
    theme = id;
    _p.setString('theme', id);
    notifyListeners();
  }
}
