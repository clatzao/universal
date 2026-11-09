import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../core/json_store.dart';
import 'workout.dart';

class WorkoutStore extends ChangeNotifier {
  List<Exercise> exercises = [];
  List<WorkoutLog> logs = [];
  List<Measurement> measures = [];

  static int _seq = 0;
  static String newId() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  Future<void> load() async {
    final j = await JsonStore.read('workouts');
    exercises = [];
    logs = [];
    measures = [];
    if (j is Map) {
      try {
        exercises = [for (final e in (j['exercises'] as List? ?? const [])) Exercise.fromJson((e as Map).cast())];
        logs = [for (final e in (j['logs'] as List? ?? const [])) WorkoutLog.fromJson((e as Map).cast())];
        measures = [for (final e in (j['measures'] as List? ?? const [])) Measurement.fromJson((e as Map).cast())];
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> save() {
    logs.sort((a, b) => b.date.compareTo(a.date));
    measures.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    return JsonStore.write('workouts', {
      'exercises': [for (final e in exercises) e.toJson()],
      'logs': [for (final l in logs) l.toJson()],
      'measures': [for (final m in measures) m.toJson()],
    });
  }

  Exercise? exercise(String id) => exercises.where((e) => e.id == id).firstOrNull;

  Future<Exercise> addExercise(String name, ExerciseKind kind) async {
    final e = Exercise(id: newId(), name: name, kind: kind);
    exercises.add(e);
    await save();
    return e;
  }

  Future<void> removeExercise(Exercise e) async {
    exercises.removeWhere((x) => x.id == e.id);
    logs.removeWhere((l) => l.exerciseId == e.id);
    await save();
  }

  Future<void> addLog(WorkoutLog l) async {
    logs.add(l);
    await save();
  }

  Future<void> removeLog(WorkoutLog l) async {
    logs.removeWhere((x) => x.id == l.id);
    await save();
  }

  Future<void> addMeasure(Measurement m) async {
    measures.add(m);
    await save();
  }

  /// Apaga só uma medida do registro; o registro some quando fica vazio.
  Future<void> removeMeasure(Measurement m, String field) async {
    m.values.remove(field);
    if (m.values.isEmpty) measures.removeWhere((x) => x.id == m.id);
    await save();
  }

  /// Registros do exercício, do mais recente ao mais antigo.
  List<WorkoutLog> logsFor(String exerciseId) =>
      logs.where((l) => l.exerciseId == exerciseId).toList()..sort((a, b) => b.date.compareTo(a.date));

  double best(Exercise e) => logsFor(e.id).fold(0.0, (m, l) {
    final v = mainValue(l, e.kind);
    return v > m ? v : m;
  });

  /// Pontos do gráfico: um por dia (soma no dia; no tempo parado, o maior).
  List<(DateTime, double)> series(Exercise e, TrendPeriod period, DateTime now) {
    final byDay = <DateTime, double>{};
    for (final l in logsFor(e.id)) {
      if (!period.includes(l.date, now)) continue;
      final d = dayOf(l.date);
      final v = mainValue(l, e.kind);
      final before = byDay[d] ?? 0;
      byDay[d] = e.kind == ExerciseKind.hold ? max(before, v) : before + v;
    }
    return byDay.entries.map((x) => (x.key, x.value)).toList()..sort((a, b) => a.$1.compareTo(b.$1));
  }

  List<(DateTime, double)> measureSeries(String field, TrendPeriod period, DateTime now) => [
    for (final m in measures.reversed)
      if (m.values[field] != null && period.includes(m.date, now)) (m.date, m.values[field]!),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  double? latestMeasure(String field) => measures.where((m) => m.values[field] != null).firstOrNull?.values[field];

  /// Semana [weeksAgo] semanas antes da atual.
  WeekSummary week(DateTime now, {int weeksAgo = 0}) {
    final d = dayOf(now);
    final start = DateTime(d.year, d.month, d.day - (d.weekday - 1) - 7 * weeksAgo);
    final end = DateTime(start.year, start.month, start.day + 7);
    final days = <DateTime>{};
    var minutes = 0.0, km = 0.0, reps = 0;
    for (final l in logs) {
      if (l.date.isBefore(start) || !l.date.isBefore(end)) continue;
      final kind = exercise(l.exerciseId)?.kind;
      if (kind == null) continue;
      days.add(dayOf(l.date));
      if (kind == ExerciseKind.cardio) {
        minutes += l.minutes;
        km += l.km;
      } else if (kind == ExerciseKind.reps) {
        reps += l.totalReps;
      }
    }
    return WeekSummary(days.length, minutes, km, reps);
  }
}
