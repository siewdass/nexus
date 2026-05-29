import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'theme_mode';

class ThemeService extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

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
    final value = prefs.getString(_key);
    if (value == 'dark') {
      _mode = ThemeMode.dark;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }

  ThemeData get _lightTheme => ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: _lightBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _lightSidebar,
          foregroundColor: _lightPrimaryText,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _green,
          foregroundColor: Colors.white,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _greenLight;
            return _lightInactive;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _greenLight.withValues(alpha: 0.5);
            }
            return _lightInactive.withValues(alpha: 0.5);
          }),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: _lightPrimaryText),
          bodySmall: TextStyle(color: _lightSecondaryText),
          titleMedium: TextStyle(color: _lightPrimaryText),
          titleLarge: TextStyle(color: _lightPrimaryText),
        ),
        colorScheme: const ColorScheme.light(
          primary: _green,
          secondary: _greenLight,
          surface: _lightBg,
          onSurface: _lightPrimaryText,
          onSecondary: _lightPrimaryText,
        ),
      );

  ThemeData get _darkTheme => ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: _darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _darkSidebar,
          foregroundColor: _darkPrimaryText,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _green,
          foregroundColor: Colors.white,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _greenDark;
            return _darkInactive;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _greenDark.withValues(alpha: 0.5);
            }
            return _darkInactive.withValues(alpha: 0.5);
          }),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: _darkPrimaryText),
          bodySmall: TextStyle(color: _darkSecondaryText),
          titleMedium: TextStyle(color: _darkPrimaryText),
          titleLarge: TextStyle(color: _darkPrimaryText),
        ),
        colorScheme: const ColorScheme.dark(
          primary: _green,
          secondary: _greenDark,
          surface: _darkBg,
          onSurface: _darkPrimaryText,
          onSecondary: _darkSecondaryText,
        ),
      );

  ThemeData get currentTheme => isDark ? _darkTheme : _lightTheme;
}
