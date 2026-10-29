import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/settings.dart';
import 'updater.dart';

class UpdateUi {
  /// Checagem automática no máximo a cada 3 h.
  static Future<void> autoCheck(BuildContext context) async {
    final settings = context.read<SettingsStore>();
    final s = settings.value;
    if (!s.autoUpdate) return;
    final last = s.lastUpdateCheck;
    if (last != null && DateTime.now().difference(last).inHours < 3) return;
    await settings.update((x) => x.lastUpdateCheck = DateTime.now());
    try {
      final info = await Updater.check();
      if (info != null && context.mounted) await _offer(context, info);
    } catch (_) {}
  }

  static Future<void> manualCheck(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsStore>();
    messenger.showSnackBar(const SnackBar(content: Text('Verificando…'), duration: Duration(seconds: 1)));
    try {
      final info = await Updater.check();
      await settings.update((x) => x.lastUpdateCheck = DateTime.now());
      if (!context.mounted) return;
      if (info == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Você já tem a versão mais recente.')));
      } else {
        await _offer(context, info);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível verificar: $e')));
    }
  }

  static Future<void> _offer(BuildContext context, UpdateInfo info) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Nova versão ${info.tag}'),
        content: SingleChildScrollView(child: Text(info.notes.isEmpty ? 'Melhorias e correções.' : info.notes)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Depois')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Atualizar')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _DownloadDialog(info: info));
    }
  }
}

class _DownloadDialog extends StatefulWidget {
  final UpdateInfo info;

  const _DownloadDialog({required this.info});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double? progress;
  String? error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final f = await Updater.download(widget.info.apkUrl, (p) {
        if (mounted) setState(() => progress = p);
      });
      final err = await Updater.install(f);
      if (!mounted) return;
      if (err != null) {
        setState(() => error = 'Não foi possível abrir o instalador: $err\n'
            'Permita "Instalar apps desconhecidos" para o Universal nas configurações do Android.');
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Falha no download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Baixando atualização'),
      content: error != null
          ? Text(error!)
          : Column(mainAxisSize: MainAxisSize.min, children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(progress == null ? 'Baixando…' : '${(progress! * 100).round()}%'),
            ]),
      actions: [
        if (error != null) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }
}
