import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

double _sigmoid(double x) => 1.0 / (1.0 + exp(-x));

void main() => runApp(const MaterialApp(home: OpenWakeWordDemo()));

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

  String _status = "⏳ Cargando modelo...";
  bool _listening = false;
  bool _jarvisDetected = false;
  bool _modelReady = false;

  DateTime? _lastTrigger;
  static const _debounceMs = 2000;
  static const _threshold = 0.3;
  static const _frameSize = 1280;
  static const _sampleRate = 16000;
  static const _melBins = 32;
  static const _windowSize = 76;
  static const _stepSize = 8;
  static const _embedDim = 96;
  static const _nFeatureFrames = 16;
  static const _slidingWindowAvg = 10;

  final List<double> _audioBuffer = [];
  final List<Float32List> _melBuffer = [];
  final List<Float32List> _featureBuffer = [];
  final List<double> _recentScores = [];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      setState(() => _status = "⏳ Cargando modelos (3)...");

      final b1 = await rootBundle.load('assets/models/melspectrogram.tflite');
      final opts = InterpreterOptions()..addDelegate(XNNPackDelegate());
      _melspecModel = Interpreter.fromBuffer(b1.buffer.asUint8List(), options: opts);
      _melspecModel!.resizeInputTensor(0, [1, 1280]);
      _melspecModel!.allocateTensors();

      final b2 = await rootBundle.load('assets/models/embedding_model.tflite');
      _embedding = Interpreter.fromBuffer(b2.buffer.asUint8List());

      final b3 = await rootBundle.load('assets/models/hey_jarvis.tflite');
      _classifier = Interpreter.fromBuffer(b3.buffer.asUint8List());

      _modelReady = true;
      setState(() => _status = "✅ Listo. Di 'hey jarvis'");
    } catch (e, s) {
      setState(() => _status = "❌ Error modelo: $e");
    }
  }

  Future<void> _toggleListening() async {
    if (!_modelReady) {
      setState(() => _status = "⏳ Espera, cargando modelo...");
      return;
    }
    if (!await Permission.microphone.request().isGranted) {
      setState(() => _status = "🔇 Permiso denegado");
      return;
    }
    if (!_listening) {
      _audioBuffer.clear();
      _melBuffer.clear();
      _featureBuffer.clear();
      _recentScores.clear();
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
        _status = "🎙️ Escuchando... di 'hey jarvis'";
        _jarvisDetected = false;
      });
    } else {
      Recorder.instance.stopStreamingData();
      Recorder.instance.stop();
      await _audioStream?.cancel();
      setState(() {
        _listening = false;
        _status = "⏸️ Pausado";
      });
    }
  }

  void _processAudio(Uint8List buffer) {
    if (_melspecModel == null || _embedding == null || _classifier == null) return;

    final int16List = buffer.buffer.asInt16List();
    for (int i = 0; i < int16List.length; i++) {
      _audioBuffer.add(int16List[i] / 32768.0);
    }

    while (_audioBuffer.length >= _frameSize) {
      final chunk = Float32List(_frameSize);
      for (int i = 0; i < _frameSize; i++) {
        chunk[i] = _audioBuffer[i];
      }
      _audioBuffer.removeRange(0, _frameSize);
      _processChunk(chunk);
    }
  }

  void _processChunk(Float32List chunk) {
    final melInput = [List.generate(1280, (i) => chunk[i] * 32768.0)];
    _melspecModel!.runInference([melInput]);
    final melBytes = _melspecModel!.getOutputTensor(0).data.sublist(0);
    final melFloats = melBytes.buffer.asFloat32List();
    final numFrames = melFloats.length ~/ _melBins;

    for (int t = 0; t < numFrames; t++) {
      final norm = Float32List(_melBins);
      for (int j = 0; j < _melBins; j++) {
        norm[j] = (melFloats[t * _melBins + j] / 10.0) + 2.0;
      }
      _melBuffer.add(norm);
    }

    while (_melBuffer.length >= _windowSize) {
      final window = Float32List(_windowSize * _melBins);
      for (int i = 0; i < _windowSize; i++) {
        window.setRange(i * _melBins, (i + 1) * _melBins, _melBuffer[i]);
      }

      final remove = _stepSize < _melBuffer.length ? _stepSize : _melBuffer.length;
      _melBuffer.removeRange(0, remove);

      var embOutput = List.filled(96, 0.0).reshape([1, 1, 1, 96]);
      final embInput = [
        List.generate(_windowSize, (i) =>
            List.generate(_melBins, (j) => [window[i * _melBins + j]]))
      ];
      _embedding!.run(embInput, embOutput);
      final embedding = Float32List(_embedDim);
      for (int i = 0; i < _embedDim; i++) {
        embedding[i] = embOutput[0][0][0][i];
      }
      _featureBuffer.add(embedding);

      if (_featureBuffer.length >= _nFeatureFrames) {
        _runClassifier();
      }
    }
  }

  void _runClassifier() {
    final startIdx = _featureBuffer.length - _nFeatureFrames;
    final classifierInput = [
      List.generate(_nFeatureFrames, (i) =>
          List.generate(_embedDim, (j) => _featureBuffer[startIdx + i][j]))
    ];
    _classifier!.runInference([classifierInput]);
    final clBytes = _classifier!.getOutputTensor(0).data.sublist(0);
    final rawScore = clBytes.buffer.asFloat32List()[0];
    final score = _sigmoid(rawScore);

    _recentScores.add(score);
    if (_recentScores.length > _slidingWindowAvg) {
      _recentScores.removeAt(0);
    }

    final avg = _recentScores.reduce((a, b) => a + b) / _recentScores.length;
    if (_recentScores.length >= _slidingWindowAvg && avg >= _threshold) {
      final now = DateTime.now();
      if (_lastTrigger == null ||
          now.difference(_lastTrigger!) > const Duration(milliseconds: _debounceMs)) {
        _lastTrigger = now;
        setState(() {
          _jarvisDetected = true;
          _status = "🔥 ¡HEY JARVIS! (${avg.toStringAsFixed(2)})";
        });
        HapticFeedback.heavyImpact();
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
        title: const Text("🤖 openWakeWord Demo"),
        backgroundColor: _jarvisDetected ? Colors.orange : Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            if (_jarvisDetected) ...[
              const Icon(Icons.smart_toy, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text("¡Hola! ¿En qué puedo ayudarte?",
                  style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
              const SizedBox(height: 30),
            ],
            ElevatedButton.icon(
              onPressed: _toggleListening,
              icon: Icon(_listening ? Icons.stop : Icons.mic),
              label: Text(_listening ? "Detener" : "Iniciar"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: _listening ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "💡 Di 'hey jarvis'. Offline, sin API key.\nUmbral: $_threshold",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
