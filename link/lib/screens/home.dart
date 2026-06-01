import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import '../services/beep.dart';
import '../services/notifications.dart';
import '../services/wake.dart';
import '../services/tts.dart';
import '../services/network.dart';
import '../services/scanner.dart';
import '../services/stt.dart';
import '../services/theme_service.dart';
import 'settings.dart';

class _Interaction {
  String query;
  String think;
  String response;
  _Interaction()
      : query = '',
        think = '',
        response = '';
}

final _tts = TtsService();
final _stt = SttService();
final _beep = BeepService();

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _detector = WakeService();
  StreamSubscription<AudioDataContainer>? _audioStream;
  StreamSubscription<void>? _disconnectSub;
  final _bgService = FlutterBackgroundService();

  final List<_Interaction> _interactions = [];
  bool _listening = false;
  bool _nexusDetected = false;
  bool _isStarting = false;
  bool _recording = false;
  bool _modelsReady = false;
  int _speakingIndex = -1;
  int? _expandedThinkIndex;

  static const _sampleRate = 16000;

  Future<void> _startPrebuffering() async {
    if (_recording) return;
    if (!await Permission.microphone.request().isGranted) return;
    try {
      await Recorder.instance.init(
        format: PCMFormat.s16le,
        sampleRate: _sampleRate,
        channels: RecorderChannels.mono,
      );
      Recorder.instance.start();
      Recorder.instance.startStreamingData();
      _recording = true;
      _audioStream?.cancel();
      _audioStream = Recorder.instance.uint8ListStream.listen((data) {
        _detector.feedAudio(data.rawData);
      });
    } catch (e) {
      debugPrint('PREBUF ERROR: $e');
    }
  }

  Future<void> _stopRecorder() async {
    if (!_recording) return;
    _audioStream?.cancel();
    _audioStream = null;
    try {
      Recorder.instance.stopStreamingData();
      Recorder.instance.stop();
      Recorder.instance.deinit();
    } catch (e) {
      debugPrint('REC STOP ERROR: $e');
    }
    _recording = false;
  }

  Future<void> _connect(ScanResult scan) async {
    if (scan.public.isNotEmpty) {
      final parts = scan.public.split(':');
      final host = parts[0];
      final port = parts.length > 1 ? int.parse(parts[1]) : 5001;
      try {
        await networkService.connect(host: host, port: port);
        return;
      } catch (_) {}
    }
    await networkService.connect(host: scan.private, port: 5001);
  }

  Future<void> _tryReconnect() async {
    final scan = await Scanner.discover(timeout: const Duration(seconds: 2));
    if (scan != null && mounted) {
      try {
        await _connect(scan);
      } catch (_) {}
    }
  }

  @override
  void initState() {
    super.initState();

    _disconnectSub = networkService.onDisconnect.listen((_) {
      _tryReconnect();
    });

    _detector.onReady = () async {
      await _tts.init();
      await _stt.init();
      setState(() => _modelsReady = true);
      if (!networkService.isConnected) {
        final scan = Scanner.lastResult;
        if (scan != null) {
          try {
            await _connect(scan);
          } catch (_) {}
        }
      }
    };
    _detector.onFirstPrediction = () {
      if (_isStarting) {
        setState(() => _isStarting = false);
      }
    };
    _detector.onDetected = (score) async {
      debugPrint('[HOME] nexus detected! score=$score');
      if (!_listening) return;
      await _stopRecorder();
      _bgService.invoke('stopService');
      HapticFeedback.heavyImpact();

      setState(() {
        _recording = false;
        _isStarting = false;
        _nexusDetected = true;
      });

      // await showDetectionNotification(score);

      if (!networkService.isConnected) {
        final scan = Scanner.lastResult;
        if (scan == null) {
          _finishConversation();
          return;
        }
        try {
          await _connect(scan);
        } catch (_) {
          _finishConversation();
          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _beep.play();
      setState(() => _nexusDetected = false);
      _startSttPhase();
    };
    _detector.loadModels();
  }

  Future<void> _speakResponse(int index, String text) async {
    if (text.isEmpty) return;
    setState(() => _speakingIndex = index);
    try {
      await _tts.speakAndWait(text);
    } catch (_) {}
    setState(() => _speakingIndex = -1);
  }

  void _startSttPhase() {
    debugPrint('[HOME] STT phase');
    _stt.start().then((text) {
      if (text != null && text.isNotEmpty) {
        _handleQuery(text);
      } else {
        _finishConversation();
      }
    });
  }

  void _stopStt() {
    _stt.stop();
  }

  void _finishConversation() {
    _stopStt();
    setState(() {
      _listening = false;
      _nexusDetected = false;
    });
  }

  Future<void> _handleQuery(String text) async {
    debugPrint('[HOME] _handleQuery: "$text"');
    final interaction = _Interaction();
    interaction.query = text;
    setState(() => _interactions.add(interaction));

    final buffer = StringBuffer();
    final completer = Completer<String>();
    StreamSubscription tokenSub;
    StreamSubscription thinkSub;
    StreamSubscription doneSub;
    StreamSubscription errSub;

    tokenSub = networkService.tokens.listen((t) => buffer.write(t));
    thinkSub = networkService.think.listen((t) {
      setState(() => interaction.think += t);
    });
    doneSub = networkService.done.listen((_) {
      if (!completer.isCompleted) completer.complete(buffer.toString());
    });
    errSub = networkService.errors.listen((e) {
      if (!completer.isCompleted) completer.completeError(e);
    });

    networkService.sendChat(text);

    try {
      final response =
          await completer.future.timeout(const Duration(seconds: 15));
      setState(() => interaction.response = response);
      await _tts.speakAndWait(response);
      _finishConversation();
    } catch (e) {
      setState(() => interaction.response = 'Error: $e');
      _finishConversation();
    } finally {
      tokenSub.cancel();
      thinkSub.cancel();
      doneSub.cancel();
      errSub.cancel();
    }
  }

  Future<void> _toggleListening() async {
    try {
      if (!_detector.isReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cargando modelo...')),
          );
        }
        return;
      }

      if (_nexusDetected) {
        await _tts.stop();
        setState(() => _nexusDetected = false);
      }

      if (!await Permission.microphone.request().isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de micrófono denegado')),
          );
        }
        return;
      }

      await [Permission.notification].request();
      await Permission.ignoreBatteryOptimizations.request();

      if (!_listening) {
        _stopStt();
        setState(() {
          _listening = true;
          _isStarting = true;
        });
        _detector.prepareForListening();
        if (!_recording) await _startPrebuffering();
        await _bgService.startService();
      } else {
        _stopStt();
        _bgService.invoke('stopService');
        await _stopRecorder();
        setState(() {
          _listening = false;
          _isStarting = false;
        });
      }
    } catch (e) {
      debugPrint('TOGGLE ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _stopStt();
    _stopRecorder();
    _detector.dispose();
    _disconnectSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness:
              theme.isDark ? Brightness.light : Brightness.dark,
          statusBarColor: theme.sidebarBg,
        ),
        title: const Text('Nexus Link'),
        backgroundColor: theme.sidebarBg,
        foregroundColor: theme.primaryText,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: theme.primaryText),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      floatingActionButton: _Fab(
        listening: _listening,
        isStarting: _isStarting,
        onPressed: _toggleListening,
        theme: theme,
      ),
      body: Column(
        children: [
          if (!context.watch<NetworkService>().isConnected)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _interactions.isEmpty && !_modelsReady
                ? const Center(child: Icon(Icons.smart_toy, size: 80))
                : _interactions.isEmpty
                    ? Center(
                        child: Icon(Icons.smart_toy, size: 80, color: theme.primaryText),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _interactions.length,
                        itemBuilder: (context, index) {
                          final item = _interactions[index];
                          final isLast = index == _interactions.length - 1;
                          return _InteractionCard(
                            interaction: item,
                            isActive: isLast && _nexusDetected,
                            isSpeaking: _speakingIndex == index,
                            isThinkExpanded: _expandedThinkIndex == index,
                            onToggleThink: () {
                              setState(() {
                                _expandedThinkIndex =
                                    _expandedThinkIndex == index ? null : index;
                              });
                            },
                            onPlay: () => _speakResponse(index, item.response),
                          );
                        },
                      ),
          ),
        ],
      ),
      );
    }  // build
}  // _HomeState

class _Fab extends StatelessWidget {
  final bool listening;
  final bool isStarting;
  final VoidCallback onPressed;
  final ThemeService theme;

  const _Fab({
    required this.listening,
    required this.isStarting,
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: listening ? theme.green : theme.inactiveBg,
        child: isStarting
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.primaryText),
                ),
              )
            : Icon(
                listening ? Icons.stop : Icons.play_arrow,
                size: 28,
                color: theme.primaryText,
              ),
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  final String text;
  final bool isPlaying;
  final VoidCallback? onPlay;
  final Widget? trailing;

  const _TextCard({
    required this.text,
    this.isPlaying = false,
    this.onPlay,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          text,
          style: TextStyle(
            fontSize: 12,
            color: theme.primaryText,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => Clipboard.setData(ClipboardData(text: text)),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.content_copy, size: 14, color: theme.secondaryText),
              ),
            ),
            if (onPlay != null)
              isPlaying
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : InkWell(
                      onTap: onPlay,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.volume_up,
                            size: 14, color: theme.secondaryText),
                      ),
                    ),
            if (trailing != null) const SizedBox(width: 4),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}

class _InteractionCard extends StatelessWidget {
  final _Interaction interaction;
  final bool isActive;
  final bool isSpeaking;
  final bool isThinkExpanded;
  final VoidCallback? onToggleThink;
  final VoidCallback? onPlay;

  const _InteractionCard({
    required this.interaction,
    this.isActive = false,
    this.isSpeaking = false,
    this.isThinkExpanded = false,
    this.onToggleThink,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (interaction.query.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                interaction.query,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
                ),
              ),
            ),
        if (isActive &&
            interaction.response.isEmpty &&
            interaction.think.isNotEmpty)
          SelectableText(
            interaction.think,
            style: TextStyle(
              fontSize: 12,
              color: theme.primaryText,
              fontStyle: FontStyle.italic,
            ),
          ),
        if (isActive && interaction.response.isEmpty && !context.watch<NetworkService>().isConnected)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
            ),
          ),
        if (isThinkExpanded &&
            interaction.think.isNotEmpty &&
            interaction.response.isNotEmpty)
          SelectableText(
            interaction.think,
            style: TextStyle(
              fontSize: 12,
              color: theme.primaryText,
              fontStyle: FontStyle.italic,
            ),
          ),
        if (interaction.response.isNotEmpty)
          _TextCard(
            text: interaction.response,
            onPlay: onPlay,
            isPlaying: isSpeaking,
            trailing: interaction.think.isNotEmpty
                ? InkWell(
                    onTap: () => onToggleThink?.call(),
                    child: Tooltip(
                      message: 'Razonamiento',
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isThinkExpanded
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 14,
                          color: theme.secondaryText,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
      ],
    );
  }
}
