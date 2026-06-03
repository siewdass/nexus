import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class BeepService {
  final _player = AudioPlayer();
  static const _channel = MethodChannel('nexus/audio');

  BeepService() {
    _player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gain,
      ),
    ));
  }

  Future<bool> _hasSound() async {
    try {
      final mode = await _channel.invokeMethod<int>('getRingerMode');
      return mode == 2;
    } catch (_) {
      return true;
    }
  }

  Future<void> play() async {
    if (await _hasSound()) {
      try {
        await _player.play(AssetSource('beep.wav'), volume: 1.0);
      } catch (_) {}
    } else {
      try {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 200);
        }
      } catch (_) {}
    }
  }

  void dispose() {
    _player.dispose();
  }
}
