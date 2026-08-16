// services/recording_service.dart
// Manages the lifecycle of a recording session:
//   start → collect accelerometer + GPS → stop → return summary.

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/sensor_sample.dart';

class RecordingSession {
  final List<SensorSample> samples;
  final double distanceMetres;
  final double durationSeconds;

  const RecordingSession({
    required this.samples,
    required this.distanceMetres,
    required this.durationSeconds,
  });
}

class RecordingService {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _gpsSub;

  final List<SensorSample> _samples = [];
  Position? _lastPosition;
  double _totalDistance = 0.0;
  DateTime? _startTime;

  bool get isRecording => _accelSub != null;

  // ── start ──────────────────────────────────────────────────────
  Future<void> start() async {
    _samples.clear();
    _totalDistance = 0.0;
    _lastPosition  = null;
    _startTime     = DateTime.now();

    // Request location permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    // Subscribe to accelerometer at ~50 Hz
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen((event) {
      _samples.add(SensorSample(ax: event.x, ay: event.y, az: event.z));
    });

    // Subscribe to GPS location updates
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // update every 1 metre
    );

    _gpsSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((pos) {
      if (_lastPosition != null) {
        _totalDistance += Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
      }
      _lastPosition = pos;
    });
  }

  // ── stop ───────────────────────────────────────────────────────
  Future<RecordingSession> stop() async {
    await _accelSub?.cancel();
    await _gpsSub?.cancel();
    _accelSub = null;
    _gpsSub   = null;

    final duration = _startTime == null
        ? 0.0
        : DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;

    // If GPS unavailable, estimate distance from duration × assumed 30 km/h
    final distance =
        _totalDistance > 0 ? _totalDistance : duration * (30000 / 3600);

    return RecordingSession(
      samples:         List.unmodifiable(_samples),
      distanceMetres:  distance,
      durationSeconds: duration,
    );
  }
}
