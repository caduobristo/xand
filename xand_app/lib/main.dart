import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:xand/components/MenuOverlay.dart';

import 'game/xand.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Força o jogo em modo paisagem
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    GameWidget(
      game: Xand(),
      overlayBuilderMap: {
        'MenuOverlay': (context, game) => MenuOverlay(game: game as Xand),
      },
    ),
  );
}