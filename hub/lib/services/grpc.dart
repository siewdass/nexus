import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:nexus_grpc/nexus_grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'llm_service.dart';
import 'settings.dart';

class GrpcService extends NexusServiceBase {
  @override
  Stream<MessageResponse> message(
      ServiceCall call, MessageRequest request) async* {
    if (llmService.engine == null || llmService.modelConfig == null) {
      yield MessageResponse()..error = 'Engine no inicializado';
      return;
    }
    try {
      final cfg = llmService.modelConfig!;
      final prompt = cfg.promptFormat.build(cfg.systemPrompt, request.message);
      final session = await llmService.engine!.createSession();
      print('[LLM] modelo=${cfg.name} formato manual');

      var inThink = false;
      var buf = '';

      await for (final event in session.generate(
        prompt: prompt,
        addSpecial: true,
        parseSpecial: true,
        sampler: cfg.sampler,
        maxTokens: cfg.maxTokens,
      )) {
        if (event is TokenEvent) {
          stdout.write(event.text);
          stdout.flush();
          buf += event.text;
          if (cfg.thinkStart != null && cfg.thinkEnd != null) {
            final startTag = cfg.thinkStart!;
            final endTag = cfg.thinkEnd!;
            while (buf.isNotEmpty) {
              if (!inThink) {
                final idx = buf.indexOf(startTag);
                if (idx < 0) {
                  yield MessageResponse()..reply = buf;
                  buf = '';
                  break;
                }
                if (idx > 0) {
                  yield MessageResponse()..reply = buf.substring(0, idx);
                }
                buf = buf.substring(idx + startTag.length);
                inThink = true;
              } else {
                final idx = buf.indexOf(endTag);
                if (idx < 0) {
                  yield MessageResponse()..think = buf;
                  buf = '';
                  break;
                }
                if (idx > 0) {
                  yield MessageResponse()..think = buf.substring(0, idx);
                }
                buf = buf.substring(idx + endTag.length);
                inThink = false;
              }
            }
          } else {
            yield MessageResponse()..reply = buf;
            buf = '';
          }
        }
      }
      if (buf.isNotEmpty) {
        if (cfg.thinkStart != null && cfg.thinkEnd != null && inThink) {
          yield MessageResponse()..think = buf;
        } else {
          yield MessageResponse()..reply = buf;
        }
      }
      yield MessageResponse()..done = true;
    } catch (e, st) {
      print('Error en message: $e');
      print(st);
      yield MessageResponse()..error = 'Error: $e';
    }
  }

  @override
  Future<SettingsPayload> settingsFetch(
      ServiceCall call, SettingsFetchRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final tunnel = prefs.getBool('tunnel') ?? false;
    return SettingsPayload()..tunnel = tunnel;
  }

  @override
  Future<SettingsPatchResponse> settingsPatch(
      ServiceCall call, SettingsPayload request) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tunnel', request.tunnel);
    settingsService.setTunnel(request.tunnel);
    return SettingsPatchResponse()..success = true;
  }
}
