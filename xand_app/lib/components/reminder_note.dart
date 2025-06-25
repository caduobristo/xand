import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:xand/game/xand.dart';

class ReminderNoteComponent extends SpriteComponent
    with HasGameRef<Xand>, TapCallbacks {

  ReminderNoteComponent() : super(
    size: Vector2.all(64),
    anchor: Anchor.topRight,
  );

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('postit.png');
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    gameRef.showReminderDialog();
  }
}