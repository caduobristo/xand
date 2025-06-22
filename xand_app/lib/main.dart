import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:xand/components/MenuOverlay.dart';
import 'package:xand/components/AmbientOverlay.dart';
import 'package:xand/game/xand.dart';
import 'package:xand/minigame/flappy_xand.dart';
import 'package:xand/minigame/overlays/game_overlay.dart';

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
  late final Xand _xandGame;
  late final FlappyXandGame _flappyXandGame;

  late final ValueNotifier<FlameGame> _currentGameNotifier;

  @override
  void initState() {
    super.initState();

    _xandGame = Xand(onPlayMinigame: _switchToFlappyGame);
    _flappyXandGame = FlappyXandGame(onBack: _switchToPetGame);
    _currentGameNotifier = ValueNotifier<FlameGame>(_xandGame);
  }

  @override
  void dispose() {
    _xandGame.pauseEngine();

    _flappyXandGame.pauseEngine();

    _currentGameNotifier.dispose(); 
    super.dispose();
  }

  void _switchToPetGame() {
    _currentGameNotifier.value = _xandGame;
  }

  void _switchToFlappyGame() {
    _currentGameNotifier.value = _flappyXandGame;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold( 
        body: ValueListenableBuilder<FlameGame>(
          valueListenable: _currentGameNotifier,
          builder: (context, game, child) {
            if (game is Xand) {
              return GameWidget<Xand>(
                game: game, 
                overlayBuilderMap: {
                  'MenuOverlay': (ctx, g) => MenuOverlay(game: g as Xand),
                  'AmbientOverlay': (ctx, g) => AmbientOverlay(game: g as Xand),
                },
                initialActiveOverlays: const ['MenuOverlay'],
              );
            } else if (game is FlappyXandGame) {
              return GameWidget<FlappyXandGame>(
                game: game, 
                overlayBuilderMap: {
                  'GameOverOverlay': (ctx, g) => GameOverOverlay(game: g as FlappyXandGame),
                },
              );
            }
            return const Center(child: Text('Tipo de jogo desconhecido'));
          },
        ),
      ),
    );
  }
}