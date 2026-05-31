import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../services/status.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Column(
        children: [
          DragToMoveArea(
            child: Container(
              height: 35,
              color: const Color(0xFF16213E),
              alignment: Alignment.center,
              child: Stack(
                children: [
                  const Center(
                    child: Text(
                      'Nexus Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Icon(Icons.settings, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: serviceStatus,
              builder: (context, _) {
                final s = serviceStatus;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('LLM', s.llm),
                      const SizedBox(height: 8),
                      _row('Server', s.server),
                      const SizedBox(height: 8),
                      _row('UDP', s.udp),
                      const SizedBox(height: 8),
                      _row('Tunnel', s.tunnel),
                      const SizedBox(height: 16),
                      if (s.privateIp.isNotEmpty)
                        Text('IP: ${s.privateIp}:5001',
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      if (s.publicUrl.isNotEmpty)
                        Text('Public: ${s.publicUrl}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
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

  Widget _row(String label, ServiceState state) {
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
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        const Spacer(),
        Text(state.name,
            style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
