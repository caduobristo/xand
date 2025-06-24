import 'dart:io';
import 'dart:convert'; // Necessário para json.decode

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:xand/components/pet.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // Necessário para BuildContext e AlertDialog
import 'package:http_parser/http_parser.dart'; // Necessário para MediaType
import 'package:vibration/vibration.dart';
import 'package:xand/components/status_bar.dart';

class Xand extends FlameGame {
  late Pet _pet;
  bool isNight = false;
  bool _isPetting = false;
  bool _playingGuitar = false;
  bool _ambient = false;

  double _hunger = 1.0;
  double _energy = 1.0;
  double _fun = 1.0;

  late StatusBar _hungerBar;
  late StatusBar _energyBar;
  late StatusBar _funBar;

  String _defaultSprite = 'respirando.png';
  String _currentAnimation = 'respirando.png';
  late TimerComponent _meowTimer;

  final AudioRecorder _recorder = AudioRecorder();
  bool isRecording = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  SpriteAnimationComponent? cover;
  AudioPlayer? _ambientPlayer;

  final VoidCallback onPlayMinigame;

  Xand({required this.onPlayMinigame});

  @override
  Future<void> onLoad() async {
    await images.loadAll([
      _defaultSprite,
      'comendo.png',
      'bolinha.png',
      'dormindo.png',
      'escutando.png',
      'guitarra.png',
      'carinho.png',
      'meio_triste.png',
      'triste.png'
    ]);

    final barSize = Vector2(150, 20);
    _hungerBar = StatusBar(label: 'Fome', initialValue: _hunger, position: Vector2(30, 30), size: barSize);
    _energyBar = StatusBar(label: 'Energia', initialValue: _energy, position: Vector2(200, 30), size: barSize);
    _funBar = StatusBar(label: 'Diversão', initialValue: _fun, position: Vector2(370, 30), size: barSize);
    add(_hungerBar);
    add(_energyBar);
    add(_funBar);

    add(TimerComponent(
      period: 5.0,
      repeat: true,
      onTick: _updateStatus,
    ));

    _meowTimer = TimerComponent(
      period: 10.0,
      repeat: true,
      onTick: () {
        if (!isNight && !_playingGuitar && !_ambient) {
          AudioPlayer().play(AssetSource('audios/meow.mp3'));
        }
      },
    );
    add(_meowTimer);

    _pet = Pet(imageName: _defaultSprite, frameCount: 4, stepTime: 0.5)
      ..position = size / 2;

    add(_pet);
    overlays.add('MenuOverlay');
  }

  @override
  Color backgroundColor() =>
      isNight ? const Color(0xFFD6C9AE) : const Color(0xFFF6E7C9);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _pet.position = size / 2;
    }
  }

  void startPetting() async {
    if (_currentAnimation != _defaultSprite ||
        _isPetting || _ambient || _playingGuitar) return;

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 200], repeat: 0);
    }
    _isPetting = true;

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.play(AssetSource('audios/purr.mp3'));

    _switchPetAnimation('carinho.png', 3, 0.5);
    _fun = (_fun + 0.05).clamp(0.0, 1.0);
    _funBar.updateValue(_fun);
    _checkPetNeeds();
  }

  void stopPetting() async {
    if (!_isPetting) return;

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.cancel();
    }
    _isPetting = false;

    _audioPlayer.stop();
    _audioPlayer.setReleaseMode(ReleaseMode.release);

    _switchPetAnimation(_defaultSprite, 4, 0.5);
  }

  // Métodos de ação
  void play() async {
    stopPetting();
    overlays.remove('MenuOverlay');
    await _switchPetAnimation('bolinha.png', 3, 0.2, duration: 4);

    _fun = (_fun + 0.4).clamp(0.0, 1.0);
    _funBar.updateValue(_fun);

    _energy = (_energy - 0.2).clamp(0.0, 1.0);
    _energyBar.updateValue(_energy);

    _checkPetNeeds();

    await _switchPetAnimation(_defaultSprite, 4, 0.5);
    overlays.add('MenuOverlay');
  }

  void eat() async {
    stopPetting();
    overlays.remove('MenuOverlay');
    await _switchPetAnimation('comendo.png', 4, 0.2, duration: 4);

    _hunger = (_hunger + 0.3).clamp(0.0, 1.0);
    _hungerBar.updateValue(_hunger);
    _checkPetNeeds();

    await _switchPetAnimation(_defaultSprite, 4, 0.5);
    overlays.add('MenuOverlay');
  }

  void sleep() async {
    stopPetting();
    isNight = !isNight;

    if(isNight){
      await _switchPetAnimation('dormindo.png', 4, 0.5);
    } else{
      await _switchPetAnimation(_defaultSprite, 4, 0.5);
    }

    _checkPetNeeds();

    // Força redesenho do background
    overlays.remove('MenuOverlay');
    overlays.add('MenuOverlay');
  }

  // Função `hear` ajustada para lidar com a gravação e o envio para o backend
  void hear(BuildContext context) async {
    if (!isRecording) {
      if (await Permission.microphone.request().isGranted) {
        await startRecording();
      } else {
        print('Permissão de microfone negada');
      }
    } else {
      String? recordedPath = await stopRecording();
      if (recordedPath != null) {
        await sendAudioToXandBackend(recordedPath, context); // Passa o context
      }
    }
  }

  Future<void> sendAudioToXandBackend(String audioFilePath, BuildContext context) async {
    try {
      File audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        print('Erro: O arquivo de áudio não foi encontrado em $audioFilePath');
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.15.6:5000/xand/ask'),        //Uri.parse('http://192.168.15.70:5000/xand/ask'), // Alterado para a rota /xand/ask no rasp
      );
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioFile.path,
        filename: 'audio.ogg', 
        contentType: MediaType('audio', 'opus'), 
      ));

      var response = await request.send();

      if (response.statusCode == 200) {
        print('Arquivo de áudio enviado para XAND com sucesso!');
        String responseBody = await response.stream.bytesToString();
        print('Resposta do servidor do XAND: $responseBody');

        final data = json.decode(responseBody);
        final fala = data['text'];

        final String comando = fala.toString().replaceAll("'", "").replaceAll("`", "").replaceAll("´", "").trim().toLowerCase();
        if (comando == 'dormir') {
          sleep();
        } else if (comando == 'acordar'){
          sleep();
        } else if (comando == 'brincar') {
          play();
        } else if (comando == 'tocar guitarra') {
          playGuitar();
        } else if (comando == 'comer') {
          eat();
        } else if (comando == 'jogar'){
          onPlayMinigame();
        } else {
          if (context.mounted) showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('XAND Responde'),
                content: Text(fala),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }

      } else {
        print('Erro ao enviar o arquivo de áudio para XAND. Status code: ${response.statusCode}');
        String errorBody = await response.stream.bytesToString();
        print('Corpo da resposta de erro do XAND: $errorBody');
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Erro do XAND'),
              content: Text('Não consegui entender, tente novamente: $errorBody'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Ocorreu um erro ao se comunicar com XAND: $e');
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Erro de Comunicação'),
            content: Text('Não foi possível se comunicar com o XAND: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void playGuitar() async {
    if (!_playingGuitar) {
      _playingGuitar = true;
      overlays.remove('MenuOverlay');
      _switchCover(
          sprite: 'guitarra.png',
          stepTime: 0.15,
          frameCount: 5,
          frameSize: Vector2(2720, 1536)
      );

      await _audioPlayer.play(AssetSource('audios/guitar.mp3'));

      _audioPlayer.onPlayerComplete.listen((event) {
        if (cover != null && children.contains(cover!)) {
          remove(cover!);
          _fun = (_fun + 0.6).clamp(0.0, 1.0);
          _funBar.updateValue(_fun);
          _energy = (_energy - 0.2).clamp(0.0, 1.0);
          _energyBar.updateValue(_energy);
          _checkPetNeeds();
        }
        _playingGuitar = false;
        overlays.add('MenuOverlay');
      });
    }
  }

  Future<void> startRecording() async {
    try {
      bool hasPermission = await _recorder.hasPermission();
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/audio.ogg';
      if (hasPermission) {
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.opus), path: path);
        isRecording = true;
        overlays.remove('MenuOverlay');
        overlays.add('MenuOverlay');
        await _switchPetAnimation('escutando.png', 4, 0.5);
        print('Gravando em: $path');
      } else {
        print("Permissão de gravação negada.");
      }
    } catch (e) {
      print("Erro ao iniciar gravação: $e");
    }
  }

  Future<String?> stopRecording() async {
    try {;
      String? path = await _recorder.stop();
      await _switchPetAnimation(_defaultSprite, 4, 0.5);
      print("Gravação parada. Arquivo salvo em: $path");
      isRecording = false;
      overlays.remove('MenuOverlay');
      overlays.add('MenuOverlay');
      return path;
    } catch (e) {
      print("Erro ao parar gravação: $e");
      return null;
    }
  }

  // Utilitário para trocar animações do pet
  Future<void> _switchPetAnimation(
      String sprite,
      int frameCount,
      double stepTime, {
        int duration = 0,
      }) async {
    _currentAnimation = sprite;
    if (_currentAnimation == _defaultSprite && !isNight) {
      _meowTimer.timer.resume();
    } else {
      _meowTimer.timer.pause();
    }

    remove(_pet);
    _pet = Pet(imageName: sprite, frameCount: frameCount, stepTime: stepTime)
      ..position = size / 2;
    add(_pet);
    await Future.delayed(Duration(seconds: duration));
  }

  Future<void> _switchCover({
    required String sprite,
    required double stepTime,
    required int frameCount,
    required Vector2 frameSize,
  }) async {
    if (cover != null && children.contains(cover!)) {
      remove(cover!);
    }

    final image = await images.load(sprite);
    final spriteSheet = SpriteSheet(
      image: image,
      srcSize: frameSize,
    );

    final animation = spriteSheet.createAnimation(
      row: 0,
      stepTime: stepTime,
      to: frameCount,
    );

    cover = SpriteAnimationComponent()
      ..animation = animation
      ..size = size
      ..position = Vector2.zero()
      ..priority = 100;
    add(cover!);
  }

  void removeCover() {
    _ambientPlayer?.stop();
    _ambientPlayer?.dispose();
    _ambientPlayer = null;

    if (cover != null && children.contains(cover!)) {
      remove(cover!);
    }
    overlays.remove('AmbientOverlay');
    overlays.add('MenuOverlay');
    _ambient = false;
  }

  void showCampfire() {
    overlays.remove('MenuOverlay');
    _ambient = true;

    _switchCover(
      sprite: 'fogueira.png',
      stepTime: 0.1,
      frameCount: 100,
      frameSize: Vector2(1500, 849),
    );

    _ambientPlayer = AudioPlayer();
    _ambientPlayer!.setReleaseMode(ReleaseMode.loop);
    _ambientPlayer!.play(AssetSource('audios/fogueira.mp3'));

    overlays.add('AmbientOverlay');
  }

  void _updateStatus() {
    if (isNight) {
      _energy = (_energy + 0.1).clamp(0.0, 1.0);
    } else if (!_isPetting) {
      _energy = (_energy - 0.005).clamp(0.0, 1.0);
    }
    _hunger = (_hunger - 0.005).clamp(0.0, 1.0);
    _fun = (_fun - 0.005).clamp(0.0, 1.0);

    _hungerBar.updateValue(_hunger);
    _energyBar.updateValue(_energy);
    _funBar.updateValue(_fun);

    _checkPetNeeds();
  }

  void _checkPetNeeds() {
    if (_currentAnimation != _defaultSprite) return;

    if (_hunger > 0.6 && _energy > 0.6 && _fun > 0.6) {
      _defaultSprite = 'respirando.png';
    } else if (_hunger > 0.3 && _energy > 0.3 && _fun > 0.3){
      _defaultSprite = 'meio_triste.png';
    } else {
      _defaultSprite = 'triste.png';
    }
    final isIdle = ['respirando.png', 'meio_triste.png', 'triste.png'].contains(_currentAnimation);
    if (isIdle && _currentAnimation != _defaultSprite) {
      _switchPetAnimation(_defaultSprite, 4, 0.5);
    }
  }
}