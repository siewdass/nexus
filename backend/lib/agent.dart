import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'tools.dart';

const String _dylibDir = '../../libllama.dylib';
const String _modelPath = '../../Qwen3.5-0.8B-Q8.gguf';
const String _workspace = './workspace';

final _toolParen = RegExp(r'^\[TOOL\]\s*(\w+)\((.*)\)\s*$', multiLine: true);
final _toolSpace = RegExp(r'^\[TOOL\]\s*(\w+)[ \t]+(.+)$', multiLine: true);

String _systemPrompt(String ws) => '''You are an expert programmer with access to file tools.

AVAILABLE TOOLS:
- file_read(path) — Read a file from the workspace
- file_write(path, content) — Create or overwrite a file in the workspace
- file_list(path) — List files in the workspace directory (omit path to list root)
- file_delete(path) — Delete a file or directory

WORKSPACE: $ws

To use a tool, write exactly on its own line:
[TOOL] tool_name(arg1, arg2, ...)

Use positional arguments only (no name=value syntax).
After calling a tool, wait for the result and then continue.
When done, summarize what you did.''';

List<Map<String, String>> _parseToolCalls(String text) {
  final calls = <Map<String, String>>[];
  for (final m in _toolParen.allMatches(text)) {
    calls.add({'name': m.group(1)!, 'args': m.group(2)!.trim()});
  }
  for (final m in _toolSpace.allMatches(text)) {
    // Only add if not already matched by _toolParen
    if (!calls.any((c) => c['name'] == m.group(1)!)) {
      calls.add({'name': m.group(1)!, 'args': m.group(2)!.trim()});
    }
  }
  return calls;
}

String _stripKwPrefix(String s) {
  // If the arg looks like key=value or key="value", return just value
  final eq = s.indexOf('=');
  if (eq > 0 && eq < s.length - 1) return s.substring(eq + 1).trim();
  return s;
}

String _executeTool(FileTools tools, String name, String rawArgs) {
  // Parse comma-separated args, respecting simple quoting
  final args = <String>[];
  if (rawArgs.isNotEmpty) {
    var current = '';
    var inQuote = false;
    for (var i = 0; i < rawArgs.length; i++) {
      final c = rawArgs[i];
      if (c == '"' || c == "'") {
        inQuote = !inQuote;
      } else if (c == ',' && !inQuote) {
        args.add(_stripKwPrefix(current.trim()));
        current = '';
      } else {
        current += c;
      }
    }
    args.add(_stripKwPrefix(current.trim()));
  }

  try {
    switch (name) {
      case 'file_read':
        return tools.read(args[0]);
      case 'file_write':
        return tools.write(args[0], args.sublist(1).join(','));
      case 'file_list':
        return tools.listDir(args.isNotEmpty ? args[0] : '');
      case 'file_delete':
        return tools.delete(args[0]);
      default:
        return 'Unknown tool: $name';
    }
  } catch (e) {
    return 'Error executing $name: $e';
  }
}

Future<void> main() async {
  // Redirect C stderr to /dev/null to suppress llama.cpp logs
  LlamaLibrary.load(path: _dylibDir);
  LlamaLog.captureToFile('/dev/null');
  final engine = await LlamaEngine.spawn(
    libraryPath: _dylibDir,
    modelParams: ModelParams(path: _modelPath, gpuLayers: 99),
    contextParams: const ContextParams(nCtx: 4096),
  );

  final chat = await engine.createChat();
  chat.addSystem(_systemPrompt(_workspace));

  final tools = FileTools(_workspace);

  print('Agent ready. Type your prompt (Ctrl+C to exit).\n');
  stdout.write('> ');
  for (;;) {
    final input = stdin.readLineSync();
    if (input == null || input == '.exit') break;
    if (input.trim().isEmpty) {
      stdout.write('> ');
      continue;
    }

    chat.addUser(input);

    var fullResponse = '';
    stdout.write('\n');

    // Generate loop with tool support
    var done = false;
    while (!done) {
      await for (final event in chat.generate(
        sampler: const SamplerParams(temperature: 0.5, topP: 0.9),
        maxTokens: 2048,
      )) {
        switch (event) {
          case TokenEvent():
            stdout.write(event.text);
            fullResponse += event.text;
          case DoneEvent():
            print('\n');
            done = true;
          default:
            break;
        }
      }

      // Check for tool calls
      final toolCalls = _parseToolCalls(fullResponse);
      if (toolCalls.isEmpty) break;

      for (final tc in toolCalls) {
        final result = _executeTool(tools, tc['name']!, tc['args']!);
        print('  [Tool] ${tc['name']}(${tc['args']}) → $result\n');
        chat.addMessage(ChatMessage.tool(result));
      }

      fullResponse = '';
      done = false;
    }

    stdout.write('> ');
  }

  print('\nBye!');
}
