import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttService {
  stt.SpeechToText? _speech;
  bool _initialized = false;
  String _lastWords = '';
  Completer<void>? _sessionDone;
  Timer? _silenceTimer;

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

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      debugPrint('[STT] silence 3s -> done');
      if (_sessionDone != null && !_sessionDone!.isCompleted) {
        _sessionDone!.complete();
      }
    });
  }

  Future<String?> start() async {
    if (!_initialized || _speech == null) return null;
    _lastWords = '';
    _sessionDone = Completer<void>();
    _silenceTimer?.cancel();

    debugPrint('[STT] listen()');
    try {
      await _speech!.listen(
        onResult: (r) {
          final text = r.recognizedWords.trim();
          if (text.isNotEmpty) {
            _lastWords = text;
            debugPrint('[STT] <<< $text');
            _resetSilenceTimer();
          }
          if (r.finalResult) {
            _silenceTimer?.cancel();
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
    // Some Android devices fire 'done' (no result) before actual
    // recognition results arrive. Wait briefly for late results.
    await Future.delayed(const Duration(seconds: 1));
    _silenceTimer?.cancel();
    debugPrint('[STT] result: "$_lastWords"');
    return _lastWords.isNotEmpty ? _lastWords : null;
  }

  Future<void> stop() async {
    debugPrint('[STT] stop');
    _silenceTimer?.cancel();
    if (_sessionDone != null && !_sessionDone!.isCompleted) {
      _sessionDone!.complete();
    }
    await _speech?.stop();
  }

  void dispose() {
    _silenceTimer?.cancel();
    _sessionDone?.complete();
    _speech?.stop();
    _speech = null;
  }
}
