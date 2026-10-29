import 'package:flutter/material.dart';

import '../core/format.dart';
import '../reminders/recurrence.dart';

enum HabitType {
  agua('Água', Icons.water_drop, Colors.blue),
  remedio('Remédio', Icons.medication, Colors.red),
  exercicio('Exercício', Icons.directions_run, Colors.green),
  personalizado('Personalizado', Icons.star, Colors.amber);

  final String label;
  final IconData icon;
  final Color color;

  const HabitType(this.label, this.icon, this.color);

  static HabitType of(String? n) => HabitType.values.firstWhere((e) => e.name == n, orElse: () => personalizado);
}

enum HabitReminderMode { none, interval, fixed }

class Habit {
  final String id;
  final int nid;
  String name;
  HabitType type;
  double goal;
  String unit;
  List<double> quick;

  /// yyyy-mm-dd → quantidade do dia.
  Map<String, double> log;

  HabitReminderMode reminderMode;
  int everyMin;
  HM windowStart;
  HM windowEnd;
  List<HM> times;

  Habit({
    required this.id,
    required this.nid,
    required this.name,
    required this.type,
    required this.goal,
    required this.unit,
    required this.quick,
    Map<String, double>? log,
    this.reminderMode = HabitReminderMode.none,
    this.everyMin = 60,
    this.windowStart = const HM(8, 0),
    this.windowEnd = const HM(20, 0),
    this.times = const [],
  }) : log = log ?? {};

  static Habit preset(HabitType t, String id, int nid) => switch (t) {
        HabitType.agua => Habit(
            id: id, nid: nid, name: 'Beber água', type: t, goal: 2000, unit: 'ml', quick: [200, 300, 500],
            reminderMode: HabitReminderMode.interval, everyMin: 60),
        HabitType.remedio => Habit(
            id: id, nid: nid, name: 'Tomar remédio', type: t, goal: 1, unit: 'dose', quick: [1],
            reminderMode: HabitReminderMode.fixed, times: const [HM(8, 0)]),
        HabitType.exercicio =>
          Habit(id: id, nid: nid, name: 'Exercício', type: t, goal: 30, unit: 'min', quick: [10, 15, 30]),
        HabitType.personalizado => Habit(id: id, nid: nid, name: 'Novo hábito', type: t, goal: 1, unit: 'vez', quick: [1]),
      };

  double amountOn(DateTime d) => log[dayKey(d)] ?? 0;

  bool metOn(DateTime d) => amountOn(d) >= goal;

  /// Sequência atual: dias seguidos com meta batida. Se hoje ainda não bateu,
  /// conta a partir de ontem.
  int streak(DateTime today) {
    var d = dayOf(today);
    if (!metOn(d)) d = DateTime(d.year, d.month, d.day - 1);
    var n = 0;
    while (metOn(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  /// Maior sequência já registrada.
  int record() {
    if (log.isEmpty) return 0;
    final days = log.entries.where((e) => e.value >= goal).map((e) => DateTime.parse(e.key)).toList()..sort();
    var best = 0, cur = 0;
    DateTime? prev;
    for (final d in days) {
      cur = (prev != null && DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(prev.year, prev.month, prev.day)).inDays == 1)
          ? cur + 1
          : 1;
      if (cur > best) best = cur;
      prev = d;
    }
    return best;
  }

  /// Fração dos últimos 30 dias (incluindo hoje) com meta batida.
  double rate30(DateTime today) {
    var met = 0;
    for (var i = 0; i < 30; i++) {
      if (metOn(DateTime(today.year, today.month, today.day - i))) met++;
    }
    return met / 30;
  }

  /// Recorrência do lembrete vinculado (nulo se não houver).
  Recurrence? get recurrence => switch (reminderMode) {
        HabitReminderMode.none => null,
        HabitReminderMode.interval => Recurrence(
            kind: RecKind.interval,
            every: everyMin,
            unit: IntervalUnit.minutes,
            windowStart: windowStart,
            windowEnd: windowEnd,
          ),
        HabitReminderMode.fixed => times.isEmpty ? null : Recurrence(kind: RecKind.weekly, times: times),
      };

  String fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'nid': nid,
        'name': name,
        'type': type.name,
        'goal': goal,
        'unit': unit,
        'quick': quick,
        'log': log,
        'reminderMode': reminderMode.name,
        'everyMin': everyMin,
        'ws': windowStart.format(),
        'we': windowEnd.format(),
        'times': times.map((t) => t.format()).toList(),
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        nid: j['nid'] as int,
        name: j['name'] as String,
        type: HabitType.of(j['type'] as String?),
        goal: (j['goal'] as num).toDouble(),
        unit: (j['unit'] as String?) ?? '',
        quick: ((j['quick'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
        log: ((j['log'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        reminderMode: HabitReminderMode.values
            .firstWhere((m) => m.name == j['reminderMode'], orElse: () => HabitReminderMode.none),
        everyMin: (j['everyMin'] as int?) ?? 60,
        windowStart: HM.parse((j['ws'] as String?) ?? '08:00'),
        windowEnd: HM.parse((j['we'] as String?) ?? '20:00'),
        times: ((j['times'] as List?) ?? const []).map((e) => HM.parse(e as String)).toList(),
      );
}
