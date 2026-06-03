import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peer_rtc/peer_rtc.dart';

enum LinkPeerStatus { idle, ping, answered, connected }

class PeerRTCClient extends ChangeNotifier {
  String? _uuid;
  Peer? _peer;
  DataConnection? _connection;
  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  StreamSubscription<String?>? _peerOpenSub;
  LinkPeerStatus _status = LinkPeerStatus.idle;

  final _tokenController = StreamController<String>.broadcast();
  final _thinkController = StreamController<String>.broadcast();
  final _doneController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get tokens => _tokenController.stream;
  Stream<String> get think => _thinkController.stream;
  Stream<void> get done => _doneController.stream;
  Stream<String> get errors => _errorController.stream;

  String? get uuid => _uuid;
  LinkPeerStatus get status => _status;
  bool get isConnected =>
      _status == LinkPeerStatus.answered ||
      _status == LinkPeerStatus.connected;

  Future<void> connect(String uuid) async {
    _uuid = uuid;
    _status = LinkPeerStatus.ping;
    notifyListeners();

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

      _connection = _peer!.connect(hubPeerId);

      _connection!.onOpen.listen((_) {
        debugPrint('[RTC_CLIENT] data channel open');
        _status = LinkPeerStatus.connected;
        notifyListeners();
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
          _doneController.add(null);
        case 'error':
          _errorController.add(msg['text'] as String? ?? 'Error desconocido');
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
    try {
      _connection!.send(jsonEncode({'type': 'chat', 'text': text}));
    } catch (e) {
      _errorController.add('Error al enviar: $e');
    }
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

  void disconnect() {
    _firestoreSub?.cancel();
    _peerOpenSub?.cancel();
    _connection?.close();
    _peer?.dispose();
    _peer = null;
    _connection = null;
    _uuid = null;
    _status = LinkPeerStatus.idle;
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
    super.dispose();
  }
}

final rtcClient = PeerRTCClient();
