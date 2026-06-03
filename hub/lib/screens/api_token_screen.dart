import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_tokens.dart';
import '../services/theme_service.dart';
import 'model_selector_screen.dart';

const _minLength = 32;
const _maxLength = 56;

class ApiTokenScreen extends StatefulWidget {
  final String modelsDir;
  const ApiTokenScreen({super.key, required this.modelsDir});

  @override
  State<ApiTokenScreen> createState() => _ApiTokenScreenState();
}

class _ApiTokenScreenState extends State<ApiTokenScreen> {
  final _groqCtrl = TextEditingController();
  final _mistralCtrl = TextEditingController();
  final _googleCtrl = TextEditingController();
  bool _groqVisible = false;
  bool _mistralVisible = false;
  bool _googleVisible = false;
  bool _saving = false;

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

  String? _validate(String label, String value) {
    if (value.trim().isEmpty) return '$label es requerido';
    if (value.trim().length < _minLength) return 'Mínimo $_minLength caracteres';
    if (value.trim().length > _maxLength) return 'Máximo $_maxLength caracteres';
    return null;
  }

  Future<void> _save() async {
    final err = _validate('Groq', _groqCtrl.text) ??
        _validate('Mistral', _mistralCtrl.text) ??
        _validate('Google', _googleCtrl.text);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err, style: const TextStyle(fontSize: 13)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = context.read<ApiTokenService>();
      await svc.save(
        groq: _groqCtrl.text.trim(),
        mistral: _mistralCtrl.text.trim(),
        google: _googleCtrl.text.trim(),
      );
      await svc.markReady();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ModelSelectorScreen(modelsDir: widget.modelsDir),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: const TextStyle(fontSize: 13)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool visible,
    required ValueChanged<bool> onToggle,
    required Color primaryText,
    required Color secondaryText,
    required Color inactiveBg,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inactiveBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: !visible,
        style: TextStyle(color: primaryText, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryText, fontSize: 13),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(left: 14, right: 8, top: 10, bottom: 6),
          suffixIcon: IconButton(
            icon: Icon(
              visible ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: secondaryText,
            ),
            onPressed: () => onToggle(!visible),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          children: [
            Expanded(flex: 2,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/logo.png', width: 120, height: 120),
                    ),
                    const SizedBox(height: 8),
                    Text('Nexus Hub',
                        style: TextStyle(
                          color: theme.primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 4),
                    Text('Provider Keys',
                        style: TextStyle(
                          color: theme.secondaryText,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 32),
            Expanded(flex: 3,
              child: Center(
                child: SingleChildScrollView(
                child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildField(
                          label: 'Groq',
                          controller: _groqCtrl,
                          visible: _groqVisible,
                          onToggle: (v) => setState(() => _groqVisible = v),
                          primaryText: theme.primaryText,
                          secondaryText: theme.secondaryText,
                          inactiveBg: theme.inactiveBg,
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          label: 'Mistral',
                          controller: _mistralCtrl,
                          visible: _mistralVisible,
                          onToggle: (v) => setState(() => _mistralVisible = v),
                          primaryText: theme.primaryText,
                          secondaryText: theme.secondaryText,
                          inactiveBg: theme.inactiveBg,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          label: 'Google',
                          controller: _googleCtrl,
                          visible: _googleVisible,
                          onToggle: (v) => setState(() => _googleVisible = v),
                          primaryText: theme.primaryText,
                          secondaryText: theme.secondaryText,
                          inactiveBg: theme.inactiveBg,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Siguiente',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            ),
      ),
    );
  }
}
