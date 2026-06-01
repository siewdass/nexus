import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class PromptFormat {
  final String systemPrefix;
  final String systemSuffix;
  final String userPrefix;
  final String userSuffix;
  final String assistantPrefix;

  const PromptFormat({
    required this.systemPrefix,
    required this.systemSuffix,
    required this.userPrefix,
    required this.userSuffix,
    required this.assistantPrefix,
  });

  String build(String system, String user) =>
    '$systemPrefix$system$systemSuffix'
    '$userPrefix$user$userSuffix'
    '$assistantPrefix';
}

class ModelConfig {
  final String name;
  final String systemPrompt;
  final PromptFormat promptFormat;
  final SamplerParams sampler;
  final int maxTokens;
  final String? thinkStart;
  final String? thinkEnd;

  ModelConfig({
    required this.name,
    this.systemPrompt = 'Eres un asistente breve y conciso. Responde en espanol.',
    required this.promptFormat,
    SamplerParams? sampler,
    this.maxTokens = 4096,
    this.thinkStart,
    this.thinkEnd,
  }) : sampler = sampler ?? const SamplerParams(temperature: 0.7, topP: 0.9);
}

const _gemmaFormat = PromptFormat(
  systemPrefix: '<|turn>system\n',
  systemSuffix: '<turn|>\n',
  userPrefix: '<|turn>user\n',
  userSuffix: '<turn|>\n',
  assistantPrefix: '<|turn>model\n',
);

const _chatmlFormat = PromptFormat(
  systemPrefix: '<|im_start|>system\n',
  systemSuffix: '<|im_end|>\n',
  userPrefix: '<|im_start|>user\n',
  userSuffix: '<|im_end|>\n',
  assistantPrefix: '<|im_start|>assistant\n',
);

ModelConfig configForModel(String modelPath) {
  if (modelPath.contains('gemma') || modelPath.contains('Gemma')) {
    return ModelConfig(
      name: 'Gemma 4 E2B Q4',
      systemPrompt: 'Eres un asistente util. Responde en espanol.',
      promptFormat: _gemmaFormat,
      maxTokens: 4096,
      thinkStart: '<|channel>thought\n',
      thinkEnd: '\n<channel|>',
    );
  }
  return ModelConfig(
    name: 'Qwen 3 0.6B Q4',
    promptFormat: _chatmlFormat,
    thinkStart: '<think>',
    thinkEnd: '</think>',
  );
}

class LlmService {
  LlamaEngine? _engine;
  ModelConfig? _modelConfig;

  LlamaEngine? get engine => _engine;
  ModelConfig? get modelConfig => _modelConfig;

  Future<void> init({required String modelPath}) async {
    _modelConfig = configForModel(modelPath);
    LlamaLibrary.loadFromProcess();
    LlamaLog.captureToFile('/dev/null');
    _engine = await LlamaEngine.spawnFromProcess(
      modelParams: ModelParams(path: modelPath, gpuLayers: 99),
      contextParams: const ContextParams(nCtx: 4096),
    );
    print('[LLM] ${_modelConfig?.name} listo');
  }
}

final llmService = LlmService();
