/// Pure frequency rules for ads (no plugin code, so it is unit-testable).
///
/// * No ad at all during the first 60 s after the very first launch.
/// * At least 120 s between any two full-screen ads.
/// * Interstitial only after every 3 completed levels.
/// * "Remove Ads" disables banner / interstitial / app open (not rewarded).
class AdPolicy {
  static const minGap = Duration(seconds: 120);
  static const firstRunGrace = Duration(seconds: 60);
  static const levelsPerInterstitial = 3;

  final int firstLaunchMs;
  final bool Function() adsRemoved;
  final DateTime Function() _now;

  DateTime? lastFullScreen;
  int levelsSinceInterstitial = 0;

  AdPolicy({
    required this.firstLaunchMs,
    required this.adsRemoved,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  DateTime get now => _now();

  /// Time left before any ad may be shown after the first launch.
  Duration get graceLeft {
    final left =
        firstLaunchMs +
        firstRunGrace.inMilliseconds -
        now.millisecondsSinceEpoch;
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  bool get inGrace => graceLeft > Duration.zero;

  bool get gapOk =>
      lastFullScreen == null || now.difference(lastFullScreen!) >= minGap;

  bool get bannerAllowed => !adsRemoved() && !inGrace;

  bool get rewardedAllowed => !inGrace;

  /// Interstitial / App Open.
  bool get fullScreenAllowed => !adsRemoved() && !inGrace && gapOk;

  /// Call when a level is completed; returns true when an interstitial
  /// should be shown now.
  bool onLevelCompleted() {
    levelsSinceInterstitial++;
    return levelsSinceInterstitial >= levelsPerInterstitial &&
        fullScreenAllowed;
  }

  void onFullScreenShown({bool interstitial = false}) {
    lastFullScreen = now;
    if (interstitial) levelsSinceInterstitial = 0;
  }
}
