import 'package:flutter/material.dart';
import 'package:xand/game/xand.dart';

class MenuOverlay extends StatelessWidget {
  final Xand game;

  const MenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildButtonRow(context), // Passa o BuildContext
        ),
      ),
    );
  }

  Widget _buildButtonRow(BuildContext context) {
    // Aceita BuildContext
    if (game.isNight) {
      return ElevatedButton(
        onPressed: game.sleep,
        child: const Text('Acordar'),
      );
    }

    if (game.isRecording) {
      return ElevatedButton(
        onPressed: () => game.hear(context), // Passa o context para hear()
        child: const Text('Parar Gravação'),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: () => game.hear(context), // Passa o context para hear()
          child: const Text('Falar com XAND'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: game.showCampfire,
          child: const Text('Fogueira'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
