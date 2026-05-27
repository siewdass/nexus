import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'voice_test_screen.dart';

final _notif = FlutterLocalNotificationsPlugin();

double _sigmoid(double x) => 1.0 / (1.0 + exp(-x));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await _notif.initialize(const InitializationSettings(android: android, iOS: ios));

  final channel = AndroidNotificationChannel(
    'jarvis_detected',
    'Jarvis Wake Word',
    description: 'Notificaciones cuando se detecta hey jarvis',
    importance: Importance.high,
    playSound: true,
  );
  await _notif.resolvePlatformSpecificImplementation<
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
  Interpreter? _melspecModel;
  Interpreter? _embedding;
  Interpreter? _classifier;
  StreamSubscription<AudioDataContainer>? _audioStream;

  String _status = 'Cargando modelo...';
  bool _listening = false;
  bool _jarvisDetected = false;
  bool _modelReady = false;

  DateTime? _lastTrigger;
  double _currentScore = 0;
  double _currentRaw = 0;
  double _audioLevel = 0;
  double _melMin = 0;
  double _melMax = 0;
  double _embMin = 0;
  double _embMax = 0;
  int _debugMelFrames = 0;
  double _inputMin = 0;
  double _inputMax = 0;
  static const _debounceMs = 3000;
  static const _threshold = 0.55;
  static const _frameSize = 1280;
  static const _sampleRate = 16000;
  static const _melBins = 32;
  static const _windowSize = 76;
  static const _embedDim = 96;
  static const _nFeatureFrames = 16;
  static const _slidingWindowAvg = 10;
  static const _maxMelBuffer = 760;
  static const _maxFeatureBuffer = 120;
  static const _warmupFrames = 5;

  final List<double> _audioBuffer = [];
  final List<Float32List> _melBuffer = [];
  final List<Float32List> _featureBuffer = [];
  final List<double> _recentScores = [];
  int _predictionCount = 0;
  bool _processingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      setState(() => _status = 'Cargando modelos (3)...');

      final b1 = await rootBundle.load('assets/models/melspectrogram.tflite');
      final opts = InterpreterOptions()..addDelegate(XNNPackDelegate());
      _melspecModel = Interpreter.fromBuffer(b1.buffer.asUint8List(), options: opts);
      _melspecModel!.resizeInputTensor(0, [1, 1280]);
      _melspecModel!.allocateTensors();

      // Inspect all tensor shapes
      final melOut = _melspecModel!.getOutputTensor(0);
      final melIn = _melspecModel!.getInputTensor(0);
      debugPrint('Mel: in=${melIn.shape} type=${melIn.type} out=${melOut.shape} type=${melOut.type} dataLen=${melOut.data.length}');

      final b2 = await rootBundle.load('assets/models/embedding_model.tflite');
      _embedding = Interpreter.fromBuffer(b2.buffer.asUint8List());
      final embIn = _embedding!.getInputTensor(0);
      final embOut = _embedding!.getOutputTensor(0);
      debugPrint('Embedding: in=${embIn.shape} type=${embIn.type} out=${embOut.shape} type=${embOut.type}');

      final b3 = await rootBundle.load('assets/models/hey_jarvis.tflite');
      _classifier = Interpreter.fromBuffer(b3.buffer.asUint8List());
      final clsIn = _classifier!.getInputTensor(0);
      final clsOut = _classifier!.getOutputTensor(0);
      debugPrint('Classifier: in=${clsIn.shape} type=${clsIn.type} out=${clsOut.shape} type=${clsOut.type}');

      _modelReady = true;
      setState(() => _status = 'Di hey jarvis');
    } catch (e) {
      setState(() => _status = 'Error modelo: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (!_modelReady) {
      setState(() => _status = 'Espera, cargando modelo...');
      return;
    }
    if (!await Permission.microphone.request().isGranted) {
      setState(() => _status = 'Permiso denegado');
      return;
    }
    await [Permission.notification].request();

    if (!_listening) {

      _audioBuffer.clear();
      _melBuffer.clear();
      _featureBuffer.clear();
      _recentScores.clear();
      _predictionCount = 0;
      _processingAudio = false;

      // Initialize mel buffer with 76 ones frames (like openwakeword)
      for (int i = 0; i < _windowSize; i++) {
        _melBuffer.add(Float32List(_melBins)..fillRange(0, _melBins, 1.0));
      }

      await Recorder.instance.init(
        format: PCMFormat.s16le,
        sampleRate: _sampleRate,
        channels: RecorderChannels.mono,
      );
      Recorder.instance.start();
      Recorder.instance.startStreamingData();
      _audioStream = Recorder.instance.uint8ListStream.listen((data) {
        _processAudio(data.rawData);
      });

      setState(() {
        _listening = true;
        _status = 'Escuchando...';
        _jarvisDetected = false;
      });
      Timer.periodic(const Duration(seconds: 3), (t) {
        if (!_listening || !mounted) { t.cancel(); return; }
        debugPrint('a=${_audioLevel.toStringAsFixed(2)} i=[${_inputMin.toStringAsFixed(0)},${_inputMax.toStringAsFixed(0)}] f$_debugMelFrames m=[${_melMin.toStringAsFixed(1)},${_melMax.toStringAsFixed(1)}] e=[${_embMin.toStringAsFixed(0)},${_embMax.toStringAsFixed(0)}] r=${_currentRaw.toStringAsFixed(4)} s=${_currentScore.toStringAsFixed(4)}');
      });
    } else {
      _processingAudio = false;
      Recorder.instance.stopStreamingData();
      Recorder.instance.stop();
      await _audioStream?.cancel();

      setState(() {
        _listening = false;
        _status = 'Pausado';
      });
    }
  }

  void _processAudio(Uint8List buffer) {
    if (_melspecModel == null || _embedding == null || _classifier == null) return;
    if (_processingAudio) return;

    final int16Len = buffer.lengthInBytes ~/ 2;
    final int16List = buffer.buffer.asInt16List(buffer.offsetInBytes, int16Len);
    for (int i = 0; i < int16List.length; i++) {
      _audioBuffer.add(int16List[i] / 32768.0);
    }

    _processOneChunk();
  }

  void _processOneChunk() {
    if (!_listening) {
      _processingAudio = false;
      return;
    }
    if (_audioBuffer.length < _frameSize) {
      _processingAudio = false;
      return;
    }

    _processingAudio = true;
    final chunk = Float32List(_frameSize);
    for (int i = 0; i < _frameSize; i++) {
      chunk[i] = _audioBuffer[i];
    }
    _audioBuffer.removeRange(0, _frameSize);
    try {
      _processChunk(chunk);
    } catch (e, s) {
      debugPrint('CHUNK ERROR: $e\n$s');
    }

    Future.delayed(Duration.zero, _processOneChunk);
  }

  Float32List _readTensorFloats(dynamic tensor) {
    final data = tensor.data as Uint8List;
    final n = data.lengthInBytes ~/ 4;
    final result = Float32List(n);
    for (int i = 0; i < n; i++) {
      result[i] = data.buffer.asByteData(data.offsetInBytes).getFloat32(i * 4, Endian.little);
    }
    return result;
  }

  void _processChunk(Float32List chunk) {
    double maxLevel = 0;
    _inputMin = double.infinity;
    _inputMax = double.negativeInfinity;
    final melInputValues = [List.generate(1280, (i) {
      final v = chunk[i] * 10000.0;
      if (v < _inputMin) _inputMin = v;
      if (v > _inputMax) _inputMax = v;
      final abs = chunk[i] < 0 ? -chunk[i] : chunk[i];
      if (abs > maxLevel) maxLevel = abs;
      return v;
    })];
    _audioLevel = maxLevel;
    _melspecModel!.runInference([melInputValues]);

    // Read ALL mel frames from model output
    final melFloatsAll = _readTensorFloats(_melspecModel!.getOutputTensor(0));
    final numFrames = melFloatsAll.length ~/ _melBins;
    _debugMelFrames = numFrames;

    // Model writes 6 new frames at the END of the output ring buffer
    // Read the last 6 frames each time for streaming
    final startFrame = max(0, numFrames - 6);
    _melMin = double.infinity;
    _melMax = double.negativeInfinity;
    for (int fi = startFrame; fi < numFrames; fi++) {
      final norm = Float32List(_melBins);
      for (int j = 0; j < _melBins; j++) {
        final raw = melFloatsAll[fi * _melBins + j];
        if (raw.isFinite) {
          final v = (raw / 10.0) + 2.0;
          norm[j] = v;
        } else {
          norm[j] = 2.0;
        }
        if (norm[j] < _melMin) _melMin = norm[j];
        if (norm[j] > _melMax) _melMax = norm[j];
      }
      _melBuffer.add(norm);
    }

    // Cap mel buffer efficiently
    if (_melBuffer.length > _maxMelBuffer) {
      _melBuffer.removeRange(0, _melBuffer.length - _maxMelBuffer);
    }

    // Compute ONE embedding from the last 76 mel frames
    if (_melBuffer.length >= _windowSize) {
      final last76 = _melBuffer.sublist(_melBuffer.length - _windowSize);

      // Embedding expects NHWC: [1, 76, 32, 1] (batch, height, width, channels)
      final embInput = List.generate(1, (_) =>
          List.generate(_windowSize, (i) =>
              List.generate(_melBins, (j) =>
                  [last76[i][j]])));
      // Output is [1, 1, 1, 96]
      var embOutput = List.generate(1, (_) =>
          List.generate(1, (_) =>
              List.generate(1, (_) =>
                  List.filled(_embedDim, 0.0))));
      _embedding!.run(embInput, embOutput);

      final embedding = Float32List(_embedDim);
      _embMin = double.infinity;
      _embMax = double.negativeInfinity;
      for (int i = 0; i < _embedDim; i++) {
        final v = embOutput[0][0][0][i];
        embedding[i] = v;
        if (v < _embMin) _embMin = v;
        if (v > _embMax) _embMax = v;
      }
      _featureBuffer.add(embedding);

      while (_featureBuffer.length > _maxFeatureBuffer) {
        _featureBuffer.removeAt(0);
      }

      if (_featureBuffer.length >= _nFeatureFrames) {
        _runClassifier();
      }
    }
  }

  void _runClassifier() {
    _predictionCount++;

    if (_predictionCount <= _warmupFrames) {
      _currentScore = 0.0;
      _currentRaw = 0.0;
      return;
    }

    final startIdx = _featureBuffer.length - _nFeatureFrames;
    final classifierInput = [List.generate(_nFeatureFrames, (i) =>
        List.generate(_embedDim, (j) => _featureBuffer[startIdx + i][j]))];
    _classifier!.runInference([classifierInput]);
    final rawScore = _readTensorFloats(_classifier!.getOutputTensor(0))[0];
    _currentRaw = rawScore;
    final score = _sigmoid(rawScore);
    _currentScore = score;

    _recentScores.add(score);
    if (_recentScores.length > _slidingWindowAvg) {
      _recentScores.removeAt(0);
    }

    final avg = _recentScores.reduce((a, b) => a + b) / _recentScores.length;
    if (score >= _threshold || (_recentScores.length >= _slidingWindowAvg && avg >= _threshold)) {
      final now = DateTime.now();
      if (_lastTrigger == null ||
          now.difference(_lastTrigger!) > const Duration(milliseconds: _debounceMs)) {
        _lastTrigger = now;
        _recentScores.clear();

        _audioStream?.cancel();
        Recorder.instance.stopStreamingData();
        Recorder.instance.stop();

        setState(() {
          _listening = false;
          _jarvisDetected = true;
          _status = 'Hey Jarvis! (${avg.toStringAsFixed(2)})';
        });
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        _notif.show(
          0,
          'Hey Jarvis!',
          'Wake word detectado (${avg.toStringAsFixed(2)})',
          const NotificationDetails(
            android: AndroidNotificationDetails('jarvis_detected', 'Jarvis Wake Word',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    Recorder.instance.stopStreamingData();
    Recorder.instance.stop();
    Recorder.instance.deinit();
    _audioStream?.cancel();
    _melspecModel?.close();
    _embedding?.close();
    _classifier?.close();
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
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const VoiceTestScreen(),
            )),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status,
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
                child: Icon(
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
