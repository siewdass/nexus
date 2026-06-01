import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../services/theme_service.dart';
import '../services/state.dart';
import '../services/settings.dart';
import '../widgets/system_stats.dart';
import 'settings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                  Expanded(
                    child: Center(
                      child: Text(
                        'Nexus Hub',
                        style: TextStyle(color: theme.primaryText, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.settings, color: theme.primaryText, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SystemStats(),
                  const SizedBox(height: 16),
                  _buildStatusCard(theme, 'LLM', context.watch<StateService>().llmReady),
                  const SizedBox(height: 8),
                  _buildStatusCard(theme, 'gRPC', context.watch<StateService>().grpcReady),
                  const SizedBox(height: 8),
                  _buildTunnelCard(theme, context.watch<SettingsService>().tunnel),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeService theme, String label, bool ready) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.inactiveBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle : Icons.hourglass_empty,
            color: ready ? theme.green : theme.secondaryText,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: theme.primaryText, fontSize: 12)),
          const Spacer(),
          Text(
            ready ? 'Ready' : 'Starting...',
            style: TextStyle(
              color: ready ? theme.green : theme.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTunnelCard(ThemeService theme, bool tunnel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.inactiveBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            tunnel ? Icons.cloud : Icons.cloud_off,
            color: tunnel ? theme.green : theme.secondaryText,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text('Tunnel', style: TextStyle(color: theme.primaryText, fontSize: 12)),
          const Spacer(),
          Text(
            tunnel ? 'Enabled' : 'Disabled',
            style: TextStyle(
              color: tunnel ? theme.green : theme.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
