import 'package:flutter/material.dart';
import 'package:xand/minigame/flappy_xand.dart';

class GameOverOverlay extends StatelessWidget {
  final FlappyXandGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Game Over',
              style: TextStyle(
                fontSize: 48,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sua pontuação: ${game.score}',
              style: const TextStyle(fontSize: 24, color: Colors.white),
            ),
            Text(
              'Seu recorde: ${game.highScore}',
              style: const TextStyle(fontSize: 24, color: Colors.white),
            ),
            // Mensagem de novo recorde
            if (game.score == game.highScore && game.score > 0)
              const Text(
                'NOVO RECORDE!',
                style: TextStyle(fontSize: 28, color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: game.resetGame,
                  child: const Text('Tentar Novamente'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: game.onBack,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Voltar ao Pet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}