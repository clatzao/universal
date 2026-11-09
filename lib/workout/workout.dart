import 'package:flutter/material.dart';

import '../core/format.dart';

enum ExerciseKind {
  cardio('Cardio', 'tempo e distância', Icons.directions_run),
  reps('Repetições', 'séries e repetições', Icons.fitness_center),
  hold('Tempo parado', 'séries e segundos', Icons.timer_outlined);

  final String label;
  final String hint;
  final IconData icon;

  const ExerciseKind(this.label, this.hint, this.icon);
}

class Exercise {
  final String id;
  String name;
  ExerciseKind kind;

  Exercise({required this.id, required this.name, required this.kind});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kind': kind.name};

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Exercício',
    kind: ExerciseKind.values.where((k) => k.name == j['kind']).firstOrNull ?? ExerciseKind.reps,
  );
}

const exercisePresets = [
  ('Corrida', ExerciseKind.cardio),
  ('Caminhada', ExerciseKind.cardio),
  ('Bicicleta', ExerciseKind.cardio),
  ('Flexão', ExerciseKind.reps),
  ('Abdominal', ExerciseKind.reps),
  ('Agachamento', ExerciseKind.reps),
  ('Barra', ExerciseKind.reps),
  ('Prancha', ExerciseKind.hold),
];

/// Um registro de treino. Cardio usa minutos e km; repetições usam séries × repetições;
/// tempo parado usa séries × segundos.
class WorkoutLog {
  final String id;
  final String exerciseId;
  DateTime date;
  double minutes;
  double km;
  int sets;
  int reps;
  int seconds;

  WorkoutLog({
    required this.id,
    required this.exerciseId,
    required this.date,
    this.minutes = 0,
    this.km = 0,
    this.sets = 1,
    this.reps = 0,
    this.seconds = 0,
  });

  int get totalReps => sets * reps;

  /// Minutos por km, quando há distância.
  double? get pace => km > 0 && minutes > 0 ? minutes / km : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'date': date.toIso8601String(),
    'minutes': minutes,
    'km': km,
    'sets': sets,
    'reps': reps,
    'seconds': seconds,
  };

  factory WorkoutLog.fromJson(Map<String, dynamic> j) => WorkoutLog(
    id: j['id'] as String,
    exerciseId: j['exerciseId'] as String? ?? '',
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    minutes: (j['minutes'] as num?)?.toDouble() ?? 0,
    km: (j['km'] as num?)?.toDouble() ?? 0,
    sets: (j['sets'] as num?)?.toInt() ?? 1,
    reps: (j['reps'] as num?)?.toInt() ?? 0,
    seconds: (j['seconds'] as num?)?.toInt() ?? 0,
  );
}

/// O número que mostra a evolução do exercício: distância (ou minutos, sem distância),
/// total de repetições ou o maior tempo parado.
double mainValue(WorkoutLog l, ExerciseKind kind) => switch (kind) {
  ExerciseKind.cardio => l.km > 0 ? l.km : l.minutes,
  ExerciseKind.reps => l.totalReps.toDouble(),
  ExerciseKind.hold => l.seconds.toDouble(),
};

String mainUnit(ExerciseKind kind, {bool usesKm = true}) => switch (kind) {
  ExerciseKind.cardio => usesKm ? 'km' : 'min',
  ExerciseKind.reps => 'repetições',
  ExerciseKind.hold => 's',
};

String describeLog(WorkoutLog l, ExerciseKind kind) => switch (kind) {
  ExerciseKind.cardio => [
    if (l.minutes > 0) '${fmtNum(l.minutes)} min',
    if (l.km > 0) '${fmtNum(l.km)} km',
    if (l.pace != null) 'ritmo ${formatPace(l.pace!)}',
  ].join(' · '),
  ExerciseKind.reps => '${l.sets} × ${l.reps} = ${l.totalReps} repetições',
  ExerciseKind.hold => '${l.sets} × ${l.seconds} s',
};

String fmtNum(double v) {
  final s = v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(v * 10 == (v * 10).roundToDouble() ? 1 : 2);
  return s.replaceAll('.', ',');
}

/// 5,5 min/km → "5:30/km".
String formatPace(double minPerKm) {
  final total = (minPerKm * 60).round();
  return '${total ~/ 60}:${two(total % 60)}/km';
}

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// Períodos dos gráficos.
enum TrendPeriod {
  d30('30 dias', 30),
  d90('90 dias', 90),
  y1('1 ano', 365),
  all('Tudo', 0);

  final String label;
  final int days;

  const TrendPeriod(this.label, this.days);

  bool includes(DateTime d, DateTime now) =>
      days == 0 || !dayOf(d).isBefore(DateTime(now.year, now.month, now.day - days + 1));
}

/// Medidas do corpo: chave, nome e unidade.
const measureFields = [
  ('peso', 'Peso', 'kg'),
  ('cintura', 'Cintura', 'cm'),
  ('quadril', 'Quadril', 'cm'),
  ('peito', 'Peito', 'cm'),
  ('braco', 'Braço', 'cm'),
  ('coxa', 'Coxa', 'cm'),
  ('gordura', 'Gordura corporal', '%'),
];

class Measurement {
  final String id;
  DateTime date;
  Map<String, double> values;

  Measurement({required this.id, required this.date, required this.values});

  Map<String, dynamic> toJson() => {'id': id, 'date': date.toIso8601String(), 'values': values};

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
    id: j['id'] as String,
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    values: ((j['values'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
  );
}

/// Resumo de uma semana (segunda a domingo).
class WeekSummary {
  final int days;
  final double minutes;
  final double km;
  final int reps;

  const WeekSummary(this.days, this.minutes, this.km, this.reps);
}
