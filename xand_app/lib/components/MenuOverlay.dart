import 'package:flutter/material.dart';
import 'package:xand/game/xand.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MenuOverlay extends StatelessWidget {
  final Xand game;

  const MenuOverlay({super.key, required this.game});

  Future<void> falarComXand(BuildContext context) async {
    final url = Uri.parse('http://192.168.15.70:5000/xand/ask');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fala = data['text'];

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('XAND'),
            content: Text(fala),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        print('Erro do servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao se comunicar com XAND: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildButtonRow(),
        ),
      ),
    );
  }

  Widget _buildButtonRow() {
    if (game.isNight) {
      return ElevatedButton(
        onPressed: game.sleep,
        child: const Text('Acordar'),
      );
    }

    if (game.isRecording) {
      return ElevatedButton(
        onPressed: game.hear,
        child: const Text('Parar'),
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
        // O botão de "Ouvir" agora só aparece no estado padrão
        ElevatedButton(
          onPressed: game.hear,
          child: const Text('Ouvir'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: game.playGuitar,
          child: const Text('Tocar guitarra'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => falarComXand(game.buildContext!),
          child: const Text('Falar com XAND'),
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
