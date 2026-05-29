import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/notifications.dart';
import '../services/wake.dart';
import '../services/tts.dart';

final _tts = TtsService();

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _detector = WakeService();
  StreamSubscription<AudioDataContainer>? _audioStream;
  final _bgService = FlutterBackgroundService();

  String _status = 'Cargando modelo...';
  bool _listening = false;
  bool _nexusDetected = false;
  bool _isStarting = false;
  bool _recording = false;

  static const _sampleRate = 16000;

  Future<void> _startPrebuffering() async {
    if (_recording) return;
    if (!await Permission.microphone.request().isGranted) return;
    try {
      await Recorder.instance.init(
        format: PCMFormat.s16le,
        sampleRate: _sampleRate,
        channels: RecorderChannels.mono,
      );
      Recorder.instance.start();
      Recorder.instance.startStreamingData();
      _recording = true;
      _audioStream?.cancel();
      _audioStream = Recorder.instance.uint8ListStream.listen((data) {
        _detector.feedAudio(data.rawData);
      });
    } catch (e) {
      debugPrint('PREBUF ERROR: $e');
    }
  }

  Future<void> _stopRecorder() async {
    if (!_recording) return;
    _audioStream?.cancel();
    _audioStream = null;
    try {
      Recorder.instance.stopStreamingData();
      Recorder.instance.stop();
      Recorder.instance.deinit();
    } catch (e) {
      debugPrint('REC STOP ERROR: $e');
    }
    _recording = false;
  }

  @override
  void initState() {
    super.initState();

    _detector.onReady = () async {
      await _tts.init();
      await _startPrebuffering();
      setState(() => _status = 'Di hey nexus');
    };
    _detector.onFirstPrediction = () {
      if (_isStarting) {
        setState(() {
          _isStarting = false;
          _status = _listening ? 'Escuchando...' : 'Di hey nexus';
        });
      }
    };
    _detector.onDetected = (score) async {
      if (!_listening) return;
      _bgService.invoke('stopService');
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      setState(() {
        _listening = false;
        _isStarting = false;
        _nexusDetected = true;
        _status = 'Hey Nexus! (${score.toStringAsFixed(2)})';
      });
      await showDetectionNotification(score);
      await _tts.speak('Hola. En que puedo ayudarte?');
    };
    _detector.loadModels();
  }

  Future<void> _toggleListening() async {
    if (!_detector.isReady) {
      setState(() => _status = 'Espera, cargando modelo...');
      return;
    }

    if (_nexusDetected) {
      await _tts.stop();
      setState(() => _nexusDetected = false);
    }

    if (!await Permission.microphone.request().isGranted) {
      setState(() => _status = 'Permiso denegado');
      return;
    }

    if (!_recording) await _startPrebuffering();

    await [Permission.notification].request();
    await Permission.ignoreBatteryOptimizations.request();

    if (!_listening) {
      _detector.prepareForListening();
      await _bgService.startService();
      setState(() {
        _listening = true;
        _isStarting = true;
        _status = 'Iniciando...';
      });
    } else {
      _bgService.invoke('stopService');
      setState(() {
        _listening = false;
        _isStarting = false;
        _status = 'Pausado';
      });
    }
  }

  @override
  void dispose() {
    _stopRecorder();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexus'),
        backgroundColor: _nexusDetected ? Colors.orange : Colors.blue,
        actions: const [],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _status,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _nexusDetected ? Colors.orange : null,
              ),
            ),
            const SizedBox(height: 40),
            if (_nexusDetected) ...[
              const Icon(Icons.smart_toy, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text('Hola! En que puedo ayudarte?',
                  style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
              const SizedBox(height: 30),
            ],
            SizedBox(
              width: 100,
              height: 100,
              child: FloatingActionButton(
                onPressed: _toggleListening,
                backgroundColor: _listening ? Colors.red : Colors.green,
                child: _isStarting
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _listening ? Icons.stop : Icons.play_arrow,
                        size: 48,
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _listening ? 'Toca para detener' : 'Toca para iniciar',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
