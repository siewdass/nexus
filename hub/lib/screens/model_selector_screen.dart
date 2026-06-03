import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';
import '../services/models.dart';
import 'download_screen.dart';

class ModelSelectorScreen extends StatefulWidget {
  final String modelsDir;
  const ModelSelectorScreen({super.key, required this.modelsDir});

  @override
  State<ModelSelectorScreen> createState() => _ModelSelectorScreenState();
}

class _ModelSelectorScreenState extends State<ModelSelectorScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text('Elegí un modelo',
                style: TextStyle(
                  color: theme.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 4),
            Text('Se descargará al iniciar',
                style: TextStyle(color: theme.secondaryText, fontSize: 13)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: availableModels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final model = availableModels[i];
                  final selected = i == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                            color: selected
                                ? theme.green.withValues(alpha: 0.15)
                                : theme.inactiveBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? theme.green : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selected ? theme.green : theme.secondaryText,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(model.name,
                                style: TextStyle(
                                    color: theme.primaryText, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () {
                  final model = availableModels[_selected];
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DownloadScreen(
                        modelPath:
                            '${widget.modelsDir}/${model.filename}',
                        modelUrl: model.url,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Siguiente',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
