import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import '../services/beep.dart';
import '../services/wake.dart';
import '../services/tts.dart';
import '../services/stt.dart';
import '../services/theme_service.dart';
import '../services/rtc_client.dart';
import 'settings.dart';

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
  final _bgService = FlutterBackgroundService();

  bool _listening = false;
  bool _nexusDetected = false;
  bool _isStarting = false;
  bool _recording = false;

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

  @override
  void initState() {
    super.initState();

    _detector.onReady = () async {
      await _tts.init();
      await _stt.init();
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

      if (!rtcClient.isConnected) {
        _finishConversation();
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _beep.play();
      setState(() => _nexusDetected = false);
      _startSttPhase();
    };
    _detector.loadModels();
  }

  Future<void> _speakResponse(String text) async {
    if (text.isEmpty) return;
    try {
      await _tts.speakAndWait(text);
    } catch (_) {}
  }

  void _startSttPhase() {
    if (!_stt.isInitialized) {
      debugPrint('[HOME] STT not ready, finishing');
      _finishConversation();
      return;
    }
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

    final buffer = StringBuffer();
    final completer = Completer<String>();
    StreamSubscription tokenSub;
    StreamSubscription doneSub;
    StreamSubscription errSub;

    tokenSub = rtcClient.tokens.listen((t) => buffer.write(t));
    doneSub = rtcClient.done.listen((_) {
      if (!completer.isCompleted) completer.complete(buffer.toString());
    });
    errSub = rtcClient.errors.listen((e) {
      if (!completer.isCompleted) completer.completeError(e);
    });

    rtcClient.sendChat(text);

    try {
      final response =
          await completer.future.timeout(const Duration(seconds: 60));
      debugPrint('[HOME] response: $response');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _speakResponse(response);
      _finishConversation();
    } catch (e) {
      debugPrint('[HOME] error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _finishConversation();
    } finally {
      tokenSub.cancel();
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

      if (!context.read<PeerRTCClient>().isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión al hub. Escanea el código QR.'),
              duration: Duration(seconds: 2),
            ),
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
        backgroundColor: theme.sidebarBg,
        foregroundColor: theme.primaryText,
        title: const Text('Nexus Link'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.primaryText),
            tooltip: 'Recargar tareas',
            onPressed: rtcClient.sendListTasks,
          ),
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
        isConnected: context.watch<PeerRTCClient>().isConnected,
        listening: _listening,
        isStarting: _isStarting,
        onPressed: _toggleListening,
        theme: theme,
      ),
      body: Column(
        children: [
          if (!context.watch<PeerRTCClient>().isConnected)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _TasksTab(theme: theme),
          ),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  final bool isConnected;
  final bool listening;
  final bool isStarting;
  final VoidCallback onPressed;
  final ThemeService theme;

  const _Fab({
    required this.isConnected,
    required this.listening,
    required this.isStarting,
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !isConnected;
    return RepaintBoundary(
      child: FloatingActionButton(
        onPressed: disabled ? null : onPressed,
        backgroundColor: disabled
            ? theme.inactiveBg.withAlpha(128)
            : listening
                ? theme.green
                : theme.inactiveBg,
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
                color: disabled
                    ? theme.primaryText.withAlpha(100)
                    : theme.primaryText,
              ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'open': return const Color(0xFF7890B0);
    case 'approved': return const Color(0xFF34B77A);
    case 'building': return const Color(0xFFE8A838);
    case 'built': return const Color(0xFF5AC88C);
    case 'review': return const Color(0xFF9B59B6);
    case 'testing': return const Color(0xFFF1C40F);
    case 'tested': return const Color(0xFF2ECC71);
    case 'reopened': return const Color(0xFFBE2828);
    case 'closed': return const Color(0xFF888888);
    default: return const Color(0xFF888888);
  }
}

class _TasksTab extends StatefulWidget {
  final ThemeService theme;
  const _TasksTab({required this.theme});

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  List<Map<String, dynamic>> _tasks = [];
  int? _expandedIndex;
  StreamSubscription? _tasksSub;
  StreamSubscription? _addedSub;
  StreamSubscription? _updatedSub;
  StreamSubscription? _removedSub;

  @override
  void initState() {
    super.initState();
    rtcClient.sendListTasks();
    _tasksSub = rtcClient.tasks.listen((tasks) {
      if (mounted) setState(() => _tasks = tasks);
    });
    _addedSub = rtcClient.taskAdded.listen((task) {
      if (mounted) setState(() => _tasks.add(task));
    });
    _updatedSub = rtcClient.taskUpdated.listen((task) {
      if (mounted) setState(() {
        final idx = _tasks.indexWhere((t) => t['id'] == task['id']);
        if (idx >= 0) _tasks[idx] = task;
      });
    });
    _removedSub = rtcClient.taskRemoved.listen((data) {
      if (mounted) setState(() {
        _tasks.removeWhere((t) => t['id'] == data['id']);
      });
    });
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    _addedSub?.cancel();
    _updatedSub?.cancel();
    _removedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) {
      return Center(
        child: Text(
          'Sin tareas',
          style: TextStyle(
            fontSize: 13,
            color: widget.theme.secondaryText,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        final title = task['title'] as String? ?? 'Sin título';
        final status = task['status'] as String? ?? 'open';
        final description = task['description'] as String?;
        final color = _statusColor(status);
        final isExpanded = _expandedIndex == index;
        final criteria = task['criteria'] as List?;
        if (criteria != null && criteria.isNotEmpty) {
          debugPrint('[TASKS] showing ${criteria.length} criteria for task ${task['id']}');
        }

        return Column(
          children: [
            if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            ExpansionTile(
              key: ValueKey('${task['id']}_$isExpanded'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() => _expandedIndex = expanded ? index : null);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.theme.primaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              children: [
                if (description != null && description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.theme.secondaryText,
                        ),
                      ),
                    ),
                  ),
                if (criteria != null && criteria.isNotEmpty)
                  _CriteriaTimeline(
                    criteria: criteria,
                    theme: widget.theme,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CriteriaTimeline extends StatelessWidget {
  final List criteria;
  final ThemeService theme;

  const _CriteriaTimeline({
    required this.criteria,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Criterios de aceptación',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < criteria.length; i++)
            _buildCriteriaItem(criteria[i] as Map<String, dynamic>, i),
        ],
      ),
    );
  }

  Widget _buildCriteriaItem(Map<String, dynamic> criterion, int index) {
    final status = criterion['status'] as String? ?? 'pending';
    final description = criterion['description'] as String? ?? '';
    final isLast = index == criteria.length - 1;

    Color dotColor;
    IconData icon;
    switch (status) {
      case 'passed':
        dotColor = const Color(0xFF2ECC71);
        icon = Icons.check_circle;
      case 'failed':
        dotColor = const Color(0xFFE74C3C);
        icon = Icons.cancel;
      default:
        dotColor = const Color(0xFF7890B0);
        icon = Icons.circle;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Icon(icon, size: 12, color: dotColor),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: theme.secondaryText.withAlpha(60),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.secondaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
