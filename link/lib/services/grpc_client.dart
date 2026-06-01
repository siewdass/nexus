import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:nexus_grpc/nexus_grpc.dart';

class GrpcClientService {
  ClientChannel? _channel;
  NexusServiceClient? _client;

  bool get isConnected => _channel != null;

  Future<void> connect({String host = 'localhost', int port = 5001}) async {
    disconnect();
    // Test TCP connectivity first
    final socket = await Socket.connect(host, port,
        timeout: const Duration(seconds: 5));
    await socket.close();
    _channel = ClientChannel(
      host,
      port: port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _client = NexusServiceClient(_channel!);
  }

  void disconnect() {
    _channel?.shutdown();
    _channel = null;
    _client = null;
  }

  Stream<MessageResponse> sendMessage(String text, {String sessionId = ''}) {
    return _client!.message(
      MessageRequest(sessionId: sessionId, message: text),
    );
  }
}
