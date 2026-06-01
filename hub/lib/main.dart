import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grpc/grpc.dart';
import 'package:window_manager/window_manager.dart';

import 'package:provider/provider.dart';
import 'screens/home.dart';
import 'services/state.dart';
import 'services/settings.dart';
import 'services/tunnel.dart';
import 'services/tunnel_ffi.dart';
import 'services/grpc.dart';
import 'services/theme_service.dart';
import 'services/tray_service.dart';
import 'services/llm_service.dart';

final trayService = TrayService();
final tunnelService = TunnelService();

Directory? _cacheDir;

Future<Directory> getCacheDir() async {
  if (_cacheDir != null) return _cacheDir!;
  _cacheDir = Directory('${Platform.environment['HOME'] ?? '/tmp'}/.nexus_hub/cache');
  if (!_cacheDir!.existsSync()) _cacheDir!.createSync(recursive: true);
  return _cacheDir!;
}

Future<String> extractAsset(String asset) async {
  final cache = await getCacheDir();
  final name = asset.split('/').last;
  final file = File('${cache.path}/$name');
  if (file.existsSync()) return file.path;
  print('Extrayendo $asset...');
  final data = await rootBundle.load(asset);
  await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  print('Extraido ${file.path}');
  return file.path;
}

String? _localIp;

Future<String?> _findLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('192.168.') ||
            ip.startsWith('10.') ||
            ip.startsWith('172.')) {
          return ip;
        }
      }
    }
  } catch (_) {}
  return null;
}

void _startUdpDiscovery() {
  RawDatagramSocket.bind(InternetAddress.anyIPv4, 5002).then((udp) {
    print('UDP discovery en puerto 5002');
    udp.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = udp.receive();
        if (dg != null && utf8.decode(dg.data) == 'NEXUS_DISCOVER') {
          final response = jsonEncode({
            'private': _localIp ?? '',
            'public': hubState.publicUrl ?? '',
          });
          final data = utf8.encode(response);
          print('UDP respondiendo: $response');
          udp.send(data, dg.address, dg.port);
        }
      }
    });
  });
}

String? _bundleAssets;

String? _findBundleAssets() {
  if (!Platform.isMacOS) return null;
  try {
    final exec = File(Platform.resolvedExecutable);
    final assets = '${exec.parent.parent.path}/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets';
    if (Directory(assets).existsSync()) return assets;
  } catch (_) {}
  return null;
}

void main() {
  runZonedGuarded(() async {
    _bundleAssets = _findBundleAssets();

    // Inicializar LLM antes de Flutter para que Metal sea de llama.cpp
    try {
      final model = _bundleAssets != null
          ? '$_bundleAssets/Qwen3-0.6B-Q8_0.gguf'
          : await extractAsset('assets/Qwen3-0.6B-Q8_0.gguf');
      await llmService.init(modelPath: model);
      hubState.markLlmReady();
      print('LLM listo.');
    } catch (e, st) {
      print('Error LLM init: $e');
      print(st);
      hubState.setError('$e');
    }

    WidgetsFlutterBinding.ensureInitialized();

    _localIp = await _findLocalIp();
    hubState.setPrivateIp(_localIp ?? '?');
    _startUdpDiscovery();

    // Iniciar servidor gRPC
    try {
      final grpcServer = Server.create(services: [GrpcService()]);
      await grpcServer.serve(port: 5001);
      hubState.markGrpcReady();
      print('gRPC server en puerto 5001');
      print('Private: http://$_localIp:5001');
    } catch (e, st) {
      print('Error gRPC server: $e');
      print(st);
      hubState.setError('$e');
    }

    // Inicializar tunnel FFI
    try {
      tunnelService.init(TunnelFfi());
      print('Tunnel FFI listo.');
    } catch (e, st) {
      print('Error cargando tunnel FFI: $e');
      print(st);
    }

    // Escuchar cambios de settings para tunnel
    settingsService.addListener(() {
      if (settingsService.tunnel) {
        tunnelService.start();
      } else {
        tunnelService.stop();
      }
    });

    // Restaurar estado de tunnel (por defecto true)
    final prefs = await SharedPreferences.getInstance();
    final tunnelEnabled = prefs.getBool('tunnel') ?? true;
    if (tunnelEnabled) {
      settingsService.setTunnel(true);
    }

    await windowManager.ensureInitialized();

    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(400, 300),
        minimumSize: Size(400, 300),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: true,
      ),
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
        child: const Hub(),
      ),
    );

    if (!kReleaseMode) {
      await windowManager.show();
    }
  }, (error, stack) {
    print('ERROR NO CAPTURADO: $error');
    print(stack);
  });
}

class Hub extends StatefulWidget {
  const Hub({super.key});

  @override
  State<Hub> createState() => _HubState();
}

class _HubState extends State<Hub> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (_, theme, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.currentTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
