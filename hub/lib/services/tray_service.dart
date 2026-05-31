import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  late final MenuItem _toggleItem;
  late final Menu _menu;
  bool _isShown = false;

  Future<void> init() async {
    _toggleItem = MenuItem(key: 'toggle', label: 'Show');
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

    await trayManager.setIcon('assets/icon.png', isTemplate: true);
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
      await windowManager.hide();
      _toggleItem.label = 'Show';
      _isShown = false;
    } else {
      await windowManager.show();
      await windowManager.focus();
      _toggleItem.label = 'Hide';
      _isShown = true;
    }
    await trayManager.setContextMenu(_menu);
  }
}
