import 'dart:async';
import 'package:flutter/material.dart';
import '../services/scanner.dart';
import 'home.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _message = 'Buscando servidor Nexus...';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    final result = await Scanner.discover(timeout: const Duration(seconds: 3));
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _message = 'Servidor encontrado: ${result.private}';
        _done = true;
      });
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Home()),
      );
    } else {
      setState(() {
        _message = 'No se encontró el servidor Nexus';
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.smart_toy, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Nexus',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            if (!_done) const CircularProgressIndicator(color: Colors.white),
            if (!_done) const SizedBox(height: 16),
            Text(
              _message,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            if (_done && Scanner.lastResult == null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _message = 'Buscando servidor Nexus...';
                    _done = false;
                  });
                  _startScan();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
