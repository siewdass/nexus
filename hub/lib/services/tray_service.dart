import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  static const _channel = MethodChannel('nexus_hub/tray');

  late final MenuItem _toggleItem;
  late final Menu _menu;
  bool _isShown = true;

  Future<void> init() async {
    _toggleItem = MenuItem(key: 'toggle', label: 'Hide');
    _toggleItem.onClick = (_) => _onToggle();
    _menu = Menu(
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

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onWindowHidden':
          _isShown = false;
          _toggleItem.label = 'Show';
          await trayManager.setContextMenu(_menu);
        case 'onWindowShown':
          _isShown = true;
          _toggleItem.label = 'Hide';
          await trayManager.setContextMenu(_menu);
      }
    });

    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final iconPath = brightness == Brightness.dark
        ? 'assets/icon-light.png'
        : 'assets/icon-dark.png';
    await trayManager.setIcon(iconPath, isTemplate: true);
    await trayManager.setToolTip('Nexus Hub');
    await trayManager.setContextMenu(_menu);
    trayManager.addListener(this);
  }

  void dispose() {
    trayManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  Future<void> _onToggle() async {
    if (_isShown) {
      await _channel.invokeMethod('hideWindow');
      _toggleItem.label = 'Show';
      _isShown = false;
    } else {
      await _channel.invokeMethod('showWindow');
      _toggleItem.label = 'Hide';
      _isShown = true;
    }
    await trayManager.setContextMenu(_menu);
  }
}
