import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'finance.dart';
import 'finance_forms.dart';
import 'finance_store.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  DateTime month = monthStart(DateTime.now());

  Future<void> _export() async {
    final store = context.read<FinanceStore>();
    final csv = store.toCsv();
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('Abrir em planilha'),
              subtitle: Text('${store.txs.length} lançamentos · CSV'),
              onTap: () async {
                Navigator.pop(c);
                final dir = await getTemporaryDirectory();
                final f = File('${dir.path}/universal_financas_${dayKey(DateTime.now())}.csv');
                // BOM para o Excel reconhecer os acentos.
                await f.writeAsString('﻿$csv');
                final r = await OpenFilex.open(f.path, type: 'text/csv');
                if (r.type != ResultType.done && mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Nenhum app de planilha encontrado. Use "Copiar".')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar CSV'),
              subtitle: const Text('Cole no Google Planilhas, e-mail ou notas'),
              onTap: () {
                Navigator.pop(c);
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copiado')));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finanças'),
          actions: [IconButton(tooltip: 'Exportar', icon: const Icon(Icons.ios_share), onPressed: _export)],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Resumo'),
              Tab(text: 'Lançamentos'),
              Tab(text: 'Contas'),
              Tab(text: 'Planejamento'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => QuickTxSheet.show(context),
          icon: const Icon(Icons.add),
          label: const Text('Lançar'),
        ),
        body: !store.loaded
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _Summary(month: month, onMonth: (m) => setState(() => month = m)),
                  _TxList(month: month, onMonth: (m) => setState(() => month = m)),
                  const _Accounts(),
                  _Planning(month: month),
                ],
              ),
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onMonth;

  const _MonthBar({required this.month, required this.onMonth});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onMonth(monthStart(DateTime.now())),
              child: Text(
                monthTitle(month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

Widget _sectionTitle(BuildContext context, String text, {Widget? trailing}) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
  child: Row(
    children: [
      Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
      ?trailing,
    ],
  ),
);

class _Box extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Box(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.labelSmall?.copyWith(color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: t.titleMedium?.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Resumo ----------

class _Summary extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onMonth;

  const _Summary({required this.month, required this.onMonth});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final t = Theme.of(context).textTheme;
    final inc = store.incomes(month), exp = store.expenses(month);
    final cats = store.byCategory(month);
    final total = store.totalBalance();
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.line),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.surfaceHighest, AppTheme.surface],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SALDO EM CONTAS', style: t.labelSmall?.copyWith(color: AppTheme.textMuted, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(
                brl(total),
                style: t.displaySmall?.copyWith(
                  fontWeight: FontWeight.w300,
                  color: total < 0 ? AppTheme.negative : AppTheme.text,
                  letterSpacing: -1,
                ),
              ),
              if (store.firstCard != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Cartões: ${brl(store.accounts.where((a) => a.isCard).fold(0, (s, a) => s + store.cardDebt(a)))} comprometido',
                  style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
        _MonthBar(month: month, onMonth: onMonth),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _Box('Entradas', brl(inc), color: AppTheme.positive),
              const SizedBox(width: 10),
              _Box('Saídas', brl(exp), color: AppTheme.negative),
              const SizedBox(width: 10),
              _Box('Resultado', brl(inc - exp), color: inc - exp < 0 ? AppTheme.negative : AppTheme.text),
            ],
          ),
        ),
        _sectionTitle(context, 'Para onde foi'),
        if (cats.isEmpty)
          const _Hint(icon: Icons.pie_chart_outline, text: 'Nenhum gasto neste mês.')
        else
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 52,
                        sections: [
                          for (final e in cats.entries)
                            PieChartSectionData(
                              value: e.value.toDouble(),
                              color: e.key.color,
                              radius: 28,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final e in cats.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: e.key.color, borderRadius: BorderRadius.circular(3)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(e.key.label)),
                          Text(
                            '${(e.value * 100 / exp).round()}%',
                            style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(width: 96, child: Text(brl(e.value), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        _sectionTitle(context, 'Entradas x saídas'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
            child: SizedBox(
              height: 200,
              child: _Bars(store: store, last: month),
            ),
          ),
        ),
        if (store.budgets.isNotEmpty) ...[
          _sectionTitle(context, 'Orçamentos'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final c in store.budgets.keys) _BudgetRow(category: c, status: store.budget(c, month)!),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  final FinanceStore store;
  final DateTime last;

  const _Bars({required this.store, required this.last});

  @override
  Widget build(BuildContext context) {
    final months = [for (var i = 5; i >= 0; i--) DateTime(last.year, last.month - i)];
    final data = [for (final m in months) (store.incomes(m) / 100, store.expenses(m) / 100)];
    final maxV = data.fold<double>(1, (s, e) => [s, e.$1, e.$2].reduce((a, b) => a > b ? a : b));
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted);
    return BarChart(
      BarChartData(
        maxY: maxV * 1.15,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxV / 3,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surfaceHighest,
            getTooltipItem: (g, _, rod, _) =>
                BarTooltipItem(brl((rod.toY * 100).round()), const TextStyle(color: AppTheme.text, fontSize: 12)),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxV / 3,
              getTitlesWidget: (v, meta) => v == meta.max
                  ? const SizedBox()
                  : Text(
                      v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k' : v.round().toString(),
                      style: style,
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(monthShort(months[v.toInt()]), style: style),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: data[i].$1,
                  color: AppTheme.positive,
                  width: 9,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: data[i].$2,
                  color: AppTheme.negative,
                  width: 9,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final FinCategory category;
  final BudgetStatus status;
  final VoidCallback? onTap;

  const _BudgetRow({required this.category, required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = status.ratio;
    final color = r >= 1 ? AppTheme.negative : (r >= 0.8 ? const Color(0xFFE0B05A) : AppTheme.tone(category.color));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(category.icon, size: 18, color: AppTheme.tone(category.color)),
                const SizedBox(width: 8),
                Expanded(child: Text(category.label)),
                Text(
                  '${brl(status.spent)} / ${brl(status.limit)}',
                  style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: r.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: color,
            ),
            if (r >= 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Estourou ${brl(status.spent - status.limit)}',
                  style: t.labelSmall?.copyWith(color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    ),
  );
}

// ---------- Lançamentos ----------

class TxTile extends StatelessWidget {
  final Tx tx;

  const TxTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final store = context.read<FinanceStore>();
    final t = tx;
    final color = t.kind == TxKind.transfer ? AppTheme.textMuted : AppTheme.tone(t.category.color);
    final acc = store.account(t.accountId)?.name ?? '';
    final sub = t.kind == TxKind.transfer
        ? '$acc → ${store.account(t.toAccountId)?.name ?? ''}'
        : '${t.category.label} · $acc';
    final sign = switch (t.kind) {
      TxKind.expense => '−',
      TxKind.income => '+',
      TxKind.transfer => '',
    };
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
        child: Icon(t.kind == TxKind.transfer ? Icons.swap_horiz : t.category.icon, color: color, size: 20),
      ),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        sub,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.textMuted),
      ),
      trailing: Text(
        '$sign${brl(t.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: t.kind == TxKind.income
              ? AppTheme.positive
              : (t.kind == TxKind.transfer ? AppTheme.textMuted : AppTheme.text),
        ),
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TxEditor(tx: t))),
    );
  }
}

class _TxList extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onMonth;

  const _TxList({required this.month, required this.onMonth});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final list = store.monthTxs(month);
    final days = <DateTime, List<Tx>>{};
    for (final t in list) {
      days.putIfAbsent(dayOf(t.date), () => []).add(t);
    }
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _MonthBar(month: month, onMonth: onMonth),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _Hint(icon: Icons.receipt_long_outlined, text: 'Nenhum lançamento neste mês. Toque em "Lançar".'),
          ),
        for (final e in days.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    friendlyWhen(e.key).replaceAll(' 00:00', '').toUpperCase(),
                    style: t.labelSmall?.copyWith(color: AppTheme.textMuted, letterSpacing: 1),
                  ),
                ),
                Text(
                  brl(
                    e.value.fold(
                      0,
                      (s, x) => s + (x.kind == TxKind.expense ? -x.amount : (x.kind == TxKind.income ? x.amount : 0)),
                    ),
                  ),
                  style: t.labelSmall?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < e.value.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  Dismissible(
                    key: ValueKey(e.value[i].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AppTheme.negative.withValues(alpha: 0.2),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_outline),
                    ),
                    onDismissed: (_) async {
                      final tx = e.value[i];
                      final messenger = ScaffoldMessenger.of(context);
                      await store.removeTx(tx);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('"${tx.title}" excluído'),
                          action: SnackBarAction(label: 'Desfazer', onPressed: () => store.restore([tx])),
                        ),
                      );
                    },
                    child: TxTile(tx: e.value[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------- Contas ----------

class _Accounts extends StatelessWidget {
  const _Accounts();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final a in store.accounts)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => a.isCard ? InvoicePage(cardId: a.id) : AccountEditor(account: a),
                ),
              ),
              onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountEditor(account: a))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.type.icon),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(a.name, style: t.titleMedium, overflow: TextOverflow.ellipsis),
                              ),
                              if (store.defaultAccount.id == a.id) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.star, size: 14, color: AppTheme.textMuted),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (a.isCard) ...[
                            Builder(
                              builder: (_) {
                                final m = store.currentInvoice(a, now: now);
                                final open = store.invoiceTotal(a, m) - store.invoicePaid(a, m);
                                final due = invoiceDue(m, a.dueDay);
                                return Text(
                                  'Fatura ${brl(open)} · vence ${two(due.day)}/${two(due.month)}',
                                  style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                                );
                              },
                            ),
                            if (a.limit > 0)
                              Text(
                                'Limite disponível ${brl(a.limit - store.cardDebt(a))}',
                                style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                              ),
                          ] else
                            Text(a.type.label, style: t.bodySmall?.copyWith(color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    if (!a.isCard)
                      Text(
                        brl(store.balance(a)),
                        style: t.titleMedium?.copyWith(color: store.balance(a) < 0 ? AppTheme.negative : AppTheme.text),
                      ),
                    if (a.isCard) const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountEditor())),
          icon: const Icon(Icons.add),
          label: const Text('Nova conta ou cartão'),
        ),
        const SizedBox(height: 8),
        Text(
          'Toque e segure para editar. A conta com ★ é a padrão dos lançamentos.',
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class InvoicePage extends StatefulWidget {
  final String cardId;

  const InvoicePage({super.key, required this.cardId});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  DateTime? month;

  Future<void> _pay(FinanceStore store, Account card, DateTime m, int open) async {
    final ctrl = TextEditingController(text: (open / 100).toStringAsFixed(2).replaceAll('.', ','));
    String? from = store.accounts.where((a) => !a.isCard).firstOrNull?.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Pagar fatura'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AmountField(controller: ctrl),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: from,
                decoration: const InputDecoration(labelText: 'Pagar com'),
                items: [
                  for (final a in store.accounts.where((a) => !a.isCard))
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => set(() => from = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Pagar')),
          ],
        ),
      ),
    );
    final cents = parseCents(ctrl.text) ?? 0;
    ctrl.dispose();
    final acc = store.account(from);
    if (ok == true && cents > 0 && acc != null) await store.payInvoice(card, m, acc, cents);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final card = store.account(widget.cardId);
    if (card == null) return const Scaffold();
    final m = month ?? store.currentInvoice(card);
    final list = store.invoiceTxs(card, m);
    final total = store.invoiceTotal(card, m);
    final paid = store.invoicePaid(card, m);
    final open = total - paid;
    final due = invoiceDue(m, card.dueDay);
    final close = DateTime(due.year, due.month - (card.dueDay > card.closingDay ? 0 : 1), card.closingDay);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(card.name),
        actions: [
          IconButton(
            tooltip: 'Editar cartão',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountEditor(account: card))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _MonthBar(month: m, onMonth: (v) => setState(() => month = v)),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.line),
              gradient: const LinearGradient(colors: [AppTheme.surfaceHighest, AppTheme.surface]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  open <= 0 && total > 0 ? 'FATURA PAGA' : 'FATURA',
                  style: t.labelSmall?.copyWith(
                    color: open <= 0 && total > 0 ? AppTheme.positive : AppTheme.textMuted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(brl(total), style: t.displaySmall?.copyWith(fontWeight: FontWeight.w300, letterSpacing: -1)),
                const SizedBox(height: 6),
                Text(
                  'Fecha ${two(close.day)}/${two(close.month)} · vence ${two(due.day)}/${two(due.month)}',
                  style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                ),
                if (paid > 0)
                  Text(
                    'Pago ${brl(paid)}${open > 0 ? ' · falta ${brl(open)}' : ''}',
                    style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                if (open > 0) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _pay(store, card, m, open),
                    icon: const Icon(Icons.check),
                    label: const Text('Pagar fatura'),
                  ),
                ],
              ],
            ),
          ),
          _sectionTitle(context, 'Compras'),
          if (list.isEmpty)
            const _Hint(icon: Icons.credit_card, text: 'Nenhuma compra nesta fatura.')
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[if (i > 0) const Divider(indent: 72), TxTile(tx: list[i])],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Planejamento ----------

class _Planning extends StatelessWidget {
  final DateTime month;

  const _Planning({required this.month});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final t = Theme.of(context).textTheme;
    final addBtn = IconButton.filledTonal;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _sectionTitle(
          context,
          'Orçamentos de ${monthTitle(month).toLowerCase()}',
          trailing: addBtn(
            tooltip: 'Definir orçamento',
            onPressed: () => editBudget(context),
            icon: const Icon(Icons.add),
          ),
        ),
        if (store.budgets.isEmpty)
          const _Hint(
            icon: Icons.donut_large,
            text: 'Defina um limite mensal por categoria e receba aviso ao chegar em 80%.',
          )
        else
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final c in store.budgets.keys)
                    _BudgetRow(
                      category: c,
                      status: store.budget(c, month)!,
                      onTap: () => editBudget(context, category: c),
                    ),
                ],
              ),
            ),
          ),
        _sectionTitle(
          context,
          'Contas fixas',
          trailing: addBtn(
            tooltip: 'Nova conta fixa',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FixedEditor())),
            icon: const Icon(Icons.add),
          ),
        ),
        if (store.fixed.isEmpty)
          const _Hint(
            icon: Icons.event_repeat,
            text: 'Aluguel, luz, assinaturas… lançados sozinhos todo mês, com lembrete.',
          )
        else ...[
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < store.fixed.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  Builder(
                    builder: (_) {
                      final f = store.fixed[i];
                      final color = AppTheme.tone(f.category.color);
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(f.category.icon, color: color, size: 20),
                        ),
                        title: Text(f.description, style: TextStyle(color: f.active ? null : AppTheme.textMuted)),
                        subtitle: Text(
                          'Todo dia ${f.day} · ${store.account(f.accountId)?.name ?? ''}${f.reminderId != null ? ' · com lembrete' : ''}${f.active ? '' : ' · pausada'}',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        trailing: Text(brl(f.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FixedEditor(bill: f))),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Total fixo por mês: ${brl(store.fixedMonthly())}',
              style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ),
        ],
        _sectionTitle(
          context,
          'Metas de economia',
          trailing: addBtn(tooltip: 'Nova meta', onPressed: () => editGoal(context), icon: const Icon(Icons.add)),
        ),
        if (store.goals.isEmpty)
          const _Hint(
            icon: Icons.savings_outlined,
            text: 'Crie uma meta (viagem, reserva…) e acompanhe quanto já guardou.',
          )
        else
          for (final g in store.goals)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: InkWell(
                onTap: () => editGoal(context, goal: g),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.savings_outlined, color: AppTheme.textMuted),
                          const SizedBox(width: 10),
                          Expanded(child: Text(g.name, style: t.titleMedium)),
                          Text('${(g.progress * 100).round()}%', style: t.labelLarge),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: g.progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        color: g.progress >= 1 ? AppTheme.positive : AppTheme.accent,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${brl(g.saved)} de ${brl(g.target)}${g.progress >= 1 ? ' · meta alcançada 🎉' : ''}',
                        style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => moveGoal(context, g, add: false), child: const Text('Retirar')),
                          const SizedBox(width: 4),
                          FilledButton.tonal(
                            onPressed: () => moveGoal(context, g, add: true),
                            child: const Text('Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Resumo compacto para a tela Hoje.
class FinanceTodayCard extends StatelessWidget {
  const FinanceTodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final t = Theme.of(context).textTheme;
    final m = monthStart(DateTime.now());
    final exp = store.expenses(m), inc = store.incomes(m);
    final card = store.firstCard;
    String? invoice;
    if (card != null) {
      final im = store.currentInvoice(card);
      final due = invoiceDue(im, card.dueDay);
      invoice =
          'Fatura ${card.name}: ${brl(store.invoiceTotal(card, im) - store.invoicePaid(card, im))} · vence ${two(due.day)}/${two(due.month)}';
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancePage())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saldo', style: t.labelSmall?.copyWith(color: AppTheme.textMuted)),
                        Text(brl(store.totalBalance()), style: t.titleLarge),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Lançar',
                    onPressed: () => QuickTxSheet.show(context),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('No mês: +${brl(inc)}  ·  −${brl(exp)}', style: t.bodySmall?.copyWith(color: AppTheme.textMuted)),
              if (invoice != null) Text(invoice, style: t.bodySmall?.copyWith(color: AppTheme.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
