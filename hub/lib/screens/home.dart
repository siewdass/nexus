import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
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
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _statusColumn(theme, state),
                        ),
                        const SizedBox(width: 12),
                        if (rtc.isInitialized && rtc.uuid.isNotEmpty)
                          Expanded(
                            child: _qrCard(theme, rtc),
                          ),
                      ],
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

  Widget _statusColumn(ThemeService theme, StateService state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _agentRow(theme, state),
      ],
    );
  }

  Widget _agentRow(ThemeService theme, StateService state) {
    // final cfg = llmService.modelConfig;
    // final modelName = cfg?.name ?? 'Loading...';
    // final quant = cfg?.quantization;
    // final ctx = cfg?.contextSize;
    // final size = cfg?.fileSize;
    // final mem = state.physicalBytes;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.inactiveBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Row(
            //   children: [
            //     AppIcon(size: 16),
            //     const SizedBox(width: 8),
            //     Text('Agent', style: TextStyle(color: theme.primaryText, fontSize: 11, fontWeight: FontWeight.w600)),
            //   ],
            // ),
            // const SizedBox(height: 4),
            // _infoRow(theme, 'Model:', modelName),
            // if (quant != null) _infoRow(theme, 'Quantized:', quant),
            // if (ctx != null) _infoRow(theme, 'Context:', _compact(ctx)),
            // _infoRow(theme, 'Size:', _formatGB(size ?? 0)),
            // _infoRow(theme, 'RAM:', _formatGB(mem ?? 0)),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gaugeSize = (constraints.biggest.shortestSide - 8).clamp(80.0, 500.0);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: gaugeSize,
                          height: gaugeSize,
                          child: SfRadialGauge(
                            axes: [
                              RadialAxis(
                                minimum: 0, maximum: 100,
                                showLabels: false, showTicks: false,
                                startAngle: 270, endAngle: 270,
                                radiusFactor: 0.88,
                                axisLineStyle: AxisLineStyle(thickness: 8, color: theme.scaffoldBg),
                                pointers: [RangePointer(value: 88, width: 8, cornerStyle: CornerStyle.bothCurve, enableAnimation: true, color: theme.primaryText)],
                              ),
                              RadialAxis(
                                minimum: 0, maximum: 100,
                                showLabels: false, showTicks: false,
                                startAngle: 270, endAngle: 270,
                                radiusFactor: 0.66,
                                axisLineStyle: AxisLineStyle(thickness: 8, color: theme.scaffoldBg),
                                pointers: [RangePointer(value: 42, width: 8, cornerStyle: CornerStyle.bothCurve, enableAnimation: true, color: theme.primaryText)],
                              ),
                              RadialAxis(
                                minimum: 0, maximum: 100,
                                showLabels: false, showTicks: false,
                                startAngle: 270, endAngle: 270,
                                radiusFactor: 0.44,
                                axisLineStyle: AxisLineStyle(thickness: 8, color: theme.scaffoldBg),
                                pointers: [RangePointer(value: 67, width: 8, cornerStyle: CornerStyle.bothCurve, enableAnimation: true, color: theme.primaryText)],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Groq - Mistral - Google',
                            style: TextStyle(color: theme.primaryText, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qrCard(ThemeService theme, PeerRTCService rtc) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.inactiveBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final qrSize = (constraints.biggest.shortestSide - 32).clamp(80.0, 500.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              QrImageView(
                data: rtc.uuid,
                version: QrVersions.auto,
                size: qrSize,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: theme.primaryText),
                dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: theme.primaryText),
              ),
              const SizedBox(height: 8),
              _linkStatusRow(theme, rtc),
            ],
          );
        },
      ),
    );
  }

  Widget _linkStatusRow(ThemeService theme, PeerRTCService rtc) {
    final label = switch (rtc.status) {
      PeerStatus.waiting => 'Listening',
      PeerStatus.ping => 'Handshakeing',
      PeerStatus.answered => 'Connected',
      PeerStatus.connected => 'Connected',
    };
    return Text('Link - $label', style: TextStyle(color: theme.primaryText, fontSize: 10, fontWeight: FontWeight.bold));
  }
}
