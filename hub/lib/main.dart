import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'screens/home.dart';
import 'screens/model_selector_screen.dart';
import 'services/state.dart';
import 'services/theme_service.dart';
import 'services/rtc_service.dart';
import 'services/tray_service.dart';
import 'services/llm_service.dart';

final trayService = TrayService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LlamaLibrary.loadFromProcess();
  LlamaLog.captureToFile('/dev/null');

  final homeDir = Platform.environment['HOME'] ?? '/tmp';
  final modelsDir = Directory('$homeDir/.nexus_hub/models');
  if (!modelsDir.existsSync()) modelsDir.createSync(recursive: true);

  final existingModel = () {
    try {
      return modelsDir.listSync().whereType<File>().firstWhere(
        (f) => f.path.endsWith('.gguf'),
      );
    } catch (_) {
      return null;
    }
  }();

  if (existingModel != null) {
    await llmService.init(modelPath: existingModel.path);
    hubState.markLlmReady();
  }

  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) {
    windowManager.setSize(const Size(540, 400));
    windowManager.setTitle('Nexus Hub');
    windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  });

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCGpcuceXLr7IRPCEc3Vnb12iQsSL81C00",
      authDomain: "nexus-29e23.firebaseapp.com",
      projectId: "nexus-29e23",
      storageBucket: "nexus-29e23.firebasestorage.app",
      messagingSenderId: "440764792459",
      appId: "1:440764792459:ios:8f3b9e6eea3e99ba1ede8e",
    ),
  );

  await rtcService.init();
  await trayService.init();

  final theme = ThemeService();
  await theme.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: hubState),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: rtcService),
      ],
      child: Consumer<ThemeService>(
        builder: (_, t, __) => MaterialApp(
          theme: t.currentTheme,
          home: existingModel != null
              ? const HomeScreen()
              : ModelSelectorScreen(modelsDir: modelsDir.path),
        ),
      ),
    ),
  );

  await windowManager.show();
  await windowManager.focus();
}
