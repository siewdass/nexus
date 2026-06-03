import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/theme_service.dart';
import '../services/state.dart';
import '../services/rtc_service.dart';
import '../widgets/system_stats.dart';
import 'settings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final state = context.watch<StateService>();
    final rtc = context.watch<PeerRTCService>();
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
                  Row(
                    children: [
                      _statusCard(theme, Icons.psychology, 'Agent', state.llmReady),
                      const SizedBox(width: 8),
                      _statusCard(theme, Icons.lan, 'Network', state.grpcReady),
                      const SizedBox(width: 8),
                      _statusCard(theme, Icons.cloud, 'Tunnel', state.tunnelReady),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (rtc.isInitialized && rtc.uuid.isNotEmpty)
                    _qrCard(theme, rtc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(ThemeService theme, IconData icon, String label, bool ready) {
    final color = ready ? theme.green : theme.secondaryText;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.inactiveBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: theme.primaryText, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _qrCard(ThemeService theme, PeerRTCService rtc) {
    final statusLabel = switch (rtc.status) {
      PeerStatus.waiting => 'Esperando...',
      PeerStatus.ping => 'Conectando...',
      PeerStatus.answered => 'Conectado',
      PeerStatus.connected => 'Conectado',
    };
    final statusColor = rtc.isConnected ? theme.green : theme.secondaryText;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.inactiveBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          QrImageView(
            data: rtc.uuid,
            version: QrVersions.auto,
            size: 72,
            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: theme.primaryText),
            dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: theme.primaryText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Vinculación', style: TextStyle(color: theme.primaryText, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${rtc.uuid.substring(0, 8)}...', style: TextStyle(color: theme.secondaryText, fontSize: 10, fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
