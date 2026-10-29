import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../habits/habits_page.dart';
import '../settings/settings.dart';
import 'parser.dart';
import 'recurrence.dart';
import 'reminder.dart';
import 'reminder_editor.dart';
import 'reminders_store.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lembretes'),
          bottom: const TabBar(tabs: [Tab(text: 'Lembretes'), Tab(text: 'Hábitos')]),
        ),
        body: const TabBarView(children: [_RemindersTab(), HabitsTab()]),
      ),
    );
  }
}

class _RemindersTab extends StatelessWidget {
  const _RemindersTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RemindersStore>();
    final pending = store.pending();
    final pendingIds = pending.map((e) => e.reminder.id).toSet();
    final active = store.items.where((r) => r.enabled && !pendingIds.contains(r.id)).toList()
      ..sort((a, b) {
        final na = store.next(a), nb = store.next(b);
        if (na == null) return nb == null ? 0 : 1;
        if (nb == null) return -1;
        return na.compareTo(nb);
      });
    final finished = store.items.where((r) => !r.enabled).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        const QuickAdd(),
        if (pending.isNotEmpty) ...[
          const _Header('Pendentes'),
          for (final o in pending) ReminderTile(reminder: o.reminder, when: o.at, pending: true),
        ],
        const _Header('Ativos'),
        if (active.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhum lembrete ainda. Escreva acima, por exemplo: "toda segunda às 9h pagar academia".'),
          ),
        for (final r in active) ReminderTile(reminder: r, when: store.next(r)),
        if (finished.isNotEmpty) ...[
          const _Header('Concluídos / pausados'),
          for (final r in finished) ReminderTile(reminder: r, when: null),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final DateTime? when;
  final bool pending;

  const ReminderTile({super.key, required this.reminder, required this.when, this.pending = false});

  @override
  Widget build(BuildContext context) {
    final store = context.read<RemindersStore>();
    final r = reminder;
    final sub = [
      if (when != null) (pending ? 'Era ${friendlyWhen(when!)}' : friendlyWhen(when!)),
      describeRecurrence(r.rec),
    ].join(' · ');
    final color = AppTheme.tone(r.category.color);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(r.alarm ? Icons.alarm : r.category.icon, color: color, size: 22),
      ),
      title: Text(r.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: r.enabled ? null : TextDecoration.lineThrough,
            color: r.enabled ? null : AppTheme.textMuted,
          )),
      subtitle: Text(sub,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: pending ? AppTheme.negative : AppTheme.textMuted)),
      trailing: r.enabled
          ? IconButton(
              tooltip: 'Feito',
              icon: Icon(pending ? Icons.check_circle : Icons.check_circle_outline,
                  color: pending ? Theme.of(context).colorScheme.primary : null),
              onPressed: () async {
                await store.done(r, occurrence: when);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${r.title}" concluído')));
                }
              },
            )
          : IconButton(
              tooltip: 'Reativar',
              icon: const Icon(Icons.replay),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ReminderEditor(reminder: r))),
            ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderEditor(reminder: r))),
      onLongPress: r.enabled
          ? () => showModalBottomSheet(
                context: context,
                builder: (c) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final (label, d) in [
                      ('Adiar 10 min', const Duration(minutes: 10)),
                      ('Adiar 1 h', const Duration(hours: 1)),
                      ('Adiar até amanhã', const Duration(days: 1)),
                    ])
                      ListTile(
                        leading: const Icon(Icons.snooze),
                        title: Text(label),
                        onTap: () {
                          Navigator.pop(c);
                          store.snooze(r, d);
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.pause),
                      title: const Text('Pausar'),
                      onTap: () {
                        Navigator.pop(c);
                        r.enabled = false;
                        store.save(r);
                      },
                    ),
                  ]),
                ),
              )
          : null,
    );
  }
}

/// Campo de texto livre com prévia ("Próximo: amanhã 09:00").
class QuickAdd extends StatefulWidget {
  const QuickAdd({super.key});

  @override
  State<QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<QuickAdd> {
  final c = TextEditingController();
  ParsedReminder? parsed;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _onChanged(String s) => setState(() => parsed = s.trim().isEmpty ? null : parseReminder(s));

  Future<void> _save() async {
    final p = parsed;
    if (p == null) return;
    await context.read<RemindersStore>().add(title: p.title, rec: p.recurrence);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lembrete "${p.title.isEmpty ? 'Lembrete' : p.title}" criado')));
    c.clear();
    setState(() => parsed = null);
  }

  Future<void> _adjust() async {
    final p = parsed;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderEditor(draftTitle: p?.title ?? c.text.trim(), draftRec: p?.recurrence),
      ),
    );
    if (saved == true) {
      c.clear();
      setState(() => parsed = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsStore>().value;
    String? preview;
    final p = parsed;
    if (p != null) {
      final n = nextOccurrence(p.recurrence, DateTime.now(), EngineContext(createdAt: DateTime.now(), holidays: s.calendar));
      preview = [
        if (n != null) 'Próximo: ${friendlyWhen(n)}',
        describeRecurrence(p.recurrence),
      ].join(' · ');
    } else if (c.text.trim().isNotEmpty) {
      preview = 'Não entendi a data/hora. Toque em "Ajustar" para escolher.';
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: c,
            onChanged: _onChanged,
            onSubmitted: (_) => _save(),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ex.: amanhã às 15h30 ligar para o banco',
              prefixIcon: Icon(Icons.add_alarm),
              border: OutlineInputBorder(),
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: 8),
            Text(preview, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(onPressed: _adjust, icon: const Icon(Icons.tune), label: const Text('Ajustar')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: parsed == null ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Salvar'),
            ),
          ]),
        ]),
      ),
    );
  }
}
