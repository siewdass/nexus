import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness:
              theme.isDark ? Brightness.light : Brightness.dark,
          statusBarColor: theme.sidebarBg,
        ),
        title: const Text('Settings'),
        backgroundColor: theme.sidebarBg,
        foregroundColor: theme.primaryText,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.inactiveBg,
            child: SwitchListTile(
              title: Text(
                'Modo oscuro',
                style: TextStyle(color: theme.primaryText),
              ),
              subtitle: Text(
                'Cambiar entre tema claro y oscuro',
                style: TextStyle(color: theme.secondaryText),
              ),
              value: theme.isDark,
              activeTrackColor: theme.green,
              onChanged: (_) => theme.toggle(),
            ),
          ),
        ],
      ),
    );
  }
}
