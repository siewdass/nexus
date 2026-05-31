import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final cache = '$home/.nexus_hub/cache';
  final dylib = '$cache/libllama.dylib';
  final model = '$cache/Qwen3-0.6B-Q8_0.gguf';
  print('1: loading...');
  LlamaLibrary.load(path: dylib);
  print('2: loaded');
  LlamaLog.captureToFile('/dev/null');
  print('3: spawning...');
  final engine = await LlamaEngine.spawn(
    libraryPath: dylib,
    modelParams: ModelParams(path: model, gpuLayers: 99),
    contextParams: const ContextParams(nCtx: 4096),
  );
  print('4: spawned, creating chat...');
  final chat = await engine.createChat();
  chat.addSystem('Eres un asistente breve.');
  chat.addUser('Responde solo "Hola mundo"');
  print('5: generating...');
  await for (final event in chat.generate(
    sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
    maxTokens: 128,
  )) {
    if (event is TokenEvent) {
      stdout.write(event.text);
    }
  }
  print('\n6: done');
  engine.dispose();
}
