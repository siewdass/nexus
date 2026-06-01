import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'state.dart';
import 'tunnel_ffi.dart';

class TunnelService {
  TunnelFfi? _ffi;
  Process? _process;
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
    _process?.kill();
    _process = null;
    hubState.setPublicUrl(null);
  }

  // -- cloudflared (kept, unused) --

  Future<void> startCloudflared(String cloudflaredPath) async {
    stop();
    final proc = await Process.start(
      cloudflaredPath,
      [
        'tunnel',
        '--url', 'tcp://localhost:5001',
        '--edge-ip-version', '4',
        '--no-autoupdate',
        '--retries', '1',
      ],
    );
    _process = proc;

    proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final match = RegExp(r'(https?|tcp)://[a-z0-9-]+\.trycloudflare\.com(:\d+)?')
          .firstMatch(line);
      if (match != null) {
        hubState.setPublicUrl(match.group(0));
      }
      if (line.contains('error') || line.contains('Failed')) {
        hubState.setError(line);
      }
    });
  }
}
