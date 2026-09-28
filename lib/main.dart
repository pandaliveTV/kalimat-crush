import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/level_repository.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final storage = StorageService();
  await storage.init();
  final levels = await LevelRepository.load();
  final ads = AdService(storage);
  final iap = IapService(storage);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storage),
        ChangeNotifierProvider.value(value: ads),
        Provider.value(value: iap),
        Provider.value(value: levels),
        Provider.value(value: AudioService(storage)),
      ],
      child: const KalimatApp(),
    ),
  );
  // Consent (UMP) + SDK init run in the background so the splash is not
  // blocked. No ad is requested before consent is gathered.
  ads.init();
  iap.init();
}

class KalimatApp extends StatelessWidget {
  const KalimatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كلمات كراش',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF6A3093),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B1446),
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
