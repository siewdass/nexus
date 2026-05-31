import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class NetworkService extends ChangeNotifier {
  io.Socket? _socket;
  bool _connecting = false;
  int _connectCount = 0;
  final _tokenController = StreamController<String>.broadcast();
  final _thinkController = StreamController<String>.broadcast();
  final _doneController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();

  Stream<String> get tokens => _tokenController.stream;
  Stream<String> get think => _thinkController.stream;
  Stream<void> get done => _doneController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<void> get onDisconnect => _disconnectController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect({String host = 'localhost', int port = 5001}) async {
    final id = ++_connectCount;
    debugPrint('NET connect#$id: host=$host:$port connected=$isConnected connecting=$_connecting');
    if (isConnected) {
      debugPrint('NET connect#$id skipped: already connected');
      return;
    }
    if (_connecting) {
      debugPrint('NET connect#$id skipped: already connecting');
      return;
    }
    _connecting = true;
    _socket?.disconnect();
    _socket?.clearListeners();

    _socket = io.io('http://$host:$port', <String, dynamic>{
      'transports': ['websocket'],
      'reconnection': false,
    });

    final completer = Completer<void>();
    _socket!.onConnect((_) {
      debugPrint('NET connect#$id connected');
      notifyListeners();
      if (!completer.isCompleted) completer.complete();
    });
    _socket!.onDisconnect((_) {
      debugPrint('NET connect#$id disconnected');
      _disconnectController.add(null);
      notifyListeners();
    });
    _socket!.onConnectError((data) {
      _connecting = false;
      if (!completer.isCompleted) {
        completer.completeError('Connection failed: $data');
      }
    });
    _socket!.onError((data) {
      _connecting = false;
      if (!completer.isCompleted) {
        completer.completeError('Socket error: $data');
      }
    });

    _socket!.on('token', (data) => _tokenController.add(data as String));
    _socket!.on('think', (data) => _thinkController.add(data as String));
    _socket!.on('done', (_) => _doneController.add(null));
    _socket!.on('error', (data) => _errorController.add(data as String));

    _socket!.connect();
    try {
      await completer.future.timeout(const Duration(seconds: 5));
    } finally {
      _connecting = false;
    }
  }

  void sendChat(String text) {
    debugPrint('NET sendChat: connected=${_socket?.connected} text=$text');
    _socket?.emit('chat', {'text': text});
  }

  void disconnect() {
    _connecting = false;
    _socket?.disconnect();
    _socket?.clearListeners();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _tokenController.close();
    _thinkController.close();
    _doneController.close();
    _errorController.close();
    _disconnectController.close();
  }
}

final networkService = NetworkService();
