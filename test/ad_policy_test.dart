import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat/services/ad_policy.dart';

void main() {
  late DateTime now;
  late bool removed;
  late AdPolicy policy;
  final start = DateTime(2026, 1, 1, 12);

  setUp(() {
    now = start;
    removed = false;
    policy = AdPolicy(
      firstLaunchMs: start.millisecondsSinceEpoch,
      adsRemoved: () => removed,
      now: () => now,
    );
  });

  test('no ads at all in the first 60 seconds of the first launch', () {
    now = start.add(const Duration(seconds: 59));
    expect(policy.inGrace, isTrue);
    expect(policy.bannerAllowed, isFalse);
    expect(policy.rewardedAllowed, isFalse);
    expect(policy.fullScreenAllowed, isFalse);
    now = start.add(const Duration(seconds: 60));
    expect(policy.bannerAllowed, isTrue);
    expect(policy.rewardedAllowed, isTrue);
    expect(policy.fullScreenAllowed, isTrue);
  });

  test('interstitial only after every 3 levels', () {
    now = start.add(const Duration(minutes: 5));
    expect(policy.onLevelCompleted(), isFalse);
    expect(policy.onLevelCompleted(), isFalse);
    expect(policy.onLevelCompleted(), isTrue);
    policy.onFullScreenShown(interstitial: true);
    now = now.add(const Duration(minutes: 10));
    expect(policy.onLevelCompleted(), isFalse);
    expect(policy.onLevelCompleted(), isFalse);
    expect(policy.onLevelCompleted(), isTrue);
  });

  test('at least 120 seconds between two full-screen ads', () {
    now = start.add(const Duration(minutes: 5));
    policy.onFullScreenShown(); // e.g. an app open ad
    now = now.add(const Duration(seconds: 119));
    expect(policy.fullScreenAllowed, isFalse);
    policy.onLevelCompleted();
    policy.onLevelCompleted();
    expect(policy.onLevelCompleted(), isFalse, reason: 'gap not reached');
    now = now.add(const Duration(seconds: 1));
    expect(policy.fullScreenAllowed, isTrue);
    // Counter kept, so the interstitial shows on the next level.
    expect(policy.onLevelCompleted(), isTrue);
  });

  test('remove ads disables banner/interstitial/app open but not rewarded', () {
    now = start.add(const Duration(minutes: 5));
    removed = true;
    expect(policy.bannerAllowed, isFalse);
    expect(policy.fullScreenAllowed, isFalse);
    expect(policy.rewardedAllowed, isTrue);
  });
}
