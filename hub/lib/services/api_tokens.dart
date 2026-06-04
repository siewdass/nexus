import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiTokenService extends ChangeNotifier {
  static const _keyGroq = 'api_groq_key';
  static const _keyMistral = 'api_mistral_key';
  static const _keyGoogle = 'api_google_key';
  static const _keyReady = 'api_ready';

  String? _groq;
  String? _mistral;
  String? _google;
  bool _ready = false;

  String? get groqToken => _groq;
  String? get mistralToken => _mistral;
  String? get googleToken => _google;
  bool get hasTokens => _groq != null || _mistral != null || _google != null;
  bool get ready => _ready;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _groq = prefs.getString(_keyGroq);
    _mistral = prefs.getString(_keyMistral);
    _google = prefs.getString(_keyGoogle);
    _ready = prefs.getBool(_keyReady) ?? false;
    notifyListeners();
  }

  Future<void> save({
    String? groq,
    String? mistral,
    String? google,
  }) async {
    _groq = groq;
    _mistral = mistral;
    _google = google;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      if (groq != null) prefs.setString(_keyGroq, groq),
      if (mistral != null) prefs.setString(_keyMistral, mistral),
      if (google != null) prefs.setString(_keyGoogle, google),
    ]);
    notifyListeners();
  }

  Future<void> markReady() async {
    _ready = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReady, true);
    notifyListeners();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyGroq),
      prefs.remove(_keyMistral),
      prefs.remove(_keyGoogle),
      prefs.remove(_keyReady),
    ]);
    _groq = null;
    _mistral = null;
    _google = null;
    _ready = false;
    notifyListeners();
  }
}

final apiTokenService = ApiTokenService();
