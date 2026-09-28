import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'storage_service.dart';

enum Sfx { select, correct, bonus, wrong, win, coin }

/// Short sound effects and light haptics, both respecting user settings.
class AudioService {
  final StorageService storage;
  final _pool = <Sfx, AudioPlayer>{};

  AudioService(this.storage);

  Future<void> play(Sfx sfx) async {
    if (storage.muted) return;
    try {
      final player = _pool.putIfAbsent(
        sfx,
        () => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
      );
      await player.stop();
      await player.play(AssetSource('sounds/${sfx.name}.wav'));
    } catch (_) {
      // Audio is non-critical.
    }
  }

  void tap() {
    if (storage.vibration) HapticFeedback.selectionClick();
  }

  void light() {
    if (storage.vibration) HapticFeedback.lightImpact();
  }

  void medium() {
    if (storage.vibration) HapticFeedback.mediumImpact();
  }
}
