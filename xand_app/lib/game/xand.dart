import 'dart:io';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:xand/components/pet.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

class Xand extends FlameGame {
  late Pet _pet;
  bool isNight = false;
  bool _isPetting = false;
  bool _playingGuitar = false;

  String _currentAnimation = 'respirando.png';
  late TimerComponent _meowTimer;

  final AudioRecorder _recorder = AudioRecorder();
  bool isRecording = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  late SpriteAnimationComponent cover;

  final VoidCallback onPlayMinigame;
  Xand({required this.onPlayMinigame});

  @override
  Future<void> onLoad() async {
    await images.loadAll([
      'respirando.png',
      'comendo.png',
      'bolinha.png',
      'dormindo.png',
      'escutando.png',
      'guitarra.png',
      'carinho.png'
    ]);

    _meowTimer = TimerComponent(
      period: 10.0,
      repeat: true,
      onTick: () {
        if (!isNight && !_playingGuitar) {
          AudioPlayer().play(AssetSource('audios/meow.mp3'));
        }
      },
    );
    add(_meowTimer);

    _pet = Pet(imageName: 'respirando.png', frameCount: 2, stepTime: 0.5)
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
    if (_currentAnimation != 'respirando.png' || _isPetting) return;

    _isPetting = true;

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.play(AssetSource('audios/purr.mp3'));

    _switchPetAnimation('carinho.png', 3, 0.5);
  }

  void stopPetting() {
    if (!_isPetting) return;

    _isPetting = false;

    _audioPlayer.stop();
    _audioPlayer.setReleaseMode(ReleaseMode.release);

    _switchPetAnimation('respirando.png', 2, 0.5);
  }

  // Métodos de ação
  void play() async {
    stopPetting();
    overlays.remove('MenuOverlay');
    await _switchPetAnimation('bolinha.png', 3, 0.2, duration: 4);
    await _switchPetAnimation('respirando.png', 2, 0.5);
    overlays.add('MenuOverlay');
  }

  void eat() async {
    stopPetting();
    overlays.remove('MenuOverlay');
    await _switchPetAnimation('comendo.png', 4, 0.2, duration: 4);
    await _switchPetAnimation('respirando.png', 2, 0.5);
    overlays.add('MenuOverlay');
  }

  void sleep() async {
    stopPetting();
    isNight = !isNight;

    if(isNight){
      await _switchPetAnimation('dormindo.png', 4, 0.5);
    }
    else{
      await _switchPetAnimation('respirando.png', 2, 0.5);
    }

    // Força redesenho do background
    overlays.remove('MenuOverlay');
    overlays.add('MenuOverlay');
  }

  void hear() async {
    if (!isRecording) {
      // Solicita permissões
      if (await Permission.microphone.request().isGranted) {
        await startRecording();

        // Stop automático após 30 segundos
        Future.delayed(const Duration(seconds: 30), () async {
          if (isRecording) {
            await stopRecording();
            await sendAudioFile("Descreva o áudio");
          }
        });

      } else {
        print('Permissão de microfone negada');
      }
    } else {
      await stopRecording();
      await sendAudioFile("Descreva o áudio");
    }
  }

  Future<void> sendAudioFile(String promptText) async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String audioFilePath = '${dir.path}/audio.mp3';

      File audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        print('Erro: O arquivo de áudio não foi encontrado em $audioFilePath');
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.15.70:5000/gemini/audio'),
      );
      request.fields['text'] = promptText;
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioFile.path,
      ));

      var response = await request.send();

      if (response.statusCode == 200) {
        print('Arquivo de áudio e prompt enviados com sucesso!');
        String responseBody = await response.stream.bytesToString();
        print('Resposta do servidor: $responseBody');
      } else {
        print('Erro ao enviar o arquivo de áudio. Status code: ${response.statusCode}');
        String errorBody = await response.stream.bytesToString();
        print('Corpo da resposta de erro: $errorBody');
      }
    } catch (e) {
      print('Ocorreu um erro: $e');
    }
  }

  void playGuitar() async {
    _playingGuitar = true;
    _switchCover('guitarra.png', 0.15, 5);

    await _audioPlayer.play(AssetSource('audios/guitar.mp3'));

    _audioPlayer.onPlayerComplete.listen((event) {
      remove(cover);
      _playingGuitar = false;
    });
  }

  Future<void> startRecording() async {
    try {
      bool hasPermission = await _recorder.hasPermission();
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/audio.mp3';
      if (hasPermission) {
        overlays.remove('MenuOverlay');

        await _recorder.start(const RecordConfig(), path: path);
        isRecording = true;
        await _switchPetAnimation('escutando.png', 4, 0.5);
        overlays.add('MenuOverlay');
        print('Gravando em: $path');
      } else {
        print("Permissão de gravação negada.");
      }
    } catch (e) {
      print("Erro ao iniciar gravação: $e");
    }
  }

  Future<void> stopRecording() async {
    try {
      overlays.remove('MenuOverlay');
      String? path = await _recorder.stop();
      await _switchPetAnimation('respirando.png', 2, 0.5);
      overlays.add('MenuOverlay');
      print("Gravação parada. Arquivo salvo em: $path");
      isRecording = false;
    } catch (e) {
      print("Erro ao parar gravação: $e");
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
    if (_currentAnimation == 'respirando.png' && !isNight) {
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

  Future<void> _switchCover(
      String sprite,
      double stepTime,
      int frameCount,
      ) async {
    final image = await images.load(sprite);
    final spriteSheet = SpriteSheet(
      image: image,
      srcSize: Vector2(2720, 1536),
    );
    final animation = spriteSheet.createAnimation(
      row: 0,
      stepTime: stepTime,
      to: frameCount,
    );
    cover = SpriteAnimationComponent()
      ..animation = animation
      ..size = size            // cobre a tela toda
      ..position = Vector2.zero()
      ..priority = 100;
    add(cover);
  }
}