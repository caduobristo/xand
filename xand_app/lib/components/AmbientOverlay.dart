import 'package:flutter/material.dart';
import 'package:xand/game/xand.dart';

class AmbientOverlay extends StatelessWidget {
  final Xand game;

  const AmbientOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 40),
          onPressed: game.removeCover,
        ),
      ),
    );
  }
}