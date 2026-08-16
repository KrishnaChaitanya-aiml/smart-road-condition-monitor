// services/api_service.dart
// Sends recorded data to the Flask backend and returns the result.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_sample.dart';

class ApiService {
  // ── Change this IP to your computer's LAN address when testing on a
  //    physical device, e.g.  'http://192.168.1.100:5000'
  // ── Use 'http://10.0.2.2:5000' when running on the Android emulator.
  static const String _baseUrl = 'http://10.0.2.2:5000';

  /// POST /analyze
  /// Returns a map: { 'road_quality': String, 'potholes': int }
  /// Throws an Exception if the request fails.
  static Future<Map<String, dynamic>> analyze({
    required List<SensorSample> samples,
    required double distance,  // metres
    required double duration,  // seconds
  }) async {
    final uri = Uri.parse('$_baseUrl/analyze');

    final body = jsonEncode({
      'samples':  samples.map((s) => s.toJson()).toList(),
      'distance': distance,
      'duration': duration,
    });

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final err = jsonDecode(response.body);
      throw Exception('Backend error ${response.statusCode}: ${err['error']}');
    }
  }
}
