import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';

class SystemStats extends StatefulWidget {
  const SystemStats({super.key});

  @override
  State<SystemStats> createState() => _SystemStatsState();
}

class _SystemStatsState extends State<SystemStats>
    with SingleTickerProviderStateMixin {
  double _cpu = 0, _mem = 0, _disk = 0;
  double _cpuTarget = 0, _memTarget = 0, _diskTarget = 0;
  late AnimationController _animCtrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() {
          _cpu = _cpuTarget;
          _mem = _memTarget;
          _disk = _diskTarget;
        });
      }
    });
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final results = await Future.wait([
        _getCpuUsage(),
        _getMemUsage(),
        _getDiskUsage(),
      ]);
      if (mounted) {
        setState(() {
          _cpuTarget = results[0];
          _memTarget = results[1];
          _diskTarget = results[2];
        });
        _animCtrl.forward(from: 0);
      }
    } catch (_) {}
  }

  Future<double> _getCpuUsage() async {
    try {
      final ps = await Process.run('ps', ['-A', '-o', '%cpu']);
      final lines = (ps.stdout as String).split('\n');
      double total = 0;
      for (int i = 1; i < lines.length; i++) {
        final v = double.tryParse(lines[i].trim());
        if (v != null) total += v;
      }
      final cores = await Process.run('sysctl', ['-n', 'hw.logicalcpu']);
      final n = int.tryParse((cores.stdout as String).trim()) ?? 1;
      return (total / n).clamp(0, 100);
    } catch (_) {
      return 0;
    }
  }

  Future<double> _getMemUsage() async {
    try {
      final totalR = await Process.run('sysctl', ['-n', 'hw.memsize']);
      final total = int.tryParse((totalR.stdout as String).trim()) ?? 1;
      final vm = await Process.run('vm_stat', []);
      final lines = (vm.stdout as String).split('\n');
      int active = 0, wired = 0;
      for (final line in lines) {
        if (line.contains('Pages active')) {
          active = int.tryParse(RegExp(r'(\d+)').firstMatch(line)?.group(1) ?? '0') ?? 0;
        } else if (line.contains('Pages wired')) {
          wired = int.tryParse(RegExp(r'(\d+)').firstMatch(line)?.group(1) ?? '0') ?? 0;
        }
      }
      final pageSizeR = await Process.run('vm_stat', ['-c', '1']);
      final pageSizeLine = (pageSizeR.stdout as String).split('\n').firstWhere(
        (l) => l.contains('page size'),
        orElse: () => '4096',
      );
      final pageSize = int.tryParse(RegExp(r'(\d+)').firstMatch(pageSizeLine)?.group(1) ?? '4096') ?? 4096;
      final used = (active + wired) * pageSize;
      return ((used / total) * 100).clamp(0, 100);
    } catch (_) {
      return 0;
    }
  }

  Future<double> _getDiskUsage() async {
    try {
      final result = await Process.run('df', ['-k', '/System/Volumes/Data']);
      final lines = (result.stdout as String).split('\n');
      if (lines.length < 2) return 0;
      final parts = lines[1].split(RegExp(r'\s+'));
      if (parts.length < 6) return 0;
      final cap = parts[4].replaceAll('%', '');
      return (int.tryParse(cap) ?? 0).toDouble();
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Row(
      children: [
        _bar(theme, Icons.memory, 'CPU', _cpu, _cpuTarget),
        const SizedBox(width: 8),
        _bar(theme, Icons.developer_board, 'RAM', _mem, _memTarget),
        const SizedBox(width: 8),
        _bar(theme, Icons.storage, 'DISK', _disk, _diskTarget),
      ],
    );
  }

  Widget _bar(ThemeService theme, IconData icon, String label, double pct, double target) {
    final color = target > 80 ? Colors.redAccent : (target > 50 ? Colors.orangeAccent : Colors.greenAccent);
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: theme.secondaryText, size: 10),
          const SizedBox(width: 2),
          Text('$label ${target.toStringAsFixed(0).padLeft(2, '0')}%',
              style: TextStyle(color: theme.primaryText, fontSize: 9)),
          const SizedBox(width: 4),
          Expanded(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_animCtrl.value);
                final value = (pct + (target - pct) * t) / 100;
                return LinearProgressIndicator(
                  value: value,
                  color: color,
                  backgroundColor: theme.inactiveBg,
                  minHeight: 5,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
