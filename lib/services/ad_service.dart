import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_policy.dart';
import 'storage_service.dart';

/// ===================== AdMob unit IDs =====================
/// These are Google's official TEST ids. Before publishing, replace them
/// with the EliteP ids from your AdMob console, and set the EliteP AdMob
/// App ID in android/app/src/main/AndroidManifest.xml
/// (com.google.android.gms.ads.APPLICATION_ID).
class AdIds {
  static const banner = 'ca-app-pub-3940256099942544/6300978111';
  static const interstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const rewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const appOpen = 'ca-app-pub-3940256099942544/9257395921';
}

/// Single place for all ad logic. Frequency rules live in [AdPolicy]:
/// * no ad during the first 60 s after the very first launch
/// * at least 120 s between any two full-screen ads
/// * interstitial after every 3 completed levels
/// * banner only on Home / Levels screens (never during gameplay)
/// * rewarded ads only when the player chooses to watch one
/// * "Remove Ads" disables banner / interstitial / app open only
class AdService extends ChangeNotifier {
  final StorageService storage;
  late final AdPolicy policy;

  AdService(this.storage) {
    policy = AdPolicy(
      firstLaunchMs: storage.firstLaunch,
      adsRemoved: () => storage.adsRemoved,
    );
  }

  bool _ready = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  AppOpenAd? _appOpen;
  bool _showingFullScreen = false;
  bool _skipNextAppOpen = false;
  StreamSubscription<AppState>? _appStateSub;

  bool get ready => _ready;

  bool get canShowRewarded =>
      _ready && _rewarded != null && policy.rewardedAllowed;

  /// Gathers GDPR consent (UMP) first, then initialises the SDK.
  Future<void> init() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!completer.isCompleted) completer.complete();
      }),
      (_) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {},
    );
    if (!await ConsentInformation.instance.canRequestAds()) return;

    await MobileAds.instance.initialize();
    _ready = true;
    _loadInterstitial();
    _loadRewarded();
    _loadAppOpen();
    AppStateEventNotifier.startListening();
    _appStateSub = AppStateEventNotifier.appStateStream.listen((s) {
      if (s == AppState.foreground) _showAppOpen();
    });
    notifyListeners();
  }

  /// Whether the GDPR "privacy options" entry must be offered in settings.
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  void showPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((_) {});
  }

  /// Call before leaving the app on purpose (store purchase, privacy link)
  /// so the return is not greeted by an App Open ad.
  void skipNextAppOpen() => _skipNextAppOpen = true;

  @override
  void dispose() {
    _appStateSub?.cancel();
    super.dispose();
  }

  // ---------------- Banner ----------------
  /// Returns null when a banner must not be shown right now.
  BannerAd? createBanner(VoidCallback onLoaded) {
    if (!_ready || !policy.bannerAllowed) return null;
    return BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  // ---------------- Interstitial ----------------
  void _loadInterstitial() {
    if (storage.adsRemoved) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Call after every completed level. Shows an interstitial after every
  /// 3 levels when the frequency rules allow it. Completes when the ad is
  /// closed (or immediately when no ad is shown).
  Future<void> onLevelCompleted() {
    if (!_ready || !policy.onLevelCompleted()) return Future.value();
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return Future.value();
    }
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = _fullScreenCallback(() {
      _loadInterstitial();
      if (!done.isCompleted) done.complete();
    }, interstitial: true);
    ad.show();
    return done.future;
  }

  // ---------------- Rewarded ----------------
  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (_) {
          _rewarded = null;
          notifyListeners();
          // Retry later so the "watch ad" buttons come back.
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  /// Shows a rewarded ad (always player-initiated). Completes with true
  /// only if the reward was earned.
  Future<bool> showRewarded() {
    final ad = _rewarded;
    if (ad == null || !canShowRewarded) return Future.value(false);
    _rewarded = null;
    notifyListeners();
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = _fullScreenCallback(() {
      _loadRewarded();
      if (!result.isCompleted) result.complete(earned);
    });
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }

  // ---------------- App Open ----------------
  void _loadAppOpen() {
    if (storage.adsRemoved) return;
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpen = ad,
        onAdFailedToLoad: (_) => _appOpen = null,
      ),
    );
  }

  void _showAppOpen() {
    if (_skipNextAppOpen) {
      _skipNextAppOpen = false;
      return;
    }
    final ad = _appOpen;
    if (ad == null || _showingFullScreen || !policy.fullScreenAllowed) return;
    _appOpen = null;
    ad.fullScreenContentCallback = _fullScreenCallback(_loadAppOpen);
    ad.show();
  }

  FullScreenContentCallback<T> _fullScreenCallback<T extends Ad>(
    VoidCallback onDone, {
    bool interstitial = false,
  }) {
    return FullScreenContentCallback<T>(
      onAdShowedFullScreenContent: (_) {
        _showingFullScreen = true;
        policy.onFullScreenShown(interstitial: interstitial);
      },
      onAdDismissedFullScreenContent: (ad) {
        _showingFullScreen = false;
        policy.lastFullScreen = policy.now;
        ad.dispose();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _showingFullScreen = false;
        ad.dispose();
        onDone();
      },
    );
  }
}
