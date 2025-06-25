import 'package:flutter/material.dart';
import 'package:xand/game/xand.dart';

class StopwatchOverlay extends StatelessWidget {
  final Xand game;

  const StopwatchOverlay({super.key, required this.game});

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: game.stopwatchSecondsNotifier,
              builder: (context, value, child) {
                return Text(
                  _formatTime(value),
                  style: const TextStyle(
                    fontSize: 96,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: game.hideStopwatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 20)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}