import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'state.dart';

typedef StartTunnelNative = Uint8 Function(Int32 localPort, Pointer<Utf8> server);
typedef StartTunnelDart = int Function(int localPort, Pointer<Utf8> server);
typedef StopTunnelNative = Void Function();
typedef StopTunnelDart = void Function();
typedef TunnelUrlNative = Pointer<Utf8> Function();
typedef TunnelUrlDart = Pointer<Utf8> Function();
typedef FreeStringNative = Void Function(Pointer<Utf8> s);
typedef FreeStringDart = void Function(Pointer<Utf8> s);

class TunnelFfi {
  late final StartTunnelDart _start;
  late final StopTunnelDart _stop;
  late final TunnelUrlDart _tunnelUrl;
  late final FreeStringDart _freeString;

  TunnelFfi() {
    final lib = DynamicLibrary.process();
    _start = lib.lookupFunction<StartTunnelNative, StartTunnelDart>('start_tunnel');
    _stop = lib.lookupFunction<StopTunnelNative, StopTunnelDart>('stop_tunnel');
    _tunnelUrl = lib.lookupFunction<TunnelUrlNative, TunnelUrlDart>('tunnel_url');
    _freeString = lib.lookupFunction<FreeStringNative, FreeStringDart>('free_string');
  }

  bool start(int localPort, String server) {
    final serverPtr = server.toNativeUtf8(allocator: calloc);
    final ok = _start(localPort, serverPtr) != 0;
    calloc.free(serverPtr);
    return ok;
  }

  void stop() {
    _stop();
  }

  String? get url {
    final ptr = _tunnelUrl();
    if (ptr == nullptr) return null;
    final s = ptr.toDartString();
    _freeString(ptr);
    return s;
  }
}

class TunnelService {
  TunnelFfi? _ffi;
  Timer? _pollTimer;
  int _pollCount = 0;
  int _retryCount = 0;

  void init(TunnelFfi ffi) {
    _ffi = ffi;
  }

  Future<void> start() async {
    debugPrint('TUNNEL start()');
    stop();
    if (kDebugMode) {
      debugPrint('TUNNEL debug delay 2s');
      await Future.delayed(const Duration(seconds: 2));
    }
    _retryCount = 0;
    final ok = _ffi?.start(5001, 'bore.pub') ?? false;
    debugPrint('TUNNEL ffi.start() => $ok');
    if (!ok) {
      _scheduleRetry();
      return;
    }
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
        hubState.markTunnelReady();
        _pollTimer?.cancel();
        _pollTimer = null;
        _retryCount = 0;
      }
      if (_pollCount > 20) {
        debugPrint('TUNNEL poll timeout');
        _pollTimer?.cancel();
        _pollTimer = null;
        _scheduleRetry();
      }
    });
  }

  void _scheduleRetry() {
    _retryCount++;
    if (_retryCount > 5) {
      debugPrint('TUNNEL max retries reached');
      return;
    }
    final delay = Duration(seconds: _retryCount * 2);
    debugPrint('TUNNEL retry #$_retryCount in ${delay.inSeconds}s');
    Future.delayed(delay, start);
  }

  void stop() {
    debugPrint('TUNNEL stop()');
    _pollTimer?.cancel();
    _pollTimer = null;
    _ffi?.stop();
    hubState.setPublicUrl(null);
  }
}

final tunnelService = TunnelService();
