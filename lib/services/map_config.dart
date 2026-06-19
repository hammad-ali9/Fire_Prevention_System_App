/// MapTiler tile configuration. Free-tier key used by the POC; swap via env
/// before shipping production builds.
class MapConfig {
  MapConfig._();

  static const String apiKey = 'QMqCIotRfvctwuPTxjIG';
  static const String styleId = 'streets-v2';

  static String tileUrlTemplate() =>
      'https://api.maptiler.com/maps/$styleId/{z}/{x}/{y}.png?key=$apiKey';

  static const String attribution =
      '© MapTiler © OpenStreetMap contributors';

  static const String userAgent = 'fire_prevention_poc';
}
