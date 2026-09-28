import 'package:flutter/material.dart';

/// Background themes unlocked by progress (reaching a level).
class GameTheme {
  final String id;
  final String name;
  final int unlockLevel;
  final List<Color> colors;
  final Color accent;

  const GameTheme(
    this.id,
    this.name,
    this.unlockLevel,
    this.colors,
    this.accent,
  );
}

const gameThemes = [
  GameTheme('night', 'ليل الصحراء', 1, [
    Color(0xFF1B1446),
    Color(0xFF3B2A7A),
    Color(0xFF8E4C9E),
  ], Color(0xFFFFB84D)),
  GameTheme('sea', 'البحر', 15, [
    Color(0xFF03256C),
    Color(0xFF2541B2),
    Color(0xFF1768AC),
  ], Color(0xFF06BEE1)),
  GameTheme('oasis', 'الواحة', 40, [
    Color(0xFF0B3D2E),
    Color(0xFF16664A),
    Color(0xFF3FA66B),
  ], Color(0xFFF4D35E)),
  GameTheme('sunset', 'الغروب', 80, [
    Color(0xFF3A0F3F),
    Color(0xFFB6325C),
    Color(0xFFF08A4B),
  ], Color(0xFFFFE066)),
  GameTheme('dunes', 'الكثبان', 130, [
    Color(0xFF5C3317),
    Color(0xFFA0522D),
    Color(0xFFE0A96D),
  ], Color(0xFFFFF3B0)),
  GameTheme('aurora', 'الشفق', 190, [
    Color(0xFF051937),
    Color(0xFF004D7A),
    Color(0xFF00BF72),
  ], Color(0xFFA8EB12)),
  GameTheme('royal', 'الملكي', 250, [
    Color(0xFF141E30),
    Color(0xFF243B55),
    Color(0xFF8A6D3B),
  ], Color(0xFFFFD700)),
];

GameTheme themeById(String id) =>
    gameThemes.firstWhere((t) => t.id == id, orElse: () => gameThemes.first);

/// A theme is unlocked once the player has reached its level.
bool isThemeUnlocked(GameTheme t, int currentLevel) =>
    currentLevel >= t.unlockLevel;
