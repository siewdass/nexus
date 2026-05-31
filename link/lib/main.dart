import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'services/notifications.dart';
import 'services/theme_service.dart';
import 'screens/loading.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initNotifications();
  await _initBackgroundService();

  final theme = ThemeService();
  await theme.load();

  runApp(
    ChangeNotifierProvider.value(
      value: theme,
      child: Consumer<ThemeService>(
        builder: (_, themeService, __) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                themeService.isDark ? Brightness.light : Brightness.dark,
          ),
          child: MaterialApp(
            theme: themeService.currentTheme,
            home: const LoadingScreen(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    ),
  );
}

Future<void> _initBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onBgStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'nexus_service',
      initialNotificationContent: 'Escuchando wake word...',
      initialNotificationTitle: 'Nexus',
      foregroundServiceNotificationId: 9999,
      foregroundServiceTypes: [AndroidForegroundType.microphone],
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void _onBgStart(ServiceInstance service) {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((_) => service.stopSelf());
  }
}
