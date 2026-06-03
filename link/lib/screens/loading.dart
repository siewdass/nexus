import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/rtc_client.dart';
import '../services/theme_service.dart';
import 'scan_screen.dart';
import 'home.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool _checking = true;
  bool _connecting = false;
  bool _hasUuid = false;
  String _message = '';

  StreamSubscription<String>? _errSub;

  @override
  void initState() {
    super.initState();
    _checkSavedUuid();
  }

  Future<void> _checkSavedUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = prefs.getString('hub_uuid');
    if (!mounted) return;

    if (uuid != null && uuid.isNotEmpty) {
      setState(() {
        _hasUuid = true;
        _connecting = true;
        _message = 'Conectando al Hub...';
      });
      _connect(uuid);
    } else {
      setState(() {
        _checking = false;
        _hasUuid = false;
      });
    }
  }

  Future<void> _connect(String uuid) async {
    _errSub?.cancel();
    _errSub = rtcClient.errors.listen((e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _message = 'Error: $e';
        });
      }
    });

    try {
      await rtcClient.connect(uuid);
      rtcClient.addListener(_onRtcChange);
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _message = 'Error al conectar: $e';
        });
      }
    }
  }

  void _onRtcChange() {
    if (rtcClient.isConnected && mounted) {
      rtcClient.removeListener(_onRtcChange);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Home()),
      );
    }
  }

  Future<void> _openScanner() async {
    final uuid = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );

    if (uuid == null || uuid.isEmpty || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hub_uuid', uuid);

    setState(() {
      _hasUuid = true;
      _connecting = true;
      _message = 'Conectando al Hub...';
    });
    _connect(uuid);
  }

  Future<void> _reconnect() async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = prefs.getString('hub_uuid');
    if (uuid != null && uuid.isNotEmpty && mounted) {
      setState(() {
        _connecting = true;
        _message = 'Conectando al Hub...';
      });
      _connect(uuid);
    } else {
      await _checkSavedUuid();
    }
  }

  @override
  void dispose() {
    _errSub?.cancel();
    rtcClient.removeListener(_onRtcChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy, size: 80, color: theme.primaryText),
            const SizedBox(height: 24),
            Text(
              'Nexus Link',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 40),
            if (_checking)
              CircularProgressIndicator(color: theme.primaryText),
            if (_connecting) ...[
              CircularProgressIndicator(color: theme.primaryText),
              const SizedBox(height: 16),
              Text(
                _message,
                style: TextStyle(fontSize: 14, color: theme.secondaryText),
              ),
            ],
            if (!_checking && !_hasUuid) ...[
              Text(
                'Escanea el código QR del Hub',
                style: TextStyle(fontSize: 16, color: theme.secondaryText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openScanner,
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text('Abrir cámara'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
            if (!_connecting && _hasUuid && _message.contains('Error')) ...[
              const SizedBox(height: 16),
              Text(
                _message,
                style: TextStyle(fontSize: 14, color: theme.debugRed),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _reconnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reintentar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await rtcClient.clearSavedUuid();
                  if (mounted) {
                    setState(() {
                      _checking = false;
                      _hasUuid = false;
                      _message = '';
                    });
                  }
                },
                child: Text(
                  'Escanear otro QR',
                  style: TextStyle(color: theme.secondaryText, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
