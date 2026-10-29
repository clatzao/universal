import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../reminders/recurrence.dart';
import 'habit.dart';
import 'habits_store.dart';

class HabitsTab extends StatelessWidget {
  const HabitsTab({super.key});

  Future<void> _create(BuildContext context) async {
    final t = await showModalBottomSheet<HabitType>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Novo hábito')),
          for (final t in HabitType.values)
            ListTile(leading: Icon(t.icon, color: t.color), title: Text(t.label), onTap: () => Navigator.pop(c, t)),
        ]),
      ),
    );
    if (t == null || !context.mounted) return;
    final h = await context.read<HabitsStore>().create(t);
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => HabitDetail(habitId: h.id, editFirst: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitsStore>();
    return Scaffold(
      body: store.items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Acompanhe água, remédios, exercícios e o que mais quiser. Toque em + para começar.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [for (final h in store.items) HabitCard(habit: h)],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'habit-add',
        onPressed: () => _create(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Cartão com progresso do dia e botões rápidos (usado também na aba Hoje).
class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool compact;

  const HabitCard({super.key, required this.habit, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final store = context.read<HabitsStore>();
    final h = habit;
    final today = DateTime.now();
    final amount = h.amountOn(today);
    final progress = h.goal <= 0 ? 0.0 : (amount / h.goal).clamp(0.0, 1.0);
    final streak = h.streak(today);
    final color = AppTheme.tone(h.type.color);
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HabitDetail(habitId: h.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(h.type.icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(h.name, style: t.titleMedium)),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.surfaceHighest, borderRadius: BorderRadius.circular(10)),
                  child: Text('🔥 $streak', style: t.labelMedium),
                ),
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, minHeight: 6, borderRadius: BorderRadius.circular(3), color: color),
            const SizedBox(height: 6),
            Text('${h.fmt(amount)} de ${h.fmt(h.goal)} ${h.unit}${h.metOn(today) ? ' · meta batida ✓' : ''}',
                style: t.bodySmall?.copyWith(color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final q in h.quick)
                FilledButton.tonal(
                  onPressed: () async {
                    await store.add(h, q);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('+${h.fmt(q)} ${h.unit} em ${h.name}'),
                        action: SnackBarAction(label: 'Desfazer', onPressed: store.undo),
                      ));
                  },
                  child: Text('+${h.fmt(q)} ${h.unit}'),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class HabitDetail extends StatefulWidget {
  final String habitId;
  final bool editFirst;

  const HabitDetail({super.key, required this.habitId, this.editFirst = false});

  @override
  State<HabitDetail> createState() => _HabitDetailState();
}

class _HabitDetailState extends State<HabitDetail> {
  @override
  void initState() {
    super.initState();
    if (widget.editFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final h = context.read<HabitsStore>().items.where((e) => e.id == widget.habitId).firstOrNull;
        if (h != null) _edit(h);
      });
    }
  }

  Future<void> _edit(Habit h) => Navigator.push(context, MaterialPageRoute(builder: (_) => HabitEditor(habit: h)));

  Future<void> _adjustDay(Habit h, DateTime d) async {
    final c = TextEditingController(text: h.fmt(h.amountOn(d)));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${weekdayShort[d.weekday]} ${two(d.day)}/${two(d.month)}'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: h.unit),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.')) ?? 0),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (v != null && mounted) await context.read<HabitsStore>().setDay(h, d, v);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitsStore>();
    final h = store.items.where((e) => e.id == widget.habitId).firstOrNull;
    if (h == null) return Scaffold(appBar: AppBar());
    final today = dayOf(DateTime.now());
    final days = [for (var i = 13; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    final maxY = [h.goal, ...days.map(h.amountOn)].reduce((a, b) => a > b ? a : b) * 1.15;
    final scheme = Theme.of(context).colorScheme;

    Widget stat(String label, String value) => Expanded(
          child: Column(children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(h.name), actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(h)),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        HabitCard(habit: h),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              stat('Sequência 🔥', '${h.streak(today)}'),
              stat('Recorde', '${h.record()}'),
              stat('Últimos 30 dias', '${(h.rate30(today) * 100).round()}%'),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 200,
              child: BarChart(BarChartData(
                maxY: maxY <= 0 ? 1 : maxY,
                minY: 0,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: h.goal, color: scheme.error, strokeWidth: 1.5, dashArray: [6, 4]),
                ]),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= days.length || i.isOdd != (days.length - 1).isOdd) return const SizedBox();
                        return Text('${days[i].day}', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: h.amountOn(days[i]),
                        width: 12,
                        borderRadius: BorderRadius.circular(3),
                        color: h.metOn(days[i]) ? h.type.color : h.type.color.withValues(alpha: 0.45),
                      ),
                    ]),
                ],
              )),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Text('Toque num dia para ajustar manualmente'),
        ),
        for (final d in days.reversed)
          ListTile(
            dense: true,
            leading: Icon(h.metOn(d) ? Icons.check_circle : Icons.circle_outlined, color: h.metOn(d) ? h.type.color : null),
            title: Text(d == today ? 'Hoje' : '${weekdayShort[d.weekday]} ${two(d.day)}/${two(d.month)}'),
            trailing: Text('${h.fmt(h.amountOn(d))} ${h.unit}'),
            onTap: () => _adjustDay(h, d),
          ),
      ]),
    );
  }
}

class HabitEditor extends StatefulWidget {
  final Habit habit;

  const HabitEditor({super.key, required this.habit});

  @override
  State<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends State<HabitEditor> {
  late final TextEditingController name = TextEditingController(text: widget.habit.name);
  late final TextEditingController goal = TextEditingController(text: widget.habit.fmt(widget.habit.goal));
  late final TextEditingController unit = TextEditingController(text: widget.habit.unit);
  late final TextEditingController quick =
      TextEditingController(text: widget.habit.quick.map(widget.habit.fmt).join(', '));
  late HabitReminderMode mode = widget.habit.reminderMode;
  late int every = widget.habit.everyMin;
  late HM ws = widget.habit.windowStart;
  late HM we = widget.habit.windowEnd;
  late List<HM> times = [...widget.habit.times];

  @override
  void dispose() {
    name.dispose();
    goal.dispose();
    unit.dispose();
    quick.dispose();
    super.dispose();
  }

  Future<HM?> _pick(HM i) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: i.h, minute: i.m));
    return t == null ? null : HM(t.hour, t.minute);
  }

  Future<void> _save() async {
    final h = widget.habit;
    h.name = name.text.trim().isEmpty ? h.type.label : name.text.trim();
    h.goal = double.tryParse(goal.text.replaceAll(',', '.')) ?? h.goal;
    h.unit = unit.text.trim();
    final q = quick.text
        .split(RegExp(r'[;\s]+|,\s+'))
        .map((e) => double.tryParse(e.replaceAll(',', '.')))
        .whereType<double>()
        .where((v) => v > 0)
        .toList();
    h.quick = q.isEmpty ? [1] : q;
    h.reminderMode = mode;
    h.everyMin = every < 5 ? 5 : every;
    h.windowStart = ws;
    h.windowEnd = we;
    h.times = times..sort();
    await context.read<HabitsStore>().save(h);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir hábito?'),
        content: const Text('O histórico também será apagado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<HabitsStore>().remove(widget.habit);
    if (!mounted) return;
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar hábito'),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: goal,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Meta diária', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unidade', border: OutlineInputBorder())),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: quick,
          decoration: const InputDecoration(
            labelText: 'Botões rápidos',
            helperText: 'Valores separados por espaço ou ";" — ex.: 200 300 500',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Lembrete vinculado', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<HabitReminderMode>(
          segments: const [
            ButtonSegment(value: HabitReminderMode.none, label: Text('Nenhum')),
            ButtonSegment(value: HabitReminderMode.interval, label: Text('Intervalo')),
            ButtonSegment(value: HabitReminderMode.fixed, label: Text('Horários')),
          ],
          selected: {mode},
          onSelectionChanged: (s) => setState(() => mode = s.first),
        ),
        const SizedBox(height: 8),
        if (mode == HabitReminderMode.interval) ...[
          Row(children: [
            SizedBox(
              width: 140,
              child: TextFormField(
                initialValue: '$every',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'A cada (min)', border: OutlineInputBorder()),
                onChanged: (s) => every = int.tryParse(s) ?? every,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton(
              onPressed: () async {
                final t = await _pick(ws);
                if (t != null) setState(() => ws = t);
              },
              child: Text('Das ${ws.format()}'),
            ),
            OutlinedButton(
              onPressed: () async {
                final t = await _pick(we);
                if (t != null) setState(() => we = t);
              },
              child: Text('às ${we.format()}'),
            ),
          ]),
        ],
        if (mode == HabitReminderMode.fixed)
          Wrap(spacing: 8, children: [
            for (final t in times) InputChip(label: Text(t.format()), onDeleted: () => setState(() => times.remove(t))),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Horário'),
              onPressed: () async {
                final t = await _pick(const HM(8, 0));
                if (t != null && !times.contains(t)) setState(() => times.add(t));
              },
            ),
          ]),
        if (mode != HabitReminderMode.none)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('O lembrete para sozinho no dia em que a meta for batida.'),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Salvar')),
        ),
      ),
    );
  }
}
