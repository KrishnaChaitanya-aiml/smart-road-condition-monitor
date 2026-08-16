// screens/result_screen.dart
// Displays the analysis result returned from the Flask backend.

import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final double distance;      // metres
  final double duration;      // seconds
  final String roadQuality;   // "Smooth" | "Rough" | "Pothole"
  final int    potholes;

  const ResultScreen({
    super.key,
    required this.distance,
    required this.duration,
    required this.roadQuality,
    required this.potholes,
  });

  // Choose colour based on road quality label
  Color _qualityColor() {
    switch (roadQuality) {
      case 'Smooth':  return Colors.green[700]!;
      case 'Rough':   return Colors.orange[800]!;
      default:        return Colors.red[700]!;   // Pothole
    }
  }

  IconData _qualityIcon() {
    switch (roadQuality) {
      case 'Smooth':  return Icons.check_circle_outline;
      case 'Rough':   return Icons.warning_amber_outlined;
      default:        return Icons.dangerous_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final distKm  = (distance / 1000).toStringAsFixed(2);
    final durMin  = (duration / 60).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Road Analysis Result')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Quality badge ─────────────────────────────────────
            Card(
              color: _qualityColor().withOpacity(0.12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _qualityColor(), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Column(
                  children: [
                    Icon(_qualityIcon(), size: 64, color: _qualityColor()),
                    const SizedBox(height: 12),
                    Text(
                      'Road Quality',
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.grey),
                    ),
                    Text(
                      roadQuality,
                      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                            color: _qualityColor(),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Stats grid ────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _statCard('Potholes Detected', '$potholes', Icons.report_problem)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Distance', '$distKm km', Icons.straighten)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('Duration', '$durMin min', Icons.timer_outlined)),
              ],
            ),

            const Spacer(),

            // ── Back button ───────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('New Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1565C0), size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
