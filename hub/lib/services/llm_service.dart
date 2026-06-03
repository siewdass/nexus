import 'dart:async';
import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'state.dart';

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
  final String? quantization;
  final int? contextSize;
  final String systemPrompt;
  final PromptFormat promptFormat;
  final SamplerParams sampler;
  final int maxTokens;
  final String? thinkStart;
  final String? thinkEnd;
  int? fileSize;

  ModelConfig({
    required this.name,
    this.quantization,
    this.contextSize = 4096,
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
      name: 'Gemma 4 E2B',
      quantization: 'Q4_K_M',
      systemPrompt: 'Eres un asistente util. Responde en espanol.',
      promptFormat: _gemmaFormat,
      maxTokens: 4096,
      thinkStart: '<|channel>thought\n',
      thinkEnd: '\n<channel|>',
    );
  }
  return ModelConfig(
    name: 'Qwen 3 0.6B',
    quantization: 'Q4_K_M',
    promptFormat: _chatmlFormat,
    thinkStart: '<think>',
    thinkEnd: '</think>',
  );
}

class LlmService {
  LlamaEngine? _engine;
  ModelConfig? _modelConfig;
  Timer? _memTimer;

  LlamaEngine? get engine => _engine;
  ModelConfig? get modelConfig => _modelConfig;

  Future<void> init({required String modelPath}) async {
    _modelConfig = configForModel(modelPath);
    _modelConfig!.fileSize = File(modelPath).lengthSync();
    LlamaLibrary.loadFromProcess();
    LlamaLog.captureToFile('/dev/null');
    _engine = await LlamaEngine.spawnFromProcess(
      modelParams: ModelParams(path: modelPath, gpuLayers: 99),
      contextParams: ContextParams(nCtx: _modelConfig!.contextSize ?? 0),
    );
    _pollMemory();
    _memTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollMemory());
    print('[LLM] ${_modelConfig?.name} listo');
  }

  Future<void> _pollMemory() async {
    try {
      final r = await Process.run('vmmap', ['--summary', '$pid']);
      for (final line in (r.stdout as String).split('\n')) {
        if (line.startsWith('Physical footprint:')) {
          final bytes = _parseSize(line.split(':')[1].trim());
          hubState.setPhysicalBytes(bytes);
          break;
        }
      }
    } catch (_) {}
  }

  int _parseSize(String s) {
    s = s.trim().toUpperCase();
    if (s.endsWith('G')) return (double.parse(s.replaceAll('G', '')) * 1073741824).round();
    if (s.endsWith('M')) return (double.parse(s.replaceAll('M', '')) * 1048576).round();
    if (s.endsWith('K')) return (double.parse(s.replaceAll('K', '')) * 1024).round();
    return int.tryParse(s) ?? 0;
  }

  void dispose() {
    _memTimer?.cancel();
    _engine?.dispose();
  }
}

final llmService = LlmService();
