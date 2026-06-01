import 'dart:ffi';
import 'package:ffi/ffi.dart';

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
