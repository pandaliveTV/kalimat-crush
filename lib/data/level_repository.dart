import 'dart:convert';

import 'package:flutter/services.dart';

import '../game/level.dart';

/// Loads the generated puzzles from data/levels.json
/// (created by `dart run tool/generate_levels.dart`).
class LevelRepository {
  static const assetPath = 'data/levels.json';

  final List<Level> levels;
  LevelRepository(this.levels);

  static Future<LevelRepository> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    return LevelRepository(parse(raw));
  }

  static List<Level> parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final l in json['levels'] as List)
        Level.fromJson(l as Map<String, dynamic>),
    ];
  }

  int get count => levels.length;

  /// 1-based level lookup.
  Level byNumber(int n) => levels[(n - 1).clamp(0, levels.length - 1)];
}
