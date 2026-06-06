import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peer_rtc/peer_rtc.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

enum LinkPeerStatus { idle, finding, connecting, connected }

class PeerRTCClient extends ChangeNotifier {
  String? _uuid;
  Peer? _peer;
  DataConnection? _connection;
  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  StreamSubscription<String?>? _peerOpenSub;
  LinkPeerStatus _status = LinkPeerStatus.idle;
  bool _reconnecting = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 10;

  final _tokenController = StreamController<String>.broadcast();
  final _thinkController = StreamController<String>.broadcast();
  final _doneController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _tasksController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _taskAddedController = StreamController<Map<String, dynamic>>.broadcast();
  final _taskUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _taskRemovedController = StreamController<Map<String, dynamic>>.broadcast();
  bool _pendingChat = false;

  Stream<String> get tokens => _tokenController.stream;
  Stream<String> get think => _thinkController.stream;
  Stream<void> get done => _doneController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<List<Map<String, dynamic>>> get tasks => _tasksController.stream;
  Stream<Map<String, dynamic>> get taskAdded => _taskAddedController.stream;
  Stream<Map<String, dynamic>> get taskUpdated => _taskUpdatedController.stream;
  Stream<Map<String, dynamic>> get taskRemoved => _taskRemovedController.stream;

  String? get uuid => _uuid;
  LinkPeerStatus get status => _status;
  bool get isConnected => _status == LinkPeerStatus.connected;

  Future<void> connect(String uuid) async {
    _uuid = uuid;
    _status = LinkPeerStatus.finding;
    notifyListeners();
    _updateNotification('Buscando Hub...');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hub_uuid', uuid);
    debugPrint('[RTC_CLIENT] connecting to hub: $uuid');

    try {
      await FirebaseFirestore.instance
          .collection('connections')
          .doc(uuid)
          .update({'status': 'ping'});

      _peer = Peer(
        options: PeerOptions(debug: LogLevel.Warnings),
      );

      _peerOpenSub = _peer!.onOpen.listen((_) {
        _connectToHub(uuid);
      });
    } catch (e, st) {
      debugPrint('[RTC_CLIENT] connect error: $e\n$st');
      _errorController.add('Conexión: $e');
    }
  }

  Future<void> _connectToHub(String uuid) async {
    if (_connection != null) {
      debugPrint('[RTC_CLIENT] already connected, skipping _connectToHub');
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('connections')
          .doc(uuid)
          .get();

      if (!snap.exists) {
        _errorController.add('Hub no encontrado');
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      final hubPeerId = data['peer_id'] as String?;

      if (hubPeerId == null || hubPeerId.isEmpty) {
        debugPrint('[RTC_CLIENT] hub peer_id not ready, retrying...');
        Future.delayed(
          const Duration(seconds: 2),
          () => _connectToHub(uuid),
        );
        return;
      }

      debugPrint('[RTC_CLIENT] hub peer_id: $hubPeerId');
      _status = LinkPeerStatus.connecting;
      notifyListeners();
      _updateNotification('Conectando al Hub...');

      _connection?.close();
      _connection = _peer!.connect(hubPeerId);

      _connection!.onOpen.listen((_) {
        debugPrint('[RTC_CLIENT] data channel open');
        _status = LinkPeerStatus.connected;
        notifyListeners();
        _updateNotification('Conectado');
      });

      _connection!.onData.listen((data) {
        debugPrint('[RTC_CLIENT] data: $data');
        _handleData(data);
      });

      _connection!.onClose.listen((_) {
        debugPrint('[RTC_CLIENT] connection closed');
        _status = LinkPeerStatus.idle;
        _connection = null;
        notifyListeners();
        if (_pendingChat) {
          _pendingChat = false;
          _errorController.add('Conexión perdida con el hub');
        }
        _updateNotification('Reconectando...');
        _autoReconnect();
      });
    } catch (e, st) {
      debugPrint('[RTC_CLIENT] connect to hub error: $e\n$st');
      _errorController.add('Conexión WebRTC: $e');
    }
  }

  void _handleData(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      switch (msg['type'] as String?) {
        case 'token':
          _tokenController.add(msg['text'] as String);
        case 'think':
          _thinkController.add(msg['text'] as String);
        case 'done':
          _pendingChat = false;
          _doneController.add(null);
        case 'error':
          _pendingChat = false;
          _errorController.add(msg['text'] as String? ?? 'Error desconocido');
        case 'tasks':
          _tasksController.add((msg['data'] as List).cast<Map<String, dynamic>>());
        case 'task_added':
          _taskAddedController.add(Map<String, dynamic>.from(msg['data']));
        case 'task_updated':
          _taskUpdatedController.add(Map<String, dynamic>.from(msg['data']));
        case 'task_removed':
          _taskRemovedController.add(Map<String, dynamic>.from(msg['data']));
      }
    } catch (e) {
      debugPrint('[RTC_CLIENT] failed to parse: $e');
    }
  }

  Future<void> sendChat(String text) async {
    if (_connection == null) {
      _errorController.add('No conectado');
      return;
    }
    _pendingChat = true;
    try {
      _connection!.send(jsonEncode({'type': 'chat', 'text': text}));
    } catch (e) {
      _pendingChat = false;
      _errorController.add('Error al enviar: $e');
    }
  }

  Future<void> sendListTasks() async {
    if (_connection == null) return;
    try {
      _connection!.send(jsonEncode({'type': 'list_tasks'}));
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    if (_connection == null) {
      _errorController.add('No conectado');
      return;
    }
    try {
      _connection!.send(text);
    } catch (e) {
      _errorController.add('Error al enviar: $e');
    }
  }

  void _autoReconnect() async {
    if (_reconnecting || _uuid == null) return;
    _reconnecting = true;
    _reconnectAttempts = 0;

    while (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      await Future.delayed(const Duration(seconds: 3));
      if (_connection != null || _uuid == null) break;
      debugPrint('[RTC_CLIENT] reconnect attempt $_reconnectAttempts');
      try {
        await _connectToHub(_uuid!);
        if (_connection != null) break;
      } catch (_) {}
    }
    _reconnecting = false;
    _reconnectAttempts = 0;
    if (_connection == null) {
      _updateNotification('Escuchando...');
    }
  }

  void _updateNotification(String content) {
    try {
      FlutterBackgroundService().invoke('updateNotification', {
        'title': 'Nexus Link',
        'content': content,
      });
    } catch (_) {}
  }

  void disconnect() {
    _reconnecting = false;
    _pendingChat = false;
    _firestoreSub?.cancel();
    _peerOpenSub?.cancel();
    _connection?.close();
    _peer?.dispose();
    _peer = null;
    _connection = null;
    _uuid = null;
    _status = LinkPeerStatus.idle;
    _reconnectAttempts = 0;
    _reconnecting = false;
    _updateNotification('Escuchando...');
    notifyListeners();
  }

  Future<void> clearSavedUuid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hub_uuid');
    _uuid = null;
  }

  @override
  void dispose() {
    disconnect();
    _tokenController.close();
    _thinkController.close();
    _doneController.close();
    _errorController.close();
    _tasksController.close();
    _taskAddedController.close();
    _taskUpdatedController.close();
    _taskRemovedController.close();
    super.dispose();
  }
}

final rtcClient = PeerRTCClient();
