/// MapTiler tile configuration.
///
/// The API key is injected at build time via
/// `--dart-define=MAPTILER_KEY=...` (or a `--dart-define-from-file`). The
/// literal below is only a development fallback — for production builds pass
/// the key on the command line and restrict it to this app's bundle ID
/// (`com.rainfire.app`) in the MapTiler dashboard.
class MapConfig {
  MapConfig._();

  static const String apiKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'QMqCIotRfvctwuPTxjIG',
  );
  static const String styleId = 'streets-v2';

  static String tileUrlTemplate() =>
      'https://api.maptiler.com/maps/$styleId/{z}/{x}/{y}.png?key=$apiKey';

  static const String attribution =
      '© MapTiler © OpenStreetMap contributors';

  static const String userAgent = 'rainfire_app';
}
