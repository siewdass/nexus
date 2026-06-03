import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notifications.dart';
import 'services/theme_service.dart';
import 'services/rtc_client.dart';
import 'screens/loading.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDMDx3HuR4jSfr0YT2edE3bxQeQcKbCPvg",
      authDomain: "nexus-29e23.firebaseapp.com",
      projectId: "nexus-29e23",
      storageBucket: "nexus-29e23.firebasestorage.app",
      messagingSenderId: "440764792459",
      appId: "1:440764792459:web:d6b28dc22f6e5f031ede8e",
    ),
  );

  await initNotifications();
  await _initBackgroundService();

  final theme = ThemeService();
  await theme.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: rtcClient),
      ],
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
