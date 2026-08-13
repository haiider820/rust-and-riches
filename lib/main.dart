import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/garage/presentation/garage_screen.dart';
import 'services/ad_service.dart';
import 'features/garage/state/game_controller.dart';
import 'firebase_options.dart';
import 'services/firebase_game_service.dart';
import 'services/revenuecat_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AdService.initialize();
  final backend = FirebaseGameService();
  await backend.ensureAnonymousUser();
  final revenueCat = RevenueCatService();
  await revenueCat.configure(appUserId: FirebaseAuth.instance.currentUser?.uid);
  final ads = AdService(backend);
  await ads.preload();
  final controller = GameController(
    backend,
    adService: ads,
    revenueCat: revenueCat,
  );
  await controller.load();
  runApp(RustRichesApp(controller: controller));
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
