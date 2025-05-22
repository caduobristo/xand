import 'dart:ui';

import 'package:flame/game.dart';
import 'package:xand/components/pet.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class Xand extends FlameGame {
  late Pet _pet;
  bool isNight = false;

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  @override
  Future<void> onLoad() async {
    await images.loadAll([
      'respirando.png',
      'comendo.png',
      'bolinha.png',
      'dormindo.png',
      'escutando.png',
    ]);

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

  // Métodos de ação
  void play() async {
    if(isNight){
      isNight = !isNight;
      overlays.remove('MenuOverlay');
      overlays.add('MenuOverlay');
    }
    await _switchPetAnimation('bolinha.png', 3, 0.2, duration: 4);
    await _switchPetAnimation('respirando.png', 2, 0.5, duration: 0);
  }

  void eat() async {
    if(isNight){
      isNight = !isNight;
      overlays.remove('MenuOverlay');
      overlays.add('MenuOverlay');
    }
    await _switchPetAnimation('comendo.png', 4, 0.2, duration: 4);
    await _switchPetAnimation('respirando.png', 2, 0.5, duration: 0);
  }

  void sleep() async {
    isNight = !isNight;

    if(isNight){
      await _switchPetAnimation('dormindo.png', 4, 0.5, duration: 0);
    }
    else{
      await _switchPetAnimation('respirando.png', 2, 0.5, duration: 0);
    }

    // Força redesenho do background
    overlays.remove('MenuOverlay');
    overlays.add('MenuOverlay');
  }

  void hear() async {
    if (!_isRecording) {
      // Solicita permissões
      if (await Permission.microphone.request().isGranted) {
        await startRecording();

        // Stop automático após 30 segundos
        Future.delayed(const Duration(seconds: 30), () async {
          if (_isRecording) {
            await stopRecording();
          }
        });
      } else {
        print('❌ Permissão de microfone negada');
      }
    } else {
      await stopRecording();
    }
  }

  Future<void> startRecording() async {
    try {
      bool hasPermission = await _recorder.hasPermission();
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/audio.mp3';
      if (hasPermission) {
        await _recorder.start(const RecordConfig(), path: path);
        _isRecording = true;
        await _switchPetAnimation('escutando.png', 4, 0.5, duration: 0);
        print('🎙 Gravando em: $path');
      } else {
        print("Permissão de gravação negada.");
      }
    } catch (e) {
      print("Erro ao iniciar gravação: $e");
    }
  }

  Future<void> stopRecording() async {
    try {
      String? path = await _recorder.stop();
      await _switchPetAnimation('respirando.png', 2, 0.5, duration: 0);
      print("Gravação parada. Arquivo salvo em: $path");
      _isRecording = false;
    } catch (e) {
      print("Erro ao parar gravação: $e");
    }
  }

  // Utilitário para trocar animações do pet
  Future<void> _switchPetAnimation(
      String image,
      int frameCount,
      double stepTime, {
        int duration = 4,
      }) async {
    remove(_pet);
    _pet = Pet(imageName: image, frameCount: frameCount, stepTime: stepTime)
      ..position = size / 2;
    add(_pet);
    await Future.delayed(Duration(seconds: duration));
  }
}