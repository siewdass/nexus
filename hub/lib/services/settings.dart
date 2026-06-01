import 'package:flutter/foundation.dart';

class SettingsService extends ChangeNotifier {
  bool _tunnel = false;

  bool get tunnel => _tunnel;

  void setTunnel(bool v) {
    _tunnel = v;
    notifyListeners();
  }
}

final settingsService = SettingsService();
