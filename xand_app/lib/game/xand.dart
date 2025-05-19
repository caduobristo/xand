import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:xand/components/pet.dart';

class Xand extends FlameGame {
  late Pet _pet;

  @override
  Future<void> onLoad() async {
    await images.load('respirando.png');

    _pet = Pet()
      ..anchor = Anchor.center
      ..position = size / 2;

    add(_pet);
  }

  @override
  Color backgroundColor() => const Color(0xFFF6E7C9);
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    if (isLoaded) {
      _pet.position = canvasSize / 2; // recentraliza após redimensionamento
    }
  }
}