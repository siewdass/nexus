import 'package:flutter/foundation.dart';

class StateService extends ChangeNotifier {
  bool _llmReady = false;
  bool _grpcReady = false;
  bool _tunnelReady = false;
  String _privateIp = '';
  String? _publicUrl;
  String? _error;
  double _downloadProgress = 0.0;
  String _downloadStatus = 'idle';

  bool get llmReady => _llmReady;
  bool get grpcReady => _grpcReady;
  bool get tunnelReady => _tunnelReady;
  String get privateIp => _privateIp;
  String? get publicUrl => _publicUrl;
  String? get error => _error;
  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;

  void markLlmReady() {
    _llmReady = true;
    notifyListeners();
  }

  void markGrpcReady() {
    _grpcReady = true;
    notifyListeners();
  }

  void markTunnelReady() {
    _tunnelReady = true;
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

  void setDownloadProgress(double v) {
    _downloadProgress = v;
    _downloadStatus = 'downloading';
    notifyListeners();
  }

  void setDownloadComplete() {
    _downloadProgress = 1.0;
    _downloadStatus = 'ready';
    notifyListeners();
  }

  void setDownloadError(String msg) {
    _downloadStatus = 'error';
    _error = msg;
    notifyListeners();
  }
}

final hubState = StateService();
