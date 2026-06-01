import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:window_manager/window_manager.dart';

import 'package:provider/provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'screens/home.dart';
import 'screens/model_selector_screen.dart';
import 'services/state.dart';
import 'services/settings.dart';
import 'services/tunnel.dart';
import 'services/grpc.dart';
import 'services/theme_service.dart';
import 'services/tray_service.dart';
import 'services/llm_service.dart';
import 'services/database.dart';

final trayService = TrayService();

String? _localIp;

Future<String?> _findLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
          return ip;
        }
      }
    }
  } catch (_) {}
  return null;
}

void _startUdpDiscovery() {
  RawDatagramSocket.bind(InternetAddress.anyIPv4, 5002).then((udp) {
    udp.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = udp.receive();
        if (dg != null && utf8.decode(dg.data) == 'NEXUS_DISCOVER') {
          final response = jsonEncode({'private': _localIp ?? '', 'public': hubState.publicUrl ?? ''});
          udp.send(utf8.encode(response), dg.address, dg.port);
        }
      }
    });
  });
}

void main() {
  runZonedGuarded(
    () async {
      LlamaLibrary.loadFromProcess();
      LlamaLog.captureToFile('/dev/null');

      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      final modelsDir = Directory('$homeDir/.nexus_hub/models');
      if (!modelsDir.existsSync()) modelsDir.createSync(recursive: true);

      await databaseService.open(path: '$homeDir/.nexus_hub/db');

      final existingModel = () {
        try {
          return modelsDir.listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.gguf'));
        } catch (_) {
          return null;
        }
      }();

      if (existingModel != null) {
        await llmService.init(modelPath: existingModel.path);
        hubState.markLlmReady();
      }

      WidgetsFlutterBinding.ensureInitialized();

      _localIp = await _findLocalIp();
      hubState.setPrivateIp(_localIp ?? '?');
      _startUdpDiscovery();

      try {
        final grpcServer = Server.create(services: [GrpcService()]);
        await grpcServer.serve(port: 5001);
        hubState.markGrpcReady();
      } catch (e, st) {
        hubState.setError('gRPC: $e');
      }

      tunnelService.init(TunnelFfi());
      tunnelService.start();

      await windowManager.ensureInitialized();
      await windowManager.waitUntilReadyToShow(
        const WindowOptions(size: Size(400, 300), minimumSize: Size(400, 300), center: true, titleBarStyle: TitleBarStyle.hidden),
      );
      await windowManager.setPreventClose(true);
      await trayService.init();

      final theme = ThemeService();
      await theme.load();

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: hubState),
            ChangeNotifierProvider.value(value: settingsService),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: Consumer<ThemeService>(
            builder: (_, t, __) => MaterialApp(
              theme: t.currentTheme,
              home: existingModel != null ? const HomeScreen() : ModelSelectorScreen(modelsDir: modelsDir.path),
            ),
          ),
        ),
      );

      await windowManager.show();
    },
    (error, stack) {
      print('ERROR NO CAPTURADO: $error');
      print(stack);
    },
  );
}
