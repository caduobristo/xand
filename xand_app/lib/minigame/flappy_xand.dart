import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:xand/minigame/components/flying_xand.dart';
import 'package:xand/minigame/components/pipe.dart';

class FlappyXandGame extends FlameGame
    with HasCollisionDetection, TapDetector {
  final VoidCallback onBack;
  late FlyingXand _bird;
  late TimerComponent _pipeSpawner;

  bool isGameOver = false;

  FlappyXandGame({required this.onBack});

  @override
  Future<void> onLoad() async {
    add(
      SpriteComponent(
        sprite: await loadSprite('background.png'),
        size: size,
      ),
    );

    _bird = FlyingXand();
    add(_bird);

    // Spawner de canos
    _pipeSpawner = TimerComponent(
      period: 2.5,
      repeat: true,
      onTick: () => add(PipeGroup()),
    );
    add(_pipeSpawner);
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    if (!isGameOver) {
      _bird.fly();
    }
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;
    pauseEngine();
    overlays.add('GameOverOverlay');
  }

  void resetGame() {
    isGameOver = false;
    resumeEngine();
    // Remove todos os canos e o pássaro antigo
    children.whereType<PipeGroup>().forEach((pipe) => pipe.removeFromParent());
    _bird.removeFromParent();

    // Adiciona um novo pássaro
    _bird = FlyingXand();
    add(_bird);

    overlays.remove('GameOverOverlay');
  }
}