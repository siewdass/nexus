import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'state.dart';

class TunnelService {
  Process? _process;

  Future<void> start(String cloudflaredPath) async {
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

  void stop() {
    _process?.kill();
    _process = null;
    hubState.setPublicUrl(null);
  }
}
