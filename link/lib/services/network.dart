import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nexus_grpc/nexus_grpc.dart';

import 'grpc_client.dart';

class NetworkService extends ChangeNotifier {
  GrpcClientService? _grpc;
  bool _connecting = false;
  int _connectCount = 0;
  StreamSubscription<MessageResponse>? _chatSub;

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

  bool get isConnected => _grpc?.isConnected ?? false;

  Future<void> connect({String host = 'localhost', int port = 5001}) async {
    final id = ++_connectCount;
    debugPrint('NET connect#$id: host=$host:$port connected=$isConnected connecting=$_connecting');
    if (_connecting) {
      debugPrint('NET connect#$id skipped: already connecting');
      return;
    }
    _connecting = true;
    _grpc?.disconnect();

    try {
      _grpc = GrpcClientService();
      await _grpc!.connect(host: host, port: port);
      debugPrint('NET connect#$id connected');
      notifyListeners();
    } catch (e) {
      _connecting = false;
      debugPrint('NET connect#$id error: $e');
      rethrow;
    }
    _connecting = false;
  }

  void sendChat(String text) {
    debugPrint('NET sendChat: connected=${isConnected} text=$text');
    if (_grpc == null) {
      _errorController.add('No conectado');
      return;
    }

    _chatSub?.cancel();
    _chatSub = _grpc!.sendMessage(text).listen(
      (resp) {
        if (resp.hasThink()) {
          _thinkController.add(resp.think);
        }
        if (resp.hasReply()) {
          _tokenController.add(resp.reply);
        }
        if (resp.hasDone()) {
          _doneController.add(null);
        }
        if (resp.hasError()) {
          _errorController.add(resp.error);
        }
      },
      onError: (e) {
        _errorController.add('$e');
        disconnect();
      },
    );
  }

  void disconnect() {
    _chatSub?.cancel();
    _chatSub = null;
    _connecting = false;
    _grpc?.disconnect();
    _grpc = null;
    _disconnectController.add(null);
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _tokenController.close();
    _thinkController.close();
    _doneController.close();
    _errorController.close();
    _disconnectController.close();
    super.dispose();
  }
}

final networkService = NetworkService();
