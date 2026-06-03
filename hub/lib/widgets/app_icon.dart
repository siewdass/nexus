import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class AppIcon extends StatelessWidget {
  final double size;
  const AppIcon({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Image.asset(
      theme.isDark ? 'assets/icon-light.png' : 'assets/icon-dark.png',
      width: size,
      height: size,
    );
  }
}
