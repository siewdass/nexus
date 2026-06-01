import 'package:flutter/foundation.dart';

class StateService extends ChangeNotifier {
  bool _llmReady = false;
  bool _grpcReady = false;
  String _privateIp = '';
  String? _publicUrl;
  String? _error;

  bool get llmReady => _llmReady;
  bool get grpcReady => _grpcReady;
  String get privateIp => _privateIp;
  String? get publicUrl => _publicUrl;
  String? get error => _error;

  void markLlmReady() {
    _llmReady = true;
    notifyListeners();
  }

  void markGrpcReady() {
    _grpcReady = true;
    notifyListeners();
  }

  void setPrivateIp(String v) {
    _privateIp = v;
    notifyListeners();
  }

  void setPublicUrl(String? v) {
    _publicUrl = v;
    notifyListeners();
  }

  void setError(String? v) {
    _error = v;
    notifyListeners();
  }
}

final hubState = StateService();
