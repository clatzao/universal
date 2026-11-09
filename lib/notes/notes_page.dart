import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../finance/finance.dart';
import '../finance/finance_forms.dart';
import '../finance/finance_store.dart';
import '../reminders/reminder_editor.dart';
import 'note.dart';
import 'notes_store.dart';

void openNote(BuildContext context, Note n) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: n.id)));

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final search = TextEditingController();
  NoteKind? kind;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _create(NoteKind k) => openNote(context, context.read<NotesStore>().create(k));

  void _delete(NotesStore store, Note n) {
    store.remove(n);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${n.displayTitle}" excluída'),
          action: SnackBarAction(label: 'Desfazer', onPressed: () => store.restore(n)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    final list = store.sorted(query: search.text, kind: kind);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notas')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'nova-lista',
            tooltip: 'Nova lista',
            backgroundColor: AppTheme.surfaceHighest,
            foregroundColor: AppTheme.text,
            onPressed: () => _create(NoteKind.lista),
            child: const Icon(Icons.checklist),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'nova-nota',
            onPressed: () => _create(NoteKind.nota),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Nota'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 150),
        children: [
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(search.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tudo'),
                selected: kind == null,
                onSelected: (_) => setState(() => kind = null),
              ),
              ChoiceChip(
                label: const Text('Notas'),
                selected: kind == NoteKind.nota,
                onSelected: (_) => setState(() => kind = NoteKind.nota),
              ),
              ChoiceChip(
                label: const Text('Listas'),
                selected: kind == NoteKind.lista,
                onSelected: (_) => setState(() => kind = NoteKind.lista),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                store.items.isEmpty
                    ? 'Anote ideias e monte listas de compras ou de tarefas. Toque nos botões abaixo para começar.'
                    : 'Nada encontrado.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
            ),
          for (final n in list)
            Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppTheme.negative.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline),
              ),
              onDismissed: (_) => _delete(store, n),
              child: NoteCard(note: n),
            ),
        ],
      ),
    );
  }
}

/// Cartão com a prévia da nota ou da lista. Toque abre; toque longo fixa.
class NoteCard extends StatelessWidget {
  final Note note;

  const NoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final n = note;
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppTheme.textMuted);
    final total = n.items.where((i) => i.text.trim().isNotEmpty).length;
    final done = n.completed.where((i) => i.text.trim().isNotEmpty).length;
    final preview = n.pending.where((i) => i.text.trim().isNotEmpty).take(3).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => openNote(context, n),
        onLongPress: () {
          HapticFeedback.selectionClick();
          context.read<NotesStore>().togglePin(n);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(n.kind == NoteKind.lista ? Icons.checklist : Icons.notes, size: 18, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(n.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  ),
                  if (n.pinned) const Icon(Icons.push_pin, size: 16, color: AppTheme.textMuted),
                ],
              ),
              if (n.kind == NoteKind.nota && n.body.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(n.body.trim(), maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
              ],
              if (n.kind == NoteKind.lista && total > 0) ...[
                const SizedBox(height: 8),
                for (final i in preview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.check_box_outline_blank, size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(i.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: done / total,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  color: done == total ? AppTheme.positive : AppTheme.accent,
                ),
                const SizedBox(height: 4),
                Text('$done de $total concluídos', style: muted),
              ],
              const SizedBox(height: 6),
              Text(ago(n.updatedAt), style: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  final String noteId;

  const NoteEditorPage({super.key, required this.noteId});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final NotesStore store = context.read<NotesStore>();
  late final Note note = store.byId(widget.noteId)!;
  late final title = TextEditingController(text: note.title);
  late final body = TextEditingController(text: note.body);
  final newItem = TextEditingController();
  final newItemFocus = FocusNode();
  Timer? _saveTimer;
  bool _deleted = false;
  bool _showDone = true;

  void _changed() {
    store.touch(note);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), store.persist);
  }

  void _update(VoidCallback change) {
    setState(change);
    _changed();
  }

  void _addItem() {
    final text = newItem.text.trim();
    if (text.isEmpty) return;
    _update(() => note.items.add(NoteItem(id: NotesStore.newId(), text: text)));
    newItem.clear();
    newItemFocus.requestFocus();
  }

  void _toggle(NoteItem item, bool done) {
    HapticFeedback.selectionClick();
    _update(() => item.done = done);
  }

  void _removeItem(NoteItem item) {
    final index = note.items.indexOf(item);
    _update(() => note.items.remove(item));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${item.text}" removido'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              if (!mounted) return;
              _update(() => note.items.insert(index.clamp(0, note.items.length), item));
            },
          ),
        ),
      );
  }

  /// A posição vale só entre os itens pendentes, os únicos que aparecem para arrastar.
  void _reorder(int from, int to) {
    final pending = note.pending;
    final moved = pending[from];
    _update(() {
      pending
        ..removeAt(from)
        ..insert(to, moved);
      note.items = [...pending, ...note.completed];
    });
  }

  void _toggleShopping() => _update(() => note.shopping = !note.shopping);

  Future<void> _editPrice(NoteItem item) async {
    final price = TextEditingController(
      text: item.price == null ? '' : (item.price! / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    final qty = TextEditingController(text: '${item.qty}');
    final result = await showDialog<(int?, int)>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(item.text.trim().isEmpty ? 'Preço' : item.text.trim()),
        content: Row(
          children: [
            SizedBox(
              width: 72,
              child: TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Qtd.'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AmountField(controller: price, label: 'Preço da unidade', autofocus: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(d, (parseCents(price.text), (int.tryParse(qty.text) ?? 1).clamp(1, 999))),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    _update(() {
      item.price = result.$1 == null || result.$1! <= 0 ? null : result.$1;
      item.qty = result.$2;
    });
  }

  /// Os itens marcados são os que foram para o carrinho: a soma deles vira um gasto em Mercado.
  Future<void> _launchPurchase() async {
    final finance = context.read<FinanceStore>();
    final amount = TextEditingController(
      text: (shoppingTotal(note.completed) / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    var accountId = finance.defaultAccount.id;
    var uncheck = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setDialog) => AlertDialog(
          title: const Text('Lançar compra em Finanças'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AmountField(controller: amount, label: 'Valor pago'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Conta'),
                items: [for (final a in finance.accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
                onChanged: (v) => setDialog(() => accountId = v!),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: uncheck,
                onChanged: (v) => setDialog(() => uncheck = v ?? true),
                title: const Text('Desmarcar os itens para a próxima compra'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Lançar')),
          ],
        ),
      ),
    );
    final cents = parseCents(amount.text);
    if (ok != true || !mounted) return;
    if (cents == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o valor pago')));
      return;
    }
    final now = DateTime.now();
    final saving = finance.addTx(
      kind: TxKind.expense,
      amount: cents,
      date: now,
      category: FinCategory.mercado,
      accountId: accountId,
      description: note.displayTitle,
    );
    if (uncheck) {
      _update(() {
        for (final i in note.items) {
          i.done = false;
        }
      });
    }
    final messenger = ScaffoldMessenger.of(context);
    await saving;
    messenger.showSnackBar(SnackBar(content: Text('Compra de ${brl(cents)} lançada em Finanças')));
    if (mounted) showBudgetWarning(context, finance, FinCategory.mercado, now);
  }

  void _convert() {
    _update(() => note.convert(NotesStore.newId));
    body.text = note.body;
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: note.toPlainText()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado')));
  }

  void _remind() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderEditor(draftTitle: note.displayTitle)));

  void _delete() {
    final messenger = ScaffoldMessenger.of(context);
    _deleted = true;
    store.remove(note);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${note.displayTitle}" excluída'),
          action: SnackBarAction(label: 'Desfazer', onPressed: () => store.restore(note)),
        ),
      );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    title.dispose();
    body.dispose();
    newItem.dispose();
    newItemFocus.dispose();
    // Fora da fase de desmontagem, porque avisa as telas que observam o store.
    if (!_deleted) scheduleMicrotask(() => store.finishEditing(note));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isList = note.kind == NoteKind.lista;
    final t = Theme.of(context).textTheme;
    final titleField = TextField(
      controller: title,
      autofocus: note.isEmpty && !isList,
      textCapitalization: TextCapitalization.sentences,
      style: t.titleLarge,
      onChanged: (v) {
        note.title = v;
        _changed();
      },
      decoration: const InputDecoration(
        hintText: 'Título',
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: note.pinned ? 'Desafixar' : 'Fixar',
            icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => setState(() => store.togglePin(note)),
          ),
          IconButton(tooltip: 'Criar lembrete', icon: const Icon(Icons.add_alarm), onPressed: _remind),
          PopupMenuButton<VoidCallback>(
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: _copy, child: const Text('Copiar texto')),
              PopupMenuItem(value: _convert, child: Text(isList ? 'Transformar em nota' : 'Transformar em lista')),
              if (isList)
                PopupMenuItem(
                  value: _toggleShopping,
                  child: Text(note.shopping ? 'Tirar os preços' : 'Usar como lista de compras'),
                ),
              PopupMenuItem(value: _delete, child: const Text('Excluir')),
            ],
          ),
        ],
      ),
      body: isList ? _listBody(titleField) : _noteBody(titleField),
    );
  }

  Widget _noteBody(Widget titleField) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
    children: [
      titleField,
      const SizedBox(height: 8),
      TextField(
        controller: body,
        maxLines: null,
        minLines: 12,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (v) {
          note.body = v;
          _changed();
        },
        decoration: const InputDecoration(
          hintText: 'Escreva aqui',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ],
  );

  Widget _listBody(Widget titleField) {
    final pending = note.pending;
    final completed = note.completed;
    final t = Theme.of(context).textTheme;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 40),
      onReorderItem: _reorder,
      header: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: titleField),
      itemCount: pending.length,
      itemBuilder: (_, i) {
        final item = pending[i];
        return _ItemRow(
          key: ValueKey(item.id),
          item: item,
          index: i,
          onToggle: (v) => _toggle(item, v),
          onText: (v) {
            item.text = v;
            _changed();
          },
          onRemove: () => _removeItem(item),
          onPrice: note.shopping ? () => _editPrice(item) : null,
        );
      },
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: TextField(
              controller: newItem,
              focusNode: newItemFocus,
              autofocus: note.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _addItem(),
              decoration: InputDecoration(
                hintText: 'Adicionar item',
                prefixIcon: const Icon(Icons.add),
                suffixIcon: IconButton(
                  tooltip: 'Adicionar',
                  icon: const Icon(Icons.keyboard_return),
                  onPressed: _addItem,
                ),
              ),
            ),
          ),
          if (note.shopping) ...[
            const SizedBox(height: 12),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('No carrinho: ${brl(shoppingTotal(completed))}', style: t.titleSmall),
                    Text(
                      'Lista toda: ${brl(shoppingTotal(note.items))} · marque o que já pegou',
                      style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _launchPurchase,
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text('Lançar compra'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showDone = !_showDone),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(_showDone ? Icons.expand_less : Icons.expand_more, size: 20, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Concluídos (${completed.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelLarge?.copyWith(color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Desmarcar todos',
                  icon: const Icon(Icons.remove_done, size: 20, color: AppTheme.textMuted),
                  onPressed: () => _update(() {
                    for (final i in note.items) {
                      i.done = false;
                    }
                  }),
                ),
                IconButton(
                  tooltip: 'Apagar concluídos',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: AppTheme.textMuted),
                  onPressed: () => _update(() => note.items.removeWhere((i) => i.done)),
                ),
              ],
            ),
            if (_showDone)
              for (final item in completed)
                CheckboxListTile(
                  key: ValueKey('done-${item.id}'),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: true,
                  onChanged: (v) => _toggle(item, v ?? false),
                  title: Text(
                    item.text,
                    style: const TextStyle(color: AppTheme.textMuted, decoration: TextDecoration.lineThrough),
                  ),
                  secondary: note.shopping
                      ? TextButton(onPressed: () => _editPrice(item), child: Text(_priceLabel(item)))
                      : null,
                ),
          ],
        ],
      ),
    );
  }
}

String _priceLabel(NoteItem i) {
  if (i.price == null) return 'Preço';
  return i.qty == 1 ? brl(i.price!) : '${i.qty} × ${brl(i.price!)}';
}

class _ItemRow extends StatefulWidget {
  final NoteItem item;
  final int index;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onText;
  final VoidCallback onRemove;

  /// Só nas listas de compras.
  final VoidCallback? onPrice;

  const _ItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.onToggle,
    required this.onText,
    required this.onRemove,
    this.onPrice,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final c = TextEditingController(text: widget.item.text);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Icon(Icons.drag_indicator, size: 20, color: AppTheme.textMuted),
            ),
          ),
          Checkbox(value: false, onChanged: (v) => widget.onToggle(v ?? false)),
          Expanded(
            child: TextField(
              controller: c,
              textCapitalization: TextCapitalization.sentences,
              onChanged: widget.onText,
              decoration: const InputDecoration(
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (widget.onPrice != null)
            TextButton(
              onPressed: widget.onPrice,
              style: TextButton.styleFrom(
                foregroundColor: widget.item.price == null ? AppTheme.textMuted : null,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(_priceLabel(widget.item)),
            ),
          IconButton(
            tooltip: 'Remover',
            icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
