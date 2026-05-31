import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ScanResult {
  final String private;
  final String public;

  ScanResult({required this.private, required this.public});

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        private: json['private'] as String,
        public: json['public'] as String,
      );
}

class Scanner {
  static String? _localIp;
  static ScanResult? _lastResult;

  static String? get localIp => _localIp;
  static ScanResult? get lastResult => _lastResult;

  static Future<String?> _getLocalIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (final iface in interfaces) {
      if (iface.name.startsWith('en') ||
          iface.name.startsWith('wlan') ||
          iface.name.startsWith('eth')) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            return ip;
          }
        }
      }
    }
    return null;
  }

  static String _broadcastAddress(String ip) {
    final parts = ip.split('.');
    parts[3] = '255';
    return parts.join('.');
  }

  static Future<ScanResult?> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _localIp ??= await _getLocalIp();
    if (_localIp == null) {
      debugPrint('SCANNER: no local IP');
      return null;
    }

    final broadcast = _broadcastAddress(_localIp!);
    debugPrint('SCANNER: local=$_localIp broadcast=$broadcast');

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;

      final data = utf8.encode('NEXUS_DISCOVER');
      socket.send(
        data,
        InternetAddress(broadcast),
        5002,
      );

      final completer = Completer<ScanResult>();
      final timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Discovery timeout'));
        }
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket!.receive();
          if (datagram != null) {
            final msg = utf8.decode(datagram.data);
            try {
              final json = jsonDecode(msg) as Map<String, dynamic>;
              if (!completer.isCompleted) {
                completer.complete(ScanResult.fromJson(json));
                timer.cancel();
              }
            } catch (_) {}
          }
        }
      });

      try {
        final result = await completer.future;
        _lastResult = result;
        return result;
      } on TimeoutException {
        debugPrint('SCANNER: timeout');
        return null;
      }
    } catch (e) {
      debugPrint('SCANNER error: $e');
      return null;
    } finally {
      socket?.close();
    }
  }
}
