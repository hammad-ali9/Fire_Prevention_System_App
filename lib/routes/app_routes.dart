import 'package:flutter/material.dart';

import '../screens/activation_history_screen.dart';
import '../screens/alert_screen.dart';
import '../screens/environmental_scan_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/map_view_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/select_zone_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/zone_creation_screen.dart';

/// Static named routes for the prototype. Real builds would swap this for
/// go_router or a state-driven navigator.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String selectZone = '/select-zone';
  static const String envScan = '/environmental-scan';
  static const String alert = '/alert';
  static const String history = '/activation-history';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String zoneCreate = '/zone-create';
  static const String mapView = '/map-view';

  static Map<String, WidgetBuilder> routes() => {
        login: (_) => const LoginScreen(),
        signup: (_) => const SignupScreen(),
        forgotPassword: (_) => const ForgotPasswordScreen(),
        home: (_) => const HomeScreen(),
        selectZone: (_) => const SelectZoneScreen(),
        envScan: (_) => const EnvironmentalScanScreen(),
        alert: (_) => const AlertScreen(),
        history: (_) => const ActivationHistoryScreen(),
        reports: (_) => const ReportsScreen(),
        settings: (_) => const SettingsScreen(),
        zoneCreate: (_) => const ZoneCreationScreen(),
        mapView: (_) => const MapViewScreen(),
      };
}
