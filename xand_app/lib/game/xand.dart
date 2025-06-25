import 'dart:io';
import 'dart:convert'; // Necessário para json.decode
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:flutter_tts/flutter_tts.dart'; // TTS para fala 
import 'dart:async';

class Xand extends FlameGame {
  late Pet _pet;
  // Flags de funções
  bool isNight = false;
  bool _isPetting = false;
  bool _playingGuitar = false;
  bool _ambient = false;
  bool _alarm = false;

  // Barras de status
  double _hunger = 1.0;
  double _energy = 1.0;
  double _fun = 1.0;

  late StatusBar _hungerBar;
  late StatusBar _energyBar;
  late StatusBar _funBar;

  // Flags de sprites
  String _defaultSprite = 'respirando.png';
  String _currentAnimation = 'respirando.png';
  late TimerComponent _meowTimer;

  final AudioRecorder _recorder = AudioRecorder();
  bool isRecording = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  SpriteAnimationComponent? cover;
  AudioPlayer? _ambientPlayer;

  // Cronômetro
  final ValueNotifier<int> stopwatchSecondsNotifier = ValueNotifier(0);
  late TimerComponent _stopwatchTimer;
  bool isStopwatchRunning = false;

  // Alarme
  late TextComponent _alarmText;
  TimerComponent? _alarmTimer;

  final VoidCallback onPlayMinigame;

  late FlutterTts flutterTts;

  Completer<void>? _speechCompleter;

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

    flutterTts = FlutterTts();
    await flutterTts.setLanguage("pt-BR"); 
    await flutterTts.setSpeechRate(0.8); 
    await flutterTts.setVolume(1.0); 
    await flutterTts.setPitch(2.0);

    flutterTts.setCompletionHandler(() { 
      _speechCompleter?.complete();
      _speechCompleter = null;
    });

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
        if (!isNight && !_playingGuitar && !_ambient &&
            !_alarm && !isStopwatchRunning && _currentAnimation == _defaultSprite) {
          AudioPlayer().play(AssetSource('audios/meow.mp3')); // Restaurado som do miado
        }
      },
    );
    add(_meowTimer);

    _stopwatchTimer = TimerComponent(
      period: 1.0,
      repeat: true,
      onTick: () {
        if (stopwatchSecondsNotifier.value > 0) {
          stopwatchSecondsNotifier.value--;
        } else {
          _stopwatchTimer.timer.pause();
          AudioPlayer().play(AssetSource('audios/timer.mp3'));
          print("TIMER FINALIZADO!");
          if (overlays.isActive('StopwatchOverlay')) {
            hideStopwatch();
            isStopwatchRunning = false;
          }
        }
      },
    );
    _stopwatchTimer.timer.pause();
    add(_stopwatchTimer);

    _alarmText = TextComponent(
      text: 'Alarme: Nenhum',
      position: Vector2(size.x - 10, 10),
      anchor: Anchor.topRight,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
    add(_alarmText);

    _pet = Pet(imageName: _defaultSprite, frameCount: 4, stepTime: 0.5)
      ..position = size / 2;

    add(_pet);
    overlays.add('MenuOverlay');
  }

  @override
  void onMount() {
    super.onMount();
    _loadSavedAlarm();
  }

  @override
  Color backgroundColor() =>
      isNight ? const Color(0xFFD6C9AE) : const Color(0xFFF6E7C9);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _pet.position = size / 2;
      _alarmText.position = Vector2(size.x - 10, 10); // Alarme ajustando na tela
    }
  }

  void startPetting() async {
    if (_currentAnimation != _defaultSprite ||
        _isPetting || _ambient || _playingGuitar || _alarm || isStopwatchRunning) return;

    if (await Vibration.hasVibrator()) {
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

    if (await Vibration.hasVibrator()) {
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
        Uri.parse('http://192.168.15.2:5000/xand/ask'), 
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
          await _speakAndWait('Hmm, que soninho, vou nanar!');
          sleep();
        } else if (comando == 'acordar'){
          await _speakAndWait('Bora pra mais uma!');
          sleep();
        } else if (comando == 'brincar') {
          await _speakAndWait('Oba! Vamos brincar!');
          play();
        } else if (comando == 'tocar guitarra') {
          await _speakAndWait('Pega esse solo de guitarra!');
          playGuitar();
        } else if (comando == 'tocar piano') {
          await _speakAndWait('Certo! Uma melodia no piano para dar uma relaxada.');
          // playPiano(); 
        } else if (comando == 'comer') {
          await _speakAndWait('Hmm, que delícia! Vou comer!');
          eat();
        } else if (comando == 'jogar'){
          await _speakAndWait('Preparar, apontar, Xand, o Voador!');
          onPlayMinigame();
        } 
        // --- Lógica para TIMER e ALARME por voz ---
        else if (comando.startsWith('acao: timer:')) {
            final parts = comando.split(':');
            if (parts.length == 3 && int.tryParse(parts[2].trim()) != null) {
                final seconds = int.parse(parts[2].trim());
                await _speakAndWait('Certo! Iniciando seu cronômetro para $seconds segundos.');
                startTimer(Duration(seconds: seconds));
            } else {
                await _speakAndWait('Desculpe, não entendi a duração do cronômetro.');
            }
        } else if (comando.startsWith('acao: alarme:')) {
            final parts = comando.split(':'); 
            if (parts.length == 5 && parts[1].trim() == 'alarme') { 
                final hourStr = parts[2].trim();
                final minuteStr = parts[3].trim();
                final secondStr = parts[4].trim();

                try {
                  final now = DateTime.now();
                  final hour = int.parse(hourStr);
                  final minute = int.parse(minuteStr);
                  final second = int.parse(secondStr);

                  DateTime alarmTime = DateTime(now.year, now.month, now.day, hour, minute, second);
                  
                  if (alarmTime.isBefore(now)) {
                      alarmTime = alarmTime.add(const Duration(days: 1));
                  }
                  
                  await _speakAndWait('Alarme configurado para ${hourStr} horas, ${minuteStr} minutos e ${secondStr} segundos.');
                  setAlarm(alarmTime);
                } catch (e) {
                  await _speakAndWait('Desculpe, não consegui configurar o alarme com o horário fornecido.');
                  print('Erro de parsing de alarme: $e'); 
                }
            } else {
                await _speakAndWait('Desculpe, não entendi o formato do alarme. Por favor, diga "alarme para 07:30:00" por exemplo.');
            }
        } else if (comando == 'acao: cancelar alarme') { 
          await _speakAndWait('Alarme cancelado!');
          cancelAlarm();
        }
    
        else if (fala.startsWith('horario:') || 
                   fala.startsWith('temperatura:') || 
                   fala.startsWith('Sim!, estou te ouvindo, diga o que quer que eu fale!') || 
                   fala.startsWith('TEXTO:')) { 
            String textToSpeak = fala;
            print('DEBUG (FALA original): "${fala}"');
            if (textToSpeak.startsWith('TEXTO:')) {
                textToSpeak = textToSpeak.substring(6).trim(); 
                if (textToSpeak.isEmpty) { 
                    textToSpeak = 'Desculpe, não entendi o que você disse.';
                }
            }
            textToSpeak = textToSpeak.replaceAll("'", "").replaceAll("`", "").replaceAll("´", "");

            _speak(textToSpeak); // Dispara a fala e CONTINUA IMEDIATAMENTE
            if (context.mounted) {
              showDialog(
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
        } 
        
        else if (fala == 'NULL') {
            await _speakAndWait('Desculpe, não entendi o que você disse.');
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('XAND Responde'),
                  content: const Text('Desculpe, não entendi o que você disse.'),
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
        
        else { 
            String textToSpeak = fala.replaceAll("'", "").replaceAll("`", "").replaceAll("´", "");
            _speak(textToSpeak); 
            if (context.mounted) {
              showDialog(
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
        }

      } else {
        print('Erro ao enviar o arquivo de áudio para XAND. Status code: ${response.statusCode}');
        String errorBody = await response.stream.bytesToString();
        print('Corpo da resposta de erro do XAND: $errorBody');
        await _speakAndWait('Houve um erro na comunicação com o servidor.');
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
      await _speakAndWait('Desculpe, não foi possível conectar com o XAND. Verifique sua conexão.');
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

  void playPiano() async {
    if (!_playingGuitar) { 
      _playingGuitar = true; 
      overlays.remove('MenuOverlay');
      _switchCover(
          sprite: 'piano.png',
          stepTime: 0.15,
          frameCount: 5,
          frameSize: Vector2(2720, 1536)
      );

      await _audioPlayer.play(AssetSource('audios/piano.mp3')); 

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

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await flutterTts.speak(text);
  }

  Future<void> _speakAndWait(String text) async {
    if (text.isEmpty) return;

    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
    _speechCompleter = Completer<void>();

    await flutterTts.speak(text);
    return _speechCompleter!.future;
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

  void startTimer(Duration duration) {
    _stopwatchTimer.timer.pause();
    stopwatchSecondsNotifier.value = duration.inSeconds;

    if (stopwatchSecondsNotifier.value > 0) {
      isStopwatchRunning = true;
      _stopwatchTimer.timer.start();
    }

    overlays.remove('MenuOverlay');
    overlays.add('StopwatchOverlay');
  }

  void hideStopwatch() {
    isStopwatchRunning = false;
    _stopwatchTimer.timer.pause();
    overlays.remove('StopwatchOverlay');
    overlays.add('MenuOverlay');
  }

  void cancelAlarm() async {
    _alarmTimer?.removeFromParent();
    _alarmText.text = 'Alarme: Nenhum';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_alarm');
  }

  // Função para definir um Alarme
  void setAlarm(DateTime alarmTime) async {
    if (!isLoaded) return;

    cancelAlarm();

    final now = DateTime.now();
    if (alarmTime.isBefore(now)) {
      print("Tempo do alarme já passou");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_alarm', alarmTime.toIso8601String());

    final duration = alarmTime.difference(now);
    final formattedTime = DateFormat('HH:mm:ss').format(alarmTime);
    _alarmText.text = 'Alarme: $formattedTime';

    _alarmTimer = TimerComponent(
      period: duration.inSeconds.toDouble(),
      removeOnFinish: true,
      onTick: () {
        _alarmText.text = 'Alarme: Nenhum';
        cancelAlarm();
        _alarm = true;
        final alarmSoundPlayer = AudioPlayer();
        alarmSoundPlayer.onPlayerComplete.listen((event) {
          _alarm = false;
          alarmSoundPlayer.dispose();
        });
        alarmSoundPlayer.play(AssetSource('audios/alarme.mp3'));
      },
    );
    add(_alarmTimer!);
  }

  Future<void> _loadSavedAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmString = prefs.getString('saved_alarm');

    if (alarmString != null) {
      final alarmTime = DateTime.parse(alarmString);
      if (alarmTime.isAfter(DateTime.now())) {
        print('Alarme salvo encontrado, reativando para: $alarmTime');
        setAlarm(alarmTime);
      } else {
        await prefs.remove('saved_alarm');
      }
    }
  }
}