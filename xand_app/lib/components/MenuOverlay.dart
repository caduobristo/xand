// lib/components/MenuOverlay.dart

import 'package:flutter/material.dart';
import 'package:xand/game/xand.dart';
import 'package:http/http.dart' as http; // Manter
import 'dart:convert'; // Manter
import 'package:http_parser/http_parser.dart'; // Manter

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

  Widget _buildButtonRow(BuildContext context) { // Aceita BuildContext
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
          onPressed: game.play,
          child: const Text('Brincar'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: game.eat,
          child: const Text('Comer'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: game.sleep,
          child: const Text('Dormir'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => game.hear(context), // Passa o context para hear()
          child: const Text('Falar com XAND'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: game.playGuitar,
          child: const Text('Tocar guitarra'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: game.onPlayMinigame,
          child: const Text('Xand, o Voador'),
        ),
      ],
    );
  }
}