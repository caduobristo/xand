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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: game.play,
              child: const Text('Brincar'),
            ),
            ElevatedButton(
              onPressed: game.eat,
              child: const Text('Comer'),
            ),
            ElevatedButton(
              onPressed: game.sleep,
              child: const Text('Dormir'),
            ),
          ],
        ),
      ),
    );
  }
}