import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/text_norm.dart';
import '../core/theme.dart';
import '../finance/finance.dart';
import '../finance/finance_forms.dart';
import '../finance/finance_store.dart';
import '../notes/note.dart';
import '../notes/notes_page.dart';
import '../notes/notes_store.dart';
import '../reminders/reminder.dart';
import '../reminders/reminder_editor.dart';
import '../reminders/reminders_store.dart';

class SearchResults {
  final List<Reminder> reminders;
  final List<Note> notes;
  final List<Tx> txs;

  const SearchResults(this.reminders, this.notes, this.txs);

  bool get isEmpty => reminders.isEmpty && notes.isEmpty && txs.isEmpty;
}

/// Todas as palavras precisam aparecer, sem diferenciar maiúsculas nem acentos.
bool matchesAllWords(String query, Iterable<String> fields) {
  final text = normalizeKeepLength(fields.join(' '));
  final words = normalizeKeepLength(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.isNotEmpty && words.every(text.contains);
}

SearchResults searchAll(
  String query, {
  required List<Reminder> reminders,
  required List<Note> notes,
  required List<Tx> txs,
  String Function(String id)? accountName,
}) {
  return SearchResults(
    reminders.where((r) => matchesAllWords(query, [r.title, r.notes, r.category.label])).toList(),
    notes.where((n) => matchesAllWords(query, [n.toPlainText()])).toList(),
    txs
        .where(
          (t) => matchesAllWords(query, [
            t.title,
            if (t.kind != TxKind.transfer) t.category.label,
            accountName?.call(t.accountId) ?? '',
            brl(t.amount),
          ]),
        )
        .toList(),
  );
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final input = TextEditingController();

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceStore>();
    final query = input.text.trim();
    final results = searchAll(
      query,
      reminders: context.watch<RemindersStore>().items,
      notes: context.watch<NotesStore>().sorted(),
      txs: finance.txs,
      accountName: (id) => finance.account(id)?.name ?? '',
    );
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: input,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Notas, lembretes e lançamentos',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: query.isEmpty
                ? null
                : IconButton(tooltip: 'Limpar', icon: const Icon(Icons.close), onPressed: () => setState(input.clear)),
          ),
        ),
      ),
      body: query.isEmpty
          ? const _Hint('Digite para procurar em todo o app.')
          : results.isEmpty
          ? _Hint('Nada encontrado para "$query".')
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                if (results.reminders.isNotEmpty) const _Header('Lembretes'),
                for (final r in results.reminders)
                  _Hit(
                    icon: r.category.icon,
                    title: r.title,
                    subtitle: r.category.label,
                    onTap: () => _open(ReminderEditor(reminder: r)),
                  ),
                if (results.notes.isNotEmpty) const _Header('Notas'),
                for (final n in results.notes)
                  _Hit(
                    icon: n.kind == NoteKind.lista ? Icons.checklist : Icons.sticky_note_2_outlined,
                    title: n.displayTitle,
                    subtitle: friendlyWhen(n.updatedAt),
                    onTap: () => openNote(context, n),
                  ),
                if (results.txs.isNotEmpty) const _Header('Lançamentos'),
                for (final t in results.txs.take(100))
                  _Hit(
                    icon: t.kind == TxKind.transfer ? Icons.swap_horiz : t.category.icon,
                    title: t.title,
                    subtitle: '${brl(t.amount)} · ${two(t.date.day)}/${two(t.date.month)}/${t.date.year}',
                    onTap: () => _open(TxEditor(tx: t)),
                  ),
              ],
            ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textMuted),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Hit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Hit({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted)),
      onTap: onTap,
    ),
  );
}
