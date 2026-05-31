import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final _tts = FlutterTts();

  Future<void> init() async {
    try {
      await _tts.setEngine('com.google.android.tts');
      final voices = await _tts.getVoices;
      final target = (voices as List).cast<Map>().firstWhere(
            (v) =>
                (v['name'] as String?)?.toLowerCase() ==
                'es-us-x-esd-network',
            orElse: () => const <String, String>{},
          );
      if (target.isNotEmpty) {
        final clean = <String, String>{};
        for (final e in target.entries) {
          if (e.key != null && e.value != null) {
            clean[e.key.toString()] = e.value.toString();
          }
        }
        await _tts.setVoice(clean);
      }
    } catch (e) {
      debugPrint('TTS INIT ERROR: $e');
    }
  }

  Future<void> speak(String text) async {
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS SPEAK ERROR: $e');
    }
  }

  Future<void> speakAndWait(String text) async {
    final completer = Completer<void>();
    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    await speak(text);
    await completer.future.timeout(const Duration(seconds: 60));
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
