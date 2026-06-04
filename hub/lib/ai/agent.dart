import 'package:langchain/langchain.dart' hide Tool;
import 'provider.dart';
import 'tool.dart';

class Agent {
  final Provider provider;
  final List<Tool> tools;
  final String? systemPrompt;

  Agent({
    required this.provider,
    required this.tools,
    this.systemPrompt,
  });

  Future<String> run(String prompt) async {
    final messages = <ChatMessage>[];
    if (systemPrompt != null) {
      messages.add(ChatMessage.system(systemPrompt!));
    }
    messages.add(ChatMessage.humanText(prompt));

    final model = provider.build(
      tools: tools.map((t) => t.spec).toList(),
    );

    for (var i = 0; i < 10; i++) {
      final result = await model.invoke(PromptValue.chat(messages));
      final msg = result.output;

      if (msg.toolCalls.isEmpty) {
        return msg.content;
      }

      messages.add(msg);

      for (final tc in msg.toolCalls) {
        final tool = tools.firstWhere((t) => t.name == tc.name);
        final toolResult = await tool.execute(tc.arguments);
        messages.add(ChatMessage.tool(
          toolCallId: tc.id,
          content: toolResult,
        ));
      }
    }

    return 'Max iterations reached';
  }

  Stream<String> runStream(String prompt) async* {
    final messages = <ChatMessage>[];
    if (systemPrompt != null) {
      messages.add(ChatMessage.system(systemPrompt!));
    }
    messages.add(ChatMessage.humanText(prompt));

    final model = provider.build(
      tools: tools.map((t) => t.spec).toList(),
    );

    for (var i = 0; i < 10; i++) {
      final result = await model.invoke(PromptValue.chat(messages));
      final msg = result.output;

      if (msg.toolCalls.isEmpty) {
        yield msg.content;
        return;
      }

      messages.add(msg);

      for (final tc in msg.toolCalls) {
        final tool = tools.firstWhere((t) => t.name == tc.name);
        final toolResult = await tool.execute(tc.arguments);
        messages.add(ChatMessage.tool(
          toolCallId: tc.id,
          content: toolResult,
        ));
      }
    }

    yield 'Max iterations reached';
  }
}
