import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'workout.dart';
import 'workout_store.dart';

/// Aba Treinos: exercícios da pessoa, registros e evolução no tempo.
class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key});

  Future<void> _log(BuildContext context) async {
    final store = context.read<WorkoutStore>();
    if (store.exercises.isEmpty) {
      await _newExercise(context);
      return;
    }
    final e = await showModalBottomSheet<Exercise>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Registrar treino')),
            for (final e in store.exercises)
              ListTile(leading: Icon(e.kind.icon), title: Text(e.name), onTap: () => Navigator.pop(c, e)),
          ],
        ),
      ),
    );
    if (e != null && context.mounted) await showLogEditor(context, e);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final now = DateTime.now();
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppTheme.textMuted);
    final week = store.week(now), last = store.week(now, weeksAgo: 1);
    final weight = store.latestMeasure('peso');
    final added = {for (final e in store.exercises) e.name.toLowerCase()};
    final suggestions = exercisePresets.where((p) => !added.contains(p.$1.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treinos'),
        actions: [
          IconButton(tooltip: 'Novo exercício', icon: const Icon(Icons.add), onPressed: () => _newExercise(context)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'workout-log',
        onPressed: () => _log(context),
        icon: const Icon(Icons.add_task),
        label: const Text('Registrar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Esta semana', style: t.titleMedium),
                  const SizedBox(height: 4),
                  Text('${week.days} dia(s) de treino · semana passada: ${last.days}', style: t.bodyMedium),
                  if (week.minutes > 0 || week.reps > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (week.minutes > 0) '${fmtNum(week.minutes)} min de cardio',
                        if (week.km > 0) '${fmtNum(week.km)} km',
                        if (week.reps > 0) '${week.reps} repetições',
                      ].join(' · '),
                      style: muted,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_weight_outlined),
              title: const Text('Medidas corporais'),
              subtitle: Text(
                weight == null ? 'Registre peso e medidas para ver a evolução' : 'Peso atual: ${fmtNum(weight)} kg',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeasuresPage())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Text('Meus exercícios', style: t.titleMedium),
          ),
          if (store.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text('Adicione os exercícios que você faz.', style: muted),
            ),
          for (final e in store.exercises) _ExerciseCard(exercise: e),
          // As sugestões continuam aparecendo até todas serem adicionadas.
          if (suggestions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Text('Toque para adicionar:', style: muted),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (name, kind) in suggestions)
                  ActionChip(
                    avatar: Icon(kind.icon, size: 18),
                    label: Text(name),
                    onPressed: () => store.addExercise(name, kind),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final logs = store.logsFor(exercise.id);
    final last = logs.firstOrNull;
    return Card(
      child: ListTile(
        leading: Icon(exercise.kind.icon),
        title: Text(exercise.name),
        subtitle: Text(
          last == null ? 'Nenhum registro ainda' : '${friendlyDay(last.date)}: ${describeLog(last, exercise.kind)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        trailing: IconButton(
          tooltip: 'Registrar ${exercise.name}',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => showLogEditor(context, exercise),
        ),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailPage(exerciseId: exercise.id))),
      ),
    );
  }
}

String friendlyDay(DateTime d, {DateTime? now}) {
  final n = dayOf(now ?? DateTime.now());
  final diff = n.difference(dayOf(d)).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  return '${two(d.day)}/${two(d.month)}';
}

Future<void> _newExercise(BuildContext context) async {
  final name = TextEditingController();
  var kind = ExerciseKind.cardio;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setDialog) => AlertDialog(
        title: const Text('Novo exercício'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Corrida, Flexão'),
            ),
            const SizedBox(height: 12),
            RadioGroup<ExerciseKind>(
              groupValue: kind,
              onChanged: (v) => setDialog(() => kind = v!),
              child: Column(
                children: [
                  for (final k in ExerciseKind.values)
                    RadioListTile<ExerciseKind>(
                      contentPadding: EdgeInsets.zero,
                      value: k,
                      title: Text(k.label),
                      subtitle: Text(k.hint),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Adicionar')),
        ],
      ),
    ),
  );
  final text = name.text.trim();
  if (ok != true || text.isEmpty || !context.mounted) return;
  await context.read<WorkoutStore>().addExercise(text, kind);
}

Future<void> showLogEditor(BuildContext context, Exercise e) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => LogEditorPage(exercise: e)));

class LogEditorPage extends StatefulWidget {
  final Exercise exercise;

  const LogEditorPage({super.key, required this.exercise});

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  final a = TextEditingController();
  final b = TextEditingController();
  late final sets = TextEditingController(text: widget.exercise.kind == ExerciseKind.cardio ? '' : '3');
  DateTime date = DateTime.now();
  String? error;

  @override
  void dispose() {
    a.dispose();
    b.dispose();
    sets.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kind = widget.exercise.kind;
    final first = parseNum(a.text) ?? 0, second = parseNum(b.text) ?? 0;
    final n = int.tryParse(sets.text.trim()) ?? 1;
    final log = WorkoutLog(id: WorkoutStore.newId(), exerciseId: widget.exercise.id, date: date);
    switch (kind) {
      case ExerciseKind.cardio:
        if (first <= 0 && second <= 0) return setState(() => error = 'Informe o tempo ou a distância');
        log
          ..minutes = first
          ..km = second;
      case ExerciseKind.reps:
        if (first <= 0 || n <= 0) return setState(() => error = 'Informe séries e repetições');
        log
          ..sets = n
          ..reps = first.round();
      case ExerciseKind.hold:
        if (first <= 0 || n <= 0) return setState(() => error = 'Informe séries e segundos');
        log
          ..sets = n
          ..seconds = first.round();
    }
    final store = context.read<WorkoutStore>();
    final record = store.best(widget.exercise);
    await store.addLog(log);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final value = mainValue(log, kind);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(record > 0 && value > record ? 'Novo recorde em ${widget.exercise.name}!' : 'Treino registrado'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.exercise.kind;
    InputDecoration field(String label, String? suffix) => InputDecoration(labelText: label, suffixText: suffix);
    const number = TextInputType.numberWithOptions(decimal: true);
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(friendlyDay(date)),
            trailing: const Text('Mudar data'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => date = DateTime(d.year, d.month, d.day, date.hour, date.minute));
            },
          ),
          const SizedBox(height: 8),
          if (kind == ExerciseKind.cardio) ...[
            TextField(controller: a, keyboardType: number, inputFormatters: digits, decoration: field('Tempo', 'min')),
            const SizedBox(height: 12),
            TextField(
              controller: b,
              keyboardType: number,
              inputFormatters: digits,
              decoration: field('Distância (opcional)', 'km'),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sets,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: field('Séries', null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: a,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: kind == ExerciseKind.reps
                        ? field('Repetições por série', null)
                        : field('Segundos por série', 's'),
                  ),
                ),
              ],
            ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: AppTheme.negative)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Salvar')),
        ),
      ),
    );
  }
}

class ExerciseDetailPage extends StatefulWidget {
  final String exerciseId;

  const ExerciseDetailPage({super.key, required this.exerciseId});

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  TrendPeriod period = TrendPeriod.d90;

  Future<void> _delete(Exercise e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Excluir ${e.name}?'),
        content: const Text('Todos os registros deste exercício também serão apagados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = context.read<WorkoutStore>();
    Navigator.pop(context);
    await store.removeExercise(e);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final e = store.exercise(widget.exerciseId);
    if (e == null) return Scaffold(appBar: AppBar());
    final now = DateTime.now();
    final t = Theme.of(context).textTheme;
    final all = store.logsFor(e.id);
    final inPeriod = all.where((l) => period.includes(l.date, now)).toList();
    final usesKm = e.kind != ExerciseKind.cardio || all.any((l) => l.km > 0);
    final unit = mainUnit(e.kind, usesKm: usesKm);
    final paces = inPeriod.map((l) => l.pace).whereType<double>().toList();

    Widget stat(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(value, style: t.titleLarge, textAlign: TextAlign.center),
          Text(label, style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(e.name),
        actions: [IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(e))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'exercise-log',
        onPressed: () => showLogEditor(context, e),
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          SegmentedButton<TrendPeriod>(
            segments: [for (final p in TrendPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => period = s.first),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  stat('Treinos', '${inPeriod.length}'),
                  stat('Recorde', '${fmtNum(store.best(e))} $unit'),
                  if (e.kind == ExerciseKind.cardio)
                    stat(
                      paces.isEmpty ? 'Minutos' : 'Ritmo médio',
                      paces.isEmpty
                          ? fmtNum(inPeriod.fold(0.0, (s, l) => s + l.minutes))
                          : formatPace(paces.reduce((a, b) => a + b) / paces.length),
                    )
                  else
                    stat('Total', '${fmtNum(inPeriod.fold(0.0, (s, l) => s + mainValue(l, e.kind)))} $unit'),
                ],
              ),
            ),
          ),
          TrendChart(points: store.series(e, period, now), unit: unit, period: period, now: now),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
            child: Text('Histórico', style: t.titleMedium),
          ),
          if (all.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Nenhum registro ainda.', style: TextStyle(color: AppTheme.textMuted)),
            ),
          for (final l in all)
            ListTile(
              dense: true,
              title: Text(describeLog(l, e.kind)),
              subtitle: Text(friendlyDay(l.date), style: const TextStyle(color: AppTheme.textMuted)),
              trailing: IconButton(
                tooltip: 'Apagar registro',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => store.removeLog(l),
              ),
            ),
        ],
      ),
    );
  }
}

/// Linha da evolução no período. Com menos de dois pontos, explica o que falta.
class TrendChart extends StatelessWidget {
  final List<(DateTime, double)> points;
  final String unit;
  final TrendPeriod period;
  final DateTime now;

  const TrendChart({super.key, required this.points, required this.unit, required this.period, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (points.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Registre pelo menos dois dias neste período para ver o gráfico de evolução.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
        ),
      );
    }
    final start = dayOf(points.first.$1);
    double x(DateTime d) => dayOf(d).difference(start).inDays.toDouble();
    final values = points.map((p) => p.$2);
    final low = values.reduce((a, b) => a < b ? a : b), high = values.reduce((a, b) => a > b ? a : b);
    final pad = high == low ? (high == 0 ? 1.0 : high * 0.1) : (high - low) * 0.15;
    final change = points.last.$2 - points.first.$2;
    final color = AppTheme.accent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 10),
              child: Text(
                '${change >= 0 ? '+' : '−'}${fmtNum(change.abs())} $unit desde ${friendlyDay(points.first.$1, now: now).toLowerCase()}',
                style: t.titleSmall,
              ),
            ),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: low - pad,
                  maxY: high + pad,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: x(points.last.$1) <= 0 ? 1 : x(points.last.$1),
                        getTitlesWidget: (v, meta) {
                          final d = DateTime(start.year, start.month, start.day + v.round());
                          return Text('${two(d.day)}/${two(d.month)}', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (final p in points) FlSpot(x(p.$1), p.$2)],
                      color: color,
                      barWidth: 2.5,
                      dotData: FlDotData(show: points.length <= 30),
                      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MeasuresPage extends StatefulWidget {
  const MeasuresPage({super.key});

  @override
  State<MeasuresPage> createState() => _MeasuresPageState();
}

class _MeasuresPageState extends State<MeasuresPage> {
  String field = measureFields.first.$1;
  TrendPeriod period = TrendPeriod.d90;

  Future<void> _add() async {
    final controllers = {for (final f in measureFields) f.$1: TextEditingController()};
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Novas medidas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Preencha só o que mediu hoje.'),
              for (final (key, label, unit) in measureFields)
                TextField(
                  controller: controllers[key],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: InputDecoration(labelText: label, suffixText: unit),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final values = <String, double>{
      for (final e in controllers.entries)
        if (parseNum(e.value.text) case final v? when v > 0) e.key: v,
    };
    if (values.isEmpty) return;
    await context.read<WorkoutStore>().addMeasure(
      Measurement(id: WorkoutStore.newId(), date: DateTime.now(), values: values),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final now = DateTime.now();
    final (_, label, unit) = measureFields.firstWhere((f) => f.$1 == field);
    return Scaffold(
      appBar: AppBar(title: const Text('Medidas corporais')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'measure-add',
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Medir'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final (key, name, _) in measureFields)
                ChoiceChip(label: Text(name), selected: field == key, onSelected: (_) => setState(() => field = key)),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<TrendPeriod>(
            segments: [for (final p in TrendPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => period = s.first),
          ),
          const SizedBox(height: 8),
          TrendChart(points: store.measureSeries(field, period, now), unit: unit, period: period, now: now),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
            child: Text('Registros de ${label.toLowerCase()}', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final m in store.measures.where((m) => m.values[field] != null))
            ListTile(
              dense: true,
              title: Text('${fmtNum(m.values[field]!)} $unit'),
              subtitle: Text(friendlyDay(m.date), style: const TextStyle(color: AppTheme.textMuted)),
              trailing: IconButton(
                tooltip: 'Apagar medição',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => store.removeMeasure(m, field),
              ),
            ),
        ],
      ),
    );
  }
}
