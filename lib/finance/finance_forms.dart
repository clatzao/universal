import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../reminders/recurrence.dart';
import '../reminders/reminder.dart';
import '../reminders/reminders_store.dart';
import 'finance.dart';
import 'finance_store.dart';

String _centsText(int c) => c == 0 ? '' : (c / 100).toStringAsFixed(2).replaceAll('.', ',');

/// Aviso de orçamento depois de um gasto (80% e estourado).
void showBudgetWarning(BuildContext context, FinanceStore store, FinCategory c, DateTime date) {
  final b = store.budget(c, date);
  if (b == null || b.ratio < 0.8) return;
  final msg = b.ratio >= 1
      ? 'Orçamento de ${c.label} estourado: ${brl(b.spent)} de ${brl(b.limit)}'
      : 'Atenção: ${(b.ratio * 100).round()}% do orçamento de ${c.label} usado';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;

  const AmountField({super.key, required this.controller, this.label = 'Valor', this.autofocus = false});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(labelText: label, prefixText: 'R\$ '),
  );
}

Widget _accountDropdown(
  FinanceStore store,
  String? value,
  ValueChanged<String?> onChanged, {
  String label = 'Conta',
  bool Function(Account)? where,
}) {
  final list = store.accounts.where(where ?? (_) => true).toList();
  return DropdownButtonFormField<String>(
    initialValue: list.any((a) => a.id == value) ? value : (list.isEmpty ? null : list.first.id),
    decoration: InputDecoration(labelText: label),
    items: [
      for (final a in list)
        DropdownMenuItem(
          value: a.id,
          child: Row(children: [Icon(a.type.icon, size: 18), const SizedBox(width: 8), Text(a.name)]),
        ),
    ],
    onChanged: onChanged,
  );
}

Widget _categoryDropdown(TxKind kind, FinCategory value, ValueChanged<FinCategory> onChanged) {
  final list = FinCategory.forKind(kind);
  return DropdownButtonFormField<FinCategory>(
    initialValue: list.contains(value) ? value : list.first,
    decoration: const InputDecoration(labelText: 'Categoria'),
    items: [
      for (final c in list)
        DropdownMenuItem(
          value: c,
          child: Row(
            children: [
              Icon(c.icon, size: 18, color: c.color),
              const SizedBox(width: 8),
              Text(c.label),
            ],
          ),
        ),
    ],
    onChanged: (c) => c == null ? null : onChanged(c),
  );
}

// ---------- Lançamento rápido ----------

class QuickTxSheet extends StatefulWidget {
  const QuickTxSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const QuickTxSheet());

  @override
  State<QuickTxSheet> createState() => _QuickTxSheetState();
}

class _QuickTxSheetState extends State<QuickTxSheet> {
  final c = TextEditingController();
  ParsedTx? parsed;
  String? accountId;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _onChanged(String s) {
    final store = context.read<FinanceStore>();
    final p = parseTx(s);
    setState(() {
      parsed = p;
      // Parcelado vai para o cartão por padrão.
      if (p != null && p.installments > 1 && store.firstCard != null && !(store.account(accountId)?.isCard ?? false)) {
        accountId = store.firstCard!.id;
      }
    });
  }

  Future<void> _save() async {
    final p = parsed;
    if (p == null) return;
    final store = context.read<FinanceStore>();
    final acc = store.account(accountId) ?? store.defaultAccount;
    final messenger = ScaffoldMessenger.of(context);
    final created = await store.addTx(
      kind: p.kind,
      amount: p.amount,
      date: DateTime.now(),
      category: p.category,
      accountId: acc.id,
      description: p.description,
      installments: acc.isCard ? p.installments : 1,
    );
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${p.kind == TxKind.income ? 'Entrada' : 'Gasto'} de ${brl(p.amount)} lançado'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            for (final t in created) {
              await store.removeTx(t);
            }
          },
        ),
      ),
    );
    if (p.kind == TxKind.expense && mounted) showBudgetWarning(context, store, p.category, DateTime.now());
  }

  Future<void> _details() async {
    final p = parsed;
    final store = context.read<FinanceStore>();
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TxEditor(draft: p, draftAccountId: accountId ?? store.defaultAccount.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final t = Theme.of(context).textTheme;
    final p = parsed;
    final acc = store.account(accountId) ?? store.defaultAccount;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Novo lançamento', style: t.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Ex.: "mercado 85,90", "tênis 300 em 3x", "+ salário 3500"',
            style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: c,
            autofocus: true,
            onChanged: _onChanged,
            onSubmitted: (_) => _save(),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'O que e quanto?', prefixIcon: Icon(Icons.bolt)),
          ),
          const SizedBox(height: 12),
          if (p != null)
            Row(
              children: [
                Icon(p.category.icon, color: p.category.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      p.kind == TxKind.income ? 'Entrada' : 'Gasto',
                      if (p.description.isNotEmpty) p.description,
                      p.category.label,
                      if (p.installments > 1 && acc.isCard)
                        '${p.installments}x de ${brl(splitInstallments(p.amount, p.installments).last)}',
                    ].join(' · '),
                    style: t.bodyMedium,
                  ),
                ),
                Text(
                  brl(p.amount),
                  style: t.titleMedium?.copyWith(color: p.kind == TxKind.income ? AppTheme.positive : AppTheme.text),
                ),
              ],
            )
          else if (c.text.trim().isNotEmpty)
            Text('Inclua um valor, ex.: "uber 23".', style: t.bodySmall?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final a in store.accounts)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(a.type.icon, size: 16),
                      label: Text(a.name),
                      selected: a.id == acc.id,
                      onSelected: (_) => setState(() => accountId = a.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(onPressed: _details, icon: const Icon(Icons.tune), label: const Text('Detalhes')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: p == null ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('Lançar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Editor de lançamento ----------

class TxEditor extends StatefulWidget {
  final Tx? tx;
  final ParsedTx? draft;
  final String? draftAccountId;

  const TxEditor({super.key, this.tx, this.draft, this.draftAccountId});

  @override
  State<TxEditor> createState() => _TxEditorState();
}

class _TxEditorState extends State<TxEditor> {
  late TxKind kind;
  late TextEditingController amount;
  late TextEditingController desc;
  late FinCategory category;
  late DateTime date;
  String? accountId;
  String? toAccountId;
  int installments = 1;

  @override
  void initState() {
    super.initState();
    final t = widget.tx;
    final d = widget.draft;
    final store = context.read<FinanceStore>();
    kind = t?.kind ?? d?.kind ?? TxKind.expense;
    amount = TextEditingController(text: _centsText(t?.amount ?? d?.amount ?? 0));
    desc = TextEditingController(text: t?.description ?? d?.description ?? '');
    category = t?.category ?? d?.category ?? FinCategory.forKind(kind).first;
    date = t?.date ?? DateTime.now();
    accountId = t?.accountId ?? widget.draftAccountId ?? store.defaultAccount.id;
    toAccountId = t?.toAccountId;
    installments = d?.installments ?? 1;
  }

  @override
  void dispose() {
    amount.dispose();
    desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<FinanceStore>();
    final cents = parseCents(amount.text);
    if (cents == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um valor')));
      return;
    }
    final acc = store.account(accountId) ?? store.defaultAccount;
    if (kind == TxKind.transfer && (toAccountId == null || toAccountId == acc.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha a conta de destino')));
      return;
    }
    final t = widget.tx;
    if (t != null) {
      t
        ..kind = kind
        ..amount = cents
        ..description = desc.text.trim()
        ..category = category
        ..date = date
        ..accountId = acc.id
        ..toAccountId = kind == TxKind.transfer ? toAccountId : null;
      await store.updateTx(t);
    } else {
      await store.addTx(
        kind: kind,
        amount: cents,
        date: date,
        category: category,
        accountId: acc.id,
        toAccountId: toAccountId,
        description: desc.text.trim(),
        installments: acc.isCard ? installments : 1,
      );
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (kind == TxKind.expense) showBudgetWarning(context, store, category, date);
    nav.pop();
  }

  Future<void> _delete() async {
    final store = context.read<FinanceStore>();
    final t = widget.tx!;
    var whole = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Excluir lançamento?'),
          content: t.installments > 1
              ? CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: whole,
                  onChanged: (v) => set(() => whole = v ?? false),
                  title: Text('Excluir as ${t.installments} parcelas'),
                )
              : null,
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await store.removeTx(t, wholeGroup: whole);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final acc = store.account(accountId);
    final cents = parseCents(amount.text) ?? 0;
    final editing = widget.tx != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar lançamento' : 'Novo lançamento'),
        actions: [
          if (editing) IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TxKind>(
            segments: const [
              ButtonSegment(value: TxKind.expense, label: Text('Gasto'), icon: Icon(Icons.south_west)),
              ButtonSegment(value: TxKind.income, label: Text('Entrada'), icon: Icon(Icons.north_east)),
              ButtonSegment(value: TxKind.transfer, label: Text('Transferir'), icon: Icon(Icons.swap_horiz)),
            ],
            selected: {kind},
            onSelectionChanged: (s) => setState(() {
              kind = s.first;
              if (!FinCategory.forKind(kind).contains(category)) category = FinCategory.forKind(kind).first;
            }),
          ),
          const SizedBox(height: 16),
          AmountField(controller: amount, autofocus: !editing && widget.draft == null),
          const SizedBox(height: 12),
          TextField(
            controller: desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          const SizedBox(height: 12),
          if (kind != TxKind.transfer) ...[
            _categoryDropdown(kind, category, (c) => setState(() => category = c)),
            const SizedBox(height: 12),
          ],
          _accountDropdown(
            store,
            accountId,
            (v) => setState(() => accountId = v),
            label: kind == TxKind.transfer ? 'De' : 'Conta',
          ),
          if (kind == TxKind.transfer) ...[
            const SizedBox(height: 12),
            _accountDropdown(
              store,
              toAccountId,
              (v) => setState(() => toAccountId = v),
              label: 'Para',
              where: (a) => a.id != accountId,
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text('${two(date.day)}/${two(date.month)}/${date.year}'),
            subtitle: const Text('Data'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => date = DateTime(d.year, d.month, d.day, date.hour, date.minute));
            },
          ),
          if (!editing && kind == TxKind.expense && (acc?.isCard ?? false)) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('Parcelas')),
                IconButton(
                  onPressed: installments > 1 ? () => setState(() => installments--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('${installments}x', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  onPressed: installments < 48 ? () => setState(() => installments++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (installments > 1 && cents > 0)
              Text(
                '${installments}x de ${brl(splitInstallments(cents, installments).last)} · 1ª parcela na fatura de '
                '${_monthName(invoiceMonth(date, acc!.closingDay, acc.dueDay))}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
          ],
          if (editing && widget.tx!.installments > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Parcela ${widget.tx!.installment} de ${widget.tx!.installments}. A edição vale só para esta parcela.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Salvar')),
        ],
      ),
    );
  }
}

const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String _monthName(DateTime m) => '${_months[m.month - 1]}/${m.year}';

String monthTitle(DateTime m) {
  final s = '${_months[m.month - 1]} de ${m.year}';
  return s[0].toUpperCase() + s.substring(1);
}

String monthShort(DateTime m) => _months[m.month - 1].substring(0, 3);

// ---------- Conta ----------

class AccountEditor extends StatefulWidget {
  final Account? account;

  const AccountEditor({super.key, this.account});

  @override
  State<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<AccountEditor> {
  late TextEditingController name;
  late TextEditingController initial;
  late TextEditingController limit;
  late AccountType type;
  late int closing;
  late int due;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    name = TextEditingController(text: a?.name ?? '');
    type = a?.type ?? AccountType.banco;
    initial = TextEditingController(text: _centsText(a == null ? 0 : (a.isCard ? -a.initial : a.initial)));
    limit = TextEditingController(text: _centsText(a?.limit ?? 0));
    closing = a?.closingDay ?? 25;
    due = a?.dueDay ?? 5;
  }

  @override
  void dispose() {
    name.dispose();
    initial.dispose();
    limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<FinanceStore>();
    final init = parseCents(initial.text) ?? 0;
    final a = widget.account ?? Account(id: FinanceStore.newId(), name: '', type: type);
    a
      ..name = name.text.trim().isEmpty ? type.label : name.text.trim()
      ..type = type
      // No cartão o valor inicial é dívida já existente.
      ..initial = type == AccountType.cartao ? -init : init
      ..limit = parseCents(limit.text) ?? 0
      ..closingDay = closing
      ..dueDay = due;
    await store.saveAccount(a);
    if (mounted) Navigator.pop(context);
  }

  Widget _day(String label, int value, ValueChanged<int> set) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('Dia $d'))],
    onChanged: (v) => v == null ? null : set(v),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final a = widget.account;
    final isCard = type == AccountType.cartao;
    return Scaffold(
      appBar: AppBar(
        title: Text(a == null ? 'Nova conta' : 'Editar conta'),
        actions: [
          if (a != null)
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!store.canRemoveAccount(a)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Só dá para excluir contas sem lançamentos (e precisa sobrar ao menos uma).'),
                    ),
                  );
                  return;
                }
                await store.removeAccount(a);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<AccountType>(
            segments: [
              for (final t in AccountType.values)
                ButtonSegment(value: t, label: Text(t.label.split(' ').first), icon: Icon(t.icon)),
            ],
            selected: {type},
            onSelectionChanged: (s) => setState(() => type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nome (ex.: Nubank, Itaú)'),
          ),
          const SizedBox(height: 12),
          AmountField(controller: initial, label: isCard ? 'Dívida atual (opcional)' : 'Saldo inicial'),
          if (isCard) ...[
            const SizedBox(height: 12),
            AmountField(controller: limit, label: 'Limite (opcional)'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _day('Fecha', closing, (v) => setState(() => closing = v))),
                const SizedBox(width: 12),
                Expanded(child: _day('Vence', due, (v) => setState(() => due = v))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Compras a partir do dia do fechamento entram na fatura seguinte.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ],
          if (a != null && !a.isCard && store.defaultAccount.id != a.id) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => store.setDefaultAccount(a),
              icon: const Icon(Icons.star_outline),
              label: const Text('Usar como conta padrão'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Salvar')),
        ],
      ),
    );
  }
}

// ---------- Conta fixa ----------

class FixedEditor extends StatefulWidget {
  final FixedBill? bill;

  const FixedEditor({super.key, this.bill});

  @override
  State<FixedEditor> createState() => _FixedEditorState();
}

class _FixedEditorState extends State<FixedEditor> {
  late TextEditingController desc;
  late TextEditingController amount;
  late FinCategory category;
  String? accountId;
  late int day;
  late bool active;
  late bool remind;

  @override
  void initState() {
    super.initState();
    final f = widget.bill;
    desc = TextEditingController(text: f?.description ?? '');
    amount = TextEditingController(text: _centsText(f?.amount ?? 0));
    category = f?.category ?? FinCategory.moradia;
    accountId = f?.accountId ?? context.read<FinanceStore>().defaultAccount.id;
    day = f?.day ?? 10;
    active = f?.active ?? true;
    remind = f == null || f.reminderId != null;
  }

  @override
  void dispose() {
    desc.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> _syncReminder(RemindersStore reminders, FixedBill f) async {
    final existing = reminders.items.where((r) => r.id == f.reminderId).firstOrNull;
    if (existing != null) await reminders.remove(existing);
    f.reminderId = null;
    if (remind && f.active) {
      final r = await reminders.add(
        title: 'Pagar ${f.description}',
        rec: Recurrence(kind: RecKind.monthlyDay, monthDay: f.day, times: const [HM(9, 0)]),
        category: Category.contas,
      );
      f.reminderId = r.id;
    }
  }

  Future<void> _save() async {
    final store = context.read<FinanceStore>();
    final reminders = context.read<RemindersStore>();
    final cents = parseCents(amount.text);
    if (cents == null || cents <= 0 || desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome e valor')));
      return;
    }
    final f =
        widget.bill ??
        FixedBill(id: FinanceStore.newId(), description: '', amount: 0, category: category, accountId: '', day: day);
    f
      ..description = desc.text.trim()
      ..amount = cents
      ..category = category
      ..accountId = accountId ?? store.defaultAccount.id
      ..day = day
      ..active = active;
    await _syncReminder(reminders, f);
    await store.saveFixed(f);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final f = widget.bill;
    return Scaffold(
      appBar: AppBar(
        title: Text(f == null ? 'Nova conta fixa' : 'Conta fixa'),
        actions: [
          if (f != null)
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final reminders = context.read<RemindersStore>();
                final r = reminders.items.where((r) => r.id == f.reminderId).firstOrNull;
                if (r != null) await reminders.remove(r);
                await store.removeFixed(f);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome (ex.: Aluguel, Netflix)'),
            onChanged: (s) {
              final g = guessCategory(s, TxKind.expense);
              if (g != FinCategory.outros) setState(() => category = g);
            },
          ),
          const SizedBox(height: 12),
          AmountField(controller: amount),
          const SizedBox(height: 12),
          _categoryDropdown(TxKind.expense, category, (c) => setState(() => category = c)),
          const SizedBox(height: 12),
          _accountDropdown(store, accountId, (v) => setState(() => accountId = v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: day,
            decoration: const InputDecoration(labelText: 'Dia do mês'),
            items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('Todo dia $d'))],
            onChanged: (v) => setState(() => day = v ?? day),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: remind,
            onChanged: (v) => setState(() => remind = v),
            title: const Text('Lembrete no dia (09:00)'),
            subtitle: const Text('Cria um lembrete na categoria Contas'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: active,
            onChanged: (v) => setState(() => active = v),
            title: const Text('Ativa'),
            subtitle: const Text('Lança o gasto automaticamente todo mês'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Salvar')),
        ],
      ),
    );
  }
}

// ---------- Orçamento e metas ----------

Future<void> editBudget(BuildContext context, {FinCategory? category}) async {
  final store = context.read<FinanceStore>();
  var cat =
      category ??
      FinCategory.forKind(TxKind.expense)
          .firstWhere((c) => !store.budgets.containsKey(c), orElse: () => FinCategory.outros);
  final ctrl = TextEditingController(text: _centsText(store.budgets[cat] ?? 0));
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Orçamento mensal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _categoryDropdown(
              TxKind.expense,
              cat,
              (v) => set(() {
                cat = v;
                ctrl.text = _centsText(store.budgets[v] ?? 0);
              }),
            ),
            const SizedBox(height: 12),
            AmountField(controller: ctrl, label: 'Limite por mês', autofocus: true),
            const SizedBox(height: 8),
            Text('Deixe vazio para remover.', style: Theme.of(c).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salvar')),
        ],
      ),
    ),
  );
  if (ok == true) await store.setBudget(cat, parseCents(ctrl.text) ?? 0);
  ctrl.dispose();
}

Future<void> editGoal(BuildContext context, {SavingsGoal? goal}) async {
  final store = context.read<FinanceStore>();
  final name = TextEditingController(text: goal?.name ?? '');
  final target = TextEditingController(text: _centsText(goal?.target ?? 0));
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(goal == null ? 'Nova meta' : 'Editar meta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: goal == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Objetivo (ex.: Viagem)'),
          ),
          const SizedBox(height: 12),
          AmountField(controller: target, label: 'Quanto quer juntar'),
        ],
      ),
      actions: [
        if (goal != null) TextButton(onPressed: () => Navigator.pop(c, 'del'), child: const Text('Excluir')),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, 'ok'), child: const Text('Salvar')),
      ],
    ),
  );
  if (result == 'del' && goal != null) await store.removeGoal(goal);
  final cents = parseCents(target.text) ?? 0;
  if (result == 'ok' && cents > 0) {
    final g = goal ?? SavingsGoal(id: FinanceStore.newId(), name: '', target: 0);
    g
      ..name = name.text.trim().isEmpty ? 'Meta' : name.text.trim()
      ..target = cents;
    await store.saveGoal(g);
  }
  name.dispose();
  target.dispose();
}

Future<void> moveGoal(BuildContext context, SavingsGoal g, {required bool add}) async {
  final store = context.read<FinanceStore>();
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(add ? 'Guardar em ${g.name}' : 'Retirar de ${g.name}'),
      content: AmountField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(add ? 'Guardar' : 'Retirar')),
      ],
    ),
  );
  final cents = parseCents(ctrl.text) ?? 0;
  if (ok == true && cents > 0) await store.deposit(g, add ? cents : -cents);
  ctrl.dispose();
}
