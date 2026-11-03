import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../finance/finance.dart' show brl, parseCents;
import '../info/info_store.dart';
import 'coin_flip.dart';
import 'qr_page.dart';
import 'tools_logic.dart';
import 'vault_page.dart';

class _ToolInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() page;

  const _ToolInfo(this.title, this.subtitle, this.icon, this.page);
}

final _tools = <_ToolInfo>[
  _ToolInfo('Conversor', 'Unidades e moedas', Icons.swap_horiz, () => const ConverterPage()),
  _ToolInfo(
    'Dividir conta',
    'Em partes iguais ou por consumo, com gorjeta',
    Icons.receipt_long_outlined,
    () => const SplitPage(),
  ),
  _ToolInfo('Porcentagem', 'Descontos, aumentos e variação', Icons.percent, () => const PercentPage()),
  _ToolInfo(
    'Juros e parcelas',
    'Rendimento, financiamento e à vista x parcelado',
    Icons.trending_up,
    () => const InterestPage(),
  ),
  _ToolInfo('Sorteio', 'Times, nomes, números e cara ou coroa', Icons.casino_outlined, () => const DrawPage()),
  _ToolInfo('QR code', 'Criar e ler com a câmera', Icons.qr_code_2, () => const QrPage()),
  _ToolInfo(
    'Cofre de senhas',
    'Protegido pela digital ou bloqueio do celular',
    Icons.lock_outline,
    () => const VaultPage(),
  ),
];

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ferramentas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final tool in _tools)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(tool.icon),
                title: Text(tool.title),
                subtitle: Text(tool.subtitle, style: const TextStyle(color: AppTheme.textMuted)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => tool.page())),
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? prefix;
  final String? suffix;
  final ValueChanged<String>? onChanged;

  const _NumberField(this.controller, this.label, {this.prefix, this.suffix, this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))],
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label, prefixText: prefix, suffixText: suffix),
  );
}

class _Result extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Result(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          SelectableText(value, style: t.titleLarge?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper(this.label, this.value, this.onChanged, {this.max = 100});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        tooltip: 'Menos',
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove),
      ),
      SizedBox(
        width: 36,
        child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      ),
      IconButton(
        tooltip: 'Mais',
        onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add),
      ),
    ],
  );
}

String _money(double v) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);

// ---------- Conversor ----------

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  final value = TextEditingController(text: '1');
  bool currencyMode = false;
  UnitGroup group = unitGroups.first;
  late Unit from = group.units[2];
  late Unit to = group.units[3];
  String fromCurrency = 'USD';
  String toCurrency = 'BRL';

  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  void _setGroup(UnitGroup g) => setState(() {
    group = g;
    from = g.units.first;
    to = g.units[1];
  });

  void _swap() => setState(() {
    if (currencyMode) {
      final previous = fromCurrency;
      fromCurrency = toCurrency;
      toCurrency = previous;
    } else {
      final previous = from;
      from = to;
      to = previous;
    }
  });

  @override
  Widget build(BuildContext context) {
    final q = context.watch<InfoStore>().quotes;
    final rates = <String, double?>{'BRL': 1, 'USD': q?.usd, 'EUR': q?.eur, 'BTC': q?.btc};
    final n = parseNumber(value.text);
    String result = '—';
    if (n != null) {
      if (currencyMode) {
        final a = rates[fromCurrency], b = rates[toCurrency];
        if (a != null && b != null) result = '${formatNumber(convertCurrency(n, a, b))} $toCurrency';
      } else {
        result = formatNumber(convertUnit(n, group, from, to));
      }
    }
    final swap = Center(
      child: IconButton(tooltip: 'Inverter', icon: const Icon(Icons.swap_vert), onPressed: _swap),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Conversor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Unidades')),
              ButtonSegment(value: true, label: Text('Moedas')),
            ],
            selected: {currencyMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => currencyMode = s.first),
          ),
          const SizedBox(height: 14),
          if (!currencyMode) ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final g in unitGroups)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(g.label),
                        selected: identical(g, group),
                        onSelected: (_) => _setGroup(g),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          _NumberField(value, 'Valor', onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          if (currencyMode) ...[
            _currencyDropdown('De', fromCurrency, (v) => setState(() => fromCurrency = v)),
            swap,
            _currencyDropdown('Para', toCurrency, (v) => setState(() => toCurrency = v)),
            if (q == null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Cotações ainda não carregadas. Verifique a internet.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
          ] else ...[
            _unitDropdown('De', from, (u) => setState(() => from = u)),
            swap,
            _unitDropdown('Para', to, (u) => setState(() => to = u)),
          ],
          _Result('Resultado', result),
        ],
      ),
    );
  }

  Widget _unitDropdown(String label, Unit value, ValueChanged<Unit> onChanged) => DropdownButtonFormField<Unit>(
    key: ValueKey('$label-${group.label}-${value.id}'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [for (final u in group.units) DropdownMenuItem(value: u, child: Text(u.label))],
    onChanged: (u) => u == null ? null : onChanged(u),
  );

  Widget _currencyDropdown(String label, String value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: const [
          DropdownMenuItem(value: 'BRL', child: Text('Real (BRL)')),
          DropdownMenuItem(value: 'USD', child: Text('Dólar (USD)')),
          DropdownMenuItem(value: 'EUR', child: Text('Euro (EUR)')),
          DropdownMenuItem(value: 'BTC', child: Text('Bitcoin (BTC)')),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      );
}

// ---------- Dividir conta ----------

class _Person {
  final name = TextEditingController();
  final amount = TextEditingController();

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class SplitPage extends StatefulWidget {
  const SplitPage({super.key});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  bool byConsumption = false;
  final total = TextEditingController();
  final shared = TextEditingController();
  final tipField = TextEditingController(text: '10');
  int people = 2;
  final persons = [_Person(), _Person()];

  @override
  void dispose() {
    total.dispose();
    shared.dispose();
    tipField.dispose();
    for (final p in persons) {
      p.dispose();
    }
    super.dispose();
  }

  void _refresh([String? _]) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tip = parseNumber(tipField.text) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Dividir conta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Partes iguais')),
              ButtonSegment(value: true, label: Text('Por consumo')),
            ],
            selected: {byConsumption},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => byConsumption = s.first),
          ),
          const SizedBox(height: 16),
          if (byConsumption) ..._consumption(tip) else ..._equal(tip),
        ],
      ),
    );
  }

  Widget _tipField() => _NumberField(tipField, 'Gorjeta', suffix: '%', onChanged: _refresh);

  List<Widget> _equal(double tip) {
    final cents = parseCents(total.text) ?? 0;
    final withTip = addTip(cents, tip);
    final parts = splitEqually(withTip, people);
    return [
      _NumberField(total, 'Valor da conta', prefix: 'R\$ ', onChanged: _refresh),
      const SizedBox(height: 12),
      _tipField(),
      const SizedBox(height: 4),
      _Stepper('Pessoas', people, (v) => setState(() => people = v)),
      _Result('Total com gorjeta', brl(withTip)),
      _Result('Cada pessoa paga', parts.isEmpty ? '—' : brl(parts.last)),
      if (parts.isNotEmpty && parts.first != parts.last)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${parts.where((p) => p == parts.first).length} pessoa(s) paga(m) ${brl(parts.first)} para fechar os centavos.',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ),
    ];
  }

  List<Widget> _consumption(double tip) {
    final consumed = [for (final p in persons) parseCents(p.amount.text) ?? 0];
    final parts = splitByConsumption(consumed, parseCents(shared.text) ?? 0, tip);
    return [
      for (var i = 0; i < persons.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: persons[i].name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: _refresh,
                  decoration: InputDecoration(labelText: 'Pessoa ${i + 1}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _NumberField(persons[i].amount, 'Consumiu', onChanged: _refresh)),
              IconButton(
                tooltip: 'Remover',
                onPressed: persons.length > 2 ? () => setState(() => persons.removeAt(i).dispose()) : null,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      OutlinedButton.icon(
        onPressed: () => setState(() => persons.add(_Person())),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Adicionar pessoa'),
      ),
      const SizedBox(height: 12),
      _NumberField(shared, 'Compartilhado (ex.: entrada, couvert)', prefix: 'R\$ ', onChanged: _refresh),
      const SizedBox(height: 12),
      _tipField(),
      const SizedBox(height: 8),
      for (var i = 0; i < persons.length; i++)
        _Result(persons[i].name.text.trim().isEmpty ? 'Pessoa ${i + 1}' : persons[i].name.text.trim(), brl(parts[i])),
      _Result('Total', brl(parts.fold(0, (s, v) => s + v))),
    ];
  }
}

// ---------- Porcentagem ----------

class PercentPage extends StatefulWidget {
  const PercentPage({super.key});

  @override
  State<PercentPage> createState() => _PercentPageState();
}

class _PercentPageState extends State<PercentPage> {
  final _c = [for (var i = 0; i < 8; i++) TextEditingController()];

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _card(String title, int i, String a, String b, String Function(double, double) compute) {
    final x = parseNumber(_c[i].text), y = parseNumber(_c[i + 1].text);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _NumberField(_c[i], a, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(child: _NumberField(_c[i + 1], b, onChanged: (_) => setState(() {}))),
              ],
            ),
            _Result('Resultado', x == null || y == null ? '—' : compute(x, y)),
          ],
        ),
      ),
    );
  }

  String _pct(double? v) => v == null ? 'Não dá para dividir por zero' : '${formatNumber(v)}%';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Porcentagem')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card('Quanto é X% de um valor?', 0, 'X %', 'Valor', (p, v) => formatNumber(percentOf(p, v))),
          _card(
            'Desconto',
            2,
            'Preço',
            'Desconto %',
            (v, p) => '${formatNumber(applyDiscount(v, p))} (economia de ${formatNumber(percentOf(p, v))})',
          ),
          _card('Aumento', 4, 'Valor', 'Aumento %', (v, p) => formatNumber(applyIncrease(v, p))),
          _card('Variação entre dois valores', 6, 'De', 'Para', (a, b) => _pct(percentChange(a, b))),
        ],
      ),
    );
  }
}

// ---------- Juros e parcelas ----------

class InterestPage extends StatefulWidget {
  const InterestPage({super.key});

  @override
  State<InterestPage> createState() => _InterestPageState();
}

class _InterestPageState extends State<InterestPage> {
  int mode = 0;
  final a = TextEditingController();
  final b = TextEditingController();
  final rate = TextEditingController();
  final months = TextEditingController(text: '12');

  @override
  void dispose() {
    for (final c in [a, b, rate, months]) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh([String? _]) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(months.text.trim()) ?? 0;
    final x = parseNumber(a.text), y = parseNumber(b.text), r = parseNumber(rate.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Juros e parcelas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Render')),
              ButtonSegment(value: 1, label: Text('Parcela')),
              ButtonSegment(value: 2, label: Text('À vista?')),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              mode = s.first;
              a.clear();
              b.clear();
            }),
          ),
          const SizedBox(height: 16),
          ...switch (mode) {
            0 => _invest(x, y, r, n),
            1 => _loan(x, r, n),
            _ => _compare(x, y, r, n),
          },
          const SizedBox(height: 16),
          const Text('Valores estimados, sem impostos e taxas.', style: TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _common({String rateLabel = 'Taxa ao mês'}) => Row(
    children: [
      Expanded(
        child: _NumberField(rate, rateLabel, suffix: '%', onChanged: _refresh),
      ),
      const SizedBox(width: 10),
      Expanded(child: _NumberField(months, 'Meses', onChanged: _refresh)),
    ],
  );

  List<Widget> _invest(double? x, double? y, double? r, int n) {
    final res = r == null || n <= 0 ? null : compound(initial: x ?? 0, monthlyRate: r, months: n, monthly: y ?? 0);
    return [
      _NumberField(a, 'Valor inicial', prefix: 'R\$ ', onChanged: _refresh),
      const SizedBox(height: 12),
      _NumberField(b, 'Aporte por mês (opcional)', prefix: 'R\$ ', onChanged: _refresh),
      const SizedBox(height: 12),
      _common(),
      _Result('Total ao final', res == null ? '—' : _money(res.total)),
      _Result('Você investiu', res == null ? '—' : _money(res.invested)),
      _Result('Juros ganhos', res == null ? '—' : _money(res.interest), color: AppTheme.positive),
    ];
  }

  List<Widget> _loan(double? x, double? r, int n) {
    final p = x == null || r == null || n <= 0 ? null : installmentValue(principal: x, monthlyRate: r, months: n);
    return [
      _NumberField(a, 'Valor financiado', prefix: 'R\$ ', onChanged: _refresh),
      const SizedBox(height: 12),
      _common(),
      _Result('Parcela', p == null ? '—' : '${n}x de ${_money(p)}'),
      _Result('Total pago', p == null ? '—' : _money(p * n)),
      _Result('Juros pagos', p == null ? '—' : _money(p * n - x!), color: AppTheme.negative),
    ];
  }

  List<Widget> _compare(double? cash, double? parcel, double? r, int n) {
    String verdict = '—';
    String implied = '—';
    if (cash != null && parcel != null && n > 0) {
      final rateImplied = impliedMonthlyRate(principal: cash, installment: parcel, months: n);
      implied = rateImplied == null ? 'Parcelado sai mais barato que à vista' : '${formatNumber(rateImplied)}% ao mês';
      if (r != null) {
        final pv = presentValue(installment: parcel, months: n, monthlyReturn: r);
        verdict = pv < cash
            ? 'Parcelar compensa: economia de ${_money(cash - pv)} em valores de hoje'
            : 'À vista compensa: economia de ${_money(pv - cash)} em valores de hoje';
      }
    }
    return [
      _NumberField(a, 'Preço à vista', prefix: 'R\$ ', onChanged: _refresh),
      const SizedBox(height: 12),
      _NumberField(b, 'Valor da parcela', prefix: 'R\$ ', onChanged: _refresh),
      const SizedBox(height: 12),
      _common(rateLabel: 'Seu dinheiro rende'),
      _Result('Juros embutidos no parcelado', implied),
      _Result('Conclusão', verdict),
    ];
  }
}

// ---------- Sorteio ----------

class DrawPage extends StatefulWidget {
  final Random? random;

  const DrawPage({super.key, this.random});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  late final Random random = widget.random ?? Random.secure();
  int mode = 0;
  final names = TextEditingController();
  final minC = TextEditingController(text: '1');
  final maxC = TextEditingController(text: '100');
  int perTeam = 5;
  int count = 1;
  List<List<String>>? teams;
  String? winner;
  List<int>? numbers;
  String? coin;

  @override
  void dispose() {
    names.dispose();
    minC.dispose();
    maxC.dispose();
    super.dispose();
  }

  List<String> get people => parseNames(names.text);

  void _drawTeams() {
    HapticFeedback.mediumImpact();
    setState(() => teams = drawTeams(people, perTeam, random));
  }

  void _drawName() {
    final list = people;
    if (list.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => winner = list[random.nextInt(list.length)]);
  }

  void _drawNumbers() {
    final a = int.tryParse(minC.text.trim()), b = int.tryParse(maxC.text.trim());
    if (a == null || b == null || b < a || b - a > 1000000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confira o intervalo de números')));
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => numbers = count == 1 ? [drawNumber(a, b, random)] : drawNumbers(a, b, count, random));
  }

  void _copyTeams() {
    final text = [for (var i = 0; i < teams!.length; i++) 'Time ${i + 1}: ${teams![i].join(', ')}'].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Times copiados')));
  }

  Widget _namesField() => TextField(
    controller: names,
    minLines: 4,
    maxLines: 10,
    textCapitalization: TextCapitalization.words,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: 'Nomes (um por linha ou separados por vírgula)',
      alignLabelWithHint: true,
      helperText: '${people.length} ${people.length == 1 ? 'nome' : 'nomes'}',
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sorteio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Times')),
              ButtonSegment(value: 1, label: Text('Nomes')),
              ButtonSegment(value: 2, label: Text('Nº')),
              ButtonSegment(value: 3, label: Text('Moeda')),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => mode = s.first),
          ),
          const SizedBox(height: 16),
          ...switch (mode) {
            0 => _teams(),
            1 => _name(),
            2 => _number(),
            _ => _coin(),
          },
        ],
      ),
    );
  }

  List<Widget> _teams() {
    final t = Theme.of(context).textTheme;
    final list = teams;
    final total = people.length;
    final leftover = perTeam == 0 ? 0 : total % perTeam;
    return [
      _namesField(),
      const SizedBox(height: 8),
      _Stepper('Pessoas por time', perTeam, (v) => setState(() => perTeam = v), max: 50),
      if (total > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${(total / perTeam).ceil()} time(s)${leftover == 0 ? '' : '; o último fica com $leftover pessoa(s)'}',
            style: t.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
        ),
      FilledButton.icon(
        onPressed: total == 0 ? null : _drawTeams,
        icon: const Icon(Icons.groups_outlined),
        label: Text(list == null ? 'Sortear times' : 'Sortear de novo'),
      ),
      if (list != null) ...[
        const SizedBox(height: 16),
        for (var i = 0; i < list.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Time ${i + 1} (${list[i].length})', style: t.titleSmall),
                  const SizedBox(height: 6),
                  for (final name in list[i]) Padding(padding: const EdgeInsets.only(top: 3), child: Text(name)),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(onPressed: _copyTeams, icon: const Icon(Icons.copy), label: const Text('Copiar times')),
      ],
    ];
  }

  List<Widget> _name() => [
    _namesField(),
    const SizedBox(height: 12),
    FilledButton.icon(
      onPressed: people.isEmpty ? null : _drawName,
      icon: const Icon(Icons.casino_outlined),
      label: const Text('Sortear nome'),
    ),
    if (winner != null) _Result('Sorteado', winner!),
  ];

  List<Widget> _number() => [
    Row(
      children: [
        Expanded(child: _NumberField(minC, 'De')),
        const SizedBox(width: 10),
        Expanded(child: _NumberField(maxC, 'Até')),
      ],
    ),
    const SizedBox(height: 4),
    _Stepper('Quantos números', count, (v) => setState(() => count = v), max: 50),
    FilledButton.icon(onPressed: _drawNumbers, icon: const Icon(Icons.casino_outlined), label: const Text('Sortear')),
    if (numbers != null) _Result(numbers!.length == 1 ? 'Número' : 'Números (sem repetir)', numbers!.join(', ')),
  ];

  List<Widget> _coin() => [
    CoinFlip(random: random, result: coin, onResult: (v) => setState(() => coin = v)),
    if (coin != null) _Result('Resultado', coin!),
  ];
}
