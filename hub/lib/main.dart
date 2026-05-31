import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:socket_io_plus/socket_io.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:window_manager/window_manager.dart';

import 'package:provider/provider.dart';
import 'screens/home.dart';
import 'screens/settings.dart';
import 'services/status.dart';
import 'services/theme_service.dart';
import 'services/tray_service.dart';

final trayService = TrayService();

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
  if (Platform.isMacOS) {
    await Process.run('chmod', ['+x', file.path]);
    await Process.run('xattr', ['-d', 'com.apple.quarantine', file.path]);
    await Process.run('codesign', ['--force', '--sign', '-', file.path]);
  }
  print('Extraido ${file.path}');
  return file.path;
}

class LlmService {
  LlamaEngine? _engine;

  LlamaEngine? get engine => _engine;

  Future<void> init({String? bundleAssets}) async {
    final dylib = bundleAssets != null
        ? '$bundleAssets/libllama.dylib'
        : await extractAsset('assets/libllama.dylib');
    final model = bundleAssets != null
        ? '$bundleAssets/Qwen3-0.6B-Q8_0.gguf'
        : await extractAsset('assets/Qwen3-0.6B-Q8_0.gguf');
    LlamaLibrary.load(path: dylib);
    LlamaLog.captureToFile('/dev/null');
    _engine = await LlamaEngine.spawn(
      libraryPath: dylib,
      modelParams: ModelParams(path: model, gpuLayers: 99),
      contextParams: const ContextParams(nCtx: 4096),
    );
  }
}

String? _localIp;
String? _publicUrl;

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
            'public': _publicUrl ?? '',
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
    final llm = LlmService();
    try {
      await llm.init(bundleAssets: _bundleAssets);
      serviceStatus.setLlmReady();
      print('LLM listo.');
    } catch (e, st) {
      print('Error LLM init: $e');
      print(st);
      serviceStatus.setLlmError('$e');
    }

    WidgetsFlutterBinding.ensureInitialized();

  _localIp = await _findLocalIp();
  serviceStatus.setPrivate(_localIp ?? '?');
  _startUdpDiscovery();
  serviceStatus.setUdpReady();

  final io = Server();

  var _inThink = false;
  var _unprocessed = '';

  void _clientEmit(Socket client, String event, String data) {
    client.emit(event, data);
  }

  void _flushTokens(String chunk, Socket client) {
    _unprocessed += chunk;
    while (_unprocessed.isNotEmpty) {
      if (!_inThink) {
        final idx = _unprocessed.indexOf('<think>');
        if (idx < 0) {
          _clientEmit(client, 'token', _unprocessed);
          _unprocessed = '';
          break;
        }
        if (idx > 0) {
          _clientEmit(client, 'token', _unprocessed.substring(0, idx));
        }
        _unprocessed = _unprocessed.substring(idx + 7);
        _inThink = true;
      } else {
        final idx = _unprocessed.indexOf('</think>');
        if (idx < 0) {
          _clientEmit(client, 'think', _unprocessed);
          _unprocessed = '';
          break;
        }
        if (idx > 0) {
          _clientEmit(client, 'think', _unprocessed.substring(0, idx));
        }
        _unprocessed = _unprocessed.substring(idx + 8);
        _inThink = false;
      }
    }
  }

  io.on('connection', (Socket client) {
    print('Cliente conectado: ${client.id}');

    client.on('chat', (data) async {
      if (llm.engine == null) {
        client.emit('error', 'Engine no inicializado');
        return;
      }

      final text = (data as Map?)?['text'] as String?;
      if (text == null || text.isEmpty) {
        client.emit('error', 'Texto vacio');
        return;
      }

      try {
        final chat = await llm.engine!.createChat();
        chat.addSystem('Eres un asistente breve y conciso. Responde en espanol.');
        chat.addUser(text);

        await for (final event in chat.generate(
          sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
          maxTokens: 4096,
        )) {
          if (event is TokenEvent) {
            _flushTokens(event.text, client);
          }
        }

        if (_unprocessed.isNotEmpty) {
          if (_inThink) {
            _clientEmit(client, 'think', _unprocessed);
          } else {
            _clientEmit(client, 'token', _unprocessed);
          }
          _unprocessed = '';
        }
        _inThink = false;
        client.emit('done', '');
      } catch (e, st) {
        print('Error en chat: $e');
        print(st);
        client.emit('error', 'Error: $e');
      }
    });

    client.on('disconnect', (_) {
      print('Cliente desconectado: ${client.id}');
    });
  });

  try {
    await io.listen(5001);
    serviceStatus.setServerReady();
    print('Private: http://$_localIp:5001');
  } catch (e) {
    serviceStatus.setServerError('$e');
  }

  final tunnelPath = await extractAsset('assets/cloudflared');
  final tunnelBin = File(tunnelPath);
  if (await tunnelBin.exists()) {
    try {
      final tunnel = await Process.start(
        tunnelBin.path,
        ['tunnel', '--url', 'http://localhost:5001', '--edge-ip-version', '4', '--no-autoupdate', '--retries', '1'],
      );
      tunnel.stderr.transform(utf8.decoder).listen((line) {
        final match =
            RegExp(r'https://[a-z-]+\.trycloudflare\.com').firstMatch(line);
        if (match != null) {
          _publicUrl = match.group(0);
          serviceStatus.setPublicUrl(_publicUrl!);
          print('Public: $_publicUrl');
        }
        if (line.contains('error') || line.contains('Failed')) {
          serviceStatus.setTunnelError(line);
        }
      });
    } catch (e) {
      serviceStatus.setTunnelError('$e');
    }
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
    ChangeNotifierProvider.value(
      value: theme,
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
