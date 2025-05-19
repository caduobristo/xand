import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/flame.dart';

class Pet extends SpriteAnimationComponent {
  Pet() : super(size: Vector2.all(256)); // tamanho do pet

  @override
  Future<void> onLoad() async {
    final image = await Flame.images.load('respirando.png');

    final spriteSheet = SpriteSheet(
      image: image,
      srcSize: Vector2(1024, 1024), // tamanho de cada frame
    );

    animation = spriteSheet.createAnimation(
      row: 0,
      stepTime: 1,
      to: 2, // número de frames
      loop: true,
    );
  }
}