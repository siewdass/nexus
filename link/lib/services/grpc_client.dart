import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:nexus_grpc/nexus_grpc.dart';

class GrpcClientService {
  ClientChannel? _channel;
  NexusServiceClient? _client;

  bool get isConnected => _channel != null;

  Future<void> connect({String host = 'localhost', int port = 5001, bool useTls = false}) async {
    disconnect();
    _channel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(
        credentials: useTls ? const ChannelCredentials.secure() : const ChannelCredentials.insecure(),
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
