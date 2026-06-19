/// A single NOAA/NWS observation snapshot. Any field may be null when the
/// reporting station didn't include it; callers keep simulated values for the
/// missing metrics.
class LiveWeather {
  const LiveWeather({
    this.temperature,
    this.humidity,
    this.windSpeed,
    this.windDirection,
    this.redFlag = false,
    required this.fetchedAt,
  });

  final double? temperature; // °C
  final double? humidity; // %
  final double? windSpeed; // km/h
  final double? windDirection; // degrees, meteorological (wind FROM)
  final bool redFlag; // active Red Flag Warning / Fire Weather Watch
  final DateTime fetchedAt;

  bool get hasAny =>
      temperature != null || humidity != null || windSpeed != null;
}
