import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../services/iap_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _privacyOptions = false;

  @override
  void initState() {
    super.initState();
    context.read<AdService>().privacyOptionsRequired().then((v) {
      if (mounted) setState(() => _privacyOptions = v);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    final iap = context.read<IapService>();
    final ads = context.read<AdService>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: GradientBackground(
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('الصوت'),
              secondary: Icon(s.muted ? Icons.volume_off : Icons.volume_up),
              value: !s.muted,
              onChanged: (v) => s.setMuted(!v),
            ),
            SwitchListTile(
              title: const Text('الاهتزاز'),
              secondary: const Icon(Icons.vibration),
              value: s.vibration,
              onChanged: s.setVibration,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(
                s.adsRemoved
                    ? 'تمت إزالة الإعلانات — شكراً لك!'
                    : 'إزالة الإعلانات',
              ),
              subtitle: s.adsRemoved
                  ? null
                  : Text(
                      iap.product?.price ??
                          'يزيل إعلانات البانر والإعلانات البينية',
                    ),
              onTap: s.adsRemoved
                  ? null
                  : () async {
                      ads.skipNextAppOpen();
                      final ok = await iap.buyRemoveAds();
                      if (!ok && context.mounted) {
                        showToast(context, 'المتجر غير متاح حالياً');
                      }
                    },
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('استعادة المشتريات'),
              onTap: () {
                ads.skipNextAppOpen();
                iap.restore();
              },
            ),
            if (_privacyOptions)
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('خيارات الخصوصية للإعلانات'),
                onTap: ads.showPrivacyOptions,
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('سياسة الخصوصية'),
              onTap: () => openPrivacyPolicy(context),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('كلمات كراش — EliteP'),
              subtitle: Text('الإصدار 1.0.0'),
            ),
          ],
        ),
      ),
    );
  }
}
