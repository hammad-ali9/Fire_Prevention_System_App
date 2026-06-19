import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/alert_store.dart';
import 'services/auth_service.dart';
import 'services/device_store.dart';
import 'services/history_store.dart';
import 'services/live_data_service.dart';
import 'services/location_service.dart';
import 'services/make_it_rain_controller.dart';
import 'services/notification_service.dart';
import 'services/settings_store.dart';
import 'services/telemetry_simulator.dart';
import 'services/zone_store.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  // Web is a design-preview target only — skip Firebase entirely.
  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  // Restore persisted state BEFORE runApp so the first frame already sees
  // the user's zones / history / settings instead of an empty UI that then
  // pops back in.
  await Future.wait([
    ZoneStore.instance.load(),
    DeviceStore.instance.load(),
    HistoryStore.instance.load(),
    AlertStore.instance.load(),
    SettingsStore.instance.load(),
  ]);
  // Warm the GPS fix early (used as the FIRMS/NIFC focus before any zone
  // exists); never blocks startup — it falls back internally.
  if (!kIsWeb) {
    unawaited(LocationService.instance.resolve());
    unawaited(NotificationService.instance.init());
  }
  TelemetrySimulator.instance.start();
  LiveDataService.instance.start();
  runApp(const FirePreventionApp());
}

class FirePreventionApp extends StatelessWidget {
  const FirePreventionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire Prevention',
      navigatorKey: MakeItRainController.instance.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _AuthGate(),
      routes: AppRoutes.routes(),
    );
  }
}

/// Picks the start screen. On native, listens to FirebaseAuth state. On web,
/// bypasses auth (web is for UI preview only — Firebase is skipped at startup).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    // Authenticated users (including first-time signup) land on Home. The
    // home screen has an empty-state CTA that walks them into zone creation
    // when they're ready — they don't get forced into it on launch.
    if (kIsWeb) {
      return const HomeScreen();
    }
    // Seed the stream with the cached user (populated synchronously by
    // FirebaseAuth after Firebase.initializeApp completed in main). Without
    // this, the stream's first emission can briefly be null on Android,
    // bouncing already-signed-in users to the LoginScreen on every launch.
    final cached = AuthService.instance.currentUser;
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      initialData: cached,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            cached == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
