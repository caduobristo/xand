import 'package:flutter/material.dart';
import 'package:xand/game/xand.dart';

class ActionCancelOverlay extends StatelessWidget {
  final Xand game;

  const ActionCancelOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Parar Ação'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          onPressed: game.cancelCurrentAction,
        ),
      ),
    );
  }
}