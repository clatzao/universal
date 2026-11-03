import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/system.dart';
import '../core/theme.dart';
import 'tools_logic.dart';
import 'vault.dart';

/// Resultado de pedir a digital, o rosto ou o bloqueio de tela do aparelho.
enum VaultAuthResult { ok, canceled, noDeviceLock }

Future<VaultAuthResult> deviceAuth() async {
  final auth = LocalAuthentication();
  if (!await auth.isDeviceSupported()) return VaultAuthResult.noDeviceLock;
  try {
    final ok = await auth.authenticate(localizedReason: 'Abrir o cofre de senhas', persistAcrossBackgrounding: true);
    return ok ? VaultAuthResult.ok : VaultAuthResult.canceled;
  } on LocalAuthException catch (e) {
    if (e.code == LocalAuthExceptionCode.noCredentialsSet) return VaultAuthResult.noDeviceLock;
    return VaultAuthResult.canceled;
  }
}

class VaultPage extends StatefulWidget {
  final VaultBackend? backend;
  final Future<VaultAuthResult> Function() auth;

  const VaultPage({super.key, this.backend, this.auth = deviceAuth});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> with WidgetsBindingObserver {
  late final VaultStore store = VaultStore(widget.backend ?? SecureVaultBackend());
  final search = TextEditingController();
  bool _authenticating = false;
  String? _message;
  bool _readFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sem capturas de tela e sem prévia do cofre na lista de apps recentes.
    SystemInfo.setSecure(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemInfo.setSecure(false);
    store.lock();
    store.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.hidden || state == AppLifecycleState.paused) && !_authenticating) _lock();
  }

  void _lock() {
    if (!store.isOpen) return;
    final route = ModalRoute.of(context);
    Navigator.of(context).popUntil((r) => r == route);
    search.clear();
    store.lock();
    setState(() => _message = null);
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    final result = await widget.auth();
    if (!mounted) return;
    _authenticating = false;
    if (result == VaultAuthResult.ok) {
      try {
        await store.open();
        _readFailed = false;
      } on VaultReadError {
        _readFailed = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _message = switch (result) {
        VaultAuthResult.noDeviceLock =>
          'Para usar o cofre, ative um bloqueio de tela no celular (PIN, padrão ou digital).',
        VaultAuthResult.canceled => 'Não foi possível confirmar sua identidade.',
        VaultAuthResult.ok =>
          _readFailed ? 'Não foi possível ler o cofre. Nada foi apagado; tente de novo mais tarde.' : null,
      };
    });
  }

  Future<void> _edit([VaultEntry? entry]) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VaultEntryPage(store: store, entry: entry),
    ),
  );

  void _copy(String value, String what) {
    copySensitive(value);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what copiado. Será limpo em 30 s.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Cofre de senhas'),
          actions: [
            if (store.isOpen) IconButton(tooltip: 'Trancar', icon: const Icon(Icons.lock_outline), onPressed: _lock),
          ],
        ),
        floatingActionButton: store.isOpen
            ? FloatingActionButton.extended(
                onPressed: _edit,
                icon: const Icon(Icons.add),
                label: const Text('Nova senha'),
              )
            : null,
        body: store.isOpen ? _openBody() : _lockedBody(),
      ),
    );
  }

  Widget _lockedBody() {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('Cofre trancado', style: t.titleLarge),
            const SizedBox(height: 8),
            Text(
              _message ?? 'Use a digital, o rosto ou o bloqueio de tela do celular para abrir.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _authenticating ? null : _unlock,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Abrir cofre'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _openBody() {
    final t = Theme.of(context).textTheme;
    final list = store.search(search.text);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Buscar', prefixIcon: Icon(Icons.search)),
        ),
        const SizedBox(height: 12),
        if (store.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nenhuma senha guardada ainda.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
            ),
          ),
        for (final e in list)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(e.name.isEmpty ? 'Sem nome' : e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: e.username.isEmpty
                  ? null
                  : Text(
                      e.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.username.isNotEmpty)
                    IconButton(
                      tooltip: 'Copiar usuário',
                      icon: const Icon(Icons.person_outline, size: 20),
                      onPressed: () => _copy(e.username, 'Usuário'),
                    ),
                  IconButton(
                    tooltip: 'Copiar senha',
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copy(e.password, 'Senha'),
                  ),
                ],
              ),
              onTap: () => _edit(e),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'As senhas ficam criptografadas só neste aparelho, sem cópia na nuvem. '
          'Se você desinstalar o app ou trocar de celular, elas serão perdidas.',
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class VaultEntryPage extends StatefulWidget {
  final VaultStore store;
  final VaultEntry? entry;

  const VaultEntryPage({super.key, required this.store, this.entry});

  @override
  State<VaultEntryPage> createState() => _VaultEntryPageState();
}

class _VaultEntryPageState extends State<VaultEntryPage> {
  late final name = TextEditingController(text: widget.entry?.name);
  late final username = TextEditingController(text: widget.entry?.username);
  late final password = TextEditingController(text: widget.entry?.password);
  late final site = TextEditingController(text: widget.entry?.site);
  late final notes = TextEditingController(text: widget.entry?.notes);
  bool _show = false;

  @override
  void dispose() {
    for (final c in [name, username, password, site, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (name.text.trim().isEmpty || password.text.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Informe o nome e a senha')));
      return;
    }
    final entry = VaultEntry(
      id: widget.entry?.id ?? VaultStore.newId(),
      name: name.text.trim(),
      username: username.text.trim(),
      password: password.text,
      site: site.text.trim(),
      notes: notes.text.trim(),
      updatedAt: DateTime.now(),
    );
    try {
      await widget.store.save(entry);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível salvar. Tente de novo.')));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir esta senha?'),
        content: const Text('Não dá para desfazer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.remove(widget.entry!);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível excluir. Tente de novo.')));
    }
  }

  Future<void> _generate() async {
    var length = 16.0;
    var upper = true, digits = true, symbols = true;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Gerar senha com ${length.round()} caracteres', style: Theme.of(c).textTheme.titleMedium),
                Slider(value: length, min: 8, max: 32, divisions: 24, onChanged: (v) => set(() => length = v)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Maiúsculas'),
                  value: upper,
                  onChanged: (v) => set(() => upper = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Números'),
                  value: digits,
                  onChanged: (v) => set(() => digits = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Símbolos'),
                  value: symbols,
                  onChanged: (v) => set(() => symbols = v),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      password.text = generatePassword(
                        length: length.round(),
                        upper: upper,
                        digits: digits,
                        symbols: symbols,
                      );
                      _show = true;
                    });
                    Navigator.pop(c);
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Gerar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final web = Uri.tryParse(site.text.trim().contains('://') ? site.text.trim() : 'https://${site.text.trim()}');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Nova senha' : 'Editar senha'),
        actions: [
          if (widget.entry != null)
            IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome (ex.: Banco, e-mail)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: username,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Usuário ou e-mail'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: !_show,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(
              labelText: 'Senha',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _show ? 'Esconder' : 'Mostrar',
                    icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                  IconButton(tooltip: 'Gerar senha', icon: const Icon(Icons.auto_awesome), onPressed: _generate),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: site,
            autocorrect: false,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Site (opcional)',
              suffixIcon: site.text.trim().isEmpty || web == null || !web.hasAuthority
                  ? null
                  : IconButton(
                      tooltip: 'Abrir site',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => launchUrl(web, mode: LaunchMode.externalApplication),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notes,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Observações (opcional)'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Salvar')),
        ],
      ),
    );
  }
}
