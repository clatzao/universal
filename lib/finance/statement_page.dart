import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'finance.dart';
import 'finance_store.dart';
import 'statement.dart';

/// Revisão do extrato: nada é gravado antes de a pessoa confirmar.
class StatementImportPage extends StatefulWidget {
  final List<StatementLine> lines;

  const StatementImportPage({super.key, required this.lines});

  @override
  State<StatementImportPage> createState() => _StatementImportPageState();
}

class _StatementImportPageState extends State<StatementImportPage> {
  late String accountId = context.read<FinanceStore>().defaultAccount.id;
  bool invert = false;
  List<ImportCandidate> candidates = [];
  final selected = <String>{};

  @override
  void initState() {
    super.initState();
    _review();
  }

  void _review() {
    candidates = context.read<FinanceStore>().reviewImport(widget.lines, accountId, invert: invert);
    selected
      ..clear()
      ..addAll([
        for (final c in candidates)
          if (c.selectedByDefault) c.key,
      ]);
  }

  Future<void> _import() async {
    final store = context.read<FinanceStore>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final count = await store.importCandidates(candidates.where((c) => selected.contains(c.key)), accountId);
    messenger.showSnackBar(SnackBar(content: Text('$count lançamento(s) importado(s)')));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final store = context.watch<FinanceStore>();
    final chosen = candidates.where((c) => selected.contains(c.key));
    final out = chosen.where((c) => c.kind == TxKind.expense).fold(0, (s, c) => s + c.amount);
    final inc = chosen.where((c) => c.kind == TxKind.income).fold(0, (s, c) => s + c.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Importar extrato')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Saídas: ${brl(out)} · Entradas: ${brl(inc)}',
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: selected.isEmpty ? null : _import,
                child: Text('Importar ${selected.length} lançamento(s)'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: accountId,
            decoration: const InputDecoration(labelText: 'Conta'),
            items: [for (final a in store.accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
            onChanged: (v) => setState(() {
              accountId = v!;
              _review();
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: invert,
            title: const Text('Inverter entradas e saídas'),
            subtitle: const Text('Use se as compras aparecerem como entradas, comum em fatura de cartão'),
            onChanged: (v) => setState(() {
              invert = v;
              _review();
            }),
          ),
          Text('Desmarcados: já importados ou iguais a um lançamento seu do mesmo dia.', style: t.bodySmall),
          const SizedBox(height: 8),
          for (final c in candidates)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected.contains(c.key),
              onChanged: (v) => setState(() => v == true ? selected.add(c.key) : selected.remove(c.key)),
              title: Text(
                c.description.isEmpty ? c.category.label : c.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  '${two(c.date.day)}/${two(c.date.month)}/${c.date.year}',
                  c.category.label,
                  if (c.alreadyImported) 'já importado' else if (c.looksManual) 'parece repetido',
                ].join(' · '),
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              secondary: Text(
                '${c.kind == TxKind.expense ? '-' : '+'}${brl(c.amount)}',
                style: TextStyle(color: c.kind == TxKind.expense ? AppTheme.negative : AppTheme.positive),
              ),
            ),
        ],
      ),
    );
  }
}
