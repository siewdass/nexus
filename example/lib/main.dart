import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

late MenuItem _toggleItem;
late Menu _trayMenu;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(400, 300),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
    ),
  );

  if (!kReleaseMode) {
    await windowManager.show();
  } else {
    await windowManager.setOpacity(0);
    await windowManager.hide();
    await windowManager.setOpacity(1);
  }

  await windowManager.setPreventClose(true);

  _toggleItem = MenuItem(key: 'toggle', label: 'Show');
  _toggleItem.onClick = (_) => _onToggle();
  _trayMenu = Menu(
    items: [
      _toggleItem,
      MenuItem(key: 'dummy', label: 'Dummy', disabled: true),
      MenuItem.separator(),
      MenuItem(
        key: 'quit',
        label: 'Exit',
        onClick: (_) {
          windowManager.destroy();
          trayManager.destroy();
          exit(0);
        },
      ),
    ],
  );

  await trayManager.setIcon('assets/icon.png', isTemplate: true);
  await trayManager.setToolTip('Nexus Hub');
  await trayManager.setContextMenu(_trayMenu);

  runApp(const MyApp());
}

void _onToggle() async {
  if (await windowManager.isVisible()) {
    windowManager.hide();
    _toggleItem.label = 'Show';
  } else {
    windowManager.show();
    windowManager.focus();
    _toggleItem.label = 'Hide';
  }
  await trayManager.setContextMenu(_trayMenu);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: _Home());
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Column(
        children: [
          DragToMoveArea(
            child: Container(
              height: 35,
              color: const Color(0xFF16213E),
              alignment: Alignment.center,
              child: const Text(
                'Nexus Hub',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Custom window',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
