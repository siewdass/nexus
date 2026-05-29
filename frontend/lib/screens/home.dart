import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/notifications.dart';
import '../services/wake.dart';
import '../services/tts.dart';
import '../services/network.dart';
import '../services/scanner.dart';

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
  String _thinkText = '';
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
      setState(() => _status = 'Di nexus');
      if (!networkService.isConnected) {
        final scan = Scanner.lastResult;
        if (scan != null) {
          try {
            await networkService.connect(host: scan.private, port: 5001);
          } catch (_) {}
        }
      }
    };
    _detector.onFirstPrediction = () {
      if (_isStarting) {
        setState(() {
          _isStarting = false;
          _status = _listening ? 'Escuchando...' : 'Di nexus';
        });
      }
    };
    _detector.onDetected = (score) async {
      if (!_listening) return;
      await _stopRecorder();
      _bgService.invoke('stopService');
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      setState(() {
        _listening = false;
        _recording = false;
        _isStarting = false;
        _nexusDetected = true;
        _thinkText = '';
        _status = 'Conectando...';
      });
      await showDetectionNotification(score);

      if (!networkService.isConnected) {
        final scan = Scanner.lastResult;
        if (scan == null) {
          setState(() => _status = 'Sin servidor');
          return;
        }
        try {
          await networkService.connect(host: scan.private, port: 5001);
        } catch (e) {
          setState(() => _status = 'Error de conexión');
          return;
        }
      }

      setState(() => _status = 'Preguntando...');

      final buffer = StringBuffer();
      final completer = Completer<String>();
      StreamSubscription tokenSub;
      StreamSubscription thinkSub;
      StreamSubscription doneSub;
      StreamSubscription errSub;

      tokenSub = networkService.tokens.listen((t) => buffer.write(t));
      thinkSub = networkService.think.listen((t) {
        setState(() => _thinkText += t);
      });
      doneSub = networkService.done.listen((_) {
        if (!completer.isCompleted) completer.complete(buffer.toString());
      });
      errSub = networkService.errors.listen((e) {
        if (!completer.isCompleted) completer.completeError(e);
      });

      networkService.sendChat(
        'El usuario te ha llamado. Salúdalo brevemente y pregúntale cómo puedes ayudarle.',
      );

      try {
        final response = await completer.future
            .timeout(const Duration(seconds: 15));
        setState(() => _status = 'Respondiendo...');
        await _tts.speakAndWait(response);
        setState(() {
          _nexusDetected = false;
          _thinkText = '';
          _status = 'Di nexus';
        });
      } catch (e) {
        setState(() {
          _thinkText = '';
          _status = 'Error: $e';
        });
      } finally {
        tokenSub.cancel();
        thinkSub.cancel();
        doneSub.cancel();
        errSub.cancel();
      }
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

    await [Permission.notification].request();
    await Permission.ignoreBatteryOptimizations.request();

    if (!_listening) {
      if (!_recording) await _startPrebuffering();
      _detector.prepareForListening();
      await _bgService.startService();
      setState(() {
        _listening = true;
        _isStarting = true;
        _status = 'Iniciando...';
      });
    } else {
      _bgService.invoke('stopService');
      await _stopRecorder();
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
            if (_thinkText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _thinkText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
