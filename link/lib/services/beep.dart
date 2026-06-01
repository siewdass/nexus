import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class BeepService {
  final _player = AudioPlayer();

  BeepService() {
    _player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gain,
      ),
    ));
  }

  Future<void> play() async {
    try {
      await _player.play(AssetSource('beep.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('BEEP error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
