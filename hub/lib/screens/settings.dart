import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';

class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SwitchListTile(
        title: Text('Tema',
            style: TextStyle(color: theme.primaryText)),
        subtitle: Text('Claro / Oscuro',
            style: TextStyle(color: theme.secondaryText)),
        value: theme.isDark,
        activeTrackColor: theme.green,
        onChanged: (_) => theme.toggle(),
      ),
    );
  }
}
