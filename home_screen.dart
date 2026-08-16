// screens/home_screen.dart
// Main screen: Start / Stop recording buttons + live sample counter.

import 'package:flutter/material.dart';
import '../services/recording_service.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RecordingService _recorder = RecordingService();

  bool _recording  = false;
  bool _uploading  = false;
  int  _sampleCount = 0;

  // Periodically refresh the sample count while recording
  void _refreshCount() {
    if (!_recording) return;
    setState(() => _sampleCount = _recorder.isRecording ? _sampleCount + 1 : _sampleCount);
    Future.delayed(const Duration(milliseconds: 500), _refreshCount);
  }

  // ── Start recording ────────────────────────────────────────────
  Future<void> _startRecording() async {
    try {
      await _recorder.start();
      setState(() {
        _recording   = true;
        _sampleCount = 0;
      });
      _refreshCount();
    } catch (e) {
      _showError('Could not start recording: $e');
    }
  }

  // ── Stop recording & upload ────────────────────────────────────
  Future<void> _stopRecording() async {
    setState(() { _recording = false; _uploading = true; });

    try {
      final session = await _recorder.stop();
      setState(() => _sampleCount = session.samples.length);

      if (session.samples.length < 100) {
        _showError('Need at least 100 samples (got ${session.samples.length}). Drive a bit longer!');
        setState(() => _uploading = false);
        return;
      }

      // Send to Flask backend
      final result = await ApiService.analyze(
        samples:  session.samples,
        distance: session.distanceMetres,
        duration: session.durationSeconds,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            distance:    session.distanceMetres,
            duration:    session.durationSeconds,
            roadQuality: result['road_quality'] as String,
            potholes:    result['potholes'] as int,
          ),
        ),
      );
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Road Monitor')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── App icon / graphic ──────────────────────────────
              Icon(
                Icons.directions_car,
                size: 96,
                color: _recording ? Colors.red : Colors.blueGrey,
              ),
              const SizedBox(height: 24),

              // ── Status text ─────────────────────────────────────
              Text(
                _uploading
                    ? 'Analysing road data…'
                    : _recording
                        ? 'Recording… ($_sampleCount samples)'
                        : 'Press Start to begin monitoring',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ── Animated indicator ──────────────────────────────
              if (_recording)
                const LinearProgressIndicator()
              else if (_uploading)
                const CircularProgressIndicator(),

              const SizedBox(height: 40),

              // ── Buttons ─────────────────────────────────────────
              if (!_recording && !_uploading)
                ElevatedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
                  label: const Text('Start Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                ),

              if (_recording)
                ElevatedButton.icon(
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop & Analyse'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                ),

              const SizedBox(height: 24),
              const Text(
                'Drive over roads to collect vibration data.\nThe ML model will detect potholes automatically.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
