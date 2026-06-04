import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

enum ProviderType { groq, mistral }

class Provider {
  final String apiKey;
  final String model;
  final ProviderType type;

  const Provider({
    required this.apiKey,
    required this.model,
    required this.type,
  });

  factory Provider.auto({required String apiKey, required String model}) {
    return Provider(apiKey: apiKey, model: model, type: _detect(apiKey));
  }

  static ProviderType _detect(String key) {
    if (key.startsWith('gsk_')) return ProviderType.groq;
    return ProviderType.mistral;
  }

  Runnable<PromptValue, ChatModelOptions, ChatResult> build({
    List<ToolSpec> tools = const [],
  }) {
    switch (type) {
      case ProviderType.groq:
        return ChatOpenAI(
          apiKey: apiKey,
          baseUrl: 'https://api.groq.com/openai/v1',
          defaultOptions: ChatOpenAIOptions(
            model: model,
            tools: tools.isEmpty ? null : tools,
          ),
        );
      case ProviderType.mistral:
        return ChatOpenAI(
          apiKey: apiKey,
          baseUrl: 'https://api.mistral.ai/v1',
          defaultOptions: ChatOpenAIOptions(
            model: model,
            tools: tools.isEmpty ? null : tools,
          ),
        );
    }
  }
}
