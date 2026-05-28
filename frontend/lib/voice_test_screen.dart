import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen({super.key});
  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen> {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textCtrl = TextEditingController(
    text:
        'Señor, detecto una anomalía en los sistemas de seguridad del nivel inferior. Iniciando protocolo de diagnóstico automático. Los sensores indican actividad inusual en el sector B. ¿Desea que active los sistemas de defensa secundarios?',
  );
  final TextEditingController _engineCtrl = TextEditingController();
  final TextEditingController _filterCtrl = TextEditingController();
  List<Map> _voices = [];
  List<String> _engines = [];
  String? _currentEngine;
  String? _defaultEngine;
  Map? _playingVoice;
  bool _isPlaying = false;
  bool _loaded = false;
  double _pitch = 1.0;
  double _rate = 0.45;

  List<Map> get _filteredVoices {
    final q = _filterCtrl.text.toLowerCase();
    if (q.isEmpty) return _voices;
    return _voices.where((v) {
      final name = (v['name']?.toString() ?? '').toLowerCase();
      final locale = (v['locale']?.toString() ?? '').toLowerCase();
      return name.contains(q) || locale.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted)
        setState(() {
          _playingVoice = null;
          _isPlaying = false;
        });
    });
    _tts.setCancelHandler(() {
      if (mounted)
        setState(() {
          _playingVoice = null;
          _isPlaying = false;
        });
    });
    _tts.setErrorHandler((_) {
      if (mounted)
        setState(() {
          _playingVoice = null;
          _isPlaying = false;
        });
    });
    _initTts();
  }

  Future<void> _initTts() async {
    _defaultEngine = await _tts.getDefaultEngine;
    _engines = (await _tts.getEngines).cast<String>();
    try {
      await _tts.setEngine('com.google.android.tts');
      final voices = await _tts.getVoices;
      setState(() {
        _currentEngine = 'com.google.android.tts';
        _voices = voices.cast<Map>();
        _loaded = true;
      });
    } catch (e) {
      setState(() {
        _currentEngine = _defaultEngine;
        _voices = [];
        _loaded = true;
      });
    }
  }

  Future<void> _switchEngine(String engine) async {
    try {
      await _tts.stop();
      await _tts.setEngine(engine);
      final voices = await _tts.getVoices;
      if (mounted) {
        setState(() {
          _currentEngine = engine;
          _voices = voices.cast<Map>();
          _filterCtrl.clear();
          _playingVoice = null;
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Motor: $engine  |  ${voices.length} voces')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _play(String text, Map voice) async {
    await _tts.stop();
    final clean = <String, String>{};
    for (final e in voice.entries) {
      if (e.key != null && e.value != null) {
        clean[e.key.toString()] = e.value.toString();
      }
    }
    await _tts.setVoice(clean);
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(1.0);
    await _tts.speak(text);
    setState(() {
      _playingVoice = voice;
      _isPlaying = true;
    });
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() {
      _playingVoice = null;
      _isPlaying = false;
    });
  }

  String _voiceLabel(Map v) {
    final name = v['name']?.toString() ?? '?';
    final locale = v['locale']?.toString() ?? '?';
    return '$name ($locale)';
  }

  String _voiceFeatures(Map v) {
    final feat = v['features']?.toString() ?? '';
    if (feat.isNotEmpty) return 'features: $feat';
    final quality = v['quality']?.toString() ?? '';
    final latency = v['latency']?.toString() ?? '';
    if (quality.isNotEmpty || latency.isNotEmpty)
      return 'quality: $quality  latency: $latency';
    return '';
  }

  void _logVoices() {
    final buffer = StringBuffer();
    buffer.writeln('=== MOTOR: $_currentEngine ===');
    buffer.writeln('Total voces: ${_voices.length}');
    buffer.writeln('');
    for (int i = 0; i < _voices.length; i++) {
      final v = _voices[i];
      buffer.writeln('--- Voz #${i + 1} ---');
      for (final e in v.entries) {
        buffer.writeln('  ${e.key}: ${e.value}');
      }
      buffer.writeln('');
    }
    debugPrint(buffer.toString());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_voices.length} voces impresas en consola')),
      );
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _textCtrl.dispose();
    _engineCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Probar Voces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Listar voces en consola',
            onPressed: _loaded ? _logVoices : null,
          ),
          if (_isPlaying)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: _stop,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Texto de prueba',
              ),
            ),
          ),
          if (_loaded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Motor: ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _currentEngine,
                          isExpanded: true,
                          hint: const Text('Seleccionar motor'),
                          items: [
                            ..._engines.map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12)),
                                )),
                            if (!_engines.contains('com.google.android.tts'))
                              const DropdownMenuItem(
                                value: 'com.google.android.tts',
                                child: Text(
                                    'com.google.android.tts (Google TTS)',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.blue)),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null && v != _currentEngine)
                              _switchEngine(v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _engineCtrl,
                          decoration: const InputDecoration(
                            hintText:
                                'Engine package (ej: com.google.android.tts)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final pkg = _engineCtrl.text.trim();
                          if (pkg.isNotEmpty && pkg != _currentEngine)
                            _switchEngine(pkg);
                        },
                        child: const Text('Ir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Pitch', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: _pitch,
                    min: 0.1,
                    max: 2.0,
                    divisions: 19,
                    label: _pitch.toStringAsFixed(1),
                    onChanged: (v) {
                      _tts.setPitch(v);
                      setState(() => _pitch = v);
                    },
                  ),
                ),
                Text(_pitch.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Rate', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: _rate,
                    min: 0.1,
                    max: 1.5,
                    divisions: 14,
                    label: _rate.toStringAsFixed(2),
                    onChanged: (v) {
                      _tts.setSpeechRate(v);
                      setState(() => _rate = v);
                    },
                  ),
                ),
                Text(_rate.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (_loaded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  hintText: 'Filtrar (ej: es, en)',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  isDense: true,
                  suffixIcon: _filterCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _filterCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ),
          const SizedBox(height: 4),
          if (!_loaded)
            const Center(child: CircularProgressIndicator())
          else if (_filteredVoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No se encontraron voces'),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _filteredVoices.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final v = _filteredVoices[i];
                  final isActive = _playingVoice?['locale'] == v['locale'];
                  final features = _voiceFeatures(v);
                  return ListTile(
                    leading: Icon(
                      isActive ? Icons.volume_up : Icons.record_voice_over,
                      color: isActive ? Colors.green : null,
                    ),
                    title: Text(_voiceLabel(v)),
                    subtitle: features.isNotEmpty
                        ? Text(features,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]))
                        : null,
                    trailing: IconButton(
                      icon: Icon(
                        isActive ? Icons.stop_circle : Icons.play_circle_fill,
                        color: isActive ? Colors.red : Colors.green,
                      ),
                      onPressed: () {
                        if (isActive) {
                          _stop();
                        } else {
                          _play(_textCtrl.text, v);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
