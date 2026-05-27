import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'wakeword.dart';
import 'voice_test_screen.dart';

final _notif = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await _notif
      .initialize(const InitializationSettings(android: android, iOS: ios));

  final channel = AndroidNotificationChannel(
    'jarvis_detected',
    'Jarvis Wake Word',
    description: 'Notificaciones cuando se detecta hey jarvis',
    importance: Importance.high,
    playSound: true,
  );
  await _notif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const MaterialApp(home: OpenWakeWordDemo()));
}

class OpenWakeWordDemo extends StatefulWidget {
  const OpenWakeWordDemo({super.key});
  @override
  State<OpenWakeWordDemo> createState() => _OpenWakeWordDemoState();
}

class _OpenWakeWordDemoState extends State<OpenWakeWordDemo> {
  final _detector = WakeWordDetector();
  StreamSubscription<AudioDataContainer>? _audioStream;

  String _status = 'Cargando modelo...';
  bool _listening = false;
  bool _jarvisDetected = false;
  bool _isStarting = false;

  static const _sampleRate = 16000;

  @override
  void initState() {
    super.initState();
    _detector.onReady = () {
      setState(() => _status = 'Di hey jarvis');
    };
    _detector.onFirstPrediction = () {
      setState(() {
        _isStarting = false;
        _status = 'Escuchando...';
      });
    };
    _detector.onDetected = (score) {
      _audioStream?.cancel();
      Recorder.instance.stopStreamingData();
      Recorder.instance.stop();
      setState(() {
        _listening = false;
        _isStarting = false;
        _jarvisDetected = true;
        _status = 'Hey Jarvis! (${score.toStringAsFixed(2)})';
      });
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      _notif.show(
        0,
        'Hey Jarvis!',
        'Wake word detectado (${score.toStringAsFixed(2)})',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'jarvis_detected',
            'Jarvis Wake Word',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    };
    _detector.loadModels();
  }

  Future<void> _toggleListening() async {
    if (!_detector.isReady) {
      setState(() => _status = 'Espera, cargando modelo...');
      return;
    }
    if (!await Permission.microphone.request().isGranted) {
      setState(() => _status = 'Permiso denegado');
      return;
    }
    await [Permission.notification].request();

    if (!_listening) {
      _detector.reset();

      await Recorder.instance.init(
        format: PCMFormat.s16le,
        sampleRate: _sampleRate,
        channels: RecorderChannels.mono,
      );
      Recorder.instance.start();
      Recorder.instance.startStreamingData();
      _audioStream = Recorder.instance.uint8ListStream.listen((data) {
        _detector.feedAudio(data.rawData);
      });

      setState(() {
        _listening = true;
        _isStarting = true;
        _status = 'Iniciando...';
        _jarvisDetected = false;
      });
    } else {
      Recorder.instance.stopStreamingData();
      Recorder.instance.stop();
      await _audioStream?.cancel();

      setState(() {
        _listening = false;
        _isStarting = false;
        _status = 'Pausado';
      });
    }
  }

  @override
  void dispose() {
    Recorder.instance.stopStreamingData();
    Recorder.instance.stop();
    Recorder.instance.deinit();
    _audioStream?.cancel();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jarvis'),
        backgroundColor: _jarvisDetected ? Colors.orange : Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VoiceTestScreen(),
                )),
          ),
        ],
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
                color: _jarvisDetected ? Colors.orange : null,
              ),
            ),
            const SizedBox(height: 40),
            if (_jarvisDetected) ...[
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
