# كلمات كراش (Kalimat Crush) — EliteP

Arabic crossword word game for Android, built with Flutter (no game engine).
Package / applicationId: **`com.elitep.kalimat`**.

## Gameplay
- A wheel of 4–7 Arabic letters. Drag a finger across the letters to build a word;
  drag back onto the previous letter to undo it.
- Correct words fill the crossword grid above the wheel (right-to-left).
- Valid words that are not in the grid are **bonus words** (+3 coins each, list under the ⭐ button).
- Hints: reveal a letter for **25 coins**, or watch a rewarded ad for a **free hint**.
- Shuffle button, **daily reward** with a 7-day streak (20 → 80 coins),
  **background themes** unlocked by progress (levels 1, 15, 40, 80, 130, 190, 250).
- Level complete: +coins, optional **×2 coins** via rewarded ad.
- **300 levels** from `data/levels.json`; progress (level, coins, settings, best level,
  hints used in the current level) is saved with `shared_preferences`.

### Arabic handling
- Word comparison is normalised (`lib/game/arabic.dart`): أ إ آ ٱ → ا, ة → ه, ى → ي,
  harakat and tatweel are ignored.
- Grid cells of horizontal words keep their connected shape (initial / medial / final)
  using zero-width joiners; the word preview above the wheel is rendered as a normal
  shaped Arabic string. The whole app runs with `Locale('ar')` (RTL).

## Run
```bash
flutter pub get
flutter run            # device or emulator
flutter analyze        # must be clean
flutter test           # logic, levels data, storage, ad rules, widgets
```

## Project layout
```
lib/
  game/      arabic.dart (normalisation, letter shapes), crossword.dart (layout model +
             builder), level.dart, game_controller.dart (pure game logic)
  screens/   splash, home, levels, game, themes, settings
  services/  ad_service.dart + ad_policy.dart, iap_service.dart, storage_service.dart,
             audio_service.dart
  widgets/   letter_wheel.dart, crossword_grid.dart, daily_reward_dialog.dart, common.dart
  data/      level_repository.dart, themes.dart
data/
  arabic_words.txt   curated Arabic word list (one word per line)
  levels.json        generated levels (bundled as an asset)
tool/
  generate_levels.dart
assets/sounds/       short sound effects
store/icon_512.png   Play Store icon
```

## Regenerating the levels
The generator picks a base word for each wheel (4 → 7 letters as levels progress),
finds every dictionary word that can be spelled from those letters, lays out a
crossword (every word crosses another, no side-by-side letters, max 8 columns) and
stores the remaining words as bonus words.
```bash
dart run tool/generate_levels.dart            # 300 levels, seed 7
dart run tool/generate_levels.dart --levels 400 --seed 3
flutter test test/levels_test.dart            # validates the generated file
```
To add words, append them to `data/arabic_words.txt` (without diacritics). Words after the
`# @secondary` marker (regular verb conjugations) are accepted but used less in grids.

## AdMob — where to change IDs
The app currently uses **Google test IDs**. Before release:
1. `lib/services/ad_service.dart` → class **`AdIds`** (banner, interstitial, rewarded, app open).
2. `android/app/src/main/AndroidManifest.xml` → meta-data
   **`com.google.android.gms.ads.APPLICATION_ID`** (EliteP AdMob App ID).
3. AdMob console → Privacy & messaging: publish a GDPR message (UMP is already wired;
   consent is gathered before any ad is requested, and "خيارات الخصوصية للإعلانات"
   appears in Settings when required).

Ad rules (all in `AdService` / `AdPolicy`, unit-tested in `test/ad_policy_test.dart`):
| Format | Where / when |
|---|---|
| Banner | bottom of Home and Levels screens only (never during gameplay) |
| Interstitial | after every 3 completed levels |
| Rewarded | only when the player taps: free hint, ×2 coins |
| App Open | when returning from background |
| All | no ads in the first 60 s after the first launch; ≥120 s between any two full-screen ads |
| Remove Ads IAP | disables banner, interstitial and app open (rewarded stays optional) |

There is no "lose" state in this game, so the rewarded *revive* use-case does not apply;
rewarded ads are used for hints and doubling coins.

## In-app purchase
Create a managed (one-time) product **`remove_ads`** in Play Console → Monetize → Products
(id in `lib/services/iap_service.dart`). Settings has "إزالة الإعلانات" and "استعادة المشتريات".

## Privacy policy
Set the URL in `lib/widgets/common.dart` (`privacyPolicyUrl`) and in the Play Console listing.

## Build the AAB for Google Play
1. Create an upload keystore (once, keep it safe):
   ```bash
   keytool -genkey -v -keystore ~/elitep-upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (git-ignored):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/home/you/elitep-upload.jks
   ```
   `android/app/build.gradle.kts` already reads it and signs release builds with it
   (without the file it falls back to debug keys so `flutter run --release` works).
3. Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`; the number after `+` must increase).
4. Build:
   ```bash
   flutter build appbundle --release
   ```
5. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.
   Declare "Contains ads", complete the Data safety form (AdMob collects device IDs),
   and use `store_listing.md` for the texts.
