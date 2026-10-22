import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/garage/presentation/garage_screen.dart';
import 'features/garage/state/game_controller.dart';
import 'firebase_options.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/demo_backend.dart';
import 'services/firebase_game_service.dart';
import 'services/game_backend.dart';
import 'services/missions_service.dart';
import 'services/revenuecat_service.dart';
import 'services/sound_service.dart';

/// Set with `--dart-define=DEMO=true` for the interactive web preview.
/// Skips Firebase/Ads entirely and runs the game on [DemoBackend].
const demoMode = bool.fromEnvironment('DEMO', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GameBackend backend;
  AdService? ads;
  RevenueCatService? revenueCat;

  if (demoMode) {
    final demo = DemoBackend();
    backend = demo;
    ads = DemoAdService(demo);
  } else {
    final ready = await _initFirebase();
    if (ready) {
      await _requestAdConsent();
      await AdService.initialize();
      final firebaseBackend = FirebaseGameService();
      await firebaseBackend.ensureAnonymousUser();
      backend = firebaseBackend;
      revenueCat = RevenueCatService();
      await revenueCat.configure(
        appUserId: FirebaseAuth.instance.currentUser?.uid,
      );
      final realAds = AdService(firebaseBackend);
      await realAds.preload();
      ads = realAds;
    } else {
      // Firebase unreachable (or still on placeholder config): the game
      // stays playable on the local demo backend instead of hanging.
      final demo = DemoBackend();
      backend = demo;
      ads = DemoAdService(demo);
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final missions = MissionsService(prefs);
  await missions.init();
  final sounds = SoundService();
  final analytics = AnalyticsService()..init();

  final controller = GameController(
    backend,
    adService: ads,
    revenueCat: revenueCat,
    missions: missions,
    analytics: analytics,
    sounds: sounds,
  );
  await controller.load();
  runApp(RustRichesApp(controller: controller));
}

/// Returns true when Firebase initialized cleanly. Guards everything:
/// placeholder `firebase_options.dart`, no network, missing native config.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (_) {
      // Crashlytics is best-effort.
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// GDPR/UMP consent flow. No-ops on platforms or configs without UMP.
Future<void> _requestAdConsent() async {
  try {
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
  } catch (_) {
    // Consent is best-effort; ads still serve with non-personalized fallback.
  }
}

class RustRichesApp extends StatefulWidget {
  const RustRichesApp({required this.controller, super.key});

  final GameController controller;

  @override
  State<RustRichesApp> createState() => _RustRichesAppState();
}

class _RustRichesAppState extends State<RustRichesApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.controller.saveForBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rust & Riches',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F1E5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE76F3C),
          brightness: Brightness.light,
        ),
        fontFamily: 'sans',
        cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
      ),
      home: GarageScreen(controller: widget.controller),
    );
  }
}
