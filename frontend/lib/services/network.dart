import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

class NetworkService {
  io.Socket? _socket;
  final _tokenController = StreamController<String>.broadcast();
  final _doneController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get tokens => _tokenController.stream;
  Stream<void> get done => _doneController.stream;
  Stream<String> get errors => _errorController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect({String host = 'localhost', int port = 5001}) async {
    disconnect();

    _socket = io.io(
      'http://$host:$port',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .build(),
    );

    final completer = Completer<void>();
    _socket!.onConnect((_) {
      if (!completer.isCompleted) completer.complete();
    });
    _socket!.onConnectError((data) {
      if (!completer.isCompleted) {
        completer.completeError('Connection failed: $data');
      }
    });
    _socket!.onError((data) {
      if (!completer.isCompleted) {
        completer.completeError('Socket error: $data');
      }
    });

    _socket!.on('token', (data) => _tokenController.add(data as String));
    _socket!.on('done', (_) => _doneController.add(null));
    _socket!.on('error', (data) => _errorController.add(data as String));

    _socket!.connect();
    await completer.future.timeout(const Duration(seconds: 5));
  }

  void sendChat(String text) {
    _socket?.emit('chat', {'text': text});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.clearListeners();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _tokenController.close();
    _doneController.close();
    _errorController.close();
  }
}
