import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class WakeWordDetector {
  Interpreter? _melspecModel;
  Interpreter? _embedding;
  Interpreter? _classifier;

  bool _isReady = false;
  bool _isStarting = false;

  static const _threshold = 0.51;
  static const _frameSize = 1280;
  static const _melBins = 32;
  static const _windowSize = 76;
  static const _embedDim = 96;
  static const _nFeatureFrames = 16;
  static const _slidingWindowAvg = 10;
  static const _maxMelBuffer = 760;
  static const _maxFeatureBuffer = 120;
  static const _warmupFrames = 0;
  static const _debounceMs = 3000;

  final List<double> _audioBuffer = [];
  final List<Float32List> _melBuffer = [];
  final List<Float32List> _featureBuffer = [];
  final List<double> _recentScores = [];
  int _predictionCount = 0;
  bool _processingAudio = false;
  final List<double> _melInputBuf = List.filled(1280, 0.0);
  DateTime? _lastTrigger;
  final _embOutput = List.generate(
      1,
      (_) => List.generate(
          1, (_) => List.generate(1, (_) => List.filled(96, 0.0))));

  VoidCallback? onReady;
  VoidCallback? onFirstPrediction;
  void Function(double score)? onDetected;

  bool get isReady => _isReady;
  bool get isStarting => _isStarting;

  Future<void> loadModels() async {
    final b1 = await rootBundle.load('assets/models/melspectrogram.tflite');
    final opts = InterpreterOptions()..addDelegate(XNNPackDelegate());
    _melspecModel =
        Interpreter.fromBuffer(b1.buffer.asUint8List(), options: opts);
    _melspecModel!.resizeInputTensor(0, [1, 1280]);
    _melspecModel!.allocateTensors();

    final b2 = await rootBundle.load('assets/models/embedding_model.tflite');
    _embedding = Interpreter.fromBuffer(b2.buffer.asUint8List());

    final b3 = await rootBundle.load('assets/models/hey_jarvis.tflite');
    _classifier = Interpreter.fromBuffer(b3.buffer.asUint8List());

    _isReady = true;
    onReady?.call();
  }

  void reset() {
    _audioBuffer.clear();
    _melBuffer.clear();
    _featureBuffer.clear();
    _recentScores.clear();
    _predictionCount = 0;
    _processingAudio = false;
    _isStarting = true;
    _lastTrigger = null;

    for (int i = 0; i < _windowSize; i++) {
      _melBuffer.add(Float32List(_melBins)..fillRange(0, _melBins, 1.0));
    }
  }

  void feedAudio(Uint8List rawData) {
    if (!_isReady) return;
    if (_processingAudio) return;

    final int16Len = rawData.lengthInBytes ~/ 2;
    final int16List =
        rawData.buffer.asInt16List(rawData.offsetInBytes, int16Len);
    for (int i = 0; i < int16List.length; i++) {
      _audioBuffer.add(int16List[i] / 32768.0);
    }

    _processOneChunk();
  }

  void _processOneChunk() {
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
      result[i] = data.buffer
          .asByteData(data.offsetInBytes)
          .getFloat32(i * 4, Endian.little);
    }
    return result;
  }

  double _sigmoid(double x) => 1.0 / (1.0 + exp(-x));

  void _processChunk(Float32List chunk) {
    for (int i = 0; i < _frameSize; i++) {
      _melInputBuf[i] = chunk[i] * 10000.0;
    }
    _melspecModel!.runInference([
      [_melInputBuf]
    ]);

    final melFloatsAll = _readTensorFloats(_melspecModel!.getOutputTensor(0));
    final numFrames = melFloatsAll.length ~/ _melBins;

    final startFrame = max(0, numFrames - 6);
    for (int fi = startFrame; fi < numFrames; fi++) {
      final norm = Float32List(_melBins);
      for (int j = 0; j < _melBins; j++) {
        final raw = melFloatsAll[fi * _melBins + j];
        norm[j] = raw.isFinite ? (raw / 10.0) + 2.0 : 2.0;
      }
      _melBuffer.add(norm);
    }

    if (_melBuffer.length > _maxMelBuffer) {
      _melBuffer.removeRange(0, _melBuffer.length - _maxMelBuffer);
    }

    if (_melBuffer.length >= _windowSize) {
      final last76 = _melBuffer.sublist(_melBuffer.length - _windowSize);

      final embInput = List.generate(
          1,
          (_) => List.generate(_windowSize,
              (i) => List.generate(_melBins, (j) => [last76[i][j]])));
      _embedding!.run(embInput, _embOutput);

      final embedding = Float32List(_embedDim);
      for (int i = 0; i < _embedDim; i++) {
        embedding[i] = _embOutput[0][0][0][i];
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
    if (_predictionCount <= _warmupFrames) return;

    if (_isStarting) {
      _isStarting = false;
      onFirstPrediction?.call();
    }

    final startIdx = _featureBuffer.length - _nFeatureFrames;
    final classifierInput = [
      List.generate(
          _nFeatureFrames,
          (i) =>
              List.generate(_embedDim, (j) => _featureBuffer[startIdx + i][j]))
    ];
    _classifier!.runInference([classifierInput]);
    final rawScore = _readTensorFloats(_classifier!.getOutputTensor(0))[0];
    final score = _sigmoid(rawScore);

    _recentScores.add(score);
    if (_recentScores.length > _slidingWindowAvg) {
      _recentScores.removeAt(0);
    }

    final avg = _recentScores.reduce((a, b) => a + b) / _recentScores.length;
    if (score >= _threshold ||
        (_recentScores.length >= _slidingWindowAvg && avg >= _threshold)) {
      final now = DateTime.now();
      if (_lastTrigger == null ||
          now.difference(_lastTrigger!) >
              const Duration(milliseconds: _debounceMs)) {
        _lastTrigger = now;
        _recentScores.clear();
        onDetected?.call(avg);
      }
    }
  }

  void dispose() {
    _melspecModel?.close();
    _embedding?.close();
    _classifier?.close();
  }
}
