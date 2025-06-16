import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:xand/minigame/flappy_xand.dart';

class FlyingXand extends SpriteComponent
    with HasGameRef<FlappyXandGame>, CollisionCallbacks {
  final double _gravity = 10;
  final double _jumpForce = 350;
  Vector2 _velocity = Vector2.zero();

  late Sprite _spriteParado;
  late Sprite _spriteVoando;

  FlyingXand();

  @override
  Future<void> onLoad() async {
    _spriteParado = await gameRef.loadSprite('astronauta1.png');
    _spriteVoando = await gameRef.loadSprite('astronauta2.png');

    sprite = _spriteParado;
    position = Vector2(50, gameRef.size.y / 2 - size.y / 2);
    size = Vector2.all(60);
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
    add(
      RotateEffect.to(
        -0.2,
        EffectController(duration: 0.1, reverseDuration: 0.3),
      ),
    );
    sprite = _spriteVoando;

    children.whereType<TimerComponent>().forEach((timer) => timer.removeFromParent());
    add(TimerComponent(
      period: 0.3,
      removeOnFinish: true,
      onTick: () {
        sprite = _spriteParado;
      },
    ));
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