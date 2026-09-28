import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/themes.dart';
import '../services/ad_service.dart';
import '../services/storage_service.dart';

/// TODO(EliteP): replace with the published EliteP privacy policy URL.
const privacyPolicyUrl = 'https://elitep.com/privacy';

Future<void> openPrivacyPolicy(BuildContext context) {
  context.read<AdService>().skipNextAppOpen();
  return launchUrl(
    Uri.parse(privacyPolicyUrl),
    mode: LaunchMode.externalApplication,
  );
}

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = themeById(
      context.select<StorageService, String>((s) => s.theme),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.colors,
        ),
      ),
      child: child,
    );
  }
}

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final coins = context.select<StorageService, int>((s) => s.coins);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final double width;
  const BigButton(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.color = Colors.white,
    this.width = 280,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.play_arrow),
        label: Text(label),
      ),
    );
  }
}

/// Banner shown only on the Home and Levels screens (never during gameplay).
/// Waits for the SDK / first-run grace period before requesting an ad.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _tryLoad();
  }

  void _tryLoad() {
    if (!mounted || _ad != null) return;
    final ads = context.read<AdService>();
    if (context.read<StorageService>().adsRemoved) return;
    _ad = ads.createBanner(() {
      if (mounted) setState(() => _loaded = true);
    });
    if (_ad == null) {
      // SDK not ready yet or still in the first-launch grace period.
      final wait = ads.ready
          ? ads.policy.graceLeft + const Duration(seconds: 1)
          : const Duration(seconds: 5);
      _retry = Timer(wait, _tryLoad);
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final removed = context.select<StorageService, bool>((s) => s.adsRemoved);
    final ad = _ad;
    if (removed || !_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

void showToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
}
