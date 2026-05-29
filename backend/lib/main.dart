import 'dart:convert';
import 'dart:io';
import 'package:socket_io_plus/socket_io.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:hotreloader/hotreloader.dart';

class LlmService {
  LlamaEngine? _engine;

  LlamaEngine? get engine => _engine;

  Future<void> init() async {
    const dylib = 'assets/libllama.dylib';
    const model = 'assets/Qwen3-0.6B-Q8_0.gguf';
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
          udp.send(utf8.encode(response), dg.address, dg.port);
          print('UDP discover respondido a ${dg.address.address}');
        }
      }
    });
  });
}

Future<void> main() async {
  final reloader = await HotReloader.create(
    debounceInterval: Duration(seconds: 1),
  );
  print('Iniciando LLM engine...');
  final llm = LlmService();
  await llm.init();
  print('LLM listo.');

  _localIp = await _findLocalIp();
  print('Local IP: $_localIp');

  _startUdpDiscovery();

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

      final chat = await llm.engine!.createChat();
      chat.addSystem('Eres un asistente breve y conciso. Responde en espanol.');
      chat.addUser(text);

      await for (final event in chat.generate(
        sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
        maxTokens: 4096,
      )) {
        if (event is TokenEvent) {
          stdout.write(event.text);
          _flushTokens(event.text, client);
        }
      }
      stdout.write('\n');

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
    });

    client.on('disconnect', (_) {
      print('Cliente desconectado: ${client.id}');
    });
  });

  await io.listen(5001);
  print('Private: http://$_localIp:5001');

  final tunnelBin = File('assets/cloudflared');
  if (tunnelBin.existsSync()) {
    final tunnel = await Process.start(
      tunnelBin.path,
      ['tunnel', '--url', 'http://localhost:5001'],
    );
    tunnel.stderr.transform(utf8.decoder).listen((line) {
      final match =
          RegExp(r'https://[a-z-]+\.trycloudflare\.com').firstMatch(line);
      if (match != null) {
        _publicUrl = match.group(0);
        print('Public: $_publicUrl');
      }
    });
  }
}
