import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/state.dart';
import '../services/download.dart';
import '../services/theme_service.dart';
import '../services/llm_service.dart';
import 'home.dart';

class DownloadScreen extends StatefulWidget {
  final String modelPath;
  final String modelUrl;

  const DownloadScreen({
    super.key,
    required this.modelPath,
    required this.modelUrl,
  });

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startDownload();
    }
  }

  Future<void> _startDownload() async {
    final state = context.read<StateService>();
    state.setDownloadProgress(0.0);

    try {
      await ModelDownloader.download(
        url: widget.modelUrl,
        destPath: widget.modelPath,
        onProgress: (received, total) {
          state.setDownloadProgress(total > 0 ? received / total : 0.0);
        },
      );
      state.setDownloadComplete();
      await llmService.init(modelPath: widget.modelPath);
      if (mounted) {
        state.markLlmReady();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      state.setDownloadError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final state = context.watch<StateService>();
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nexus Hub',
                style: TextStyle(
                  color: theme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              if (state.downloadStatus == 'downloading') ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: state.downloadProgress,
                    minHeight: 8,
                    backgroundColor: theme.secondaryText.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(theme.green),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(state.downloadProgress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: theme.secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Descargando modelo...',
                  style: TextStyle(color: theme.secondaryText, fontSize: 13),
                ),
              ] else if (state.downloadStatus == 'ready') ...[
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Inicializando LLM...',
                  style: TextStyle(color: theme.secondaryText, fontSize: 13),
                ),
              ] else if (state.downloadStatus == 'error') ...[
                Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                const SizedBox(height: 12),
                Text(
                  'Error al descargar',
                  style: TextStyle(color: Colors.red[300], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  state.error ?? '',
                  style: TextStyle(color: theme.secondaryText, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
