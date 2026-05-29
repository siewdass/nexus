import 'dart:convert';
import 'dart:io';
import 'package:socket_io_plus/socket_io.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:hotreloader/hotreloader.dart';

class LlmService {
  LlamaEngine? _engine;

  LlamaEngine? get engine => _engine;

  Future<void> init() async {
    const dylib = 'assets/libllama.dylib';
    const model = 'assets/Qwen3-0.6B-Q8_0.gguf';
    LlamaLibrary.load(path: dylib);
    LlamaLog.captureToFile('/dev/null');
    _engine = await LlamaEngine.spawn(
      libraryPath: dylib,
      modelParams: ModelParams(path: model, gpuLayers: 99),
      contextParams: const ContextParams(nCtx: 4096),
    );
  }
}

Future<void> main() async {
  final reloader = await HotReloader.create(
    debounceInterval: Duration(seconds: 1),
  );
  print('Iniciando LLM engine...');
  final llm = LlmService();
  await llm.init();
  print('LLM listo.');

  final io = Server();

  io.on('connection', (Socket client) {
    print('Cliente conectado: ${client.id}');

    client.on('chat', (data) async {
      if (llm.engine == null) {
        client.emit('error', 'Engine no inicializado');
        return;
      }

      final text = (data as Map?)?['text'] as String?;
      if (text == null || text.isEmpty) {
        client.emit('error', 'Texto vacio');
        return;
      }

      final chat = await llm.engine!.createChat();
      chat.addSystem('Eres un asistente breve y conciso. Responde en espanol.');
      chat.addUser(text);

      await for (final event in chat.generate(
        sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
        maxTokens: 4096,
      )) {
        if (event is TokenEvent) {
          client.emit('token', event.text);
        }
      }

      client.emit('done', '');
    });

    client.on('disconnect', (_) {
      print('Cliente desconectado: ${client.id}');
    });
  });

  await io.listen(5001);
  print('Private: http://localhost:5001');

  final tunnelBin = File('assets/cloudflared');
  if (tunnelBin.existsSync()) {
    final tunnel = await Process.start(
      tunnelBin.path,
      ['tunnel', '--url', 'http://localhost:5001'],
    );
    tunnel.stderr.transform(utf8.decoder).listen((line) {
      final match =
          RegExp(r'https://[a-z-]+\.trycloudflare\.com').firstMatch(line);
      if (match != null) {
        print('Public: ${match.group(0)}');
      }
    });
  }
}
