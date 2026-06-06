import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peer_rtc/peer_rtc.dart';
import 'package:uuid/uuid.dart';

import 'package:nexus_hub/ai/provider.dart';
import 'package:nexus_hub/ai/agent.dart';
import 'package:nexus_hub/ai/tool.dart';
import 'package:nexus_hub/ai/mistral.dart';
import 'api_tokens.dart';
import 'database.dart';

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
          autoReconnect: true,
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
            switch (msg['type'] as String?) {
              case 'chat':
                if (msg['text'] != null) _handleChat(msg['text'] as String);
              case 'list_tasks':
                _handleListTasks();
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
    debugPrint('[RTC] _handleChat text="$text"');
    final key = apiTokenService.mistralToken;
    if (key == null) {
      debugPrint('[MISTRAL] ERROR: mistralToken is null');
      _connection?.send(jsonEncode({'type': 'error', 'text': 'Mistral key no encontrada'}));
      return;
    }
    debugPrint('[RTC] calling _handleMistral');
    await _handleMistral(text, key);
    debugPrint('[RTC] _handleMistral completed');
  }

  Future<void> _handleMistral(String text, String key) async {
    debugPrint('[MISTRAL] start chat=$text model=$mistralModel');
    List<Map<String, dynamic>> beforeTasks;
    try {
      beforeTasks = await _getAllTasks();
      debugPrint('[MISTRAL] beforeTasks count=${beforeTasks.length}');
    } catch (e) {
      debugPrint('[MISTRAL] beforeTasks error: $e');
      beforeTasks = [];
    }

    try {
      debugPrint('[MISTRAL] creating provider...');
      final provider = Provider.auto(apiKey: key, model: mistralModel);
      debugPrint('[MISTRAL] creating agent...');
      final agent = Agent(
        provider: provider,
        tools: [
          createTaskTool, updateTaskTool, listTasksTool, deleteTaskTool,
          createCriteriaTool, updateCriteriaTool, deleteCriteriaTool, listCriteriaTool,
        ],
        systemPrompt: mistralSystemPrompt,
      );
      debugPrint('[MISTRAL] calling agent.run()...');
      final response = await agent.run(text);
      debugPrint('[MISTRAL] agent.run() ok, response length=${response.length}');
      _connection?.send(jsonEncode({'type': 'token', 'text': response}));
      _connection?.send(jsonEncode({'type': 'done'}));
      debugPrint('[MISTRAL] response sent to link');
    } catch (e, st) {
      debugPrint('[MISTRAL] ERROR: $e\n$st');
      _connection?.send(jsonEncode({'type': 'error', 'text': 'Error: $e'}));
    }

    List<Map<String, dynamic>> afterTasks;
    try {
      afterTasks = await _getAllTasks();
      debugPrint('[MISTRAL] afterTasks count=${afterTasks.length}');
    } catch (e) {
      debugPrint('[MISTRAL] afterTasks error: $e');
      afterTasks = [];
    }

    _sendTaskDiff(beforeTasks, afterTasks);
    debugPrint('[MISTRAL] task diff sent');
  }

  Future<void> _handleListTasks() async {
    try {
      final tasks = await _getAllTasks();
      _connection?.send(jsonEncode({'type': 'tasks', 'data': tasks}));
    } catch (e) {
      debugPrint('[RTC] list_tasks error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getAllTasks() async {
    final result = await databaseService.read('tasks', {}, many: true);
    final tasks = (result as List).cast<Map<String, dynamic>>();
    for (final task in tasks) {
      final taskId = task['id'] as String;
      final criteria = await databaseService.read('criteria', {'task_id': taskId}, many: true) as List;
      task['criteria'] = criteria;
      debugPrint('[TASKS] task $taskId has ${criteria.length} criteria');
    }
    return tasks;
  }

  void _sendTaskDiff(List<Map<String, dynamic>> before, List<Map<String, dynamic>> after) {
    final beforeIds = before.map((t) => t['id'] as String).toSet();
    final afterIds = after.map((t) => t['id'] as String).toSet();
    final beforeMap = {for (final t in before) t['id'] as String: t};

    for (final task in after) {
      final id = task['id'] as String;
      if (!beforeIds.contains(id)) {
        _connection?.send(jsonEncode({'type': 'task_added', 'data': task}));
      } else {
        final old = beforeMap[id];
        if (old != null && _mapsDiffer(old, task)) {
          _connection?.send(jsonEncode({'type': 'task_updated', 'data': task}));
        }
      }
    }

    for (final task in before) {
      if (!afterIds.contains(task['id'] as String)) {
        _connection?.send(jsonEncode({'type': 'task_removed', 'data': {'id': task['id']}}));
      }
    }
  }

  bool _mapsDiffer(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return true;
    for (final key in a.keys) {
      if (a[key] != b[key]) return true;
    }
    return false;
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
