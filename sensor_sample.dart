// models/sensor_sample.dart
// Simple data class holding one accelerometer reading.

class SensorSample {
  final double ax; // acceleration X  (m/s²)
  final double ay; // acceleration Y  (m/s²)
  final double az; // acceleration Z  (m/s²)

  const SensorSample({
    required this.ax,
    required this.ay,
    required this.az,
  });

  /// Serialise to JSON for the HTTP POST body.
  Map<String, dynamic> toJson() => {
        'ax': ax,
        'ay': ay,
        'az': az,
      };
}
