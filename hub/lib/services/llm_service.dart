import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class LlmService {
  LlamaEngine? _engine;

  LlamaEngine? get engine => _engine;

  Future<void> init({required String dylibPath, required String modelPath}) async {
    LlamaLibrary.load(path: dylibPath);
    LlamaLog.captureToFile('/dev/null');
    _engine = await LlamaEngine.spawn(
      libraryPath: dylibPath,
      modelParams: ModelParams(path: modelPath, gpuLayers: 99),
      contextParams: const ContextParams(nCtx: 4096),
    );
  }
}

final llmService = LlmService();
