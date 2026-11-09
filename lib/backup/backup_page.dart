import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/system.dart';
import '../core/theme.dart';
import '../finance/finance_store.dart';
import '../games/games_store.dart';
import '../habits/habits_store.dart';
import '../news/news_store.dart';
import '../notes/notes_store.dart';
import '../reminders/reminders_store.dart';
import '../settings/settings.dart';
import '../tools/vault.dart';
import '../tools/vault_page.dart';
import '../workout/workout_store.dart';
import 'backup.dart';

class BackupPage extends StatefulWidget {
  final VaultBackend? vaultBackend;

  const BackupPage({super.key, this.vaultBackend});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final BackupService service = BackupService(widget.vaultBackend ?? SecureVaultBackend());
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool includeVault = true;
  bool show = false;
  String? working;

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void _say(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// O backup leva as senhas do cofre: antes de tocar nelas, confirma quem está com o aparelho.
  Future<bool> _confirmIdentity() async {
    final result = await deviceAuth();
    if (result == VaultAuthResult.ok) return true;
    if (mounted) {
      _say(
        result == VaultAuthResult.noDeviceLock
            ? 'Ative um bloqueio de tela no celular para usar o cofre.'
            : 'Não foi possível confirmar sua identidade.',
      );
    }
    return false;
  }

  Future<void> _export() async {
    if (password.text.length < backupMinPassword) {
      _say('Use uma senha com pelo menos $backupMinPassword caracteres');
      return;
    }
    if (password.text != confirm.text) {
      _say('As senhas não são iguais');
      return;
    }
    if (includeVault && !await _confirmIdentity()) return;
    setState(() => working = 'Protegendo o backup…');
    try {
      final content = await service.collect(includeVault: includeVault);
      final bytes = await encryptBackup(content, password.text);
      if (!mounted) return;
      setState(() => working = null);
      final saved = await SystemInfo.saveFile('universal-backup-${dayKey(DateTime.now())}.ubak', bytes);
      if (!saved || !mounted) return;
      await context.read<SettingsStore>().update((s) => s.lastBackup = DateTime.now());
      password.clear();
      confirm.clear();
      _say('Backup salvo');
    } on BackupReadError {
      _say('Não foi possível ler todos os dados. O backup não foi criado.');
    } catch (_) {
      _say('Não foi possível salvar o backup. Tente de novo.');
    } finally {
      if (mounted) setState(() => working = null);
    }
  }

  Future<void> _restore() async {
    final List<int>? bytes;
    try {
      bytes = await SystemInfo.openFile();
    } catch (_) {
      _say('Não foi possível abrir o arquivo.');
      return;
    }
    if (bytes == null || !mounted) return;
    final filePassword = await _askPassword();
    if (filePassword == null || !mounted) return;

    setState(() => working = 'Abrindo o backup…');
    final BackupContent content;
    try {
      content = await decryptBackup(bytes, filePassword);
    } on BackupPasswordError {
      _say('Senha incorreta, ou o arquivo foi alterado.');
      return;
    } on BackupFormatError {
      _say('Este arquivo não é um backup válido do Universal.');
      return;
    } catch (_) {
      _say('Não foi possível abrir o backup.');
      return;
    } finally {
      if (mounted) setState(() => working = null);
    }
    if (!mounted || !await _confirmRestore(content)) return;
    if (content.hasVault && !await _confirmIdentity()) return;
    if (!mounted) return;

    final settings = context.read<SettingsStore>();
    final reminders = context.read<RemindersStore>();
    final habits = context.read<HabitsStore>();
    final notes = context.read<NotesStore>();
    final finance = context.read<FinanceStore>();
    final games = context.read<GamesStore>();
    final news = context.read<NewsStore>();
    final workouts = context.read<WorkoutStore>();
    setState(() => working = 'Restaurando…');
    try {
      await service.restore(content);
      await settings.load();
      await Future.wait([
        reminders.load(),
        habits.load(),
        notes.load(),
        finance.load(),
        games.load(),
        news.load(),
        workouts.load(),
      ]);
      Replanner.request();
      if (mounted) _say('Backup restaurado');
    } on BackupRestoreError {
      if (mounted) _say('Não foi possível restaurar. Seus dados anteriores foram mantidos.');
    } finally {
      if (mounted) setState(() => working = null);
    }
  }

  Future<String?> _askPassword() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Senha do backup'),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Senha'),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Abrir')),
        ],
      ),
    ).whenComplete(c.dispose);
  }

  Future<bool> _confirmRestore(BackupContent c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Substituir os dados atuais?'),
        content: Text(
          'Backup de ${friendlyWhen(c.createdAt)}:\n'
          '${c.reminders} lembretes, ${c.habits} hábitos, ${c.notes} notas e ${c.transactions} lançamentos'
          '${c.hasVault ? ', ${c.vaultEntries} senhas no cofre' : ''}.\n\n'
          'O que está no app agora será trocado por este backup.'
          '${c.hasVault ? '' : ' O cofre de senhas atual não muda, porque este backup não o inclui.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Substituir')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppTheme.textMuted);
    final last = context.watch<SettingsStore>().value.lastBackup;
    final busy = working != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Guarde seus lembretes, hábitos, treinos, notas, finanças, jogos e configurações em um arquivo criptografado. '
            'Salve-o fora do celular, como no Drive, para usar ao trocar de aparelho.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(last == null ? 'Nenhum backup feito ainda.' : 'Último backup: ${friendlyWhen(last)}.', style: muted),
          if (busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            Text(working!, style: muted),
          ],
          const SizedBox(height: 20),
          Text('Criar backup', style: t.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            obscureText: !show,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Crie uma senha para o arquivo',
              suffixIcon: IconButton(
                tooltip: show ? 'Esconder' : 'Mostrar',
                icon: Icon(show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => show = !show),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirm,
            obscureText: !show,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Repita a senha'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: includeVault,
            onChanged: (v) => setState(() => includeVault = v),
            title: const Text('Incluir o cofre de senhas'),
            subtitle: const Text('Pede sua digital ou o bloqueio do celular'),
          ),
          Text(
            'Sem essa senha o backup não pode ser aberto por ninguém, nem por você. Não há como recuperá-la.',
            style: t.bodySmall?.copyWith(color: AppTheme.negative),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : _export,
            icon: const Icon(Icons.save_alt),
            label: const Text('Criar e salvar backup'),
          ),
          const SizedBox(height: 28),
          Text('Restaurar', style: t.titleMedium),
          const SizedBox(height: 6),
          Text('Escolha um arquivo .ubak. Nada muda antes de você confirmar.', style: muted),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const Text('Restaurar de um arquivo'),
          ),
        ],
      ),
    );
  }
}
