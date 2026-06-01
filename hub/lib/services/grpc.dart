import 'dart:async';

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
    if (llmService.engine == null) {
      yield MessageResponse()..error = 'Engine no inicializado';
      return;
    }
    try {
      final chat = await llmService.engine!.createChat();
      chat.addSystem('Eres un asistente breve y conciso. Responde en espanol.');
      chat.addUser(request.message);

      var inThink = false;
      var buf = '';

      await for (final event in chat.generate(
        sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
        maxTokens: 4096,
      )) {
        if (event is TokenEvent) {
          buf += event.text;
          while (buf.isNotEmpty) {
            if (!inThink) {
              final idx = buf.indexOf('<think>');
              if (idx < 0) {
                yield MessageResponse()..reply = buf;
                buf = '';
                break;
              }
              if (idx > 0) {
                yield MessageResponse()..reply = buf.substring(0, idx);
              }
              buf = buf.substring(idx + 7);
              inThink = true;
            } else {
              final idx = buf.indexOf('</think>');
              if (idx < 0) {
                yield MessageResponse()..think = buf;
                buf = '';
                break;
              }
              if (idx > 0) {
                yield MessageResponse()..think = buf.substring(0, idx);
              }
              buf = buf.substring(idx + 8);
              inThink = false;
            }
          }
        }
      }
      if (buf.isNotEmpty) {
        if (inThink) {
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
