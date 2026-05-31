import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../services/theme_service.dart';
import '../services/llm_service.dart';
import '../widgets/system_stats.dart';
import '../widgets/chat.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showSettings = false;

  Stream<String> _onChat(String text) async* {
    if (llmService.engine == null) {
      yield 'LLM no disponible';
      return;
    }
    try {
      final chat = await llmService.engine!.createChat();
      chat.addSystem('Eres un asistente breve y conciso. Responde en espanol.');
      chat.addUser(text);
      await for (final event in chat.generate(sampler: const SamplerParams(temperature: 0.7, topP: 0.9), maxTokens: 4096)) {
        if (event is TokenEvent) {
          yield event.text;
        }
      }
    } catch (e, st) {
      print('Error en chat: $e');
      print(st);
      yield 'Error: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Column(
        children: [
          DragToMoveArea(
            child: Container(
              height: 35,
              color: theme.sidebarBg,
              child: Row(
                children: [
                  const SizedBox(width: 70),
                  if (_showSettings)
                    GestureDetector(
                      onTap: () => setState(() => _showSettings = false),
                      child: Icon(Icons.arrow_back, color: theme.primaryText, size: 18),
                    ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _showSettings ? 'Nexus Hub - Settings' : 'Nexus Hub',
                        style: TextStyle(color: theme.primaryText, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (!_showSettings)
                    GestureDetector(
                      onTap: () => setState(() => _showSettings = true),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(Icons.settings, color: theme.primaryText, size: 18),
                      ),
                    ),
                  if (_showSettings) const SizedBox(width: 18 + 12),
                ],
              ),
            ),
          ),
          Expanded(
            child: _showSettings
                ? const SettingsBody()
                : ChatWidget(
                    header: Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      color: theme.scaffoldBg,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SystemStats(),
                          const SizedBox(height: 8),
                          Divider(height: 1, color: theme.inactiveBg),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    onSend: _onChat,
                  ),
          ),
        ],
      ),
    );
  }
}
