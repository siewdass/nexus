import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peer_rtc/peer_rtc.dart';
import 'package:uuid/uuid.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'llm_service.dart';
import 'package:nexus_hub/ai/provider.dart';
import 'package:nexus_hub/ai/agent.dart';
import 'api_tokens.dart';

enum PeerStatus { waiting, ping, answered, connected }

class PeerRTCService extends ChangeNotifier {
  final _uuid = const Uuid();
  late String _uuidValue;
  PeerStatus _status = PeerStatus.waiting;
  Peer? _peer;
  DataConnection? _connection;
  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  StreamSubscription<String?>? _peerOpenSub;
  StreamSubscription<DataConnection>? _peerConnSub;
  bool _initialized = false;
  String? _initError;
  String _peerId = '';

  String get uuid => _uuidValue;
  PeerStatus get status => _status;
  bool get isConnected =>
      _status == PeerStatus.answered || _status == PeerStatus.connected;
  bool get isInitialized => _initialized;
  String? get initError => _initError;
  String get peerId => _peerId;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _uuidValue = prefs.getString('hub_uuid') ?? _uuid.v4();
      await prefs.setString('hub_uuid', _uuidValue);

      debugPrint('[RTC] init hub uuid: $_uuidValue');

      // Create peer_rtc Peer
      _peer = Peer(
        options: PeerOptions(
          debug: LogLevel.Warnings,
        ),
      );

      _peerOpenSub = _peer!.onOpen.listen((id) {
        _peerId = id ?? '';
        debugPrint('[RTC] peer open: $_peerId');

        // Register in Firestore with peer ID
        FirebaseFirestore.instance
            .collection('connections')
            .doc(_uuidValue)
            .set({
          'status': 'waiting',
          'hub_uuid': _uuidValue,
          'peer_id': _peerId,
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      _peerConnSub = _peer!.onConnection.listen((conn) {
        debugPrint('[RTC] incoming connection from: ${conn.peer}');
        _connection?.close();
        _connection = null;
        _status = PeerStatus.waiting;
        notifyListeners();

        _connection = conn;
        _status = PeerStatus.connected;
        notifyListeners();

        conn.onData.listen((data) {
          debugPrint('[RTC] data: $data');
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (msg['type'] == 'chat' && msg['text'] != null) {
              _handleChat(msg['text'] as String);
            }
          } catch (e) {
            debugPrint('[RTC] failed to parse message: $e');
          }
        });

        conn.onOpen.listen((_) {
          debugPrint('[RTC] connection open');
          if (_connection == conn) notifyListeners();
        });

        conn.onClose.listen((_) {
          debugPrint('[RTC] connection closed');
          if (_connection == conn) {
            _status = PeerStatus.waiting;
            _connection = null;
            notifyListeners();
          }
        });
      });

      _initialized = true;
    } catch (e) {
      _initError = e.toString();
      _uuidValue = _uuid.v4();
      debugPrint('[RTC] init error: $e');
    }

    notifyListeners();
  }

  Future<void> _handleChat(String text) async {
    await _handleGroq(text, apiTokenService.groqToken!);
    return;
    // ignore_for_file: dead_code
    // local LLM code below kept intact for reference
    if (llmService.engine == null || llmService.modelConfig == null) {
      _connection?.send(jsonEncode({'type': 'error', 'text': 'Engine no inicializado'}));
      debugPrint('[LLM] engine not available');
      return;
    }
    EngineSession? session;
    try {
      final cfg = llmService.modelConfig!;
      final prompt = cfg.promptFormat.build(cfg.systemPrompt, text);
      session = await llmService.engine!.createSession();
      debugPrint('[LLM] modelo=${cfg.name} chat=$text');

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
            while (buf.isNotEmpty) {
              if (!inThink) {
                final idx = buf.indexOf(cfg.thinkStart!);
                if (idx < 0) {
                  _connection?.send(jsonEncode({'type': 'token', 'text': buf}));
                  buf = '';
                  break;
                }
                if (idx > 0) {
                  _connection?.send(jsonEncode({'type': 'token', 'text': buf.substring(0, idx)}));
                }
                buf = buf.substring(idx + cfg.thinkStart!.length);
                inThink = true;
              } else {
                final idx = buf.indexOf(cfg.thinkEnd!);
                if (idx < 0) {
                  _connection?.send(jsonEncode({'type': 'think', 'text': buf}));
                  buf = '';
                  break;
                }
                if (idx > 0) {
                  _connection?.send(jsonEncode({'type': 'think', 'text': buf.substring(0, idx)}));
                }
                buf = buf.substring(idx + cfg.thinkEnd!.length);
                inThink = false;
              }
            }
          } else {
            _connection?.send(jsonEncode({'type': 'token', 'text': buf}));
            buf = '';
          }
        }
      }
      if (buf.isNotEmpty) {
        if (cfg.thinkStart != null && cfg.thinkEnd != null && inThink) {
          _connection?.send(jsonEncode({'type': 'think', 'text': buf}));
        } else {
          _connection?.send(jsonEncode({'type': 'token', 'text': buf}));
        }
      }
      _connection?.send(jsonEncode({'type': 'done'}));
    } catch (e, st) {
      debugPrint('[LLM] error: $e\n$st');
      _connection?.send(jsonEncode({'type': 'error', 'text': 'Error: $e'}));
    } finally {
      try { await session?.dispose(); } catch (_) {}
    }
  }

  Future<void> _handleGroq(String text, String key) async {
    debugPrint('[GROQ] chat=$text');
    try {
      final provider = Provider.auto(apiKey: key, model: 'llama-3.3-70b-versatile');
      final agent = Agent(provider: provider, tools: []);
      final response = await agent.run(text);
      _connection?.send(jsonEncode({'type': 'token', 'text': response}));
      _connection?.send(jsonEncode({'type': 'done'}));
    } catch (e, st) {
      debugPrint('[GROQ] error: $e\n$st');
      _connection?.send(jsonEncode({'type': 'error', 'text': 'Error: $e'}));
    }
  }

  Future<void> sendMessage(Map<String, dynamic> data) async {
    if (_connection != null) {
      _connection!.send(data);
    }
  }

  @override
  void dispose() {
    _peerOpenSub?.cancel();
    _peerConnSub?.cancel();
    _firestoreSub?.cancel();
    _connection?.close();
    _peer?.dispose();
    super.dispose();
  }
}

final rtcService = PeerRTCService();
