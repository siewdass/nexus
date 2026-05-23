import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

const String _dylibDir = '../../libllama.dylib';
const String _modelPath = '../../Qwen3.5-0.8B-Q8.gguf';

Future<void> main() async {
  LlamaLibrary.load(path: _dylibDir);
  LlamaLog.captureToFile('/dev/null');

  print('Iniciando engine...\n');
  final engine = await LlamaEngine.spawn(
    libraryPath: _dylibDir,
    modelParams: ModelParams(path: _modelPath, gpuLayers: 99),
    contextParams: const ContextParams(nCtx: 4096),
  );

  final chat = await engine.createChat();
  chat.addSystem('Eres un asistente breve y conciso.');
  chat.addUser('Hola, dime algo breve en español:');

  print('Generando...\n');
  await for (final event in chat.generate(
    sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
    maxTokens: 4096,
  )) {
    switch (event) {
      case TokenEvent():
        stdout.write(event.text);
      case DoneEvent():
        print('\n\n[Hecho: ${event.reason}, ${event.generatedCount} tokens]');
      default:
        break;
    }
  }

  // Skip explicit dispose to avoid GGML_ASSERT crash during Metal cleanup on exit.
  // The OS reclaims GPU resources naturally when the process terminates.
}
