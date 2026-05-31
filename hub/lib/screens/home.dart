import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../services/status.dart';
import '../services/theme_service.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
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
                  if (_showSettings)
                    GestureDetector(
                      onTap: () => setState(() => _showSettings = false),
                      child: Icon(Icons.arrow_back, color: theme.primaryText, size: 18),
                    ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _showSettings ? 'Nexus Hub - Settings' : 'Nexus Hub',
                        style: TextStyle(
                          color: theme.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (!_showSettings)
                    GestureDetector(
                      onTap: () => setState(() => _showSettings = true),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(Icons.settings, color: theme.primaryText, size: 18),
                      ),
                    ),
                  if (_showSettings)
                    const SizedBox(width: 18 + 12),
                ],
              ),
            ),
          ),
          Expanded(
            child: _showSettings
                ? const SettingsBody()
                : ListenableBuilder(
                    listenable: serviceStatus,
                    builder: (context, _) {
                      final s = serviceStatus;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _row(theme, 'LLM', s.llm),
                            const SizedBox(height: 8),
                            _row(theme, 'Server', s.server),
                            const SizedBox(height: 8),
                            _row(theme, 'UDP', s.udp),
                            const SizedBox(height: 8),
                            _row(theme, 'Tunnel', s.tunnel),
                            const SizedBox(height: 16),
                            if (s.privateIp.isNotEmpty)
                              Text('IP: ${s.privateIp}:5001',
                                  style: TextStyle(color: theme.secondaryText, fontSize: 12)),
                            if (s.publicUrl.isNotEmpty)
                              Text('Public: ${s.publicUrl}',
                                  style: TextStyle(color: theme.secondaryText, fontSize: 12)),
                            if (s.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(s.error!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeService theme, String label, ServiceState state) {
    final icon = switch (state) {
      ServiceState.starting => Icons.sync,
      ServiceState.ready => Icons.check_circle,
      ServiceState.error => Icons.error,
    };
    final color = switch (state) {
      ServiceState.starting => Colors.yellowAccent,
      ServiceState.ready => Colors.greenAccent,
      ServiceState.error => Colors.redAccent,
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: theme.primaryText, fontSize: 13)),
        const Spacer(),
        Text(state.name,
            style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
