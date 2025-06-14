import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:xand/minigame/flappy_xand.dart';

class FlyingXand extends SpriteComponent
    with HasGameRef<FlappyXandGame>, CollisionCallbacks {
  final double _gravity = 10;
  final double _jumpForce = 350;
  Vector2 _velocity = Vector2.zero();

  FlyingXand();

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('respirando.png');
    position = Vector2(50, gameRef.size.y / 2 - size.y / 2);
    size = Vector2.all(50);
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _velocity.y += _gravity;
    position.y += _velocity.y * dt;

    // Checa se o pássaro saiu da tela por baixo
    if (position.y > gameRef.size.y) {
      gameRef.gameOver();
    }
  }

  void fly() {
    _velocity.y = -_jumpForce;
    // Efeito de rotação ao pular
    add(
      RotateEffect.to(
        -0.2, // Rotação para cima em radianos
        EffectController(duration: 0.1, reverseDuration: 0.3),
      ),
    );
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    gameRef.gameOver();
  }
}