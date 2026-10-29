import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../info/info_store.dart';
import '../info/weather.dart';
import '../settings/settings.dart';
import 'recurrence.dart';
import 'reminder.dart';
import 'reminders_store.dart';

const kindLabels = {
  RecKind.once: 'Uma vez',
  RecKind.weekly: 'Dias da semana',
  RecKind.interval: 'A cada X tempo',
  RecKind.monthlyDay: 'Todo mês no dia N',
  RecKind.monthlyNth: 'N-ésimo dia da semana do mês',
  RecKind.yearly: 'Todo ano',
  RecKind.afterCompletion: 'X tempo depois de concluir',
  RecKind.relativeDate: 'Antes/depois de uma data',
  RecKind.chain: 'Corrente (depois de outro lembrete)',
  RecKind.location: 'Ao chegar/sair de um lugar',
  RecKind.condition: 'Condição externa (clima/cotação)',
};

const ruleLabels = {
  BusinessRule.ignore: 'Ignorar feriados e fins de semana',
  BusinessRule.skip: 'Pular',
  BusinessRule.next: 'Mover para o próximo dia útil',
  BusinessRule.previous: 'Antecipar para o dia útil anterior',
};

const unitLabels = {IntervalUnit.minutes: 'minutos', IntervalUnit.hours: 'horas', IntervalUnit.days: 'dias'};

/// Editor completo de um lembrete. Recebe um lembrete existente ou um
/// rascunho (título + recorrência) vindo do texto livre.
class ReminderEditor extends StatefulWidget {
  final Reminder? reminder;
  final String? draftTitle;
  final Recurrence? draftRec;

  const ReminderEditor({super.key, this.reminder, this.draftTitle, this.draftRec});

  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  late final TextEditingController title;
  late final TextEditingController notes;
  late Category category;
  late bool alarm;
  late int insistEvery;
  late int insistMax;

  // Estado da recorrência.
  late RecKind kind;
  DateTime? at;
  List<HM> times = [];
  Set<int> weekdays = {};
  int every = 1;
  IntervalUnit unit = IntervalUnit.hours;
  bool useWindow = false;
  HM windowStart = const HM(8, 0);
  HM windowEnd = const HM(18, 0);
  int monthDay = 1;
  int nth = 1;
  int nthWeekday = 1;
  int month = 1;
  int day = 1;
  DateTime? target;
  List<int> offsets = [];
  bool repeatYearly = false;
  String? chainFrom;
  int chainDelay = 30;
  double? lat;
  double? lon;
  int radius = 200;
  bool onEnter = true;
  late final TextEditingController placeName;
  ConditionType condition = ConditionType.rainToday;
  late final TextEditingController threshold;
  BusinessRule rule = BusinessRule.ignore;
  DateTime? anchor;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    final rec = r?.rec ?? widget.draftRec ?? Recurrence(kind: RecKind.once, at: _defaultAt());
    title = TextEditingController(text: r?.title ?? widget.draftTitle ?? '');
    notes = TextEditingController(text: r?.notes ?? '');
    category = r?.category ?? Category.pessoal;
    alarm = r?.alarm ?? false;
    insistEvery = r?.insistEveryMin ?? 0;
    insistMax = r?.insistMax ?? 0;
    kind = rec.kind;
    at = rec.at ?? _defaultAt();
    times = [...rec.times];
    weekdays = {...rec.weekdays};
    every = rec.every;
    unit = rec.unit;
    useWindow = rec.windowStart != null;
    windowStart = rec.windowStart ?? const HM(8, 0);
    windowEnd = rec.windowEnd ?? const HM(18, 0);
    monthDay = rec.monthDay;
    nth = rec.nth;
    nthWeekday = rec.nthWeekday;
    month = rec.month;
    day = rec.day;
    target = rec.target;
    offsets = [...rec.offsets];
    repeatYearly = rec.repeatYearly;
    chainFrom = rec.chainFrom;
    chainDelay = rec.chainDelayMin == 0 ? 30 : rec.chainDelayMin;
    lat = rec.lat;
    lon = rec.lon;
    radius = rec.radiusM;
    onEnter = rec.onEnter;
    placeName = TextEditingController(text: rec.placeName ?? '');
    condition = rec.condition ?? ConditionType.rainToday;
    threshold = TextEditingController(text: rec.threshold == 0 ? '' : _num(rec.threshold));
    rule = rec.businessRule;
    anchor = rec.anchor;
  }

  /// Aceita "5,40", "5.40" e "1.234,56".
  static double _parseNumber(String s) {
    final t = s.trim();
    final normalized = t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
    return double.tryParse(normalized) ?? 0;
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static DateTime _defaultAt() {
    final n = DateTime.now().add(const Duration(hours: 1));
    return DateTime(n.year, n.month, n.day, n.hour);
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    placeName.dispose();
    threshold.dispose();
    super.dispose();
  }

  Recurrence _build() => Recurrence(
        kind: kind,
        at: at,
        times: times,
        weekdays: weekdays,
        every: every < 1 ? 1 : every,
        unit: unit,
        windowStart: kind == RecKind.interval && unit != IntervalUnit.days && useWindow ? windowStart : null,
        windowEnd: kind == RecKind.interval && unit != IntervalUnit.days && useWindow ? windowEnd : null,
        anchor: anchor ??
            (kind == RecKind.interval && unit == IntervalUnit.days ? dayOf(DateTime.now()) : DateTime.now()),
        monthDay: monthDay,
        nth: nth,
        nthWeekday: nthWeekday,
        month: month,
        day: day,
        target: target,
        offsets: offsets,
        repeatYearly: repeatYearly,
        chainFrom: chainFrom,
        chainDelayMin: chainDelay,
        lat: lat,
        lon: lon,
        radiusM: radius,
        onEnter: onEnter,
        placeName: placeName.text.trim().isEmpty ? null : placeName.text.trim(),
        condition: condition,
        threshold: _parseNumber(threshold.text),
        businessRule: rule,
      );

  String? _validate() {
    switch (kind) {
      case RecKind.once:
        if (at == null) return 'Escolha a data e a hora.';
      case RecKind.relativeDate:
        if (target == null) return 'Escolha a data-alvo.';
        if (offsets.isEmpty) return 'Adicione ao menos um deslocamento (ex.: 7 dias antes).';
      case RecKind.chain:
        if (chainFrom == null) return 'Escolha o lembrete A da corrente.';
      case RecKind.location:
        if (lat == null || lon == null) return 'Defina o lugar.';
      case RecKind.condition:
        if (threshold.text.trim().isEmpty) return 'Informe o valor da condição.';
      default:
        break;
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final store = context.read<RemindersStore>();
    final rec = _build();
    final r = widget.reminder;
    if (r == null) {
      await store.add(
        title: title.text.trim(),
        rec: rec,
        category: category,
        alarm: alarm,
        insistEveryMin: insistEvery,
        insistMax: insistMax,
        notes: notes.text.trim(),
      );
    } else {
      final kindChanged = r.rec.kind != rec.kind;
      r
        ..title = title.text.trim().isEmpty ? 'Lembrete' : title.text.trim()
        ..notes = notes.text.trim()
        ..category = category
        ..rec = rec
        ..alarm = alarm
        ..insistEveryMin = insistEvery
        ..insistMax = insistMax
        ..enabled = true;
      if (kindChanged || rec.kind == RecKind.once) {
        r.lastCompleted = null;
        r.doneUntil = null;
      }
      await store.save(r);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final r = widget.reminder;
    if (r == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir lembrete?'),
        content: Text(r.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<RemindersStore>().remove(r);
    if (mounted) Navigator.pop(context, true);
  }

  Future<HM?> _pickTime(HM initial) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: initial.h, minute: initial.m));
    return t == null ? null : HM(t.hour, t.minute);
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

  Widget _timesEditor() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final t in [...times]..sort())
          InputChip(
            label: Text(t.format()),
            onPressed: () async {
              final n = await _pickTime(t);
              if (n != null) setState(() => times[times.indexOf(t)] = n);
            },
            onDeleted: () => setState(() => times.remove(t)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: Text(times.isEmpty ? 'Horário (padrão 09:00)' : 'Horário'),
          onPressed: () async {
            final n = await _pickTime(const HM(9, 0));
            if (n != null && !times.contains(n)) setState(() => times.add(n));
          },
        ),
      ],
    );
  }

  Widget _weekdayPicker() => Wrap(
        spacing: 6,
        children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              label: Text(weekdayShort[d]),
              selected: weekdays.contains(d),
              onSelected: (v) => setState(() => v ? weekdays.add(d) : weekdays.remove(d)),
            ),
        ],
      );

  Widget _numberField(String label, int value, ValueChanged<int> onChanged, {int min = 1, int max = 9999}) {
    return SizedBox(
      width: 120,
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        onChanged: (s) {
          final v = int.tryParse(s);
          if (v != null) onChanged(v.clamp(min, max));
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  List<Widget> _kindFields() {
    switch (kind) {
      case RecKind.once:
        return [
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(at == null ? 'Data' : '${two(at!.day)}/${two(at!.month)}/${at!.year}'),
              onPressed: () async {
                final d = await _pickDate(at);
                if (d != null) setState(() => at = DateTime(d.year, d.month, d.day, at?.hour ?? 9, at?.minute ?? 0));
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(at == null ? 'Hora' : hm(at!)),
              onPressed: () async {
                final t = await _pickTime(at == null ? const HM(9, 0) : HM(at!.hour, at!.minute));
                final base = at ?? DateTime.now();
                if (t != null) setState(() => at = DateTime(base.year, base.month, base.day, t.h, t.m));
              },
            ),
          ]),
        ];
      case RecKind.weekly:
        return [
          _weekdayPicker(),
          const SizedBox(height: 4),
          Text('Nenhum dia marcado = todos os dias (diário).', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          _timesEditor(),
        ];
      case RecKind.interval:
        return [
          Row(children: [
            _numberField('A cada', every, (v) => setState(() => every = v)),
            const SizedBox(width: 12),
            DropdownButton<IntervalUnit>(
              value: unit,
              items: [for (final u in IntervalUnit.values) DropdownMenuItem(value: u, child: Text(unitLabels[u]!))],
              onChanged: (u) => setState(() => unit = u!),
            ),
          ]),
          if (unit != IntervalUnit.days) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Só numa janela do dia (recomeça todo dia)'),
              value: useWindow,
              onChanged: (v) => setState(() => useWindow = v),
            ),
            if (useWindow)
              Wrap(spacing: 8, children: [
                OutlinedButton(
                  onPressed: () async {
                    final t = await _pickTime(windowStart);
                    if (t != null) setState(() => windowStart = t);
                  },
                  child: Text('Das ${windowStart.format()}'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final t = await _pickTime(windowEnd);
                    if (t != null) setState(() => windowEnd = t);
                  },
                  child: Text('às ${windowEnd.format()}'),
                ),
              ]),
          ] else
            _timesEditor(),
          const SizedBox(height: 8),
          const Text('Só nestes dias da semana (opcional):'),
          _weekdayPicker(),
        ];
      case RecKind.monthlyDay:
        return [
          Row(children: [
            _numberField('Dia', monthDay, (v) => setState(() => monthDay = v), max: 31),
            const SizedBox(width: 12),
            const Expanded(child: Text('31 = último dia do mês')),
          ]),
          const SizedBox(height: 8),
          _timesEditor(),
        ];
      case RecKind.monthlyNth:
        return [
          Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            DropdownButton<int>(
              value: nth,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1ª')),
                DropdownMenuItem(value: 2, child: Text('2ª')),
                DropdownMenuItem(value: 3, child: Text('3ª')),
                DropdownMenuItem(value: 4, child: Text('4ª')),
                DropdownMenuItem(value: 5, child: Text('5ª')),
                DropdownMenuItem(value: -1, child: Text('Última')),
              ],
              onChanged: (v) => setState(() => nth = v!),
            ),
            DropdownButton<int>(
              value: nthWeekday,
              items: [for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text(weekdayLong[d]))],
              onChanged: (v) => setState(() => nthWeekday = v!),
            ),
            const Text('do mês'),
          ]),
          _timesEditor(),
        ];
      case RecKind.yearly:
        return [
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text('${two(day)}/${two(month)}'),
            onPressed: () async {
              final d = await _pickDate(DateTime(DateTime.now().year, month, day));
              if (d != null) {
                setState(() {
                  day = d.day;
                  month = d.month;
                });
              }
            },
          ),
          const SizedBox(height: 8),
          _timesEditor(),
        ];
      case RecKind.afterCompletion:
        return [
          Row(children: [
            _numberField('Depois de', every, (v) => setState(() => every = v)),
            const SizedBox(width: 12),
            DropdownButton<IntervalUnit>(
              value: unit,
              items: [for (final u in IntervalUnit.values) DropdownMenuItem(value: u, child: Text(unitLabels[u]!))],
              onChanged: (u) => setState(() => unit = u!),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('Conta a partir da última vez que você marcou "feito". Se atrasar, lembra 1x por dia até concluir.'),
          if (unit == IntervalUnit.days) ...[const SizedBox(height: 8), _timesEditor()],
        ];
      case RecKind.relativeDate:
        return [
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(target == null ? 'Data-alvo' : '${two(target!.day)}/${two(target!.month)}/${target!.year}'),
            onPressed: () async {
              final d = await _pickDate(target);
              if (d != null) setState(() => target = d);
            },
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final o in [...offsets]..sort())
              InputChip(
                label: Text(o == 0 ? 'No dia' : (o < 0 ? '${-o} dia(s) antes' : '$o dia(s) depois')),
                onDeleted: () => setState(() => offsets.remove(o)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Aviso'),
              onPressed: _addOffset,
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repetir todo ano'),
            value: repeatYearly,
            onChanged: (v) => setState(() => repeatYearly = v),
          ),
          _timesEditor(),
        ];
      case RecKind.chain:
        final others = context.read<RemindersStore>().items.where((e) => e.id != widget.reminder?.id).toList();
        return [
          DropdownButtonFormField<String>(
            initialValue: others.any((e) => e.id == chainFrom) ? chainFrom : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Quando eu concluir…', border: OutlineInputBorder()),
            items: [for (final o in others) DropdownMenuItem(value: o.id, child: Text(o.title, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => chainFrom = v),
          ),
          const SizedBox(height: 8),
          _numberField('…avisar após (min)', chainDelay, (v) => setState(() => chainDelay = v), min: 0),
        ];
      case RecKind.location:
        return [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Ao chegar'), icon: Icon(Icons.login)),
              ButtonSegment(value: false, label: Text('Ao sair'), icon: Icon(Icons.logout)),
            ],
            selected: {onEnter},
            onSelectionChanged: (s) => setState(() => onEnter = s.first),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: placeName,
            decoration: const InputDecoration(labelText: 'Nome do lugar (ex.: Casa)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text('Usar onde estou'),
              onPressed: () async {
                final p = await currentPosition();
                if (!mounted) return;
                if (p == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Não consegui a localização. Verifique a permissão.')));
                  return;
                }
                setState(() {
                  lat = p.latitude;
                  lon = p.longitude;
                });
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Buscar cidade'),
              onPressed: () async {
                final pl = await showCitySearch(context);
                if (pl != null) {
                  setState(() {
                    lat = pl.lat;
                    lon = pl.lon;
                    if (placeName.text.isEmpty) placeName.text = pl.name.split(',').first;
                  });
                }
              },
            ),
          ]),
          if (lat != null)
            Text('Coordenadas: ${lat!.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall),
          Text('Raio: $radius m'),
          Slider(
            value: radius.toDouble(),
            min: 100,
            max: 3000,
            divisions: 29,
            label: '$radius m',
            onChanged: (v) => setState(() => radius = v.round()),
          ),
          Text('Funciona em segundo plano (checagem a cada ~15 min) e exige a permissão de localização '
              '"Permitir o tempo todo" (Mais → Configurações → Permissões).',
              style: Theme.of(context).textTheme.bodySmall),
        ];
      case RecKind.condition:
        return [
          DropdownButtonFormField<ConditionType>(
            initialValue: condition,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Condição', border: OutlineInputBorder()),
            items: [for (final c in ConditionType.values) DropdownMenuItem(value: c, child: Text(conditionLabel(c)))],
            onChanged: (v) => setState(() => condition = v!),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: threshold,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Valor',
              suffixText: conditionSuffix(condition).isEmpty ? 'R\$' : conditionSuffix(condition),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          Text('Checado em segundo plano; no máximo 1 aviso por dia. Clima usa a cidade das configurações.',
              style: Theme.of(context).textTheme.bodySmall),
        ];
    }
  }

  Future<void> _addOffset() async {
    var n = 1;
    var before = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Novo aviso'),
          content: Row(children: [
            SizedBox(
              width: 70,
              child: TextFormField(
                initialValue: '1',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (s) => n = int.tryParse(s) ?? 0,
              ),
            ),
            const SizedBox(width: 8),
            const Text('dia(s)'),
            const SizedBox(width: 8),
            DropdownButton<bool>(
              value: before,
              items: const [
                DropdownMenuItem(value: true, child: Text('antes')),
                DropdownMenuItem(value: false, child: Text('depois')),
              ],
              onChanged: (v) => set(() => before = v!),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Adicionar')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final v = before ? -n : n;
      if (!offsets.contains(v)) setState(() => offsets.add(v));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RemindersStore>();
    final s = context.watch<SettingsStore>().value;
    final rec = _build();
    String preview;
    if (!rec.isTimeBased) {
      preview = describeRecurrence(rec);
    } else {
      final n = nextOccurrence(
          rec,
          DateTime.now(),
          EngineContext(
            holidays: s.calendar,
            createdAt: widget.reminder?.createdAt ?? DateTime.now(),
            chainSourceCompleted: kind == RecKind.chain ? store.byId(chainFrom)?.lastCompleted : null,
          ));
      preview = n == null
          ? (kind == RecKind.chain ? 'Aguardando concluir o lembrete A' : 'Sem próximas ocorrências')
          : 'Próximo: ${friendlyWhen(n)}';
    }
    final dateBased = {
      RecKind.weekly,
      RecKind.monthlyDay,
      RecKind.monthlyNth,
      RecKind.yearly,
      RecKind.relativeDate,
      RecKind.interval,
    }.contains(kind);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reminder == null ? 'Novo lembrete' : 'Editar lembrete'),
        actions: [
          if (widget.reminder != null) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          TextField(
            controller: title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final c in Category.values)
              ChoiceChip(
                avatar: Icon(c.icon, size: 18, color: c.color),
                label: Text(c.label),
                selected: category == c,
                onSelected: (_) => setState(() => category = c),
              ),
          ]),
          _section('Repetição', [
            DropdownButtonFormField<RecKind>(
              initialValue: kind,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [for (final k in RecKind.values) DropdownMenuItem(value: k, child: Text(kindLabels[k]!))],
              onChanged: (k) => setState(() {
                kind = k!;
                anchor = null;
                if (kind == RecKind.afterCompletion && unit == IntervalUnit.hours && every == 1) unit = IntervalUnit.days;
              }),
            ),
            const SizedBox(height: 12),
            ..._kindFields(),
          ]),
          if (dateBased)
            _section('Feriados e fins de semana', [
              DropdownButtonFormField<BusinessRule>(
                initialValue: rule,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [for (final r in BusinessRule.values) DropdownMenuItem(value: r, child: Text(ruleLabels[r]!))],
                onChanged: (v) => setState(() => rule = v!),
              ),
            ]),
          _section('Alerta', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alarme em tela cheia'),
              subtitle: const Text('Toca o som de alarme até você responder'),
              value: alarm,
              onChanged: (v) => setState(() => alarm = v),
            ),
            Row(children: [
              _numberField('Insistir a cada (min)', insistEvery, (v) => setState(() => insistEvery = v), min: 0),
              const SizedBox(width: 12),
              _numberField('Até N vezes', insistMax, (v) => setState(() => insistMax = v), min: 0, max: 10),
            ]),
            const SizedBox(height: 4),
            Text('0 = sem insistência. Para quando você marcar como feito.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
          _section('Observações', [
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Expanded(child: Text(preview, style: Theme.of(context).textTheme.bodyMedium)),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Salvar')),
          ]),
        ),
      ),
    );
  }
}

/// Busca de cidade pela API de geocodificação do Open-Meteo.
Future<Place?> showCitySearch(BuildContext context) {
  return showDialog<Place>(context: context, builder: (_) => const _CitySearch());
}

class _CitySearch extends StatefulWidget {
  const _CitySearch();

  @override
  State<_CitySearch> createState() => _CitySearchState();
}

class _CitySearchState extends State<_CitySearch> {
  final q = TextEditingController();
  List<Place> results = [];
  bool loading = false;
  String? error;

  Future<void> _search() async {
    if (q.text.trim().length < 2) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      results = await searchCity(q.text.trim());
      if (results.isEmpty) error = 'Nenhuma cidade encontrada.';
    } catch (_) {
      error = 'Sem conexão.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar cidade'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: q,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Ex.: Campinas',
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
            ),
          ),
          if (loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
          if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!)),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final p in results)
                ListTile(title: Text(p.name), onTap: () => Navigator.pop(context, p)),
            ]),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
    );
  }
}
