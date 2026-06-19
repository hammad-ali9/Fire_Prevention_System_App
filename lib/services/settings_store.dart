import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ActivationMode { ai, threshold, off }

class AppSettings {
  AppSettings({
    this.tempThreshold = 35,
    this.humidityThreshold = 25,
    this.windThreshold = 60,
    this.riskThreshold = 75,
    this.makeItRainThreshold = 80,
    this.activationMode = ActivationMode.off,
    this.autoActivation = false,
    this.enableAlerts = true,
  });

  double tempThreshold; // °C — risk grows above this
  double humidityThreshold; // % — risk grows below this
  double windThreshold; // km/h — risk grows above this
  double riskThreshold; // % — auto-activate above this
  double makeItRainThreshold; // % — risk above this pops the Make it Rain prompt
  ActivationMode activationMode;
  bool autoActivation;
  bool enableAlerts;

  AppSettings copyWith({
    double? tempThreshold,
    double? humidityThreshold,
    double? windThreshold,
    double? riskThreshold,
    double? makeItRainThreshold,
    ActivationMode? activationMode,
    bool? autoActivation,
    bool? enableAlerts,
  }) =>
      AppSettings(
        tempThreshold: tempThreshold ?? this.tempThreshold,
        humidityThreshold: humidityThreshold ?? this.humidityThreshold,
        windThreshold: windThreshold ?? this.windThreshold,
        riskThreshold: riskThreshold ?? this.riskThreshold,
        makeItRainThreshold: makeItRainThreshold ?? this.makeItRainThreshold,
        activationMode: activationMode ?? this.activationMode,
        autoActivation: autoActivation ?? this.autoActivation,
        enableAlerts: enableAlerts ?? this.enableAlerts,
      );

  Map<String, dynamic> toJson() => {
        'tempThreshold': tempThreshold,
        'humidityThreshold': humidityThreshold,
        'windThreshold': windThreshold,
        'riskThreshold': riskThreshold,
        'makeItRainThreshold': makeItRainThreshold,
        'activationMode': activationMode.name,
        'autoActivation': autoActivation,
        'enableAlerts': enableAlerts,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        tempThreshold: (j['tempThreshold'] as num?)?.toDouble() ?? 35,
        humidityThreshold:
            (j['humidityThreshold'] as num?)?.toDouble() ?? 25,
        windThreshold: (j['windThreshold'] as num?)?.toDouble() ?? 60,
        riskThreshold: (j['riskThreshold'] as num?)?.toDouble() ?? 75,
        makeItRainThreshold:
            (j['makeItRainThreshold'] as num?)?.toDouble() ?? 80,
        activationMode: ActivationMode.values.firstWhere(
          (e) => e.name == j['activationMode'],
          orElse: () => ActivationMode.off,
        ),
        autoActivation: (j['autoActivation'] as bool?) ?? false,
        enableAlerts: (j['enableAlerts'] as bool?) ?? true,
      );
}

class SettingsStore {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _kKey = 'settings_store.settings';

  final ValueNotifier<AppSettings> settings =
      ValueNotifier<AppSettings>(AppSettings());

  AppSettings get current => settings.value;

  /// Read persisted settings. Call once at app startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return;
    try {
      settings.value =
          AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_kKey);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(settings.value.toJson()));
  }

  void update(AppSettings Function(AppSettings) mutate) {
    settings.value = mutate(settings.value);
    _persist();
  }
}
