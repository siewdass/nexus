import 'package:grpc/service_api.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:jarvis_proto/jarvis.pbgrpc.dart';

class JarvisService extends JarvisServiceBase {
  final LlmService _llm;

  JarvisService(this._llm);

  @override
  Stream<ChatResponse> chat(ServiceCall call, ChatRequest request) async* {
    if (_llm.engine == null) {
      yield ChatResponse(text: 'Error: engine no inicializado');
      return;
    }

    final chat = await _llm.engine!.createChat();
    chat.addSystem('Eres un asistente breve y conciso. Responde en espanol.');
    chat.addUser(request.text);

    await for (final event in chat.generate(
      sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
      maxTokens: 4096,
    )) {
      if (event is TokenEvent) {
        yield ChatResponse(text: event.text);
      }
    }
  }
}

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
