import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _key = 'theme_mode';

  static const _lightBg = Color(0xFFBAC7D5);
  static const _lightSidebar = Color(0xFFA5B6C9);
  static const _lightInactive = Color(0xFFDAE2EB);
  static const _lightPrimaryText = Color(0xFF4A5560);
  static const _lightSecondaryText = Color(0xFF73808E);
  static const _green = Color(0xFF34B77A);
  static const _greenLight = Color(0xFF5AC88C);

  static const _darkBg = Color(0xFF1A222D);
  static const _darkSidebar = Color(0xFF222B38);
  static const _darkInactive = Color(0xFF303A4A);
  static const _darkPrimaryText = Color(0xFFF0F4F8);
  static const _darkSecondaryText = Color(0xFFA0B2C0);
  static const _greenDark = Color(0xFF42BD82);
  static const _red = Color(0xFFBE2828);

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Color get scaffoldBg => isDark ? _darkBg : _lightBg;
  Color get sidebarBg => isDark ? _darkSidebar : _lightSidebar;
  Color get inactiveBg => isDark ? _darkInactive : _lightInactive;
  Color get primaryText => isDark ? _darkPrimaryText : _lightPrimaryText;
  Color get secondaryText => isDark ? _darkSecondaryText : _lightSecondaryText;
  Color get green => _green;
  Color get greenLight => isDark ? _greenDark : _greenLight;
  Color get debugRed => _red;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    if (val == 'dark') {
      _mode = ThemeMode.dark;
      notifyListeners();
    }
  }

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setString(_key, _mode.name));
  }

  ThemeData get currentTheme => isDark ? _darkTheme : _lightTheme;

  ThemeData get _lightTheme => ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: _lightBg,
    appBarTheme: AppBarTheme(
      backgroundColor: _lightSidebar,
      foregroundColor: _lightPrimaryText,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _green,
      foregroundColor: _lightPrimaryText,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _greenLight;
        return _lightInactive;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _green;
        return _lightPrimaryText;
      }),
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: _lightPrimaryText),
    ),
    colorScheme: ColorScheme.light(
      primary: _green,
      secondary: _lightSecondaryText,
    ),
  );

  ThemeData get _darkTheme => ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: _darkBg,
    appBarTheme: AppBarTheme(
      backgroundColor: _darkSidebar,
      foregroundColor: _darkPrimaryText,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _greenDark,
      foregroundColor: _darkPrimaryText,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _greenDark;
        return _darkInactive;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _greenDark;
        return _darkSecondaryText;
      }),
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: _darkPrimaryText),
    ),
    colorScheme: ColorScheme.dark(
      primary: _greenDark,
      secondary: _darkSecondaryText,
    ),
  );
}
