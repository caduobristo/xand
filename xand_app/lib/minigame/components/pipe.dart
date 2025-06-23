import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:xand/minigame/flappy_xand.dart';

class PipeGroup extends PositionComponent with HasGameRef<FlappyXandGame> {
  final double _pipeSpeed = 200;
  final double pipeGap; // Espaço entre os canos

  PipeGroup({required this.pipeGap});

  @override
  Future<void> onLoad() async {
    final random = Random();
    final pipeHeight = gameRef.size.y;
    final gapPosition =
        random.nextDouble() * (pipeHeight - pipeGap - 100) + 50;

    // Cano de baixo
    final bottomPipe = await _buildPipe(gapPosition + pipeGap, false);
    add(bottomPipe);

    // Cano de cima
    final topPipe = await _buildPipe(gapPosition, true);
    add(topPipe);

    // Inicia a posição do grupo fora da tela
    position.x = gameRef.size.x;
  }

  Future<SpriteComponent> _buildPipe(double yPos, bool isTop) async {
    final pipe = SpriteComponent(
      sprite: await gameRef.loadSprite('pipe.png'),
      size: Vector2(80, gameRef.size.y / 2),
    );

    pipe.position = Vector2(0, yPos);

    if (isTop) {
      pipe.flipVertically();
      pipe.position.y -= pipe.size.y;
    }

    pipe.add(RectangleHitbox());
    return pipe;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= _pipeSpeed * dt;

    // Remove o grupo de canos quando ele sai da tela
    if (position.x < -width) {
      removeFromParent();
    }
  }
}