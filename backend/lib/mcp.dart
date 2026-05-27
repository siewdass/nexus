import 'package:mcp_client/mcp_client.dart';

class McpTools {
  Client? _client;
  List<Tool>? _tools;

  Future<void> connect({
    required String command,
    List<String> arguments = const [],
    String? workingDirectory,
  }) async {
    final config = McpClient.simpleConfig(
      name: 'agentic_dart',
      version: '0.1.0',
    );
    final transport = TransportConfig.stdio(
      command: command,
      arguments: arguments,
      workingDirectory: workingDirectory,
    );
    final result = await McpClient.createAndConnect(
      config: config,
      transportConfig: transport,
    );
    _client = result.fold(
      (c) => c,
      (e) => throw Exception('MCP connection failed: $e'),
    );
    _tools = await _client!.listTools();
  }

  List<Tool> get tools => _tools ?? [];

  String get toolDescriptions {
    return tools.map((t) {
      final props = t.inputSchema['properties'] as Map<String, dynamic>?;
      final params = props?.entries.map((e) => e.key).join(', ');
      return '- ${t.name}(${params ?? ''}) — ${t.description}';
    }).join('\n');
  }

  Future<String> callTool(String name, Map<String, dynamic> args) async {
    final result = await _client!.callTool(name, args);
    return result.content
        .map((c) => c is TextContent ? c.text : c.toString())
        .join('\n');
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
    _tools = null;
  }
}
