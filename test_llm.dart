import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final cache = '$home/.nexus_hub/cache';
  final dylib = '$cache/libllama.dylib';
  final model = '$cache/Qwen3-0.6B-Q8_0.gguf';

  if (!File(dylib).existsSync()) {
    print('ERROR: $dylib not found. Run the Flutter app first to extract assets.');
    exit(1);
  }

  print('Loading dylib: $dylib');
  LlamaLibrary.load(path: dylib);
  print('OK');

  LlamaLog.captureToFile('/dev/null');

  print('Spawning engine...');
  final engine = await LlamaEngine.spawn(
    libraryPath: dylib,
    modelParams: ModelParams(path: model, gpuLayers: 99),
    contextParams: const ContextParams(nCtx: 4096),
  );
  print('Engine ready');

  print('Creating chat...');
  final chat = await engine.createChat();
  chat.addSystem('Eres un asistente breve.');
  chat.addUser('Responde solo "Hola mundo"');

  print('Generating...');
  await for (final event in chat.generate(
    sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
    maxTokens: 128,
  )) {
    if (event is TokenEvent) {
      stdout.write(event.text);
    }
  }
  stdout.write('\n');
  print('Done!');
  engine.dispose();
}
