import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xand/minigame/components/flying_xand.dart';
import 'package:xand/minigame/components/pipe.dart';

class FlappyXandGame extends FlameGame
    with HasCollisionDetection, TapDetector {
  final VoidCallback onBack;
  late FlyingXand _bird;
  late Timer _pipeSpawnerTimer;

  static const double initialPipeInterval = 3;
  static const double minPipeInterval = 1.2;
  static const double initialVerticalGap = 10;
  static const double minVerticalGap = 2;

  double _pipeInterval = initialPipeInterval;
  double _verticalGap = initialVerticalGap;

  bool isGameOver = false;

  int score = 0;
  int highScore = 0;
  late TextComponent _scoreText;
  late TimerComponent _scoreTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();

  FlappyXandGame({required this.onBack});

  @override
  Future<void> onLoad() async {
    await _loadHighScore();

    add(
      SpriteComponent(
        sprite: await loadSprite('background.png'),
        size: size,
      ),
    );

    // Pontuação atual
    _scoreText = TextComponent(
      text: 'Pontos: 0',
      priority: 100,
      position: Vector2(20, 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_scoreText);

    // Timer de pontuação
    _scoreTimer = TimerComponent(
      period: 5.0,
      repeat: true,
      onTick: () {
        score += 10;
        _scoreText.text = 'Pontos: $score';
      },
    );
    add(_scoreTimer);

    // Timer de dificuldade
    add(TimerComponent(
      period: 60,
      repeat: true,
      onTick: _increaseDifficulty,
    ));

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.play(AssetSource('audios/minigame.mp3'));

    _bird = FlyingXand();
    add(_bird);

    // Spawner de canos
    _pipeSpawnerTimer = Timer(
      _pipeInterval,
      onTick: () => add(PipeGroup(pipeGap: _verticalGap)),
      repeat: true,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isGameOver) {
      _pipeSpawnerTimer.update(dt);
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    if (!isGameOver) {
      _bird.fly();
    }
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;

    _audioPlayer.stop();
    _audioPlayer.setReleaseMode(ReleaseMode.release);

    _pipeSpawnerTimer.pause();

    if (score > highScore) {
      highScore = score;
      _saveHighScore();
    }

    pauseEngine();
    overlays.add('GameOverOverlay');
  }

  void resetGame() {
    isGameOver = false;

    // Reset de pontuação
    score = 0;
    _scoreText.text = 'Pontos: 0';

    _pipeInterval = initialPipeInterval;
    _verticalGap = initialVerticalGap;
    _pipeSpawnerTimer.limit = _pipeInterval;
    _pipeSpawnerTimer.reset();
    _pipeSpawnerTimer.start();

    resumeEngine();
    // Remove todos os canos e o pássaro antigo
    children.whereType<PipeGroup>().forEach((pipe) => pipe.removeFromParent());
    _bird.removeFromParent();

    // Adiciona um novo pássaro
    _bird = FlyingXand();
    add(_bird);

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.play(AssetSource('audios/minigame.mp3'));

    overlays.remove('GameOverOverlay');
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('flappy_high_score') ?? 0;
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('flappy_high_score', highScore);
  }

  void _increaseDifficulty() {
    _pipeInterval = max(minPipeInterval, _pipeInterval - 0.2);
    _verticalGap = max(minVerticalGap, _verticalGap - 10.0);

    _pipeSpawnerTimer.limit = _pipeInterval;
  }
}