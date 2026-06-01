import 'dart:async';
import 'package:flutter/foundation.dart';

import 'state.dart';
import 'tunnel_ffi.dart';

class TunnelService {
  TunnelFfi? _ffi;
  Timer? _pollTimer;
  int _pollCount = 0;

  void init(TunnelFfi ffi) {
    _ffi = ffi;
  }

  void start() {
    debugPrint('TUNNEL start()');
    stop();
    final ok = _ffi?.start(5001, 'bore.pub') ?? false;
    debugPrint('TUNNEL ffi.start() => $ok');
    if (!ok) return;
    _pollCount = 0;
    _pollUrl();
  }

  void _pollUrl() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollCount++;
      final u = _ffi?.url;
      debugPrint('TUNNEL poll #$_pollCount: url=$u');
      if (u != null) {
        hubState.setPublicUrl(u);
        debugPrint('TUNNEL publicUrl set: $u');
        _pollTimer?.cancel();
        _pollTimer = null;
      }
      if (_pollCount > 20) {
        debugPrint('TUNNEL poll timeout');
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    });
  }

  void stop() {
    debugPrint('TUNNEL stop()');
    _pollTimer?.cancel();
    _pollTimer = null;
    _ffi?.stop();
    hubState.setPublicUrl(null);
  }

}
