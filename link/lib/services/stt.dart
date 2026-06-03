import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttService {
  stt.SpeechToText? _speech;
  bool _initialized = false;
  String _lastWords = '';
  Completer<void>? _sessionDone;
  Timer? _silenceTimer;
  Timer? _maxDurationTimer;

  bool get isInitialized => _initialized;
  bool get isListening => _speech?.isListening ?? false;

  Future<bool> init() async {
    _speech = stt.SpeechToText();
    _initialized = await _speech!.initialize(
      onStatus: (s) {
        debugPrint('[STT] status: $s');
        if (s == 'done' &&
            _sessionDone != null &&
            !_sessionDone!.isCompleted) {
          _sessionDone!.complete();
        }
      },
      onError: (e) {
        debugPrint('[STT] error: ${e.errorMsg}');
        if (_sessionDone != null && !_sessionDone!.isCompleted) {
          _sessionDone!.complete();
        }
      },
    );
    return _initialized;
  }

  void _resetSilenceTimer(String currentText) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      debugPrint('[STT] silence 3s -> done');
      if (_sessionDone != null && !_sessionDone!.isCompleted) {
        _sessionDone!.complete();
      }
    });
  }

  void _cancelTimers() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
  }

  Future<String?> start() async {
    if (!_initialized || _speech == null) return null;
    _lastWords = '';
    _sessionDone = Completer<void>();
    _cancelTimers();

    debugPrint('[STT] listen()');

    _maxDurationTimer = Timer(const Duration(seconds: 10), () {
      debugPrint('[STT] max 10s -> done');
      if (_sessionDone != null && !_sessionDone!.isCompleted) {
        _sessionDone!.complete();
      }
    });

    try {
      await _speech!.listen(
        onResult: (r) {
          final text = r.recognizedWords.trim();
          if (text.isNotEmpty && text != _lastWords) {
            _lastWords = text;
            debugPrint('[STT] <<< $text');
            _resetSilenceTimer(text);
          }
          if (r.finalResult) {
            _cancelTimers();
            if (_sessionDone != null && !_sessionDone!.isCompleted) {
              _sessionDone!.complete();
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'es_ES',
        ),
      );
    } catch (e) {
      debugPrint('[STT] listen threw: $e');
    }

    debugPrint('[STT] waiting for done...');
    await _sessionDone!.future;
    _cancelTimers();
    // Solo esperar resultados tardios si aun no hay palabras reconocidas
    if (_lastWords.isEmpty) {
      await Future.delayed(const Duration(seconds: 1));
    }
    _cancelTimers();
    debugPrint('[STT] result: "$_lastWords"');
    return _lastWords.isNotEmpty ? _lastWords : null;
  }

  Future<void> stop() async {
    debugPrint('[STT] stop');
    _cancelTimers();
    if (_sessionDone != null && !_sessionDone!.isCompleted) {
      _sessionDone!.complete();
    }
    await _speech?.stop();
  }

  void dispose() {
    _cancelTimers();
    _sessionDone?.complete();
    _speech?.stop();
    _speech = null;
  }
}
