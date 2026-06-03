import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../services/api_tokens.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _groqCtrl = TextEditingController();
  final _mistralCtrl = TextEditingController();
  final _googleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final tokens = context.read<ApiTokenService>();
    if (tokens.groqToken != null) _groqCtrl.text = tokens.groqToken!;
    if (tokens.mistralToken != null) _mistralCtrl.text = tokens.mistralToken!;
    if (tokens.googleToken != null) _googleCtrl.text = tokens.googleToken!;
  }

  @override
  void dispose() {
    _groqCtrl.dispose();
    _mistralCtrl.dispose();
    _googleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final svc = context.read<ApiTokenService>();
    await svc.save(
      groq: _groqCtrl.text.trim(),
      mistral: _mistralCtrl.text.trim(),
      google: _googleCtrl.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Column(
        children: [
          DragToMoveArea(
            child: Container(
              height: 35,
              color: theme.sidebarBg,
              child: Row(
                children: [
                  const SizedBox(width: 70),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Settings',
                        style: TextStyle(color: theme.primaryText, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _save,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.save, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance',
                        style: TextStyle(color: theme.secondaryText, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Card(
                      color: theme.inactiveBg,
                      child: SwitchListTile(
                        title: Text('Dark theme',
                            style: TextStyle(color: theme.primaryText, fontSize: 13)),
                        subtitle: Text('Light / Dark',
                            style: TextStyle(color: theme.secondaryText, fontSize: 11)),
                        value: theme.isDark,
                        activeTrackColor: theme.green,
                        onChanged: (_) => theme.toggle(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Providers',
                        style: TextStyle(color: theme.secondaryText, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Card(
                      color: theme.inactiveBg,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _tokenField(theme, 'Groq', _groqCtrl),
                            const SizedBox(height: 8),
                            _tokenField(theme, 'Mistral', _mistralCtrl),
                            const SizedBox(height: 8),
                            _tokenField(theme, 'Google', _googleCtrl),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tokenField(ThemeService theme, String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      readOnly: false,
      style: TextStyle(color: theme.primaryText, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.secondaryText, fontSize: 13),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.only(left: 14, right: 8, top: 10, bottom: 6),
      ),
    );
  }
}
