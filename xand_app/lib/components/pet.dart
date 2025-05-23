import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../game/xand.dart';

class Pet extends SpriteAnimationComponent with HasGameRef<Xand> {
  final String imageName;
  final int frameCount;
  final double stepTime;

  Pet({
    required this.imageName,
    required this.frameCount,
    required this.stepTime,
  });

  @override
  Future<void> onLoad() async {
    final image = await gameRef.images.load(imageName);
    final frameWidth = image.width / frameCount;
    final frameHeight = image.height.toDouble();

    final spriteSheet = SpriteSheet(
      image: image,
      srcSize: Vector2(frameWidth, frameHeight),
    );

    animation = spriteSheet.createAnimation(
      row: 0,
      stepTime: stepTime,
      to: frameCount,
    );

    size = Vector2(512, 512);
    anchor = Anchor.center;
  }
}