import 'package:flutter/foundation.dart';

enum ServiceState { starting, ready, error }

class ServiceStatus extends ChangeNotifier {
  ServiceState _llm = ServiceState.starting;
  ServiceState _server = ServiceState.starting;
  ServiceState _udp = ServiceState.starting;
  ServiceState _tunnel = ServiceState.starting;
  String _privateIp = '';
  String _publicUrl = '';
  String? _error;

  ServiceState get llm => _llm;
  ServiceState get server => _server;
  ServiceState get udp => _udp;
  ServiceState get tunnel => _tunnel;
  String get privateIp => _privateIp;
  String get publicUrl => _publicUrl;
  String? get error => _error;

  void setLlmReady() { _llm = ServiceState.ready; notifyListeners(); }
  void setLlmError(String e) { _llm = ServiceState.error; _error = e; notifyListeners(); }
  void setServerReady() { _server = ServiceState.ready; notifyListeners(); }
  void setServerError(String e) { _server = ServiceState.error; _error = e; notifyListeners(); }
  void setUdpReady() { _udp = ServiceState.ready; notifyListeners(); }
  void setPrivateIp(String ip) { _privateIp = ip; notifyListeners(); }
  void setPublicUrl(String url) { _publicUrl = url; _tunnel = ServiceState.ready; notifyListeners(); }
  void setTunnelError(String e) { _tunnel = ServiceState.error; _error = e; notifyListeners(); }
}

final serviceStatus = ServiceStatus();
