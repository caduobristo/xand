import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:xand/components/MenuOverlay.dart';
import 'package:xand/game/xand.dart';
import 'package:xand/minigame/flappy_xand.dart';
import 'package:xand/minigame/overlays/game_overlay.dart';

import 'game/xand.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Widget _gameWidget;

  @override
  void initState() {
    super.initState();
    _switchToPetGame();
  }

  void _switchToPetGame() {
    setState(() {
      _gameWidget = GameWidget<Xand>(
        game: Xand(onPlayMinigame: _switchToFlappyGame),
        overlayBuilderMap: {
          'MenuOverlay': (context, game) => MenuOverlay(game: game as Xand),
        },
      );
    });
  }

  void _switchToFlappyGame() {
    setState(() {
      _gameWidget = GameWidget<FlappyXandGame>(
        game: FlappyXandGame(onBack: _switchToPetGame),
        overlayBuilderMap: {
          'GameOverOverlay': (context, game) =>
              GameOverOverlay(game: game as FlappyXandGame),
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _gameWidget,
    );
  }
}