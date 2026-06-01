import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../services/theme_service.dart';
import '../services/settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final settings = context.watch<SettingsService>();
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Column(
        children: [
          DragToMoveArea(
            child: Container(
              height: 35,
              color: theme.sidebarBg,
              child: Row(
                children: [
                  const SizedBox(width: 70),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Nexus Hub - Settings',
                        style: TextStyle(color: theme.primaryText, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.save, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: theme.inactiveBg,
                    child: SwitchListTile(
                      title: Text('Theme',
                          style: TextStyle(color: theme.primaryText)),
                      subtitle: Text('Light / Dark',
                          style: TextStyle(color: theme.secondaryText)),
                      value: theme.isDark,
                      activeTrackColor: theme.green,
                      onChanged: (_) => theme.toggle(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: theme.inactiveBg,
                    child: SwitchListTile(
                      title: Text('Tunnel',
                          style: TextStyle(color: theme.primaryText)),
                      subtitle: Text('Cloudflare tunnel',
                          style: TextStyle(color: theme.secondaryText)),
                      value: settings.tunnel,
                      activeTrackColor: theme.green,
                      onChanged: (v) => settings.setTunnel(v),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
